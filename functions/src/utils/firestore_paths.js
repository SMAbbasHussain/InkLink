/**
 * Firestore collection and field name constants
 * Matches the Flutter app's firestore_paths.dart for consistency
 */

const FirestorePaths = {
  // Collections
  USERS: 'users',
  FRIEND_REQUESTS: 'friend_requests',
  
  // User subcollections
  FRIENDS_SUBCOLLECTION: 'friends',
  
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
  
  // Friend request fields
  FROM_UID: 'fromUid',
  TO_UID: 'toUid',
  SENDER_NAME: 'senderName',
  SENDER_PIC: 'senderPic',
  TIMESTAMP: 'timestamp',
  STATUS: 'status',
  
  // Friend document fields
  SINCE: 'since',
};

module.exports = FirestorePaths;
