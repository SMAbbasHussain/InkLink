import 'package:isar_community/isar.dart';

import '../../../core/database/collections/local_canvas_sync_state.dart';
import '../../../core/database/collections/local_crdt_update.dart';
import '../../../core/database/local_database_service.dart';
import 'crdt_local_store.dart';

/// The phone store: the Isar queries and transactions the canvas sync
/// repository ran before the store existed, moved here unchanged.
class IsarCrdtLocalStore implements CrdtLocalStore {
  final LocalDatabaseService _localDatabaseService;

  IsarCrdtLocalStore(this._localDatabaseService);

  @override
  Future<void> saveUpdateAndSyncedAt(LocalCrdtUpdate update) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(update);
      final existing = await isar.localCanvasSyncStates.getByBoardId(
        update.boardId,
      );
      await isar.localCanvasSyncStates.putByBoardId(
        (existing ?? LocalCanvasSyncState()
            ..boardId = update.boardId)
          ..lastSyncedAppliedAt = update.appliedAt,
      );
    });
  }

  @override
  Future<void> deleteUpdatesForBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).deleteAll();
    });
  }

  @override
  Future<LocalCrdtUpdate?> getByUpdateId(String updateId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates.getByUpdateId(updateId);
  }

  @override
  Future<void> putUpdate(LocalCrdtUpdate update) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(update);
    });
  }

  @override
  Future<List<LocalCrdtUpdate>> updatesForBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).findAll();
  }

  @override
  Future<List<LocalCrdtUpdate>> updatesForBoardNewestFirst(
    String boardId,
  ) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByAppliedAtDesc()
        .findAll();
  }

  @override
  Future<LocalCrdtUpdate?> latestSyncedUpdate(String boardId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .isSyncedEqualTo(true)
        .sortByAppliedAtDesc()
        .findFirst();
  }

  @override
  Future<LocalCrdtUpdate?> latestUpdate(String boardId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByAppliedAtDesc()
        .findFirst();
  }

  @override
  Future<LocalCrdtUpdate?> highestVersionUpdate(String boardId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByVersionDesc()
        .findFirst();
  }

  @override
  Future<List<LocalCrdtUpdate>> unsyncedUpdatesOldestFirst(
    String boardId,
  ) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .isSyncedEqualTo(false)
        .sortByAppliedAt()
        .findAll();
  }

  @override
  Future<void> deleteSyncedUpdatesAppliedBefore(
    String boardId,
    DateTime cutoff,
  ) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates
          .filter()
          .boardIdEqualTo(boardId)
          .isSyncedEqualTo(true)
          .appliedAtLessThan(cutoff)
          .deleteAll();
    });
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchUpdatesForBoard(String boardId) async* {
    final isar = await _localDatabaseService.database;
    yield* isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByAppliedAt()
        .watch(fireImmediately: true);
  }

  @override
  Future<String?> getLastSeenCursor(String boardId) async {
    final isar = await _localDatabaseService.database;
    final syncState = await isar.localCanvasSyncStates.getByBoardId(boardId);
    return syncState?.lastSeenCursor;
  }

  @override
  Future<void> saveLastSeenCursor(String boardId, String cursor) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      final existing = await isar.localCanvasSyncStates.getByBoardId(boardId);
      await isar.localCanvasSyncStates.putByBoardId(
        (existing ?? LocalCanvasSyncState()
            ..boardId = boardId)
          ..lastSeenCursor = cursor,
      );
    });
  }

  @override
  Future<void> saveLastSyncedAppliedAt(
    String boardId,
    DateTime appliedAt,
  ) async {
    final isar = await _localDatabaseService.database;
    // As before: read outside the transaction, write inside it.
    final existing = await isar.localCanvasSyncStates.getByBoardId(boardId);
    await isar.writeTxn(() async {
      await isar.localCanvasSyncStates.putByBoardId(
        (existing ?? LocalCanvasSyncState()
            ..boardId = boardId)
          ..lastSyncedAppliedAt = appliedAt,
      );
    });
  }
}
