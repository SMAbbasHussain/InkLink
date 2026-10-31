import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/repositories/canvas/board_comments_repository.dart';
import 'package:inklink/domain/services/canvas/board_comments_service_impl.dart';
import 'package:inklink/features/canvas/models/canvas_comment.dart';

class FakeBoardCommentsRepository implements BoardCommentsRepository {
  final List<CanvasComment> comments = [];

  @override
  Stream<List<CanvasComment>> watchComments(String boardId) {
    return Stream.value(comments.where((c) => c.boardId == boardId).toList());
  }

  @override
  Future<void> addComment(CanvasComment comment) async {
    comments.add(comment);
  }

  @override
  Future<void> addReply(
    String boardId,
    String commentId,
    CanvasCommentReply reply,
  ) async {
    final idx = comments.indexWhere((c) => c.id == commentId);
    if (idx != -1) {
      final updatedReplies = List<CanvasCommentReply>.from(comments[idx].replies)..add(reply);
      comments[idx] = comments[idx].copyWith(replies: updatedReplies);
    }
  }

  @override
  Future<void> deleteComment(String boardId, String commentId) async {
    comments.removeWhere((c) => c.id == commentId);
  }
}

class FakeAuthService implements AuthService {
  @override
  User? getCurrentUser() => null;

  @override
  String? getCurrentUserId() => 'mock-user-123';

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-token';

  @override
  FirebaseAuth getInstance() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified() async =>
      EmailVerificationStatus.unverified;

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  late FakeBoardCommentsRepository fakeRepo;
  late FakeAuthService fakeAuth;
  late BoardCommentsServiceImpl service;

  setUp(() {
    fakeRepo = FakeBoardCommentsRepository();
    fakeAuth = FakeAuthService();
    service = BoardCommentsServiceImpl(
      repository: fakeRepo,
      authService: fakeAuth,
    );
  });

  group('BoardCommentsServiceImpl', () {
    test('addComment creates and saves comment with extracted mentions', () async {
      final comment = await service.addComment(
        boardId: 'board-test',
        text: 'Review this design @sarah_connor and @john.doe please',
        canvasPosition: const Offset(100, 200),
        boardTitle: 'Design Sprint',
      );

      expect(comment.boardId, 'board-test');
      expect(comment.canvasPosition, const Offset(100, 200));
      expect(comment.mentions, containsAll(['sarah_connor', 'john.doe']));
      expect(fakeRepo.comments.length, 1);
      expect(fakeRepo.comments.first.id, comment.id);
    });

    test('addReply appends reply to comment thread', () async {
      final comment = await service.addComment(
        boardId: 'board-test',
        text: 'Initial question',
      );

      final reply = await service.addReply(
        boardId: 'board-test',
        commentId: comment.id,
        text: 'Here is the answer @mock-user',
      );

      expect(reply.text, 'Here is the answer @mock-user');
      expect(fakeRepo.comments.first.replies.length, 1);
      expect(fakeRepo.comments.first.replies.first.id, reply.id);
    });

    test('deleteComment removes comment from repository', () async {
      final comment = await service.addComment(
        boardId: 'board-test',
        text: 'To be deleted',
      );
      expect(fakeRepo.comments.length, 1);

      await service.deleteComment(
        boardId: 'board-test',
        commentId: comment.id,
      );
      expect(fakeRepo.comments.isEmpty, isTrue);
    });
  });
}
