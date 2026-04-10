import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:developer' as developer;
import 'friends_repository.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import 'package:rxdart/rxdart.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final CloudFunctionsService _functionsService;

  FriendsRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required CloudFunctionsService functionsService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _functionsService = functionsService;

  String get _currentUid => _authService.getCurrentUserId()!;

  @override
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    // FIX: Ensure consistent email lookup by converting to lowercase
    // Important: Make sure emails are always stored lowercase in Firestore
    // to prevent case sensitivity issues in search
    final snap = await _firestoreService
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  @override
  Future<void> sendFriendRequest(String targetUid) async {
    if (_currentUid == targetUid) return;

    try {
      final result = await _functionsService
          .httpsCallable('sendFriendRequest')
          .call({'targetUid': targetUid});

      if (result.data['success'] != true) {
        throw Exception('Server failed to send request');
      }
    } on FirebaseFunctionsException catch (e) {
      developer.log(
        'Cloud Function Error: ${e.code} - ${e.message}',
        name: 'FriendsRepositoryImpl',
      );
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Connection error');
    }
  }

  @override
  Future<void> acceptFriendRequest(String requestId, String senderUid) async {
    try {
      // Ensure this string matches the filename in functions/src/ EXACTLY (without .js)
      final result = await _functionsService
          .httpsCallable('acceptFriendRequest')
          .call({'requestId': requestId});

      if (result.data['success'] != true) {
        throw Exception("Server failed to establish friendship");
      }
    } on FirebaseFunctionsException catch (e) {
      // This will give you the actual error from the Cloud Function logs
      developer.log(
        'Cloud Function Error: ${e.code} - ${e.message}',
        name: 'FriendsRepositoryImpl',
      );
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Connection error");
    }
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    // FIX: Use Cloud Function instead of direct Firestore delete
    // This ensures server-side validation (permission checks, logging)
    // and matches the decline_friend_request Cloud Function
    try {
      final result = await _functionsService
          .httpsCallable('declineFriendRequest')
          .call({'requestId': requestId});

      if (result.data['success'] != true) {
        throw Exception("Server failed to decline request");
      }
    } on FirebaseFunctionsException catch (e) {
      developer.log(
        'Cloud Function Error: ${e.code} - ${e.message}',
        name: 'FriendsRepositoryImpl',
      );
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Connection error");
    }
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
