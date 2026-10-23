import '../../../../domain/models/chat/chat_message_model.dart';
import '../../../../domain/models/chat/chat_share_payload.dart';

abstract class ChatThreadEvent {
  const ChatThreadEvent();
}

class LoadChatThread extends ChatThreadEvent {
  final String conversationId;
  const LoadChatThread(this.conversationId);
}

class MessagesUpdated extends ChatThreadEvent {
  final List<ChatMessageModel> messages;
  const MessagesUpdated(this.messages);
}

class SendTextMessageRequested extends ChatThreadEvent {
  final String text;
  final bool isGroup;
  final String? conversationName;
  final String? conversationAvatar;

  const SendTextMessageRequested({
    required this.text,
    this.isGroup = false,
    this.conversationName,
    this.conversationAvatar,
  });
}

class SendImageMessageRequested extends ChatThreadEvent {
  final String filePath;
  final bool isGroup;
  final String? conversationName;
  final String? conversationAvatar;

  const SendImageMessageRequested({
    required this.filePath,
    this.isGroup = false,
    this.conversationName,
    this.conversationAvatar,
  });
}

class SendGifMessageRequested extends ChatThreadEvent {
  final String gifUrl;
  final bool isGroup;
  final String? conversationName;
  final String? conversationAvatar;

  const SendGifMessageRequested({
    required this.gifUrl,
    this.isGroup = false,
    this.conversationName,
    this.conversationAvatar,
  });
}

class SendFileMessageRequested extends ChatThreadEvent {
  final String filePath;
  final String fileName;
  final int? fileSize;
  final bool isGroup;
  final String? conversationName;
  final String? conversationAvatar;

  const SendFileMessageRequested({
    required this.filePath,
    required this.fileName,
    this.fileSize,
    this.isGroup = false,
    this.conversationName,
    this.conversationAvatar,
  });
}

class SendShareCardRequested extends ChatThreadEvent {
  final ChatSharePayload payload;
  final bool isGroup;
  final String? conversationName;
  final String? conversationAvatar;

  const SendShareCardRequested({
    required this.payload,
    this.isGroup = false,
    this.conversationName,
    this.conversationAvatar,
  });
}

class ToggleReactionRequested extends ChatThreadEvent {
  final String messageId;
  final String emoji;
  const ToggleReactionRequested({required this.messageId, required this.emoji});
}

class EditMessageRequested extends ChatThreadEvent {
  final String messageId;
  final String newContent;
  const EditMessageRequested({required this.messageId, required this.newContent});
}

class DeleteMessageRequested extends ChatThreadEvent {
  final String messageId;
  const DeleteMessageRequested(this.messageId);
}
