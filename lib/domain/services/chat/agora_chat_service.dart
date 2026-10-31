import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:isar_community/isar.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/database/collections/local_chat_conversation.dart';
import '../../../core/database/collections/local_chat_message.dart';
import '../../../core/database/collections/local_profile.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/utils/network_config.dart';
import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../models/chat/chat_share_payload.dart';
import '../presence/presence_service.dart';
import 'chat_service.dart';

/// Chat transport backed *exclusively* by the Agora Chat SDK.
///
/// Data flow:
/// - Sends: Isar (`sending`) -> Agora `sendMessage` -> `sent` on SDK ack,
///   `failed` on error. Nothing is mirrored to Firestore.
/// - Receives: Agora events (`onMessagesReceived`, delivery/read acks,
///   recall/edit/reaction events) -> Isar.
/// - History: Agora server conversations + local Isar cache. Catch-up happens
///   at login via `_syncFromAgora`.
/// - Auth: a per-user Chat token minted by the InkLink server
///   (`POST /api/agora/chat/token`, Bearer Firebase ID token). The token is
///   renewed on `onTokenWillExpire` / refreshed-with-login on expiry.
///
/// If the token endpoint is unreachable (no VPN / server down / chat not
/// provisioned), the service stays in "local-first" mode: messages are
/// persisted to Isar and queued, then drained automatically once Agora
/// connects.
class AgoraChatServiceImpl implements ChatService {
  final LocalDatabaseService _localDbService;
  final AuthService _authService;
  final PresenceService? _presenceService;

  /// Resolves the device push token (FCM/APNs) for Agora offline push
  /// binding. Best-effort; null provider simply skips binding.
  final Future<String?> Function()? _pushTokenProvider;

  final http.Client _http = http.Client();

  bool _initialized = false;
  String? _initAppKey;
  String? _currentUserId;
  bool _loginInFlight = false;

