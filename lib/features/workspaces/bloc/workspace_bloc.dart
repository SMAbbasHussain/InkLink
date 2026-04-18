import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/board.dart';
import '../../../domain/models/workspace.dart';
import '../../../domain/services/workspace/workspace_service.dart';

abstract class WorkspaceEvent {}

class LoadWorkspacesRequested extends WorkspaceEvent {}

class LoadWorkspaceBoardsRequested extends WorkspaceEvent {
  final String workspaceId;

  LoadWorkspaceBoardsRequested(this.workspaceId);
}

class LoadWorkspaceMembersRequested extends WorkspaceEvent {
  final String workspaceId;

  LoadWorkspaceMembersRequested(this.workspaceId);
}

class _OwnedWorkspacesUpdated extends WorkspaceEvent {
  final List<Workspace> workspaces;

  _OwnedWorkspacesUpdated(this.workspaces);
}

class _MemberWorkspacesUpdated extends WorkspaceEvent {
  final List<Workspace> workspaces;

  _MemberWorkspacesUpdated(this.workspaces);
}

class _IncomingInvitesUpdated extends WorkspaceEvent {
  final List<WorkspaceInvite> invites;

  _IncomingInvitesUpdated(this.invites);
}

class _WorkspacePreviewBoardsUpdated extends WorkspaceEvent {
  final String workspaceId;
  final List<Board> boards;

  _WorkspacePreviewBoardsUpdated({
    required this.workspaceId,
    required this.boards,
  });
}

class _WorkspaceBoardsUpdated extends WorkspaceEvent {
  final String workspaceId;
  final List<Board> boards;

  _WorkspaceBoardsUpdated({required this.workspaceId, required this.boards});
}

class _WorkspaceMembersUpdated extends WorkspaceEvent {
  final String workspaceId;
  final List<WorkspaceMember> members;

  _WorkspaceMembersUpdated({required this.workspaceId, required this.members});
}

class CreateWorkspaceRequested extends WorkspaceEvent {
  final String name;
  final String description;
  final List<String>? boardIds;

  CreateWorkspaceRequested({
    required this.name,
    required this.description,
    this.boardIds,
  });
}

class UpdateWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;
  final String name;
  final String description;

  UpdateWorkspaceRequested({
    required this.workspaceId,
    required this.name,
    required this.description,
  });
}

class DeleteWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;

  DeleteWorkspaceRequested(this.workspaceId);
}

class InviteToWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;
  final List<String> invitedUserIds;

  InviteToWorkspaceRequested({
    required this.workspaceId,
    required this.invitedUserIds,
  });
}

class LeaveWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;
  final List<String>? importedBoardsToKeep;

  LeaveWorkspaceRequested(
    this.workspaceId, {
    this.importedBoardsToKeep,
  });
}

class RemoveWorkspaceMemberRequested extends WorkspaceEvent {
  final String workspaceId;
  final String memberUid;

  RemoveWorkspaceMemberRequested({
    required this.workspaceId,
    required this.memberUid,
  });
}

class LoadIncomingInvitesRequested extends WorkspaceEvent {}

class AcceptWorkspaceInviteRequested extends WorkspaceEvent {
  final String inviteId;

  AcceptWorkspaceInviteRequested(this.inviteId);
}

class RejectWorkspaceInviteRequested extends WorkspaceEvent {
  final String inviteId;

  RejectWorkspaceInviteRequested(this.inviteId);
}

class AddBoardToWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;
  final String boardId;

  AddBoardToWorkspaceRequested({
    required this.workspaceId,
    required this.boardId,
  });
}

class CreateBoardInWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;
  final String title;
  final String? description;
  final String? visibility;

  CreateBoardInWorkspaceRequested({
    required this.workspaceId,
    required this.title,
    this.description,
    this.visibility,
  });
}

class RemoveBoardFromWorkspaceRequested extends WorkspaceEvent {
  final String workspaceId;
  final String boardId;

  RemoveBoardFromWorkspaceRequested({
    required this.workspaceId,
    required this.boardId,
  });
}

abstract class WorkspaceState {}

class WorkspaceInitial extends WorkspaceState {}

