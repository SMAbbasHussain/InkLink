class BoardChatMessage {
  final String id;
  final String boardId;
  final String senderUid;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final int timestamp;

  const BoardChatMessage({
    required this.id,
    required this.boardId,
    required this.senderUid,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boardId': boardId,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory BoardChatMessage.fromMap(Map<String, dynamic> map) {
    return BoardChatMessage(
      id: map['id'] as String? ?? '',
      boardId: map['boardId'] as String? ?? '',
      senderUid: map['senderUid'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Anonymous',
      senderPhotoUrl: map['senderPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
