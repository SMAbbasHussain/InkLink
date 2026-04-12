import 'package:firebase_database/firebase_database.dart';

import 'presence_repository.dart';

class FirebasePresenceRepository implements PresenceRepository {
  final FirebaseDatabase _database;

  FirebasePresenceRepository({required FirebaseDatabase database})
    : _database = database;

  @override
  Stream<bool> watchConnectionStatus() {
    return _database
        .ref('.info/connected')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  @override
  Future<void> armOnDisconnectOffline(String uid) {
    return _database.ref('presence/$uid').onDisconnect().set(_offlinePayload());
  }

  @override
  Future<void> cancelOnDisconnect(String uid) {
    return _database.ref('presence/$uid').onDisconnect().cancel();
  }

  @override
  Future<void> setOnline(String uid) {
    return _database.ref('presence/$uid').set(_onlinePayload());
  }

  @override
  Future<void> setOffline(String uid) {
    return _database.ref('presence/$uid').set(_offlinePayload());
  }

  @override
  Stream<PresenceSnapshot?> watchUserPresence(String uid) {
    return _database.ref('presence/$uid').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map<Object?, Object?>) {
        return null;
      }

      final state = (value['state']?.toString() ?? 'offline').toLowerCase();
      final rawLastChanged = value['last_changed'];

      DateTime? lastChanged;
      if (rawLastChanged is int) {
        lastChanged = DateTime.fromMillisecondsSinceEpoch(rawLastChanged);
      } else if (rawLastChanged is String) {
        lastChanged = DateTime.tryParse(rawLastChanged);
      }

      return PresenceSnapshot(
        state: state == 'online' ? 'online' : 'offline',
        lastChanged: lastChanged,
      );
    });
  }

  Map<String, dynamic> _onlinePayload() {
    return {'state': 'online', 'last_changed': ServerValue.timestamp};
  }

  Map<String, dynamic> _offlinePayload() {
    return {'state': 'offline', 'last_changed': ServerValue.timestamp};
  }
}
