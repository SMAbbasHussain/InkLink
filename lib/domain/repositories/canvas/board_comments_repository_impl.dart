import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../features/canvas/models/canvas_comment.dart';
import 'board_comments_repository.dart';

class FirestoreBoardCommentsRepository implements BoardCommentsRepository {
  final FirestoreService _firestoreService;

  FirestoreBoardCommentsRepository({
    required FirestoreService firestoreService,
  }) : _firestoreService = firestoreService;

  CollectionReference<Map<String, dynamic>> _commentsRef(String boardId) {
    return _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('comments');
  }

  @override
  Stream<List<CanvasComment>> watchComments(String boardId) {
    return _commentsRef(boardId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CanvasComment.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<void> addComment(CanvasComment comment) async {
    await _commentsRef(comment.boardId).doc(comment.id).set(comment.toMap());
  }

  @override
  Future<void> addReply(
    String boardId,
    String commentId,
    CanvasCommentReply reply,
  ) async {
    await _commentsRef(boardId).doc(commentId).update({
      'replies': FieldValue.arrayUnion([reply.toMap()]),
      'updatedAt': reply.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> deleteComment(String boardId, String commentId) async {
    await _commentsRef(boardId).doc(commentId).delete();
  }
}
