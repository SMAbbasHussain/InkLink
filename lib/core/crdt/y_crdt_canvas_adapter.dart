import 'dart:typed_data';
import 'dart:convert';

import 'package:y_crdt/y_crdt.dart';

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
    return YCrdtCanvasAdapter.create();
  }
}

class YCrdtCanvasAdapter implements CanvasDocAdapter {
  static const String elementsMapName = 'elements';
  static const String historyArrayName = 'history';
  final CanvasDocAdapter _delegate;

  YCrdtCanvasAdapter._(this._delegate);

  factory YCrdtCanvasAdapter.fallbackForTest() {
    return YCrdtCanvasAdapter._(_FallbackCanvasDocAdapter());
  }

  static Future<YCrdtCanvasAdapter> create() async {
    try {
      final api = await ycrdtApi();
      final doc = api.newDoc();
      final elements = doc.map(name: elementsMapName);
      final history = doc.array(name: historyArrayName);
      return YCrdtCanvasAdapter._(
        _YjsCanvasDocAdapter(api, doc, elements, history),
      );
    } catch (_) {
      // On some Android runtimes y_crdt initialization can fail.
      // Fallback keeps local+remote persistence operational.
      return YCrdtCanvasAdapter._(_FallbackCanvasDocAdapter());
    }
  }

  @override
  Uint8List encodeStateVector() {
    return _delegate.encodeStateVector();
  }

  @override
  Uint8List encodeStateUpdate({Uint8List? vector}) {
    return _delegate.encodeStateUpdate(vector: vector);
  }

  @override
  void applyUpdate(Uint8List update, {String origin = 'remote'}) {
    _delegate.applyUpdate(update, origin: origin);
  }

  @override
  Uint8List upsertElement(
    String elementId,
    Map<String, dynamic> payload, {
    String origin = 'local',
  }) {
    return _delegate.upsertElement(elementId, payload, origin: origin);
  }

  @override
  Uint8List deleteElement(String elementId, {String origin = 'local'}) {
    return _delegate.deleteElement(elementId, origin: origin);
  }

  @override
  Uint8List clearElements({String origin = 'local'}) {
    return _delegate.clearElements(origin: origin);
  }

  @override
  Uint8List? undoLast({String origin = 'local'}) {
    return _delegate.undoLast(origin: origin);
  }

  @override
  Uint8List? redoLast({String origin = 'local'}) {
    return _delegate.redoLast(origin: origin);
  }

  @override
  Map<String, Map<String, dynamic>> materializeElements() {
    return _delegate.materializeElements();
  }
}

class _YjsCanvasDocAdapter implements CanvasDocAdapter {
  final YCrdt _api;
  final YDocI _doc;
  final YMapI _elements;
  final YArrayI _history;

  _YjsCanvasDocAdapter(this._api, this._doc, this._elements, this._history);

  @override
  Uint8List encodeStateVector() {
    return _api.encodeStateVector(doc: _doc);
  }

  @override
  Uint8List encodeStateUpdate({Uint8List? vector}) {
    final result = _api.encodeStateAsUpdate(doc: _doc, vector: vector);
    if (result.isError) {
      throw Exception('Failed to encode CRDT state update: ${result.error}');
    }
    return result.ok!;
  }

  @override
  void applyUpdate(Uint8List update, {String origin = 'remote'}) {
    final result = _api.applyUpdate(
      doc: _doc,
      diff: update,
      origin: Uint8List.fromList(origin.codeUnits),
    );
    if (result.isError) {
      throw Exception('Failed to apply CRDT update: ${result.error}');
    }
  }

  @override
  Uint8List upsertElement(
    String elementId,
    Map<String, dynamic> payload, {
    String origin = 'local',
  }) {
    final before = materializeElements()[elementId];

    final txn = _doc.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );
    _elements.set(elementId, _toAnyVal(payload), txn: txn);
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

  @override
  Uint8List deleteElement(String elementId, {String origin = 'local'}) {
    final before = materializeElements()[elementId];
    if (before == null) {
      final txn = _doc.writeTransaction(
        origin: Uint8List.fromList(origin.codeUnits),
      );
      final update = txn.encodeUpdate();
      txn.commit();
      return update;
    }

    final txn = _doc.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );
    _elements.delete(elementId, txn: txn);
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

