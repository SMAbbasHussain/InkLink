DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    return (value as dynamic).toDate() as DateTime? ?? DateTime.now();
  } catch (_) {
    return DateTime.now();
  }
}

/// Pure domain entity representing a user profile.
/// Free of database framework dependencies (Isar/Firestore).
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? bio;
  final String? photoURL;
  final int friendCount;
  final int boardCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool? isOnline;
  final DateTime? lastActive;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio,
    this.photoURL,
    this.friendCount = 0,
    this.boardCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isOnline,
    this.lastActive,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      displayName: (data['displayName'] ?? 'User').toString(),
      email: (data['email'] ?? '').toString(),
      bio: data['bio']?.toString(),
      photoURL: data['photoURL']?.toString(),
      friendCount: (data['friendCount'] as num?)?.toInt() ?? 0,
      boardCount: (data['boardCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
      isOnline: data['isOnline'] as bool?,
      lastActive: data['lastActive'] != null ? _parseDate(data['lastActive']) : null,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) =>
      UserModel.fromFirestore(data, uid);

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'photoURL': photoURL,
      'friendCount': friendCount,
      'boardCount': boardCount,
      'updatedAt': updatedAt ?? DateTime.now(),
      'isOnline': isOnline,
      'lastActive': lastActive,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  /// Backwards-compatible map-like access for legacy UI widgets.
  dynamic operator [](String key) {
    switch (key) {
      case 'uid':
        return uid;
      case 'displayName':
        return displayName;
      case 'email':
        return email;
      case 'bio':
        return bio;
      case 'photoURL':
        return photoURL;
      case 'friendCount':
        return friendCount;
      case 'boardCount':
        return boardCount;
      case 'createdAt':
        return createdAt;
      case 'updatedAt':
        return updatedAt;
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
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
