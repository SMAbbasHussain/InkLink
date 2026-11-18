import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/members_tray.dart';
import 'package:inklink/features/canvas/view/widgets/canvas_toolbar.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

class _FakeCanvasService implements CanvasService {
  final _boardController = StreamController<Board?>.broadcast();

  void emitBoard(Board? board) => _boardController.add(board);

  Future<void> dispose() => _boardController.close();

  @override
  bool get canSync => true;

  @override
  String? get currentClientId => 'member-1';

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate({
    required String boardId,
    required String elementId,
  }) async => null;

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) =>
      const Stream.empty();

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) =>
      const Stream.empty();

  @override
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) async {}

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {}

  @override
  Future<bool> retryPendingSync(String boardId) async => true;

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {}

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {}

  @override
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required Uint8List payload,
  }) async {}

  @override
  Stream<Board?> watchBoardById(String boardId) => _boardController.stream;
}

class _FakeBoardService implements BoardService {
  final _membersController = StreamController<List<BoardMember>>.broadcast();

  void emitMembers(List<BoardMember> members) =>
      _membersController.add(members);

  Future<void> dispose() => _membersController.close();

  @override
  Stream<List<BoardMember>> getBoardMembers(String boardId) =>
      _membersController.stream;

  @override
  Future<void> archiveBoard(String boardId) async {}

  @override
  Future<CreateBoardResult> createBoard({
    String? title,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required String inviteTargetRole,
    required List<String> tags,
    bool allowMembersToCopy = false,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteBoard(String boardId) async {}

  @override
  Future<String> duplicateBoard(String boardId, {String? customTitle}) =>
      throw UnimplementedError();

  @override
  Stream<Board?> getBoardById(String boardId) => const Stream.empty();

  @override
  Stream<List<Board>> getJoinedBoards() => const Stream.empty();

  @override
  Stream<List<Board>> getOwnedBoards() => const Stream.empty();

  @override
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) => throw UnimplementedError();

  @override
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) async => const [];

  @override
  Future<void> joinBoard(String boardId) async {}

  @override
  Future<void> leaveBoard(String boardId) async {}

  @override
  Future<void> removeBoardMember(String boardId, String targetUid) async {}

  @override
  Future<void> renameBoard(String boardId, String newName) async {}

  @override
  Future<void> requestBoardAccess({
    required String boardId,
    required String requestType,
    String? message,
  }) async {}

  @override
  Future<void> respondToBoardAccessRequest({
    required String boardId,
    required String requesterUid,
    required String notificationId,
    required String action,
    required String requestType,
  }) async {}

  @override
  Future<SendBoardInviteResult> sendBoardInvite({
    required String boardId,
    required String boardTitle,
    required List<String> invitedUserIds,
    required String targetRole,
    int inviteExpiryHours = 72,
  }) async => const SendBoardInviteResult();

  @override
  Future<void> startBoardsSync() async {}

  @override
  Future<void> stopBoardsSync() async {}

  @override
  Future<void> unarchiveBoard(String boardId) async {}

  @override
  Future<void> updateBoardMemberRole(
    String boardId,
    String targetUid,
    String role,
  ) async {}

  @override
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  }) async {}

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) async {}
}