class WorkspaceLoaded extends WorkspaceState {
  final List<Workspace> ownedWorkspaces;
  final List<Workspace> memberWorkspaces;
  final List<WorkspaceInvite> incomingInvites;
  final Map<String, List<Board>> previewBoardsByWorkspace;
  final Map<String, List<Board>> boardsByWorkspace;
  final Map<String, List<WorkspaceMember>> membersByWorkspace;
  final Set<String> processingInviteDecisionIds;
  final Set<String> invitingUserIds;
  final String? actionError;
  final String? actionInfo;

  WorkspaceLoaded({
    required this.ownedWorkspaces,
    required this.memberWorkspaces,
    required this.incomingInvites,
    required this.previewBoardsByWorkspace,
    required this.boardsByWorkspace,
    required this.membersByWorkspace,
    this.processingInviteDecisionIds = const <String>{},
    this.invitingUserIds = const <String>{},
    this.actionError,
    this.actionInfo,
  });

  WorkspaceLoaded copyWith({
    List<Workspace>? ownedWorkspaces,
    List<Workspace>? memberWorkspaces,
    List<WorkspaceInvite>? incomingInvites,
    Map<String, List<Board>>? previewBoardsByWorkspace,
    Map<String, List<Board>>? boardsByWorkspace,
    Map<String, List<WorkspaceMember>>? membersByWorkspace,
    Set<String>? processingInviteDecisionIds,
    Set<String>? invitingUserIds,
    Object? actionError = _unset,
    Object? actionInfo = _unset,
  }) {
    return WorkspaceLoaded(
      ownedWorkspaces: ownedWorkspaces ?? this.ownedWorkspaces,
      memberWorkspaces: memberWorkspaces ?? this.memberWorkspaces,
      incomingInvites: incomingInvites ?? this.incomingInvites,
      previewBoardsByWorkspace:
          previewBoardsByWorkspace ?? this.previewBoardsByWorkspace,
      boardsByWorkspace: boardsByWorkspace ?? this.boardsByWorkspace,
      membersByWorkspace: membersByWorkspace ?? this.membersByWorkspace,
      processingInviteDecisionIds:
          processingInviteDecisionIds ?? this.processingInviteDecisionIds,
      invitingUserIds: invitingUserIds ?? this.invitingUserIds,
      actionError: actionError == _unset
          ? this.actionError
          : actionError as String?,
      actionInfo: actionInfo == _unset
          ? this.actionInfo
          : actionInfo as String?,
    );
  }
}

const Object _unset = Object();

