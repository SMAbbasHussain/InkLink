abstract class ProfileRepository {
  String? getCurrentUserId();
  Future<Map<String, dynamic>?> getUserById(String uid);
  Stream<Map<String, dynamic>?> getUserByIdStream(String uid);
  Future<bool> checkFriendshipStatus(String targetUid);
  Future<void> updateUserProfile({required String name, required String bio});
  Future<String> uploadProfilePhoto({
    required String imageData,
    required String filename,
  });
}
