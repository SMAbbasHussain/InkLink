import '../../../../domain/models/chat/chat_message_model.dart';

abstract class ChatThreadState {
  const ChatThreadState();
}

class ChatThreadInitial extends ChatThreadState {
  const ChatThreadInitial();
}

class ChatThreadLoading extends ChatThreadState {
  const ChatThreadLoading();
}

class ChatThreadLoaded extends ChatThreadState {
  final String conversationId;
  final List<ChatMessageModel> messages;
  final bool isSending;
  final String? typingUser;

  const ChatThreadLoaded({
    required this.conversationId,
    required this.messages,
    this.isSending = false,
    this.typingUser,
  });

  ChatThreadLoaded copyWith({
    String? conversationId,
    List<ChatMessageModel>? messages,
    bool? isSending,
    String? typingUser,
  }) {
    return ChatThreadLoaded(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      typingUser: typingUser ?? this.typingUser,
    );
  }
}

class ChatThreadError extends ChatThreadState {
  final String message;
  const ChatThreadError(this.message);
}
