import 'dart:typed_data';
import 'dart:convert';

import 'package:y_crdt/y_crdt.dart';

class YCrdtCanvasAdapter {
  static const String elementsMapName = 'elements';
  static const String historyArrayName = 'history';

  final YCrdt? _api;
  final YDocI? _doc;
  final YMapI? _elements;
  final YArrayI? _history;
  final bool _fallback;
  final Map<String, Map<String, dynamic>> _fallbackElements =
      <String, Map<String, dynamic>>{};
  final List<Map<String, dynamic>> _fallbackHistory = <Map<String, dynamic>>[];

  YCrdtCanvasAdapter._(
    this._api,
    this._doc,
    this._elements,
    this._history, {
    bool fallback = false,
  }) : _fallback = fallback;

  static Future<YCrdtCanvasAdapter> create() async {
    try {
      final api = await ycrdtApi();
      final doc = api.newDoc();
      final elements = doc.map(name: elementsMapName);
      final history = doc.array(name: historyArrayName);
      return YCrdtCanvasAdapter._(api, doc, elements, history);
    } catch (_) {
      // On some Android runtimes y_crdt initialization can fail.
      // Fallback keeps local+remote persistence operational.
      return YCrdtCanvasAdapter._(null, null, null, null, fallback: true);
    }
  }

  Uint8List encodeStateVector() {
    if (_fallback) return Uint8List(0);
    return _api!.encodeStateVector(doc: _doc!);
  }

  Uint8List encodeStateUpdate({Uint8List? vector}) {
    if (_fallback) {
      return _encodeFallbackSnapshot();
    }

    final result = _api!.encodeStateAsUpdate(doc: _doc!, vector: vector);
    if (result.isError) {
      throw Exception('Failed to encode CRDT state update: ${result.error}');
    }
    return result.ok!;
  }

  void applyUpdate(Uint8List update, {String origin = 'remote'}) {
    if (_fallback) {
      _applyFallbackSnapshot(update);
      return;
    }

    final result = _api!.applyUpdate(
      doc: _doc!,
      diff: update,
      origin: Uint8List.fromList(origin.codeUnits),
    );
    if (result.isError) {
      throw Exception('Failed to apply CRDT update: ${result.error}');
    }
  }

  Uint8List upsertElement(
    String elementId,
    Map<String, dynamic> payload, {
    String origin = 'local',
  }) {
    if (_fallback) {
      final before = _fallbackElements[elementId];
      _fallbackElements[elementId] = Map<String, dynamic>.from(payload);
      _fallbackHistory.add({
        'op': 'upsert',
        'elementId': elementId,
        'before': before,
        'after': payload,
        'undone': false,
        'origin': origin,
        'ts': DateTime.now().toIso8601String(),
      });
      return _encodeFallbackSnapshot();
    }

    final before = materializeElements()[elementId];

    final txn = _doc!.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );
    _elements!.set(elementId, _toAnyVal(payload), txn: txn);
    _appendHistory({
      'op': 'upsert',
      'elementId': elementId,
      'before': before,
      'after': payload,
      'undone': false,
      'origin': origin,
      'ts': DateTime.now().toIso8601String(),
    }, txn);
    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  Uint8List deleteElement(String elementId, {String origin = 'local'}) {
    if (_fallback) {
      final before = _fallbackElements[elementId];
      if (before == null) {
        return _encodeFallbackSnapshot();
      }

      _fallbackElements.remove(elementId);
      _fallbackHistory.add({
        'op': 'delete',
        'elementId': elementId,
        'before': before,
        'after': null,
        'undone': false,
        'origin': origin,
        'ts': DateTime.now().toIso8601String(),
      });
      return _encodeFallbackSnapshot();
    }

    final before = materializeElements()[elementId];
    if (before == null) {
      final txn = _doc!.writeTransaction(
        origin: Uint8List.fromList(origin.codeUnits),
      );
      final update = txn.encodeUpdate();
      txn.commit();
      return update;
    }

    final txn = _doc!.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );
    _elements!.delete(elementId, txn: txn);
    _appendHistory({
      'op': 'delete',
      'elementId': elementId,
      'before': before,
      'after': null,
      'undone': false,
      'origin': origin,
      'ts': DateTime.now().toIso8601String(),
    }, txn);
    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  Uint8List clearElements({String origin = 'local'}) {
    if (_fallback) {
      final snapshot = materializeElements();
      _fallbackElements.clear();
      _fallbackHistory.add({
        'op': 'clear',
        'elementId': null,
        'before': snapshot,
        'after': null,
        'undone': false,
        'origin': origin,
        'ts': DateTime.now().toIso8601String(),
      });
      return _encodeFallbackSnapshot();
    }

    final snapshot = materializeElements();
    final txn = _doc!.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );
    for (final key in snapshot.keys) {
      _elements!.delete(key, txn: txn);
    }
    _appendHistory({
      'op': 'clear',
      'elementId': null,
      'before': snapshot,
      'after': null,
      'undone': false,
      'origin': origin,
      'ts': DateTime.now().toIso8601String(),
    }, txn);
    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  Uint8List? undoLast({String origin = 'local'}) {
    if (_fallback) {
      int index = -1;
      Map<String, dynamic>? entry;

      for (int i = _fallbackHistory.length - 1; i >= 0; i--) {
        final e = _fallbackHistory[i];
        if ((e['undone'] as bool?) == true) continue;
        index = i;
        entry = e;
        break;
      }

      if (index == -1 || entry == null) return null;

      _applyFallbackInverse(entry);
      entry['undone'] = true;
      _fallbackHistory[index] = Map<String, dynamic>.from(entry);
      return _encodeFallbackSnapshot();
    }

    final history = _readHistory();
    int index = -1;
    Map<String, dynamic>? entry;

    for (int i = history.length - 1; i >= 0; i--) {
      final e = history[i];
      if ((e['undone'] as bool?) == true) continue;
      index = i;
      entry = e;
      break;
    }

    if (index == -1 || entry == null) return null;

    final txn = _doc!.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );

