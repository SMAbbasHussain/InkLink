import '../../domain/models/board.dart';
import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/notification/in_app_notification.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import 'web_account.dart';

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
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerificationEmail();
  Future<bool> reloadEmailVerified();
  Future<void> signOut();

  // Profile
  Stream<UserModel?> watchMyProfile();
  Future<void> updateProfile({required String name, required String bio});

  // Boards
  Stream<List<Board>> watchMyBoards();
  Future<List<Board>> loadPublicBoards({int limit = 40});

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

  // Notifications
  Stream<List<InAppNotification>> watchNotifications();
  Future<void> deleteNotification(String notificationId);
}