Board _makeBoard({required String role}) {
  final now = DateTime(2026, 1, 1);
  return Board(
    id: 'board-1',
    title: 'Shared Board',
    ownerId: 'owner-1',
    members: const ['owner-1', 'member-1'],
    currentUserRole: role,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CanvasBloc live member role sync', () {
    test(
      'unlocks editing immediately when promoted from viewer to editor via getBoardMembers even if board doc still reports viewer',
      () async {
        final canvasService = _FakeCanvasService();
        final boardService = _FakeBoardService();
        final crdtAdapter = await CanvasDocAdapterFactory.create();
        final bloc = CanvasBloc(
          canvasService: canvasService,
          boardService: boardService,
          crdtAdapter: crdtAdapter,
          currentUserId: 'member-1',
          boardId: 'board-1',
        );
        addTearDown(() async {
          await bloc.close();
          await canvasService.dispose();
          await boardService.dispose();
        });

        bloc.add(const CanvasInitializeCrdt('board-1'));
        await Future<void>.delayed(Duration.zero);

        canvasService.emitBoard(_makeBoard(role: Board.roleViewer));
        boardService.emitMembers(const [
          BoardMember(uid: 'owner-1', role: Board.roleOwner, status: 'active'),
          BoardMember(
            uid: 'member-1',
            role: Board.roleViewer,
            status: 'active',
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.currentUserRole, Board.roleViewer);
        expect(bloc.state.canEdit, isFalse);

        // Viewer attempt fails with viewer warning.
        bloc.add(const CanvasAddStickyNote(center: Offset(100, 100), text: 'Hi'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.elements, isEmpty);
        expect(bloc.state.error, contains('viewer'));

        // Owner promotes member-1 in MembersTray; members stream updates first
        // while board doc metadata hasn't changed.
        boardService.emitMembers(const [
          BoardMember(uid: 'owner-1', role: Board.roleOwner, status: 'active'),
          BoardMember(
            uid: 'member-1',
            role: Board.roleEditor,
            status: 'active',
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.currentUserRole, Board.roleEditor);
        expect(bloc.state.canEdit, isTrue);

        // Editing now succeeds immediately.
        bloc.add(
          const CanvasAddStickyNote(center: Offset(100, 100), text: 'Promoted'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.elements.length, 1);

        // Demoting back to viewer locks editing again.
        boardService.emitMembers(const [
          BoardMember(uid: 'owner-1', role: Board.roleOwner, status: 'active'),
          BoardMember(
            uid: 'member-1',
            role: Board.roleViewer,
            status: 'active',
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.currentUserRole, Board.roleViewer);
        expect(bloc.state.canEdit, isFalse);
      },
    );

    test('never downgrades the board owner via member list updates', () async {
      final canvasService = _FakeCanvasService();
      final boardService = _FakeBoardService();
      final crdtAdapter = await CanvasDocAdapterFactory.create();
      final bloc = CanvasBloc(
        canvasService: canvasService,
        boardService: boardService,
        crdtAdapter: crdtAdapter,
        currentUserId: 'owner-1',
        boardId: 'board-1',
      );
      addTearDown(() async {
        await bloc.close();
        await canvasService.dispose();
        await boardService.dispose();
      });

      bloc.add(const CanvasInitializeCrdt('board-1'));
      await Future<void>.delayed(Duration.zero);

      canvasService.emitBoard(_makeBoard(role: Board.roleOwner));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.currentUserRole, Board.roleOwner);

      boardService.emitMembers(const [
        BoardMember(uid: 'owner-1', role: Board.roleViewer, status: 'active'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.currentUserRole, Board.roleOwner);
      expect(bloc.state.canEdit, isTrue);
    });
  });

  group('MembersTray & CanvasToolbar live promotion UI', () {
    testWidgets(
      'removes view-only request banner and unlocks tools when promoted to editor',
      (tester) async {
        final canvasService = _FakeCanvasService();
        final boardService = _FakeBoardService();
        final crdtAdapter = await CanvasDocAdapterFactory.create();
        final bloc = CanvasBloc(
          canvasService: canvasService,
          boardService: boardService,
          crdtAdapter: crdtAdapter,
          currentUserId: 'member-1',
          boardId: 'board-1',
        );
        addTearDown(() async {
          await bloc.close();
          await canvasService.dispose();
          await boardService.dispose();
        });

        bloc.add(const CanvasInitializeCrdt('board-1'));
        await tester.pump();
        await tester.pump();

        canvasService.emitBoard(_makeBoard(role: Board.roleViewer));
        boardService.emitMembers(const [
          BoardMember(
            uid: 'owner-1',
            role: Board.roleOwner,
            status: 'active',
            displayName: 'Owner',
          ),
          BoardMember(
            uid: 'member-1',
            role: Board.roleViewer,
            status: 'active',
            displayName: 'Member',
          ),
        ]);
        await tester.pump();
        await tester.pump();

        await tester.pumpWidget(
          MaterialApp(
            theme: InkTheme.light(),
            home: Scaffold(
              body: BlocProvider<CanvasBloc>.value(
                value: bloc,
                child: BlocBuilder<CanvasBloc, CanvasState>(
                  builder: (context, state) {
                    return Stack(
                      children: [
                        const MembersTray(isOpen: true),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: CanvasToolbar(
                            activeTool: state.currentToolMode,
                            canEdit: state.canEdit,
                            onToolSelected: (_) {},
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('You have view-only access.'), findsOneWidget);
        expect(find.text('Request Edit'), findsOneWidget);
        expect(
          tester.widget<CanvasToolbar>(find.byType(CanvasToolbar)).canEdit,
          isFalse,
        );

        // Promote member-1 to editor.
        boardService.emitMembers(const [
          BoardMember(
            uid: 'owner-1',
            role: Board.roleOwner,
            status: 'active',
            displayName: 'Owner',
          ),
          BoardMember(
            uid: 'member-1',
            role: Board.roleEditor,
            status: 'active',
            displayName: 'Member',
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(find.text('You have view-only access.'), findsNothing);
        expect(find.text('Request Edit'), findsNothing);
        expect(
          tester.widget<CanvasToolbar>(find.byType(CanvasToolbar)).canEdit,
          isTrue,
        );
      },
    );
  });
}
