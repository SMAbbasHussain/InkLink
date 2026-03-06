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

  //Methods for profile screen
  Future<Map<String, dynamic>?> getUserById(String uid);
  Future<bool> checkFriendshipStatus(String targetUid);
  Future<void> updateUserProfile({required String name, required String bio});
}