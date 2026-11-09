import 'dart:async';
import 'dart:convert';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/models/chat/chat_conversation_model.dart';
import 'package:inklink/domain/models/chat/chat_message_model.dart';
import 'package:inklink/domain/repositories/chat/chat_repository.dart';
import 'package:inklink/domain/repositories/chat/chat_repository_impl.dart';
import 'package:inklink/domain/services/chat/agora_chat_service.dart';
import 'package:inklink/domain/services/chat/chat_service.dart';

class _FakeAuthService implements AuthService {
  String? currentUid;
  Future<String?> Function(String? uid)? tokenHook;

  _FakeAuthService({this.currentUid});

  @override
  String? getCurrentUserId() => currentUid;

  @override
  User? getCurrentUser() => null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (tokenHook != null) return tokenHook!(currentUid);
    final uid = currentUid;
    return uid == null ? null : 'id-token-$uid';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConversationHandle implements AgoraConversationHandle {
  @override
  final String id;

  @override
  final ChatConversationType type;

  final List<ChatMessage> localMessages;

  _FakeConversationHandle({
    required this.id,
    this.type = ChatConversationType.Chat,
    List<ChatMessage>? localMessages,
  }) : localMessages = localMessages ?? [];

  @override
  Future<List<ChatMessage>> loadMessages({
    String startMsgId = '',
    int loadCount = 50,
  }) async {
    // Sort ascending by serverTime like SDK local query semantics:
    // empty startMsgId returns the newest `loadCount` messages; non-empty
    // startMsgId returns up to `loadCount` messages older than `startMsgId`.
    final sorted = List<ChatMessage>.from(localMessages)
      ..sort((a, b) => a.serverTime.compareTo(b.serverTime));
    if (sorted.isEmpty) return [];

    int endExclusive = sorted.length;
    if (startMsgId.isNotEmpty) {
      final idx = sorted.indexWhere((m) => m.msgId == startMsgId);
      if (idx <= 0) return [];
      endExclusive = idx;
    }
    final start = (endExclusive - loadCount).clamp(0, endExclusive);
    return sorted.sublist(start, endExclusive);
  }

  @override
  Future<ChatMessage?> latestMessage() async {
    if (localMessages.isEmpty) return null;
    final sorted = List<ChatMessage>.from(localMessages)
      ..sort((a, b) => a.serverTime.compareTo(b.serverTime));
    return sorted.last;
  }

  @override
  Future<void> markAllMessagesAsRead() async {}

  @override
  Future<void> deleteMessage(String messageId) async {
    localMessages.removeWhere((m) => m.msgId == messageId);
  }
}

class _FakeAgoraSdkGateway implements AgoraChatSdkGateway {
  bool initialized = false;
  bool loggedInBefore = false;
  bool connected = true;
  String? currentUsername;

  int initCalls = 0;
  int startCallbackCalls = 0;
  int logoutCalls = 0;
  final List<({String username, String token})> loginCalls = [];
  final List<String> renewTokenCalls = [];
  int syncConversationFetchCalls = 0;

  Future<void> Function()? onStartCallback;
  Future<void> Function(String username, String token)? onLoginWithToken;
  Future<void> Function(String token)? onRenewAgoraToken;
  Future<void> Function(bool clearDeviceToken)? onLogout;

  ChatEventHandler? chatEventHandler;
  ChatMessageEvent? messageEvent;
  ConnectionEventHandler? connectionEventHandler;
  ChatGroupEventHandler? groupEventHandler;

  List<AgoraConversationHandle> localConversations = [];
  Map<String?, ChatCursorResult<AgoraConversationHandle>> conversationPages = {};
  Map<String, Map<String, ChatCursorResult<ChatMessage>>> historyPages = {};
  Map<int, List<ChatGroup>> joinedGroupPages = {};
  Map<String, ChatGroup> groupDetails = {};
  Map<String, Map<String?, ChatCursorResult<String>>> groupMemberPages = {};

  @override
  Future<void> init(String appKey) async {
    initCalls++;
    initialized = true;
  }

  @override
  Future<void> changeAppKey(String newAppKey) async {}

  @override
  Future<void> updateAckSettings() async {}

  @override
  Future<void> startCallback() async {
    startCallbackCalls++;
    if (onStartCallback != null) {
      await onStartCallback!();
    }
  }

  @override
  void registerHandlers({
    required ChatEventHandler chatEventHandler,
    required ChatMessageEvent messageEvent,
    required ConnectionEventHandler connectionEventHandler,
    required ChatGroupEventHandler groupEventHandler,
  }) {
    this.chatEventHandler = chatEventHandler;
    this.messageEvent = messageEvent;
    this.connectionEventHandler = connectionEventHandler;
    this.groupEventHandler = groupEventHandler;
  }

  @override
  Future<bool> isLoginBefore() async => loggedInBefore;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<String?> getCurrentUsername() async => currentUsername;

  @override
  bool isAlreadyLoggedInError(Object error) =>
      error is ChatError && error.code == 200;

  @override
  Future<void> loginWithToken(String username, String token) async {
    loginCalls.add((username: username, token: token));
    if (onLoginWithToken != null) {
      await onLoginWithToken!(username, token);
      return;
    }
    loggedInBefore = true;
    currentUsername = username;
  }

