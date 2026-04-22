import '../../../core/database/collections/local_crdt_update.dart';

abstract class CanvasSyncRepository {
  String? get currentUserId;

  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update);
  Future<void> markCrdtUpdateSynced(String updateId);
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId);
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(String boardId);
  Stream<List<LocalCrdtUpdate>> watchLocalCrdtUpdates(String boardId);
  Stream<List<LocalCrdtUpdate>> watchRemoteCrdtUpdates(String boardId);
  Future<void> writeRemoteCrdtUpdate({
    required String boardId,
    required String updateId,
    required String payloadBase64,
    required String sourceClientId,
  });
}
