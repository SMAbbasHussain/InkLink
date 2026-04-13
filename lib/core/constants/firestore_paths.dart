// Firestore collection and document paths - centralized constants
// This prevents typos and makes it easier to refactor databases in the future

class FirestorePaths {
  // Collections
  static const String users = 'users';
  static const String friendRequests = 'friend_requests';

  // User subcollections
  static const String friendsSubcollection = 'friends';

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
}
