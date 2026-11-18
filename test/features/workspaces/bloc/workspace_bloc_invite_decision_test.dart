import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/models/workspace.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/domain/services/workspace/workspace_service.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/features/workspaces/bloc/workspace_bloc.dart';
import 'package:inklink/features/workspaces/view/workspace_invites_screen.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWorkspaceService extends Fake implements WorkspaceService {
  Object? failure;
  int acceptCallCount = 0;
  int rejectCallCount = 0;
  Completer<void>? pendingDecision;
  final invitesController =
      StreamController<List<WorkspaceInvite>>.broadcast();

  @override
  Future<void> startWorkspacSync() async {}

  @override
  Future<void> stopWorkspacSync() async {
    await invitesController.close();
  }

  @override
  Stream<List<Workspace>> getOwnedWorkspaces() => const Stream.empty();

  @override
  Stream<List<Workspace>> getMemberWorkspaces() => const Stream.empty();

  @override
  Stream<List<WorkspaceInvite>> getIncomingWorkspaceInvites() =>
      invitesController.stream;

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) async {
    acceptCallCount++;
    if (pendingDecision != null) {
      await pendingDecision!.future;
    }
    if (failure != null) throw failure!;
  }

  @override
  Future<void> rejectWorkspaceInvite(String inviteId) async {
    rejectCallCount++;
    if (pendingDecision != null) {
      await pendingDecision!.future;
    }
    if (failure != null) throw failure!;
  }
}

class _FakeNotificationService implements NotificationService {
  @override
  Future<void> deleteNotification(String notificationId) async {}

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() =>
      const Stream.empty();
}

void main() {
  test(
    'accept reports success only after the workspace call completes',
    () async {
      final service = _FakeWorkspaceService();
      final bloc = WorkspaceBloc(workspaceService: service);
      addTearDown(bloc.close);
      final result = Completer<(bool, String?)>();

      bloc.add(
        AcceptWorkspaceInviteRequested(
          'invite-1',
          onCompleted: (success, error) => result.complete((success, error)),
        ),
      );

      final (success, error) = await result.future.timeout(
        const Duration(seconds: 2),
      );
      expect(success, isTrue);
      expect(error, isNull);
    },
  );

  test('accept reports a failure that leaves the invite unresolved', () async {
    final service = _FakeWorkspaceService()
      ..failure = Exception('invite is no longer pending');
    final bloc = WorkspaceBloc(workspaceService: service);
    addTearDown(bloc.close);
    final result = Completer<(bool, String?)>();

    bloc.add(
      AcceptWorkspaceInviteRequested(
        'invite-1',
        onCompleted: (success, error) => result.complete((success, error)),
      ),
    );

    final (success, error) = await result.future.timeout(
      const Duration(seconds: 2),
    );
    expect(success, isFalse);
    expect(error, contains('no longer pending'));
  });

  test('reject reports success after the workspace call completes', () async {
    final service = _FakeWorkspaceService();
    final bloc = WorkspaceBloc(workspaceService: service);
    addTearDown(bloc.close);
    final result = Completer<(bool, String?)>();

    bloc.add(
      RejectWorkspaceInviteRequested(
        'invite-1',
        onCompleted: (success, error) => result.complete((success, error)),
      ),
    );

    final (success, error) = await result.future.timeout(
      const Duration(seconds: 2),
    );
    expect(success, isTrue);
    expect(error, isNull);
  });

  test('rapid duplicate accept/reject events only call backend once', () async {
    final gate = Completer<void>();
    final service = _FakeWorkspaceService()..pendingDecision = gate;
    final bloc = WorkspaceBloc(workspaceService: service);
    addTearDown(bloc.close);

    final firstDone = Completer<bool>();
    bloc.add(
      AcceptWorkspaceInviteRequested(
        'invite-1',
        onCompleted: (ok, _) => firstDone.complete(ok),
      ),
    );
    // Second rapid dispatch while first is still in flight should be silently ignored.
    bloc.add(AcceptWorkspaceInviteRequested('invite-1'));
    bloc.add(RejectWorkspaceInviteRequested('invite-1'));

    await Future<void>.delayed(Duration.zero);
    expect(service.acceptCallCount, 1);
    expect(service.rejectCallCount, 0);

    gate.complete();
    expect(await firstDone.future, isTrue);
    expect(service.acceptCallCount, 1);
    expect(service.rejectCallCount, 0);
  });

  testWidgets(
    'WorkspaceInvitesScreen clears loading state before showing success snackbar and ignores rapid double taps',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<void>();
      final service = _FakeWorkspaceService()..pendingDecision = gate;
      final workspaceBloc = WorkspaceBloc(workspaceService: service);
      final notificationsBloc = NotificationsBloc(
        notificationService: _FakeNotificationService(),
        notificationPreferences: NotificationPreferences(prefs: prefs),
      );
      addTearDown(() async {
        await workspaceBloc.close();
        await notificationsBloc.close();
      });

      workspaceBloc.add(LoadWorkspacesRequested());
      await tester.pump();

      service.invitesController.add([
        WorkspaceInvite(
          id: 'invite-1',
          workspaceId: 'ws-1',
          fromUid: 'owner-1',
          toUid: 'me-1',
          senderName: 'Alice',
          workspaceName: 'Design Studio',
          status: 'pending',
          timestamp: DateTime(2026, 1, 1),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WorkspaceBloc>.value(value: workspaceBloc),
            BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
          ],
          child: MaterialApp(
            theme: InkTheme.light(),
            home: const WorkspaceInvitesScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Accept'), findsOneWidget);

      // Tap twice rapidly before the first frame finishes.
      await tester.tap(find.text('Accept'));
      await tester.tap(find.text('Accept'), warnIfMissed: false);
      await tester.pump();

      expect(service.acceptCallCount, 1);
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.text('Invite accepted.'), findsNothing);

      // Complete backend request.
      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('Invite accepted.'), findsOneWidget);
      expect(find.text('Processing...'), findsNothing);
      expect(find.text('No pending invitations'), findsOneWidget);
      expect(service.acceptCallCount, 1);
    },
  );
}