  final StreamController<List<ChatConversationModel>> _conversationsController =
      StreamController<List<ChatConversationModel>>.broadcast();
  final Map<String, StreamController<List<ChatMessageModel>>> _messagesControllers = {};
  final Map<String, String> _canonicalThreadIds = {};
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
    required LocalDatabaseService localDbService,
    required AuthService authService,
    PresenceService? presenceService,
    Future<String?> Function()? pushTokenProvider,
  })  : _localDbService = localDbService,
        _authService = authService,
        _presenceService = presenceService,
        _pushTokenProvider = pushTokenProvider;

  String _sanitizeAgoraUid(String uid) {
    // Agora Chat usernames accept [a-zA-Z0-9_-]+. Mirrored by the server
    // (`sanitizeAgoraUid` in server/src/index.js) — keep both in sync.
    return uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
  }

  void _ensureWatchingPresence(String uid) {
    final presenceService = _presenceService;
    if (presenceService == null || uid.isEmpty) return;
    if (_presenceSubs.containsKey(uid)) return;
    final lowerKey = uid.toLowerCase();
    _presenceSubs[uid] = presenceService.watchUserPresence(uid).listen(
      (presence) {
        final prev = _presenceStates[lowerKey];
        _presenceStates[lowerKey] = presence.isOnline;
        if (prev != presence.isOnline) {
          unawaited(_syncConversationsFromLocal());
        }
      },
      onError: (_) {},
    );
  }

  bool _isThreadActive(String conversationId) {
    final key = conversationId.toLowerCase();
    final controller = _messagesControllers[key];
    return controller != null && controller.hasListener;
  }

  Future<String> _resolveCanonicalUid(String rawId) async {
    if (rawId.isEmpty) return rawId;
    final currentUid = _authService.getCurrentUserId();
    if (currentUid != null &&
        currentUid.isNotEmpty &&
        currentUid.toLowerCase() == rawId.toLowerCase()) {
      return currentUid;
    }
    try {
      final isar = await _localDbService.database;
      final profile = await isar.localProfiles
          .filter()
          .uidEqualTo(rawId, caseSensitive: false)
          .findFirst();
      if (profile != null && profile.uid.isNotEmpty) {
        return profile.uid;
      }
      final conv = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(rawId, caseSensitive: false)
          .findFirst();
      if (conv != null && conv.conversationId.isNotEmpty) {
        if (conv.conversationId != rawId.toLowerCase()) {
          return conv.conversationId;
        }
        for (final member in conv.memberIds) {
          if (member.toLowerCase() == rawId.toLowerCase() &&
              member != rawId.toLowerCase()) {
            return member;
          }
        }
      }
    } catch (_) {}
    return rawId;
  }

  // ============================================================
  // AUTH — server-minted per-user Agora Chat token
  // ============================================================

  /// Fetches `{agoraUsername, appKey, appId, token, expiresAt}` from the
  /// InkLink server. Returns null when unavailable (offline / not configured).
  Future<Map<String, dynamic>?> _fetchAgoraCredentials() async {
    final idToken = await _authService.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      developer.log('No Firebase ID token available for Agora Chat auth',
          name: 'AgoraChatService');
      return null;
    }
    try {
      final base = resolveWebSocketUrl();
      final res = await _http.post(
        Uri.parse('$base/api/agora/chat/token'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        developer.log('Agora Chat token endpoint returned ${res.statusCode}',
            name: 'AgoraChatService');
        return null;
      }
      final body = jsonDecode(res.body);
      if (body is Map && body['token'] != null && body['appKey'] != null) {
        return Map<String, dynamic>.from(body);
      }
      developer.log('Agora Chat token endpoint returned unexpected payload',
          name: 'AgoraChatService');
      return null;
    } catch (e) {
      developer.log('Agora Chat token fetch failed (local-first mode): $e',
          name: 'AgoraChatService');
      return null;
    }
  }

  Future<bool> _isSdkLoggedIn() async {
    if (!_initialized) return false;
    try {
      return await ChatClient.getInstance.isLoginBefore();
    } catch (_) {
      return false;
    }
  }

  /// Initializes ChatClient exactly once per app key. Subsequent logins reuse
  /// the existing options; an app-key change goes through `changeAppKey`.
  Future<void> _ensureInitialized(String appKey) async {
    if (_initialized) {
      if (_initAppKey != appKey) {
        try {
          await ChatClient.getInstance.changeAppKey(newAppKey: appKey);
          _initAppKey = appKey;
        } catch (e) {
          developer.log('Agora Chat changeAppKey failed: $e', name: 'AgoraChatService');
        }
      }
      return;
    }
    final options = ChatOptions.withAppKey(
      appKey,
      autoLogin: false,
      debugMode: false,
      requireAck: true,
      requireDeliveryAck: true,
    );
    await ChatClient.getInstance.init(options);
    try {
      await ChatClient.getInstance.updateRequireAckSetting(true);
      await ChatClient.getInstance.updateDeliveryAckSetting(true);
    } catch (_) {}
    await ChatClient.getInstance.startCallback();
    _registerMessageHandlers();
    _initialized = true;
    _initAppKey = appKey;
    developer.log('Agora Chat SDK initialized with app key', name: 'AgoraChatService');
  }

  bool _handlersRegistered = false;

  void _registerMessageHandlers() {
    if (_handlersRegistered) return;
    _handlersRegistered = true;

    ChatClient.getInstance.chatManager.addEventHandler(
      'inklink_chat_handler',
      ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) async {
          for (final msg in messages) {
            await _handleIncomingAgoraMessage(msg);
          }
        },
        onMessagesDelivered: (List<ChatMessage> messages) async {
          for (final msg in messages) {
            final targetId = _agoraMsgIdToLocalId[msg.msgId] ??
                msg.attributes?['localMessageId']?.toString() ??
                msg.msgId;
            final convId = msg.conversationId ?? msg.to ?? '';
            await _updateMessageStatus(targetId, ChatMessageStatus.delivered,
                conversationId: convId);
          }
        },
        onMessagesRead: (List<ChatMessage> messages) async {
          for (final msg in messages) {
            final targetId = _agoraMsgIdToLocalId[msg.msgId] ??
                msg.attributes?['localMessageId']?.toString() ??
                msg.msgId;
            final convId = msg.conversationId ?? msg.to ?? msg.from ?? '';
            await _updateMessageStatus(targetId, ChatMessageStatus.read,
                conversationId: convId);
          }
        },
        onConversationRead: (String from, String to) async {
          developer.log('Agora onConversationRead: from=$from, to=$to',
              name: 'AgoraChatService');
          final canonicalPeerId = await _resolveCanonicalUid(from);
          final currentUid = _authService.getCurrentUserId() ?? '';
          final isar = await _localDbService.database;
          await isar.writeTxn(() async {
            final sentMsgs = await isar.localChatMessages
                .filter()
                .group((q) => q
                    .conversationIdEqualTo(canonicalPeerId, caseSensitive: false)
                    .or()
                    .conversationIdEqualTo(from, caseSensitive: false))
                .and()
                .group((q) => q
                    .senderIdEqualTo(currentUid, caseSensitive: false)
                    .or()
                    .senderIdEqualTo(to, caseSensitive: false))
                .and()
                .not()
                .statusEqualTo(ChatMessageStatus.read.name)
                .findAll();

            for (final msg in sentMsgs) {
              msg.status = ChatMessageStatus.read.name;
              await isar.localChatMessages.put(msg);
            }
          });
          _notifyThreadUpdated(canonicalPeerId);
          _notifyThreadUpdated(from);
        },
        onMessagesRecalled: (List<ChatMessage> messages) async {
          for (final msg in messages) {
            final conversationId = msg.conversationId ?? msg.to ?? '';
            await _markMessageRecalledLocally(conversationId, msg.msgId);
          }
        },
        onMessagesRecalledInfo: (List<RecallMessageInfo> infos) async {
          for (final info in infos) {
            final conversationId =
                info.conversationId ?? info.recallMessage?.conversationId ?? info.recallBy;
            await _markMessageRecalledLocally(conversationId, info.recallMessageId);
          }
        },
        onMessageContentChanged:
            (ChatMessage msg, String lastModifyOperatorId, int lastModifyTime) async {
          final conversationId = msg.conversationId ?? msg.to ?? '';
          final isar = await _localDbService.database;
          String content = '';
          if (msg.body is ChatTextMessageBody) {
            content = (msg.body as ChatTextMessageBody).content;
          }
          await isar.writeTxn(() async {
            final stored = await isar.localChatMessages
                .filter()
                .messageIdEqualTo(msg.msgId)
                .findFirst();
            if (stored != null) {
              stored.content = content;
              stored.isEdited = true;
              await isar.localChatMessages.put(stored);
            }
          });
          _notifyThreadUpdated(conversationId);
        },
        onMessageReactionDidChange: (List<ChatMessageReactionEvent> events) async {
          // Server-authoritative reaction updates (may batch several messages).
          for (final event in events) {
            final isar = await _localDbService.database;
            final parsed = _reactionsFromChatReactionList(event.reactions);
            await isar.writeTxn(() async {
              final stored = await isar.localChatMessages
                  .filter()
                  .messageIdEqualTo(event.messageId)
                  .findFirst();
              if (stored != null) {
                stored.reactionsJson = jsonEncode(parsed);
                await isar.localChatMessages.put(stored);
              }
            });
            _notifyThreadUpdated(event.conversationId);
          }
          await _syncConversationsFromLocal();
        },
      ),
    );

    // Send-status callbacks (attachment uploads in particular resolve
    // asynchronously, after `sendMessage` has returned).
    ChatClient.getInstance.chatManager.addMessageEvent(
      'inklink_message_status',
      ChatMessageEvent(
        onSuccess: (String msgId, ChatMessage msg) async {
          final localId = msg.attributes?['localMessageId']?.toString() ?? msgId;
          await _updateMessageStatus(localId, ChatMessageStatus.sent);
        },
        onError: (String msgId, ChatMessage msg, ChatError error) async {
          final localId = msg.attributes?['localMessageId']?.toString() ?? msgId;
          developer.log('Message send failed: ${error.code} ${error.description}',
              name: 'AgoraChatService');
          await _updateMessageStatus(localId, ChatMessageStatus.failed);
        },
      ),
    );

    ChatClient.getInstance.addConnectionEventHandler(
      'inklink_chat_connection',
      ConnectionEventHandler(
        onConnected: () async {
          developer.log('Agora Chat connected', name: 'AgoraChatService');
          _setConnectionState(ChatConnectionState.connected);
          unawaited(_drainOfflineQueue());
        },
        onDisconnected: () {
          developer.log('Agora Chat disconnected', name: 'AgoraChatService');
          _setConnectionState(ChatConnectionState.disconnected);
        },
        onTokenWillExpire: () async {
          // Renew in-place with a fresh token from the server.
          final creds = await _fetchAgoraCredentials();
          final token = creds?['token']?.toString();
          if (token != null && token.isNotEmpty) {
            try {
              await ChatClient.getInstance.renewAgoraToken(token);
              developer.log('Agora Chat token renewed', name: 'AgoraChatService');
            } catch (e) {
              developer.log('Agora Chat token renewal failed: $e',
                  name: 'AgoraChatService');
            }
          }
        },
        onTokenDidExpire: () async {
          developer.log('Agora Chat token expired; re-login', name: 'AgoraChatService');
          final uid = _currentUserId;
          if (uid != null && uid.isNotEmpty) {
            unawaited(login(uid));
          }
        },
      ),
    );
  }

  // ============================================================
  // LOGIN / LOGOUT
  // ============================================================

  @override
  Future<void> initialize() async {
    // Lightweight by design: the Chat SDK is initialized on first successful
    // login, when the server has provided the Agora app key.
    if (_initialized) return;
    _setConnectionState(ChatConnectionState.disconnected);
  }

  @override
  Future<void> login(String userId) async {
    if (_loginInFlight) return;
    _loginInFlight = true;
    try {
      _currentUserId = userId;

      final creds = await _fetchAgoraCredentials();
      if (creds == null) {
        // Local-first mode: everything queues in Isar until Agora is reachable.
        _setConnectionState(ChatConnectionState.unavailable);
        await _syncConversationsFromLocal();
        return;
      }

      _setConnectionState(ChatConnectionState.connecting);
      try {
        await _ensureInitialized(creds['appKey'].toString());
      } catch (e, st) {
        developer.log('Agora Chat init failure: $e', name: 'AgoraChatService',
            stackTrace: st);
        _setConnectionState(ChatConnectionState.unavailable);
        await _syncConversationsFromLocal();
        return;
      }

      final agoraUsername = creds['agoraUsername']?.toString() ?? _sanitizeAgoraUid(userId);
      final token = creds['token']?.toString() ?? '';
      // Re-login only when the account actually differs; repeated logins for
      // the same user would otherwise drop the connection needlessly.
      final alreadyLoggedIn = await _isSdkLoggedIn();
      if (alreadyLoggedIn) {
        final currentLoggedIn = await ChatClient.getInstance.getCurrentUserId() ??
            ChatClient.getInstance.currentUserId;
        if (currentLoggedIn != null &&
            currentLoggedIn.isNotEmpty &&
            currentLoggedIn != agoraUsername) {
          try {
            await ChatClient.getInstance.logout(true);
          } catch (_) {}
        }
      }
      try {
        await ChatClient.getInstance.loginWithToken(agoraUsername, token);
        developer.log('Logged into Agora Chat as: $agoraUsername',
            name: 'AgoraChatService');
      } catch (e, st) {
        developer.log(
          'Failed to log into Agora Chat: $e. Operating in local-first mode.',
          name: 'AgoraChatService',
          stackTrace: st,
        );
        _setConnectionState(ChatConnectionState.unavailable);
        await _syncConversationsFromLocal();
        return;
      }

      await _bindPushTokenBestEffort();

      await _syncFromAgora();
      await _syncConversationsFromLocal();
      if (await ChatClient.getInstance.isConnected()) {
        _setConnectionState(ChatConnectionState.connected);
        unawaited(_drainOfflineQueue());
      }
    } finally {
      _loginInFlight = false;
    }
  }

  Future<void> _bindPushTokenBestEffort() async {
    try {
      final pushToken = await _pushTokenProvider?.call();
      if (pushToken == null || pushToken.isEmpty) return;
      final notifier = Platform.isAndroid ? 'FCM' : 'APNs';
      await ChatClient.getInstance.pushManager
          .bindDeviceToken(notifierName: notifier, deviceToken: pushToken);
      developer.log('Agora Chat push token bound ($notifier)', name: 'AgoraChatService');
    } catch (e) {
      developer.log('Agora Chat push binding skipped: $e', name: 'AgoraChatService');
    }
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
    for (final sub in _presenceSubs.values) {
      await sub.cancel();
    }
    _presenceSubs.clear();
    _presenceStates.clear();
    _setConnectionState(ChatConnectionState.disconnected);
    if (_initialized) {
      try {
        await ChatClient.getInstance.logout(true);
      } catch (_) {}
    }
  }

  // ============================================================
  // HISTORY SYNC — Agora server -> Isar
  // ============================================================

  Future<void> _syncFromAgora() async {
    try {
      final isLogged = await _isSdkLoggedIn();
      if (!isLogged) return;

      List<ChatConversation> agoraConvs = [];
      try {
        agoraConvs = await ChatClient.getInstance.chatManager.loadAllConversations();
      } catch (e) {
        developer.log('Agora loadAllConversations error: $e', name: 'AgoraChatService');
      }

      try {
        final serverConvs = await ChatClient.getInstance.chatManager.getConversationsFromServer();
        final existingIds = agoraConvs.map((c) => c.id).toSet();
        for (final sc in serverConvs) {
          if (!existingIds.contains(sc.id)) {
            agoraConvs.add(sc);
          }
        }
      } catch (e) {
        developer.log('Agora getConversationsFromServer notice: $e', name: 'AgoraChatService');
      }

      // Group discovery: pulls in groups this user was invited/added to on
      // any device (replaces the old Firestore chats-doc fan-out).
      await _syncJoinedGroups();

      for (final conv in agoraConvs) {
        try {
          final isGroup = conv.type == ChatConversationType.GroupChat;
          final messages = await conv.loadMessages(startMsgId: '', loadCount: 50);
          for (final msg in messages) {
            await _handleIncomingAgoraMessage(
              msg,
              triggerNotification: false,
              countUnread: false,
              isGroup: isGroup,
            );
          }
        } catch (e) {
          developer.log('Error loading messages for conv ${conv.id}: $e',
              name: 'AgoraChatService');
        }
      }
    } catch (e) {
      developer.log('Agora sync error: $e', name: 'AgoraChatService');
    }
  }

  /// Mirrors every group the current user belongs to into Isar so the inbox
  /// lists it even without messages.
  Future<void> _syncJoinedGroups() async {
    try {
      final groups = await ChatClient.getInstance.groupManager.fetchJoinedGroupsFromServer(
        needRole: true,
      );
      await _ingestGroups(groups);
    } catch (e) {
      developer.log('Agora fetchJoinedGroupsFromServer error: $e', name: 'AgoraChatService');
    }
  }

  Future<void> _ingestGroups(List<ChatGroup> groups) async {
    if (groups.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      for (final g in groups) {
        final existing = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(g.groupId, caseSensitive: false)
            .findFirst();
        final conv = existing ?? LocalChatConversation()
          ..conversationId = g.groupId;
        conv
          ..isGroup = true
          ..lastMessage = existing?.lastMessage ?? 'Group chat'
          ..lastMessageTimestamp = existing?.lastMessageTimestamp ?? DateTime.now()
          ..updatedAt = existing?.updatedAt ?? DateTime.now()
          ..unreadCount = existing?.unreadCount ?? 0
          ..isMuted = existing?.isMuted ?? false;
        if (g.groupName != null && g.groupName!.isNotEmpty) conv.name = g.groupName!;
        if (g.avatarUrl != null && g.avatarUrl!.isNotEmpty) conv.avatarUrl = g.avatarUrl;
        if (g.desc != null) conv.description = g.desc;
        final ownerId = g.owner;
        if (ownerId != null && ownerId.isNotEmpty) conv.ownerId = ownerId;
        final admins = g.adminList;
        if (admins != null) {
          conv.adminIds = [...admins];
        } else if (existing != null) {
          conv.adminIds = [...existing.adminIds];
        }
        final members = g.memberList;
        if (members != null && members.isNotEmpty) {
          conv.memberIds = members.toSet().toList();
        } else if (existing != null) {
          conv.memberIds = [...existing.memberIds];
        }
        await isar.localChatConversations.put(conv);
      }
    });
  }

  // ============================================================
  // INBOX / THREAD (Isar-backed, unchanged public behaviour)
  // ============================================================

  @override
  Stream<List<ChatConversationModel>> watchConversations() {
    if (!_initialized && !_loginInFlight) {
      final uid = _authService.getCurrentUserId();
      if (uid != null && uid.isNotEmpty) {
        unawaited(login(uid));
      }
    }
    _syncConversationsFromLocal();
    return _conversationsController.stream;
  }

  @override
  Future<List<ChatConversationModel>> getConversations() async {
    final isar = await _localDbService.database;
    final currentUid = _authService.getCurrentUserId();

    // Auto-repair/materialize incoming DM conversations for the current user
    if (currentUid != null && currentUid.isNotEmpty) {
      final incomingDmMessages = await isar.localChatMessages
          .filter()
          .conversationIdEqualTo(currentUid, caseSensitive: false)
          .and()
          .not()
          .senderIdEqualTo(currentUid, caseSensitive: false)
          .findAll();

      final senders = <String, LocalChatMessage>{};
      for (final m in incomingDmMessages) {
        final key = m.senderId.toLowerCase();
        if (!senders.containsKey(key) ||
            m.timestamp.isAfter(senders[key]!.timestamp)) {
          senders[key] = m;
        }
      }

      for (final entry in senders.entries) {
        final latestMsg = entry.value;
        final senderUid = await _resolveCanonicalUid(latestMsg.senderId);
        final existingPartnerConv = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(senderUid, caseSensitive: false)
            .findFirst();

        if (existingPartnerConv == null) {
          final conv = LocalChatConversation()
            ..conversationId = senderUid
            ..name = latestMsg.senderName.isNotEmpty ? latestMsg.senderName : 'User'
            ..avatarUrl = latestMsg.senderAvatar
            ..isGroup = false
            ..lastMessage = latestMsg.type == 'text' ? latestMsg.content : '[${latestMsg.type}]'
            ..lastMessageTimestamp = latestMsg.timestamp
            ..unreadCount = 1
            ..memberIds = [currentUid, senderUid]
            ..updatedAt = latestMsg.timestamp;

          await isar.writeTxn(() async {
            await isar.localChatConversations.put(conv);
          });
        }
      }
    }

    final locals = await isar.localChatConversations
        .where()
        .sortByUpdatedAtDesc()
        .findAll();

    final results = <ChatConversationModel>[];
    final seenConvKeys = <String>{};
    for (final c in locals) {
      // Don't show DM with self or conversations the current user is not a participant of
      if (currentUid != null && currentUid.isNotEmpty) {
        final lowerCurrent = currentUid.toLowerCase();
        if (!c.isGroup) {
          if (c.conversationId.toLowerCase() == lowerCurrent) continue;
          if (c.memberIds.isNotEmpty &&
              !c.memberIds.any((m) => m.toLowerCase() == lowerCurrent)) {
            continue;
          }
        } else {
          if (c.memberIds.isNotEmpty &&
              !c.memberIds.any((m) => m.toLowerCase() == lowerCurrent)) {
            continue;
          }
        }
      }

      final dedupKey = c.isGroup ? c.conversationId : c.conversationId.toLowerCase();
      if (!seenConvKeys.add(dedupKey)) continue;

      String canonicalId = c.conversationId;
      String resolvedName = c.name;
      String? resolvedAvatar = c.avatarUrl;

      // Resolve canonical UID and profile display fields for DMs
      if (!c.isGroup) {
        final profile = await isar.localProfiles
            .filter()
            .uidEqualTo(c.conversationId, caseSensitive: false)
            .findFirst();
        if (profile != null) {
          if (profile.uid.isNotEmpty) {
            canonicalId = profile.uid;
          }
          if ((resolvedName.isEmpty ||
                  resolvedName == 'User' ||
                  resolvedName.toLowerCase() == c.conversationId.toLowerCase()) &&
              profile.displayName.isNotEmpty) {
            resolvedName = profile.displayName;
          }
          if ((resolvedAvatar == null || resolvedAvatar.isEmpty) &&
              profile.photoURL != null &&
              profile.photoURL!.isNotEmpty) {
            resolvedAvatar = profile.photoURL;
          }
        } else if (resolvedName.isEmpty ||
            resolvedName == 'User' ||
            resolvedName.toLowerCase() == c.conversationId.toLowerCase() ||
            resolvedAvatar == null ||
            resolvedAvatar.isEmpty) {
          final partnerMsg = await isar.localChatMessages
              .filter()
              .senderIdEqualTo(c.conversationId, caseSensitive: false)
              .findFirst();
          if (partnerMsg != null && partnerMsg.senderName.isNotEmpty) {
            resolvedName = partnerMsg.senderName;
            resolvedAvatar ??= partnerMsg.senderAvatar;
          }
        }

        _ensureWatchingPresence(canonicalId);
      }

      final isOnline =
          !c.isGroup && (_presenceStates[canonicalId.toLowerCase()] ?? false);

      results.add(
        ChatConversationModel(
          id: canonicalId,
          name: resolvedName.isNotEmpty ? resolvedName : (c.isGroup ? 'Group Chat' : 'User'),
          avatarUrl: resolvedAvatar,
          isGroup: c.isGroup,
          lastMessage: c.lastMessage,
          lastMessageTimestamp: c.lastMessageTimestamp,
          unreadCount: c.unreadCount,
          isOnline: isOnline,
          isMuted: c.isMuted,
          memberIds: List.from(c.memberIds),
          adminIds: List.from(c.adminIds),
          ownerId: c.ownerId,
          description: c.description,
        ),
      );
    }

    return results;
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final convs = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId, caseSensitive: false)
          .findAll();
      for (final conv in convs) {
        conv.unreadCount = 0;
        await isar.localChatConversations.put(conv);
      }
    });

    var isLogged = await _isSdkLoggedIn();
    if (!isLogged) {
      final uid = _authService.getCurrentUserId();
      if (uid != null && uid.isNotEmpty) {
        await login(uid);
        isLogged = await _isSdkLoggedIn();
      }
    }

    if (isLogged) {
      try {
        final convType = await _agoraConversationType(conversationId);
        final agoraId = convType == ChatConversationType.GroupChat
            ? conversationId
            : _sanitizeAgoraUid(conversationId);
        final agoraConv = await ChatClient.getInstance.chatManager
            .getConversation(agoraId, type: convType);
        await agoraConv?.markAllMessagesAsRead();
        if (convType != ChatConversationType.GroupChat) {
          await ChatClient.getInstance.chatManager.sendConversationReadAck(agoraId);
          if (agoraConv != null) {
            final unreadList = await agoraConv.loadMessages(startMsgId: '', loadCount: 20);
            for (final m in unreadList) {
              if (m.direction == MessageDirection.RECEIVE && !m.hasReadAck) {
                try {
                  await ChatClient.getInstance.chatManager.sendMessageReadAck(m);
                } catch (_) {}
              }
            }
          }
        }
      } catch (e) {
        developer.log('Agora sendConversationReadAck error: $e', name: 'AgoraChatService');
      }
    }

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId, caseSensitive: false)
          .deleteAll();
      await isar.localChatMessages
          .filter()
          .conversationIdEqualTo(conversationId, caseSensitive: false)
          .deleteAll();
    });

    if (_initialized) {
      try {
        final isGroup = await _isGroupConversation(conversationId);
        final agoraId = isGroup ? conversationId : _sanitizeAgoraUid(conversationId);
        await ChatClient.getInstance.chatManager
            .deleteConversation(agoraId, deleteMessages: true);
      } catch (_) {}
    }

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> toggleMuteConversation(String conversationId) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final conv = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId, caseSensitive: false)
          .findFirst();
      if (conv != null) {
        conv.isMuted = !conv.isMuted;
        await isar.localChatConversations.put(conv);
      }
    });
    await _syncConversationsFromLocal();
  }

  @override
  Stream<List<ChatMessageModel>> watchMessages(String conversationId) {
    final key = conversationId.toLowerCase();
    _canonicalThreadIds[key] = conversationId;
    if (!_messagesControllers.containsKey(key)) {
      _messagesControllers[key] =
          StreamController<List<ChatMessageModel>>.broadcast();
    }
    _notifyThreadUpdated(conversationId);
    return _messagesControllers[key]!.stream;
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    final isar = await _localDbService.database;
    final currentUid = _authService.getCurrentUserId() ?? '';
    if (!_initialized && !_loginInFlight && currentUid.isNotEmpty) {
      unawaited(login(currentUid));
    }

    // Fetch all messages for this thread:
    // Either stored directly under conversationId,
    // or sent between conversationId and currentUid (counterpart DM)
    var locals = await isar.localChatMessages
        .filter()
        .conversationIdEqualTo(conversationId, caseSensitive: false)
        .or()
        .group((q) => q
            .conversationIdEqualTo(currentUid, caseSensitive: false)
            .and()
            .senderIdEqualTo(conversationId, caseSensitive: false))
        .sortByTimestamp()
        .findAll();

    // If local Isar has no messages, lazily fetch from Agora Chat SDK
    if (locals.isEmpty && _initialized) {
      try {
        final convType = await _agoraConversationType(conversationId);
        final agoraId = convType == ChatConversationType.GroupChat
            ? conversationId
            : _sanitizeAgoraUid(conversationId);
        final conv = await ChatClient.getInstance.chatManager
            .getConversation(agoraId, type: convType);
        if (conv != null) {
          final msgs = await conv.loadMessages(startMsgId: '', loadCount: 50);
          for (final msg in msgs) {
            await _handleIncomingAgoraMessage(
              msg,
              triggerNotification: false,
              countUnread: false,
              isGroup: convType == ChatConversationType.GroupChat,
            );
          }
          locals = await isar.localChatMessages
              .filter()
              .conversationIdEqualTo(conversationId, caseSensitive: false)
              .or()
              .group((q) => q
                  .conversationIdEqualTo(currentUid, caseSensitive: false)
                  .and()
                  .senderIdEqualTo(conversationId, caseSensitive: false))
              .sortByTimestamp()
              .findAll();
        }
      } catch (e) {
        developer.log('Notice loading messages on demand from Agora: $e',
            name: 'AgoraChatService');
      }
    }

    // Catch up any read acks recorded on the Agora server while offline or inactive
    if (_initialized &&
        locals.any((m) =>
            m.senderId.toLowerCase() == currentUid.toLowerCase() &&
            m.status != ChatMessageStatus.read.name)) {
      try {
        final convType = await _agoraConversationType(conversationId);
        final agoraId = convType == ChatConversationType.GroupChat
            ? conversationId
            : _sanitizeAgoraUid(conversationId);
        final conv = await ChatClient.getInstance.chatManager
            .getConversation(agoraId, type: convType);
        if (conv != null) {
          final msgs = await conv.loadMessages(startMsgId: '', loadCount: 50);
          bool hasUpdatedRead = false;
          for (final msg in msgs) {
            if (msg.hasReadAck) {
              final targetId = _agoraMsgIdToLocalId[msg.msgId] ??
                  msg.attributes?['localMessageId']?.toString() ??
                  msg.msgId;
              final match = locals.cast<LocalChatMessage?>().firstWhere(
                    (m) =>
                        m != null &&
                        (m.messageId == targetId || m.messageId == msg.msgId),
                    orElse: () => null,
                  );
              if (match != null && match.status != ChatMessageStatus.read.name) {
                match.status = ChatMessageStatus.read.name;
                await isar.writeTxn(() async {
                  await isar.localChatMessages.put(match);
                });
                hasUpdatedRead = true;
              }
            }
          }
          if (hasUpdatedRead) {
            locals = await isar.localChatMessages
                .filter()
                .conversationIdEqualTo(conversationId, caseSensitive: false)
                .or()
                .group((q) => q
                    .conversationIdEqualTo(currentUid, caseSensitive: false)
                    .and()
                    .senderIdEqualTo(conversationId, caseSensitive: false))
                .sortByTimestamp()
                .findAll();
          }
        }
      } catch (_) {}
    }

    return locals.map((m) {
      Map<String, List<String>> parsedReactions = {};
      if (m.reactionsJson != null && m.reactionsJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(m.reactionsJson!);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (v is List) {
                parsedReactions[k.toString()] = v.map((e) => e.toString()).toList();
              }
            });
          }
        } catch (_) {}
      }

      ChatSharePayload? sharePayload;
      if (m.sharePayloadJson != null && m.sharePayloadJson!.isNotEmpty) {
        try {
          sharePayload = ChatSharePayload.fromJsonString(m.sharePayloadJson!);
        } catch (_) {}
      }

      return ChatMessageModel(
        id: m.messageId,
        conversationId: m.conversationId,
        senderId: m.senderId,
        senderName: m.senderName,
        senderAvatar: m.senderAvatar,
        type: ChatMessageType.fromString(m.type),
        content: m.content,
        timestamp: m.timestamp,
        status: ChatMessageStatus.fromString(m.status),
        reactions: parsedReactions,
        isEdited: m.isEdited,
        isDeleted: m.isDeleted,
        fileName: m.fileName,
        fileSize: m.fileSize,
        sharePayload: sharePayload,
        replyToId: m.replyToId,
        replyToSender: m.replyToSender,
        replyToText: m.replyToText,
      );
    }).toList();
  }

  // ============================================================
  // INCOMING MESSAGE HANDLER
  // ============================================================

  Future<void> _handleIncomingAgoraMessage(
    ChatMessage msg, {
    bool triggerNotification = true,
    bool countUnread = true,
    bool isGroup = false,
  }) async {
    try {
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

      // Group membership is authoritative from the wire, but keep the
      // parameter when the caller already knows the type (history sync).
      isGroup = isGroup || msg.chatType == ChatType.GroupChat;

      final currentUid = _authService.getCurrentUserId();
      final attrSenderUid = msg.attributes?['senderUid']?.toString() ?? '';
      final rawSenderId = attrSenderUid.isNotEmpty ? attrSenderUid : (msg.from ?? '');
      final senderId = await _resolveCanonicalUid(rawSenderId);

      String conversationId;
      if (isGroup) {
        conversationId = msg.conversationId ?? msg.to ?? '';
      } else {
        final isFromSelf = currentUid != null &&
            currentUid.isNotEmpty &&
            senderId.toLowerCase() == currentUid.toLowerCase();
        if (isFromSelf) {
          final attrTargetUid = msg.attributes?['targetUid']?.toString() ?? '';
          final rawTarget = attrTargetUid.isNotEmpty
              ? attrTargetUid
              : (msg.to ?? msg.conversationId ?? '');
          conversationId = await _resolveCanonicalUid(rawTarget);
        } else {
          conversationId = senderId;
        }
      }
      if (conversationId.isEmpty) return;

      // Server-authoritative reactions carried on the message itself.
      final reactions = await _reactionsFromMessage(msg);

      // Echoes of our own sends (multi-device sync) carry the local id used
      // at send time; map back so the original Isar row is updated instead
      // of a second row being created under the server id.
      final localMessageId = msg.attributes?['localMessageId']?.toString();
      final isSelfSender = currentUid != null &&
          currentUid.isNotEmpty &&
          senderId.toLowerCase() == currentUid.toLowerCase();
      final messageId =
          (!isSelfSender || localMessageId == null)
              ? msg.msgId
              : (localMessageId.isNotEmpty ? localMessageId : msg.msgId);
      final isOwnEcho = isSelfSender && localMessageId != null;

      ChatSharePayload? sharePayload;
      if (msgType == ChatMessageType.boardShare ||
          msgType == ChatMessageType.workspaceShare) {
        try {
          sharePayload = ChatSharePayload.fromJsonString(textContent);
        } catch (_) {}
      }

      // If receiver is currently viewing this conversation, send read receipts immediately
      final active = !isGroup && _isThreadActive(conversationId);
      if (active) {
        try {
          final agoraPeerId = _sanitizeAgoraUid(conversationId);
          await ChatClient.getInstance.chatManager.sendConversationReadAck(agoraPeerId);
          await ChatClient.getInstance.chatManager.sendMessageReadAck(msg);
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
        isGroup: isGroup,
        countUnread: countUnread && !active,
      );

      // Dispatch local foreground notification if receiver is not sender and chat is not muted
      if (triggerNotification && senderId.isNotEmpty && !active) {
        if (!isSelfSender &&
            DateTime.now().difference(model.timestamp).inMinutes.abs() < 2) {
          final isar = await _localDbService.database;
          final conv = await isar.localChatConversations
              .filter()
              .conversationIdEqualTo(conversationId, caseSensitive: false)
              .findFirst();
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
                'senderName': isGroup ? (conv?.name ?? 'Group') : model.senderName,
                'isGroup': isGroup.toString(),
              },
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error handling incoming Agora message: $e', name: 'AgoraChatService');
    }
  }

  /// Maps the reactions carried on a received `ChatMessage` into the Isar
  /// shape `{emoji: [userIds]}`. Offline-safe: no extra network call.
  ///
  /// Note: the wire only reports up to three users per reaction
  /// (`ChatMessageReaction.userList`); the reaction sheet may therefore show
  /// fewer names than `userCount`. Counts remain correct because agggregation
  /// on the server keeps `userCount` authoritative for display purposes.
  /// Maps the reactions of a received `ChatMessage` into the Isar shape
  /// `{emoji: [userIds]}`. `reactionList()` is a per-message native lookup;
  /// failures degrade to "no reactions" rather than blocking ingestion.
  Future<Map<String, List<String>>> _reactionsFromMessage(ChatMessage msg) async {
    try {
      return _reactionsFromChatReactionList(await msg.reactionList());
    } catch (_) {
      return {};
    }
  }

  Map<String, List<String>> _reactionsFromChatReactionList(
    List<ChatMessageReaction>? reactList,
  ) {
    final parsed = <String, List<String>>{};
    if (reactList == null) return parsed;
    for (final r in reactList) {
      if (r.userCount <= 0) continue;
      // userList is non-nullable per the SDK model; count stays authoritative.
      final users = r.userList.toList();
      if (users.isEmpty) {
        // The wire omits user ids in rare cases (only the count is known).
        // Pad with a stable placeholder so the bubble count matches the
        // authoritative server count.
        parsed[r.reaction] = List.filled(r.userCount, 'unknown-user');
      } else {
        parsed[r.reaction] = users;
      }
    }
    return parsed;
  }

  Future<bool> _isGroupConversation(String conversationId) async {
    final isar = await _localDbService.database;
    final conv = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(conversationId, caseSensitive: false)
        .findFirst();
    return conv?.isGroup ?? conversationId.startsWith('group_');
  }

  Future<ChatConversationType> _agoraConversationType(String conversationId) async {
    return (await _isGroupConversation(conversationId))
        ? ChatConversationType.GroupChat
        : ChatConversationType.Chat;
  }

  // ============================================================
  // LOCAL PERSISTENCE (Isar)
  // ============================================================

  Future<void> _persistMessageLocally(
    ChatMessageModel model, {
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
    bool countUnread = true,
  }) async {
    final isar = await _localDbService.database;

    await isar.writeTxn(() async {
      // 1. Save or update message
      final existingMsg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(model.id)
          .findFirst();

      final localMsg = existingMsg ?? LocalChatMessage();
      localMsg.messageId = model.id;
      localMsg.conversationId = model.conversationId;
      localMsg.senderId = model.senderId;
      localMsg.senderName = model.senderName;
      localMsg.senderAvatar = model.senderAvatar;
      localMsg.type = model.type.asString;
      localMsg.content = model.content;
      localMsg.timestamp = model.timestamp;
      localMsg.status = model.status.name;
      localMsg.reactionsJson = jsonEncode(model.reactions);
      localMsg.isEdited = model.isEdited;
      localMsg.isDeleted = model.isDeleted;
      localMsg.fileName = model.fileName;
      localMsg.fileSize = model.fileSize;
      localMsg.sharePayloadJson = model.sharePayload?.toJsonString();
      localMsg.replyToId = model.replyToId;
      localMsg.replyToSender = model.replyToSender;
      localMsg.replyToText = model.replyToText;

      await isar.localChatMessages.put(localMsg);

      // 2. Update conversation snippet
      final existingConv = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(model.conversationId, caseSensitive: false)
          .findFirst();

      final conv = existingConv ?? LocalChatConversation();
      if (conv.conversationId.isEmpty ||
          model.conversationId != model.conversationId.toLowerCase()) {
        conv.conversationId = model.conversationId;
      }
      if (conversationName != null && conversationName.isNotEmpty) {
        conv.name = conversationName;
      } else if (conv.name.isEmpty) {
        conv.name = isGroup ? 'Group Chat' : model.senderName;
      }
      if (conversationAvatar != null && conversationAvatar.isNotEmpty) {
        conv.avatarUrl = conversationAvatar;
      }
      conv.isGroup = isGroup || conv.isGroup;
      conv.lastMessage = model.type == ChatMessageType.text
          ? model.content
          : '[${model.type.name}]';
      conv.lastMessageTimestamp = model.timestamp;
      conv.updatedAt = DateTime.now();

      final currentUid = _authService.getCurrentUserId();
      final isFromSelf = currentUid != null &&
          currentUid.isNotEmpty &&
          model.senderId.toLowerCase() == currentUid.toLowerCase();
      if (countUnread && !isFromSelf) {
        conv.unreadCount = conv.unreadCount + 1;
      }

      // Track participants for DMs so we know which user owns this conversation
      if (!conv.isGroup) {
        final members = Set<String>.from(conv.memberIds);
        if (currentUid != null && currentUid.isNotEmpty) members.add(currentUid);
        if (model.conversationId.isNotEmpty) members.add(model.conversationId);
        if (model.senderId.isNotEmpty) members.add(model.senderId);
        conv.memberIds = members.toList();
      }

      await isar.localChatConversations.put(conv);
    });

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(model.conversationId);
    if (!isGroup && model.senderId.isNotEmpty) {
      _notifyThreadUpdated(model.senderId);
    }
  }

  void _notifyThreadUpdated(String conversationId) async {
    final key = conversationId.toLowerCase();
    final controller = _messagesControllers[key];
    if (controller != null && !controller.isClosed) {
      final canonicalId = _canonicalThreadIds[key] ?? conversationId;
      final messages = await getMessages(canonicalId);
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
    String? conversationId,
  }) async {
    final isar = await _localDbService.database;
    final resolvedId = _agoraMsgIdToLocalId[messageId] ?? messageId;
    String? targetConvId = conversationId;
    await isar.writeTxn(() async {
      var msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(resolvedId)
          .findFirst();
      if (msg == null && resolvedId != messageId) {
        msg = await isar.localChatMessages
            .filter()
            .messageIdEqualTo(messageId)
            .findFirst();
      }
      if (msg != null) {
        msg.status = status.name;
        targetConvId ??= msg.conversationId;
        await isar.localChatMessages.put(msg);
      } else if (status == ChatMessageStatus.read &&
          targetConvId != null &&
          targetConvId!.isNotEmpty) {
        final currentUid = _authService.getCurrentUserId() ?? '';
        final unreadMsgs = await isar.localChatMessages
            .filter()
            .conversationIdEqualTo(targetConvId!, caseSensitive: false)
            .and()
            .senderIdEqualTo(currentUid, caseSensitive: false)
            .and()
            .not()
            .statusEqualTo(ChatMessageStatus.read.name)
            .findAll();
        for (final m in unreadMsgs) {
          m.status = ChatMessageStatus.read.name;
          await isar.localChatMessages.put(m);
        }
      }
    });

    if (targetConvId != null && targetConvId!.isNotEmpty) {
      _notifyThreadUpdated(targetConvId!);
    }
  }

  Future<void> _markMessageRecalledLocally(
    String conversationId,
    String messageId,
  ) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        msg.isDeleted = true;
        msg.content = 'This message was deleted';
        await isar.localChatMessages.put(msg);
      }
      // A recall may arrive before we ever stored the message (fresh room);
      // nothing to do in that case — the text message event will still apply
      // its own state and the deleted marker only matters for stored rows.
    });
    _notifyThreadUpdated(conversationId);
  }

  /// Rebuilds an Agora `ChatMessage` from a locally stored row so queued
  /// (`sending`/`failed`) messages can be replayed after reconnect.
  ChatMessage? _rebuildAgoraMessage(LocalChatMessage local, String targetId, bool isGroup) {
    final type = ChatMessageType.fromString(local.type);
    final chatType = isGroup ? ChatType.GroupChat : ChatType.Chat;
    final attributes = <String, dynamic>{
      'senderUid': local.senderId,
      'targetUid': local.conversationId,
      'senderName': local.senderName,
      'senderAvatar': local.senderAvatar ?? '',
      'localMessageId': local.messageId,
      if (local.replyToId != null) 'replyToId': local.replyToId,
      if (local.replyToSender != null) 'replyToSender': local.replyToSender,
      if (local.replyToText != null) 'replyToText': local.replyToText,
    };
    try {
      final ChatMessage msg;
      switch (type) {
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
            event: type == ChatMessageType.boardShare ? 'board_share' : 'workspace_share',
            params: {'payload': local.content},
            chatType: chatType,
          );
          break;
      }
      msg.attributes = attributes;
      return msg;
    } catch (e) {
      developer.log('Failed to rebuild message for retry: $e', name: 'AgoraChatService');
      return null;
    }
  }

  /// Sends queued (`sending`) and failed messages when the connection returns.
  /// A message that fails permanently stays marked `failed` so the UI can
  /// offer a manual retry.
  Future<void> _drainOfflineQueue() async {
    try {
      if (!await _isSdkLoggedIn()) return;
      if (!await ChatClient.getInstance.isConnected()) return;

      final isar = await _localDbService.database;
      final currentUid = _authService.getCurrentUserId();
      if (currentUid == null || currentUid.isEmpty) return;

      final queued = await isar.localChatMessages
          .filter()
          .senderIdEqualTo(currentUid, caseSensitive: false)
          .group((q) => q
              .statusEqualTo(ChatMessageStatus.sending.name)
              .or()
              .statusEqualTo(ChatMessageStatus.failed.name))
          .findAll();

      for (final local in queued) {
        final isGroup = await _isGroupConversation(local.conversationId);
        final targetId = isGroup
            ? local.conversationId
            : _sanitizeAgoraUid(local.conversationId);
        final msg = _rebuildAgoraMessage(local, targetId, isGroup);
        if (msg == null) continue;
        try {
          final sent = await ChatClient.getInstance.chatManager.sendMessage(msg);
          if (sent.msgId.isNotEmpty) {
            _agoraMsgIdToLocalId[sent.msgId] = local.messageId;
          }
          await _updateMessageStatus(local.messageId, ChatMessageStatus.sent,
              conversationId: local.conversationId);
        } catch (e) {
          developer.log('Queued message retry failed: $e', name: 'AgoraChatService');
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
    required bool isGroup,
  }) async {
    var isLogged = await _isSdkLoggedIn();
    if (!isLogged) {
      final uid = _authService.getCurrentUserId();
      if (uid != null && uid.isNotEmpty) {
        await login(uid);
        isLogged = await _isSdkLoggedIn();
      }
    }
    if (!isLogged) {
      await _updateMessageStatus(model.id, ChatMessageStatus.failed,
          conversationId: model.conversationId);
      return model.copyWith(status: ChatMessageStatus.failed);
    }
    try {
      final sent = await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
      if (sent.msgId.isNotEmpty) {
        _agoraMsgIdToLocalId[sent.msgId] = model.id;
      }
      // `sendMessage` returns once the native SDK accepts the message into its
      // send pipeline (status is typically PROGRESS/CREATE until the async
      // ChatMessageEvent.onSuccess/onError callback fires). Treat any non-FAIL
      // status as accepted (`sent`), and let ChatMessageEvent.onError mark
      // `failed` if the server rejects it.
      final accepted = sent.status != MessageStatus.FAIL;
      await _updateMessageStatus(
        model.id,
        accepted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        conversationId: model.conversationId,
      );
      return model.copyWith(
        status: accepted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
      );
    } catch (e, st) {
      developer.log('Agora send failure: $e', name: 'AgoraChatService', stackTrace: st);
      await _updateMessageStatus(model.id, ChatMessageStatus.failed,
          conversationId: model.conversationId);
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
    final currentUid = currentUser?.uid ?? 'unknown';
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
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
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

    return _send(agoraMsg: agoraMsg, model: model, isGroup: isGroup);
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
    final currentUid = currentUser?.uid ?? 'unknown';
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
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
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

    return _send(agoraMsg: agoraMsg, model: model, isGroup: isGroup);
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
    final currentUid = currentUser?.uid ?? 'unknown';
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
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
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

    return _send(agoraMsg: agoraMsg, model: model, isGroup: isGroup);
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
    final currentUid = currentUser?.uid ?? 'unknown';
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
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
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

    return _send(agoraMsg: agoraMsg, model: model, isGroup: isGroup);
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
    final currentUid = currentUser?.uid ?? 'unknown';
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
      type: isBoard ? ChatMessageType.boardShare : ChatMessageType.workspaceShare,
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
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
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

    return _send(agoraMsg: agoraMsg, model: model, isGroup: isGroup);
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
    final isLoggedIn = await _isSdkLoggedIn();
    if (isLoggedIn) {
      try {
        await ChatClient.getInstance.chatManager.addReaction(
          messageId: messageId,
          reaction: emoji,
        );
      } catch (e) {
        developer.log('Agora addReaction failed: $e', name: 'AgoraChatService');
      }
    }

    final currentUid = _authService.getCurrentUserId() ?? 'me';
    final isar = await _localDbService.database;

    LocalChatMessage? targetMsg;
    Map<String, List<String>> reactions = {};
    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        targetMsg = msg;
        if (msg.reactionsJson != null && msg.reactionsJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.reactionsJson!);
            if (decoded is Map) {
              decoded.forEach((k, v) {
                if (v is List) {
                  reactions[k.toString()] = v.map((e) => e.toString()).toList();
                }
              });
            }
          } catch (_) {}
        }

        // Ensure single reaction per user: replace previous reaction
        reactions.forEach((k, v) {
          v.remove(currentUid);
        });
        reactions.removeWhere((k, v) => v.isEmpty);

        final users = reactions[emoji] ?? [];
        if (!users.contains(currentUid)) {
          users.add(currentUid);
          reactions[emoji] = users;
        }

        msg.reactionsJson = jsonEncode(reactions);
        await isar.localChatMessages.put(msg);
      }
    });

    _notifyThreadUpdated(conversationId);
    if (targetMsg != null) {
      if (targetMsg!.conversationId.isNotEmpty && targetMsg!.conversationId != conversationId) {
        _notifyThreadUpdated(targetMsg!.conversationId);
      }
      if (targetMsg!.senderId.isNotEmpty && targetMsg!.senderId != conversationId) {
        _notifyThreadUpdated(targetMsg!.senderId);
      }
    }
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final isLoggedIn = await _isSdkLoggedIn();
    if (isLoggedIn) {
      try {
        await ChatClient.getInstance.chatManager.removeReaction(
          messageId: messageId,
          reaction: emoji,
        );
      } catch (e) {
        developer.log('Agora removeReaction failed: $e', name: 'AgoraChatService');
      }
    }

    final currentUid = _authService.getCurrentUserId() ?? 'me';
    final isar = await _localDbService.database;

    LocalChatMessage? targetMsg;
    Map<String, List<String>> reactions = {};
    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        targetMsg = msg;
        if (msg.reactionsJson != null && msg.reactionsJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.reactionsJson!);
            if (decoded is Map) {
              decoded.forEach((k, v) {
                if (v is List) {
                  reactions[k.toString()] = v.map((e) => e.toString()).toList();
                }
              });
            }
          } catch (_) {}
        }

        final users = reactions[emoji];
        if (users != null) {
          users.remove(currentUid);
          if (users.isEmpty) {
            reactions.remove(emoji);
          } else {
            reactions[emoji] = users;
          }
        }

        msg.reactionsJson = jsonEncode(reactions);
        await isar.localChatMessages.put(msg);
      }
    });

    _notifyThreadUpdated(conversationId);
    if (targetMsg != null) {
      if (targetMsg!.conversationId.isNotEmpty && targetMsg!.conversationId != conversationId) {
        _notifyThreadUpdated(targetMsg!.conversationId);
      }
      if (targetMsg!.senderId.isNotEmpty && targetMsg!.senderId != conversationId) {
        _notifyThreadUpdated(targetMsg!.senderId);
      }
    }
  }

  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    if (_initialized) {
      try {
        await ChatClient.getInstance.chatManager.modifyMessage(
          messageId: messageId,
          msgBody: ChatTextMessageBody(content: newContent),
        );
      } catch (e) {
        developer.log('Agora modifyMessage failed: $e', name: 'AgoraChatService');
      }
    }

    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        msg.content = newContent;
        msg.isEdited = true;
        await isar.localChatMessages.put(msg);
      }
    });

    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    // Server-side recall propagates the deletion to every member via
    // onMessagesRecalled / onMessagesRecalledInfo. Local-only deletion is the
    // fallback when the sender no longer controls the message.
    if (_initialized) {
      try {
        await ChatClient.getInstance.chatManager.recallMessage(messageId);
      } catch (e) {
        developer.log('Agora recallMessage fallback (local delete): $e',
            name: 'AgoraChatService');
        try {
          final convType = await _agoraConversationType(conversationId);
          final conv = await ChatClient.getInstance.chatManager
              .getConversation(conversationId, type: convType);
          if (conv != null) {
            await conv.deleteMessage(messageId);
          }
        } catch (_) {}
      }
    }

    await _markMessageRecalledLocally(conversationId, messageId);
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
    if (_initialized) {
      try {
        final options = ChatGroupOptions(
          style: ChatGroupStyle.PublicJoinNeedApproval,
          maxCount: 200,
        );
        final group = await ChatClient.getInstance.groupManager.createGroup(
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
        developer.log('Agora createGroup failed (offline fallback id): $e',
            name: 'AgoraChatService');
      }
    }

    final groupId = agoraGroupId ?? 'group_${const Uuid().v4().substring(0, 8)}';
    final allMembers = {...memberIds, currentUid}.toList();

    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final groupConv = LocalChatConversation()
        ..conversationId = groupId
        ..name = name
        ..description = description
        ..avatarUrl = iconUrl
        ..isGroup = true
        ..ownerId = currentUid
        ..adminIds = [currentUid]
        ..memberIds = allMembers
        ..unreadCount = 0
        ..isMuted = false
        ..lastMessage = 'Group created'
        ..lastMessageTimestamp = DateTime.now()
        ..updatedAt = DateTime.now();

      await isar.localChatConversations.put(groupConv);
    });

    await _syncConversationsFromLocal();

    return ChatConversationModel(
      id: groupId,
      name: name,
      description: description,
      avatarUrl: iconUrl,
      isGroup: true,
      ownerId: currentUid,
      adminIds: [currentUid],
      memberIds: allMembers,
      lastMessage: 'Group created',
      lastMessageTimestamp: DateTime.now(),
    );
  }

  @override
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && !group.adminIds.contains(currentUid) && group.ownerId != currentUid) {
      throw StateError('Only a group owner or admin can update group info.');
    }

    if (_initialized) {
      try {
        if (name != null && name.isNotEmpty) {
          await ChatClient.getInstance.groupManager.updateGroupName(groupId, name);
        }
        if (description != null) {
          await ChatClient.getInstance.groupManager.updateGroupDesc(groupId, description);
        }
        if (iconUrl != null && iconUrl.isNotEmpty) {
          await ChatClient.getInstance.groupManager.updateGroupAvatar(
            groupId: groupId,
            avatarUrl: iconUrl,
          );
        }
      } catch (e) {
        developer.log('Agora group update failed: $e', name: 'AgoraChatService');
      }
    }

    await isar.writeTxn(() async {
      final target = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (target != null) {
        if (name != null && name.isNotEmpty) target.name = name;
        if (description != null) target.description = description;
        if (iconUrl != null) target.avatarUrl = iconUrl;
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && !group.adminIds.contains(currentUid) && group.ownerId != currentUid) {
      throw StateError('Only a group owner or admin can add members.');
    }

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.addMembers(
          groupId,
          memberIds.map(_sanitizeAgoraUid).toList(),
        );
      } catch (e) {
        developer.log('Agora addMembers failed: $e', name: 'AgoraChatService');
      }
    }

    await isar.writeTxn(() async {
      final target = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (target != null) {
        final currentMembers = Set<String>.from(target.memberIds);
        currentMembers.addAll(memberIds);
        target.memberIds = currentMembers.toList();
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && !group.adminIds.contains(currentUid) && group.ownerId != currentUid) {
      throw StateError('Only a group owner or admin can remove members.');
    }

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.removeMembers(
          groupId,
          [_sanitizeAgoraUid(memberId)],
        );
      } catch (e) {
        developer.log('Agora removeMembers failed: $e', name: 'AgoraChatService');
      }
    }

    await isar.writeTxn(() async {
      final target = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (target != null) {
        final currentMembers = List<String>.from(target.memberIds);
        currentMembers.remove(memberId);
        final currentAdmins = List<String>.from(target.adminIds);
        currentAdmins.remove(memberId);
        target.memberIds = currentMembers;
        target.adminIds = currentAdmins;
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> promoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && group.ownerId != currentUid) {
      throw StateError('Only the group owner can promote admins.');
    }

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.addAdmin(
          groupId,
          _sanitizeAgoraUid(memberId),
        );
      } catch (e) {
        developer.log('Agora addAdmin failed: $e', name: 'AgoraChatService');
      }
    }

    await isar.writeTxn(() async {
      final target = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (target != null) {
        final currentAdmins = Set<String>.from(target.adminIds);
        currentAdmins.add(memberId);
        target.adminIds = currentAdmins.toList();
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> demoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && group.ownerId != currentUid) {
      throw StateError('Only the group owner can demote admins.');
    }

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.removeAdmin(
          groupId,
          _sanitizeAgoraUid(memberId),
        );
      } catch (e) {
        developer.log('Agora removeAdmin failed: $e', name: 'AgoraChatService');
      }
    }

    await isar.writeTxn(() async {
      final target = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (target != null) {
        final currentAdmins = List<String>.from(target.adminIds);
        currentAdmins.remove(memberId);
        target.adminIds = currentAdmins;
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> transferGroupOwner({
    required String groupId,
    required String newOwnerId,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && group.ownerId != currentUid) {
      throw StateError('Only the group owner can transfer ownership.');
    }

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.changeOwner(
          groupId,
          _sanitizeAgoraUid(newOwnerId),
        );
      } catch (e) {
        developer.log('Agora changeOwner failed: $e', name: 'AgoraChatService');
      }
    }

    await isar.writeTxn(() async {
      final target = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (target != null) {
        target.ownerId = newOwnerId;
        final currentAdmins = Set<String>.from(target.adminIds);
        currentAdmins.add(newOwnerId);
        target.adminIds = currentAdmins.toList();
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final currentUid = _authService.getCurrentUserId() ?? '';

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.leaveGroup(groupId);
      } catch (e) {
        developer.log('Agora leaveGroup failed: $e', name: 'AgoraChatService');
      }
    }

    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        final currentMembers = List<String>.from(group.memberIds);
        currentMembers.remove(currentUid);
        final currentAdmins = List<String>.from(group.adminIds);
        currentAdmins.remove(currentUid);
        group.memberIds = currentMembers;
        group.adminIds = currentAdmins;
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> destroyGroup(String groupId) async {
    final currentUid = _authService.getCurrentUserId() ?? 'unknown';
    final isar = await _localDbService.database;
    final group = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(groupId)
        .findFirst();
    if (group != null && group.ownerId != currentUid) {
      throw StateError('Only the group owner can destroy the group.');
    }

    if (_initialized) {
      try {
        await ChatClient.getInstance.groupManager.destroyGroup(groupId);
      } catch (e) {
        developer.log('Agora destroyGroup failed: $e', name: 'AgoraChatService');
      }
    }

    await deleteConversation(groupId);
    await _syncConversationsFromLocal();
  }

  @override
  Stream<ChatConnectionState> get connectionState => _connectionStateController.stream;

  @override
  Future<void> dispose() async {
    await logout();
    await _conversationsController.close();
    for (final c in _messagesControllers.values) {
      await c.close();
    }
    _messagesControllers.clear();
    await _connectionStateController.close();
    _http.close();
  }
}
