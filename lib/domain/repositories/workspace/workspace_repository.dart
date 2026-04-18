import '../../models/board.dart';
import '../../models/workspace.dart';

abstract class WorkspaceRepository {
  String? get currentUserId;

  Future<void> startWorkspaceSync();
  Future<void> stopWorkspaceSync();
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
