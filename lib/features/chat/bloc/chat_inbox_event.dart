import '../../../../domain/models/chat/chat_conversation_model.dart';

abstract class ChatInboxEvent {
  const ChatInboxEvent();
}

class LoadChatInbox extends ChatInboxEvent {
  const LoadChatInbox();
}

class ConversationsUpdated extends ChatInboxEvent {
  final List<ChatConversationModel> conversations;
  const ConversationsUpdated(this.conversations);
}

class SearchConversations extends ChatInboxEvent {
  final String query;
  const SearchConversations(this.query);
}

class DeleteConversationRequested extends ChatInboxEvent {
  final String conversationId;
  const DeleteConversationRequested(this.conversationId);
}

class ToggleMuteConversationRequested extends ChatInboxEvent {
  final String conversationId;
  const ToggleMuteConversationRequested(this.conversationId);
}

class MarkConversationReadRequested extends ChatInboxEvent {
  final String conversationId;
  const MarkConversationReadRequested(this.conversationId);
}
