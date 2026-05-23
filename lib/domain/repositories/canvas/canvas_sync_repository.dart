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
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required String payloadBase64,
    required String sourceClientId,
  });
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId);
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
    bool preferSocket = true,
  });
  Stream<List<LocalCrdtUpdate>> watchRemoteCanvasPreviews(String boardId);
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

  /// Send an explicit logout handshake to the server which clears server-side queues.
  Future<void> logoutSocket();

  /// Disconnect WebSocket locally. Server will NOT clear user queues on simple
  /// disconnects; queues are preserved until an explicit `logout` is received.
  Future<void> disconnectSocket();
}
