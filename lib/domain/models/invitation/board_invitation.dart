import 'package:inklink/core/utils/dynamic_parsing.dart';

class BoardInvitation {
  final String id;
  final String boardId;
  final String boardTitle;
  final String fromUid;
  final String toUid;
  final String senderName;
  final String? senderPic;
  final String status;
  final String targetRole;
  final DateTime timestamp;
  final DateTime? expiresAt;

  const BoardInvitation({
    required this.id,
    required this.boardId,
    required this.boardTitle,
    required this.fromUid,
    required this.toUid,
    required this.senderName,
    this.senderPic,
    this.status = 'pending',
    this.targetRole = 'viewer',
    required this.timestamp,
    this.expiresAt,
  });

  factory BoardInvitation.fromMap(Map<String, dynamic> map, [String? fallbackId]) {
    return BoardInvitation(
      id: (map['id'] ?? map['inviteId'] ?? fallbackId ?? '').toString(),
      boardId: (map['boardId'] ?? '').toString(),
      boardTitle: (map['boardTitle'] ?? 'Untitled Board').toString(),
      fromUid: (map['fromUid'] ?? '').toString(),
      toUid: (map['toUid'] ?? '').toString(),
      senderName: (map['senderName'] ?? 'User').toString(),
      senderPic: map['senderPic']?.toString(),
      status: (map['status'] ?? 'pending').toString(),
      targetRole: (map['targetRole'] ?? 'viewer').toString(),
      timestamp: parseDateTimeValue(map['timestamp']),
      expiresAt: map['expiresAt'] != null ? parseDateTimeValue(map['expiresAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'inviteId': id,
    'boardId': boardId,
    'boardTitle': boardTitle,
    'fromUid': fromUid,
    'toUid': toUid,
    'senderName': senderName,
    'senderPic': senderPic,
    'status': status,
    'targetRole': targetRole,
    'timestamp': timestamp.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
  };

  /// Backwards-compatible map-like access for legacy UI widgets.
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
      case 'inviteId':
        return id;
      case 'boardId':
        return boardId;
      case 'boardTitle':
        return boardTitle;
      case 'fromUid':
        return fromUid;
      case 'toUid':
        return toUid;
      case 'senderName':
        return senderName;
      case 'senderPic':
        return senderPic;
      case 'status':
        return status;
      case 'targetRole':
        return targetRole;
      case 'timestamp':
        return timestamp;
      case 'expiresAt':
        return expiresAt;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardInvitation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
