import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String name, String email, String password);
  Future<User?> signInWithGoogle();
  Future<void> signOut();
  Stream<User?> get user;
  User? get currentUser;
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<bool> reloadAndCheckEmailVerified();
  Future<Map<String, dynamic>?> getUserData(String uid);
  Future<void> upsertUserData(String uid, Map<String, dynamic> data);
  Future<void> syncFcmToken(String uid, String token);
  Future<void> removeFcmTokenOnSignOut(String uid, {String? token});
  Future<void> upsertUserProfile({
    required String uid,
    required String? email,
    required String displayName,
    required String photoURL,
    required List<String> searchKeywords,
    required bool isNewUser,
  });
  /// Re-enable Firestore & RTDB so that sign-up / sign-in profile upserts
  /// succeed even when a previous session called [signOut] which disables the
  /// network.
  Future<void> enableNetwork();
  /// Disable Firestore & RTDB to stop listeners and prevent permission-denied
  /// errors after the auth token is invalidated during sign-out.
  Future<void> disableNetwork();
  /// Delete the user account from Firebase Auth (FR02-06)
  Future<void> deleteAccount({String? password});
  /// Re-authenticate the current user for sensitive operations
  Future<void> reauthenticate({String? password});
}
