import '../../../features/canvas/models/canvas_comment.dart';

abstract class BoardCommentsRepository {
  Stream<List<CanvasComment>> watchComments(String boardId);
  Future<void> addComment(CanvasComment comment);
  Future<void> addReply(String boardId, String commentId, CanvasCommentReply reply);
  Future<void> deleteComment(String boardId, String commentId);
}
