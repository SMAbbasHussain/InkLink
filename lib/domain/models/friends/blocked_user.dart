class BlockedUser {
  final String blockedUid;
  final String blockerUid;
  final String displayName;
  final String? photoURL;

  const BlockedUser({
    required this.blockedUid,
    required this.blockerUid,
    required this.displayName,
    this.photoURL,
  });

  factory BlockedUser.fromMap(Map<String, dynamic> map) {
    return BlockedUser(
      blockedUid: (map['blockedUid'] ?? map['uid'] ?? '').toString(),
      blockerUid: (map['blockerUid'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'User').toString(),
      photoURL: map['photoURL']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'blockedUid': blockedUid,
    'blockerUid': blockerUid,
    'displayName': displayName,
    'photoURL': photoURL,
  };

  /// Backwards-compatible map-like access for legacy UI widgets.
  dynamic operator [](String key) {
    switch (key) {
      case 'blockedUid':
      case 'uid':
        return blockedUid;
      case 'blockerUid':
        return blockerUid;
      case 'displayName':
        return displayName;
      case 'photoURL':
        return photoURL;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedUser &&
          runtimeType == other.runtimeType &&
          blockedUid == other.blockedUid;

  @override
  int get hashCode => blockedUid.hashCode;
}
