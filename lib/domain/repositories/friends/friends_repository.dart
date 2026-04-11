abstract class FriendsRepository {
  // Search
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email);
  Future<int> countFriendsForUser(String userId);

  // Block Status
  Future<bool> hasUserBlockedTarget(String targetUid);
  Stream<List<Map<String, dynamic>>> watchBlockedUsers();
  Future<void> cacheBlockedUser(String targetUid);
  Future<void> removeBlockedUser(String targetUid);

  // Streams for UI Reactivity
  Stream<List<Map<String, dynamic>>> watchIncomingRequests();
  Stream<List<Map<String, dynamic>>> watchOutgoingRequests();
  Stream<List<Map<String, dynamic>>> watchFriendsList();
}
