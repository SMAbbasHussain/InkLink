import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../models/history/board_activity_block.dart';
import '../../models/history/undo_request.dart';
import 'board_history_repository.dart';

class BoardHistoryRepositoryImpl implements BoardHistoryRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  BoardHistoryRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
  }) : _firestoreService = firestoreService,
       _authService = authService;

  @override
  Stream<List<BoardActivityBlock>> watchActivityFeed(
    String boardId, {
    int limit = 50,
  }) {
    if (boardId.trim().isEmpty) {
      return Stream.value(const <BoardActivityBlock>[]);
    }
    return _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('activity_index')
        .orderBy('fromVersion', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => BoardActivityBlock.fromMap({
                  'blockId': doc.id,
                  ...doc.data(),
                }),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<List<UndoRequest>> watchUndoRequests(String boardId) {
    if (boardId.trim().isEmpty) {
      return Stream.value(const <UndoRequest>[]);
    }
    return _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('undo_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UndoRequest.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<UndoRequest>> watchMyUndoRequests(String boardId, String uid) {
    if (boardId.trim().isEmpty || uid.trim().isEmpty) {
      return Stream.value(const <UndoRequest>[]);
    }
    if (_authService.getCurrentUserId() != uid) {
      return Stream.value(const <UndoRequest>[]);
    }
    // No orderBy here on purpose: equality filter + orderBy on another field
    // needs a composite index. Sort the (small) result client-side instead.
    return _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('undo_requests')
        .where('requesterUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => UndoRequest.fromMap(doc.id, doc.data()))
          .toList(growable: false);
      return requests
        ..sort((a, b) {
          final aAt = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bAt = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bAt.compareTo(aAt);
        });
    });
  }
}
