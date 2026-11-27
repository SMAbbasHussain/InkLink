import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/board_comments_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/comments_tray.dart';
import 'package:inklink/features/canvas/view/widgets/comment_mention_picker.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _FakeAuthService implements AuthService {
  @override
  String? getCurrentUserId() => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingCommentsService implements BoardCommentsService {
  final List<({String text, List<String>? mentions})> addedComments = [];
  final List<({String commentId, String text, List<String>? mentions})>
      addedReplies = [];

  @override
  Stream<List<CanvasComment>> watchComments(String boardId) =>
      const Stream.empty();

  @override
  Future<CanvasComment> addComment({
    required String boardId,
    required String text,
    Offset? canvasPosition,
    String? boardTitle,
    List<String>? mentions,
  }) async {
    addedComments.add((text: text, mentions: mentions));
    return CanvasComment(
      id: 'c-1',
      boardId: boardId,
      authorUid: 'me',
      authorName: 'Me',
      text: text,
      createdAt: DateTime.now(),
      mentions: mentions ?? const [],
    );
  }

  @override
  Future<CanvasCommentReply> addReply({
    required String boardId,
    required String commentId,
    required String text,
    String? boardTitle,
    List<String>? mentions,
  }) async {
    addedReplies.add((commentId: commentId, text: text, mentions: mentions));
    return CanvasCommentReply(
      id: 'r-1',
      authorUid: 'me',
      authorName: 'Me',
      text: text,
      createdAt: DateTime.now(),
      mentions: mentions ?? const [],
    );
  }

  @override
  Future<void> deleteComment({
    required String boardId,
    required String commentId,
  }) async {}
}

void main() {
  const members = [
    BoardMember(
      uid: 'me',
      role: 'owner',
      status: 'active',
      displayName: 'Current User',
      email: 'me@example.com',
    ),
    BoardMember(
      uid: 'uid-alice',
      role: 'editor',
      status: 'active',
      displayName: 'Alice Smith',
      email: 'alice@example.com',
    ),
    BoardMember(
      uid: 'uid-bob',
      role: 'viewer',
      status: 'active',
      displayName: 'Bob Jones',
      email: 'bob@example.com',
    ),
  ];

  Widget buildTestHarness(CanvasBloc bloc) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: RepositoryProvider<AuthService>.value(
        value: _FakeAuthService(),
        child: Scaffold(
          body: BlocProvider<CanvasBloc>.value(
            value: bloc,
            child: const Stack(
              children: [CommentsTray()],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('typing @ shows filtered users and only mentions when tile chosen',
      (tester) async {
    final commentsService = _RecordingCommentsService();
    final bloc = CanvasBloc(
      currentUserId: 'me',
      boardId: 'board-1',
      boardCommentsService: commentsService,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(buildTestHarness(bloc));

    bloc.add(const CanvasBoardMembersUpdated(members));
    bloc.add(const CanvasToggleCommentsTray());
    await tester.pumpAndSettle();

    // 1. Typing `@` opens the picker with both Alice and Bob (excluding self)
    final input = find.byType(TextField).first;
    await tester.enterText(input, 'Hey @');
    await tester.pumpAndSettle();

    expect(find.byType(MentionMemberPicker), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Current User'), findsNothing);

    // 2. Typing `@al` filters down to Alice Smith only
    await tester.enterText(input, 'Hey @al');
    await tester.pumpAndSettle();

    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);

    // 3. Tapping the Alice Smith tile inserts @Alice_Smith and records her UID
    await tester.tap(find.text('Alice Smith'));
    await tester.pumpAndSettle();

    expect(find.byType(MentionMemberPicker), findsNothing);
    final controller = tester.widget<TextField>(input).controller!;
    expect(controller.text, 'Hey @Alice_Smith ');

    // Submit via send button
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(commentsService.addedComments.length, 1);
    expect(commentsService.addedComments.first.text, 'Hey @Alice_Smith');
    expect(commentsService.addedComments.first.mentions, ['uid-alice']);

    // 4. Typing @Bob_Jones manually WITHOUT tapping the tile produces empty mentions
    await tester.enterText(input, 'Ping @Bob_Jones without selecting');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(commentsService.addedComments.length, 2);
    expect(commentsService.addedComments.last.mentions, isEmpty);
  });

  testWidgets('deleting a chosen @mention before send removes it from mentions',
      (tester) async {
    final commentsService = _RecordingCommentsService();
    final bloc = CanvasBloc(
      currentUserId: 'me',
      boardId: 'board-1',
      boardCommentsService: commentsService,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(buildTestHarness(bloc));

    bloc.add(const CanvasBoardMembersUpdated(members));
    bloc.add(const CanvasToggleCommentsTray());
    await tester.pumpAndSettle();

    final input = find.byType(TextField).first;
    await tester.enterText(input, '@al');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice Smith'));
    await tester.pumpAndSettle();

    // User removes @Alice_Smith before sending
    await tester.enterText(input, 'Never mind');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(commentsService.addedComments.length, 1);
    expect(commentsService.addedComments.first.mentions, isEmpty);
  });
}
