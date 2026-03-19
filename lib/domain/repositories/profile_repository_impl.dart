import '../../core/utils/helpers.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import 'profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  ProfileRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
  }) : _firestoreService = firestoreService,
       _authService = authService;

  @override
  String? getCurrentUserId() {
    return _authService.getCurrentUserId();
  }

  @override
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final doc = await _firestoreService.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  Future<bool> checkFriendshipStatus(String targetUid) async {
    final currentUid = _authService.getCurrentUserId();
    if (currentUid == null) return false;

    final doc = await _firestoreService
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  @override
  Future<void> updateUserProfile({
    required String name,
    required String bio,
  }) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    // 1. Update Firebase Auth (for local app instance)
    await user.updateDisplayName(name);

    // 2. Generate new search keywords for the new name
    final keywords = generateSearchKeywords(name);

    // 3. Update Firestore (Source of truth for friends)
    await _firestoreService.collection('users').doc(user.uid).update({
      'displayName': name,
      'bio': bio,
      'searchKeywords': keywords,
    });
  }
}
