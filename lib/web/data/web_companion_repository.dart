import 'dart:typed_data';

import '../../domain/models/board.dart';
import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/notification/in_app_notification.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import 'web_account.dart';
import 'web_account_settings.dart';
import 'web_board_ops.dart';
import 'web_mappers.dart';

/// Pure data-access contract for the web companion (Auth, Firestore, and
/// browser `SharedPreferences`).
///
/// Contains **no Cloud Function callables**: privileged mutations are
/// orchestrated by [WebCompanionService] (domain service layer) so
/// repositories stay strictly data-access only.
abstract class WebCompanionDataRepository {
  // Auth
  Stream<WebAccount?> get authChanges;
  WebAccount? get currentUser;
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerificationEmail();
  Future<bool> reloadEmailVerified();
  Future<void> signOut();

  // Profile & account settings
  Stream<UserModel?> watchMyProfile();
  Future<void> updateProfile({required String name, required String bio});
  Stream<WebAccountSettings> watchAccountSettings();
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  });
  Future<void> updatePreferredTags(List<String> tags);

  // Boards (Firestore reads & direct writes — delegated to WebBoardRepository)
  Stream<List<Board>> watchMyBoards();
  Future<List<Board>> loadPublicBoards({int limit = 40});
  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  });
  Future<void> renameBoard(String boardId, String newName);
  Future<void> setBoardArchived(String boardId, {required bool archived});
  Future<void> duplicateBoard(String boardId, {String? customTitle});
  Future<void> updateBoardTags(String boardId, List<String> tags);

  // Workspaces (Firestore reads & direct member writes)
  Stream<List<Workspace>> watchMyWorkspaces();
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId);
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId);
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  });
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  });

  // Invites (Firestore reads)
  Stream<List<BoardInvitation>> watchBoardInvites();
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites();

  // Friends (Firestore reads)
  Stream<List<FriendRequest>> watchIncomingFriendRequests();
  Stream<List<Friend>> watchFriends();
  Future<List<Friend>> searchUsersByEmail(String email);
  Stream<List<Friend>> watchBlockedUsers();

  // Notifications (Firestore + SharedPreferences read state)
  Stream<List<InAppNotification>> watchNotifications();
  Future<void> deleteNotification(String notificationId);
  Stream<Set<String>> watchReadNotificationIds();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead(Iterable<String> ids);

  /// The feed with the browser's read state applied (badges and dots use this).
  Stream<List<InAppNotification>> watchNotificationsWithReadState() =>
      combineLatest2(
        watchNotifications(),
        watchReadNotificationIds(),
        applyReadState,
      );
}

/// Full offline/in-memory contract implemented by `SampleWebCompanionRepository`
/// for design previews and widget tests without Firebase Cloud Functions.
abstract class WebCompanionRepository extends WebCompanionDataRepository {
  Future<void> deleteAccount();
  Future<void> uploadProfilePhoto(Uint8List bytes, {required String filename});

  Future<void> joinBoard(String boardIdOrCode);
  Future<void> setBoardPaused(String boardId, {required bool paused});
  Future<void> deleteBoard(String boardId);
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  });

  Future<String> createWorkspace({
    required String name,
    required String description,
  });
  Future<void> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  });
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  });
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  });
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> userIds,
  });
  Future<void> leaveWorkspace(String workspaceId);
  Future<void> deleteWorkspace(String workspaceId);

  Future<void> acceptBoardInvite(String inviteId);
  Future<void> declineBoardInvite(String inviteId);
  Future<void> acceptWorkspaceInvite(String inviteId);
  Future<void> declineWorkspaceInvite(String inviteId);

  Future<void> acceptFriendRequest(String requestId);
  Future<void> declineFriendRequest(String requestId);
  Future<void> sendFriendRequest(String targetUid);
  Future<void> unfriend(String targetUid);
  Future<void> blockUser(String targetUid);
  Future<void> unblockUser(String targetUid);
}
