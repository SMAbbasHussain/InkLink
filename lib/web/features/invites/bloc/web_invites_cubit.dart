import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/invitation/board_invitation.dart';
import '../../../../domain/models/workspace.dart';
import '../../../domain/services/web_companion_service.dart';

class WebInvitesState {
  final List<BoardInvitation> boardInvites;
  final bool boardInvitesLoading;
  final Object? boardInvitesError;

  final List<WorkspaceInvite> workspaceInvites;
  final bool workspaceInvitesLoading;
  final Object? workspaceInvitesError;

  const WebInvitesState({
    this.boardInvites = const [],
    this.boardInvitesLoading = true,
    this.boardInvitesError,
    this.workspaceInvites = const [],
    this.workspaceInvitesLoading = true,
    this.workspaceInvitesError,
  });

  int get totalPendingInvites => boardInvites.length + workspaceInvites.length;

  WebInvitesState copyWith({
    List<BoardInvitation>? boardInvites,
    bool? boardInvitesLoading,
    Object? Function()? boardInvitesError,
    List<WorkspaceInvite>? workspaceInvites,
    bool? workspaceInvitesLoading,
    Object? Function()? workspaceInvitesError,
  }) => WebInvitesState(
    boardInvites: boardInvites ?? this.boardInvites,
    boardInvitesLoading: boardInvitesLoading ?? this.boardInvitesLoading,
    boardInvitesError: boardInvitesError != null
        ? boardInvitesError()
        : this.boardInvitesError,
    workspaceInvites: workspaceInvites ?? this.workspaceInvites,
    workspaceInvitesLoading:
        workspaceInvitesLoading ?? this.workspaceInvitesLoading,
    workspaceInvitesError: workspaceInvitesError != null
        ? workspaceInvitesError()
        : this.workspaceInvitesError,
  );
}

/// Manages pending board and workspace invitations for the web companion via
/// [WebCompanionService].
class WebInvitesCubit extends Cubit<WebInvitesState> {
  final WebCompanionService _service;
  final List<StreamSubscription<dynamic>> _subs = [];

  WebInvitesCubit({required this._service}) : super(const WebInvitesState()) {
    rebind();
  }

  void rebind() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    emit(const WebInvitesState());
    _subs.addAll([
      _service.watchBoardInvites().listen(
        (invites) {
          if (!isClosed) {
            emit(
              state.copyWith(
                boardInvites: invites,
                boardInvitesLoading: false,
                boardInvitesError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(
                boardInvitesLoading: false,
                boardInvitesError: () => error,
              ),
            );
          }
        },
      ),
      _service.watchWorkspaceInvites().listen(
        (invites) {
          if (!isClosed) {
            emit(
              state.copyWith(
                workspaceInvites: invites,
                workspaceInvitesLoading: false,
                workspaceInvitesError: () => null,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              state.copyWith(
                workspaceInvitesLoading: false,
                workspaceInvitesError: () => error,
              ),
            );
          }
        },
      ),
    ]);
  }

  Future<void> acceptBoardInvite(String inviteId) =>
      _service.acceptBoardInvite(inviteId);

  Future<void> declineBoardInvite(String inviteId) =>
      _service.declineBoardInvite(inviteId);

  Future<void> acceptWorkspaceInvite(String inviteId) =>
      _service.acceptWorkspaceInvite(inviteId);

  Future<void> declineWorkspaceInvite(String inviteId) =>
      _service.declineWorkspaceInvite(inviteId);

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
