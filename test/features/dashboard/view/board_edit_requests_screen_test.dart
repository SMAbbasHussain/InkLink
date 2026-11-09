import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/features/dashboard/view/board_edit_requests_screen.dart';
import 'package:inklink/features/dashboard/view/widgets/board_card.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MockNotificationsBloc
    extends Bloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {
  MockNotificationsBloc(super.initialState) {
    on<NotificationsEvent>((event, emit) {});
  }

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBoardService implements BoardService {
  String? lastAction;
  String? lastRequesterUid;
  String? lastBoardId;

  @override
  Future<void> respondToBoardAccessRequest({
    required String boardId,
    required String requesterUid,
    required String notificationId,
    required String action,
    required String requestType,
  }) async {
    lastBoardId = boardId;
    lastRequesterUid = requesterUid;
    lastAction = action;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildTestWidget({
    required Widget child,
    required NotificationsBloc notificationsBloc,
    required BoardService boardService,
  }) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BoardService>.value(value: boardService),
      ],
      child: BlocProvider<NotificationsBloc>.value(
        value: notificationsBloc,
        child: MaterialApp(
          theme: InkTheme.light(),
          home: child,
        ),
      ),
    );
  }

  group('BoardEditRequestsScreen', () {
    testWidgets('renders pending requests and filters by username', (tester) async {
      final fakeBoardService = FakeBoardService();
      final mockNotifBloc = MockNotificationsBloc(
        const NotificationsLoaded(
          [
            {
              'id': 'notif_1',
              'type': 'board_edit_request',
              'status': 'pending',
              'targetId': 'board_1',
              'senderName': 'fahad',
              'extraData': {
                'boardId': 'board_1',
                'requesterUid': 'u_fahad',
                'requesterName': 'Fahad Basra',
                'message': 'Need edit access for styling',
                'requestType': 'edit',
              },
            },
            {
              'id': 'notif_2',
              'type': 'board_edit_request',
              'status': 'pending',
              'targetId': 'board_1',
              'senderName': 'abbas',
              'extraData': {
                'boardId': 'board_1',
                'requesterUid': 'u_abbas',
                'requesterName': 'Abbas Hussain',
                'message': 'Ready to draw diagram',
                'requestType': 'edit',
              },
            },
          ],
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const BoardEditRequestsScreen(
            boardId: 'board_1',
            boardTitle: 'Test Board',
          ),
          notificationsBloc: mockNotifBloc,
          boardService: fakeBoardService,
        ),
      );
      await tester.pumpAndSettle();

      // Both requesters should be visible initially
      expect(find.text('Fahad Basra'), findsOneWidget);
      expect(find.text('Abbas Hussain'), findsOneWidget);
      expect(find.text('Need edit access for styling'), findsOneWidget);
      expect(find.text('Grant Edit Access'), findsNWidgets(2));

      // Filter by username "abbas"
      await tester.enterText(
        find.byType(TextField).first,
        'abbas',
      );
      await tester.pumpAndSettle();

      // Only Abbas should remain visible
      expect(find.text('Abbas Hussain'), findsOneWidget);
      expect(find.text('Fahad Basra'), findsNothing);

      // Filter with no match
      await tester.enterText(
        find.byType(TextField).first,
        'nonexistent_user',
      );
      await tester.pumpAndSettle();

      expect(find.text('No requests matching "nonexistent_user"'), findsOneWidget);
    });

    testWidgets('approving request calls BoardService.respondToBoardAccessRequest', (tester) async {
      final fakeBoardService = FakeBoardService();
      final mockNotifBloc = MockNotificationsBloc(
        const NotificationsLoaded(
          [
            {
              'id': 'notif_1',
              'type': 'board_edit_request',
              'status': 'pending',
              'targetId': 'board_1',
              'senderName': 'sam',
              'extraData': {
                'boardId': 'board_1',
                'requesterUid': 'u_sam',
                'requesterName': 'Sam Altman',
                'message': 'Grant edit please',
                'requestType': 'edit',
              },
            },
          ],
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const BoardEditRequestsScreen(
            boardId: 'board_1',
            boardTitle: 'Test Board',
          ),
          notificationsBloc: mockNotifBloc,
          boardService: fakeBoardService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sam Altman'), findsOneWidget);

      // Tap Grant Edit Access
      await tester.tap(find.text('Grant Edit Access'));
      await tester.pumpAndSettle();

      expect(fakeBoardService.lastBoardId, equals('board_1'));
      expect(fakeBoardService.lastRequesterUid, equals('u_sam'));
      expect(fakeBoardService.lastAction, equals('accept'));
    });
  });

  group('BoardCard Indicator', () {
    testWidgets('shows indicator badge when pendingRequestsCount > 0', (tester) async {
      final board = Board(
        id: 'board_test',
        title: 'Indicator Board',
        ownerId: 'owner_1',
        members: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: BoardCard(
              board: board,
              isOwner: true,
              pendingRequestsCount: 3,
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge count should be rendered
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(LucideIcons.userCheck), findsOneWidget);
    });

    testWidgets('hides indicator badge when pendingRequestsCount is 0', (tester) async {
      final board = Board(
        id: 'board_test',
        title: 'Indicator Board',
        ownerId: 'owner_1',
        members: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: BoardCard(
              board: board,
              isOwner: true,
              pendingRequestsCount: 0,
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.userCheck), findsNothing);
    });
  });
}
