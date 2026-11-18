import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/friends/friends_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/dashboard/bloc/board_settings_bloc.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/dashboard/view/board_settings_screen.dart';
import 'package:inklink/features/dashboard/view/widgets/invite_expiration_picker.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/ink_button.dart';
import 'package:inklink/ui/widgets/ink_dialog.dart';
import 'package:inklink/ui/widgets/ink_segmented.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _StubAuthBloc extends Cubit<AuthState> implements AuthBloc {
  _StubAuthBloc()
    : super(Authenticated('Owner', uid: 'owner-1', email: 'owner@test.com'));

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubDashboardBloc extends Cubit<DashboardState>
    implements DashboardBloc {
  _StubDashboardBloc()
    : super(DashboardLoaded(ownedBoards: const [], joinedBoards: const []));

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubNotificationsBloc extends Cubit<NotificationsState>
    implements NotificationsBloc {
  _StubNotificationsBloc() : super(NotificationsLoaded(const []));

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBoardService extends Fake implements BoardService {
  final StreamController<Board?> boardController =
      StreamController<Board?>.broadcast(sync: true);
  final StreamController<List<BoardMember>> membersController =
      StreamController<List<BoardMember>>.broadcast(sync: true);

  List<String>? lastInvitedUserIds;
  String? lastTargetRole;
  int? lastInviteExpiryHours;
  bool? lastPausedValue;

  @override
  Stream<Board?> getBoardById(String boardId) => boardController.stream;

  @override
  Stream<List<BoardMember>> getBoardMembers(String boardId) =>
      membersController.stream;

  @override
  Future<SendBoardInviteResult> sendBoardInvite({
    required String boardId,
    required String boardTitle,
    required List<String> invitedUserIds,
    required String targetRole,
    int inviteExpiryHours = 72,
  }) async {
    lastInvitedUserIds = invitedUserIds;
    lastTargetRole = targetRole;
    lastInviteExpiryHours = inviteExpiryHours;
    return const SendBoardInviteResult();
  }

  @override
  Future<void> setBoardPaused(String boardId, {required bool isPaused}) async {
    lastPausedValue = isPaused;
  }

  Future<void> dispose() async {
    await boardController.close();
    await membersController.close();
  }
}

class _FakeFriendsService extends Fake implements FriendsService {
  final StreamController<List<Map<String, dynamic>>> friendsController =
      StreamController<List<Map<String, dynamic>>>.broadcast(sync: true);

  @override
  Stream<List<Map<String, dynamic>>> watchFriends() => friendsController.stream;

  Future<void> dispose() async {
    await friendsController.close();
  }
}

void main() {
  group('InviteExpirationPicker', () {
    testWidgets('supports presets and custom hours/days input with validation', (
      tester,
    ) async {
      var selectedHours = 72;
      var isValid = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return InviteExpirationPicker(
                  valueHours: selectedHours,
                  onChanged: (hours) => setState(() => selectedHours = hours),
                  onValidityChanged: (valid) => setState(() => isValid = valid),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('24 hours'));
      await tester.pump();
      expect(selectedHours, 24);
      expect(isValid, isTrue);

      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(InkSegmented),
          matching: find.text('Hours'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(InkSegmented),
          matching: find.text('Days'),
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();
      expect(selectedHours, 120);
      expect(isValid, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(InkSegmented),
          matching: find.text('Hours'),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      expect(selectedHours, 12);
      expect(isValid, isTrue);

      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(isValid, isFalse);
      expect(find.textContaining('Enter 1 to'), findsOneWidget);
    });
  });

  group('BoardSettingsScreen invite UI & pause toggle', () {
    testWidgets(
      'filters local friends by username, invites friend + non-friend email with custom days timer, and pauses board',
      (tester) async {
        final boardService = _FakeBoardService();
        final friendsService = _FakeFriendsService();
        final authBloc = _StubAuthBloc();
        final dashboardBloc = _StubDashboardBloc();
        final notificationsBloc = _StubNotificationsBloc();
        final settingsBloc = BoardSettingsBloc(
          boardService: boardService,
          friendsService: friendsService,
        );

        final board = Board(
          id: 'board-1',
          title: 'Design Sprint',
          ownerId: 'owner-1',
          members: const ['owner-1', 'existing-member'],
          currentUserRole: Board.roleOwner,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 2),
        );

        addTearDown(() async {
          await settingsBloc.close();
          await authBloc.close();
          await dashboardBloc.close();
          await notificationsBloc.close();
          await boardService.dispose();
          await friendsService.dispose();
        });

        settingsBloc.add(const BoardSettingsStarted('board-1'));

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<DashboardBloc>.value(value: dashboardBloc),
              BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
              BlocProvider<BoardSettingsBloc>.value(value: settingsBloc),
            ],
            child: MaterialApp(
              theme: InkTheme.light(),
              home: BoardSettingsScreen(board: board),
            ),
          ),
        );

        boardService.boardController.add(board);
        boardService.membersController.add(const [
          BoardMember(uid: 'owner-1', role: Board.roleOwner, status: 'active'),
        ]);
        friendsService.friendsController.add(const [
          {
            'uid': 'existing-member',
            'displayName': 'Existing Member',
            'email': 'existing@test.com',
          },
          {
            'uid': 'friend-alice',
            'displayName': 'Alice Designer',
            'email': 'alice@test.com',
          },
          {
            'uid': 'friend-bob',
            'displayName': 'Bob Illustrator',
            'email': 'bob@test.com',
          },
        ]);
        await tester.pump();
        await tester.pump();

        // Open friends dropdown
        final dropdownFinder = find.byKey(
          const ValueKey('board_settings_friends_dropdown_trigger'),
        );
        await tester.scrollUntilVisible(
          dropdownFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(dropdownFinder);
        await tester.pump();

        // Already a member should be hidden; both non-member friends should appear.
        expect(find.text('Existing Member'), findsNothing);
        expect(find.text('Alice Designer'), findsOneWidget);
        expect(find.text('Bob Illustrator'), findsOneWidget);

        // Filter friends by username
        await tester.enterText(
          find.widgetWithText(TextField, 'Filter friends by username...'),
          'ali',
        );
        await tester.pump();
        expect(find.text('Alice Designer'), findsOneWidget);
        expect(find.text('Bob Illustrator'), findsNothing);

        // Select Alice
        await tester.tap(find.text('Alice Designer'));
        await tester.pump();

        // Add non-friend email
        final emailField = find.widgetWithText(
          TextField,
          'Emails (comma, space, or newline separated)',
        );
        await tester.scrollUntilVisible(
          emailField,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(emailField, 'guest@example.com');
        await tester.pump();

        // Pick Editor role and Custom 4 days (= 96 hours)
        await tester.scrollUntilVisible(
          find.text('Custom'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Editor').last);
        await tester.pump();
        await tester.tap(find.text('Custom'));
        await tester.pump();
        final customDurationField = find.widgetWithText(TextField, 'Days');
        await tester.scrollUntilVisible(
          customDurationField,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(customDurationField, '4');
        await tester.pump();

        // Send invites
        await tester.scrollUntilVisible(
          find.text('Send Invites'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Send Invites'));
        await tester.pump();

        expect(
          boardService.lastInvitedUserIds,
          containsAll(<String>['friend-alice', 'guest@example.com']),
        );
        expect(boardService.lastTargetRole, Board.roleEditor);
        expect(boardService.lastInviteExpiryHours, 96);

        // Owner Pause Board toggle
        await tester.scrollUntilVisible(
          find.text('Pause Board'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Pause Board'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No one (including you) will be able to edit'),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(InkDialog),
            matching: find.widgetWithText(InkButton, 'Pause Board'),
          ),
        );
        await tester.pumpAndSettle();

        expect(boardService.lastPausedValue, isTrue);
        expect(find.text('Resume Board'), findsOneWidget);
        expect(find.byIcon(LucideIcons.play), findsOneWidget);
      },
    );
  });
}
