import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';

/// Refreshed group metadata and roster fetched from the chat backend.
class SyncedGroupInfo {
  final String groupId;
  final String? name;
  final String? avatarUrl;
  final String? description;
  final String? ownerId;
  final List<String> adminIds;
  final List<String> memberIds;
  final bool adminsProvided;
  final bool membersProvided;
  final bool includeCurrentUser;
  final DateTime? activityTimestamp;

  const SyncedGroupInfo({
    required this.groupId,
    this.name,
    this.avatarUrl,
    this.description,
    this.ownerId,
    this.adminIds = const [],
    this.memberIds = const [],
    this.adminsProvided = true,
    this.membersProvided = true,
    this.includeCurrentUser = true,
    this.activityTimestamp,
  });
}

/// Repository abstraction over local chat persistence (Isar) and cached profile
/// metadata so domain services never access `LocalDatabaseService` directly.
abstract class ChatRepository {
  /// Ensures a direct-message conversation row exists for ([currentUid], [peerUid])
  /// without fabricating a recent activity timestamp when no messages exist.
  Future<void> ensureDmConversationExists({
    required String currentUid,
    required String peerUid,
    String? name,
    String? avatarUrl,
    DateTime? activityTimestamp,
  });

  /// Mirrors refreshed group metadata and replaces stale cached rosters with
  /// authoritative server membership.
  Future<void> ingestGroups({
    required String currentUid,
    required List<SyncedGroupInfo> groups,
    bool pruneMissingServerGroups = false,
  });

  /// Returns all conversations visible to [currentUid], ordered with active
  /// conversations descending by `updatedAt` and empty conversations last.
  Future<List<ChatConversationModel>> getConversations({
    required String currentUid,
    bool Function(String peerUid)? isOnlineResolver,
  });

  /// Returns all messages authorized for ([currentUid], [conversationId]),
  /// ordered chronologically.
  Future<List<ChatMessageModel>> getMessagesForThread({
    required String currentUid,
    required String conversationId,
  });

  /// Persists or updates [model] under [currentUid]'s local store and updates
  /// the corresponding conversation snippet.
  Future<void> persistMessage({
    required String currentUid,
    required ChatMessageModel model,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    bool countUnread = true,
  });

  /// Updates delivery/send/read status for [messageId] (with optional fallback
  /// [fallbackMessageId]) and returns the unwrapped conversation ID if found.
  Future<String?> updateMessageStatus({
    required String currentUid,
    required String messageId,
    String? fallbackMessageId,
    required ChatMessageStatus status,
    String? conversationId,
  });

  /// Marks all non-read outgoing messages from [currentUid] in [conversationId]
  /// as `read`.
  Future<void> markOutgoingMessagesAsRead({
    required String currentUid,
    required String conversationId,
  });

  /// Marks [messageId] as recalled/deleted locally.
  Future<void> markMessageRecalled({
    required String currentUid,
    required String messageId,
  });

  /// Updates content and sets `isEdited = true` for [messageId].
  Future<void> updateMessageContent({
    required String currentUid,
    required String messageId,
    required String newContent,
  });

  /// Replaces the reactions map on [messageId].
  Future<void> setMessageReactions({
    required String currentUid,
    required String messageId,
    required Map<String, List<String>> reactions,
  });

  /// Adds or replaces [reactorUid]'s reaction [emoji] on [messageId].
  /// Returns affected conversation/sender IDs for UI notification.
  Future<({String? conversationId, String? senderId})> addReactionLocally({
    required String currentUid,
    required String messageId,
    required String reactorUid,
    required String emoji,
  });

  /// Removes [reactorUid]'s reaction [emoji] from [messageId].
  /// Returns affected conversation/sender IDs for UI notification.
  Future<({String? conversationId, String? senderId})> removeReactionLocally({
    required String currentUid,
    required String messageId,
    required String reactorUid,
    required String emoji,
  });

  /// Resets unread count to 0 for ([currentUid], [conversationId]).
  Future<void> markConversationAsRead({
    required String currentUid,
    required String conversationId,
  });

  /// Deletes the local conversation and all of its messages for ([currentUid], [conversationId]).
  Future<void> deleteConversation({
    required String currentUid,
    required String conversationId,
  });

  /// Flips `isMuted` for ([currentUid], [conversationId]).
  Future<void> toggleMuteConversation({
    required String currentUid,
    required String conversationId,
  });

  /// Returns local conversation metadata (`name`, `isMuted`, `isGroup`) for
  /// ([currentUid], [conversationId]), or null if none exists.
  Future<ChatConversationModel?> getConversation({
    required String currentUid,
    required String conversationId,
  });

  /// Returns whether [conversationId] is a group conversation for [currentUid].
  Future<bool> isGroupConversation({
    required String currentUid,
    required String conversationId,
  });

  /// Returns unsent (`sending` or `failed`) outgoing messages belonging to [currentUid].
  Future<List<ChatMessageModel>> getQueuedOutgoingMessages({
    required String currentUid,
  });

  /// Creates and persists a group conversation for [currentUid].
  Future<ChatConversationModel> saveCreatedGroup({
    required String currentUid,
    required String groupId,
    required String name,
    required String description,
    required List<String> memberIds,
    String? iconUrl,
    required DateTime createdAt,
  });

  Future<void> updateGroupInfoLocally({
    required String currentUid,
    required String groupId,
    String? name,
    String? description,
    String? iconUrl,
  });

  Future<void> addGroupMembersLocally({
    required String currentUid,
    required String groupId,
    required List<String> memberIds,
  });

  Future<void> removeGroupMemberLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  });

  Future<void> promoteGroupAdminLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  });

  Future<void> demoteGroupAdminLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  });

  Future<void> transferGroupOwnerLocally({
    required String currentUid,
    required String groupId,
    required String newOwnerId,
  });

  Future<void> leaveGroupLocally({
    required String currentUid,
    required String groupId,
  });

  /// Resolves an Agora SDK username back to a known Firebase UID **only** when
  /// a single known Firebase UID unambiguously maps to [agoraUsername].
  /// Returns [agoraUsername] unchanged if zero or multiple distinct Firebase
  /// UIDs map to [agoraUsername].
  Future<String> resolveUniqueUidForAgoraUsername(
    String agoraUsername, {
    required String currentUid,
    String? currentAgoraUsername,
    Iterable<String> additionalCandidates = const [],
  });

  /// Resolves cached member display metadata for [uids].
  Future<Map<String, ChatMemberProfile>> getMemberProfiles(List<String> uids);
}

