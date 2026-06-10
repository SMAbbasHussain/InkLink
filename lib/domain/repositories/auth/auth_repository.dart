import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String name, String email, String password);
  Future<User?> signInWithGoogle();
  Future<void> signOut();
  Stream<User?> get user;
  User? get currentUser;
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
}
