import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/board.dart';
import '../../../../domain/models/workspace.dart';
import '../../../domain/services/web_companion_service.dart';

class WebWorkspacesState {
  final List<Workspace> workspaces;
  final bool loading;
  final Object? error;

  const WebWorkspacesState({
    this.workspaces = const [],
    this.loading = true,
    this.error,
  });

  WebWorkspacesState copyWith({
    List<Workspace>? workspaces,
    bool? loading,
    Object? Function()? error,
  }) => WebWorkspacesState(
    workspaces: workspaces ?? this.workspaces,
    loading: loading ?? this.loading,
    error: error != null ? error() : this.error,
  );
}

/// Manages the user's workspaces, workspace boards, and member administration
/// via [WebCompanionService].
class WebWorkspacesCubit extends Cubit<WebWorkspacesState> {
  final WebCompanionService _service;
  StreamSubscription<List<Workspace>>? _workspacesSub;

  WebWorkspacesCubit({required this._service})
    : super(const WebWorkspacesState()) {
    rebind();
  }

  String? get currentUserId => _service.currentUser?.uid;

  void rebind() {
    _workspacesSub?.cancel();
    emit(const WebWorkspacesState());
    _workspacesSub = _service.watchMyWorkspaces().listen(
      (workspaces) {
        if (!isClosed) {
          emit(
            state.copyWith(
              workspaces: workspaces,
              loading: false,
              error: () => null,
            ),
          );
        }
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(state.copyWith(loading: false, error: () => error));
        }
      },
    );
  }

  void refresh() => rebind();

  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) =>
      _service.watchWorkspaceBoards(workspaceId);

  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId) =>
      _service.watchWorkspaceMembers(workspaceId);

  Future<({List<Board> activeBoards, Set<String> linkedIds})>
  loadManageableBoards(String workspaceId) async {
    final boards = await _service.watchMyBoards().first;
    final linked = await _service.watchWorkspaceBoards(workspaceId).first;
    return (
      activeBoards: boards.where((b) => !b.isArchived).toList(),
      linkedIds: linked.map((b) => b.id).toSet(),
    );
  }

  Future<String> createWorkspace({
    required String name,
    required String description,
  }) => _service.createWorkspace(name: name, description: description);

  Future<void> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  }) => _service.updateWorkspace(
    workspaceId: workspaceId,
    name: name,
    description: description,
  );

  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  }) =>
      _service.addBoardToWorkspace(workspaceId: workspaceId, boardId: boardId);

  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  }) => _service.removeBoardFromWorkspace(
    workspaceId: workspaceId,
    boardId: boardId,
  );

  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) => _service.updateWorkspaceMemberRole(
    workspaceId: workspaceId,
    memberUid: memberUid,
    role: role,
  );

  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  }) => _service.removeWorkspaceMember(
    workspaceId: workspaceId,
    memberUid: memberUid,
  );

  Future<void> inviteToWorkspaceByEmail({
    required String workspaceId,
    required String email,
  }) async {
    final users = await _service.searchUsersByEmail(email);
    if (users.isEmpty) throw 'No user found with that email.';
    await _service.inviteToWorkspace(
      workspaceId: workspaceId,
      userIds: [users.first.uid],
    );
  }

  Future<void> leaveWorkspace(String workspaceId) =>
      _service.leaveWorkspace(workspaceId);

  Future<void> deleteWorkspace(String workspaceId) =>
      _service.deleteWorkspace(workspaceId);

  @override
  Future<void> close() async {
    await _workspacesSub?.cancel();
    return super.close();
  }
}