  @override
  Uint8List clearElements({String origin = 'local'}) {
    final snapshot = materializeElements();
    final txn = _doc.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );
    for (final key in snapshot.keys) {
      _elements.delete(key, txn: txn);
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

  @override
  Uint8List? undoLast({String origin = 'local'}) {
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

    final txn = _doc.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );

    _applyInverse(entry, txn);
    entry['undone'] = true;
    _replaceHistoryEntry(index, entry, txn);

    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  @override
  Uint8List? redoLast({String origin = 'local'}) {
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

    final txn = _doc.writeTransaction(
      origin: Uint8List.fromList(origin.codeUnits),
    );

    _applyForward(entry, txn);
    entry['undone'] = false;
    _replaceHistoryEntry(index, entry, txn);

    final update = txn.encodeUpdate();
    txn.commit();
    return update;
  }

  @override
  Map<String, Map<String, dynamic>> materializeElements() {
    final json = _elements.toJson();
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
    _history.push([_toAnyVal(entry)], txn: txn);
  }

  List<Map<String, dynamic>> _readHistory() {
    final raw = _history.toJson();
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
    _history.delete(index: index, length: 1, txn: txn);
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
          _elements.set(elementId, _toAnyVal(before), txn: txn);
        } else {
          _elements.delete(elementId, txn: txn);
        }
        return;
      case 'delete':
        if (elementId == null) return;
        if (before is Map<String, dynamic>) {
          _elements.set(elementId, _toAnyVal(before), txn: txn);
        }
        return;
      case 'clear':
        final current = _elements.toJson();
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
          _elements.set(elementId, _toAnyVal(after), txn: txn);
        }
        return;
      case 'delete':
        if (elementId == null) return;
        _elements.delete(elementId, txn: txn);
        return;
      case 'clear':
        final current = _elements.toJson();
        for (final key in current.keys) {
          _elements.delete(key, txn: txn);
        }
        return;
      default:
        return;
    }
  }
}

class _FallbackCanvasDocAdapter implements CanvasDocAdapter {
  final Map<String, Map<String, dynamic>> _elements =
      <String, Map<String, dynamic>>{};
  final Map<String, int> _elementVersions = <String, int>{};
  final Map<String, int> _tombstoneVersions = <String, int>{};
  final List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  int _lastVersion = 0;

  @override
  Uint8List encodeStateVector() {
    return Uint8List(0);
  }

  @override
  Uint8List encodeStateUpdate({Uint8List? vector}) {
    return _encodeSnapshot();
  }

  @override
  void applyUpdate(Uint8List update, {String origin = 'remote'}) {
    _applySnapshot(update);
  }

  @override
  Uint8List upsertElement(
    String elementId,
    Map<String, dynamic> payload, {
    String origin = 'local',
  }) {
    final version = _nextVersion();
    final before = _elements[elementId];
    _setElement(
      elementId,
      Map<String, dynamic>.from(payload),
      version: version,
    );
    _history.add({
      'op': 'upsert',
      'opId': _newOpId(version),
      'elementId': elementId,
      'before': before,
      'after': payload,
      'undone': false,
      'origin': origin,
      'version': version,
      'ts': DateTime.now().toIso8601String(),
    });
    return _encodeSnapshot();
  }

  @override
  Uint8List deleteElement(String elementId, {String origin = 'local'}) {
    final version = _nextVersion();
    final before = _elements[elementId];
    _setDeleted(elementId, version: version);
    _history.add({
      'op': 'delete',
      'opId': _newOpId(version),
      'elementId': elementId,
      'before': before,
      'after': null,
      'undone': false,
      'origin': origin,
      'version': version,
      'ts': DateTime.now().toIso8601String(),
    });
    return _encodeSnapshot();
  }

  @override
  Uint8List clearElements({String origin = 'local'}) {
    final version = _nextVersion();
    final snapshot = materializeElements();
    for (final elementId in _elements.keys.toList(growable: false)) {
      _setDeleted(elementId, version: version);
    }
    _elements.clear();
    _history.add({
      'op': 'clear',
      'opId': _newOpId(version),
      'elementId': null,
      'before': snapshot,
      'after': null,
      'undone': false,
      'origin': origin,
      'version': version,
      'ts': DateTime.now().toIso8601String(),
    });
    return _encodeSnapshot();
  }