  @override
  Future<void> renewAgoraToken(String token) async {
    renewTokenCalls.add(token);
    if (onRenewAgoraToken != null) {
      await onRenewAgoraToken!(token);
    }
  }

  @override
  Future<void> logout(bool clearDeviceToken) async {
    logoutCalls++;
    if (onLogout != null) {
      await onLogout!(clearDeviceToken);
      return;
    }
    loggedInBefore = false;
    currentUsername = null;
  }

  @override
  Future<void> bindDeviceToken({
    required String notifierName,
    required String deviceToken,
  }) async {}

  @override
  Future<List<AgoraConversationHandle>> loadAllConversations() async =>
      List.of(localConversations);

  @override
  Future<ChatCursorResult<AgoraConversationHandle>> fetchConversationsPage({
    int pageSize = 50,
    String? cursor,
  }) async {
    syncConversationFetchCalls++;
    return conversationPages[cursor] ?? ChatCursorResult(null, const []);
  }

  @override
  Future<List<AgoraConversationHandle>>
      getConversationsFromServerFallback() async => const [];

  @override
  Future<AgoraConversationHandle?> getConversation(
    String conversationId, {
    required ChatConversationType type,
    bool createIfNeed = true,
  }) async {
    for (final c in localConversations) {
      if (c.id.toLowerCase() == conversationId.toLowerCase() &&
          c.type == type) {
        return c;
      }
    }
    if (!createIfNeed) return null;
    return _FakeConversationHandle(id: conversationId, type: type);
  }

  @override
  Future<void> deleteConversation(
    String conversationId, {
    bool deleteMessages = true,
  }) async {
    localConversations.removeWhere(
      (c) => c.id.toLowerCase() == conversationId.toLowerCase(),
    );
  }

  @override
  Future<ChatCursorResult<ChatMessage>> fetchHistoryMessagesPage({
    required String conversationId,
    required ChatConversationType type,
    int pageSize = 50,
    String startMsgId = '',
  }) async {
    final pagesForConv = historyPages[conversationId.toLowerCase()];
    if (pagesForConv == null) {
      return ChatCursorResult(null, const []);
    }
    return pagesForConv[startMsgId] ?? ChatCursorResult(null, const []);
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) async => message;

  @override
  Future<void> sendConversationReadAck(String conversationId) async {}

  @override
  Future<void> sendMessageReadAck(ChatMessage message) async {}

  @override
  Future<void> addReaction({
    required String messageId,
    required String reaction,
  }) async {}

  @override
  Future<void> removeReaction({
    required String messageId,
    required String reaction,
  }) async {}

  @override
  Future<void> modifyMessage({
    required String messageId,
    required ChatTextMessageBody msgBody,
  }) async {}

  @override
  Future<void> recallMessage(String messageId) async {}

  @override
  Future<List<ChatMessageReaction>> getMessageReactionList(
    ChatMessage message,
  ) async =>
      const [];

  @override
  Future<List<ChatGroup>> fetchJoinedGroupsPage({
    int pageSize = 20,
    int pageNum = 0,
    bool needRole = true,
  }) async {
    return joinedGroupPages[pageNum] ?? const [];
  }

  @override
  Future<ChatGroup> fetchGroupInfoFromServer(String groupId) async {
    final detail = groupDetails[groupId];
    if (detail != null) return detail;
    throw ChatError(404, 'Not found');
  }

  @override
  Future<ChatCursorResult<String>> fetchGroupMembersPage(
    String groupId, {
    int pageSize = 200,
    String? cursor,
  }) async {
    final pages = groupMemberPages[groupId];
    if (pages == null) return ChatCursorResult(null, const []);
    return pages[cursor] ?? ChatCursorResult(null, const []);
  }

  @override
  Future<ChatGroup> createGroup({
    required String groupName,
    String? avatarUrl,
    required String desc,
    required ChatGroupOptions options,
    required List<String> inviteMembers,
  }) async {
    return ChatGroup(groupId: 'grp-created', groupName: groupName, desc: desc);
  }

  @override
  Future<void> updateGroupName(String groupId, String name) async {}

  @override
  Future<void> updateGroupDesc(String groupId, String desc) async {}

  @override
  Future<void> updateGroupAvatar({
    required String groupId,
    required String avatarUrl,
  }) async {}

  @override
  Future<void> addGroupMembers(String groupId, List<String> members) async {}

  @override
  Future<void> removeGroupMembers(String groupId, List<String> members) async {}

  @override
  Future<void> addGroupAdmin(String groupId, String memberId) async {}

  @override
  Future<void> removeGroupAdmin(String groupId, String memberId) async {}

  @override
  Future<void> changeGroupOwner(String groupId, String newOwner) async {}

  @override
  Future<void> leaveGroup(String groupId) async {}

  @override
  Future<void> destroyGroup(String groupId) async {}
}

/// In-memory reference implementation of [ChatRepository] mirroring the exact
/// scoping, exact-UID matching, empty-chat null-timestamp ordering, and
/// roster-replacement semantics of [ChatRepositoryImpl].
class _InMemoryChatRepository implements ChatRepository {
  final Map<String, ({ChatConversationModel conv, DateTime? updatedAt})> _convs =
      {};
  final Map<String, ChatMessageModel> _msgs = {};
  final Map<String, ChatMemberProfile> profiles = {};