    _applyInverse(entry, txn);
    entry['undone'] = true;
    _replaceHistoryEntry(index, entry, txn);

    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  Uint8List? redoLast({String origin = 'local'}) {
    if (_fallback) {
      int index = -1;
      Map<String, dynamic>? entry;

      for (int i = _fallbackHistory.length - 1; i >= 0; i--) {
        final e = _fallbackHistory[i];
        if ((e['undone'] as bool?) != true) continue;
        index = i;
        entry = e;
        break;
      }

      if (index == -1 || entry == null) return null;

      _applyFallbackForward(entry);
      entry['undone'] = false;
      _fallbackHistory[index] = Map<String, dynamic>.from(entry);
      return _encodeFallbackSnapshot();
    }

    final history = _readHistory();
    int index = -1;
    Map<String, dynamic>? entry;

    for (int i = history.length - 1; i >= 0; i--) {
      final e = history[i];
      if ((e['undone'] as bool?) != true) continue;
      index = i;
      entry = e;
      break;
    }

    if (index == -1 || entry == null) return null;

    final txn = _doc!.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );

    _applyForward(entry, txn);
    entry['undone'] = false;
    _replaceHistoryEntry(index, entry, txn);

    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  Map<String, Map<String, dynamic>> materializeElements() {
    if (_fallback) {
      return _fallbackElements.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
      );
    }

    final json = _elements!.toJson();
    final result = <String, Map<String, dynamic>>{};

    for (final entry in json.entries) {
      final mapped = _fromAnyVal(entry.value);
      if (mapped is Map<String, dynamic>) {
        result[entry.key] = mapped;
      }
    }

