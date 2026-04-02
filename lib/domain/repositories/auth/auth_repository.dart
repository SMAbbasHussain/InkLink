import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String name, String email, String password);
  Future<User?> signInWithGoogle();
  Future<void> syncFcmToken();
  Future<void> signOut();
  Stream<User?> get user;
  User? get currentUser;
  Future<void> registerUserInFirestore(User user, {String? displayName});
}
