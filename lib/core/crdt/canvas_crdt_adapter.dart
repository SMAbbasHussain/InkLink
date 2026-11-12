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

  /// Remove every undo/redo entry that touches any of [elementIds].
  /// Called when an owner's remote 'revert' arrives (D14).
  void pruneReverted(Set<String> elementIds);

  /// Drop the entire local undo/redo history (remote 'restore'/'clear' or a
  /// full snapshot hydration replaces the board, so the stack is meaningless).
  void clearLocalHistory();
}

/// Ledger entry stored on a Yjs undo stack item: the ORIGINAL local edit time
/// (never refreshed by undo/redo) plus the element keys that entry touches.
class _UndoMeta {
  final DateTime createdAt;
  final Set<String> elementIds;
  _UndoMeta(this.createdAt, this.elementIds);
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

  CanvasCrdtAdapter._(this._doc, this._elements, this._undoManager) {
    _undoManager.on('stack-item-added', (dynamic data, [dynamic _]) {
      final map = data as Map;
      if (map['origin'] != _localOrigin) return; // only genuine local edits
      final item = map['stackItem']; // inferred StackItem; never name the type
      (item.meta as Map<Object, Object?>)[_metaKey] =
          _UndoMeta(DateTime.now(), _changedElementIds(map['changedParentTypes']));
    });
    _undoManager.on('stack-item-updated', (dynamic data, [dynamic _]) {
      final map = data as Map;
      if (map['origin'] != _localOrigin) return;
      final item = map['stackItem'];
      final meta = (item.meta as Map<Object, Object?>)[_metaKey] as _UndoMeta?;
      // Merge: keep the ORIGINAL createdAt, accumulate touched keys.
      meta?.elementIds.addAll(_changedElementIds(map['changedParentTypes']));
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
    transact<void>(_doc, (_) {
      _elements.clear();
    }, origin);
    return encodeStateUpdate(vector: beforeVector);
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
    um.undo();
    // The inverse item was created with origin == manager (untagged). Carry the
    // ORIGINAL timestamp onto it so a later redo is validated against the same
    // window (ping-ponging cannot keep an edit alive past 15 minutes).
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
    um.redo();
    // Only tag when the stack actually grew — otherwise the last item is a
    // pre-existing entry and overwriting its meta would corrupt it.
    if (um.undoStack.length > undoLenBefore) {
      um.undoStack.last.meta[_metaKey] = meta;
    }
    return encodeStateUpdate(vector: beforeVector);
  }

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
