import 'dart:convert';

class ChatConversationModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isGroup;
  final String? lastMessage;
  final DateTime? lastMessageTimestamp;
  final int unreadCount;
  final bool isMuted;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? ownerId;
  final String? description;
  final bool isOnline;

  const ChatConversationModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isGroup = false,
    this.lastMessage,
    this.lastMessageTimestamp,
    this.unreadCount = 0,
    this.isMuted = false,
    this.memberIds = const [],
    this.adminIds = const [],
    this.ownerId,
    this.description,
    this.isOnline = false,
  });

  bool get isAdmin => false; // Resolved in UI/Service based on current UID

  bool isUserAdmin(String uid) {
    if (ownerId == uid) return true;
    return adminIds.contains(uid);
  }

  bool isUserOwner(String uid) {
    return ownerId == uid;
  }

  ChatConversationModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isGroup,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    int? unreadCount,
    bool? isMuted,
    List<String>? memberIds,
    List<String>? adminIds,
    String? ownerId,
    String? description,
    bool? isOnline,
  }) {
    return ChatConversationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'isGroup': isGroup,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp?.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'isMuted': isMuted,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'ownerId': ownerId,
      'description': description,
      'isOnline': isOnline,
    };
  }

  factory ChatConversationModel.fromMap(Map<String, dynamic> map) {
    return ChatConversationModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Conversation',
      avatarUrl: map['avatarUrl']?.toString(),
      isGroup: map['isGroup'] == true,
      lastMessage: map['lastMessage']?.toString(),
      lastMessageTimestamp: map['lastMessageTimestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              int.parse(map['lastMessageTimestamp'].toString()),
            )
          : null,
      unreadCount: int.tryParse(map['unreadCount']?.toString() ?? '0') ?? 0,
      isMuted: map['isMuted'] == true,
      memberIds: (map['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      adminIds: (map['adminIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      ownerId: map['ownerId']?.toString(),
      description: map['description']?.toString(),
      isOnline: map['isOnline'] == true,
    );
  }

  String toJsonString() => jsonEncode(toMap());
}
