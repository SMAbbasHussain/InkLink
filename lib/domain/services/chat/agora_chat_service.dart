import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/utils/network_config.dart';
import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../models/chat/chat_share_payload.dart';
import '../../repositories/chat/chat_repository.dart';
import '../presence/presence_service.dart';
import 'chat_service.dart';

/// Thin wrapper around an Agora SDK conversation object for testability.
abstract class AgoraConversationHandle {
  String get id;
  ChatConversationType get type;
  Future<List<ChatMessage>> loadMessages({
    String startMsgId = '',
    int loadCount = 50,
  });
  Future<ChatMessage?> latestMessage();
  Future<void> markAllMessagesAsRead();
  Future<void> deleteMessage(String messageId);
}

class _LiveAgoraConversationHandle implements AgoraConversationHandle {
  final ChatConversation _conv;
  _LiveAgoraConversationHandle(this._conv);

  @override
  String get id => _conv.id;

  @override
  ChatConversationType get type => _conv.type;

  @override
  Future<List<ChatMessage>> loadMessages({
    String startMsgId = '',
    int loadCount = 50,
  }) {
    return _conv.loadMessages(startMsgId: startMsgId, loadCount: loadCount);
  }

  @override
  Future<ChatMessage?> latestMessage() => _conv.latestMessage();

  @override
  Future<void> markAllMessagesAsRead() => _conv.markAllMessagesAsRead();

  @override
  Future<void> deleteMessage(String messageId) => _conv.deleteMessage(messageId);
}

/// Gateway over `ChatClient.getInstance` so `AgoraChatServiceImpl` can be
/// deterministically unit-tested without native platform channels.
abstract class AgoraChatSdkGateway {
  Future<void> init(String appKey);
  Future<void> changeAppKey(String newAppKey);
  Future<void> updateAckSettings();
  Future<void> startCallback();

  void registerHandlers({
    required ChatEventHandler chatEventHandler,
    required ChatMessageEvent messageEvent,
    required ConnectionEventHandler connectionEventHandler,
    required ChatGroupEventHandler groupEventHandler,
  });

  Future<bool> isLoginBefore();
  Future<bool> isConnected();
  Future<String?> getCurrentUsername();
  bool isAlreadyLoggedInError(Object error);

  Future<void> loginWithToken(String username, String token);
  Future<void> renewAgoraToken(String token);
  Future<void> logout(bool clearDeviceToken);
  Future<void> bindDeviceToken({
    required String notifierName,
    required String deviceToken,
  });

  Future<List<AgoraConversationHandle>> loadAllConversations();
  Future<ChatCursorResult<AgoraConversationHandle>> fetchConversationsPage({
    int pageSize = 50,
    String? cursor,
  });
  Future<List<AgoraConversationHandle>> getConversationsFromServerFallback();
  Future<AgoraConversationHandle?> getConversation(
    String conversationId, {
    required ChatConversationType type,
    bool createIfNeed = true,
  });
  Future<void> deleteConversation(
    String conversationId, {
    bool deleteMessages = true,
  });

  Future<ChatCursorResult<ChatMessage>> fetchHistoryMessagesPage({
    required String conversationId,
    required ChatConversationType type,
    int pageSize = 50,
    String startMsgId = '',
  });

  Future<ChatMessage> sendMessage(ChatMessage message);
  Future<void> sendConversationReadAck(String conversationId);
  Future<void> sendMessageReadAck(ChatMessage message);
  Future<void> addReaction({
    required String messageId,
    required String reaction,
  });
  Future<void> removeReaction({
    required String messageId,
    required String reaction,
  });
  Future<void> modifyMessage({
    required String messageId,
    required ChatTextMessageBody msgBody,
  });
  Future<void> recallMessage(String messageId);
  Future<List<ChatMessageReaction>> getMessageReactionList(ChatMessage message);

  Future<List<ChatGroup>> fetchJoinedGroupsPage({
    int pageSize = 20,
    int pageNum = 0,
    bool needRole = true,
  });
  Future<ChatGroup> fetchGroupInfoFromServer(String groupId);
  Future<ChatCursorResult<String>> fetchGroupMembersPage(
    String groupId, {
    int pageSize = 200,
    String? cursor,
  });

  Future<ChatGroup> createGroup({
    required String groupName,
    String? avatarUrl,
    required String desc,
    required ChatGroupOptions options,
    required List<String> inviteMembers,
  });
  Future<void> updateGroupName(String groupId, String name);
  Future<void> updateGroupDesc(String groupId, String desc);
  Future<void> updateGroupAvatar({
    required String groupId,
    required String avatarUrl,
  });
  Future<void> addGroupMembers(String groupId, List<String> members);
  Future<void> removeGroupMembers(String groupId, List<String> members);
  Future<void> addGroupAdmin(String groupId, String memberId);
  Future<void> removeGroupAdmin(String groupId, String memberId);
  Future<void> changeGroupOwner(String groupId, String newOwner);
  Future<void> leaveGroup(String groupId);
  Future<void> destroyGroup(String groupId);
}

class LiveAgoraChatSdkGateway implements AgoraChatSdkGateway {
  const LiveAgoraChatSdkGateway();

  @override
  Future<void> init(String appKey) {
    final options = ChatOptions.withAppKey(
      appKey,
      autoLogin: false,
      debugMode: false,
      requireAck: true,
      requireDeliveryAck: true,
    );
    return ChatClient.getInstance.init(options);
  }

  @override
  Future<void> changeAppKey(String newAppKey) {
    return ChatClient.getInstance.changeAppKey(newAppKey: newAppKey);
  }

  @override
  Future<void> updateAckSettings() async {
    await ChatClient.getInstance.updateRequireAckSetting(true);
    await ChatClient.getInstance.updateDeliveryAckSetting(true);
  }

  @override
  Future<void> startCallback() => ChatClient.getInstance.startCallback();

  @override
  void registerHandlers({
    required ChatEventHandler chatEventHandler,
    required ChatMessageEvent messageEvent,
    required ConnectionEventHandler connectionEventHandler,
    required ChatGroupEventHandler groupEventHandler,
  }) {
    ChatClient.getInstance.chatManager.addEventHandler(
      'inklink_chat_handler',
      chatEventHandler,
    );
    ChatClient.getInstance.chatManager.addMessageEvent(
      'inklink_message_status',
      messageEvent,
    );
    ChatClient.getInstance.addConnectionEventHandler(
      'inklink_chat_connection',
      connectionEventHandler,
    );
    ChatClient.getInstance.groupManager.addEventHandler(
      'inklink_group_handler',
      groupEventHandler,
    );
  }

  @override
  Future<bool> isLoginBefore() => ChatClient.getInstance.isLoginBefore();

  @override
  Future<bool> isConnected() => ChatClient.getInstance.isConnected();

  @override
  Future<String?> getCurrentUsername() async {
    return await ChatClient.getInstance.getCurrentUserId() ??
        ChatClient.getInstance.currentUserId;
  }

  @override
  bool isAlreadyLoggedInError(Object error) =>
      error is ChatError && error.code == 200;

  @override
  Future<void> loginWithToken(String username, String token) =>
      ChatClient.getInstance.loginWithToken(username, token);

  @override
  Future<void> renewAgoraToken(String token) =>
      ChatClient.getInstance.renewAgoraToken(token);

  @override
  Future<void> logout(bool clearDeviceToken) =>
      ChatClient.getInstance.logout(clearDeviceToken);

  @override
  Future<void> bindDeviceToken({
    required String notifierName,
    required String deviceToken,
  }) {
    return ChatClient.getInstance.pushManager.bindDeviceToken(
      notifierName: notifierName,
      deviceToken: deviceToken,
    );
  }

  @override
  Future<List<AgoraConversationHandle>> loadAllConversations() async {
    final convs =
        await ChatClient.getInstance.chatManager.loadAllConversations();
    return convs.map(_LiveAgoraConversationHandle.new).toList();
  }

  @override
  Future<ChatCursorResult<AgoraConversationHandle>> fetchConversationsPage({
    int pageSize = 50,
    String? cursor,
  }) async {
    final res = await ChatClient.getInstance.chatManager
        .fetchConversationsByOptions(
      options: ConversationFetchOptions(
        pageSize: pageSize,
        cursor: cursor,
      ),
    );
    return ChatCursorResult<AgoraConversationHandle>(
      res.cursor,
      res.data.map(_LiveAgoraConversationHandle.new).toList(),
    );
  }

  @override
  Future<List<AgoraConversationHandle>> getConversationsFromServerFallback() async {
    // ignore: deprecated_member_use
    final convs =
        await ChatClient.getInstance.chatManager.getConversationsFromServer();
    return convs.map(_LiveAgoraConversationHandle.new).toList();
  }

  @override
  Future<AgoraConversationHandle?> getConversation(
    String conversationId, {
    required ChatConversationType type,
    bool createIfNeed = true,
  }) async {
    final conv = await ChatClient.getInstance.chatManager.getConversation(
      conversationId,
      type: type,
      createIfNeed: createIfNeed,
    );
    return conv == null ? null : _LiveAgoraConversationHandle(conv);
  }

  @override
  Future<void> deleteConversation(
    String conversationId, {
    bool deleteMessages = true,
  }) {
    return ChatClient.getInstance.chatManager.deleteConversation(
      conversationId,
      deleteMessages: deleteMessages,
    );
  }

  @override
  Future<ChatCursorResult<ChatMessage>> fetchHistoryMessagesPage({
    required String conversationId,
    required ChatConversationType type,
    int pageSize = 50,
    String startMsgId = '',
  }) {
    return ChatClient.getInstance.chatManager.fetchHistoryMessages(
      conversationId: conversationId,
      type: type,
      pageSize: pageSize,
      startMsgId: startMsgId,
    );
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) =>
      ChatClient.getInstance.chatManager.sendMessage(message);

  @override
  Future<void> sendConversationReadAck(String conversationId) =>
      ChatClient.getInstance.chatManager
          .sendConversationReadAck(conversationId);

  @override
  Future<void> sendMessageReadAck(ChatMessage message) =>
      ChatClient.getInstance.chatManager.sendMessageReadAck(message);

  @override
  Future<void> addReaction({
    required String messageId,
    required String reaction,
  }) {
    return ChatClient.getInstance.chatManager.addReaction(
      messageId: messageId,
      reaction: reaction,
    );
  }

  @override
  Future<void> removeReaction({
    required String messageId,
    required String reaction,
  }) {
    return ChatClient.getInstance.chatManager.removeReaction(
      messageId: messageId,
      reaction: reaction,
    );
  }

  @override
  Future<void> modifyMessage({
    required String messageId,
    required ChatTextMessageBody msgBody,
  }) {
    return ChatClient.getInstance.chatManager.modifyMessage(
      messageId: messageId,
      msgBody: msgBody,
    );
  }

  @override
  Future<void> recallMessage(String messageId) =>
      ChatClient.getInstance.chatManager.recallMessage(messageId);

  @override
  Future<List<ChatMessageReaction>> getMessageReactionList(
    ChatMessage message,
  ) =>
      message.reactionList();

  @override
  Future<List<ChatGroup>> fetchJoinedGroupsPage({
    int pageSize = 20,
    int pageNum = 0,
    bool needRole = true,
  }) {
    return ChatClient.getInstance.groupManager.fetchJoinedGroupsFromServer(
      pageSize: pageSize,
      pageNum: pageNum,
      needRole: needRole,
    );
  }

  @override
  Future<ChatGroup> fetchGroupInfoFromServer(String groupId) =>
      ChatClient.getInstance.groupManager.fetchGroupInfoFromServer(groupId);

  @override
  Future<ChatCursorResult<String>> fetchGroupMembersPage(
    String groupId, {
    int pageSize = 200,
    String? cursor,
  }) {
    return ChatClient.getInstance.groupManager.fetchMemberListFromServer(
      groupId,
      pageSize: pageSize,
      cursor: cursor,
    );
  }

