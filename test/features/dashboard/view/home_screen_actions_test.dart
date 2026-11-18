import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/invitation/invitation_service.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/board_invitations/bloc/board_invitations_bloc.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/dashboard/view/home_screen.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/command_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthBloc extends Cubit<AuthState> implements AuthBloc {
  _StubAuthBloc()
    : super(Authenticated('Owner', uid: 'owner-1', email: 'owner@test.com'));

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubDashboardBloc extends Cubit<DashboardState> implements DashboardBloc {
  _StubDashboardBloc()
    : super(DashboardLoaded(ownedBoards: const [], joinedBoards: const []));

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeInvitationService extends Fake implements InvitationService {
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  Stream<List<Map<String, dynamic>>> watchPendingInvites() => controller.stream;

  @override
  Future<bool> isOnline() async => true;
}

class _FakeNotificationService implements NotificationService {
  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() => controller.stream;

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

void main() {
  testWidgets(
    'HomeScreen keeps only top Explore button and removes theme toggle and bottom Explore button',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      final authBloc = _StubAuthBloc();
      final dashboardBloc = _StubDashboardBloc();
      final invitationService = _FakeInvitationService();
      final notificationService = _FakeNotificationService();
      final boardInvitesBloc = BoardInvitationsBloc(
        invitationService: invitationService,
      );
      final notificationsBloc = NotificationsBloc(
        notificationService: notificationService,
        notificationPreferences: NotificationPreferences(prefs: prefs!),
      );

      addTearDown(() async {
        await authBloc.close();
        await dashboardBloc.close();
        await boardInvitesBloc.close();
        await notificationsBloc.close();
        await invitationService.controller.close();
        await notificationService.controller.close();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<DashboardBloc>.value(value: dashboardBloc),
            BlocProvider<BoardInvitationsBloc>.value(value: boardInvitesBloc),
            BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
          ],
          child: MaterialApp(
            theme: InkTheme.light(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('Explore Public Boards'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CommandBar),
          matching: find.byTooltip('Explore Public Boards'),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Switch to light mode'), findsNothing);
      expect(find.byTooltip('Switch to dark mode'), findsNothing);
    },
  );
}
