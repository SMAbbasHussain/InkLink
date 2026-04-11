abstract class ProfileRepository {
  String? getCurrentUserId();
  Future<Map<String, dynamic>?> getUserById(String uid);
  Stream<Map<String, dynamic>?> getUserByIdStream(String uid);
  Future<bool> checkFriendshipStatus(String targetUid);
  Future<void> cacheUserProfile(
    String uid,
    Map<String, dynamic> data, {
    required bool isFriend,
    required bool isSelf,
    String source = 'profile_open',
  });
  Future<void> updateUserFields(String uid, Map<String, dynamic> data);
}