  int ensureDmCalls = 0;

  String _convKey(String ownerUid, String id, {required bool isGroup}) =>
      isGroup
          ? ChatRepositoryImpl.groupKey(ownerUid, id)
          : ChatRepositoryImpl.dmKey(ownerUid, id);

  String _msgKey(String ownerUid, String msgId) =>
      ChatRepositoryImpl.msgKey(ownerUid, msgId);

  ({ChatConversationModel conv, DateTime? updatedAt})? _findEntry(
    String currentUid,
    String conversationId,
  ) {
    return _convs[ChatRepositoryImpl.groupKey(currentUid, conversationId)] ??
        _convs[ChatRepositoryImpl.dmKey(currentUid, conversationId)];
  }

  @override
  Future<void> ensureDmConversationExists({
    required String currentUid,
    required String peerUid,
    String? name,
    String? avatarUrl,
    DateTime? activityTimestamp,
  }) async {
    if (currentUid.isEmpty || peerUid.isEmpty || currentUid == peerUid) return;
    ensureDmCalls++;
    final key = _convKey(currentUid, peerUid, isGroup: false);
    final existing = _convs[key];
    if (existing != null) return;
    final profile = profiles[peerUid];
    _convs[key] = (
      conv: ChatConversationModel(
        id: peerUid,
        name: (name != null && name.isNotEmpty)
            ? name
            : (profile?.displayName ?? peerUid),
        avatarUrl: avatarUrl ?? profile?.photoURL,
        lastMessageTimestamp: activityTimestamp,
        isGroup: false,
        memberIds: [currentUid, peerUid],
      ),
      updatedAt: activityTimestamp,
    );
  }

  @override
  Future<void> ingestGroups({
    required String currentUid,
    required List<SyncedGroupInfo> groups,
    bool pruneMissingServerGroups = false,
  }) async {
    final activeIds = <String>{};
    for (final g in groups) {
      if (g.groupId.isEmpty) continue;
      activeIds.add(g.groupId);
      final key = _convKey(currentUid, g.groupId, isGroup: true);
      final existing = _convs[key];
      final ownerId = g.ownerId ?? existing?.conv.ownerId;
      final admins = g.adminsProvided
          ? g.adminIds.where((e) => e.isNotEmpty).toSet().toList()
          : (existing?.conv.adminIds ?? const <String>[]);
      final members = g.membersProvided
          ? <String>{
              ...g.memberIds.where((e) => e.isNotEmpty),
              ...admins,
              if (ownerId != null && ownerId.isNotEmpty) ownerId,
              if (g.includeCurrentUser) currentUid,
            }.toList()
          : (existing?.conv.memberIds ?? <String>[currentUid]);

      final updatedAt = g.activityTimestamp ?? existing?.updatedAt;
      _convs[key] = (
        conv: ChatConversationModel(
          id: g.groupId,
          name: (g.name != null && g.name!.isNotEmpty)
              ? g.name!
              : (existing?.conv.name ?? g.groupId),
          avatarUrl: g.avatarUrl ?? existing?.conv.avatarUrl,
          description: g.description ?? existing?.conv.description,
          lastMessage: existing?.conv.lastMessage,
          lastMessageTimestamp:
              existing?.conv.lastMessageTimestamp ?? g.activityTimestamp,
          unreadCount: existing?.conv.unreadCount ?? 0,
          isGroup: true,
          isMuted: existing?.conv.isMuted ?? false,
          ownerId: ownerId,
          adminIds: admins,
          memberIds: members,
        ),
        updatedAt: updatedAt,
      );
    }

    if (pruneMissingServerGroups) {
      final prefix = 'grp:${currentUid.length}:$currentUid:';
      final staleKeys = _convs.keys.where((k) {
        if (!k.startsWith(prefix)) return false;
        final gid = k.substring(prefix.length);
        return !activeIds.contains(gid);
      }).toList();
      for (final sk in staleKeys) {
        final gid = sk.substring(prefix.length);
        _convs.remove(sk);
        _msgs.removeWhere(
          (mk, m) =>
              mk.startsWith('msg:${currentUid.length}:$currentUid:') &&
              m.conversationId == gid,
        );
      }
    }
  }

  @override
  Future<List<ChatConversationModel>> getConversations({
    required String currentUid,
    bool Function(String peerUid)? isOnlineResolver,
  }) async {
    final dmPrefix = 'dm:${currentUid.length}:$currentUid:';
    final grpPrefix = 'grp:${currentUid.length}:$currentUid:';
    final entries = _convs.entries
        .where((e) => e.key.startsWith(dmPrefix) || e.key.startsWith(grpPrefix))
        .map((e) => e.value)
        .where((entry) {
      if (!entry.conv.isGroup) {
        return entry.conv.id != currentUid &&
            entry.conv.memberIds.contains(currentUid);
      }
      return entry.conv.ownerId == currentUid ||
          entry.conv.adminIds.contains(currentUid) ||
          entry.conv.memberIds.contains(currentUid);
    }).toList();

    entries.sort((a, b) {
      final aTime = a.updatedAt ?? a.conv.lastMessageTimestamp;
      final bTime = b.updatedAt ?? b.conv.lastMessageTimestamp;
      if (aTime != null && bTime != null) {
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }
      return a.conv.name.toLowerCase().compareTo(b.conv.name.toLowerCase());
    });

    return entries
        .map(
          (e) => e.conv.copyWith(
            isOnline:
                e.conv.isGroup ? false : (isOnlineResolver?.call(e.conv.id) ?? false),
          ),
        )
        .toList();
  }

