import 'dart:convert';
import 'dart:typed_data';

import 'package:yjs_dart/yjs_dart.dart';
import 'package:yjs_dart/yjs_dart.dart' as yjs;

abstract class CanvasDocAdapter {
  Uint8List encodeStateVector();
  Uint8List encodeStateUpdate({Uint8List? vector});
  void applyUpdate(Uint8List update, {String origin = 'remote'});
  Uint8List upsertElement(
    String elementId,
    Map<String, dynamic> payload, {
    String origin = 'local',
  });
  Uint8List deleteElement(String elementId, {String origin = 'local'});
  Uint8List clearElements({String origin = 'local'});
  Uint8List? undoLast({String origin = 'local'});
  Uint8List? redoLast({String origin = 'local'});
  Map<String, Map<String, dynamic>> materializeElements();

  /// Element ids the TOP undo entry would revert, without popping it.
  /// Returns null when the stack is empty or the entry is older than the
  /// 15-minute window (D2) — the caller should fall back to the server-side
  /// log undo. Used to detect "someone changed my work" conflicts BEFORE the
  /// entry is consumed (see [CanvasBloc._onUndo]).
  Set<String>? peekUndoElementIds();

  /// Same as [peekUndoElementIds] for the top REDO entry.
  Set<String>? peekRedoElementIds();

  /// Remove every undo/redo entry that touches any of [elementIds].
  /// Called when an owner's remote 'revert' arrives (D14).
  void pruneReverted(Set<String> elementIds);

  /// Drop the entire local undo/redo history (remote 'restore'/'clear' or a
  /// full snapshot hydration replaces the board, so the stack is meaningless).
  void clearLocalHistory();
}

/// Ledger entry stored on a Yjs undo stack item: the ORIGINAL local edit time
/// (never refreshed by undo/redo), the element keys that entry touches, and
/// what those elements held BEFORE the entry was applied (null = absent).
/// The pre-state lets a pop that changed nothing visible (peer interference,
/// §7.2) still be completed as an element-level revert (D10) and gives the
/// matching redo entry its content.
class _UndoMeta {
  final DateTime createdAt;
  final Set<String> elementIds;
  final Map<String, Map<String, dynamic>?> preState;
  _UndoMeta(this.createdAt, this.elementIds, {Map<String, Map<String, dynamic>?>? preState})
      : preState = preState ?? <String, Map<String, dynamic>?>{};
}

class CanvasDocAdapterFactory {
  static Future<CanvasDocAdapter> create() {
    return CanvasCrdtAdapter.create();
  }
}

class CanvasCrdtAdapter implements CanvasDocAdapter {
  static const String elementsMapName = 'elements';
  static const String _localOrigin = 'local';

  final Doc _doc;
  final YMap<Object?> _elements;
  final UndoManager _undoManager;

  static const Duration undoWindow = Duration(minutes: 15); // D2
  static const String _metaKey = 'inklinkUndo'; // key into StackItem.meta

  /// Element values captured immediately BEFORE a local edit transaction, so
  /// the stack-item-added/updated events can attach them to the entry's meta.
  Map<String, Map<String, dynamic>?>? _txnPreState;

  CanvasCrdtAdapter._(this._doc, this._elements, this._undoManager) {
    _undoManager.on('stack-item-added', (dynamic data, [dynamic _]) {
      final map = data as Map;
      if (map['origin'] != _localOrigin) return; // only genuine local edits
      final item = map['stackItem']; // inferred StackItem; never name the type
      (item.meta as Map<Object, Object?>)[_metaKey] = _UndoMeta(
        DateTime.now(),
        _changedElementIds(map['changedParentTypes']),
        preState: _txnPreState == null ? null : Map.of(_txnPreState!),
      );
      _txnPreState = null;
    });
    _undoManager.on('stack-item-updated', (dynamic data, [dynamic _]) {
      final map = data as Map;
      if (map['origin'] != _localOrigin) return;
      final item = map['stackItem'];
      final meta = (item.meta as Map<Object, Object?>)[_metaKey] as _UndoMeta?;
      // Merge: keep the ORIGINAL createdAt and pre-state, accumulate touched
      // keys.
      meta?.elementIds.addAll(_changedElementIds(map['changedParentTypes']));
      if (meta != null && _txnPreState != null) {
        _txnPreState!.forEach((id, value) {
          meta.preState.putIfAbsent(id, () => value);
        });
      }
      _txnPreState = null;
    });
  }

