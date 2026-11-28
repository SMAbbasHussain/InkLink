import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstract interface for Firestore operations.
///
/// Enables dependency injection and easier testing without exposing Cloud
/// Functions (use `CloudFunctionsService` for callable functions instead).
abstract class FirestoreService {
  /// Get reference to a collection.
  CollectionReference<Map<String, dynamic>> collection(String path);

  /// Get Firestore instance (if direct access is needed, e.g. transactions).
  FirebaseFirestore getInstance();

  /// Re-enable Firestore network after sign-out.
  Future<void> enableNetwork();

  /// Disable Firestore network to prevent permission-denied errors after
  /// the auth token is invalidated.
  Future<void> disableNetwork();
}

/// Production implementation using Firebase.
class FirestoreServiceImpl implements FirestoreService {
  final FirebaseFirestore _firestore;

  /// Constructor accepting optional [FirebaseFirestore] for testability.
  FirestoreServiceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  @override
  FirebaseFirestore getInstance() {
    return _firestore;
  }

  @override
  Future<void> enableNetwork() async {
    try {
      await _firestore.enableNetwork();
    } catch (_) {}
  }

  @override
  Future<void> disableNetwork() async {
    try {
      await _firestore.disableNetwork();
    } catch (_) {}
  }
}
