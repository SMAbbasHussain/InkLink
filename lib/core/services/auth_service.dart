import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface for Firebase Authentication operations
/// This enables dependency injection and easier testing (can mock implementations)
abstract class AuthService {
  /// Get the current authenticated user
  User? getCurrentUser();

  /// Get the current user's UID
  String? getCurrentUserId();

  /// Get Firebase Auth instance (if direct access needed)
  FirebaseAuth getInstance();
}

/// Production implementation using Firebase
class AuthServiceImpl implements AuthService {
  final FirebaseAuth _auth;

  /// Constructor accepting optional FirebaseAuth instance for testability
  /// In production, uses FirebaseAuth.instance
  AuthServiceImpl({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  @override
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  @override
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  @override
  FirebaseAuth getInstance() {
    return _auth;
  }
}
