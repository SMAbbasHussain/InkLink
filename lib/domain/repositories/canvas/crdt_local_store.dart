import '../../models/canvas/crdt_update.dart';

/// Local persistence used by the canvas sync repository.
///
/// Each method is one storage step the sync repository already performed
/// against Isar. Phones use [IsarCrdtLocalStore] (the same queries and
/// transactions as before); the web uses [MemoryCrdtLocalStore]
/// (online-only, cleared on page reload).
abstract class CrdtLocalStore {
  /// Puts [update] (replacing one with the same `updateId`) and records its
  /// `appliedAt` as the board's last synced time, in one transaction.
  Future<void> saveUpdateAndSyncedAt(LocalCrdtUpdate update);

  /// Deletes every update of [boardId].
  Future<void> deleteUpdatesForBoard(String boardId);

  /// The update with [updateId], or null.
  Future<LocalCrdtUpdate?> getByUpdateId(String updateId);

  /// Puts [update], replacing one with the same `updateId`.
  Future<void> putUpdate(LocalCrdtUpdate update);

  /// Every update of [boardId] (storage order).
  Future<List<LocalCrdtUpdate>> updatesForBoard(String boardId);

  /// Every update of [boardId], newest `appliedAt` first.
  Future<List<LocalCrdtUpdate>> updatesForBoardNewestFirst(String boardId);

  /// The synced update of [boardId] with the newest `appliedAt`.
  Future<LocalCrdtUpdate?> latestSyncedUpdate(String boardId);

  /// The update of [boardId] with the newest `appliedAt`.
  Future<LocalCrdtUpdate?> latestUpdate(String boardId);

  /// The update of [boardId] with the highest `version`.
  Future<LocalCrdtUpdate?> highestVersionUpdate(String boardId);

  /// Unsynced updates of [boardId], oldest `appliedAt` first.
  Future<List<LocalCrdtUpdate>> unsyncedUpdatesOldestFirst(String boardId);

  /// Deletes synced updates of [boardId] applied before [cutoff].
  Future<void> deleteSyncedUpdatesAppliedBefore(
    String boardId,
    DateTime cutoff,
  );

  /// Updates of [boardId], oldest `appliedAt` first; emits now and after
  /// every change.
  Stream<List<LocalCrdtUpdate>> watchUpdatesForBoard(String boardId);

  /// The board's stored server cursor, or null.
  Future<String?> getLastSeenCursor(String boardId);

  /// Stores the board's server cursor.
  Future<void> saveLastSeenCursor(String boardId, String cursor);

  /// Stores the board's last synced time.
  Future<void> saveLastSyncedAppliedAt(String boardId, DateTime appliedAt);
}