  @override
  Future<ChatGroup> createGroup({
    required String groupName,
    String? avatarUrl,
    required String desc,
    required ChatGroupOptions options,
    required List<String> inviteMembers,
  }) {
    return ChatClient.getInstance.groupManager.createGroup(
      groupName: groupName,
      avatarUrl: avatarUrl,
      desc: desc,
      options: options,
      inviteMembers: inviteMembers,
    );
  }

  @override
  Future<void> updateGroupName(String groupId, String name) =>
      ChatClient.getInstance.groupManager.updateGroupName(groupId, name);

  @override
  Future<void> updateGroupDesc(String groupId, String desc) =>
      ChatClient.getInstance.groupManager.updateGroupDesc(groupId, desc);

  @override
  Future<void> updateGroupAvatar({
    required String groupId,
    required String avatarUrl,
  }) {
    return ChatClient.getInstance.groupManager.updateGroupAvatar(
      groupId: groupId,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Future<void> addGroupMembers(String groupId, List<String> members) =>
      ChatClient.getInstance.groupManager.addMembers(groupId, members);

  @override
  Future<void> removeGroupMembers(String groupId, List<String> members) =>
      ChatClient.getInstance.groupManager.removeMembers(groupId, members);

  @override
  Future<void> addGroupAdmin(String groupId, String memberId) =>
      ChatClient.getInstance.groupManager.addAdmin(groupId, memberId);

  @override
  Future<void> removeGroupAdmin(String groupId, String memberId) =>
      ChatClient.getInstance.groupManager.removeAdmin(groupId, memberId);

  @override
  Future<void> changeGroupOwner(String groupId, String newOwner) =>
      ChatClient.getInstance.groupManager.changeOwner(groupId, newOwner);

  @override
  Future<void> leaveGroup(String groupId) =>
      ChatClient.getInstance.groupManager.leaveGroup(groupId);

  @override
  Future<void> destroyGroup(String groupId) =>
      ChatClient.getInstance.groupManager.destroyGroup(groupId);
}

/// Chat transport backed *exclusively* by the Agora Chat SDK, with local
/// persistence delegated through [ChatRepository].
///
/// Data flow:
/// - Sends: ChatRepository (`sending`) -> Agora `sendMessage` -> `sent` on SDK
///   ack, `failed` on error. Nothing is mirrored to Firestore.
/// - Receives: Agora events (`onMessagesReceived`, delivery/read acks,
///   recall/edit/reaction/group events) -> ChatRepository.
/// - History: Agora server conversations + local repository cache. Full cursor
///   pagination runs at login via `_syncFromAgora` and on-demand per thread.
/// - Auth: a per-user Chat token minted by the InkLink server
///   (`POST /api/agora/chat/token`, Bearer Firebase ID token). The token is
///   renewed on `onTokenWillExpire` / refreshed-with-login on expiry or rejection.
class AgoraChatServiceImpl implements ChatService {
  final ChatRepository _chatRepository;
  final AuthService _authService;
  final PresenceService? _presenceService;
  final Future<String?> Function()? _pushTokenProvider;
  final http.Client _http;
  final bool _ownsHttpClient;
  final AgoraChatSdkGateway _sdk;
  final String Function()? _serverBaseUrlProvider;

  bool _initialized = false;
  String? _initAppKey;

  /// Latest Firebase UID requested via `login()`.
  String? _currentUserId;

  /// Firebase UID whose Agora SDK session has been verified and authenticated.
  String? _authenticatedUserId;
  String? _authenticatedAgoraUsername;

  /// Coalesced login queue: ensures account switches during an in-flight login
  /// always authenticate the newest UID before chat operations proceed.
  String? _pendingLoginUserId;
  Future<void>? _loginLoopFuture;
  int _authGeneration = 0;

  final Set<String> _backfilledThreadsForUser = {};
  final Map<String, Future<void>> _inFlightThreadBackfills = {};

  final StreamController<List<ChatConversationModel>> _conversationsController =
      StreamController<List<ChatConversationModel>>.broadcast();
  final Map<String, StreamController<List<ChatMessageModel>>>
      _messagesControllers = {};
  final Map<String, String> _agoraMsgIdToLocalId = {};
  final Map<String, StreamSubscription<UserPresence>> _presenceSubs = {};
  final Map<String, bool> _presenceStates = {};
  final StreamController<ChatConnectionState> _connectionStateController =
      StreamController<ChatConnectionState>.broadcast();

  ChatConnectionState _connectionState = ChatConnectionState.disconnected;
  ChatConnectionState get connectionStateValue => _connectionState;

  void _setConnectionState(ChatConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  AgoraChatServiceImpl({
    required ChatRepository chatRepository,
    required AuthService authService,
    PresenceService? presenceService,
    Future<String?> Function()? pushTokenProvider,
    http.Client? httpClient,
    AgoraChatSdkGateway? sdkGateway,
    String Function()? serverBaseUrlProvider,
  })  : _chatRepository = chatRepository,
        _authService = authService,
        _presenceService = presenceService,
        _pushTokenProvider = pushTokenProvider,
        _http = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _sdk = sdkGateway ?? const LiveAgoraChatSdkGateway(),
        _serverBaseUrlProvider = serverBaseUrlProvider;

  String _sanitizeAgoraUid(String uid) {
    // Agora Chat usernames accept [a-zA-Z0-9_-]+. Mirrored by the server
    // (`sanitizeAgoraUid` in server/src/index.js) — keep both in sync.
    // Used ONLY when addressing the Agora SDK, never to equate Firebase UIDs.
    return uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
  }

  /// Exact, collision-safe Firebase UID identity comparison.
  bool _isSameFirebaseUid(String a, String b) {
    return a.isNotEmpty && a == b;
  }

  String _activeLocalUid() {
    return _authService.getCurrentUserId() ?? _currentUserId ?? '';
  }

  bool _isStaleLogin(String targetUid, int startGeneration) {
    if (_authGeneration != startGeneration) return true;
    if (_currentUserId != targetUid) return true;
    if (_pendingLoginUserId != null && _pendingLoginUserId != targetUid) {
      return true;
    }
    final liveAuthUid = _authService.getCurrentUserId();
    if (liveAuthUid != null &&
        liveAuthUid.isNotEmpty &&
        liveAuthUid != targetUid) {
      return true;
    }
    return false;
  }

  void _ensureWatchingPresence(String uid) {
    final presenceService = _presenceService;
    if (presenceService == null || uid.isEmpty) return;
    if (_presenceSubs.containsKey(uid)) return;
    _presenceSubs[uid] = presenceService.watchUserPresence(uid).listen(
      (presence) {
        final prev = _presenceStates[uid];
        _presenceStates[uid] = presence.isOnline;
        if (prev != presence.isOnline) {
          unawaited(_syncConversationsFromLocal());
        }
      },
      onError: (_) {},
    );
  }

  bool _isThreadActive(String conversationId) {
    final controller = _messagesControllers[conversationId];
    return controller != null && controller.hasListener;
  }

  Future<String> _resolveUidFromAgoraUsername(
    String rawAgoraId, {
    required String currentUid,
    Iterable<String> additionalCandidates = const [],
  }) {
    if (rawAgoraId.isEmpty) return Future.value(rawAgoraId);
    return _chatRepository.resolveUniqueUidForAgoraUsername(
      rawAgoraId,
      currentUid: currentUid,
      currentAgoraUsername: _authenticatedUserId == currentUid
          ? _authenticatedAgoraUsername
          : null,
      additionalCandidates: additionalCandidates,
    );
  }

  // ============================================================
  // AUTH — server-minted per-user Agora Chat token
  // ============================================================

  /// Fetches `{agoraUsername, appKey, appId, token, expiresAt}` from the
  /// InkLink server. Returns null when unavailable (offline / not configured).
  Future<Map<String, dynamic>?> _fetchAgoraCredentials() async {
    final idToken = await _authService.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      developer.log(
        'No Firebase ID token available for Agora Chat auth',
        name: 'AgoraChatService',
      );
      return null;
    }
    try {
      final base = _serverBaseUrlProvider != null
          ? _serverBaseUrlProvider()
          : resolveWebSocketUrl();
      final res = await _http
          .post(
            Uri.parse('$base/api/agora/chat/token'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        developer.log(
          'Agora Chat token endpoint returned ${res.statusCode}',
          name: 'AgoraChatService',
        );
        return null;
      }
      final body = jsonDecode(res.body);
      if (body is Map && body['token'] != null && body['appKey'] != null) {
        return Map<String, dynamic>.from(body);
      }
      developer.log(
        'Agora Chat token endpoint returned unexpected payload',
        name: 'AgoraChatService',
      );
      return null;
    } catch (e) {
      developer.log(
        'Agora Chat token fetch failed (local-first mode): $e',
        name: 'AgoraChatService',
      );
      return null;
    }
  }

  Future<bool> _isSdkLoggedIn() async {
    if (!_initialized) return false;
    try {
      return await _sdk.isLoginBefore();
    } catch (_) {
      return false;
    }
  }

  /// Verifies that the SDK is logged in *and* authenticated as [expectedUid].
  Future<bool> _isSdkAuthenticatedFor(String expectedUid) async {
    if (expectedUid.isEmpty) return false;
    if (!_initialized || _authenticatedUserId != expectedUid) return false;
    return _isSdkLoggedIn();
  }

  Future<void> _armCallbacksWithRetry() async {
    try {
      await _sdk.startCallback();
    } catch (firstErr) {
      developer.log(
        'Agora startCallback failed on first attempt ($firstErr); retrying...',
        name: 'AgoraChatService',
      );
      await _sdk.startCallback();
    }
  }

  /// Initializes ChatClient once per app key and ensures native callbacks are
  /// armed on every subsequent login. Throws if initialization or callback
  /// re-arming fails so login never proceeds deaf to live events.
  Future<void> _ensureInitialized(String appKey) async {
    if (_initialized) {
      if (_initAppKey != appKey) {
        try {
          await _sdk.changeAppKey(appKey);
          _initAppKey = appKey;
        } catch (e) {
          developer.log(
            'Agora changeAppKey failed ($e); logging out and retrying.',
            name: 'AgoraChatService',
          );
          try {
            await _sdk.logout(true);
          } catch (_) {}
          await _sdk.changeAppKey(appKey);
          _initAppKey = appKey;
        }
      }
      // Native Android `ClientWrapper.logout()` clears `ListenerHandle.hasReady`.
      // Re-arm callbacks on subsequent logins; surface failures if retry fails.
      await _armCallbacksWithRetry();
      return;
    }

    await _sdk.init(appKey);
    try {
      await _sdk.updateAckSettings();
    } catch (_) {}
    await _armCallbacksWithRetry();
    _registerMessageHandlers();
    _initialized = true;
    _initAppKey = appKey;
    developer.log(
      'Agora Chat SDK initialized with app key',
      name: 'AgoraChatService',
    );
  }

  bool _handlersRegistered = false;

  void _registerMessageHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    _sdk.registerHandlers(
      chatEventHandler: ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null ||
              activeUid.isEmpty ||
              activeUid != _activeLocalUid()) {
            return;
          }
          for (final msg in messages) {
            await _handleIncomingAgoraMessage(msg, targetAccountUid: activeUid);
          }
        },
        onMessagesDelivered: (List<ChatMessage> messages) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          for (final msg in messages) {
            final targetId = _agoraMsgIdToLocalId[msg.msgId] ??
                msg.attributes?['localMessageId']?.toString() ??
                msg.msgId;
            final attrTarget = msg.attributes?['targetUid']?.toString();
            final convId = (attrTarget != null && attrTarget.isNotEmpty)
                ? attrTarget
                : (msg.conversationId ?? msg.to ?? '');
            await _updateMessageStatus(
              targetId,
              ChatMessageStatus.delivered,
              currentUid: activeUid,
              fallbackMessageId: msg.msgId,
              conversationId: convId,
            );
          }
        },
        onMessagesRead: (List<ChatMessage> messages) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          for (final msg in messages) {
            final targetId = _agoraMsgIdToLocalId[msg.msgId] ??
                msg.attributes?['localMessageId']?.toString() ??
                msg.msgId;
            final attrTarget = msg.attributes?['targetUid']?.toString();
            final convId = (attrTarget != null && attrTarget.isNotEmpty)
                ? attrTarget
                : (msg.conversationId ?? msg.to ?? msg.from ?? '');
            await _updateMessageStatus(
              targetId,
              ChatMessageStatus.read,
              currentUid: activeUid,
              fallbackMessageId: msg.msgId,
              conversationId: convId,
            );
          }
        },
        onConversationRead: (String from, String to) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          developer.log(
            'Agora onConversationRead: from=$from, to=$to',
            name: 'AgoraChatService',
          );
          final peerUid = await _resolveUidFromAgoraUsername(
            from,
            currentUid: activeUid,
          );
          if (peerUid.isEmpty || _isSameFirebaseUid(peerUid, activeUid)) return;
          await _chatRepository.markOutgoingMessagesAsRead(
            currentUid: activeUid,
            conversationId: peerUid,
          );
          _notifyThreadUpdated(peerUid);
        },
        onMessagesRecalled: (List<ChatMessage> messages) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          for (final msg in messages) {
            final conversationId = msg.conversationId ?? msg.to ?? '';
            await _markMessageRecalledLocally(
              activeUid,
              conversationId,
              msg.msgId,
            );
          }
        },
        onMessagesRecalledInfo: (List<RecallMessageInfo> infos) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          for (final info in infos) {
            final conversationId = info.conversationId ??
                info.recallMessage?.conversationId ??
                info.recallBy;
            await _markMessageRecalledLocally(
              activeUid,
              conversationId,
              info.recallMessageId,
            );
          }
        },
        onMessageContentChanged: (
          ChatMessage msg,
          String lastModifyOperatorId,
          int lastModifyTime,
        ) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          final conversationId = msg.conversationId ?? msg.to ?? '';
          String content = '';
          if (msg.body is ChatTextMessageBody) {
            content = (msg.body as ChatTextMessageBody).content;
          }
          final targetId = _agoraMsgIdToLocalId[msg.msgId] ?? msg.msgId;
          await _chatRepository.updateMessageContent(
            currentUid: activeUid,
            messageId: targetId,
            newContent: content,
          );
          if (targetId != msg.msgId) {
            await _chatRepository.updateMessageContent(
              currentUid: activeUid,
              messageId: msg.msgId,
              newContent: content,
            );
          }
          _notifyThreadUpdated(conversationId);
        },
        onMessageReactionDidChange:
            (List<ChatMessageReactionEvent> events) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          for (final event in events) {
            final parsed = await _reactionsFromChatReactionList(
              event.reactions,
              currentUid: activeUid,
            );
            final targetId =
                _agoraMsgIdToLocalId[event.messageId] ?? event.messageId;
            await _chatRepository.setMessageReactions(
              currentUid: activeUid,
              messageId: targetId,
              reactions: parsed,
            );
            _notifyThreadUpdated(event.conversationId);
          }
          await _syncConversationsFromLocal();
        },
      ),
      messageEvent: ChatMessageEvent(
        onSuccess: (String msgId, ChatMessage msg) async {
          final activeUid = _authenticatedUserId ?? _activeLocalUid();
          if (activeUid.isEmpty) return;
          final localId =
              msg.attributes?['localMessageId']?.toString() ?? msgId;
          await _updateMessageStatus(
            localId,
            ChatMessageStatus.sent,
            currentUid: activeUid,
            fallbackMessageId: msgId,
          );
        },
        onError: (String msgId, ChatMessage msg, ChatError error) async {
          final activeUid = _authenticatedUserId ?? _activeLocalUid();
          if (activeUid.isEmpty) return;
          final localId =
              msg.attributes?['localMessageId']?.toString() ?? msgId;
          developer.log(
            'Message send failed: ${error.code} ${error.description}',
            name: 'AgoraChatService',
          );
          await _updateMessageStatus(
            localId,
            ChatMessageStatus.failed,
            currentUid: activeUid,
            fallbackMessageId: msgId,
          );
        },
      ),
      connectionEventHandler: ConnectionEventHandler(
        onConnected: () async {
          if (_authenticatedUserId == null) return;
          developer.log('Agora Chat connected', name: 'AgoraChatService');
          _setConnectionState(ChatConnectionState.connected);
          unawaited(_drainOfflineQueue());
        },
        onDisconnected: () {
          developer.log('Agora Chat disconnected', name: 'AgoraChatService');
          if (_connectionState != ChatConnectionState.unavailable) {
            _setConnectionState(ChatConnectionState.disconnected);
          }
        },
        onTokenWillExpire: () async {
          final uid = _authenticatedUserId ?? _currentUserId;
          if (uid == null || uid.isEmpty) return;
          final creds = await _fetchAgoraCredentials();
          final token = creds?['token']?.toString();
          if (token != null && token.isNotEmpty) {
            try {
              await _sdk.renewAgoraToken(token);
              developer.log(
                'Agora Chat token renewed',
                name: 'AgoraChatService',
              );
              return;
            } catch (e) {
              developer.log(
                'Agora Chat token renewal failed ($e); re-authenticating.',
                name: 'AgoraChatService',
              );
            }
          }
          // Transition to recovery via full login/re-authentication.
          unawaited(_recoverExpiredOrRejectedSession(uid));
        },
        onTokenDidExpire: () async {
          developer.log(
            'Agora Chat token expired; re-login',
            name: 'AgoraChatService',
          );
          final uid = _authenticatedUserId ?? _currentUserId;
          if (uid != null && uid.isNotEmpty) {
            unawaited(_recoverExpiredOrRejectedSession(uid));
          }
        },
      ),
      groupEventHandler: ChatGroupEventHandler(
        onUserRemovedFromGroup: (String groupId, String? groupName) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          await _chatRepository.leaveGroupLocally(
            currentUid: activeUid,
            groupId: groupId,
          );
          await _syncConversationsFromLocal();
          _notifyThreadUpdated(groupId);
        },
        onGroupDestroyed: (String groupId, String? groupName) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          await _chatRepository.deleteConversation(
            currentUid: activeUid,
            conversationId: groupId,
          );
          await _syncConversationsFromLocal();
          _notifyThreadUpdated(groupId);
        },
        onMemberExitedFromGroup: (String groupId, String member) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          final resolved = await _resolveUidFromAgoraUsername(
            member,
            currentUid: activeUid,
          );
          await _chatRepository.removeGroupMemberLocally(
            currentUid: activeUid,
            groupId: groupId,
            memberId: resolved,
          );
          await _syncConversationsFromLocal();
        },
        onMemberJoinedFromGroup: (String groupId, String member) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          final resolved = await _resolveUidFromAgoraUsername(
            member,
            currentUid: activeUid,
          );
          await _chatRepository.addGroupMembersLocally(
            currentUid: activeUid,
            groupId: groupId,
            memberIds: [resolved],
          );
          await _syncConversationsFromLocal();
        },
        onAdminAddedFromGroup: (String groupId, String administrator) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          final resolved = await _resolveUidFromAgoraUsername(
            administrator,
            currentUid: activeUid,
          );
          await _chatRepository.promoteGroupAdminLocally(
            currentUid: activeUid,
            groupId: groupId,
            memberId: resolved,
          );
          await _syncConversationsFromLocal();
        },
        onAdminRemovedFromGroup: (String groupId, String administrator) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          final resolved = await _resolveUidFromAgoraUsername(
            administrator,
            currentUid: activeUid,
          );
          await _chatRepository.demoteGroupAdminLocally(
            currentUid: activeUid,
            groupId: groupId,
            memberId: resolved,
          );
          await _syncConversationsFromLocal();
        },
        onOwnerChangedFromGroup: (
          String groupId,
          String newOwner,
          String oldOwner,
        ) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          final resolved = await _resolveUidFromAgoraUsername(
            newOwner,
            currentUid: activeUid,
          );
          await _chatRepository.transferGroupOwnerLocally(
            currentUid: activeUid,
            groupId: groupId,
            newOwnerId: resolved,
          );
          await _syncConversationsFromLocal();
        },
        onSpecificationDidUpdate: (ChatGroup group) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          await _refreshSingleGroupFromServer(group.groupId, activeUid);
          await _syncConversationsFromLocal();
        },
        onAutoAcceptInvitationFromGroup: (
          String groupId,
          String inviter,
          String? inviteMessage,
        ) async {
          final activeUid = _authenticatedUserId;
          if (activeUid == null || activeUid.isEmpty) return;
          await _refreshSingleGroupFromServer(groupId, activeUid);
          await _syncConversationsFromLocal();
        },
      ),
    );
  }

  Future<void> _recoverExpiredOrRejectedSession(String uid) async {
    if (_currentUserId != uid) return;
    _authenticatedUserId = null;
    _authenticatedAgoraUsername = null;
    try {
      await _sdk.logout(true);
    } catch (_) {}
    await login(uid);
  }

  // ============================================================
  // LOGIN / LOGOUT
  // ============================================================

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _setConnectionState(ChatConnectionState.disconnected);
  }

  @override
  Future<void> login(String userId) async {
    if (userId.isEmpty) return;
    if (_currentUserId != userId) {
      _authGeneration++;
      _currentUserId = userId;
      _authenticatedUserId = null;
      _authenticatedAgoraUsername = null;
      _backfilledThreadsForUser.clear();
      _inFlightThreadBackfills.clear();
    }

    _pendingLoginUserId = userId;
    if (_loginLoopFuture != null) {
      await _loginLoopFuture;
      return;
    }

    final future = _runLoginLoop();
    _loginLoopFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loginLoopFuture, future)) {
        _loginLoopFuture = null;
      }
    }
  }

  Future<void> _runLoginLoop() async {
    while (_pendingLoginUserId != null) {
      final targetUid = _pendingLoginUserId!;
      _pendingLoginUserId = null;
      await _performLogin(targetUid);
    }
  }

  Future<void> _performLogin(String userId) async {
    final startGen = _authGeneration;
    if (_isStaleLogin(userId, startGen)) return;

    final creds = await _fetchAgoraCredentials();
    if (_isStaleLogin(userId, startGen)) return;

    if (creds == null) {
      // Ensure any lingering SDK session from a previous user is logged out.
      if (_initialized && await _isSdkLoggedIn()) {
        final expectedAgora = _sanitizeAgoraUid(userId);
        final sdkUser = await _sdk.getCurrentUsername();
        if (sdkUser == null ||
            sdkUser.toLowerCase() != expectedAgora.toLowerCase()) {
          try {
            await _sdk.logout(true);
          } catch (_) {}
        }
      }
      _authenticatedUserId = null;
      _authenticatedAgoraUsername = null;
      _setConnectionState(ChatConnectionState.unavailable);
      await _syncConversationsFromLocal();
      return;
    }

    _setConnectionState(ChatConnectionState.connecting);
    try {
      await _ensureInitialized(creds['appKey'].toString());
    } catch (e, st) {
      developer.log(
        'Agora Chat init/callback failure: $e',
        name: 'AgoraChatService',
        stackTrace: st,
      );
      if (!_isStaleLogin(userId, startGen)) {
        _authenticatedUserId = null;
        _authenticatedAgoraUsername = null;
        _setConnectionState(ChatConnectionState.unavailable);
        await _syncConversationsFromLocal();
      }
      return;
    }

    if (_isStaleLogin(userId, startGen)) return;

    final agoraUsername =
        creds['agoraUsername']?.toString() ?? _sanitizeAgoraUid(userId);
    final token = creds['token']?.toString() ?? '';
    if (token.isEmpty) {
      _authenticatedUserId = null;
      _authenticatedAgoraUsername = null;
      _setConnectionState(ChatConnectionState.unavailable);
      await _syncConversationsFromLocal();
      return;
    }

    final alreadyLoggedIn = await _isSdkLoggedIn();
    var needsSdkLogin = true;
    if (alreadyLoggedIn) {
      final currentLoggedIn = await _sdk.getCurrentUsername();
      if (currentLoggedIn != null &&
          currentLoggedIn.isNotEmpty &&
          currentLoggedIn.toLowerCase() == agoraUsername.toLowerCase()) {
        try {
          await _sdk.renewAgoraToken(token);
          needsSdkLogin = false;
        } catch (e, st) {
          developer.log(
            'Agora token renewal rejected ($e); transitioning to full re-login.',
            name: 'AgoraChatService',
            stackTrace: st,
          );
          needsSdkLogin = true;
          try {
            await _sdk.logout(true);
            await _armCallbacksWithRetry();
          } catch (logoutErr) {
            developer.log(
              'Logout during token-renewal recovery failed: $logoutErr',
              name: 'AgoraChatService',
            );
          }
        }
      } else {
        try {
          await _sdk.logout(true);
          await _armCallbacksWithRetry();
        } catch (logoutErr) {
          developer.log(
            'Logout of previous Agora account failed: $logoutErr',
            name: 'AgoraChatService',
          );
        }
      }
    }

    if (_isStaleLogin(userId, startGen)) return;

    if (needsSdkLogin) {
      try {
        await _sdk.loginWithToken(agoraUsername, token);
        developer.log(
          'Logged into Agora Chat as: $agoraUsername',
          name: 'AgoraChatService',
        );
      } catch (e, st) {
        final isAlreadyLoggedInError = _sdk.isAlreadyLoggedInError(e);
        if (!isAlreadyLoggedInError) {
          developer.log(
            'Failed to log into Agora Chat: $e. Operating in local-first mode.',
            name: 'AgoraChatService',
            stackTrace: st,
          );
          if (!_isStaleLogin(userId, startGen)) {
            _authenticatedUserId = null;
            _authenticatedAgoraUsername = null;
            _setConnectionState(ChatConnectionState.unavailable);
            await _syncConversationsFromLocal();
          }
          return;
        }

        // Verify the SDK is actually logged in as `agoraUsername` before
        // treating USER_ALREADY_LOGIN (code 200) as success.
        final sdkUsername = await _sdk.getCurrentUsername();
        final isExpectedSdkUser = sdkUsername != null &&
            sdkUsername.isNotEmpty &&
            sdkUsername.toLowerCase() == agoraUsername.toLowerCase();

        if (!isExpectedSdkUser) {
          developer.log(
            'USER_ALREADY_LOGIN mismatch: SDK user is "$sdkUsername", expected "$agoraUsername". Aborting sync.',
            name: 'AgoraChatService',
          );
          if (!_isStaleLogin(userId, startGen)) {
            _authenticatedUserId = null;
            _authenticatedAgoraUsername = null;
            _setConnectionState(ChatConnectionState.unavailable);
            await _syncConversationsFromLocal();
          }
          return;
        }

        // Ensure the already-logged-in session accepts the fresh token.
        try {
          await _sdk.renewAgoraToken(token);
        } catch (renewErr, renewSt) {
          developer.log(
            'Token renewal failed after USER_ALREADY_LOGIN: $renewErr',
            name: 'AgoraChatService',
            stackTrace: renewSt,
          );
          if (!_isStaleLogin(userId, startGen)) {
            _authenticatedUserId = null;
            _authenticatedAgoraUsername = null;
            _setConnectionState(ChatConnectionState.unavailable);
            await _syncConversationsFromLocal();
          }
          return;
        }
      }
    }

    if (_isStaleLogin(userId, startGen)) {
      return;
    }

    _authenticatedUserId = userId;
    _authenticatedAgoraUsername = agoraUsername;

    await _bindPushTokenBestEffort();
    if (_isStaleLogin(userId, startGen)) return;

    await _syncFromAgora(userId, startGen);
    if (_isStaleLogin(userId, startGen)) return;

    await _syncConversationsFromLocal();
    if (await _sdk.isConnected()) {
      _setConnectionState(ChatConnectionState.connected);
      unawaited(_drainOfflineQueue());
    }
  }

  Future<void> _bindPushTokenBestEffort() async {
    try {
      final pushToken = await _pushTokenProvider?.call();
      if (pushToken == null || pushToken.isEmpty) return;
      final notifier = Platform.isAndroid ? 'FCM' : 'APNs';
      await _sdk.bindDeviceToken(
        notifierName: notifier,
        deviceToken: pushToken,
      );
      developer.log(
        'Agora Chat push token bound ($notifier)',
        name: 'AgoraChatService',
      );
    } catch (e) {
      developer.log(
        'Agora Chat push binding skipped: $e',
        name: 'AgoraChatService',
      );
    }
  }

  @override
  Future<void> logout() async {
    _authGeneration++;
    _currentUserId = null;
    _authenticatedUserId = null;
    _authenticatedAgoraUsername = null;
    _pendingLoginUserId = null;
    _backfilledThreadsForUser.clear();
    _inFlightThreadBackfills.clear();

    for (final sub in _presenceSubs.values) {
      await sub.cancel();
    }
    _presenceSubs.clear();
    _presenceStates.clear();
    _setConnectionState(ChatConnectionState.disconnected);

    if (_initialized) {
      try {
        await _sdk.logout(true);
      } catch (_) {}
    }
    await _syncConversationsFromLocal();
  }

  // ============================================================
  // HISTORY SYNC — Agora server -> ChatRepository (full pagination)
  // ============================================================

  Future<List<ChatMessage>> _loadAllConversationMessages({
    required String targetUid,
    required String agoraConversationId,
    required ChatConversationType type,
    AgoraConversationHandle? convHandle,
  }) async {
    final byMsgId = <String, ChatMessage>{};

    final handle = convHandle ??
        await _sdk.getConversation(
          agoraConversationId,
          type: type,
          createIfNeed: true,
        );

    if (handle != null) {
      try {
        var startMsgId = '';
        final seenLocalCursors = <String>{};
        while (true) {
          final batch = await handle.loadMessages(
            startMsgId: startMsgId,
            loadCount: 50,
          );
          if (batch.isEmpty) break;
          ChatMessage? oldest;
          for (final m in batch) {
            if (m.msgId.isNotEmpty) {
              byMsgId[m.msgId] = m;
              if (oldest == null || m.serverTime < oldest.serverTime) {
                oldest = m;
              }
            }
          }
          if (batch.length < 50 || oldest == null || oldest.msgId.isEmpty) {
            break;
          }
          if (!seenLocalCursors.add(oldest.msgId)) {
            break;
          }
          startMsgId = oldest.msgId;
        }
      } catch (_) {}
    }

    if (await _isSdkAuthenticatedFor(targetUid)) {
      try {
        var startCursor = '';
        final seenHistoryCursors = <String>{};
        while (true) {
          final historyResult = await _sdk.fetchHistoryMessagesPage(
            conversationId: agoraConversationId,
            type: type,
            pageSize: 50,
            startMsgId: startCursor,
          );
          for (final m in historyResult.data) {
            if (m.msgId.isNotEmpty) {
              byMsgId[m.msgId] = m;
            }
          }
          final nextCursor = historyResult.cursor;
          if (historyResult.data.isEmpty ||
              nextCursor == null ||
              nextCursor.isEmpty ||
              !seenHistoryCursors.add(nextCursor)) {
            break;
          }
          startCursor = nextCursor;
        }
      } catch (e) {
        developer.log(
          'Agora fetchHistoryMessages notice for $agoraConversationId: $e',
          name: 'AgoraChatService',
        );
      }
    }

    if (byMsgId.isEmpty && handle != null) {
      try {
        final latest = await handle.latestMessage();
        if (latest != null && latest.msgId.isNotEmpty) {
          byMsgId[latest.msgId] = latest;
        }
      } catch (_) {}
    }

    final sorted = byMsgId.values.toList()
      ..sort((a, b) => a.serverTime.compareTo(b.serverTime));
    return sorted;
  }

  Future<void> _syncFromAgora(String targetUid, int startGen) async {
    try {
      if (_isStaleLogin(targetUid, startGen)) return;
      if (!await _isSdkAuthenticatedFor(targetUid)) return;

      final convByKey = <String, AgoraConversationHandle>{};
      void addConv(AgoraConversationHandle conv) {
        if (conv.id.isEmpty) return;
        final key = '${conv.type.name}:${conv.id.toLowerCase()}';
        convByKey.putIfAbsent(key, () => conv);
      }

      try {
        final localConvs = await _sdk.loadAllConversations();
        for (final c in localConvs) {
          addConv(c);
        }
      } catch (e) {
        developer.log(
          'Agora loadAllConversations error: $e',
          name: 'AgoraChatService',
        );
      }

      // Paginate through ALL server conversation pages via cursor.
      try {
        String? convCursor;
        final seenConvCursors = <String>{};
        while (true) {
          if (_isStaleLogin(targetUid, startGen)) return;
          final cursorResult = await _sdk.fetchConversationsPage(
            pageSize: 50,
            cursor: (convCursor != null && convCursor.isNotEmpty)
                ? convCursor
                : null,
          );
          for (final sc in cursorResult.data) {
            addConv(sc);
          }
          final nextCursor = cursorResult.cursor;
          if (cursorResult.data.isEmpty ||
              nextCursor == null ||
              nextCursor.isEmpty ||
              !seenConvCursors.add(nextCursor)) {
            break;
          }
          convCursor = nextCursor;
        }
      } catch (e) {
        developer.log(
          'Agora fetchConversationsByOptions notice: $e',
          name: 'AgoraChatService',
        );
        try {
          final serverConvs = await _sdk.getConversationsFromServerFallback();
          for (final sc in serverConvs) {
            addConv(sc);
          }
        } catch (fallbackErr) {
          developer.log(
            'Agora getConversationsFromServer notice: $fallbackErr',
            name: 'AgoraChatService',
          );
        }
      }

      if (_isStaleLogin(targetUid, startGen)) return;

      // Group discovery: pulls in all joined groups across pages and replaces
      // stale cached rosters with authoritative server membership.
      final joinedGroups = await _syncJoinedGroups(targetUid, startGen);
      for (final g in joinedGroups) {
        try {
          final groupConv = await _sdk.getConversation(
            g.groupId,
            type: ChatConversationType.GroupChat,
            createIfNeed: true,
          );
          if (groupConv != null) {
            addConv(groupConv);
          }
        } catch (_) {}
      }

      for (final conv in convByKey.values) {
        if (_isStaleLogin(targetUid, startGen)) return;
        try {
          final isGroup = conv.type == ChatConversationType.GroupChat;
          final messages = await _loadAllConversationMessages(
            targetUid: targetUid,
            agoraConversationId: conv.id,
            type: conv.type,
            convHandle: conv,
          );

          if (_isStaleLogin(targetUid, startGen)) return;

          if (messages.isEmpty && !isGroup) {
            await _ensureDmConversationExists(conv.id, currentUid: targetUid);
          } else {
            String? resolvedPeerId;
            for (final msg in messages) {
              resolvedPeerId = await _handleIncomingAgoraMessage(
                msg,
                targetAccountUid: targetUid,
                triggerNotification: false,
                countUnread: false,
                isGroup: isGroup,
              );
            }
            if (isGroup) {
              _backfilledThreadsForUser.add(conv.id);
            } else if (resolvedPeerId != null && resolvedPeerId.isNotEmpty) {
              _backfilledThreadsForUser.add(resolvedPeerId);
            }
          }
        } catch (e) {
          developer.log(
            'Error loading messages for conv ${conv.id}: $e',
            name: 'AgoraChatService',
          );
        }
      }
    } catch (e) {
      developer.log('Agora sync error: $e', name: 'AgoraChatService');
    }
  }

  Future<void> _ensureDmConversationExists(
    String rawPeerId, {
    required String currentUid,
  }) async {
    if (currentUid.isEmpty || rawPeerId.isEmpty) return;
    if (_authenticatedAgoraUsername != null &&
        rawPeerId.toLowerCase() == _authenticatedAgoraUsername!.toLowerCase()) {
      return;
    }

    final peerUid = await _resolveUidFromAgoraUsername(
      rawPeerId,
      currentUid: currentUid,
    );
    if (peerUid.isEmpty || _isSameFirebaseUid(peerUid, currentUid)) return;

    await _chatRepository.ensureDmConversationExists(
      currentUid: currentUid,
      peerUid: peerUid,
    );
  }

  Future<SyncedGroupInfo> _buildSyncedGroupInfo(
    ChatGroup baseGroup,
    String currentUid,
  ) async {
    final existingConv = await _chatRepository.getConversation(
      currentUid: currentUid,
      conversationId: baseGroup.groupId,
    );
    final candidateHints = <String>{
      if (existingConv != null) ...existingConv.memberIds,
      if (existingConv != null) ...existingConv.adminIds,
      if (existingConv?.ownerId != null) existingConv!.ownerId!,
    };

    ChatGroup detailed = baseGroup;
    try {
      detailed = await _sdk.fetchGroupInfoFromServer(baseGroup.groupId);
    } catch (_) {}

    List<String>? serverMembers = detailed.memberList ?? baseGroup.memberList;
    bool fetchedPaginatedMembers = false;
    try {
      final collected = <String>[];
      String? cursor;
      final seenCursors = <String>{};
      while (true) {
        final page = await _sdk.fetchGroupMembersPage(
          baseGroup.groupId,
          pageSize: 200,
          cursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
        );
        collected.addAll(page.data);
        fetchedPaginatedMembers = true;
        final next = page.cursor;
        if (page.data.isEmpty ||
            next == null ||
            next.isEmpty ||
            !seenCursors.add(next)) {
          break;
        }
        cursor = next;
      }
      if (fetchedPaginatedMembers) {
        // Combine paginated regular members with any inline memberList returned
        // on the specification object (excluding stale cached members).
        serverMembers = <String>{
          ...collected,
          if (detailed.memberList != null) ...detailed.memberList!,
        }.toList();
      }
    } catch (_) {}

    String? resolvedOwner;
    final rawOwner = detailed.owner ?? baseGroup.owner;
    if (rawOwner != null && rawOwner.isNotEmpty) {
      resolvedOwner = await _resolveUidFromAgoraUsername(
        rawOwner,
        currentUid: currentUid,
        additionalCandidates: candidateHints,
      );
    }

    final rawAdmins = detailed.adminList ?? baseGroup.adminList;
    final resolvedAdmins = <String>[];
    if (rawAdmins != null) {
      for (final a in rawAdmins) {
        if (a.isEmpty) continue;
        resolvedAdmins.add(
          await _resolveUidFromAgoraUsername(
            a,
            currentUid: currentUid,
            additionalCandidates: candidateHints,
          ),
        );
      }
    }

    final resolvedMembers = <String>[];
    if (serverMembers != null) {
      for (final m in serverMembers) {
        if (m.isEmpty) continue;
        resolvedMembers.add(
          await _resolveUidFromAgoraUsername(
            m,
            currentUid: currentUid,
            additionalCandidates: candidateHints,
          ),
        );
      }
    }

    return SyncedGroupInfo(
      groupId: detailed.groupId.isNotEmpty ? detailed.groupId : baseGroup.groupId,
      name: detailed.groupName ?? baseGroup.groupName,
      avatarUrl: detailed.avatarUrl ?? baseGroup.avatarUrl,
      description: detailed.desc ?? baseGroup.desc,
      ownerId: resolvedOwner,
      adminIds: resolvedAdmins,
      memberIds: resolvedMembers,
      adminsProvided: rawAdmins != null || fetchedPaginatedMembers,
      membersProvided: serverMembers != null,
      includeCurrentUser: true,
    );
  }

  Future<void> _refreshSingleGroupFromServer(
    String groupId,
    String currentUid,
  ) async {
    if (groupId.isEmpty || currentUid.isEmpty) return;
    try {
      final info = await _sdk.fetchGroupInfoFromServer(groupId);
      final synced = await _buildSyncedGroupInfo(info, currentUid);
      await _chatRepository.ingestGroups(
        currentUid: currentUid,
        groups: [synced],
        pruneMissingServerGroups: false,
      );
    } catch (e) {
      developer.log(
        'Agora single group refresh failed for $groupId: $e',
        name: 'AgoraChatService',
      );
    }
  }

  /// Mirrors every group the current user belongs to into [ChatRepository],
  /// paginating across all server pages and replacing stale cached rosters.
  Future<List<ChatGroup>> _syncJoinedGroups(
    String targetUid,
    int startGen,
  ) async {
    try {
      const pageSize = 20;
      var pageNum = 0;
      final allGroups = <ChatGroup>[];
      final seenGroupIds = <String>{};

      while (true) {
        if (_isStaleLogin(targetUid, startGen)) return const [];
        final page = await _sdk.fetchJoinedGroupsPage(
          pageSize: pageSize,
          pageNum: pageNum,
          needRole: true,
        );
        if (page.isEmpty) break;
        var addedInPage = 0;
        for (final g in page) {
          if (g.groupId.isNotEmpty && seenGroupIds.add(g.groupId)) {
            allGroups.add(g);
            addedInPage++;
          }
        }
        if (page.length < pageSize || addedInPage == 0) {
          break;
        }
        pageNum++;
      }

      final syncedInfos = <SyncedGroupInfo>[];
      for (final g in allGroups) {
        if (_isStaleLogin(targetUid, startGen)) return const [];
        syncedInfos.add(await _buildSyncedGroupInfo(g, targetUid));
      }

      if (_isStaleLogin(targetUid, startGen)) return const [];
      await _chatRepository.ingestGroups(
        currentUid: targetUid,
        groups: syncedInfos,
        pruneMissingServerGroups: true,
      );
      return allGroups;
    } catch (e) {
      developer.log(
        'Agora fetchJoinedGroupsFromServer error: $e',
        name: 'AgoraChatService',
      );
      return const [];
    }
  }

  // ============================================================
  // INBOX / THREAD (ChatRepository-backed)
  // ============================================================

  @override
  Stream<List<ChatConversationModel>> watchConversations() {
    final uid = _authService.getCurrentUserId();
    if (uid != null &&
        uid.isNotEmpty &&
        (!_initialized ||
            _currentUserId != uid ||
            _authenticatedUserId != uid)) {
      unawaited(login(uid));
    }
    unawaited(_syncConversationsFromLocal());
    return _conversationsController.stream;
  }

  @override
  Future<List<ChatConversationModel>> getConversations() async {
    final currentUid = _authService.getCurrentUserId() ?? _currentUserId ?? '';
    if (currentUid.isEmpty) return const [];

    final conversations = await _chatRepository.getConversations(
      currentUid: currentUid,
      isOnlineResolver: (peerUid) => _presenceStates[peerUid] ?? false,
    );

    for (final c in conversations) {
      if (!c.isGroup) {
        _ensureWatchingPresence(c.id);
      }
    }
    return conversations;
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty || conversationId.isEmpty) return;

    await _chatRepository.markConversationAsRead(
      currentUid: currentUid,
      conversationId: conversationId,
    );

    var isLogged = await _isSdkAuthenticatedFor(currentUid);
    if (!isLogged) {
      await login(currentUid);
      isLogged = await _isSdkAuthenticatedFor(currentUid);
    }

    if (isLogged) {
      try {
        final convType = await _agoraConversationType(
          currentUid: currentUid,
          conversationId: conversationId,
        );
        final agoraId = convType == ChatConversationType.GroupChat
            ? conversationId
            : _sanitizeAgoraUid(conversationId);
        final agoraConv = await _sdk.getConversation(agoraId, type: convType);
        await agoraConv?.markAllMessagesAsRead();
        if (convType != ChatConversationType.GroupChat) {
          await _sdk.sendConversationReadAck(agoraId);
          if (agoraConv != null) {
            final unreadList = await agoraConv.loadMessages(
              startMsgId: '',
              loadCount: 20,
            );
            for (final m in unreadList) {
              if (m.direction == MessageDirection.RECEIVE && !m.hasReadAck) {
                try {
                  await _sdk.sendMessageReadAck(m);
                } catch (_) {}
              }
            }
          }
        }
      } catch (e) {
        developer.log(
          'Agora sendConversationReadAck error: $e',
          name: 'AgoraChatService',
        );
      }
    }

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty || conversationId.isEmpty) return;

    final isGroup = await _chatRepository.isGroupConversation(
      currentUid: currentUid,
      conversationId: conversationId,
    );

    await _chatRepository.deleteConversation(
      currentUid: currentUid,
      conversationId: conversationId,
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        final agoraId =
            isGroup ? conversationId : _sanitizeAgoraUid(conversationId);
        await _sdk.deleteConversation(agoraId, deleteMessages: true);
      } catch (_) {}
    }

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> toggleMuteConversation(String conversationId) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty || conversationId.isEmpty) return;
    await _chatRepository.toggleMuteConversation(
      currentUid: currentUid,
      conversationId: conversationId,
    );
    await _syncConversationsFromLocal();
  }

  @override
  Stream<List<ChatMessageModel>> watchMessages(String conversationId) {
    if (!_messagesControllers.containsKey(conversationId)) {
      _messagesControllers[conversationId] =
          StreamController<List<ChatMessageModel>>.broadcast();
    }
    _notifyThreadUpdated(conversationId);
    return _messagesControllers[conversationId]!.stream;
  }

  Future<void> _backfillThreadFromAgora({
    required String currentUid,
    required String conversationId,
  }) async {
    final inflightKey = '$currentUid::$conversationId';
    if (_inFlightThreadBackfills.containsKey(inflightKey)) {
      await _inFlightThreadBackfills[inflightKey];
      return;
    }

    final future = () async {
      try {
        final convType = await _agoraConversationType(
          currentUid: currentUid,
          conversationId: conversationId,
        );
        final isGroup = convType == ChatConversationType.GroupChat;
        final agoraId =
            isGroup ? conversationId : _sanitizeAgoraUid(conversationId);

        final sortedMsgs = await _loadAllConversationMessages(
          targetUid: currentUid,
          agoraConversationId: agoraId,
          type: convType,
        );

        if (_activeLocalUid() != currentUid) return;

        for (final msg in sortedMsgs) {
          await _handleIncomingAgoraMessage(
            msg,
            targetAccountUid: currentUid,
            triggerNotification: false,
            countUnread: false,
            isGroup: isGroup,
            additionalUidCandidates: isGroup ? const [] : [conversationId],
          );
        }
        _backfilledThreadsForUser.add(conversationId);
      } catch (e) {
        developer.log(
          'Notice loading messages on demand from Agora: $e',
          name: 'AgoraChatService',
        );
      }
    }();

    _inFlightThreadBackfills[inflightKey] = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightThreadBackfills[inflightKey], future)) {
        _inFlightThreadBackfills.remove(inflightKey);
      }
    }
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    if (currentUid.isEmpty || conversationId.isEmpty) return const [];

    if (!_initialized ||
        _currentUserId != currentUid ||
        _authenticatedUserId != currentUid) {
      unawaited(login(currentUid));
    }

    var locals = await _chatRepository.getMessagesForThread(
      currentUid: currentUid,
      conversationId: conversationId,
    );

    // Backfill full paginated history from Agora if this thread has not yet
    // been completely synced in this session.
    if ((locals.isEmpty || !_backfilledThreadsForUser.contains(conversationId)) &&
        await _isSdkAuthenticatedFor(currentUid)) {
      await _backfillThreadFromAgora(
        currentUid: currentUid,
        conversationId: conversationId,
      );
      locals = await _chatRepository.getMessagesForThread(
        currentUid: currentUid,
        conversationId: conversationId,
      );
    }

    // Catch up any read acks recorded on the Agora SDK while offline/inactive
    if (await _isSdkAuthenticatedFor(currentUid) &&
        locals.any((m) =>
            _isSameFirebaseUid(m.senderId, currentUid) &&
            m.status != ChatMessageStatus.read)) {
      try {
        final convType = await _agoraConversationType(
          currentUid: currentUid,
          conversationId: conversationId,
        );
        final agoraId = convType == ChatConversationType.GroupChat
            ? conversationId
            : _sanitizeAgoraUid(conversationId);
        final conv = await _sdk.getConversation(agoraId, type: convType);
        if (conv != null) {
          final msgs = await conv.loadMessages(startMsgId: '', loadCount: 50);
          var hasUpdatedRead = false;
          for (final msg in msgs) {
            if (msg.hasReadAck) {
              final targetId = _agoraMsgIdToLocalId[msg.msgId] ??
                  msg.attributes?['localMessageId']?.toString() ??
                  msg.msgId;
              final match = locals.cast<ChatMessageModel?>().firstWhere(
                    (m) =>
                        m != null &&
                        (m.id == targetId || m.id == msg.msgId) &&
                        _isSameFirebaseUid(m.senderId, currentUid),
                    orElse: () => null,
                  );
              if (match != null && match.status != ChatMessageStatus.read) {
                await _chatRepository.updateMessageStatus(
                  currentUid: currentUid,
                  messageId: match.id,
                  fallbackMessageId: msg.msgId,
                  status: ChatMessageStatus.read,
                  conversationId: conversationId,
                );
                hasUpdatedRead = true;
              }
            }
          }
          if (hasUpdatedRead) {
            locals = await _chatRepository.getMessagesForThread(
              currentUid: currentUid,
              conversationId: conversationId,
            );
          }
        }
      } catch (_) {}
    }

    // Final safety check: guarantee every returned message belongs to the
    // exact requested conversation and authenticated user.
    final isGroup = await _chatRepository.isGroupConversation(
      currentUid: currentUid,
      conversationId: conversationId,
    );
    return locals.where((m) {
      if (m.conversationId != conversationId) return false;
      if (!isGroup) {
        return _isSameFirebaseUid(m.senderId, currentUid) ||
            _isSameFirebaseUid(m.senderId, conversationId);
      }
      return true;
    }).toList();
  }

  // ============================================================
  // INCOMING MESSAGE HANDLER
  // ============================================================

  Future<String?> _handleIncomingAgoraMessage(
    ChatMessage msg, {
    required String targetAccountUid,
    bool triggerNotification = true,
    bool countUnread = true,
    bool isGroup = false,
    Iterable<String> additionalUidCandidates = const [],
  }) async {
    try {
      if (targetAccountUid.isEmpty) return null;

      String textContent = '';
      ChatMessageType msgType = ChatMessageType.text;
      String? fileName;
      int? fileSize;

      if (msg.body is ChatTextMessageBody) {
        final body = msg.body as ChatTextMessageBody;
        textContent = body.content;
      } else if (msg.body is ChatImageMessageBody) {
        final body = msg.body as ChatImageMessageBody;
        textContent = body.remotePath ?? body.localPath;
        msgType = ChatMessageType.image;
        fileName = body.displayName;
        fileSize = body.fileSize;
      } else if (msg.body is ChatFileMessageBody) {
        final body = msg.body as ChatFileMessageBody;
        textContent = body.remotePath ?? body.localPath;
        msgType = ChatMessageType.file;
        fileName = body.displayName;
        fileSize = body.fileSize;
      } else if (msg.body is ChatCustomMessageBody) {
        final body = msg.body as ChatCustomMessageBody;
        if (body.event == 'board_share') {
          msgType = ChatMessageType.boardShare;
        } else if (body.event == 'workspace_share') {
          msgType = ChatMessageType.workspaceShare;
        } else if (body.event == 'gif') {
          msgType = ChatMessageType.gif;
        }
        textContent = body.params?['payload'] ?? '';
      }

      isGroup = isGroup || msg.chatType == ChatType.GroupChat;

      // Exact Firebase UID from wire attributes takes strict precedence over
      // Agora's normalized `msg.from` / `msg.to` usernames.
      final attrSenderUid = msg.attributes?['senderUid']?.toString() ?? '';
      final attrTargetUid = msg.attributes?['targetUid']?.toString() ?? '';

      final String senderId;
      if (attrSenderUid.isNotEmpty) {
        senderId = attrSenderUid;
      } else {
        senderId = await _resolveUidFromAgoraUsername(
          msg.from ?? '',
          currentUid: targetAccountUid,
          additionalCandidates: additionalUidCandidates,
        );
      }

      final isFromSelf = _isSameFirebaseUid(senderId, targetAccountUid);

      String conversationId;
      if (isGroup) {
        conversationId = (attrTargetUid.isNotEmpty)
            ? attrTargetUid
            : (msg.conversationId ?? msg.to ?? '');
      } else {
        if (isFromSelf) {
          if (attrTargetUid.isNotEmpty) {
            conversationId = attrTargetUid;
          } else {
            conversationId = await _resolveUidFromAgoraUsername(
              msg.to ?? msg.conversationId ?? '',
              currentUid: targetAccountUid,
              additionalCandidates: additionalUidCandidates,
            );
          }
        } else {
          // If an explicit `targetUid` attribute is present on an incoming DM
          // and points to a DIFFERENT Firebase UID (e.g. a colliding Agora
          // username intended for another Firebase user), reject it!
          if (attrTargetUid.isNotEmpty &&
              !_isSameFirebaseUid(attrTargetUid, targetAccountUid)) {
            return null;
          }
          conversationId = senderId;
        }
      }

      if (conversationId.isEmpty) return null;
      if (!isGroup && _isSameFirebaseUid(conversationId, targetAccountUid)) {
        return null;
      }

      final reactions = await _reactionsFromMessage(
        msg,
        currentUid: targetAccountUid,
      );

      final localMessageId = msg.attributes?['localMessageId']?.toString();
      if (localMessageId != null &&
          localMessageId.isNotEmpty &&
          msg.msgId.isNotEmpty) {
        _agoraMsgIdToLocalId[msg.msgId] = localMessageId;
      }

      final messageId = (!isFromSelf || localMessageId == null)
          ? msg.msgId
          : (localMessageId.isNotEmpty ? localMessageId : msg.msgId);
      final isOwnEcho = isFromSelf && localMessageId != null;

      ChatSharePayload? sharePayload;
      if (msgType == ChatMessageType.boardShare ||
          msgType == ChatMessageType.workspaceShare) {
        try {
          sharePayload = ChatSharePayload.fromJsonString(textContent);
        } catch (_) {}
      }

      final active = !isGroup && _isThreadActive(conversationId);
      if (active && !isFromSelf) {
        try {
          final agoraPeerId = _sanitizeAgoraUid(conversationId);
          await _sdk.sendConversationReadAck(agoraPeerId);
          await _sdk.sendMessageReadAck(msg);
        } catch (_) {}
      }

      final ChatMessageStatus status;
      if (isOwnEcho) {
        if (msg.hasReadAck) {
          status = ChatMessageStatus.read;
        } else if (msg.hasDeliverAck) {
          status = ChatMessageStatus.delivered;
        } else {
          status = ChatMessageStatus.sent;
        }
      } else {
        status = ChatMessageStatus.delivered;
      }

      final model = ChatMessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderName: msg.attributes?['senderName']?.toString() ?? senderId,
        senderAvatar: msg.attributes?['senderAvatar']?.toString(),
        type: msgType,
        content: textContent,
        timestamp: DateTime.fromMillisecondsSinceEpoch(msg.serverTime),
        status: status,
        reactions: reactions,
        fileName: fileName,
        fileSize: fileSize,
        sharePayload: sharePayload,
        replyToId: msg.attributes?['replyToId']?.toString(),
        replyToSender: msg.attributes?['replyToSender']?.toString(),
        replyToText: msg.attributes?['replyToText']?.toString(),
      );

      await _persistMessageLocally(
        model,
        currentUid: targetAccountUid,
        isGroup: isGroup,
        countUnread: countUnread && !active,
      );

      if (triggerNotification && senderId.isNotEmpty && !active) {
        if (!isFromSelf &&
            DateTime.now().difference(model.timestamp).inMinutes.abs() < 2) {
          final conv = await _chatRepository.getConversation(
            currentUid: targetAccountUid,
            conversationId: conversationId,
          );
          final isMuted = conv?.isMuted ?? false;
          if (!isMuted) {
            final notifyTitle = isGroup
                ? (conv != null && conv.name.isNotEmpty
                    ? '${conv.name} (${model.senderName})'
                    : model.senderName)
                : model.senderName;
            final notifyBody = model.type == ChatMessageType.text
                ? model.content
                : '[${model.type.name}]';
            await LocalNotificationService.showNotification(
              title: notifyTitle,
              body: notifyBody,
              largeIcon: model.senderAvatar,
              payload: {
                'type': 'chat_message',
                'targetId': conversationId,
                'senderName':
                    isGroup ? (conv?.name ?? 'Group') : model.senderName,
                'isGroup': isGroup.toString(),
              },
            );
          }
        }
      }
      return conversationId;
    } catch (e) {
      developer.log(
        'Error handling incoming Agora message: $e',
        name: 'AgoraChatService',
      );
      return null;
    }
  }

  Future<Map<String, List<String>>> _reactionsFromMessage(
    ChatMessage msg, {
    required String currentUid,
  }) async {
    try {
      final list = await _sdk.getMessageReactionList(msg);
      return await _reactionsFromChatReactionList(list, currentUid: currentUid);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, List<String>>> _reactionsFromChatReactionList(
    List<ChatMessageReaction>? reactList, {
    required String currentUid,
  }) async {
    final parsed = <String, List<String>>{};
    if (reactList == null) return parsed;
    for (final r in reactList) {
      if (r.userCount <= 0) continue;
      final rawUsers = r.userList.toList();
      if (rawUsers.isEmpty) {
        parsed[r.reaction] = List.filled(r.userCount, 'unknown-user');
      } else {
        final resolvedUsers = <String>[];
        for (final u in rawUsers) {
          resolvedUsers.add(
            await _resolveUidFromAgoraUsername(u, currentUid: currentUid),
          );
        }
        parsed[r.reaction] = resolvedUsers;
      }
    }
    return parsed;
  }

  Future<ChatConversationType> _agoraConversationType({
    required String currentUid,
    required String conversationId,
  }) async {
    final isGroup = await _chatRepository.isGroupConversation(
      currentUid: currentUid,
      conversationId: conversationId,
    );
    return isGroup ? ChatConversationType.GroupChat : ChatConversationType.Chat;
  }

  // ============================================================
  // LOCAL PERSISTENCE DELEGATION (via ChatRepository)
  // ============================================================

  Future<void> _persistMessageLocally(
    ChatMessageModel model, {
    required String currentUid,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    bool countUnread = true,
  }) async {
    await _chatRepository.persistMessage(
      currentUid: currentUid,
      model: model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
      countUnread: countUnread,
    );

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(model.conversationId);
  }

  void _notifyThreadUpdated(String conversationId) async {
    final controller = _messagesControllers[conversationId];
    if (controller != null && !controller.isClosed) {
      final messages = await getMessages(conversationId);
      if (!controller.isClosed) {
        controller.add(messages);
      }
    }
  }

  Future<void> _syncConversationsFromLocal() async {
    final conversations = await getConversations();
    if (!_conversationsController.isClosed) {
      _conversationsController.add(conversations);
    }
  }

  Future<void> _updateMessageStatus(
    String messageId,
    ChatMessageStatus status, {
    required String currentUid,
    String? fallbackMessageId,
    String? conversationId,
  }) async {
    final resolvedId = _agoraMsgIdToLocalId[messageId] ?? messageId;
    final updatedConvId = await _chatRepository.updateMessageStatus(
      currentUid: currentUid,
      messageId: resolvedId,
      fallbackMessageId: fallbackMessageId ?? messageId,
      status: status,
      conversationId: conversationId,
    );

    if (updatedConvId != null && updatedConvId.isNotEmpty) {
      _notifyThreadUpdated(updatedConvId);
    }
  }

  Future<void> _markMessageRecalledLocally(
    String currentUid,
    String conversationId,
    String messageId,
  ) async {
    final resolvedId = _agoraMsgIdToLocalId[messageId] ?? messageId;
    await _chatRepository.markMessageRecalled(
      currentUid: currentUid,
      messageId: resolvedId,
    );
    if (resolvedId != messageId) {
      await _chatRepository.markMessageRecalled(
        currentUid: currentUid,
        messageId: messageId,
      );
    }
    if (conversationId.isNotEmpty) {
      _notifyThreadUpdated(conversationId);
    }
  }

  /// Rebuilds an Agora `ChatMessage` from a locally queued `ChatMessageModel`
  /// so `sending`/`failed` messages can be replayed after reconnect.
  ChatMessage? _rebuildAgoraMessage(
    ChatMessageModel local,
    String targetId,
    bool isGroup,
  ) {
    final chatType = isGroup ? ChatType.GroupChat : ChatType.Chat;
    final attributes = <String, dynamic>{
      'senderUid': local.senderId,
      'targetUid': local.conversationId,
      'senderName': local.senderName,
      'senderAvatar': local.senderAvatar ?? '',
      'localMessageId': local.id,
      if (local.replyToId != null) 'replyToId': local.replyToId,
      if (local.replyToSender != null) 'replyToSender': local.replyToSender,
      if (local.replyToText != null) 'replyToText': local.replyToText,
    };
    try {
      final ChatMessage msg;
      switch (local.type) {
        case ChatMessageType.text:
          msg = ChatMessage.createTxtSendMessage(
            targetId: targetId,
            content: local.content,
            chatType: chatType,
          );
          break;
        case ChatMessageType.image:
          msg = ChatMessage.createImageSendMessage(
            targetId: targetId,
            filePath: local.content,
            displayName: local.fileName,
            chatType: chatType,
          );
          break;
        case ChatMessageType.gif:
          msg = ChatMessage.createCustomSendMessage(
            targetId: targetId,
            event: 'gif',
            params: {'payload': local.content},
            chatType: chatType,
          );
          break;
        case ChatMessageType.file:
          msg = ChatMessage.createFileSendMessage(
            targetId: targetId,
            filePath: local.content,
            displayName: local.fileName ?? local.content.split('/').last,
            chatType: chatType,
          );
          break;
        case ChatMessageType.boardShare:
        case ChatMessageType.workspaceShare:
          msg = ChatMessage.createCustomSendMessage(
            targetId: targetId,
            event: local.type == ChatMessageType.boardShare
                ? 'board_share'
                : 'workspace_share',
            params: {'payload': local.content},
            chatType: chatType,
          );
          break;
      }
      msg.attributes = attributes;
      return msg;
    } catch (e) {
      developer.log(
        'Failed to rebuild message for retry: $e',
        name: 'AgoraChatService',
      );
      return null;
    }
  }

  /// Sends queued (`sending`) and failed messages when the connection returns.
  Future<void> _drainOfflineQueue() async {
    try {
      final currentUid = _authService.getCurrentUserId();
      if (currentUid == null || currentUid.isEmpty) return;
      if (!await _isSdkAuthenticatedFor(currentUid)) return;
      if (!await _sdk.isConnected()) return;

      final queued = await _chatRepository.getQueuedOutgoingMessages(
        currentUid: currentUid,
      );

      for (final local in queued) {
        if (!await _isSdkAuthenticatedFor(currentUid)) return;
        final isGroup = await _chatRepository.isGroupConversation(
          currentUid: currentUid,
          conversationId: local.conversationId,
        );
        final targetId = isGroup
            ? local.conversationId
            : _sanitizeAgoraUid(local.conversationId);
        final msg = _rebuildAgoraMessage(local, targetId, isGroup);
        if (msg == null) continue;
        try {
          final sent = await _sdk.sendMessage(msg);
          if (sent.msgId.isNotEmpty) {
            _agoraMsgIdToLocalId[sent.msgId] = local.id;
          }
          await _updateMessageStatus(
            local.id,
            ChatMessageStatus.sent,
            currentUid: currentUid,
            conversationId: local.conversationId,
          );
        } catch (e) {
          developer.log(
            'Queued message retry failed: $e',
            name: 'AgoraChatService',
          );
        }
      }
    } catch (e) {
      developer.log('Offline queue drain error: $e', name: 'AgoraChatService');
    }
  }

  // ============================================================
  // SEND PATHS — Agora-only
  // ============================================================

  Future<ChatMessageModel> _send({
    required ChatMessage agoraMsg,
    required ChatMessageModel model,
    required String senderUid,
    required bool isGroup,
  }) async {
    var isLogged = await _isSdkAuthenticatedFor(senderUid);
    if (!isLogged && senderUid.isNotEmpty && senderUid != 'unknown') {
      await login(senderUid);
      isLogged = await _isSdkAuthenticatedFor(senderUid);
    }
    if (!isLogged) {
      await _updateMessageStatus(
        model.id,
        ChatMessageStatus.failed,
        currentUid: senderUid,
        conversationId: model.conversationId,
      );
      return model.copyWith(status: ChatMessageStatus.failed);
    }
    try {
      final sent = await _sdk.sendMessage(agoraMsg);
      if (sent.msgId.isNotEmpty) {
        _agoraMsgIdToLocalId[sent.msgId] = model.id;
      }
      final accepted = sent.status != MessageStatus.FAIL;
      await _updateMessageStatus(
        model.id,
        accepted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        currentUid: senderUid,
        conversationId: model.conversationId,
      );
      return model.copyWith(
        status: accepted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
      );
    } catch (e, st) {
      developer.log(
        'Agora send failure: $e',
        name: 'AgoraChatService',
        stackTrace: st,
      );
      await _updateMessageStatus(
        model.id,
        ChatMessageStatus.failed,
        currentUid: senderUid,
        conversationId: model.conversationId,
      );
      return model.copyWith(status: ChatMessageStatus.failed);
    }
  }

  @override
  Future<ChatMessageModel> sendTextMessage({
    required String conversationId,
    required String text,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final currentUser = _authService.getCurrentUser();
    final currentUid =
        currentUser?.uid ?? _authService.getCurrentUserId() ?? 'unknown';
    final currentName = currentUser?.displayName ?? 'You';
    final currentAvatar = currentUser?.photoURL;
    final messageId = const Uuid().v4();

    final model = ChatMessageModel(
      id: messageId,
      conversationId: conversationId,
      senderId: currentUid,
      senderName: currentName,
      senderAvatar: currentAvatar,
      type: ChatMessageType.text,
      content: text,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
      replyToId: replyToId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    await _persistMessageLocally(
      model,
      currentUid: currentUid,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
      countUnread: false,
    );

    final agoraMsg = ChatMessage.createTxtSendMessage(
      targetId: isGroup ? conversationId : _sanitizeAgoraUid(conversationId),
      content: text,
      chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
    );
    agoraMsg.attributes = {
      'senderUid': currentUid,
      'targetUid': conversationId,
      'senderName': currentName,
      'senderAvatar': currentAvatar ?? '',
      'localMessageId': messageId,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (replyToText != null) 'replyToText': replyToText,
    };

    return _send(
      agoraMsg: agoraMsg,
      model: model,
      senderUid: currentUid,
      isGroup: isGroup,
    );
  }

  @override
  Future<ChatMessageModel> sendImageMessage({
    required String conversationId,
    required String filePath,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final currentUser = _authService.getCurrentUser();
    final currentUid =
        currentUser?.uid ?? _authService.getCurrentUserId() ?? 'unknown';
    final currentName = currentUser?.displayName ?? 'You';
    final currentAvatar = currentUser?.photoURL;
    final messageId = const Uuid().v4();

    final file = File(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final fileSize = file.existsSync() ? file.lengthSync() : null;

    final model = ChatMessageModel(
      id: messageId,
      conversationId: conversationId,
      senderId: currentUid,
      senderName: currentName,
      senderAvatar: currentAvatar,
      type: ChatMessageType.image,
      content: filePath,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
      fileName: fileName,
      fileSize: fileSize,
      replyToId: replyToId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    await _persistMessageLocally(
      model,
      currentUid: currentUid,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
      countUnread: false,
    );

    final agoraMsg = ChatMessage.createImageSendMessage(
      targetId: isGroup ? conversationId : _sanitizeAgoraUid(conversationId),
      filePath: filePath,
      displayName: fileName,
      chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
    );
    agoraMsg.attributes = {
      'senderUid': currentUid,
      'targetUid': conversationId,
      'senderName': currentName,
      'senderAvatar': currentAvatar ?? '',
      'localMessageId': messageId,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (replyToText != null) 'replyToText': replyToText,
    };

    return _send(
      agoraMsg: agoraMsg,
      model: model,
      senderUid: currentUid,
      isGroup: isGroup,
    );
  }

  @override
  Future<ChatMessageModel> sendGifMessage({
    required String conversationId,
    required String gifUrl,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final currentUser = _authService.getCurrentUser();
    final currentUid =
        currentUser?.uid ?? _authService.getCurrentUserId() ?? 'unknown';
    final currentName = currentUser?.displayName ?? 'You';
    final currentAvatar = currentUser?.photoURL;
    final messageId = const Uuid().v4();

    final model = ChatMessageModel(
      id: messageId,
      conversationId: conversationId,
      senderId: currentUid,
      senderName: currentName,
      senderAvatar: currentAvatar,
      type: ChatMessageType.gif,
      content: gifUrl,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
      replyToId: replyToId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    await _persistMessageLocally(
      model,
      currentUid: currentUid,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
      countUnread: false,
    );

    final agoraMsg = ChatMessage.createCustomSendMessage(
      targetId: isGroup ? conversationId : _sanitizeAgoraUid(conversationId),
      event: 'gif',
      params: {'payload': gifUrl},
      chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
    );
    agoraMsg.attributes = {
      'senderUid': currentUid,
      'targetUid': conversationId,
      'senderName': currentName,
      'senderAvatar': currentAvatar ?? '',
      'localMessageId': messageId,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (replyToText != null) 'replyToText': replyToText,
    };

    return _send(
      agoraMsg: agoraMsg,
      model: model,
      senderUid: currentUid,
      isGroup: isGroup,
    );
  }

  @override
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
  }) async {
    final currentUser = _authService.getCurrentUser();
    final currentUid =
        currentUser?.uid ?? _authService.getCurrentUserId() ?? 'unknown';
    final currentName = currentUser?.displayName ?? 'You';
    final currentAvatar = currentUser?.photoURL;
    final messageId = const Uuid().v4();

    final model = ChatMessageModel(
      id: messageId,
      conversationId: conversationId,
      senderId: currentUid,
      senderName: currentName,
      senderAvatar: currentAvatar,
      type: ChatMessageType.file,
      content: filePath,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
      fileName: fileName,
      fileSize: fileSize,
      replyToId: replyToId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    await _persistMessageLocally(
      model,
      currentUid: currentUid,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
      countUnread: false,
    );

    final agoraMsg = ChatMessage.createFileSendMessage(
      targetId: isGroup ? conversationId : _sanitizeAgoraUid(conversationId),
      filePath: filePath,
      displayName: fileName,
      chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
    );
    agoraMsg.attributes = {
      'senderUid': currentUid,
      'targetUid': conversationId,
      'senderName': currentName,
      'senderAvatar': currentAvatar ?? '',
      'localMessageId': messageId,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (replyToText != null) 'replyToText': replyToText,
    };

    return _send(
      agoraMsg: agoraMsg,
      model: model,
      senderUid: currentUid,
      isGroup: isGroup,
    );
  }

  @override
  Future<ChatMessageModel> sendShareCardMessage({
    required String conversationId,
    required ChatSharePayload payload,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    String? replyToId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final currentUser = _authService.getCurrentUser();
    final currentUid =
        currentUser?.uid ?? _authService.getCurrentUserId() ?? 'unknown';
    final currentName = currentUser?.displayName ?? 'You';
    final currentAvatar = currentUser?.photoURL;
    final messageId = const Uuid().v4();

    final isBoard = payload.type == ChatShareType.board;
    final model = ChatMessageModel(
      id: messageId,
      conversationId: conversationId,
      senderId: currentUid,
      senderName: currentName,
      senderAvatar: currentAvatar,
      type: isBoard
          ? ChatMessageType.boardShare
          : ChatMessageType.workspaceShare,
      content: payload.toJsonString(),
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
      sharePayload: payload,
      replyToId: replyToId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    await _persistMessageLocally(
      model,
      currentUid: currentUid,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
      countUnread: false,
    );

    final agoraMsg = ChatMessage.createCustomSendMessage(
      targetId: isGroup ? conversationId : _sanitizeAgoraUid(conversationId),
      event: isBoard ? 'board_share' : 'workspace_share',
      params: {'payload': payload.toJsonString()},
      chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
    );
    agoraMsg.attributes = {
      'senderUid': currentUid,
      'targetUid': conversationId,
      'senderName': currentName,
      'senderAvatar': currentAvatar ?? '',
      'localMessageId': messageId,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (replyToText != null) 'replyToText': replyToText,
    };

    return _send(
      agoraMsg: agoraMsg,
      model: model,
      senderUid: currentUid,
      isGroup: isGroup,
    );
  }

  // ============================================================
  // REACTIONS / EDIT / DELETE — Agora-authoritative
  // ============================================================

  @override
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty) return;

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.addReaction(messageId: messageId, reaction: emoji);
      } catch (e) {
        developer.log('Agora addReaction failed: $e', name: 'AgoraChatService');
      }
    }

    final affected = await _chatRepository.addReactionLocally(
      currentUid: currentUid,
      messageId: messageId,
      reactorUid: currentUid,
      emoji: emoji,
    );

    _notifyThreadUpdated(conversationId);
    if (affected.conversationId != null &&
        affected.conversationId!.isNotEmpty &&
        affected.conversationId != conversationId) {
      _notifyThreadUpdated(affected.conversationId!);
    }
    if (affected.senderId != null &&
        affected.senderId!.isNotEmpty &&
        affected.senderId != conversationId) {
      _notifyThreadUpdated(affected.senderId!);
    }
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty) return;

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.removeReaction(messageId: messageId, reaction: emoji);
      } catch (e) {
        developer.log(
          'Agora removeReaction failed: $e',
          name: 'AgoraChatService',
        );
      }
    }

    final affected = await _chatRepository.removeReactionLocally(
      currentUid: currentUid,
      messageId: messageId,
      reactorUid: currentUid,
      emoji: emoji,
    );

    _notifyThreadUpdated(conversationId);
    if (affected.conversationId != null &&
        affected.conversationId!.isNotEmpty &&
        affected.conversationId != conversationId) {
      _notifyThreadUpdated(affected.conversationId!);
    }
    if (affected.senderId != null &&
        affected.senderId!.isNotEmpty &&
        affected.senderId != conversationId) {
      _notifyThreadUpdated(affected.senderId!);
    }
  }

  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty) return;

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.modifyMessage(
          messageId: messageId,
          msgBody: ChatTextMessageBody(content: newContent),
        );
      } catch (e) {
        developer.log(
          'Agora modifyMessage failed: $e',
          name: 'AgoraChatService',
        );
      }
    }

    await _chatRepository.updateMessageContent(
      currentUid: currentUid,
      messageId: messageId,
      newContent: newContent,
    );

    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final currentUid = _activeLocalUid();
    if (currentUid.isEmpty) return;

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.recallMessage(messageId);
      } catch (e) {
        developer.log(
          'Agora recallMessage fallback (local delete): $e',
          name: 'AgoraChatService',
        );
        try {
          final convType = await _agoraConversationType(
            currentUid: currentUid,
            conversationId: conversationId,
          );
          final agoraConvId = convType == ChatConversationType.GroupChat
              ? conversationId
              : _sanitizeAgoraUid(conversationId);
          final conv = await _sdk.getConversation(agoraConvId, type: convType);
          if (conv != null) {
            await conv.deleteMessage(messageId);
          }
        } catch (_) {}
      }
    }

    await _markMessageRecalledLocally(currentUid, conversationId, messageId);
  }

  // ============================================================
  // GROUP MANAGEMENT — Agora groups are the source of truth
  // ============================================================

  @override
  Future<ChatConversationModel> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    String? iconUrl,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';

    String? agoraGroupId;
    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        final options = ChatGroupOptions(
          style: ChatGroupStyle.PublicJoinNeedApproval,
          maxCount: 200,
        );
        final group = await _sdk.createGroup(
          groupName: name,
          avatarUrl: iconUrl,
          desc: description,
          options: options,
          inviteMembers: memberIds.map(_sanitizeAgoraUid).toList(),
        );
        if (group.groupId.isNotEmpty) {
          agoraGroupId = group.groupId;
        }
      } catch (e) {
        developer.log(
          'Agora createGroup failed (offline fallback id): $e',
          name: 'AgoraChatService',
        );
      }
    }

    final groupId =
        agoraGroupId ?? 'group_${const Uuid().v4().substring(0, 8)}';
    final created = await _chatRepository.saveCreatedGroup(
      currentUid: currentUid,
      groupId: groupId,
      name: name,
      description: description,
      memberIds: memberIds,
      iconUrl: iconUrl,
      createdAt: DateTime.now(),
    );

    await _syncConversationsFromLocal();
    return created;
  }

  Future<ChatConversationModel> _requireAuthorizedGroup(
    String currentUid,
    String groupId, {
    required bool ownerOnly,
    required String errorMessage,
  }) async {
    final group = await _chatRepository.getConversation(
      currentUid: currentUid,
      conversationId: groupId,
    );
    if (group == null || !group.isGroup) {
      throw StateError(errorMessage);
    }
    if (ownerOnly) {
      if (!group.isUserOwner(currentUid)) {
        throw StateError(errorMessage);
      }
    } else if (!group.isUserAdmin(currentUid)) {
      throw StateError(errorMessage);
    }
    return group;
  }

  @override
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: false,
      errorMessage: 'Only a group owner or admin can update group info.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        if (name != null && name.isNotEmpty) {
          await _sdk.updateGroupName(groupId, name);
        }
        if (description != null) {
          await _sdk.updateGroupDesc(groupId, description);
        }
        if (iconUrl != null && iconUrl.isNotEmpty) {
          await _sdk.updateGroupAvatar(groupId: groupId, avatarUrl: iconUrl);
        }
      } catch (e) {
        developer.log('Agora group update failed: $e', name: 'AgoraChatService');
      }
    }

    await _chatRepository.updateGroupInfoLocally(
      currentUid: currentUid,
      groupId: groupId,
      name: name,
      description: description,
      iconUrl: iconUrl,
    );

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: false,
      errorMessage: 'Only a group owner or admin can add members.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.addGroupMembers(
          groupId,
          memberIds.map(_sanitizeAgoraUid).toList(),
        );
      } catch (e) {
        developer.log('Agora addMembers failed: $e', name: 'AgoraChatService');
      }
    }

    await _chatRepository.addGroupMembersLocally(
      currentUid: currentUid,
      groupId: groupId,
      memberIds: memberIds,
    );

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: false,
      errorMessage: 'Only a group owner or admin can remove members.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.removeGroupMembers(groupId, [_sanitizeAgoraUid(memberId)]);
      } catch (e) {
        developer.log(
          'Agora removeMembers failed: $e',
          name: 'AgoraChatService',
        );
      }
    }

    await _chatRepository.removeGroupMemberLocally(
      currentUid: currentUid,
      groupId: groupId,
      memberId: memberId,
    );

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> promoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: true,
      errorMessage: 'Only the group owner can promote admins.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.addGroupAdmin(groupId, _sanitizeAgoraUid(memberId));
      } catch (e) {
        developer.log('Agora addAdmin failed: $e', name: 'AgoraChatService');
      }
    }

    await _chatRepository.promoteGroupAdminLocally(
      currentUid: currentUid,
      groupId: groupId,
      memberId: memberId,
    );

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> demoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: true,
      errorMessage: 'Only the group owner can demote admins.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.removeGroupAdmin(groupId, _sanitizeAgoraUid(memberId));
      } catch (e) {
        developer.log('Agora removeAdmin failed: $e', name: 'AgoraChatService');
      }
    }

    await _chatRepository.demoteGroupAdminLocally(
      currentUid: currentUid,
      groupId: groupId,
      memberId: memberId,
    );

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> transferGroupOwner({
    required String groupId,
    required String newOwnerId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: true,
      errorMessage: 'Only the group owner can transfer ownership.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.changeGroupOwner(groupId, _sanitizeAgoraUid(newOwnerId));
      } catch (e) {
        developer.log('Agora changeOwner failed: $e', name: 'AgoraChatService');
      }
    }

    await _chatRepository.transferGroupOwnerLocally(
      currentUid: currentUid,
      groupId: groupId,
      newOwnerId: newOwnerId,
    );

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    if (currentUid.isEmpty) return;

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.leaveGroup(groupId);
      } catch (e) {
        developer.log('Agora leaveGroup failed: $e', name: 'AgoraChatService');
      }
    }

    await _chatRepository.leaveGroupLocally(
      currentUid: currentUid,
      groupId: groupId,
    );

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(groupId);
  }

  @override
  Future<void> destroyGroup(String groupId) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await _requireAuthorizedGroup(
      currentUid,
      groupId,
      ownerOnly: true,
      errorMessage: 'Only the group owner can destroy the group.',
    );

    if (await _isSdkAuthenticatedFor(currentUid)) {
      try {
        await _sdk.destroyGroup(groupId);
      } catch (e) {
        developer.log(
          'Agora destroyGroup failed: $e',
          name: 'AgoraChatService',
        );
      }
    }

    await deleteConversation(groupId);
    await _syncConversationsFromLocal();
  }

  @override
  Future<Map<String, ChatMemberProfile>> getMemberProfiles(
    List<String> uids,
  ) {
    return _chatRepository.getMemberProfiles(uids);
  }

  @override
  Stream<ChatConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Future<void> dispose() async {
    await logout();
    await _conversationsController.close();
    for (final c in _messagesControllers.values) {
      await c.close();
    }
    _messagesControllers.clear();
    await _connectionStateController.close();
    if (_ownsHttpClient) {
      _http.close();
    }
  }
}