  @override
  Uint8List? undoLast({String origin = 'local'}) {
    int index = -1;
    Map<String, dynamic>? entry;

    for (int i = _history.length - 1; i >= 0; i--) {
      final e = _history[i];
      if ((e['undone'] as bool?) == true) continue;
      index = i;
      entry = e;
      break;
    }

    if (index == -1 || entry == null) return null;

    _applyInverse(entry);
    entry['undone'] = true;
    _history[index] = Map<String, dynamic>.from(entry);
    return _encodeSnapshot();
  }

  @override
  Uint8List? redoLast({String origin = 'local'}) {
    int index = -1;
    Map<String, dynamic>? entry;

    for (int i = _history.length - 1; i >= 0; i--) {
      final e = _history[i];
      if ((e['undone'] as bool?) != true) continue;
      index = i;
      entry = e;
      break;
    }

    if (index == -1 || entry == null) return null;

    _applyForward(entry);
    entry['undone'] = false;
    _history[index] = Map<String, dynamic>.from(entry);
    return _encodeSnapshot();
  }

  @override
  Map<String, Map<String, dynamic>> materializeElements() {
    return _elements.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
  }

  Uint8List _encodeSnapshot() {
    final payload = {
      'kind': 'fallback_snapshot_v1',
      'elements': _elements,
      'elementVersions': _elementVersions,
      'tombstones': _tombstoneVersions,
      'history': _history,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  void _applySnapshot(Uint8List update) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(update));
    } catch (_) {
      return;
    }

    if (decoded is! Map<String, dynamic>) return;
    if (decoded['kind'] != 'fallback_snapshot_v1') return;

    final remoteElements = _readElementsMap(decoded['elements']);
    final remoteElementVersions = _readVersionsMap(decoded['elementVersions']);
    final remoteTombstones = _readVersionsMap(decoded['tombstones']);

    if (remoteElementVersions.isEmpty && remoteTombstones.isEmpty) {
      // Legacy payloads had no merge metadata. Merge as additive upserts.
      for (final entry in remoteElements.entries) {
        final version = _nextVersion();
        _setElement(entry.key, entry.value, version: version);
      }
    } else {
      final ids = <String>{
        ..._elements.keys,
        ..._elementVersions.keys,
        ..._tombstoneVersions.keys,
        ...remoteElements.keys,
        ...remoteElementVersions.keys,
        ...remoteTombstones.keys,
      };

      for (final id in ids) {
        final localElementVersion = _elementVersions[id] ?? 0;
        final localTombstoneVersion = _tombstoneVersions[id] ?? 0;
        final localVersion = localElementVersion >= localTombstoneVersion
            ? localElementVersion
            : localTombstoneVersion;
        final localIsDeleted = localTombstoneVersion > localElementVersion;

        final remoteElementVersion = remoteElementVersions[id] ?? 0;
        final remoteTombstoneVersion = remoteTombstones[id] ?? 0;
        final remoteVersion = remoteElementVersion >= remoteTombstoneVersion
            ? remoteElementVersion
            : remoteTombstoneVersion;
        final remoteIsDeleted = remoteTombstoneVersion > remoteElementVersion;

        if (remoteVersion > localVersion) {
          if (remoteIsDeleted) {
            _setDeleted(id, version: remoteVersion);
          } else {
            final remoteElement = remoteElements[id];
            if (remoteElement != null) {
              _setElement(id, remoteElement, version: remoteVersion);
            }
          }
          continue;
        }

        if (remoteVersion == localVersion && remoteVersion != 0) {
          // Prefer tombstones on equal clocks to avoid resurrection.
          if (remoteIsDeleted && !localIsDeleted) {
            _setDeleted(id, version: remoteVersion);
          }
        }
      }
    }

