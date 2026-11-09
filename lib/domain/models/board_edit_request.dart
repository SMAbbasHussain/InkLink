import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's request for edit permissions on a board.
class BoardEditRequest {
  final String id;
  final String boardId;
  final String boardTitle;
  final String requesterUid;
  final String requesterName;
  final String? requesterPhotoUrl;
  final String message;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;

  const BoardEditRequest({
    required this.id,
    required this.boardId,
    required this.boardTitle,
    required this.requesterUid,
    required this.requesterName,
    this.requesterPhotoUrl,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  factory BoardEditRequest.fromNotificationMap(
    Map<String, dynamic> map, {
    String fallbackBoardId = '',
  }) {
    final extraData = map['extraData'] is Map
        ? (map['extraData'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final boardId = extraData['boardId']?.toString() ??
        map['targetId']?.toString() ??
        fallbackBoardId;

    final boardTitle = extraData['boardTitle']?.toString() ??
        map['title']?.toString() ??
        'Board';

    final requesterUid = extraData['requesterUid']?.toString() ??
        map['fromUid']?.toString() ??
        map['senderUid']?.toString() ??
        '';

    final requesterName = extraData['requesterName']?.toString() ??
        map['senderName']?.toString() ??
        'InkLink User';

    final requesterPhotoUrl =
        map['senderPic']?.toString() ?? map['senderPhotoUrl']?.toString();

    final message = extraData['message']?.toString() ?? '';
    final status = map['status']?.toString() ?? 'pending';

    DateTime createdAt = DateTime.now();
    final rawTimestamp = map['timestamp'];
    if (rawTimestamp is Timestamp) {
      createdAt = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      createdAt = rawTimestamp;
    } else if (rawTimestamp is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is String) {
      createdAt = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    }

    return BoardEditRequest(
      id: map['id']?.toString() ?? '',
      boardId: boardId,
      boardTitle: boardTitle,
      requesterUid: requesterUid,
      requesterName: requesterName,
      requesterPhotoUrl: requesterPhotoUrl,
      message: message,
      status: status,
      createdAt: createdAt,
    );
  }
}

