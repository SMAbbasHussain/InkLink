import 'dart:developer' as developer;
import 'dart:ui';

import 'package:uuid/uuid.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../models/canvas/canvas_comment.dart';
import '../../repositories/canvas/board_comments_repository.dart';
import 'board_comments_service.dart';

class BoardCommentsServiceImpl implements BoardCommentsService {
  final BoardCommentsRepository _repository;
  final AuthService _authService;
  final CloudFunctionsService? _cloudFunctionsService;
  final Uuid _uuid = const Uuid();

  BoardCommentsServiceImpl({
    required this._repository,
    required this._authService,
    this._cloudFunctionsService,
  });

  @override
  Stream<List<CanvasComment>> watchComments(String boardId) {
    return _repository.watchComments(boardId);
  }

  @override
  Future<CanvasComment> addComment({
    required String boardId,
    required String text,
    Offset? canvasPosition,
    String? boardTitle,
    List<String>? mentions,
  }) async {
    final user = _authService.getCurrentUser();
    final authorUid = user?.uid ?? 'anonymous';
    final authorName = user?.displayName ?? 'Anonymous';
    final authorPhotoUrl = user?.photoURL;

    final commentId = _uuid.v4();
    final resolvedMentions = mentions != null
        ? mentions.toSet().toList()
        : _extractMentions(text);

    final comment = CanvasComment(
      id: commentId,
      boardId: boardId,
      canvasPosition: canvasPosition,
      authorUid: authorUid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      text: text,
      createdAt: DateTime.now(),
      mentions: resolvedMentions,
    );

    await _repository.addComment(comment);

    if (resolvedMentions.isNotEmpty && _cloudFunctionsService != null) {
      _dispatchMentionNotification(
        boardId: boardId,
        boardTitle: boardTitle,
        commentId: commentId,
        commentText: text,
        senderName: authorName,
        senderPhotoUrl: authorPhotoUrl,
        mentionedUids: mentions != null ? resolvedMentions : null,
      );
    }

    return comment;
  }

  @override
  Future<CanvasCommentReply> addReply({
    required String boardId,
    required String commentId,
    required String text,
    String? boardTitle,
    List<String>? mentions,
  }) async {
    final user = _authService.getCurrentUser();
    final authorUid = user?.uid ?? 'anonymous';
    final authorName = user?.displayName ?? 'Anonymous';
    final authorPhotoUrl = user?.photoURL;

    final replyId = _uuid.v4();
    final resolvedMentions = mentions != null
        ? mentions.toSet().toList()
        : _extractMentions(text);

    final reply = CanvasCommentReply(
      id: replyId,
      authorUid: authorUid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      text: text,
      createdAt: DateTime.now(),
      mentions: resolvedMentions,
    );

    await _repository.addReply(boardId, commentId, reply);

    if (resolvedMentions.isNotEmpty && _cloudFunctionsService != null) {
      _dispatchMentionNotification(
        boardId: boardId,
        boardTitle: boardTitle,
        commentId: commentId,
        commentText: text,
        senderName: authorName,
        senderPhotoUrl: authorPhotoUrl,
        mentionedUids: mentions != null ? resolvedMentions : null,
      );
    }

    return reply;
  }

  @override
  Future<void> deleteComment({
    required String boardId,
    required String commentId,
  }) async {
    await _repository.deleteComment(boardId, commentId);
  }

  List<String> _extractMentions(String text) {
    final exp = RegExp(r'@([a-zA-Z0-9_\.\-]+)');
    final matches = exp.allMatches(text);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  void _dispatchMentionNotification({
    required String boardId,
    String? boardTitle,
    required String commentId,
    required String commentText,
    required String senderName,
    String? senderPhotoUrl,
    List<String>? mentionedUids,
  }) async {
    // Non-blocking fire-and-forget call to Cloud Function
    try {
      await _cloudFunctionsService?.httpsCallable('sendCommentMention').call({
        'boardId': boardId,
        'boardTitle': boardTitle ?? 'Whiteboard',
        'commentId': commentId,
        'commentText': commentText,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        if (mentionedUids != null) 'mentionedUids': mentionedUids,
      });
    } catch (err) {
      developer.log(
        'Failed to dispatch mention notification: $err',
        name: 'BoardCommentsService',
      );
    }
  }
}
