import '../../../core/database/collections/local_crdt_update.dart';

abstract class CanvasSyncRepository {
  String? get currentUserId;

  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update);
  Future<void> clearLocalCrdtUpdatesForBoard(String boardId);
  Future<void> markCrdtUpdateSynced(String updateId);
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted);
  Future<LocalCrdtUpdate?> getElementCrdtUpdate(
    String boardId,
    String elementId,
  );
  Future<DateTime?> getLatestLocalCrdtUpdateAt(String boardId);
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required String payloadBase64,
  });
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId);
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
    bool preferSocket = true,
  });
  Stream<List<LocalCrdtUpdate>> watchLocalCrdtUpdates(String boardId);
  Stream<List<LocalCrdtUpdate>> watchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
  });
  Future<void> writeRemoteCrdtUpdate({
    required String boardId,
    required String updateId,
    required String payloadBase64,
    required String sourceClientId,
    String? elementId,
  });

  /// Sync all pending local CRDT updates in a single Firestore batch.
  /// Returns true if the batch succeeded.
  Future<bool> batchSyncPendingUpdates(String boardId, String userId);

  /// Disconnect WebSocket on logout.
  /// Server will clear Redis queues for this user automatically on disconnect.
  Future<void> disconnectSocket();
}
