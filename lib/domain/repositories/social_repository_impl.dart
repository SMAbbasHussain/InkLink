import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/social_repository.dart';
import 'package:rxdart/rxdart.dart';

class SocialRepositoryImpl implements SocialRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  String get _currentUid => _auth.currentUser!.uid;

  @override
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<void> sendFriendRequest(String targetUid) async {
    if (_currentUid == targetUid) return;

    // Deterministic ID (senderUid_receiverUid) ensures 1 request per pair
    final List<String> ids = [_currentUid, targetUid]..sort();
    final String requestId = ids.join('_');

    // Check if friendship already exists
    final friendCheck = await _db
        .collection('users')
        .doc(_currentUid)
        .collection('friends')
        .doc(targetUid)
        .get();
    if (friendCheck.exists) throw Exception("Already friends.");

    await _db.collection('friend_requests').doc(requestId).set({
      'fromUid': _currentUid,
      'toUid': targetUid,
      'senderName': _auth.currentUser!.displayName,
      'senderPic': _auth.currentUser!.photoURL,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  Future<void> acceptFriendRequest(String requestId, String senderUid) async {
    try {
      // Ensure this string matches the filename in functions/src/ EXACTLY (without .js)
      final result = await _functions
          .httpsCallable('accept_friend_request')
          .call({'requestId': requestId});

      if (result.data['success'] != true) {
        throw Exception("Server failed to establish friendship");
      }
    } on FirebaseFunctionsException catch (e) {
      // This will give you the actual error from the Cloud Function logs
      print("Cloud Function Error: ${e.code} - ${e.message}");
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Connection error");
    }
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchIncomingRequests() {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: _currentUid)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchFriendsList() {
    final currentUid = _auth.currentUser!.uid;

    return _db
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .snapshots()
        .switchMap((snapshot) {
          // Get the IDs
          final friendUids = snapshot.docs.map((doc) => doc.id).toList();

          // IMPORTANT: If no friends, return empty list immediately
          // to avoid Firestore 'whereIn' error with empty array.
          if (friendUids.isEmpty) {
            return Stream.value([]);
          }

          return _db
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendUids)
              .snapshots()
              .map(
                (userSnap) => userSnap.docs.map((doc) => doc.data()).toList(),
              );
        });
  }

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
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < name.length; i++) {
      temp = temp + name[i].toLowerCase();
      keywords.add(temp);
    }

    // 3. Update Firestore (Source of truth for friends)
    await _db.collection('users').doc(user.uid).update({
      'displayName': name,
      'bio': bio,
      'searchKeywords': keywords,
    });
  }
}
