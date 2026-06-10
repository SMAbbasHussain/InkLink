import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final FirebaseDatabase _database;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  FirebaseAuthRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
    required FirebaseDatabase database,
  }) : _authService = authService,
       _firestoreService = firestoreService,
       _database = database;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    _googleInitialized = true;
    await _googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );
  }

  @override
  Future<void> enableNetwork() async {
    await _firestoreService.enableNetwork();
    try {
      await _database.goOnline();
    } catch (_) {}
  }

  @override
  Future<void> disableNetwork() async {
    await _firestoreService.disableNetwork();
    try {
      await _database.goOffline();
    } catch (_) {}
  }

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
      await _ensureGoogleInitialized();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null) {
        developer.log('Google sign-in returned no idToken.', name: 'Auth');
        throw FirebaseAuthException(
          code: 'missing-google-token',
          message:
              'Google sign-in returned no idToken. Check SHA-1/web client ID configuration.',
        );
      }
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _authService
          .getInstance()
          .signInWithCredential(credential);
      return userCredential.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      developer.log(
        'Google sign-in exception: ${e.code}',
        name: 'Auth',
        error: e,
      );
      throw 'Google sign-in failed (${e.code}). Check OAuth client configuration.';
    } on FirebaseAuthException catch (e) {
      developer.log('Google sign-in failed: ${e.code}', name: 'Auth', error: e);
      throw _mapFirebaseAuthError(e);
    } on PlatformException catch (e) {
      developer.log(
        'Google sign-in platform error: ${e.code}',
        name: 'Auth',
        error: e,
      );
      throw 'Google sign-in failed (${e.code}). Check SHA-1 / OAuth client configuration.';
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
    });
  }

  @override
  Future<void> removeFcmTokenOnSignOut(String uid, {String? token}) {
    final userUpdates = <String, dynamic>{
      'fcmToken': FieldValue.delete(),
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
    final normalizedEmail = email?.trim().toLowerCase();
    return upsertUserData(uid, {
      'uid': uid,
      'email': normalizedEmail,
      'displayName': displayName,
      'photoURL': photoURL,
      'lastActive': FieldValue.serverTimestamp(),
      'searchKeywords': searchKeywords,
      if (isNewUser) 'createdAt': FieldValue.serverTimestamp(),
      if (isNewUser) 'friendCount': 0,
      if (isNewUser) 'boardCount': 0,
    });
  }

  @override
  Future<User?> signUp(String name, String email, String password) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final credential = await _authService
          .getInstance()
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw "An unexpected error occurred during sign up.";
    }
  }

  @override
  Future<User?> signIn(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    return (await _authService.getInstance().signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    )).user;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _authService.getInstance().signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Account exists with different credentials.';
      case 'invalid-credential':
        return 'Invalid credential. Check Google sign-in configuration.';
      case 'operation-not-allowed':
        return 'Google sign-in is disabled for this project.';
      case 'user-disabled':
        return "This account has been disabled.";
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
        return "Incorrect password.";
      case 'network-request-failed':
        return "Check your internet connection.";
      default:
        return "Authentication failed (${e.code}). Please try again.";
    }
  }
}
