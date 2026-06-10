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
  Future<String?> getLastSeenCursor(String boardId);

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
    String? lastSeenCursor,
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

  /// Mark the current board as single-user so CRDT updates carry a server-side
  /// flag that skips broadcasting and offline queuing.
  void setBoardSingleUserStatus(bool isSingleUser);

  /// Sync all pending local CRDT updates via socket.
  /// Returns true if all updates were acknowledged.
  Future<bool> batchSyncPendingUpdates(String boardId, String userId);

  /// Persist the sync cursor for [boardId] based on the latest local update so
  /// that the next sync can resume from where the user left off.
  Future<void> persistCursorForBoard(String boardId);

  /// Send an explicit logout handshake to the server which clears cursor tracking.
  Future<void> logoutSocket();

  /// Disconnect WebSocket locally. Server will preserve cursor tracking until
  /// an explicit `logout` is received.
  Future<void> disconnectSocket();
}
