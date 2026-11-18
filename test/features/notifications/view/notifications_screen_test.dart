import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/invitation/invitation_service.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/domain/services/workspace/workspace_service.dart';
import 'package:inklink/features/board_invitations/bloc/board_invitations_bloc.dart';
import 'package:inklink/features/friends/bloc/friends_bloc.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/features/notifications/view/notifications_screen.dart';
import 'package:inklink/features/workspaces/bloc/workspace_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService implements NotificationService {
  final controller =
      StreamController<List<Map<String, dynamic>>>.broadcast(sync: true);

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() => controller.stream;

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

class _FakeBoardService extends Fake implements BoardService {}

class _FakeInvitationService extends Fake implements InvitationService {
  final controller =
      StreamController<List<Map<String, dynamic>>>.broadcast(sync: true);

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() => controller.stream;

  @override
  Future<bool> isOnline() async => true;
}

class _FakeWorkspaceService extends Fake implements WorkspaceService {
  @override
  Future<void> stopWorkspacSync() async {}
}

class _StubFriendsBloc extends Cubit<FriendsState> implements FriendsBloc {
  _StubFriendsBloc() : super(FriendsInitial());

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
    'NotificationsScreen renders actionable items cleanly without Set<String> errors',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      final notificationService = _FakeNotificationService();
      final invitationService = _FakeInvitationService();
      final notificationsBloc = NotificationsBloc(
        notificationService: notificationService,
        notificationPreferences: NotificationPreferences(prefs: prefs!),
        boardService: _FakeBoardService(),
      );
      final boardInvitesBloc = BoardInvitationsBloc(
        invitationService: invitationService,
      );
      final workspaceBloc = WorkspaceBloc(
        workspaceService: _FakeWorkspaceService(),
      );
      final friendsBloc = _StubFriendsBloc();

      addTearDown(() async {
        await notificationsBloc.close();
        await boardInvitesBloc.close();
        await workspaceBloc.close();
        await friendsBloc.close();
        await notificationService.controller.close();
        await invitationService.controller.close();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
            BlocProvider<BoardInvitationsBloc>.value(value: boardInvitesBloc),
            BlocProvider<WorkspaceBloc>.value(value: workspaceBloc),
            BlocProvider<FriendsBloc>.value(value: friendsBloc),
          ],
          child: MaterialApp(
            theme: InkTheme.light(),
            home: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pump();

      notificationService.controller.add([
        {
          'id': 'n-ws-1',
          'type': 'workspace_invite',
          'status': 'pending',
          'senderName': 'Alice',
          'title': 'Workspace Invite',
          'body': 'Join Design Team',
          'targetId': 'ws-1_u2',
          'extraData': {'inviteId': 'ws-1_u2', 'workspaceId': 'ws-1'},
        },
        {
          'id': 'n-board-1',
          'type': 'board_invite',
          'status': 'pending',
          'senderName': 'Bob',
          'title': 'Board Invite',
          'body': 'Join Board',
          'targetId': 'b-1_u2',
          'extraData': {'inviteId': 'b-1_u2', 'boardId': 'b-1'},
        },
      ]);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Workspace Invite'), findsOneWidget);
      expect(find.text('Board Invite'), findsOneWidget);
    },
  );
}
