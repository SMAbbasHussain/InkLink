import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface for Firebase Authentication operations
/// This enables dependency injection and easier testing (can mock implementations)
abstract class AuthService {
  /// Get the current authenticated user
  User? getCurrentUser();

  /// Get the current user's UID
  String? getCurrentUserId();

  /// Get the current user's ID token (Firebase JWT) for server authentication
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Get Firebase Auth instance (if direct access needed)
  FirebaseAuth getInstance();

  /// Send password reset email via Firebase (FR01-07)
  Future<void> sendPasswordResetEmail(String email);

  /// Send email verification to currently logged in user (FR01-05)
  Future<void> sendEmailVerification();

  /// Reload user from Firebase and return whether email is verified (FR01-06)
  Future<bool> reloadAndCheckEmailVerified();

  /// Delete the current authenticated user account (FR02-06)
  Future<void> deleteAccount();
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

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
