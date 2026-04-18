import '../../../core/services/cloud_functions_service.dart';
import '../../models/board.dart';
import '../../models/workspace.dart';
import '../../repositories/workspace/workspace_repository.dart';

abstract class WorkspaceService {
  Future<void> startWorkspacSync();
  Future<void> stopWorkspacSync();
  Stream<List<Workspace>> getOwnedWorkspaces();
  Stream<List<Workspace>> getMemberWorkspaces();
  Stream<Workspace?> getWorkspaceById(String workspaceId);
  Stream<List<Board>> getWorkspaceBoards(String workspaceId, {int? limit});
  Stream<List<WorkspaceMember>> getWorkspaceMembers(String workspaceId);
  Future<String> createWorkspace({
    required String name,
    required String description,
    List<String>? boardIds,
  });
  Future<void> updateWorkspace({
    required String workspaceId,
    required String name,
    required String description,
  });
  Future<void> deleteWorkspace(String workspaceId);
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> invitedUserIds,
  });
  Future<void> leaveWorkspace({
    String? workspaceId,
    List<String>? importedBoardsToKeep,
  });
  Future<void> removeMemberFromWorkspace({
    required String workspaceId,
    required String memberUid,
  });
  Stream<List<WorkspaceInvite>> getIncomingWorkspaceInvites();
  Future<void> acceptWorkspaceInvite(String inviteId);
  Future<void> rejectWorkspaceInvite(String inviteId);
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  });
  Future<String> createBoardInWorkspace({
    required String workspaceId,
    required String title,
    String? description,
    String? visibility,
  });
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  });
  Future<void> setWorkspaceBoardVisibility({
    required String workspaceId,
    required String boardId,
    required bool visible,
  });
}

class WorkspaceServiceImpl implements WorkspaceService {
  final WorkspaceRepository _repository;
  final CloudFunctionsService _cloudFunctionsService;

  WorkspaceServiceImpl({
    required WorkspaceRepository repository,
    required CloudFunctionsService cloudFunctionsService,
  }) : _repository = repository,
       _cloudFunctionsService = cloudFunctionsService;

  @override
  Future<void> startWorkspacSync() => _repository.startWorkspaceSync();

  @override
  Future<void> stopWorkspacSync() => _repository.stopWorkspaceSync();

  @override
  Stream<List<Workspace>> getOwnedWorkspaces() =>
      _repository.getOwnedWorkspaces();

  @override
  Stream<List<Workspace>> getMemberWorkspaces() =>
      _repository.getMemberWorkspaces();

  @override
  Stream<Workspace?> getWorkspaceById(String workspaceId) =>
      _repository.getWorkspaceById(workspaceId);

  @override
  Stream<List<Board>> getWorkspaceBoards(String workspaceId, {int? limit}) =>
      _repository.getWorkspaceBoards(workspaceId, limit: limit);

  @override
  Stream<List<WorkspaceMember>> getWorkspaceMembers(String workspaceId) =>
      _repository.getWorkspaceMembers(workspaceId);

  @override
  Future<String> createWorkspace({
    required String name,
    required String description,
    List<String>? boardIds,
  }) => _repository.createWorkspace(
    name: name,
    description: description,
    boardIds: boardIds,
  );

  @override
  Future<void> updateWorkspace({
    required String workspaceId,
    required String name,
    required String description,
  }) => _repository.updateWorkspace(
    workspaceId: workspaceId,
    name: name,
    description: description,
  );

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      _repository.deleteWorkspace(workspaceId);

  @override
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> invitedUserIds,
  }) async {
    await _cloudFunctionsService.httpsCallable('inviteToWorkspace').call({
      'workspaceId': workspaceId,
      'invitedUserIds': invitedUserIds,
    });
  }

  @override
  Future<void> leaveWorkspace({
    String? workspaceId,
    List<String>? importedBoardsToKeep,
  }) async {
    if (workspaceId == null || workspaceId.isEmpty) {
      throw ArgumentError('workspaceId is required');
    }
    await _cloudFunctionsService.httpsCallable('leaveWorkspace').call({
      'workspaceId': workspaceId,
      'importedBoardsToKeep': importedBoardsToKeep ?? [],
    });
  }

  @override
  Future<void> removeMemberFromWorkspace({
    required String workspaceId,
    required String memberUid,
  }) => _repository.removeMemberFromWorkspace(
    workspaceId: workspaceId,
    memberUid: memberUid,
  );

  @override
  Stream<List<WorkspaceInvite>> getIncomingWorkspaceInvites() =>
      _repository.getIncomingWorkspaceInvites();

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) async {
    await _cloudFunctionsService.httpsCallable('acceptWorkspaceInvite').call({
      'inviteId': inviteId,
    });
  }

  @override
  Future<void> rejectWorkspaceInvite(String inviteId) async {
    await _cloudFunctionsService.httpsCallable('rejectWorkspaceInvite').call({
      'inviteId': inviteId,
    });
  }

  @override
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  }) async {
    await _cloudFunctionsService.httpsCallable('addBoardToWorkspace').call({
      'workspaceId': workspaceId,
      'boardId': boardId,
    });
  }

  @override
  Future<String> createBoardInWorkspace({
    required String workspaceId,
    required String title,
    String? description,
    String? visibility,
  }) async {
    final result = await _cloudFunctionsService
        .httpsCallable('createWorkspaceBoard')
        .call({
          'workspaceId': workspaceId,
          'title': title,
          'description': description,
          'visibility': visibility,
        });
    return result.data['boardId'] as String;
  }

  @override
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  }) => _repository.removeBoardFromWorkspace(
    workspaceId: workspaceId,
    boardId: boardId,
  );

  @override
  Future<void> setWorkspaceBoardVisibility({
    required String workspaceId,
    required String boardId,
    required bool visible,
  }) => _repository.setWorkspaceBoardVisibility(
    workspaceId: workspaceId,
    boardId: boardId,
    visible: visible,
  );
}
