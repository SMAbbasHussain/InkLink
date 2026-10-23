import 'dart:convert';

enum ChatShareType {
  board,
  workspace;

  static ChatShareType fromString(String? value) {
    if (value == 'workspace') return ChatShareType.workspace;
    return ChatShareType.board;
  }
}

class ChatSharePayload {
  final ChatShareType type;
  final String targetId;
  final String title;
  final String joinCode;
  final String? thumbnailUrl;
  final int memberCount;
  final String? description;

  const ChatSharePayload({
    required this.type,
    required this.targetId,
    required this.title,
    required this.joinCode,
    this.thumbnailUrl,
    this.memberCount = 1,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'shareType': type.name,
      'targetId': targetId,
      'title': title,
      'joinCode': joinCode,
      'thumbnailUrl': thumbnailUrl,
      'memberCount': memberCount,
      'description': description,
    };
  }

  String toJsonString() => jsonEncode(toMap());

  factory ChatSharePayload.fromMap(Map<String, dynamic> map) {
    return ChatSharePayload(
      type: ChatShareType.fromString(map['shareType']?.toString()),
      targetId: map['targetId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled',
      joinCode: map['joinCode']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      memberCount: int.tryParse(map['memberCount']?.toString() ?? '1') ?? 1,
      description: map['description']?.toString(),
    );
  }

  factory ChatSharePayload.fromJsonString(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return ChatSharePayload.fromMap(decoded);
      }
      return ChatSharePayload.fromMap(Map<String, dynamic>.from(decoded as Map));
    } catch (_) {
      return const ChatSharePayload(
        type: ChatShareType.board,
        targetId: '',
        title: 'Unknown',
        joinCode: '',
      );
    }
  }
}
