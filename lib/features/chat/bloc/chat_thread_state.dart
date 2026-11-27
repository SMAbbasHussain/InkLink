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
  final bool? isOnline;
  final String? partnerAvatarUrl;
  final String? partnerName;

  const ChatThreadLoaded({
    required this.conversationId,
    required this.messages,
    this.isSending = false,
    this.typingUser,
    this.isOnline,
    this.partnerAvatarUrl,
    this.partnerName,
  });

  ChatThreadLoaded copyWith({
    String? conversationId,
    List<ChatMessageModel>? messages,
    bool? isSending,
    String? typingUser,
    bool? isOnline,
    String? partnerAvatarUrl,
    String? partnerName,
  }) {
    return ChatThreadLoaded(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      typingUser: typingUser ?? this.typingUser,
      isOnline: isOnline ?? this.isOnline,
      partnerAvatarUrl: partnerAvatarUrl ?? this.partnerAvatarUrl,
      partnerName: partnerName ?? this.partnerName,
    );
  }
}

class ChatThreadError extends ChatThreadState {
  final String message;
  const ChatThreadError(this.message);
}