  @override
  Future<List<ChatMessageModel>> getMessagesForThread({
    required String currentUid,
    required String conversationId,
  }) async {
    final prefix = 'msg:${currentUid.length}:$currentUid:';
    final isGroup = await isGroupConversation(
      currentUid: currentUid,
      conversationId: conversationId,
    );
    final list = _msgs.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => e.value)
        .where((m) {
      if (m.conversationId != conversationId) return false;
      if (!isGroup) {
        return m.senderId == currentUid || m.senderId == conversationId;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  @override
  Future<void> persistMessage({
    required String currentUid,
    required ChatMessageModel model,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    bool countUnread = true,
  }) async {
    final mk = _msgKey(currentUid, model.id);
    final isNew = !_msgs.containsKey(mk);
    _msgs[mk] = model;

    final ck = _convKey(currentUid, model.conversationId, isGroup: isGroup);
    final existing = _convs[ck];
    final isIncoming = model.senderId != currentUid;
    final unread = (existing?.conv.unreadCount ?? 0) +
        ((isNew && isIncoming && countUnread) ? 1 : 0);

    final prevTs = existing?.conv.lastMessageTimestamp;
    final shouldAdvance = prevTs == null || !model.timestamp.isBefore(prevTs);

    _convs[ck] = (
      conv: ChatConversationModel(
        id: model.conversationId,
        name: conversationName ??
            existing?.conv.name ??
            profiles[model.conversationId]?.displayName ??
            model.conversationId,
        avatarUrl: conversationAvatar ?? existing?.conv.avatarUrl,
        description: existing?.conv.description,
        lastMessage: shouldAdvance ? model.content : existing?.conv.lastMessage,
        lastMessageTimestamp:
            shouldAdvance ? model.timestamp : existing?.conv.lastMessageTimestamp,
        unreadCount: unread,
        isGroup: isGroup,
        isMuted: existing?.conv.isMuted ?? false,
        ownerId: existing?.conv.ownerId,
        adminIds: existing?.conv.adminIds ?? const [],
        memberIds: existing?.conv.memberIds ??
            (isGroup
                ? <String>[currentUid]
                : <String>[currentUid, model.conversationId]),
      ),
      updatedAt: shouldAdvance ? model.timestamp : existing?.updatedAt,
    );
  }

  @override
  Future<String?> updateMessageStatus({
    required String currentUid,
    required String messageId,
    String? fallbackMessageId,
    required ChatMessageStatus status,
    String? conversationId,
  }) async {
    final k1 = _msgKey(currentUid, messageId);
    final k2 =
        fallbackMessageId != null ? _msgKey(currentUid, fallbackMessageId) : null;
    final targetKey = _msgs.containsKey(k1)
        ? k1
        : (k2 != null && _msgs.containsKey(k2) ? k2 : null);
    if (targetKey == null) return conversationId;
    final existing = _msgs[targetKey]!;
    _msgs[targetKey] = existing.copyWith(status: status);
    return existing.conversationId;
  }

  @override
  Future<void> markOutgoingMessagesAsRead({
    required String currentUid,
    required String conversationId,
  }) async {}

  @override
  Future<void> markMessageRecalled({
    required String currentUid,
    required String messageId,
  }) async {}

  @override
  Future<void> updateMessageContent({
    required String currentUid,
    required String messageId,
    required String newContent,
  }) async {}

  @override
  Future<void> setMessageReactions({
    required String currentUid,
    required String messageId,
    required Map<String, List<String>> reactions,
  }) async {}

  @override
  Future<({String? conversationId, String? senderId})> addReactionLocally({
    required String currentUid,
    required String messageId,
    required String reactorUid,
    required String emoji,
  }) async =>
      (conversationId: null, senderId: null);

  @override
  Future<({String? conversationId, String? senderId})> removeReactionLocally({
    required String currentUid,
    required String messageId,
    required String reactorUid,
    required String emoji,
  }) async =>
      (conversationId: null, senderId: null);

  @override
  Future<void> markConversationAsRead({
    required String currentUid,
    required String conversationId,
  }) async {}

  @override
  Future<void> deleteConversation({
    required String currentUid,
    required String conversationId,
  }) async {
    _convs.remove(ChatRepositoryImpl.dmKey(currentUid, conversationId));
    _convs.remove(ChatRepositoryImpl.groupKey(currentUid, conversationId));
  }

  @override
  Future<void> toggleMuteConversation({
    required String currentUid,
    required String conversationId,
  }) async {}

  @override
  Future<ChatConversationModel?> getConversation({
    required String currentUid,
    required String conversationId,
  }) async =>
      _findEntry(currentUid, conversationId)?.conv;

  @override
  Future<bool> isGroupConversation({
    required String currentUid,
    required String conversationId,
  }) async =>
      _convs.containsKey(ChatRepositoryImpl.groupKey(currentUid, conversationId));

  @override
  Future<List<ChatMessageModel>> getQueuedOutgoingMessages({
    required String currentUid,
  }) async =>
      const [];

  @override
  Future<ChatConversationModel> saveCreatedGroup({
    required String currentUid,
    required String groupId,
    required String name,
    required String description,
    required List<String> memberIds,
    String? iconUrl,
    required DateTime createdAt,
  }) async {
    final conv = ChatConversationModel(
      id: groupId,
      name: name,
      description: description,
      avatarUrl: iconUrl,
      isGroup: true,
      ownerId: currentUid,
      adminIds: const [],
      memberIds: {...memberIds, currentUid}.toList(),
    );
    _convs[ChatRepositoryImpl.groupKey(currentUid, groupId)] = (
      conv: conv,
      updatedAt: createdAt,
    );
    return conv;
  }

  @override
  Future<void> updateGroupInfoLocally({
    required String currentUid,
    required String groupId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {}

  @override
  Future<void> addGroupMembersLocally({
    required String currentUid,
    required String groupId,
    required List<String> memberIds,
  }) async {}

  @override
  Future<void> removeGroupMemberLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  }) async {}

  @override
  Future<void> promoteGroupAdminLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  }) async {}

  @override
  Future<void> demoteGroupAdminLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  }) async {}

