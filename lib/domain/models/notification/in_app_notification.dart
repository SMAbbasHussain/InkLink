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

class InAppNotification {
  final String id;
  final String uid;
  final DateTime timestamp;
  final String type;
  final String title;
  final String? body;
  final String? targetId;
  final String? senderUid;
  final String? senderDisplayName;
  final String? senderPhotoUrl;
  final bool read;
  final DateTime? readAt;

  const InAppNotification({
    required this.id,
    required this.uid,
    required this.timestamp,
    required this.type,
    required this.title,
    this.body,
    this.targetId,
    this.senderUid,
    this.senderDisplayName,
    this.senderPhotoUrl,
    this.read = false,
    this.readAt,
  });

  factory InAppNotification.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    return InAppNotification(
      id: (map['id'] ?? map['notificationId'] ?? fallbackId ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      timestamp: _parseDate(map['timestamp']),
      type: (map['type'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: map['body']?.toString(),
      targetId: map['targetId']?.toString(),
      senderUid: map['senderUid']?.toString(),
      senderDisplayName: map['senderDisplayName']?.toString(),
      senderPhotoUrl: map['senderPhotoUrl']?.toString(),
      read: (map['read'] as bool?) ?? false,
      readAt: map['readAt'] != null ? _parseDate(map['readAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    'title': title,
    'body': body,
    'targetId': targetId,
    'senderUid': senderUid,
    'senderDisplayName': senderDisplayName,
    'senderPhotoUrl': senderPhotoUrl,
    'read': read,
    'readAt': readAt?.toIso8601String(),
  };

  /// Backwards-compatible map-like access for legacy UI widgets.
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
      case 'notificationId':
        return id;
      case 'uid':
        return uid;
      case 'timestamp':
        return timestamp;
      case 'type':
        return type;
      case 'title':
        return title;
      case 'body':
        return body;
      case 'targetId':
        return targetId;
      case 'senderUid':
        return senderUid;
      case 'senderDisplayName':
        return senderDisplayName;
      case 'senderPhotoUrl':
        return senderPhotoUrl;
      case 'read':
        return read;
      case 'readAt':
        return readAt;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
