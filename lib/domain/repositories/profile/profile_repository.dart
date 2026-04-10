abstract class ProfileRepository {
  String? getCurrentUserId();
  Future<Map<String, dynamic>?> getUserById(String uid);
  Stream<Map<String, dynamic>?> getUserByIdStream(String uid);
  Future<bool> checkFriendshipStatus(String targetUid);
  Future<void> updateUserFields(String uid, Map<String, dynamic> data);
}
