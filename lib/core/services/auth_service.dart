import 'package:firebase_auth/firebase_auth.dart';

/// Outcome of an email-verification reload/check.
enum EmailVerificationStatus { verified, unverified, unknown }

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

  /// Reload user from Firebase and report the verification status (FR01-06).
  /// [EmailVerificationStatus.unknown] means the check itself failed and
  /// callers must NOT treat it as "unverified".
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified();

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
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return EmailVerificationStatus.unknown;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return EmailVerificationStatus.unknown;
    return refreshed.emailVerified
        ? EmailVerificationStatus.verified
        : EmailVerificationStatus.unverified;
  }
  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
