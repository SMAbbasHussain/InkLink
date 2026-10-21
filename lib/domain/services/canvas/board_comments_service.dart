import 'dart:ui';
import '../../../features/canvas/models/canvas_comment.dart';

abstract class BoardCommentsService {
  Stream<List<CanvasComment>> watchComments(String boardId);

  Future<CanvasComment> addComment({
    required String boardId,
    required String text,
    Offset? canvasPosition,
    String? boardTitle,
  });

  Future<CanvasCommentReply> addReply({
    required String boardId,
    required String commentId,
    required String text,
    String? boardTitle,
  });

  Future<void> deleteComment({
    required String boardId,
    required String commentId,
  });
}
