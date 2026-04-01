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

  CanvasCrdtAdapter._(this._doc, this._elements, this._undoManager);

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
    if (!_undoManager.canUndo()) {
      return null;
    }

    final beforeVector = encodeStateVector();
    _undoManager.undo();
    return encodeStateUpdate(vector: beforeVector);
  }

  @override
  Uint8List? redoLast({String origin = 'local'}) {
    if (!_undoManager.canRedo()) {
      return null;
    }

    final beforeVector = encodeStateVector();
    _undoManager.redo();
    return encodeStateUpdate(vector: beforeVector);
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
