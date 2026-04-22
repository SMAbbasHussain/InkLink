import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';

import '../../../core/services/auth_service.dart';
import '../../repositories/presence/presence_repository.dart';

class UserPresence {
  final String state;
  final DateTime? lastChanged;

  const UserPresence({required this.state, this.lastChanged});

  bool get isOnline => state == 'online';

  factory UserPresence.offline() {
    return const UserPresence(state: 'offline');
  }
}

abstract class PresenceService {
  Future<void> setUserOnline();
  Future<void> setUserOffline();
  Stream<UserPresence> watchUserPresence(String uid);
  Future<void> dispose();
}

class PresenceServiceImpl implements PresenceService {
  final PresenceRepository _presenceRepository;
  final AuthService _authService;

  StreamSubscription<bool>? _connectedSubscription;

  PresenceServiceImpl({
    required PresenceRepository presenceRepository,
    required AuthService authService,
  }) : _presenceRepository = presenceRepository,
       _authService = authService;

  @override
  Future<void> setUserOnline() async {
    final uid = _authService.getCurrentUserId();
    if (uid == null || uid.isEmpty) {
      developer.log(
        'Presence skipped: setUserOnline called without authenticated uid',
        name: 'PresenceService',
      );
      return;
    }

    try {
      await _connectedSubscription?.cancel();

      await _armOnDisconnectAndMarkOnline(uid);

      _connectedSubscription = _presenceRepository
          .watchConnectionStatus()
          .listen((connected) async {
            if (!connected) return;
            await _armOnDisconnectAndMarkOnline(uid);
          });
    } catch (e, st) {
      _logPresenceFailure(
        action: 'setUserOnline',
        uid: uid,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> setUserOffline() async {
    final uid = _authService.getCurrentUserId();
    if (uid == null || uid.isEmpty) {
      developer.log(
        'Presence skipped: setUserOffline called without authenticated uid',
        name: 'PresenceService',
      );
      return;
    }

    try {
      await _presenceRepository.cancelOnDisconnect(uid);
      await _presenceRepository.setOffline(uid);

      await _connectedSubscription?.cancel();
      _connectedSubscription = null;
    } catch (e, st) {
      _logPresenceFailure(
        action: 'setUserOffline',
        uid: uid,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<UserPresence> watchUserPresence(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return Stream<UserPresence>.value(UserPresence.offline());
    }

    return _presenceRepository.watchUserPresence(normalizedUid).map((snapshot) {
      if (snapshot == null) {
        return UserPresence.offline();
      }

      return UserPresence(
        state: snapshot.state,
        lastChanged: snapshot.lastChanged,
      );
    });
  }

  @override
  Future<void> dispose() async {
    await _connectedSubscription?.cancel();
    _connectedSubscription = null;
  }

  Future<void> _armOnDisconnectAndMarkOnline(String uid) async {
    await _presenceRepository.armOnDisconnectOffline(uid);
    await _presenceRepository.setOnline(uid);
  }

  void _logPresenceFailure({
    required String action,
    required String uid,
    required Object error,
    StackTrace? stackTrace,
  }) {
    final isPermissionDenied =
        error is FirebaseException &&
        (error.code == 'permission-denied' ||
            error.message?.toLowerCase().contains('permission denied') == true);

    final hint = isPermissionDenied
        ? 'RTDB denied $action for uid=$uid. Check deployed database rules and ensure FirebaseAuth session matches the same Firebase project/database URL.'
        : '$action failed for uid=$uid: $error';

    developer.log(
      hint,
      name: 'PresenceService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
