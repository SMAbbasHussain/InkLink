import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../domain/models/user_model.dart';
import '../models/web_account.dart';
import '../models/web_account_settings.dart';

/// Firebase Auth and `users/{uid}` profile/settings data source for the web
/// companion.
class WebAuthProfileDataSource {
  final AuthService _auth;
  final FirestoreService _firestore;

  WebAuthProfileDataSource({
    required AuthService authService,
    required FirestoreService firestoreService,
  }) : _auth = authService,
       _firestore = firestoreService;

  String? get uid => _auth.getCurrentUserId();

  static WebAccount? _toAccount(User? user) => user == null
      ? null
      : WebAccount(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          emailVerified: user.emailVerified,
          usesPassword: user.providerData.any(
            (p) => p.providerId == 'password',
          ),
        );

  Stream<WebAccount?> get authChanges =>
      _auth.getInstance().authStateChanges().map(_toAccount);

  WebAccount? get currentUser => _toAccount(_auth.getCurrentUser());

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.getInstance().signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _requireExistingAccount();
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _auth.getInstance().signInWithPopup(GoogleAuthProvider());
      await _requireExistingAccount();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      throw _authMessage(e);
    }
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw 'Please enter your name.';
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await _auth
          .getInstance()
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      final user = credential.user;
      if (user == null) {
        throw 'Could not create your account. Please try again.';
      }
      try {
        await user.updateDisplayName(trimmedName);
      } catch (_) {}
      await _firestore.collection(FirestorePaths.users).doc(user.uid).set({
        FirestorePaths.uid: user.uid,
        FirestorePaths.email: normalizedEmail,
        FirestorePaths.displayName: trimmedName,
        FirestorePaths.photoURL: '',
        FirestorePaths.searchKeywords: generateSearchKeywords(trimmedName),
        FirestorePaths.friendCount: 0,
        FirestorePaths.boardCount: 0,
        FirestorePaths.createdAt: FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      try {
        await _auth.sendEmailVerification();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  Future<void> _requireExistingAccount() async {
    final currentUid = uid;
    if (currentUid == null) return;
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(currentUid)
        .get();
    if (!doc.exists) {
      await signOut();
      throw 'No InkLink account found. Please create your account in the InkLink mobile app first.';
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  Future<void> resendVerificationEmail() => _auth.sendEmailVerification();

  Future<bool> reloadEmailVerified() async {
    final user = _auth.getCurrentUser();
    if (user == null) return false;
    await user.reload();
    return _auth.getCurrentUser()?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.getInstance().signOut();

  Stream<UserModel?> watchMyProfile() {
    final currentUid = uid;
    if (currentUid == null) return Stream.value(null);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(currentUid)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? UserModel.fromFirestore(doc.data()!, currentUid)
              : null,
        );
  }

  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {
    final currentUid = uid;
    if (currentUid == null) throw 'Please sign in again.';
    final trimmedName = name.trim();
    await _firestore.collection(FirestorePaths.users).doc(currentUid).update({
      FirestorePaths.displayName: trimmedName,
      FirestorePaths.bio: bio.trim(),
      FirestorePaths.searchKeywords: generateSearchKeywords(trimmedName),
    });
  }

  Stream<WebAccountSettings> watchAccountSettings() {
    final currentUid = uid;
    if (currentUid == null) return Stream.value(WebAccountSettings.defaults);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(currentUid)
        .snapshots()
        .map((doc) => WebAccountSettings.fromMap(doc.data()));
  }

  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) async {
    final currentUid = uid;
    if (currentUid == null) throw 'Please sign in again.';
    await _firestore
        .collection(FirestorePaths.users)
        .doc(currentUid)
        .update(
          const WebAccountSettings()
              .copyWith(
                isProfilePublic: isProfilePublic,
                showOnlineStatus: showOnlineStatus,
                showEmail: showEmail,
              )
              .privacyFields(),
        );
  }

  Future<void> updatePreferredTags(List<String> tags) async {
    final currentUid = uid;
    if (currentUid == null) throw 'Please sign in again.';
    await _firestore.collection(FirestorePaths.users).doc(currentUid).update({
      'preferredTags': List<String>.of(tags),
    });
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'popup-blocked':
        return 'Your browser blocked the sign-in popup. Please allow popups for this site.';
      case 'account-exists-with-different-credential':
        return 'This email already uses a different sign-in method.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Sign in instead.';
      case 'weak-password':
        return 'Use at least 6 characters for your password.';
      case 'operation-not-allowed':
        return 'Email sign-up is not available right now. Please try again later.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }
}
