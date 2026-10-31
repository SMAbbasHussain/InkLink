import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/stream_registry.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/utils/helpers.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../repositories/canvas/canvas_sync_repository.dart';
import '../presence/presence_service.dart';

// Re-exported so feature blocs can reference the enum without importing
// core services directly (see tool/architecture_guardrails.dart).
export '../../../core/services/auth_service.dart' show EmailVerificationStatus;

abstract class AuthSessionService {
  Stream<User?> get user;
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String name, String email, String password);
  Future<User?> signInWithGoogle();
  Future<void> onAuthenticated(User user);
  Future<void> signOut();
  User? get currentUser;
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified();
  Future<void> deleteAccount({String? password});
  Future<void> reauthenticate({String? password});
  void registerPreSignOutCallback(Future<void> Function() callback);
  void unregisterPreSignOutCallback(Future<void> Function() callback);
}

class AuthSessionServiceImpl implements AuthSessionService {
  final AuthRepository _authRepository;
  final AuthService _authService;
  final MessagingService _messagingService;
  final LocalDatabaseService _localDatabaseService;
  final PresenceService _presenceService;
  final CanvasSyncRepository _canvasSyncRepository;
  final CloudFunctionsService? _cloudFunctionsService;
  final List<Future<void> Function()> _preSignOutCallbacks = [];
  bool _tokenRefreshBound = false;
  String? _lastSyncedToken;
  StreamSubscription<String>? _tokenRefreshSub;

  AuthSessionServiceImpl({
    required AuthRepository authRepository,
    required AuthService authService,
    required MessagingService messagingService,
    required LocalDatabaseService localDatabaseService,
    required PresenceService presenceService,
    required CanvasSyncRepository canvasSyncRepository,
    CloudFunctionsService? cloudFunctionsService,
  }) : _authRepository = authRepository,
       _authService = authService,
       _messagingService = messagingService,
       _localDatabaseService = localDatabaseService,
       _presenceService = presenceService,
       _canvasSyncRepository = canvasSyncRepository,
       _cloudFunctionsService = cloudFunctionsService;

  @override
  Stream<User?> get user => _authRepository.user;

  @override
  User? get currentUser => _authService.getCurrentUser();

  @override
  Future<User?> signIn(String email, String password) {
    return _authRepository.signIn(email, password);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _authRepository.sendPasswordResetEmail(email);
  }

  @override
  Future<void> sendEmailVerification() {
    return _authRepository.sendEmailVerification();
  }

  @override
  Future<EmailVerificationStatus> reloadAndCheckEmailVerified() {
    return _authRepository.reloadAndCheckEmailVerified();
  }

  @override
  Future<User?> signUp(String name, String email, String password) async {
    await _authRepository.enableNetwork();
    final user = await _authRepository.signUp(name, email, password);
    if (user == null) return null;

    await user.updateDisplayName(name);
    await _upsertUserProfile(user, displayName: name);

    // FR01-05: Automatically dispatch email verification upon registration
    try {
      await _authRepository.sendEmailVerification();
      developer.log('Initial email verification dispatched to ${user.email}', name: 'AuthSessionService');
    } catch (e) {
      developer.log('Initial email verification dispatch warning: $e', name: 'AuthSessionService', error: e);
    }

    return user;
  }

  @override
  Future<User?> signInWithGoogle() async {
    await _authRepository.enableNetwork();
    final user = await _authRepository.signInWithGoogle();
    if (user == null) return null;

    await _upsertUserProfile(user, displayName: user.displayName);
    return user;
  }

  @override
  Future<void> onAuthenticated(User user) async {
    developer.log('onAuthenticated: uid=${user.uid}', name: 'AuthSessionService');
    // Restore Firestore and RTDB connectivity (was disabled during sign-out).
    await _authRepository.enableNetwork();
    developer.log('enableNetwork done', name: 'AuthSessionService');
    unawaited(_presenceService.setUserOnline());
    developer.log('setUserOnline done', name: 'AuthSessionService');
    unawaited(_syncFcmToken());
    developer.log('syncFcmToken done', name: 'AuthSessionService');
  }

  @override
  void registerPreSignOutCallback(Future<void> Function() callback) {
    if (!_preSignOutCallbacks.contains(callback)) {
      _preSignOutCallbacks.add(callback);
    }
  }

  @override
  void unregisterPreSignOutCallback(Future<void> Function() callback) {
    _preSignOutCallbacks.remove(callback);
  }