  Set<String> _changedElementIds(dynamic changed) {
    final keys = <String>{};
    if (changed is Map) {
      final events = changed[_elements]; // List<YEvent> for our YMap
      if (events is List) {
        for (final event in events) {
          if (event is YEvent) keys.addAll(event.keysChanged);
        }
      }
    }
    return keys;
  }

  static Future<CanvasCrdtAdapter> create() async {
    final doc = Doc();
    final elements = doc.getMap<Object?>(elementsMapName);
    if (elements == null) {
      throw StateError('Failed to initialize CRDT elements map.');
    }

    final undoManager = UndoManager(
      elements,
      UndoManagerOpts(trackedOrigins: {_localOrigin}),
    );

    return CanvasCrdtAdapter._(doc, elements, undoManager);
  }

  @override
  Uint8List encodeStateVector() {
    return yjs.encodeStateVector(_doc);
  }

  @override
  Uint8List encodeStateUpdate({Uint8List? vector}) {
    return yjs.encodeStateAsUpdate(_doc, vector);
  }

  @override
  void applyUpdate(Uint8List update, {String origin = 'remote'}) {
    yjs.applyUpdate(_doc, update, origin);
  }

  @override
  Uint8List upsertElement(
    String elementId,
    Map<String, dynamic> payload, {
    String origin = 'local',
  }) {
    final beforeVector = encodeStateVector();
    _capturePreState(origin, {elementId: materializeElements()[elementId]});
    transact<void>(_doc, (_) {
      _elements.set(elementId, _cloneValue(payload));
    }, origin);
    return encodeStateUpdate(vector: beforeVector);
  }

  @override
  Uint8List deleteElement(String elementId, {String origin = 'local'}) {
    if (!_elements.has(elementId)) {
      return Uint8List(0);
    }

    final beforeVector = encodeStateVector();
    _capturePreState(origin, {elementId: materializeElements()[elementId]});
    transact<void>(_doc, (_) {
      _elements.delete(elementId);
    }, origin);
    return encodeStateUpdate(vector: beforeVector);
  }

  @override
  Uint8List clearElements({String origin = 'local'}) {
    if (_elements.size == 0) {
      return Uint8List(0);
    }

    final beforeVector = encodeStateVector();
    _capturePreState(
      origin,
      {
        for (final entry in materializeElements().entries)
          entry.key: entry.value,
      },
    );
    transact<void>(_doc, (_) {
      _elements.clear();
    }, origin);
    return encodeStateUpdate(vector: beforeVector);
  }

  /// Remember the element values present BEFORE a local edit transaction so
  /// the entry's meta can carry them (see [_UndoMeta.preState]).
  void _capturePreState(
    String origin,
    Map<String, Map<String, dynamic>?> values,
  ) {
    if (origin != _localOrigin) return;
    _txnPreState = values;
  }

  @override
  Uint8List? undoLast({String origin = 'local'}) {
    final um = _undoManager;
    if (!um.canUndo()) return null;
    final top = um.undoStack.last;
    final meta = top.meta[_metaKey] as _UndoMeta?;
    // D2: refuse when we cannot prove the edit is within the window. The bloc
    // then falls back to server-side undo_own (§6.9). Because the stack is LIFO
    // an expired top means everything beneath it is older too.
    if (meta == null || DateTime.now().difference(meta.createdAt) > undoWindow) {
      return null;
    }
    final redoLenBefore = um.redoStack.length;
    final beforeVector = encodeStateVector();
    final beforeElements = materializeElements();
    um.undo();
    // The inverse item was created with origin == manager (untagged). Carry the
    // ORIGINAL timestamp onto it so a later redo is validated against the same
    // window (ping-ponging cannot keep an edit alive past 15 minutes).
    if (um.redoStack.length > redoLenBefore) {
      um.redoStack.last.meta[_metaKey] = meta;
    }
    // A pop that leaves every element untouched achieved nothing visible —
    // e.g. a collaborator overwrote our creation and then undid their own
    // edit: yjs resurrects our value as a PEER-owned redo copy, so our stack
    // item's own items are dead and undoing them changes nothing. Complete
    // the undo OURSELVES as an element-level revert (D10): restore the
    // pre-entry values, and make THAT restore the redo unit so undo/redo
    // keeps ping-ponging (§7.2).
    if (!_visibleStateEquals(beforeElements, materializeElements())) {
      return encodeStateUpdate(vector: beforeVector);
    }
    if (um.redoStack.length > redoLenBefore) {
      um.redoStack.removeLast(); // drop the empty entry the pop appended
    }
    um.undoing = true; // keep the redo stack; the restore IS its redo unit
    try {
      transact<void>(_doc, (_) {
        meta.preState.forEach((id, value) {
          if (value == null) {
            if (_elements.has(id)) _elements.delete(id);
          } else {
            _elements.set(id, _cloneValue(value));
          }
        });
      }, um);
    } finally {
      um.undoing = false;
    }
    if (um.redoStack.length > redoLenBefore) {
      um.redoStack.last.meta[_metaKey] = meta;
    }
    return encodeStateUpdate(vector: beforeVector);
  }

