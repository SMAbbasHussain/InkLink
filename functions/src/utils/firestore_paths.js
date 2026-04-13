/**
 * Firestore collection and field name constants
 * Matches the Flutter app's firestore_paths.dart for consistency
 */

const FirestorePaths = {
  // Collections
  USERS: 'users',
  BOARDS: 'boards',
  FRIEND_REQUESTS: 'friend_requests',
  BOARD_INVITES: 'board_invites',
  BLOCKED_USERS: 'blocked_users',
  USER_REPORTS: 'user_reports',
  
  // User subcollections
  FRIENDS_SUBCOLLECTION: 'friends',
  NOTIFICATIONS_SUBCOLLECTION: 'notifications',
  
  // User document fields
  UID: 'uid',
  EMAIL: 'email',
  DISPLAY_NAME: 'displayName',
  PHOTO_URL: 'photoURL',
  BIO: 'bio',
  IS_ONLINE: 'isOnline',
  CREATED_AT: 'createdAt',
  LAST_ACTIVE: 'lastActive',
  SEARCH_KEYWORDS: 'searchKeywords',
  FCM_TOKEN: 'fcmToken',
  FCM_TOKENS: 'fcmTokens',
  FRIEND_COUNT: 'friendCount',
  BOARD_COUNT: 'boardCount',
  OWNED_BOARDS: 'ownedBoards',
  JOINED_BOARDS: 'joinedBoards',
  
  // Friend request fields
  FROM_UID: 'fromUid',
  TO_UID: 'toUid',
  SENDER_NAME: 'senderName',
  SENDER_PIC: 'senderPic',
  TIMESTAMP: 'timestamp',
  STATUS: 'status',

  // Board invite fields
  BOARD_ID: 'boardId',
  BOARD_TITLE: 'boardTitle',
  EXPIRES_AT: 'expiresAt',
  INVITE_EXPIRY_HOURS: 'inviteExpiryHours',
  VISIBILITY: 'visibility',
  PRIVATE_JOIN_POLICY: 'privateJoinPolicy',
  JOIN_VIA_CODE_ENABLED: 'joinViaCodeEnabled',
  JOIN_CODE: 'joinCode',
  TAGS: 'tags',

  // Notification fields
  TYPE: 'type',
  TITLE: 'title',
  BODY: 'body',
  ACTION: 'action',
  TARGET_ID: 'targetId',
  GROUPING_KEY: 'groupingKey',
  READ_AT: 'readAt',
  
  // Friend document fields
  SINCE: 'since',
};

module.exports = FirestorePaths;