    final remoteHistory = _readHistoryList(decoded['history']);
    _mergeHistory(remoteHistory);
  }

  void _applyInverse(Map<String, dynamic> entry) {
    final version = _nextVersion();
    final op = entry['op'] as String?;
    final elementId = entry['elementId'] as String?;
    final before = entry['before'];

    switch (op) {
      case 'upsert':
        if (elementId == null) return;
        if (before is Map) {
          _setElement(
            elementId,
            before.map((k, v) => MapEntry(k.toString(), v)),
            version: version,
          );
        } else {
          _setDeleted(elementId, version: version);
        }
        return;
      case 'delete':
        if (elementId == null) return;
        if (before is Map) {
          _setElement(
            elementId,
            before.map((k, v) => MapEntry(k.toString(), v)),
            version: version,
          );
        }
        return;
      case 'clear':
        _elements.clear();
        _elementVersions.clear();
        if (before is Map) {
          for (final entry in before.entries) {
            if (entry.key is! String || entry.value is! Map) continue;
            final elementId = entry.key as String;
            final mapValue = (entry.value as Map).map(
              (k, v) => MapEntry(k.toString(), v),
            );
            _setElement(elementId, mapValue, version: version);
          }
        }
        return;
      default:
        return;
    }
  }

  void _applyForward(Map<String, dynamic> entry) {
    final version = _nextVersion();
    final op = entry['op'] as String?;
    final elementId = entry['elementId'] as String?;
    final after = entry['after'];

    switch (op) {
      case 'upsert':
        if (elementId == null || after is! Map) return;
        _setElement(
          elementId,
          after.map((k, v) => MapEntry(k.toString(), v)),
          version: version,
        );
        return;
      case 'delete':
        if (elementId == null) return;
        _setDeleted(elementId, version: version);
        return;
      case 'clear':
        for (final elementId in _elements.keys.toList(growable: false)) {
          _setDeleted(elementId, version: version);
        }
        _elements.clear();
        return;
      default:
        return;
    }
  }

  int _nextVersion() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (now <= _lastVersion) {
      _lastVersion += 1;
    } else {
      _lastVersion = now;
    }
    return _lastVersion;
  }

  String _newOpId(int version) => 'v$version';

  void _setElement(
    String elementId,
    Map<String, dynamic> payload, {
    required int version,
  }) {
    _elements[elementId] = Map<String, dynamic>.from(payload);
    _elementVersions[elementId] = version;
    _tombstoneVersions.remove(elementId);
    if (version > _lastVersion) {
      _lastVersion = version;
    }
  }

  void _setDeleted(String elementId, {required int version}) {
    _elements.remove(elementId);
    _elementVersions.remove(elementId);
    _tombstoneVersions[elementId] = version;
    if (version > _lastVersion) {
      _lastVersion = version;
    }
  }

  Map<String, Map<String, dynamic>> _readElementsMap(dynamic rawElements) {
    if (rawElements is! Map) return <String, Map<String, dynamic>>{};

    return rawElements.map(
      (k, v) => MapEntry(
        k.toString(),
        (v is Map)
            ? v.map((ek, ev) => MapEntry(ek.toString(), ev))
            : <String, dynamic>{},
      ),
    );
  }

  Map<String, int> _readVersionsMap(dynamic rawVersions) {
    if (rawVersions is! Map) return <String, int>{};

    return rawVersions.map((k, v) {
      final asInt = (v as num?)?.toInt() ?? 0;
      return MapEntry(k.toString(), asInt);
    });
  }

  List<Map<String, dynamic>> _readHistoryList(dynamic rawHistory) {
    if (rawHistory is! List) return <Map<String, dynamic>>[];

    return rawHistory
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  void _mergeHistory(List<Map<String, dynamic>> remoteHistory) {
    if (remoteHistory.isEmpty) return;

    final knownKeys = <String>{
      for (final h in _history)
        _historyKey(
          opId: h['opId']?.toString(),
          version: (h['version'] as num?)?.toInt(),
          op: h['op']?.toString(),
          elementId: h['elementId']?.toString(),
          ts: h['ts']?.toString(),
        ),
    };

    for (final remote in remoteHistory) {
      final key = _historyKey(
        opId: remote['opId']?.toString(),
        version: (remote['version'] as num?)?.toInt(),
        op: remote['op']?.toString(),
        elementId: remote['elementId']?.toString(),
        ts: remote['ts']?.toString(),
      );
      if (knownKeys.contains(key)) continue;

      _history.add(Map<String, dynamic>.from(remote));
      knownKeys.add(key);
    }
  }

  String _historyKey({
    required String? opId,
    required int? version,
    required String? op,
    required String? elementId,
    required String? ts,
  }) {
    if (opId != null && opId.isNotEmpty) {
      return 'op:$opId';
    }
    if (version != null) {
      return 'ver:$version';
    }
    return 'legacy:${op ?? ''}:${elementId ?? ''}:${ts ?? ''}';
  }
}
