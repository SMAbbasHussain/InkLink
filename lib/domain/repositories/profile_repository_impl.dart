import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/helpers.dart';
import 'profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  Future<bool> checkFriendshipStatus(String targetUid) async {
    final doc = await _db
        .collection('users')
        .doc(_auth.currentUser!.uid)
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
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Update Firebase Auth (for local app instance)
    await user.updateDisplayName(name);

    // 2. Generate new search keywords for the new name
    final keywords = generateSearchKeywords(name);

    // 3. Update Firestore (Source of truth for friends)
    await _db.collection('users').doc(user.uid).update({
      'displayName': name,
      'bio': bio,
      'searchKeywords': keywords,
    });
  }
}
