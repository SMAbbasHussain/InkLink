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

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String senderName;
  final String? senderPic;
  final String? recipientName;
  final String? recipientPic;
  final String status;
  final DateTime timestamp;

  const FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.senderName,
    this.senderPic,
    this.recipientName,
    this.recipientPic,
    this.status = 'pending',
    required this.timestamp,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    return FriendRequest(
      id: (map['id'] ?? map['requestId'] ?? fallbackId ?? '').toString(),
      fromUid: (map['fromUid'] ?? '').toString(),
      toUid: (map['toUid'] ?? '').toString(),
      senderName: (map['senderName'] ?? 'User').toString(),
      senderPic: map['senderPic']?.toString(),
      recipientName: map['recipientName']?.toString(),
      recipientPic: map['recipientPic']?.toString(),
      status: (map['status'] ?? 'pending').toString(),
      timestamp: _parseDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'fromUid': fromUid,
    'toUid': toUid,
    'senderName': senderName,
    'senderPic': senderPic,
    'recipientName': recipientName,
    'recipientPic': recipientPic,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Backwards-compatible map-like access for legacy UI widgets.
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
      case 'requestId':
        return id;
      case 'fromUid':
        return fromUid;
      case 'toUid':
        return toUid;
      case 'senderName':
        return senderName;
      case 'senderPic':
        return senderPic;
      case 'recipientName':
        return recipientName;
      case 'recipientPic':
        return recipientPic;
      case 'status':
        return status;
      case 'timestamp':
        return timestamp;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
