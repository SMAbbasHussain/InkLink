abstract class ProfileRepository {
  Future<Map<String, dynamic>?> getUserById(String uid);
  Future<bool> checkFriendshipStatus(String targetUid);
  Future<void> updateUserProfile({required String name, required String bio});
}