  @override
  Uint8List? redoLast({String origin = 'local'}) {
    final um = _undoManager;
    if (!um.canRedo()) return null;
    final top = um.redoStack.last;
    final meta = top.meta[_metaKey] as _UndoMeta?;
    if (meta == null || DateTime.now().difference(meta.createdAt) > undoWindow) {
      return null;
    }
    final undoLenBefore = um.undoStack.length;
    final beforeVector = encodeStateVector();
    final beforeElements = materializeElements();
    um.redo();
    // Only tag when the stack actually grew — otherwise the last item is a
    // pre-existing entry and overwriting its meta would corrupt it.
    if (um.undoStack.length > undoLenBefore) {
      um.undoStack.last.meta[_metaKey] = meta;
    }
    // Same no-visible-change rule as undoLast: a redo whose target already
    // holds the restored value (e.g. the peer undid their overwrite, which
    // resurrected our content) is an honest no-op, not a success (§7.2).
    if (_visibleStateEquals(beforeElements, materializeElements())) {
      return Uint8List(0);
    }
    return encodeStateUpdate(vector: beforeVector);
  }

  /// Top-of-stack element ids without popping. Null = nothing to undo/redo
  /// locally (empty stack, or the entry is outside the 15-minute D2 window).
  Set<String>? _peekElementIds(bool undo) {
    final um = _undoManager;
    if (undo ? !um.canUndo() : !um.canRedo()) return null;
    final stack = undo ? um.undoStack : um.redoStack;
    if (stack.isEmpty) return null;
    final meta = stack.last.meta[_metaKey] as _UndoMeta?;
    if (meta == null || DateTime.now().difference(meta.createdAt) > undoWindow) {
      return null;
    }
    return Set<String>.of(meta.elementIds);
  }

  @override
  Set<String>? peekUndoElementIds() => _peekElementIds(true);

  @override
  Set<String>? peekRedoElementIds() => _peekElementIds(false);

  @override
  void pruneReverted(Set<String> elementIds) {
    if (elementIds.isEmpty) return;
    final um = _undoManager;
    bool touches(dynamic item) {
      final meta = (item.meta as Map<Object, Object?>)[_metaKey] as _UndoMeta?;
      return meta != null && meta.elementIds.intersection(elementIds).isNotEmpty;
    }

    um.undoStack.removeWhere(touches);
    um.redoStack.removeWhere(touches);
    um.stopCapturing(); // the next local edit starts a fresh entry
  }

  @override
  void clearLocalHistory() {
    _undoManager.clear();
  }

  @override
  Map<String, Map<String, dynamic>> materializeElements() {
    final result = <String, Map<String, dynamic>>{};
    final raw = _elements.toMap();

    for (final entry in raw.entries) {
      final normalized = _normalizeValue(entry.value);
      if (normalized is Map<String, dynamic>) {
        result[entry.key] = normalized;
      }
    }

    return result;
  }

  /// Deep equality between two [materializeElements] snapshots, used to
  /// detect whether an undo/redo pop actually changed anything a user could
  /// see. Values come from the same doc, so nested lists keep their order.
  bool _visibleStateEquals(
    Map<String, Map<String, dynamic>> a,
    Map<String, Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (!_leafEquals(entry.value, other)) return false;
    }
    return true;
  }

  bool _leafEquals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_leafEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_leafEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  dynamic _cloneValue(dynamic value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is Uint8List) {
      return Uint8List.fromList(value);
    }
    if (value is List) {
      return value.map(_cloneValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _cloneValue(v)));
    }
    return value;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is Uint8List) {
      return Uint8List.fromList(value);
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _normalizeValue(v)));
    }
    if (value is List) {
      return value.map(_normalizeValue).toList(growable: false);
    }

    try {
      return jsonDecode(jsonEncode(value));
    } catch (_) {
      return value.toString();
    }
  }
}
