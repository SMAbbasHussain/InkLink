abstract class FriendsRepository {
  // Search
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email);

  // Streams for UI Reactivity
  Stream<List<Map<String, dynamic>>> watchIncomingRequests();
  Stream<List<Map<String, dynamic>>> watchOutgoingRequests();
  Stream<List<Map<String, dynamic>>> watchFriendsList();
}
