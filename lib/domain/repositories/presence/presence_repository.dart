class PresenceSnapshot {
  final String state;
  final DateTime? lastChanged;

  const PresenceSnapshot({required this.state, this.lastChanged});
}

abstract class PresenceRepository {
  Stream<bool> watchConnectionStatus();
  Future<void> armOnDisconnectOffline(String uid);
  Future<void> cancelOnDisconnect(String uid);
  Future<void> setOnline(String uid);
  Future<void> setOffline(String uid);
  Stream<PresenceSnapshot?> watchUserPresence(String uid);
}
