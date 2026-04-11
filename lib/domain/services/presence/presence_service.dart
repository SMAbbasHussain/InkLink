import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/services/auth_service.dart';

class UserPresence {
  final String state;
  final DateTime? lastChanged;

  const UserPresence({required this.state, this.lastChanged});

  bool get isOnline => state == 'online';

  factory UserPresence.offline() {
    return const UserPresence(state: 'offline');
  }

  factory UserPresence.fromSnapshot(DataSnapshot snapshot) {
    final value = snapshot.value;
    if (value is! Map<Object?, Object?>) {
      return UserPresence.offline();
    }

    final state = (value['state']?.toString() ?? 'offline').toLowerCase();
    final rawLastChanged = value['last_changed'];

    DateTime? parsedLastChanged;
    if (rawLastChanged is int) {
      parsedLastChanged = DateTime.fromMillisecondsSinceEpoch(rawLastChanged);
    } else if (rawLastChanged is String) {
      parsedLastChanged = DateTime.tryParse(rawLastChanged);
    }

    return UserPresence(
      state: state == 'online' ? 'online' : 'offline',
      lastChanged: parsedLastChanged,
    );
  }
}

abstract class PresenceService {
  Future<void> setUserOnline();
  Future<void> setUserOffline();
  Stream<UserPresence> watchUserPresence(String uid);
  Future<void> dispose();
}

class PresenceServiceImpl implements PresenceService {
  final FirebaseDatabase _database;
  final AuthService _authService;

  StreamSubscription<DatabaseEvent>? _connectedSubscription;

  PresenceServiceImpl({
    required AuthService authService,
    FirebaseDatabase? database,
  }) : _authService = authService,
       _database = database ?? FirebaseDatabase.instance;

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

      _connectedSubscription = _database.ref('.info/connected').onValue.listen((
        event,
      ) async {
        final connected = event.snapshot.value == true;
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
      final userPresenceRef = _database.ref('presence/$uid');
      await userPresenceRef.onDisconnect().cancel();
      await userPresenceRef.set(_offlinePayload());

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

    return _database.ref('presence/$normalizedUid').onValue.map((event) {
      return UserPresence.fromSnapshot(event.snapshot);
    });
  }

  @override
  Future<void> dispose() async {
    await _connectedSubscription?.cancel();
    _connectedSubscription = null;
  }

  Future<void> _armOnDisconnectAndMarkOnline(String uid) async {
    final userPresenceRef = _database.ref('presence/$uid');
    await userPresenceRef.onDisconnect().set(_offlinePayload());
    await userPresenceRef.set(_onlinePayload());
  }

  Map<String, dynamic> _onlinePayload() {
    return {'state': 'online', 'last_changed': ServerValue.timestamp};
  }

  Map<String, dynamic> _offlinePayload() {
    return {'state': 'offline', 'last_changed': ServerValue.timestamp};
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
