import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_repository.dart';
import '../../../core/utils/helpers.dart'; // FIX: Use centralized helper for search keywords
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/messaging_service.dart';
import 'dart:developer' as developer;

class FirebaseAuthRepository implements AuthRepository {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final MessagingService _messagingService;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _tokenRefreshBound = false;

  FirebaseAuthRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
    required MessagingService messagingService,
  }) : _authService = authService,
       _firestoreService = firestoreService,
       _messagingService = messagingService;

  @override
  Stream<User?> get user => _authService.getInstance().authStateChanges();

  @override
  User? get currentUser => _authService.getCurrentUser();

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
      final User? user = userCredential.user;

      if (user != null) {
        // 1. CHECK IF USER EXISTS FIRST
        final userDoc = await _firestoreService
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
          await _firestoreService.collection('users').doc(user.uid).update({
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
      await _firestoreService
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      developer.log("User doc processed with merge: true");
    } catch (e) {
      developer.log("Firestore Save Error", error: e);
    }
  }

  @override
  Future<User?> signUp(String name, String email, String password) async {
    try {
      final credential = await _authService
          .getInstance()
          .createUserWithEmailAndPassword(email: email, password: password);
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
      (await _authService.getInstance().signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user;

  @override
  Future<void> syncFcmToken() async {
    final current = _authService.getCurrentUser();
    if (current == null) return;

    try {
      await _messagingService.requestPermission();
      final token = await _messagingService.getToken();
      if (token != null && token.isNotEmpty) {
        await _firestoreService.collection('users').doc(current.uid).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!_tokenRefreshBound) {
        _tokenRefreshBound = true;
        _messagingService.onTokenRefresh.listen((newToken) async {
          final user = _authService.getCurrentUser();
          if (user == null || newToken.isEmpty) return;

          await _firestoreService.collection('users').doc(user.uid).set({
            'fcmToken': newToken,
            'fcmTokens': FieldValue.arrayUnion([newToken]),
            'lastActive': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }
    } catch (e) {
      developer.log('Failed to sync FCM token', error: e);
    }
  }

  @override
  Future<void> signOut() async {
    final current = _authService.getCurrentUser();
    if (current != null) {
      try {
        final token = await _messagingService.getToken();
        if (token != null && token.isNotEmpty) {
          await _firestoreService.collection('users').doc(current.uid).set({
            'fcmToken': FieldValue.delete(),
            'fcmTokens': FieldValue.arrayRemove([token]),
            'lastActive': FieldValue.serverTimestamp(),
            'isOnline': false,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        developer.log('Failed to clear FCM token on sign out', error: e);
      }
    }

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