  @override
  Future<void> transferGroupOwnerLocally({
    required String currentUid,
    required String groupId,
    required String newOwnerId,
  }) async {}

  @override
  Future<void> leaveGroupLocally({
    required String currentUid,
    required String groupId,
  }) async {
    _convs.remove(ChatRepositoryImpl.groupKey(currentUid, groupId));
  }

  @override
  Future<String> resolveUniqueUidForAgoraUsername(
    String agoraUsername, {
    required String currentUid,
    String? currentAgoraUsername,
    Iterable<String> additionalCandidates = const [],
  }) async {
    final normalized = agoraUsername.toLowerCase();
    final matches = <String>{};

    void check(String uid) {
      if (uid.isEmpty) return;
      if (ChatRepositoryImpl.sanitizeAgoraUsername(uid) == normalized) {
        matches.add(uid);
      }
    }

    if (currentAgoraUsername != null &&
        currentAgoraUsername.toLowerCase() == normalized) {
      matches.add(currentUid);
    }
    check(currentUid);
    for (final c in additionalCandidates) {
      check(c);
    }
    for (final uid in profiles.keys) {
      check(uid);
    }
    for (final entry in _convs.values) {
      check(entry.conv.id);
      for (final m in entry.conv.memberIds) {
        check(m);
      }
    }

    if (matches.length == 1) return matches.single;
    return agoraUsername;
  }

  @override
  Future<Map<String, ChatMemberProfile>> getMemberProfiles(
    List<String> uids,
  ) async {
    return {
      for (final u in uids)
        if (profiles.containsKey(u)) u: profiles[u]!,
    };
  }
}

ChatMessage _makeAgoraTextMsg({
  required String msgId,
  required String from,
  required String to,
  String? convId,
  required String content,
  required int serverTime,
  ChatType chatType = ChatType.Chat,
  MessageDirection direction = MessageDirection.RECEIVE,
  Map<String, dynamic>? attributes,
}) {
  return ChatMessage.fromJson({
    'msgId': msgId,
    'from': from,
    'to': to,
    'convId': convId ?? (chatType == ChatType.GroupChat ? to : from),
    'body': ChatTextMessageBody(content: content).toJson(),
    if (attributes != null) 'attributes': attributes,
    'direction': direction.index,
    'hasRead': false,
    'hasReadAck': false,
    'hasDeliverAck': false,
    'needGroupAck': false,
    'chatType': chatType.index,
    'localTime': serverTime,
    'serverTime': serverTime,
    'status': MessageStatus.SUCCESS.index,
  });
}

