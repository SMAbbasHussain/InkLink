import '../../models/canvas/crdt_update.dart';

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
    bool ignoreCursor = false,
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
    String action = 'upsert',
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

  /// Pre-joins the socket room for [boardId] and arms inbound buffering so no
  /// live broadcast updates are missed while initial hydration/history fetch is running.
  /// Returns the current server version at the moment of join, if available.
  Future<int?> preWatchBoard(String boardId);

  /// Fetches specific missing CRDT updates from the server by version range or version list.
  Future<List<LocalCrdtUpdate>> fetchMissingCrdtUpdates({
    required String boardId,
    int? fromVersion,
    int? toVersion,
    int? sinceVersion,
    List<int>? missingVersions,
  });

  /// Broadcasts a request to online peers in [boardId] for missing CRDT updates.
  void requestPeerCrdtUpdates({
    required String boardId,
    int? fromVersion,
    int? toVersion,
    List<int>? missingVersions,
  });

  /// Relays local CRDT updates to a peer who requested them.
  void relayPeerCrdtUpdates({
    required String boardId,
    required List<LocalCrdtUpdate> updates,
    String? targetUid,
  });

  /// Stream of CRDT updates received directly from peers.
  Stream<List<LocalCrdtUpdate>> watchPeerCrdtUpdates(String boardId);

  /// Send an explicit logout handshake to the server which clears cursor tracking.
  Future<void> logoutSocket();

  /// Disconnect WebSocket locally. Server will preserve cursor tracking until
  /// an explicit `logout` is received.
  Future<void> disconnectSocket();
}
