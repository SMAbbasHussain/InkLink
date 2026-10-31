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
          googleUser.authentication;
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
  Future<void> syncFcmToken(String uid, String token) async {
    final firestore = _firestoreService.getInstance();
    final userRef = firestore.collection('users').doc(uid);
    final batch = firestore.batch();

    // Store push tokens in a protected per-token subcollection instead of the
    // user document (which every signed-in user can read).
    final tokenDoc = userRef.collection('fcm_tokens').doc(_fcmTokenDocId(token));
    batch.set(tokenDoc, <String, dynamic>{
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Migration: strip legacy token fields from the (world-readable) user doc.
    batch.set(userRef, <String, dynamic>{
      'fcmToken': FieldValue.delete(),
      'fcmTokens': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  static String _fcmTokenDocId(String token) {
    // Firestore doc ids may not contain '/', '#', '[', ']' or '.' and must not
    // start with '__'. FCM tokens are URL-safe, but sanitize defensively.
    var id = token.replaceAll(RegExp(r'[.#$/\[\]]'), '_');
    if (id.startsWith('__')) id = 'tk_$id';
    if (id.length > 1400) id = 'tk_${id.hashCode.toUnsigned(31)}';
    return id;
  }

  @override
  Future<void> removeFcmTokenOnSignOut(String uid, {String? token}) {
    final userUpdates = <String, dynamic>{
      'fcmToken': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (token != null && token.isNotEmpty) {
      userUpdates['fcmTokens'] = FieldValue.arrayRemove([token]);
      return Future.wait<void>([
        upsertUserData(uid, userUpdates),
        _firestoreService
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .doc(_fcmTokenDocId(token))
            .delete(),
      ]).then((_) { });
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

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      await _authService.sendPasswordResetEmail(normalizedEmail);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw 'Failed to send verification email. Please try again.';
    }
  }

  @override
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified() async {
    try {
      return await _authService.reloadAndCheckEmailVerified();
    } catch (e) {
      // The check itself failed (network flake, transient error) — report
      // `unknown` so callers don't mistake it for "confirmed unverified"
      // and trap verified users on the verification screen.
      developer.log('Failed to check email verified status: $e', name: 'Auth', error: e);
      return EmailVerificationStatus.unknown;
    }
  }

  @override
  Future<void> reauthenticate({String? password}) async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw 'User not authenticated.';
    }
    final uid = user.uid;

    final isPasswordUser = user.providerData.any((p) => p.providerId == 'password');
    final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');

    try {
      if (isPasswordUser) {
        if (password == null || password.trim().isEmpty) {
          throw 'Please enter your password to confirm.';
        }
        final email = user.email;
        if (email != null && email.isNotEmpty) {
          final credential = EmailAuthProvider.credential(
            email: email,
            password: password.trim(),
          );
          await user.reauthenticateWithCredential(credential);
          developer.log('Re-authenticated email/password user $uid', name: 'AuthRepository');
        }
      } else if (isGoogleUser) {
        await _ensureGoogleInitialized();
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        if (googleAuth.idToken == null) {
          throw 'Google re-authentication failed: missing ID token.';
        }
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        developer.log('Re-authenticated Google user $uid', name: 'AuthRepository');
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw 'Google re-authentication was cancelled.';
      }
      throw 'Google re-authentication failed (${e.code}).';
    } on FirebaseAuthException catch (e) {
      developer.log('Re-authentication failed: ${e.code}', name: 'AuthRepository', error: e);
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw 'Incorrect password. Please verify and try again.';
      }
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Re-authentication failed: $e';
    }
  }

  @override
  Future<void> deleteAccount({String? password, bool reauthenticateUser = true}) async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw 'User not authenticated.';
    }
    final uid = user.uid;
    final firestore = _firestoreService.getInstance();

    developer.log('Starting deleteAccount workflow for $uid...', name: 'AuthRepository');

    // 0. Pre-authenticate / re-authenticate BEFORE deleting any data!
    if (reauthenticateUser) {
      await reauthenticate(password: password);
    }

    developer.log('Purging user data for $uid...', name: 'AuthRepository');

    try {
      // 1. Remove FCM token
      try {
        await removeFcmTokenOnSignOut(uid);
      } catch (e) {
        developer.log('Failed removing FCM token: $e', name: 'AuthRepository');
      }

      // 2. Cascade delete boards owned by user (including members, operations, snapshot subcollections)
      try {
        final ownedBoardsSnap = await firestore
            .collection('boards')
            .where('ownerId', isEqualTo: uid)
            .get();
        for (final doc in ownedBoardsSnap.docs) {
          try {
            final membersSnap = await doc.reference.collection('members').get();
            for (final mDoc in membersSnap.docs) {
              await mDoc.reference.delete();
            }
          } catch (_) {}
          try {
            final opsSnap = await doc.reference.collection('operations').get();
            for (final opDoc in opsSnap.docs) {
              await opDoc.reference.delete();
            }
          } catch (_) {}
          try {
            final snapDocs = await doc.reference.collection('snapshot').get();
            for (final sDoc in snapDocs.docs) {
              await sDoc.reference.delete();
            }
          } catch (_) {}
          await doc.reference.delete();
        }
      } catch (e) {
        developer.log('Failed purging owned boards: $e', name: 'AuthRepository');
      }

      // 3. Check users/{uid}/boards subcollection for any additional owned boards or links
      try {
        final userBoardsSnap = await firestore
            .collection('users')
            .doc(uid)
            .collection('boards')
            .get();
        for (final doc in userBoardsSnap.docs) {
          final data = doc.data();
          if (data['relation'] == 'owned') {
            final boardId = doc.id;
            try {
              final boardRef = firestore.collection('boards').doc(boardId);
              final boardSnap = await boardRef.get();
              if (boardSnap.exists && (boardSnap.data()?['ownerId'] == uid)) {
                final membersSnap = await boardRef.collection('members').get();
                for (final mDoc in membersSnap.docs) {
                  await mDoc.reference.delete();
                }
                final opsSnap = await boardRef.collection('operations').get();
                for (final opDoc in opsSnap.docs) {
                  await opDoc.reference.delete();
                }
                final snapDocs = await boardRef.collection('snapshot').get();
                for (final sDoc in snapDocs.docs) {
                  await sDoc.reference.delete();
                }
                await boardRef.delete();
              }
            } catch (_) {}
          }
          await doc.reference.delete();
        }
      } catch (e) {
        developer.log('Failed purging user boards subcollection: $e', name: 'AuthRepository');
      }

      // 4. Remove user from joined boards / group boards
      // Note: Do not delete canvas elements or edits made in groups; simply remove user from member lists
      try {
        final memberBoardsSnap = await firestore
            .collection('boards')
            .where('members', arrayContains: uid)
            .get();
        for (final doc in memberBoardsSnap.docs) {
          try {
            await doc.reference.update({
              'members': FieldValue.arrayRemove([uid]),
            });
            await doc.reference.collection('members').doc(uid).delete();
          } catch (_) {}
        }
      } catch (e) {
        developer.log('Failed removing from member boards: $e', name: 'AuthRepository');
      }

      // 5. Clean up friends & reciprocal friend lists
      try {
        final friendsSnap = await firestore
            .collection('users')
            .doc(uid)
            .collection('friends')
            .get();
        for (final fDoc in friendsSnap.docs) {
          final friendUid = fDoc.id;
          try {
            await firestore
                .collection('users')
                .doc(friendUid)
                .collection('friends')
                .doc(uid)
                .delete();
            await firestore.collection('users').doc(friendUid).update({
              'friendCount': FieldValue.increment(-1),
            });
          } catch (_) {}
          await fDoc.reference.delete();
        }
      } catch (e) {
        developer.log('Failed purging friends: $e', name: 'AuthRepository');
      }

      // 6. Clean up friend requests (sent & received)
      try {
        final sentReqs = await firestore
            .collection('friend_requests')
            .where('fromUid', isEqualTo: uid)
            .get();
        for (final doc in sentReqs.docs) {
          await doc.reference.delete();
        }
        final recvReqs = await firestore
            .collection('friend_requests')
            .where('toUid', isEqualTo: uid)
            .get();
        for (final doc in recvReqs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        developer.log('Failed purging friend requests: $e', name: 'AuthRepository');
      }

      // 7. Clean up workspaces / groups:
      // Remove user from joined groups and delete workspaces owned by user
      try {
        final ownedWorkspaces = await firestore
            .collection('workspaces')
            .where('ownerId', isEqualTo: uid)
            .get();
        for (final doc in ownedWorkspaces.docs) {
          try {
            final membersSnap = await doc.reference.collection('members').get();
            for (final mDoc in membersSnap.docs) {
              await mDoc.reference.delete();
            }
          } catch (_) {}
          await doc.reference.delete();
        }

        final memberWorkspaces = await firestore
            .collection('workspaces')
            .where('members', arrayContains: uid)
            .get();
        for (final doc in memberWorkspaces.docs) {
          try {
            await doc.reference.update({
              'members': FieldValue.arrayRemove([uid]),
            });
            await doc.reference.collection('members').doc(uid).delete();
          } catch (_) {}
        }
      } catch (e) {
        developer.log('Failed purging workspaces: $e', name: 'AuthRepository');
      }

      // 8. Delete user notifications subcollection
      try {
        final notifsSnap = await firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .get();
        for (final doc in notifsSnap.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        developer.log('Failed purging user notifications: $e', name: 'AuthRepository');
      }

      // 9. Delete user profile document
      try {
        await firestore.collection('users').doc(uid).delete();
      } catch (e) {
        developer.log('Failed deleting user doc: $e', name: 'AuthRepository');
      }

      // 10. Delete Firebase Auth user
      await _authService.deleteAccount();
      developer.log('Successfully deleted Firebase Auth user $uid', name: 'AuthRepository');

    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'This sensitive operation requires recent login. Please log out, sign in again, and retry deleting your account.';
      }
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to delete account: $e';
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Account exists with different credentials.';
      case 'invalid-credential':
        return 'Invalid credential. Check Google sign-in configuration.';
      case 'operation-not-allowed':
        return 'Operation is disabled for this project.';
      case 'user-disabled':
        return "This account has been disabled.";
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
        return "Incorrect password.";
      case 'invalid-email':
        return "Please enter a valid email address.";
      case 'email-already-in-use':
        return "An account already exists with this email address.";
      case 'weak-password':
        return "The password provided is too weak.";
      case 'too-many-requests':
        return "Too many attempts. Please wait a moment and try again.";
      case 'network-request-failed':
        return "Check your internet connection.";
      default:
        return "Authentication failed (${e.code}). Please try again.";
    }
  }
}
