import '../../../../domain/models/chat/chat_conversation_model.dart';

abstract class ChatInboxState {
  const ChatInboxState();
}

class ChatInboxInitial extends ChatInboxState {
  const ChatInboxInitial();
}

class ChatInboxLoading extends ChatInboxState {
  const ChatInboxLoading();
}

class ChatInboxLoaded extends ChatInboxState {
  final List<ChatConversationModel> allConversations;
  final List<ChatConversationModel> filteredConversations;
  final String searchQuery;
  final int totalUnreadCount;

  const ChatInboxLoaded({
    required this.allConversations,
    required this.filteredConversations,
    this.searchQuery = '',
    required this.totalUnreadCount,
  });

  ChatInboxLoaded copyWith({
    List<ChatConversationModel>? allConversations,
    List<ChatConversationModel>? filteredConversations,
    String? searchQuery,
    int? totalUnreadCount,
  }) {
    return ChatInboxLoaded(
      allConversations: allConversations ?? this.allConversations,
      filteredConversations: filteredConversations ?? this.filteredConversations,
      searchQuery: searchQuery ?? this.searchQuery,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }
}

class ChatInboxError extends ChatInboxState {
  final String message;
  const ChatInboxError(this.message);
}
