import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/utils/helpers.dart'; // FIX: Use centralized helper for search keywords
import 'dart:developer' as developer;

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Add Firestore instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<User?> get user => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

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

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // 1. CHECK IF USER EXISTS FIRST
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // 2. Only register if they are a NEW user
          developer.log("New Google user. Registering...");
          await registerUserInFirestore(user, displayName: user.displayName);
        } else {
          // 3. If they exist, ONLY update presence/activity, NOT the whole profile
          developer.log("Existing Google user. Updating activity...");
          await _firestore.collection('users').doc(user.uid).update({
            'lastActive': FieldValue.serverTimestamp(),
            'isOnline': true,
          });
        }
      }

      return user;
    } on FirebaseAuthException catch (e, stackTrace) {
      developer.log(
        "Google Sign-In Auth Error",
        error: e,
        stackTrace: stackTrace,
      );
      throw _mapFirebaseAuthError(e);
    } catch (e, stackTrace) {
      developer.log(
        "Google Sign-In Unknown Error",
        error: e,
        stackTrace: stackTrace,
      );
      throw "An unexpected error occurred. Please try again.";
    }
  }

  @override
  Future<void> registerUserInFirestore(User user, {String? displayName}) async {
    try {
      final String finalName =
          displayName ?? user.displayName ?? "InkLink Creator";

      final userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': finalName,
        'photoURL': user.photoURL ?? '',
        'isOnline': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'searchKeywords': generateSearchKeywords(
          finalName,
        ), // FIX: Use centralized helper
        // No 'bio' here, so we MUST use merge: true
      };

      // FIX: Use SetOptions(merge: true) to prevent wiping existing fields like 'bio'
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      developer.log("User doc processed with merge: true");
    } catch (e) {
      developer.log("Firestore Save Error", error: e);
    }
  }

  // FIX: Removed duplicate _generateSearchKeywords - now using centralized helper
  // from lib/core/utils/helpers.dart to avoid duplication

  // --- SIGN IN WITH EMAIL (Don't forget to add Firestore here too!) ---
  @override
  Future<User?> signUp(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;

      if (user != null) {
        // 1. Update Auth Profile
        await user.updateDisplayName(name);

        // 2. PASS THE NAME MANUALLY HERE
        // This bypasses the null check on the stale 'user' object
        await registerUserInFirestore(user, displayName: name);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw "An unexpected error occurred during sign up.";
    }
  }

  @override
  Future<User?> signIn(String email, String password) async =>
      (await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user;

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
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
