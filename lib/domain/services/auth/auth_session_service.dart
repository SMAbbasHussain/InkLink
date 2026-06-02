import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/stream_registry.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/utils/helpers.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../repositories/canvas/canvas_sync_repository.dart';
import '../presence/presence_service.dart';

abstract class AuthSessionService {
  Stream<User?> get user;
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String name, String email, String password);
  Future<User?> signInWithGoogle();
  Future<void> onAuthenticated(User user);
  Future<void> signOut();
  User? get currentUser;
}

class AuthSessionServiceImpl implements AuthSessionService {
  final AuthRepository _authRepository;
  final AuthService _authService;
  final MessagingService _messagingService;
  final LocalDatabaseService _localDatabaseService;
  final PresenceService _presenceService;
  final CanvasSyncRepository _canvasSyncRepository;
  final FirebaseDatabase _database;
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
    required FirebaseDatabase database,
  }) : _authRepository = authRepository,
       _authService = authService,
       _messagingService = messagingService,
       _localDatabaseService = localDatabaseService,
       _presenceService = presenceService,
       _canvasSyncRepository = canvasSyncRepository,
       _database = database;

  @override
  Stream<User?> get user => _authRepository.user;

  @override
  User? get currentUser => _authService.getCurrentUser();

  /// Re-enable Firestore & RTDB so that sign-up / sign-in profile upserts
  /// succeed even when the previous session called [signOut] which disables
  /// the network.
  Future<void> _ensureNetworkOnline() async {
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (_) {}
    try {
      await _database.goOnline();
    } catch (_) {}
  }

  @override
  Future<User?> signIn(String email, String password) {
    return _authRepository.signIn(email, password);
  }

  @override
  Future<User?> signUp(String name, String email, String password) async {
    await _ensureNetworkOnline();
    final user = await _authRepository.signUp(name, email, password);
    if (user == null) return null;

    await user.updateDisplayName(name);
    await _upsertUserProfile(user, displayName: name);
    return user;
  }

  @override
  Future<User?> signInWithGoogle() async {
    await _ensureNetworkOnline();
    final user = await _authRepository.signInWithGoogle();
    if (user == null) return null;

    await _upsertUserProfile(user, displayName: user.displayName);
    return user;
  }

  @override
  Future<void> onAuthenticated(User user) async {
    print('[AUTH_SVC] onAuthenticated: uid=${user.uid}');
    // Restore Firestore and RTDB connectivity (was disabled during sign-out).
    try {
      await FirebaseFirestore.instance.enableNetwork();
      print('[AUTH_SVC] enableNetwork done');
    } catch (e) {
      print('[AUTH_SVC] enableNetwork error=$e');
    }
    try {
      await _database.goOnline();
      print('[AUTH_SVC] goOnline done');
    } catch (e) {
      print('[AUTH_SVC] goOnline error=$e');
    }
    await _presenceService.setUserOnline();
    print('[AUTH_SVC] setUserOnline done');
    await _syncFcmToken();
    print('[AUTH_SVC] syncFcmToken done');
  }

  @override
  Future<void> signOut() async {
    print('[AUTH_SVC] signOut: start');
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

    // Disable Firestore network and take RTDB offline — this immediately
    // stops all native listeners so they won't try to re-authenticate (and
    // fail with permission-denied) when the auth token is invalidated below.
    try {
      await FirebaseFirestore.instance.disableNetwork();
      print('[AUTH_SVC] disableNetwork done');
    } catch (e) {
      print('[AUTH_SVC] disableNetwork error=$e');
    }
    try {
      await _database.goOffline();
      print('[AUTH_SVC] goOffline done');
    } catch (e) {
      print('[AUTH_SVC] goOffline error=$e');
    }

    print('[AUTH_SVC] signOut: calling _authRepository.signOut()');
    await _authRepository.signOut();
    print('[AUTH_SVC] signOut: FirebaseAuth.signOut done');
    await _localDatabaseService.clearLocalCache();
    _lastSyncedToken = null;
    print('[AUTH_SVC] signOut: complete');
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
      await _authRepository.syncFcmToken(current.uid, token);
      _lastSyncedToken = token;
    }

    if (_tokenRefreshBound) return;
    _tokenRefreshBound = true;
    _tokenRefreshSub = _messagingService.onTokenRefresh.listen((newToken) async {
      final user = _authService.getCurrentUser();
      if (user == null || newToken.isEmpty || _lastSyncedToken == newToken) {
        return;
      }

      await _authRepository.syncFcmToken(user.uid, newToken);
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
