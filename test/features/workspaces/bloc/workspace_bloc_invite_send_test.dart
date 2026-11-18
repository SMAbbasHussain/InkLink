import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/workspace.dart';
import 'package:inklink/domain/services/workspace/workspace_service.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/friends/bloc/friends_bloc.dart';
import 'package:inklink/features/workspaces/bloc/workspace_bloc.dart';
import 'package:inklink/features/workspaces/view/workspace_settings_screen.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

class _FakeWorkspaceService extends Fake implements WorkspaceService {
  final ownedController = StreamController<List<Workspace>>.broadcast(sync: true);
  final memberWorkspacesController =
      StreamController<List<Workspace>>.broadcast(sync: true);
  final incomingController =
      StreamController<List<WorkspaceInvite>>.broadcast(sync: true);
  final membersController =
      StreamController<List<WorkspaceMember>>.broadcast(sync: true);
  final pendingSentController =
      StreamController<Set<String>>.broadcast(sync: true);

  int inviteCalls = 0;
  final List<List<String>> invitedBatches = [];
  Completer<void>? inviteGate;

  @override
  Future<void> startWorkspacSync() async {}

  @override
  Future<void> stopWorkspacSync() async {}

  @override
  Stream<List<Workspace>> getOwnedWorkspaces() => ownedController.stream;

  @override
  Stream<List<Workspace>> getMemberWorkspaces() =>
      memberWorkspacesController.stream;

  @override
  Stream<List<WorkspaceInvite>> getIncomingWorkspaceInvites() =>
      incomingController.stream;

  @override
  Stream<List<Board>> getWorkspaceBoards(String workspaceId, {int? limit}) =>
      const Stream.empty();

  @override
  Stream<List<WorkspaceMember>> getWorkspaceMembers(String workspaceId) =>
      membersController.stream;

  @override
  Stream<Set<String>> getPendingSentWorkspaceInviteUserIds(
    String workspaceId,
  ) => pendingSentController.stream;

  @override
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> invitedUserIds,
  }) async {
    inviteCalls++;
    invitedBatches.add(List<String>.from(invitedUserIds));
    if (inviteGate != null) {
      await inviteGate!.future;
    }
  }

  Future<void> dispose() async {
    await ownedController.close();
    await memberWorkspacesController.close();
    await incomingController.close();
    await membersController.close();
    await pendingSentController.close();
  }
}

class _StubAuthBloc extends Cubit<AuthState> implements AuthBloc {
  _StubAuthBloc()
    : super(
        Authenticated('Owner', uid: 'owner-1', email: 'owner@test.com'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubFriendsBloc extends Cubit<FriendsState> implements FriendsBloc {
  _StubFriendsBloc()
    : super(
        FriendsLoaded(
          friends: const [
            {
              'uid': 'friend-1',
              'displayName': 'Alice',
              'email': 'alice@test.com',
            },
          ],
          incomingRequests: const [],
          outgoingRequests: const [],
        ),
      );

  @override
  void add(dynamic event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test(
    'WorkspaceBloc deduplicates in-flight and already-sent workspace invites',
    () async {
      final gate = Completer<void>();
      final service = _FakeWorkspaceService()..inviteGate = gate;
      final bloc = WorkspaceBloc(workspaceService: service);
      addTearDown(() async {
        await bloc.close();
        await service.dispose();
      });

      bloc.add(LoadWorkspacesRequested());
      await Future<void>.delayed(Duration.zero);
      service.ownedController.add([
        Workspace(
          id: 'ws-1',
          name: 'Team Space',
          description: '',
          ownerId: 'owner-1',
          memberCount: 1,
          boardCount: 0,
          currentUserRole: 'owner',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      bloc.add(LoadWorkspaceMembersRequested('ws-1'));
      await Future<void>.delayed(Duration.zero);

      final firstDone = Completer<bool>();
      bloc.add(
        InviteToWorkspaceRequested(
          workspaceId: 'ws-1',
          invitedUserIds: ['friend-1'],
          onCompleted: firstDone.complete,
        ),
      );
      bloc.add(
        InviteToWorkspaceRequested(
          workspaceId: 'ws-1',
          invitedUserIds: ['friend-1'],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.inviteCalls, 1);

      gate.complete();
      expect(await firstDone.future, isTrue);

      final loaded = bloc.state as WorkspaceLoaded;
      expect(loaded.pendingInviteUserIdsByWorkspace['ws-1'], contains('friend-1'));
      expect(loaded.invitingUserIds, isEmpty);

      // Sending again once already pending/sent is a silent no-op.
      bloc.add(
        InviteToWorkspaceRequested(
          workspaceId: 'ws-1',
          invitedUserIds: ['friend-1'],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.inviteCalls, 1);
    },
  );

  testWidgets(
    'WorkspaceSettingsScreen shows Sent greyed-out button after invite and blocks resends',
    (tester) async {
      final gate = Completer<void>();
      final service = _FakeWorkspaceService()..inviteGate = gate;
      final bloc = WorkspaceBloc(workspaceService: service);
      final authBloc = _StubAuthBloc();
      final friendsBloc = _StubFriendsBloc();
      addTearDown(() async {
        await bloc.close();
        await authBloc.close();
        await friendsBloc.close();
        await service.dispose();
      });

      bloc.add(LoadWorkspacesRequested());
      await tester.pump();
      service.ownedController.add([
        Workspace(
          id: 'ws-1',
          name: 'Team Space',
          description: '',
          ownerId: 'owner-1',
          memberCount: 1,
          boardCount: 0,
          currentUserRole: 'owner',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ]);
      await tester.pump();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<FriendsBloc>.value(value: friendsBloc),
            BlocProvider<WorkspaceBloc>.value(value: bloc),
          ],
          child: MaterialApp(
            theme: InkTheme.light(),
            home: const WorkspaceSettingsScreen(workspaceId: 'ws-1'),
          ),
        ),
      );
      await tester.pump();

      // Open invite composer.
      await tester.tap(find.text('Invite'));
      await tester.pump();

      // There are now two 'Invite' labels or one header 'Hide invite' + friend row 'Invite'.
      final inviteButtonFinder = find.text('Invite');
      expect(inviteButtonFinder, findsOneWidget);

      // Tap rapidly twice before completion.
      await tester.tap(inviteButtonFinder);
      await tester.tap(find.text('Invite'), warnIfMissed: false);
      await tester.pump();

      expect(service.inviteCalls, 1);
      expect(find.text('Sent'), findsNothing);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('Invite'), findsNothing);
      expect(find.text('Sent'), findsOneWidget);

      // Tapping Sent is a disabled no-op.
      await tester.tap(find.text('Sent'), warnIfMissed: false);
      await tester.pump();
      expect(service.inviteCalls, 1);
    },
  );
}
