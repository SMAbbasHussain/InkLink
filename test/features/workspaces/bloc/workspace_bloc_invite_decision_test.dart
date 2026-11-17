import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/workspace/workspace_service.dart';
import 'package:inklink/features/workspaces/bloc/workspace_bloc.dart';

class _FakeWorkspaceService extends Fake implements WorkspaceService {
  Object? failure;

  @override
  Future<void> stopWorkspacSync() async {}

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> rejectWorkspaceInvite(String inviteId) async {
    if (failure != null) throw failure!;
  }
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
}
