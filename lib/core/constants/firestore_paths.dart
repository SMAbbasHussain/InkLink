// Firestore collection and document paths - centralized constants
// This prevents typos and makes it easier to refactor databases in the future

class FirestorePaths {
  // Collections
  static const String users = 'users';
  static const String boards = 'boards';
  static const String boardInvites = 'board_invites';
  static const String friendRequests = 'friend_requests';
  static const String workspaces = 'workspaces';
  static const String workspaceInvites = 'workspace_invites';

  // User subcollections
  static const String friendsSubcollection = 'friends';
  static const String notificationsSubcollection = 'notifications';
  static const String boardMembersSubcollection = 'members';
  static const String workspaceMembersSubcollection = 'members';
  static const String workspaceBoardsSubcollection = 'boards';

  // User document fields
  static const String uid = 'uid';
  static const String email = 'email';
  static const String displayName = 'displayName';
  static const String photoURL = 'photoURL';
  static const String bio = 'bio';
  static const String isOnline = 'isOnline';
  static const String createdAt = 'createdAt';
  static const String lastActive = 'lastActive';
  static const String searchKeywords = 'searchKeywords';
  static const String ownedBoards = 'ownedBoards';
  static const String joinedBoards = 'joinedBoards';
  static const String boardCount = 'boardCount';
  static const String workspaceIds = 'workspaceIds';

  // Friend request fields
  static const String fromUid = 'fromUid';
  static const String toUid = 'toUid';
  static const String senderName = 'senderName';
  static const String senderPic = 'senderPic';
  static const String timestamp = 'timestamp';
  static const String status = 'status';

  // Board fields
  static const String visibility = 'visibility';
  static const String privateJoinPolicy = 'privateJoinPolicy';
  static const String joinViaCodeEnabled = 'joinViaCodeEnabled';
  static const String joinCode = 'joinCode';
  static const String tags = 'tags';
  static const String ownerId = 'ownerId';
  static const String title = 'title';
  static const String boardId = 'boardId';
  static const String updatedAt = 'updatedAt';
  static const String invitePolicy = 'invitePolicy';
  static const String whoCanInvite = 'whoCanInvite';
  static const String defaultLinkJoinRole = 'defaultLinkJoinRole';
  static const String targetRole = 'targetRole';

  // Workspace fields
  static const String workspaceId = 'workspaceId';
  static const String name = 'name';
  static const String description = 'description';
  static const String memberCount = 'memberCount';

  // Workspace board fields
  static const String boardSource =
      'boardSource'; // 'imported' or 'workspace_native'
}