void main() {
  group('AgoraChatServiceImpl security, sync, and resilience', () {
    late _FakeAuthService auth;
    late _InMemoryChatRepository repo;
    late _FakeAgoraSdkGateway sdk;
    late http.Client httpClient;
    late AgoraChatServiceImpl service;

    http.Client buildTokenHttpClient({
      String Function(String bearerToken)? uidFromBearer,
    }) {
      return MockClient((req) async {
        final authHeader = req.headers['Authorization'] ?? '';
        final bearer = authHeader.replaceFirst('Bearer ', '');
        final uid = uidFromBearer != null
            ? uidFromBearer(bearer)
            : bearer.replaceFirst('id-token-', '');
        final agoraUsername = ChatRepositoryImpl.sanitizeAgoraUsername(uid);
        return http.Response(
          jsonEncode({
            'appKey': 'org#app',
            'appId': 'app-id',
            'agoraUsername': agoraUsername,
            'token': 'agora-token-for-$uid',
            'expiresAt': 1900000000,
          }),
          200,
        );
      });
    }

    setUp(() {
      auth = _FakeAuthService(currentUid: 'user-A');
      repo = _InMemoryChatRepository();
      sdk = _FakeAgoraSdkGateway();
      httpClient = buildTokenHttpClient();
      service = AgoraChatServiceImpl(
        chatRepository: repo,
        authService: auth,
        sdkGateway: sdk,
        httpClient: httpClient,
        serverBaseUrlProvider: () => 'http://localhost:3000',
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'Comment 1: USER_ALREADY_LOGIN (error 200) aborts sync when SDK user belongs to previous account',
      () async {
        // Seed previous user's DM in repository and leave SDK stuck on `user_a`
        // (simulating a failed SDK logout during account switch to `user-B`).
        await repo.persistMessage(
          currentUid: 'user-A',
          model: ChatMessageModel(
            id: 'secret-a',
            conversationId: 'alice-peer',
            senderId: 'alice-peer',
            senderName: 'Alice Peer',
            type: ChatMessageType.text,
            content: 'Private to User A',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ),
        );

        sdk.loggedInBefore = true;
        sdk.currentUsername = 'user-a';
        sdk.onLogout = (_) async {
          throw ChatError(300, 'Logout failed');
        };
        sdk.onLoginWithToken = (username, token) async {
          throw ChatError(200, 'USER_ALREADY_LOGIN');
        };
        sdk.conversationPages[null] = ChatCursorResult(null, [
          _FakeConversationHandle(id: 'alice_server_dm'),
        ]);

        auth.currentUid = 'user-B';
        await service.login('user-B');

        // Must mark unavailable and NEVER sync `user-a`'s Agora inbox into `user-B`.
        expect(service.connectionStateValue, ChatConnectionState.unavailable);
        expect(sdk.syncConversationFetchCalls, 0);
        final convsForB = await service.getConversations();
        expect(convsForB, isEmpty);
      },
    );

    test(
      'Comment 1: USER_ALREADY_LOGIN succeeds only when SDK username matches AND token renewal succeeds',
      () async {
        auth.currentUid = 'user-B';
        sdk.loggedInBefore = false;
        sdk.currentUsername = 'user-b';
        sdk.onLoginWithToken = (username, token) async {
          sdk.loggedInBefore = true;
          throw ChatError(200, 'USER_ALREADY_LOGIN');
        };
        sdk.conversationPages[null] = ChatCursorResult(null, [
          _FakeConversationHandle(id: 'friend_one'),
        ]);

        await service.login('user-B');

        expect(sdk.renewTokenCalls, ['agora-token-for-user-B']);
        expect(service.connectionStateValue, ChatConnectionState.connected);
        expect(sdk.syncConversationFetchCalls, 1);
        final convs = await service.getConversations();
        expect(convs.map((c) => c.id), ['friend_one']);
      },
    );

    test(
      'Comments 2 & 3: distinct Firebase UIDs that sanitize to the same Agora ID never mix messages or collide',
      () async {
        // Verify genuine sanitization collisions (`/` and `.` both map to `_`):
        // - Signed-in `User.1` and peer `user/1` both sanitize to `user_1`.
        // - Peers `peer/1` and `peer.1` both sanitize to `peer_1`.
        expect(
          ChatRepositoryImpl.sanitizeAgoraUsername('User.1'),
          equals(ChatRepositoryImpl.sanitizeAgoraUsername('user/1')),
        );
        expect(
          ChatRepositoryImpl.sanitizeAgoraUsername('peer/1'),
          equals(ChatRepositoryImpl.sanitizeAgoraUsername('peer.1')),
        );

        auth.currentUid = 'User.1';
        await service.login('User.1');

        // Seed cached messages in `peer/1` thread.
        await repo.persistMessage(
          currentUid: 'User.1',
          model: ChatMessageModel(
            id: 'msg-slash',
            conversationId: 'peer/1',
            senderId: 'peer/1',
            senderName: 'Peer Slash',
            type: ChatMessageType.text,
            content: 'Only for peer/1',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000001000),
          ),
        );
        await repo.ensureDmConversationExists(
          currentUid: 'User.1',
          peerUid: 'peer.1',
          name: 'Peer Dot',
        );

        // Requesting `peer.1` must NOT expose `peer/1`'s cached messages.
        final dotMessages = await service.getMessages('peer.1');
        expect(dotMessages, isEmpty);

        final slashMessages = await service.getMessages('peer/1');
        expect(slashMessages.map((m) => m.id), ['msg-slash']);

        // Both colliding peers appear as distinct conversations in the inbox.
        final convs = await service.getConversations();
        expect(convs.map((c) => c.id).toSet(), {'peer/1', 'peer.1'});

        // Incoming message from `user/1` (whose sanitized ID `user_1` collides
        // with signed-in `User.1`) must NOT be treated as self-sent or hidden!
        final incomingFromCollidingPeer = _makeAgoraTextMsg(
          msgId: 'agora-collide-1',
          from: 'user_1',
          to: 'user_1',
          content: 'Hello from distinct user/1',
          serverTime: 1700000005000,
          attributes: {
            'senderUid': 'user/1',
            'targetUid': 'User.1',
            'senderName': 'User Slash',
          },
        );
        sdk.chatEventHandler!.onMessagesReceived!([incomingFromCollidingPeer]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final afterIncomingConvs = await service.getConversations();
        final userSlashConv = afterIncomingConvs.firstWhere(
          (c) => c.id == 'user/1',
        );
        expect(userSlashConv.unreadCount, 1);

        final userSlashMsgs = await service.getMessages('user/1');
        expect(userSlashMsgs, hasLength(1));
        expect(userSlashMsgs.single.senderId, 'user/1');
        expect(userSlashMsgs.single.content, 'Hello from distinct user/1');

        // Incoming message explicitly addressed to a DIFFERENT colliding user
        // (`targetUid: 'user/1'`) must be rejected when signed in as `User.1`.
        final misrouted = _makeAgoraTextMsg(
          msgId: 'agora-misrouted',
          from: 'outsider',
          to: 'user_1',
          content: 'Secret meant for user/1, not User.1',
          serverTime: 1700000006000,
          attributes: {
            'senderUid': 'outsider',
            'targetUid': 'user/1',
          },
        );
        sdk.chatEventHandler!.onMessagesReceived!([misrouted]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(await service.getMessages('outsider'), isEmpty);
      },
    );

    test(
      'Comment 4: group sync replaces stale cached members and admins and prunes removed groups',
      () async {
        auth.currentUid = 'me';

        // Pre-populate stale group roster (`bob` was a member, `alice` was admin)
        // plus a group `grp-removed` the user is no longer in.
        await repo.ingestGroups(
          currentUid: 'me',
          groups: const [
            SyncedGroupInfo(
              groupId: 'grp-1',
              name: 'Design Team',
              ownerId: 'owner',
              adminIds: ['alice'],
              memberIds: ['owner', 'alice', 'bob', 'me'],
            ),
            SyncedGroupInfo(
              groupId: 'grp-removed',
              name: 'Old Group',
              ownerId: 'owner',
              memberIds: ['owner', 'me'],
            ),
          ],
        );

        // Server now reports `alice` demoted (`adminList: []`), `bob` removed,
        // and only `grp-1` in joined groups.
        sdk.joinedGroupPages[0] = [
          ChatGroup(groupId: 'grp-1', groupName: 'Design Team'),
        ];
        sdk.groupDetails['grp-1'] = ChatGroup(
          groupId: 'grp-1',
          groupName: 'Design Team',
          owner: 'owner',
          adminList: const [],
          memberList: const ['me'],
        );
        sdk.groupMemberPages['grp-1'] = {
          null: ChatCursorResult('', ['me']),
        };

        await service.login('me');

        final convs = await service.getConversations();
        expect(convs.map((c) => c.id), ['grp-1']);

        final refreshed = convs.single;
        expect(refreshed.adminIds, isEmpty);
        expect(refreshed.memberIds.toSet(), {'owner', 'me'});
        expect(refreshed.memberIds, isNot(contains('bob')));
        expect(refreshed.memberIds, isNot(contains('alice')));
      },
    );

    test(
      'Comment 5: account switch while login is in flight queues and authenticates the latest UID',
      () async {
        final userALoginGate = Completer<void>();
        sdk.onLoginWithToken = (username, token) async {
          if (username == 'user-a') {
            await userALoginGate.future;
          }
          sdk.loggedInBefore = true;
          sdk.currentUsername = username;
        };

        sdk.conversationPages[null] = ChatCursorResult(null, [
          _FakeConversationHandle(id: 'peer_for_b'),
        ]);

        // Start login for `user-A` (blocks inside `loginWithToken`).
        auth.currentUid = 'user-A';
        final loginAFuture = service.login('user-A');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Switch Firebase user to `user-B` while `user-A` login is in flight
        // and invoke `watchConversations()`.
        auth.currentUid = 'user-B';
        final sub = service.watchConversations().listen((_) {});

        // Release `user-A`'s blocked SDK login; service must abort `user-A`
        // sync and immediately run login for `user-B`.
        userALoginGate.complete();
        await loginAFuture;
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(sdk.currentUsername, 'user-b');
        expect(
          sdk.loginCalls.map((c) => c.username).toList(),
          ['user-a', 'user-b'],
        );
        // `user-A` must have zero synced conversations; `user-B` has `peer_for_b`.
        final convsForB = await service.getConversations();
        expect(convsForB.map((c) => c.id), ['peer_for_b']);
        expect(
          await repo.getConversations(currentUid: 'user-A'),
          isEmpty,
        );

        await sub.cancel();
      },
    );

    test(
      'Comments 7, 8, 9: login sync and on-demand getMessages follow all conversation and history pagination cursors',
      () async {
        auth.currentUid = 'me';

        // 3 pages of server conversations (total 55 conversations > 50).
        final page1 = List.generate(
          25,
          (i) => _FakeConversationHandle(id: 'conv_p1_$i'),
        );
        final page2 = List.generate(
          25,
          (i) => _FakeConversationHandle(id: 'conv_p2_$i'),
        );
        final page3 = List.generate(
          5,
          (i) => _FakeConversationHandle(id: 'conv_p3_$i'),
        );
        sdk.conversationPages = {
          null: ChatCursorResult('cursor-1', page1),
          'cursor-1': ChatCursorResult('cursor-2', page2),
          'cursor-2': ChatCursorResult('', page3),
        };

        // 3 pages of server message history for `conv_p1_0` (total 65 messages).
        List<ChatMessage> makeBatch(int startIdx, int count) {
          return List.generate(
            count,
            (offset) {
              final idx = startIdx + offset;
              return _makeAgoraTextMsg(
                msgId: 'hist-$idx',
                from: 'conv_p1_0',
                to: 'me',
                convId: 'conv_p1_0',
                content: 'Message #$idx',
                serverTime: 1700000000000 + idx * 1000,
              );
            },
          );
        }

        sdk.historyPages['conv_p1_0'] = {
          '': ChatCursorResult('h-cur-1', makeBatch(40, 25)),
          'h-cur-1': ChatCursorResult('h-cur-2', makeBatch(15, 25)),
          'h-cur-2': ChatCursorResult('', makeBatch(0, 15)),
        };

        await service.login('me');

        final convs = await service.getConversations();
        expect(convs, hasLength(55));

        final syncedMessages = await service.getMessages('conv_p1_0');
        expect(syncedMessages, hasLength(65));
        expect(syncedMessages.first.content, 'Message #0');
        expect(syncedMessages.last.content, 'Message #64');

        // Also verify on-demand backfill in `getMessages` for a cold thread
        // with >50 server messages across multiple cursors.
        sdk.historyPages['cold_peer'] = {
          '': ChatCursorResult(
            'cold-cur-1',
            List.generate(
              35,
              (i) => _makeAgoraTextMsg(
                msgId: 'cold-${25 + i}',
                from: 'cold_peer',
                to: 'me',
                convId: 'cold_peer',
                content: 'Cold #${25 + i}',
                serverTime: 1700001000000 + (25 + i) * 1000,
              ),
            ),
          ),
          'cold-cur-1': ChatCursorResult(
            '',
            List.generate(
              25,
              (i) => _makeAgoraTextMsg(
                msgId: 'cold-$i',
                from: 'cold_peer',
                to: 'me',
                convId: 'cold_peer',
                content: 'Cold #$i',
                serverTime: 1700001000000 + i * 1000,
              ),
            ),
          ),
        };

        final coldMessages = await service.getMessages('cold_peer');
        expect(coldMessages, hasLength(60));
        expect(coldMessages.first.content, 'Cold #0');
        expect(coldMessages.last.content, 'Cold #59');
      },
    );

    test(
      'Comment 10: failed renewAgoraToken logs out and re-authenticates via loginWithToken (or marks unavailable if re-login fails)',
      () async {
        auth.currentUid = 'user-A';
        await service.login('user-A');
        expect(service.connectionStateValue, ChatConnectionState.connected);

        // Next `login('user-A')` sees `alreadyLoggedIn == true` and matching
        // `user_a`, but `renewAgoraToken` rejects the token.
        sdk.onRenewAgoraToken = (_) async {
          throw ChatError(108, 'Token rejected');
        };

        await service.login('user-A');

        // Must have logged out the stale session and performed full `loginWithToken`.
        expect(sdk.logoutCalls, 1);
        expect(sdk.loginCalls, hasLength(2));
        expect(service.connectionStateValue, ChatConnectionState.connected);

        // Now if both `renewAgoraToken` AND `loginWithToken` fail, state must
        // become `ChatConnectionState.unavailable`.
        sdk.onLoginWithToken = (_, _) async {
          throw ChatError(104, 'Auth failed');
        };
        await service.login('user-A');
        expect(service.connectionStateValue, ChatConnectionState.unavailable);
      },
    );

    test(
      'Comment 11: re-login does not swallow startCallback failures and marks service unavailable when retry fails',
      () async {
        auth.currentUid = 'user-A';
        await service.login('user-A');
        expect(service.connectionStateValue, ChatConnectionState.connected);

        await service.logout();

        // Transient single failure on re-login succeeds via retry.
        var attempts = 0;
        sdk.onStartCallback = () async {
          attempts++;
          if (attempts == 1) {
            throw Exception('MethodChannel not ready yet');
          }
        };
        await service.login('user-A');
        expect(attempts, 2);
        expect(service.connectionStateValue, ChatConnectionState.connected);

        await service.logout();

        // Persistent failure on both attempts fails login into `unavailable`
        // without calling `loginWithToken` or running sync with dead callbacks.
        final loginCountBefore = sdk.loginCalls.length;
        sdk.onStartCallback = () async {
          throw Exception('Native listener broken');
        };
        await service.login('user-A');

        expect(service.connectionStateValue, ChatConnectionState.unavailable);
        expect(sdk.loginCalls.length, loginCountBefore);
      },
    );

    test(
      'Comments 13 & 15: empty synced DM conversations use ChatRepository with null timestamps and sort below active chats',
      () async {
        auth.currentUid = 'me';

        sdk.conversationPages[null] = ChatCursorResult(null, [
          _FakeConversationHandle(id: 'empty_peer'),
          _FakeConversationHandle(id: 'active_peer'),
        ]);
        sdk.historyPages['active_peer'] = {
          '': ChatCursorResult('', [
            _makeAgoraTextMsg(
              msgId: 'active-1',
              from: 'active_peer',
              to: 'me',
              convId: 'active_peer',
              content: 'Real message',
              serverTime: 1700000000000,
            ),
          ]),
        };

        await service.login('me');

        expect(repo.ensureDmCalls, greaterThanOrEqualTo(1));

        final convs = await service.getConversations();
        expect(convs.map((c) => c.id).toList(), ['active_peer', 'empty_peer']);

        final emptyConv = convs.last;
        expect(emptyConv.id, 'empty_peer');
        expect(emptyConv.lastMessageTimestamp, isNull);
        expect(emptyConv.lastMessage, isNull);
      },
    );
  });
}
