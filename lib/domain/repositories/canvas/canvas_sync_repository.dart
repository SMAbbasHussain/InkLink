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
}
