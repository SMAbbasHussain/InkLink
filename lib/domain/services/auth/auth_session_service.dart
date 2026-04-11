import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/utils/helpers.dart';
import '../../repositories/auth/auth_repository.dart';
import '../presence/presence_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AuthSessionService {
  Stream<User?> get user;
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String name, String email, String password);
  Future<User?> signInWithGoogle();
  Future<void> onAuthenticated(User user);
  Future<void> signOut();
}

class AuthSessionServiceImpl implements AuthSessionService {
  final AuthRepository _authRepository;
  final AuthService _authService;
  final MessagingService _messagingService;
  final LocalDatabaseService _localDatabaseService;
  final PresenceService _presenceService;
  bool _tokenRefreshBound = false;
  String? _lastSyncedToken;

  AuthSessionServiceImpl({
    required AuthRepository authRepository,
    required AuthService authService,
    required MessagingService messagingService,
    required LocalDatabaseService localDatabaseService,
    required PresenceService presenceService,
  }) : _authRepository = authRepository,
       _authService = authService,
       _messagingService = messagingService,
       _localDatabaseService = localDatabaseService,
       _presenceService = presenceService;

  @override
  Stream<User?> get user => _authRepository.user;

  @override
  Future<User?> signIn(String email, String password) {
    return _authRepository.signIn(email, password);
  }

  @override
  Future<User?> signUp(String name, String email, String password) async {
    final user = await _authRepository.signUp(name, email, password);
    if (user == null) return null;

    await user.updateDisplayName(name);
    await _upsertUserProfile(user, displayName: name);
    return user;
  }

  @override
  Future<User?> signInWithGoogle() async {
    final user = await _authRepository.signInWithGoogle();
    if (user == null) return null;

    await _upsertUserProfile(user, displayName: user.displayName);
    return user;
  }

  @override
  Future<void> onAuthenticated(User user) async {
    await _presenceService.setUserOnline();
    await _syncFcmToken();
  }

  @override
  Future<void> signOut() async {
    final current = _authService.getCurrentUser();
    if (current != null) {
      await _presenceService.setUserOffline();

      final token = await _messagingService.getToken();
      final userUpdates = <String, dynamic>{
        'fcmToken': FieldValue.delete(),
        'lastActive': FieldValue.serverTimestamp(),
      };
      if (token != null && token.isNotEmpty) {
        userUpdates['fcmTokens'] = FieldValue.arrayRemove([token]);
      }

      await _authRepository.upsertUserData(current.uid, userUpdates);
      await _messagingService.deleteToken();
    }

    await _authRepository.signOut();
    await _localDatabaseService.clearLocalCache();
    _lastSyncedToken = null;
  }

  Future<void> _syncFcmToken() async {
    final current = _authService.getCurrentUser();
    if (current == null) return;

    await _messagingService.requestPermission();
    final token = await _messagingService.getToken();
    if (token != null && token.isNotEmpty && _lastSyncedToken != token) {
      await _authRepository.upsertUserData(current.uid, {
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActive': FieldValue.serverTimestamp(),
      });
      _lastSyncedToken = token;
    }

    if (_tokenRefreshBound) return;
    _tokenRefreshBound = true;
    _messagingService.onTokenRefresh.listen((newToken) async {
      final user = _authService.getCurrentUser();
      if (user == null || newToken.isEmpty || _lastSyncedToken == newToken) {
        return;
      }

      await _authRepository.upsertUserData(user.uid, {
        'fcmToken': newToken,
        'fcmTokens': FieldValue.arrayUnion([newToken]),
        'lastActive': FieldValue.serverTimestamp(),
      });
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

    await _authRepository.upsertUserData(user.uid, {
      'uid': user.uid,
      'email': user.email,
      'displayName': finalName,
      'photoURL': user.photoURL ?? '',
      'lastActive': FieldValue.serverTimestamp(),
      'searchKeywords': generateSearchKeywords(finalName),
      if (existingData == null) 'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