class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  final WorkspaceService? _workspaceService;
  StreamSubscription<List<Workspace>>? _ownedWorkspacesSub;
  StreamSubscription<List<Workspace>>? _memberWorkspacesSub;
  StreamSubscription<List<WorkspaceInvite>>? _incomingInvitesSub;
  final Map<String, StreamSubscription<List<Board>>> _previewBoardSubs = {};
  final Map<String, StreamSubscription<List<Board>>> _workspaceBoardSubs = {};
  final Map<String, StreamSubscription<List<WorkspaceMember>>>
  _workspaceMemberSubs = {};

  WorkspaceBloc({WorkspaceService? workspaceService})
    : _workspaceService = workspaceService,
      super(WorkspaceInitial()) {
    on<LoadWorkspacesRequested>(_onLoadWorkspacesRequested);
    on<LoadWorkspaceBoardsRequested>(_onLoadWorkspaceBoardsRequested);
    on<LoadWorkspaceMembersRequested>(_onLoadWorkspaceMembersRequested);
    on<CreateWorkspaceRequested>(_onCreateWorkspaceRequested);
    on<UpdateWorkspaceRequested>(_onUpdateWorkspaceRequested);
    on<DeleteWorkspaceRequested>(_onDeleteWorkspaceRequested);
    on<InviteToWorkspaceRequested>(_onInviteToWorkspaceRequested);
    on<LeaveWorkspaceRequested>(_onLeaveWorkspaceRequested);
    on<RemoveWorkspaceMemberRequested>(_onRemoveWorkspaceMemberRequested);
    on<LoadIncomingInvitesRequested>(_onLoadIncomingInvitesRequested);
    on<AcceptWorkspaceInviteRequested>(_onAcceptWorkspaceInviteRequested);
    on<RejectWorkspaceInviteRequested>(_onRejectWorkspaceInviteRequested);
    on<AddBoardToWorkspaceRequested>(_onAddBoardToWorkspaceRequested);
    on<CreateBoardInWorkspaceRequested>(_onCreateBoardInWorkspaceRequested);
    on<RemoveBoardFromWorkspaceRequested>(_onRemoveBoardFromWorkspaceRequested);
    on<_OwnedWorkspacesUpdated>(_onOwnedWorkspacesUpdated);
    on<_MemberWorkspacesUpdated>(_onMemberWorkspacesUpdated);
    on<_IncomingInvitesUpdated>(_onIncomingInvitesUpdated);
    on<_WorkspacePreviewBoardsUpdated>(_onWorkspacePreviewBoardsUpdated);
    on<_WorkspaceBoardsUpdated>(_onWorkspaceBoardsUpdated);
    on<_WorkspaceMembersUpdated>(_onWorkspaceMembersUpdated);
  }

  WorkspaceLoaded _emptyLoaded() {
    return WorkspaceLoaded(
      ownedWorkspaces: const [],
      memberWorkspaces: const [],
      incomingInvites: const [],
      previewBoardsByWorkspace: const {},
      boardsByWorkspace: const {},
      membersByWorkspace: const {},
      processingInviteDecisionIds: const <String>{},
      invitingUserIds: const <String>{},
    );
  }

  Future<void> _onLoadWorkspacesRequested(
    LoadWorkspacesRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.startWorkspacSync();

      await _ownedWorkspacesSub?.cancel();
      await _memberWorkspacesSub?.cancel();
      await _incomingInvitesSub?.cancel();

      _ownedWorkspacesSub = service.getOwnedWorkspaces().listen((workspaces) {
        add(_OwnedWorkspacesUpdated(workspaces));
      });

      _memberWorkspacesSub = service.getMemberWorkspaces().listen((workspaces) {
        add(_MemberWorkspacesUpdated(workspaces));
      });

      _incomingInvitesSub = service.getIncomingWorkspaceInvites().listen((
        invites,
      ) {
        add(_IncomingInvitesUpdated(invites));
      });

      emit(_emptyLoaded());
    } catch (e) {
      emit(
        _emptyLoaded().copyWith(actionError: 'Failed to load workspaces: $e'),
      );
    }
  }

  Future<void> _onLoadWorkspaceBoardsRequested(
    LoadWorkspaceBoardsRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null || _workspaceBoardSubs.containsKey(event.workspaceId)) {
      return;
    }

    _workspaceBoardSubs[event.workspaceId] = service
        .getWorkspaceBoards(event.workspaceId)
        .listen((boards) {
          add(
            _WorkspaceBoardsUpdated(
              workspaceId: event.workspaceId,
              boards: boards,
            ),
          );
        });
  }

  Future<void> _onLoadWorkspaceMembersRequested(
    LoadWorkspaceMembersRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null ||
        _workspaceMemberSubs.containsKey(event.workspaceId)) {
      return;
    }

    _workspaceMemberSubs[event.workspaceId] = service
        .getWorkspaceMembers(event.workspaceId)
        .listen((members) {
          add(
            _WorkspaceMembersUpdated(
              workspaceId: event.workspaceId,
              members: members,
            ),
          );
        });
  }

  void _onOwnedWorkspacesUpdated(
    _OwnedWorkspacesUpdated event,
    Emitter<WorkspaceState> emit,
  ) {
    final current = state is WorkspaceLoaded
        ? state as WorkspaceLoaded
        : _emptyLoaded();
    final next = current.copyWith(
      ownedWorkspaces: event.workspaces,
      actionError: null,
      actionInfo: null,
    );
    emit(next);
    _syncWorkspacePreviewSubscriptions(next);
  }

  void _onMemberWorkspacesUpdated(
    _MemberWorkspacesUpdated event,
    Emitter<WorkspaceState> emit,
  ) {
    final current = state is WorkspaceLoaded
        ? state as WorkspaceLoaded
        : _emptyLoaded();
    final next = current.copyWith(
      memberWorkspaces: event.workspaces,
      actionError: null,
      actionInfo: null,
    );
    emit(next);
    _syncWorkspacePreviewSubscriptions(next);
  }

  void _onIncomingInvitesUpdated(
    _IncomingInvitesUpdated event,
    Emitter<WorkspaceState> emit,
  ) {
    final current = state is WorkspaceLoaded
        ? state as WorkspaceLoaded
        : _emptyLoaded();
    emit(current.copyWith(incomingInvites: event.invites));
  }

  void _onWorkspacePreviewBoardsUpdated(
    _WorkspacePreviewBoardsUpdated event,
    Emitter<WorkspaceState> emit,
  ) {
    final current = state is WorkspaceLoaded
        ? state as WorkspaceLoaded
        : _emptyLoaded();
    final nextMap = Map<String, List<Board>>.from(
      current.previewBoardsByWorkspace,
    );
    nextMap[event.workspaceId] = event.boards;
    emit(current.copyWith(previewBoardsByWorkspace: nextMap));
  }

  void _onWorkspaceBoardsUpdated(
    _WorkspaceBoardsUpdated event,
    Emitter<WorkspaceState> emit,
  ) {
    final current = state is WorkspaceLoaded
        ? state as WorkspaceLoaded
        : _emptyLoaded();
    final nextMap = Map<String, List<Board>>.from(current.boardsByWorkspace);
    nextMap[event.workspaceId] = event.boards;
    emit(current.copyWith(boardsByWorkspace: nextMap));
  }

  void _onWorkspaceMembersUpdated(
    _WorkspaceMembersUpdated event,
    Emitter<WorkspaceState> emit,
  ) {
    final current = state is WorkspaceLoaded
        ? state as WorkspaceLoaded
        : _emptyLoaded();
    final nextMap = Map<String, List<WorkspaceMember>>.from(
      current.membersByWorkspace,
    );
    nextMap[event.workspaceId] = event.members;
    emit(current.copyWith(membersByWorkspace: nextMap));
  }

  Future<void> _onCreateWorkspaceRequested(
    CreateWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.createWorkspace(
        name: event.name,
        description: event.description,
        boardIds: event.boardIds,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(
            actionInfo: 'Workspace created successfully.',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to create workspace: $e'));
      }
    }
  }

  Future<void> _onUpdateWorkspaceRequested(
    UpdateWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.updateWorkspace(
        workspaceId: event.workspaceId,
        name: event.name,
        description: event.description,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(actionInfo: 'Workspace updated.', actionError: null),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to update workspace: $e'));
      }
    }
  }

  Future<void> _onDeleteWorkspaceRequested(
    DeleteWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.deleteWorkspace(event.workspaceId);
      final current = state;
      if (current is WorkspaceLoaded) {
        final previewMap = Map<String, List<Board>>.from(
          current.previewBoardsByWorkspace,
        )..remove(event.workspaceId);
        final boardsMap = Map<String, List<Board>>.from(
          current.boardsByWorkspace,
        )..remove(event.workspaceId);
        final membersMap = Map<String, List<WorkspaceMember>>.from(
          current.membersByWorkspace,
        )..remove(event.workspaceId);
        emit(
          current.copyWith(
            ownedWorkspaces: current.ownedWorkspaces
                .where((w) => w.id != event.workspaceId)
                .toList(),
            memberWorkspaces: current.memberWorkspaces
                .where((w) => w.id != event.workspaceId)
                .toList(),
            previewBoardsByWorkspace: previewMap,
            boardsByWorkspace: boardsMap,
            membersByWorkspace: membersMap,
            actionInfo: 'Workspace deleted.',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to delete workspace: $e'));
      }
    }
  }

  Future<void> _onInviteToWorkspaceRequested(
    InviteToWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    final current = state;
    if (current is WorkspaceLoaded) {
      final nextInviting = Set<String>.from(current.invitingUserIds)
        ..addAll(event.invitedUserIds);
      emit(
        current.copyWith(
          invitingUserIds: nextInviting,
          actionError: null,
          actionInfo: null,
        ),
      );
    }

    try {
      await service.inviteToWorkspace(
        workspaceId: event.workspaceId,
        invitedUserIds: event.invitedUserIds,
      );
      final updated = state;
      if (updated is WorkspaceLoaded) {
        final nextInviting = Set<String>.from(updated.invitingUserIds)
          ..removeAll(event.invitedUserIds);
        emit(
          updated.copyWith(
            invitingUserIds: nextInviting,
            actionInfo:
                'Invitations sent to ${event.invitedUserIds.length} user(s).',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final updated = state;
      if (updated is WorkspaceLoaded) {
        final nextInviting = Set<String>.from(updated.invitingUserIds)
          ..removeAll(event.invitedUserIds);
        emit(
          updated.copyWith(
            invitingUserIds: nextInviting,
            actionError: 'Failed to send invitations: $e',
          ),
        );
      }
    }
  }

  Future<void> _onLeaveWorkspaceRequested(
    LeaveWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.leaveWorkspace(
        workspaceId: event.workspaceId,
        importedBoardsToKeep: event.importedBoardsToKeep,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(
            memberWorkspaces: current.memberWorkspaces
                .where((w) => w.id != event.workspaceId)
                .toList(),
            actionInfo: 'You have left the workspace.',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to leave workspace: $e'));
      }
    }
  }

  Future<void> _onRemoveWorkspaceMemberRequested(
    RemoveWorkspaceMemberRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.removeMemberFromWorkspace(
        workspaceId: event.workspaceId,
        memberUid: event.memberUid,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(actionInfo: 'Member removed.', actionError: null),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to remove member: $e'));
      }
    }
  }

  Future<void> _onLoadIncomingInvitesRequested(
    LoadIncomingInvitesRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    // Invites are driven by stream subscriptions started in _onLoadWorkspacesRequested.
  }

  Future<void> _onAcceptWorkspaceInviteRequested(
    AcceptWorkspaceInviteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    final current = state;
    if (current is WorkspaceLoaded) {
      final nextProcessing = Set<String>.from(
        current.processingInviteDecisionIds,
      )..add(event.inviteId);
      emit(
        current.copyWith(
          processingInviteDecisionIds: nextProcessing,
          actionError: null,
          actionInfo: null,
        ),
      );
    }

    try {
      await service.acceptWorkspaceInvite(event.inviteId);
      final updated = state;
      if (updated is WorkspaceLoaded) {
        final nextProcessing = Set<String>.from(
          updated.processingInviteDecisionIds,
        )..remove(event.inviteId);
        emit(
          updated.copyWith(
            processingInviteDecisionIds: nextProcessing,
            incomingInvites: updated.incomingInvites
                .where((i) => i.id != event.inviteId)
                .toList(),
            actionInfo: 'Invite accepted.',
            actionError: null,
          ),
        );
      }
    } catch (e, st) {
      _logWorkspaceInviteError(
        action: 'accept',
        inviteId: event.inviteId,
        error: e,
        stackTrace: st,
      );
      final updated = state;
      if (updated is WorkspaceLoaded) {
        final nextProcessing = Set<String>.from(
          updated.processingInviteDecisionIds,
        )..remove(event.inviteId);
        emit(
          updated.copyWith(
            processingInviteDecisionIds: nextProcessing,
            actionError: _buildWorkspaceInviteErrorMessage(
              action: 'accept',
              error: e,
            ),
          ),
        );
      }
    }
  }

  Future<void> _onRejectWorkspaceInviteRequested(
    RejectWorkspaceInviteRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    final current = state;
    if (current is WorkspaceLoaded) {
      final nextProcessing = Set<String>.from(
        current.processingInviteDecisionIds,
      )..add(event.inviteId);
      emit(
        current.copyWith(
          processingInviteDecisionIds: nextProcessing,
          actionError: null,
          actionInfo: null,
        ),
      );
    }

    try {
      await service.rejectWorkspaceInvite(event.inviteId);
      final updated = state;
      if (updated is WorkspaceLoaded) {
        final nextProcessing = Set<String>.from(
          updated.processingInviteDecisionIds,
        )..remove(event.inviteId);
        emit(
          updated.copyWith(
            processingInviteDecisionIds: nextProcessing,
            incomingInvites: updated.incomingInvites
                .where((i) => i.id != event.inviteId)
                .toList(),
            actionInfo: 'Invite rejected.',
            actionError: null,
          ),
        );
      }
    } catch (e, st) {
      _logWorkspaceInviteError(
        action: 'reject',
        inviteId: event.inviteId,
        error: e,
        stackTrace: st,
      );
      final updated = state;
      if (updated is WorkspaceLoaded) {
        final nextProcessing = Set<String>.from(
          updated.processingInviteDecisionIds,
        )..remove(event.inviteId);
        emit(
          updated.copyWith(
            processingInviteDecisionIds: nextProcessing,
            actionError: _buildWorkspaceInviteErrorMessage(
              action: 'reject',
              error: e,
            ),
          ),
        );
      }
    }
  }

  Future<void> _onAddBoardToWorkspaceRequested(
    AddBoardToWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.addBoardToWorkspace(
        workspaceId: event.workspaceId,
        boardId: event.boardId,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(
            actionInfo: 'Board added to workspace.',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to add board: $e'));
      }
    }
  }

  Future<void> _onCreateBoardInWorkspaceRequested(
    CreateBoardInWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      final boardId = await service.createBoardInWorkspace(
        workspaceId: event.workspaceId,
        title: event.title,
        description: event.description,
        visibility: event.visibility,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(
            actionInfo: 'Board created in workspace: $boardId',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to create board: $e'));
      }
    }
  }

  Future<void> _onRemoveBoardFromWorkspaceRequested(
    RemoveBoardFromWorkspaceRequested event,
    Emitter<WorkspaceState> emit,
  ) async {
    final service = _workspaceService;
    if (service == null) return;

    try {
      await service.removeBoardFromWorkspace(
        workspaceId: event.workspaceId,
        boardId: event.boardId,
      );
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(
          current.copyWith(
            actionInfo: 'Board removed from workspace.',
            actionError: null,
          ),
        );
      }
    } catch (e) {
      final current = state;
      if (current is WorkspaceLoaded) {
        emit(current.copyWith(actionError: 'Failed to remove board: $e'));
      }
    }
  }

  void _syncWorkspacePreviewSubscriptions(WorkspaceLoaded state) {
    final service = _workspaceService;
    if (service == null) {
      return;
    }

    final targetIds = <String>{
      ...state.ownedWorkspaces.map((w) => w.id),
      ...state.memberWorkspaces.map((w) => w.id),
    };

    final staleIds = _previewBoardSubs.keys
        .where((id) => !targetIds.contains(id))
        .toList();
    for (final wsId in staleIds) {
      _previewBoardSubs.remove(wsId)?.cancel();
    }

    for (final wsId in targetIds) {
      if (_previewBoardSubs.containsKey(wsId)) {
        continue;
      }
      _previewBoardSubs[wsId] = service
          .getWorkspaceBoards(wsId, limit: 4)
          .listen((boards) {
            add(
              _WorkspacePreviewBoardsUpdated(workspaceId: wsId, boards: boards),
            );
          });
    }
  }

  Future<void> stopForLogout() async {
    await _ownedWorkspacesSub?.cancel();
    await _memberWorkspacesSub?.cancel();
    await _incomingInvitesSub?.cancel();
    _ownedWorkspacesSub = null;
    _memberWorkspacesSub = null;
    _incomingInvitesSub = null;

    for (final sub in _previewBoardSubs.values) {
      await sub.cancel();
    }
    _previewBoardSubs.clear();

    for (final sub in _workspaceBoardSubs.values) {
      await sub.cancel();
    }
    _workspaceBoardSubs.clear();

    for (final sub in _workspaceMemberSubs.values) {
      await sub.cancel();
    }
    _workspaceMemberSubs.clear();

    await _workspaceService?.stopWorkspacSync();
  }

  @override
  Future<void> close() async {
    await stopForLogout();
    return super.close();
  }

  String _buildWorkspaceInviteErrorMessage({
    required String action,
    required Object error,
  }) {
    if (error is FirebaseFunctionsException) {
      return 'Failed to $action invite (${error.code}): ${error.message ?? 'Unknown Cloud Function error'}';
    }
    return 'Failed to $action invite: $error';
  }

  void _logWorkspaceInviteError({
    required String action,
    required String inviteId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    developer.log(
      'Workspace invite $action failed for inviteId=$inviteId',
      name: 'WorkspaceBloc',
      error: error,
      stackTrace: stackTrace,
    );

    if (error is FirebaseFunctionsException) {
      developer.log(
        'Cloud Function details for $action inviteId=$inviteId | code=${error.code} | message=${error.message} | details=${error.details}',
        name: 'WorkspaceBloc',
      );
    }
  }
}
