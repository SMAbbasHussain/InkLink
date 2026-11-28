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

/// Everything the web companion reads and does.
///
/// [FirebaseWebCompanionRepository] is the real implementation. The preview
/// mode (lib/web/preview/) and the page tests use a sample-data version, so
/// the signed-in pages can be designed and tested without an account.
abstract class WebCompanionRepository {
  // Auth
  Stream<WebAccount?> get authChanges;
  WebAccount? get currentUser;
  Future<void> signInWithEmail(String email, String password);
  Future<void> signInWithGoogle();

  /// Creates an InkLink account from the browser: the Firebase user, the
  /// profile document the phone writes on first sign-in, and the verification
  /// email. The gate then asks the new account to verify its email, exactly
  /// like an existing password account that has not verified yet.
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerificationEmail();
  Future<bool> reloadEmailVerified();
  Future<void> signOut();
  Future<void> deleteAccount();

  // Profile
  Stream<UserModel?> watchMyProfile();
  Future<void> updateProfile({required String name, required String bio});

  /// Uploads a JPEG/PNG profile photo through the same Cloud Function the
  /// phone uses (base64 payload).
  Future<void> uploadProfilePhoto(Uint8List bytes, {required String filename});

  /// Settings → Privacy and Preferred Content Tags on the phone: three
  /// booleans and the tag list, all stored on the user document.
  Stream<WebAccountSettings> watchAccountSettings();
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  });
  Future<void> updatePreferredTags(List<String> tags);

  // Boards
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
  Future<void> joinBoard(String boardIdOrCode);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> setBoardArchived(String boardId, {required bool archived});
  Future<void> setBoardPaused(String boardId, {required bool paused});
  Future<void> deleteBoard(String boardId);
  Future<void> duplicateBoard(String boardId, {String? customTitle});
  Future<void> updateBoardTags(String boardId, List<String> tags);
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  });

  // Workspaces (list and open here; the management calls mirror the phone)
  Stream<List<Workspace>> watchMyWorkspaces();
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId);
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

  /// The live members of a workspace, with each member's role and profile.
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId);

  /// Owner-only: sets a member's role in `workspaces/{id}/members/{uid}`
  /// (`editor` / `member` / `viewer`, the phone's values). Refused writes throw
  /// a readable permission message.
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  });

  /// Owner-only: deletes the member document and decrements `memberCount`,
  /// as the phone's transaction does.
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  });

  /// Owner-only: sends the phone's `inviteToWorkspace` invitations.
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> userIds,
  });

  /// Leaves a workspace through the phone's `leaveWorkspace` function.
  Future<void> leaveWorkspace(String workspaceId);

  /// Owner-only: deletes a workspace through the phone's `deleteWorkspace`
  /// function.
  Future<void> deleteWorkspace(String workspaceId);

  // Invites
  Stream<List<BoardInvitation>> watchBoardInvites();
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites();
  Future<void> acceptBoardInvite(String inviteId);
  Future<void> declineBoardInvite(String inviteId);
  Future<void> acceptWorkspaceInvite(String inviteId);
  Future<void> declineWorkspaceInvite(String inviteId);

  // Friends
  Stream<List<FriendRequest>> watchIncomingFriendRequests();
  Stream<List<Friend>> watchFriends();
  Future<void> acceptFriendRequest(String requestId);
  Future<void> declineFriendRequest(String requestId);
  Future<List<Friend>> searchUsersByEmail(String email);
  Future<void> sendFriendRequest(String targetUid);
  Future<void> unfriend(String targetUid);
  Stream<List<Friend>> watchBlockedUsers();
  Future<void> blockUser(String targetUid);
  Future<void> unblockUser(String targetUid);

  // Notifications
  Stream<List<InAppNotification>> watchNotifications();
  Future<void> deleteNotification(String notificationId);

  /// Notification ids this browser has read. The phone stores them in
  /// shared_preferences because nothing writes a `read` flag to Firestore;
  /// the web feed overlays them on the Firestore documents.
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
