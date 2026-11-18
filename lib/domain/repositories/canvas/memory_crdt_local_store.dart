import 'dart:async';

import '../../models/canvas/crdt_update.dart';
import 'crdt_local_store.dart';

/// In-memory [CrdtLocalStore] for the web canvas (online-only: everything
/// is lost on page reload and rebuilt from the server).
///
/// It mimics Isar's behaviour the sync code relies on: reads return copies
/// (so changing a result does nothing until it is put back), a put replaces
/// the update with the same `updateId`, an update without an id gets the
/// next one, and sorted reads break ties by id.
class MemoryCrdtLocalStore implements CrdtLocalStore {
  final Map<String, LocalCrdtUpdate> _byUpdateId = <String, LocalCrdtUpdate>{};
  final Map<String, String> _cursors = <String, String>{};
  final Map<String, DateTime> _syncedAt = <String, DateTime>{};
  final StreamController<String> _changes = StreamController<String>.broadcast(
    sync: false,
  );
  int _nextId = 1;

  static LocalCrdtUpdate _copy(LocalCrdtUpdate u) => LocalCrdtUpdate()
    ..id = u.id
    ..updateId = u.updateId
    ..boardId = u.boardId
    ..elementId = u.elementId
    ..action = u.action
    ..affectedElementIds = u.affectedElementIds == null
        ? null
        : List<String>.of(u.affectedElementIds!)
    ..payloadBase64 = u.payloadBase64
    ..sourceClientId = u.sourceClientId
    ..appliedAt = u.appliedAt
    ..version = u.version
    ..isSynced = u.isSynced
    ..isDeleted = u.isDeleted;

  void _put(LocalCrdtUpdate update) {
    final stored = _copy(update);
    final previous = _byUpdateId.remove(update.updateId);
    if (stored.id <= 0) {
      stored.id = previous?.id ?? _nextId++;
    } else if (stored.id >= _nextId) {
      _nextId = stored.id + 1;
    }
    update.id = stored.id;
    _byUpdateId[update.updateId] = stored;
    _changes.add(update.boardId);
    if (previous != null && previous.boardId != update.boardId) {
      _changes.add(previous.boardId);
    }
  }

  List<LocalCrdtUpdate> _board(String boardId) {
    final list = _byUpdateId.values.where((u) => u.boardId == boardId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  static int _byAppliedAt(LocalCrdtUpdate a, LocalCrdtUpdate b) {
    final c = a.appliedAt.compareTo(b.appliedAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  static int _byAppliedAtDesc(LocalCrdtUpdate a, LocalCrdtUpdate b) {
    final c = b.appliedAt.compareTo(a.appliedAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  List<LocalCrdtUpdate> _copies(Iterable<LocalCrdtUpdate> list) =>
      list.map(_copy).toList();

  @override
  Future<void> saveUpdateAndSyncedAt(LocalCrdtUpdate update) async {
    _put(update);
    _syncedAt[update.boardId] = update.appliedAt;
  }

  @override
  Future<void> deleteUpdatesForBoard(String boardId) async {
    final before = _byUpdateId.length;
    _byUpdateId.removeWhere((_, u) => u.boardId == boardId);
    if (_byUpdateId.length != before) _changes.add(boardId);
  }

  @override
  Future<LocalCrdtUpdate?> getByUpdateId(String updateId) async {
    final u = _byUpdateId[updateId];
    return u == null ? null : _copy(u);
  }

  @override
  Future<void> putUpdate(LocalCrdtUpdate update) async => _put(update);

  @override
  Future<List<LocalCrdtUpdate>> updatesForBoard(String boardId) async =>
      _copies(_board(boardId));

  @override
  Future<List<LocalCrdtUpdate>> updatesForBoardNewestFirst(
    String boardId,
  ) async => _copies(_board(boardId)..sort(_byAppliedAtDesc));

  @override
  Future<LocalCrdtUpdate?> latestSyncedUpdate(String boardId) async {
    final list = _board(boardId).where((u) => u.isSynced).toList()
      ..sort(_byAppliedAtDesc);
    return list.isEmpty ? null : _copy(list.first);
  }

  @override
  Future<LocalCrdtUpdate?> latestUpdate(String boardId) async {
    final list = _board(boardId)..sort(_byAppliedAtDesc);
    return list.isEmpty ? null : _copy(list.first);
  }

  @override
  Future<LocalCrdtUpdate?> highestVersionUpdate(String boardId) async {
    final list = _board(boardId)
      ..sort((a, b) {
        final c = b.version.compareTo(a.version);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return list.isEmpty ? null : _copy(list.first);
  }

  @override
  Future<List<LocalCrdtUpdate>> unsyncedUpdatesOldestFirst(
    String boardId,
  ) async => _copies(
    _board(boardId).where((u) => !u.isSynced).toList()..sort(_byAppliedAt),
  );

  @override
  Future<void> deleteSyncedUpdatesAppliedBefore(
    String boardId,
    DateTime cutoff,
  ) async {
    final before = _byUpdateId.length;
    _byUpdateId.removeWhere(
      (_, u) =>
          u.boardId == boardId && u.isSynced && u.appliedAt.isBefore(cutoff),
    );
    if (_byUpdateId.length != before) _changes.add(boardId);
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchUpdatesForBoard(String boardId) {
    List<LocalCrdtUpdate> snapshot() =>
        _copies(_board(boardId)..sort(_byAppliedAt));
    StreamSubscription<String>? changes;
    late final StreamController<List<LocalCrdtUpdate>> controller;
    controller = StreamController<List<LocalCrdtUpdate>>(
      onListen: () {
        controller.add(snapshot());
        changes = _changes.stream.listen((changed) {
          if (changed == boardId) controller.add(snapshot());
        });
      },
      onPause: () => changes?.pause(),
      onResume: () => changes?.resume(),
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<String?> getLastSeenCursor(String boardId) async => _cursors[boardId];

  @override
  Future<void> saveLastSeenCursor(String boardId, String cursor) async {
    _cursors[boardId] = cursor;
  }

  @override
  Future<void> saveLastSyncedAppliedAt(
    String boardId,
    DateTime appliedAt,
  ) async {
    _syncedAt[boardId] = appliedAt;
  }

  /// The board's last synced time (for tests).
  DateTime? lastSyncedAppliedAt(String boardId) => _syncedAt[boardId];
}
