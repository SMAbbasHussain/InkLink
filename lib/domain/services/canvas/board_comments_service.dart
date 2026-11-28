import 'dart:ui';
import '../../models/canvas/canvas_comment.dart';

abstract class BoardCommentsService {
  Stream<List<CanvasComment>> watchComments(String boardId);

  Future<CanvasComment> addComment({
    required String boardId,
    required String text,
    Offset? canvasPosition,
    String? boardTitle,
    List<String>? mentions,
  });

  Future<CanvasCommentReply> addReply({
    required String boardId,
    required String commentId,
    required String text,
    String? boardTitle,
    List<String>? mentions,
  });

  Future<void> deleteComment({
    required String boardId,
    required String commentId,
  });
}
