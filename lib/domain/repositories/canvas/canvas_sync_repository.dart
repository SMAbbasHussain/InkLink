import '../../../core/database/collections/local_crdt_update.dart';

abstract class CanvasSyncRepository {
  String? get currentUserId;

  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required List<int> payload,
  });

  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId);
  Future<void> hydrateCrdtUpdates(String boardId);
  void startCrdtRemoteSync(String boardId);
  Future<void> stopCrdtRemoteSync(String boardId);
}
