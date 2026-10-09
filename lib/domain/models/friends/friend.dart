DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    return (value as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}

class Friend {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoURL;
  final int friendCount;
  final int boardCount;
  final bool? isOnline;
  final DateTime? lastActive;

  const Friend({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoURL,
    this.friendCount = 0,
    this.boardCount = 0,
    this.isOnline,
    this.lastActive,
  });

  factory Friend.fromMap(Map<String, dynamic> map, [String? fallbackUid]) {
    return Friend(
      uid: (map['uid'] ?? fallbackUid ?? '').toString(),
      displayName: (map['displayName'] ?? 'User').toString(),
      email: map['email']?.toString(),
      photoURL: map['photoURL']?.toString(),
      friendCount: (map['friendCount'] as num?)?.toInt() ?? 0,
      boardCount: (map['boardCount'] as num?)?.toInt() ?? 0,
      isOnline: map['isOnline'] as bool?,
      lastActive: _parseDate(map['lastActive']),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoURL': photoURL,
    'friendCount': friendCount,
    'boardCount': boardCount,
    'isOnline': isOnline,
    'lastActive': lastActive?.toIso8601String(),
  };

  /// Backwards-compatible map-like access for legacy UI widgets.
  dynamic operator [](String key) {
    switch (key) {
      case 'uid':
        return uid;
      case 'displayName':
        return displayName;
      case 'email':
        return email;
      case 'photoURL':
        return photoURL;
      case 'friendCount':
        return friendCount;
      case 'boardCount':
        return boardCount;
      case 'isOnline':
        return isOnline;
      case 'lastActive':
        return lastActive;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
