import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../models/chat/chat_share_payload.dart';

/// Chat transport status, driven by the Agora connection lifecycle.
enum ChatConnectionState {
  /// No active login / transport down.
  disconnected,

  /// Connecting or renewing credentials.
  connecting,

  /// Agora transport connected — live delivery and history sync available.
  connected,

  /// Agora is unreachable / unconfigured; the service keeps messages queued
  /// locally (Isar) and drains them automatically once it can connect.
  unavailable,
}

abstract class ChatService {
  Future<void> initialize();
  Future<void> login(String userId);
  Future<void> logout();

  /// Broadcast stream of transport state changes.
  Stream<ChatConnectionState> get connectionState;

  Stream<List<ChatConversationModel>> watchConversations();
  Future<List<ChatConversationModel>> getConversations();
  Future<void> markConversationAsRead(String conversationId);
  Future<void> deleteConversation(String conversationId);
  Future<void> toggleMuteConversation(String conversationId);

  Stream<List<ChatMessageModel>> watchMessages(String conversationId);
  Future<List<ChatMessageModel>> getMessages(String conversationId);

  Future<ChatMessageModel> sendTextMessage({
    required String conversationId,
    required String text,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  });

  Future<ChatMessageModel> sendImageMessage({
    required String conversationId,
    required String filePath,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  });

  Future<ChatMessageModel> sendGifMessage({
    required String conversationId,
    required String gifUrl,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  });

  Future<ChatMessageModel> sendFileMessage({
    required String conversationId,
    required String filePath,
    required String fileName,
    int? fileSize,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  });

  Future<ChatMessageModel> sendShareCardMessage({
    required String conversationId,
    required ChatSharePayload payload,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  });

  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  });

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  // Group Management
  Future<ChatConversationModel> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    String? iconUrl,
  });

  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? iconUrl,
  });

  Future<void> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  });

  Future<void> removeGroupMember({
    required String groupId,
    required String memberId,
  });

  Future<void> promoteAdmin({
    required String groupId,
    required String memberId,
  });

  Future<void> demoteAdmin({
    required String groupId,
    required String memberId,
  });

  Future<void> transferGroupOwner({
    required String groupId,
    required String newOwnerId,
  });

  Future<void> leaveGroup(String groupId);
  Future<void> destroyGroup(String groupId);

  Future<void> dispose();
}
