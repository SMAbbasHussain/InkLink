import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_repository.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  FirebaseAuthRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
  }) : _authService = authService,
       _firestoreService = firestoreService;

  @override
  Stream<User?> get user => _authService.getInstance().authStateChanges();

  @override
  User? get currentUser => _authService.getCurrentUser();

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestoreService.collection('users').doc(uid).get();
    return doc.data();
  }

  @override
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _authService
          .getInstance()
          .signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    }
  }

  @override
  Future<void> upsertUserData(String uid, Map<String, dynamic> data) async {
    await _firestoreService
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> syncFcmToken(String uid, String token) {
    return upsertUserData(uid, {
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeFcmTokenOnSignOut(String uid, {String? token}) {
    final userUpdates = <String, dynamic>{
      'fcmToken': FieldValue.delete(),
      'lastActive': FieldValue.serverTimestamp(),
    };

    if (token != null && token.isNotEmpty) {
      userUpdates['fcmTokens'] = FieldValue.arrayRemove([token]);
    }

    return upsertUserData(uid, userUpdates);
  }

  @override
  Future<void> upsertUserProfile({
    required String uid,
    required String? email,
    required String displayName,
    required String photoURL,
    required List<String> searchKeywords,
    required bool isNewUser,
  }) {
    return upsertUserData(uid, {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'lastActive': FieldValue.serverTimestamp(),
      'searchKeywords': searchKeywords,
      if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<User?> signUp(String name, String email, String password) async {
    try {
      final credential = await _authService
          .getInstance()
          .createUserWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw "An unexpected error occurred during sign up.";
    }
  }

  @override
  Future<User?> signIn(String email, String password) async =>
      (await _authService.getInstance().signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user;

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _authService.getInstance().signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-disabled':
        return "This account has been disabled.";
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
        return "Incorrect password.";
      case 'network-request-failed':
        return "Check your internet connection.";
      default:
        return "Authentication failed. Please try again.";
    }
  }
}
