import 'package:isar_community/isar.dart';

part 'local_chat_conversation.g.dart';

@collection
class LocalChatConversation {
  Id? id;

  @Index(unique: true, replace: true)
  String conversationId = '';

  String name = '';
  String? avatarUrl;

  @Index()
  bool isGroup = false;

  String? lastMessage;
  DateTime? lastMessageTimestamp;

  int unreadCount = 0;
  bool isMuted = false;

  List<String> memberIds = [];
  List<String> adminIds = [];
  String? ownerId;
  String? description;

  DateTime updatedAt = DateTime.now();
}
