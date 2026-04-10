import 'package:cloud_firestore/cloud_firestore.dart';
import 'friends_repository.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import 'package:rxdart/rxdart.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  FriendsRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
  }) : _firestoreService = firestoreService,
       _authService = authService;

  String get _currentUid => _authService.getCurrentUserId()!;

  @override
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    final snap = await _firestoreService
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchIncomingRequests() {
    return _firestoreService
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
    final currentUid = _authService.getCurrentUserId()!;

    return _firestoreService
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

          return _firestoreService
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendUids)
              .snapshots()
              .map(
                (userSnap) => userSnap.docs.map((doc) => doc.data()).toList(),
              );
        });
  }
}
