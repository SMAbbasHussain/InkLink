import 'package:isar_community/isar.dart';

part 'local_chat_message.g.dart';

@collection
class LocalChatMessage {
  Id? id;

  @Index(unique: true, replace: true)
  String messageId = '';

  @Index()
  String conversationId = '';

  String senderId = '';
  String senderName = '';
  String? senderAvatar;

  String type = 'text';
  String content = '';

  @Index()
  DateTime timestamp = DateTime.now();

  String status = 'sent';
  String? reactionsJson;

  bool isEdited = false;
  bool isDeleted = false;

  int? fileSize;
  String? fileName;
  String? sharePayloadJson;

  String? replyToId;
  String? replyToSender;
  String? replyToText;
}