    return result;
  }

  AnyVal _toAnyVal(dynamic value) {
    if (value == null) return const AnyValNull();
    if (value is bool) return AnyVal.boolean(value);
    if (value is num) return AnyVal.number(value.toDouble());
    if (value is String) return AnyVal.str(value);
    if (value is Uint8List) return AnyVal.buffer(value);
    if (value is List) {
      return AnyVal.array(value.map(_toAnyVal).toList(growable: false));
    }
    if (value is Map) {
      final cast = <String, AnyVal>{};
      value.forEach((k, v) {
        cast[k.toString()] = _toAnyVal(v);
      });
      return AnyVal.map(cast);
    }
    return AnyVal.str(value.toString());
  }

  dynamic _fromAnyVal(AnyVal value) {
    return switch (value) {
      AnyValNull _ => null,
      AnyValUndefined _ => null,
      AnyValBoolean v => v.value,
      AnyValNumber v => v.value,
      AnyValBigInt v => v.value,
      AnyValStr v => v.value,
      AnyValBuffer v => v.value,
      AnyValArray v => v.value.map(_fromAnyVal).toList(growable: false),
      AnyValMap v => v.value.map((k, val) => MapEntry(k, _fromAnyVal(val))),
    };
  }

  void _appendHistory(Map<String, dynamic> entry, WriteTransactionI txn) {
    _history!.push([_toAnyVal(entry)], txn: txn);
  }

  List<Map<String, dynamic>> _readHistory() {
    final raw = _history!.toJson();
    return raw
        .map(_fromAnyVal)
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  void _replaceHistoryEntry(
    int index,
    Map<String, dynamic> entry,
    WriteTransactionI txn,
  ) {
    _history!.delete(index: index, length: 1, txn: txn);
    _history.insert(index: index, items: [_toAnyVal(entry)], txn: txn);
  }

  void _applyInverse(Map<String, dynamic> entry, WriteTransactionI txn) {
    final op = entry['op'] as String?;
    final elementId = entry['elementId'] as String?;
    final before = entry['before'];

    switch (op) {
      case 'upsert':
        if (elementId == null) return;
        if (before is Map<String, dynamic>) {
          _elements!.set(elementId, _toAnyVal(before), txn: txn);
        } else {
          _elements!.delete(elementId, txn: txn);
        }
        return;
      case 'delete':
        if (elementId == null) return;
        if (before is Map<String, dynamic>) {
          _elements!.set(elementId, _toAnyVal(before), txn: txn);
        }
        return;
      case 'clear':
        final current = _elements!.toJson();
        for (final key in current.keys) {
          _elements.delete(key, txn: txn);
        }
        if (before is Map<String, dynamic>) {
          for (final e in before.entries) {
            _elements.set(e.key, _toAnyVal(e.value), txn: txn);
          }
        }
        return;
      default:
        return;
    }
  }

  void _applyForward(Map<String, dynamic> entry, WriteTransactionI txn) {
    final op = entry['op'] as String?;
    final elementId = entry['elementId'] as String?;
    final after = entry['after'];

    switch (op) {
      case 'upsert':
        if (elementId == null) return;
        if (after is Map<String, dynamic>) {
          _elements!.set(elementId, _toAnyVal(after), txn: txn);
        }
        return;
      case 'delete':
        if (elementId == null) return;
        _elements!.delete(elementId, txn: txn);
        return;
      case 'clear':
        final current = _elements!.toJson();
        for (final key in current.keys) {
          _elements.delete(key, txn: txn);
        }
        return;
      default:
        return;
    }
  }

  Uint8List _encodeFallbackSnapshot() {
    final payload = {
      'kind': 'fallback_snapshot_v1',
      'elements': _fallbackElements,
      'history': _fallbackHistory,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  void _applyFallbackSnapshot(Uint8List update) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(update));
    } catch (_) {
      return;
    }

    if (decoded is! Map<String, dynamic>) return;
    if (decoded['kind'] != 'fallback_snapshot_v1') return;

    final rawElements = decoded['elements'];
    final rawHistory = decoded['history'];

    _fallbackElements
      ..clear()
      ..addAll(
        (rawElements is Map)
            ? rawElements.map(
                (k, v) => MapEntry(
                  k.toString(),
                  (v is Map)
                      ? v.map((ek, ev) => MapEntry(ek.toString(), ev))
                      : <String, dynamic>{},
                ),
              )
            : <String, Map<String, dynamic>>{},
      );

    _fallbackHistory
      ..clear()
      ..addAll(
        (rawHistory is List)
            ? rawHistory.whereType<Map>().map(
                (e) => e.map((k, v) => MapEntry(k.toString(), v)),
              )
            : const Iterable<Map<String, dynamic>>.empty(),
      );
  }

  void _applyFallbackInverse(Map<String, dynamic> entry) {
    final op = entry['op'] as String?;
    final elementId = entry['elementId'] as String?;
    final before = entry['before'];

    switch (op) {
      case 'upsert':
        if (elementId == null) return;
        if (before is Map) {
          _fallbackElements[elementId] = before.map(
            (k, v) => MapEntry(k.toString(), v),
          );
        } else {
          _fallbackElements.remove(elementId);
        }
        return;
      case 'delete':
        if (elementId == null) return;
        if (before is Map) {
          _fallbackElements[elementId] = before.map(
            (k, v) => MapEntry(k.toString(), v),
          );
        }
        return;
      case 'clear':
        _fallbackElements.clear();
        if (before is Map) {
          _fallbackElements.addAll(
            before.map(
              (k, v) => MapEntry(
                k.toString(),
                (v is Map)
                    ? v.map((ek, ev) => MapEntry(ek.toString(), ev))
                    : <String, dynamic>{},
              ),
            ),
          );
        }
        return;
      default:
        return;
    }
  }

  void _applyFallbackForward(Map<String, dynamic> entry) {
    final op = entry['op'] as String?;
    final elementId = entry['elementId'] as String?;
    final after = entry['after'];

    switch (op) {
      case 'upsert':
        if (elementId == null || after is! Map) return;
        _fallbackElements[elementId] = after.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        return;
      case 'delete':
        if (elementId == null) return;
        _fallbackElements.remove(elementId);
        return;
      case 'clear':
        _fallbackElements.clear();
        return;
      default:
        return;
    }
  }
}
