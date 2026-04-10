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
}