  @override
  Future<void> signOut() async {
    developer.log('signOut: start', name: 'AuthSessionService');

    // Tear down all registered stream listeners/blocs BEFORE signing out
    // of Firebase Auth, while the auth token is still valid.
    for (final callback in List.of(_preSignOutCallbacks)) {
      try {
        await callback();
      } catch (e, st) {
        developer.log(
          'Error running pre-signout callback: $e',
          name: 'AuthSessionService',
          error: e,
          stackTrace: st,
        );
      }
    }

    final current = _authService.getCurrentUser();
    if (current != null) {
      await _presenceService.setUserOffline();

      String? token;
      try {
        token = await _messagingService.getToken();
      } catch (_) {
        token = null;
      }

      try {
        await _authRepository.removeFcmTokenOnSignOut(
          current.uid,
          token: token,
        );
      } catch (_) {
        // Logout must continue even when FCM is unavailable.
      }

      try {
        await _messagingService.deleteToken();
      } catch (_) {
        // Ignore FCM cleanup failures on devices without Google Play services.
      }
    }

    // Cancel FCM token refresh listener to prevent leaks.
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _tokenRefreshBound = false;

    // Explicitly inform server of logout so it can clear server-side queues,
    // then disconnect locally. Do not fail sign-out if logout handshake fails.
    try {
      await _canvasSyncRepository.logoutSocket();
    } catch (_) {}
    await _canvasSyncRepository.disconnectSocket();

    // Clear cached shared stream references.
    StreamRegistry.instance.clearAll();

    // Disable Firestore network and take RTDB offline.
    await _authRepository.disableNetwork();
    developer.log('disableNetwork done', name: 'AuthSessionService');

    developer.log('signOut: calling _authRepository.signOut()', name: 'AuthSessionService');
    await _authRepository.signOut();
    developer.log('signOut: FirebaseAuth.signOut done', name: 'AuthSessionService');
    await _localDatabaseService.clearLocalCache();
    _lastSyncedToken = null;
    developer.log('signOut: complete', name: 'AuthSessionService');
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    developer.log('deleteAccount: start', name: 'AuthSessionService');

    // Run pre-signout callbacks
    // 1. Reauthenticate first to validate user credentials before any destructive action
    await _authRepository.reauthenticate(password: password);

    for (final callback in List.of(_preSignOutCallbacks)) {
      try {
        await callback();
      } catch (e, st) {
        developer.log(
          'Error running pre-signout callback during account deletion: $e',
          name: 'AuthSessionService',
          error: e,
          stackTrace: st,
        );
      }
    }

    final current = _authService.getCurrentUser();
    bool cloudDeleted = false;
    if (current != null) {
      try {
        await _presenceService.setUserOffline();
      } catch (_) {}

      // Attempt to invoke deleteUserAccount Cloud Function with a short 3s timeout
      if (_cloudFunctionsService != null) {
        try {
          await _cloudFunctionsService
              .httpsCallable('deleteUserAccount')
              .call()
              .timeout(const Duration(seconds: 3));
          cloudDeleted = true;
          developer.log('deleteUserAccount Cloud Function succeeded', name: 'AuthSessionService');
        } catch (e) {
          developer.log('deleteUserAccount Cloud Function skipped or timed out: $e', name: 'AuthSessionService');
        }
      }
    }

    // Cancel FCM token refresh
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _tokenRefreshBound = false;

    try {
      await _canvasSyncRepository.logoutSocket();
    } catch (_) {}
    await _canvasSyncRepository.disconnectSocket();
    StreamRegistry.instance.clearAll();

    // If Cloud Function did not delete the user account, use client-side cascade deletion (skipping re-auth since already verified)
    if (!cloudDeleted) {
      await _authRepository.deleteAccount(password: password, reauthenticateUser: false);
    }

    // Disable network listeners now that user and data are deleted
    await _authRepository.disableNetwork();

    await _localDatabaseService.clearLocalCache(clearChats: true);
    _lastSyncedToken = null;
    developer.log('deleteAccount: complete', name: 'AuthSessionService');
  }

  @override
  Future<void> reauthenticate({String? password}) {
    return _authRepository.reauthenticate(password: password);
  }

  Future<void> _syncFcmToken() async {
    final current = _authService.getCurrentUser();
    if (current == null) return;

    try {
      await _messagingService.requestPermission();
    } catch (_) {
      return;
    }

    String? token;
    try {
      token = await _messagingService.getToken();
    } catch (_) {
      return;
    }
    if (token != null && token.isNotEmpty && _lastSyncedToken != token) {
      try { await _authRepository.syncFcmToken(current.uid, token); _lastSyncedToken = token; } catch (e, st) { developer.log('Failed to sync FCM token: $e', name: 'AuthSessionService', error: e, stackTrace: st); }
      _lastSyncedToken = token;
    }

    if (_tokenRefreshBound) return;
    _tokenRefreshBound = true;
    _tokenRefreshSub = _messagingService.onTokenRefresh.listen((newToken) async {
      final user = _authService.getCurrentUser();
      if (user == null || newToken.isEmpty || _lastSyncedToken == newToken) {
        return;
      }

      try { await _authRepository.syncFcmToken(user.uid, newToken); _lastSyncedToken = newToken; } catch (e, st) { developer.log('Failed to sync refreshed FCM token: $e', name: 'AuthSessionService', error: e, stackTrace: st); }
      _lastSyncedToken = newToken;
    });
  }

  Future<void> _upsertUserProfile(User user, {String? displayName}) async {
    final existingData = await _authRepository.getUserData(user.uid);

    final finalName =
        (existingData?['displayName'] as String?) ??
        displayName ??
        user.displayName ??
        'InkLink Creator';

    await _authRepository.upsertUserProfile(
      uid: user.uid,
      email: user.email,
      displayName: finalName,
      photoURL: user.photoURL ?? '',
      searchKeywords: generateSearchKeywords(finalName),
      isNewUser: existingData == null,
    );
  }
}
