abstract class SocialRepository {
  // Search
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email);
  
  // Requests
  Future<void> sendFriendRequest(String targetUid);
  Future<void> acceptFriendRequest(String requestId, String senderUid);
  Future<void> declineFriendRequest(String requestId);
  
  // Streams for UI Reactivity
  Stream<List<Map<String, dynamic>>> watchIncomingRequests();
  Stream<List<Map<String, dynamic>>> watchFriendsList();
}