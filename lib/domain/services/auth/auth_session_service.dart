import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/utils/helpers.dart';
import '../../repositories/auth/auth_repository.dart';
import '../presence/presence_service.dart';

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
      await _authRepository.removeFcmTokenOnSignOut(current.uid, token: token);
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
      await _authRepository.syncFcmToken(current.uid, token);
      _lastSyncedToken = token;
    }

    if (_tokenRefreshBound) return;
    _tokenRefreshBound = true;
    _messagingService.onTokenRefresh.listen((newToken) async {
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
