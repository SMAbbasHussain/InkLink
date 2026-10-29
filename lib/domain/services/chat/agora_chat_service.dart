import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/collections/local_chat_conversation.dart';
import '../../../core/database/collections/local_chat_message.dart';
import '../../../core/database/collections/local_profile.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../models/chat/chat_share_payload.dart';
import '../../repositories/chat/chat_repository.dart';
import 'chat_service.dart';

class AgoraChatServiceImpl implements ChatService {
  final LocalDatabaseService _localDbService;
  final AuthService _authService;
  final CloudFunctionsService? _cloudFunctionsService;
  final ChatRepository _chatRepository;

  bool _initialized = false;
  String? _currentUserId;

  final StreamController<List<ChatConversationModel>> _conversationsController =
      StreamController<List<ChatConversationModel>>.broadcast();
  final Map<String, StreamController<List<ChatMessageModel>>> _messagesControllers = {};

  StreamSubscription<List<ChatDoc>>? _firestoreChatsSub;
  final Map<String, StreamSubscription<List<ChatDocChange>>> _firestoreMessageSubs = {};
  final Set<String> _syncedMessageIds = {};
  // Chats whose first Firestore snapshot (history replay) has been
  // processed; unread is not counted for that initial replay (L2).
  final Set<String> _initialMessageSnapshotsSeen = {};

  AgoraChatServiceImpl({
    required LocalDatabaseService localDbService,
    required AuthService authService,
    CloudFunctionsService? cloudFunctionsService,
    required ChatRepository chatRepository,
  })  : _localDbService = localDbService,
        _authService = authService,
        _cloudFunctionsService = cloudFunctionsService,
        _chatRepository = chatRepository;

  String _sanitizeAgoraUid(String uid) {
    // Agora Chat usernames accept [a-zA-Z0-9_-]+
    return uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
  }

  String _getFirestoreChatId({
    required String conversationId,
    required bool isGroup,
    String? currentUid,
  }) {
    if (isGroup) {
      return conversationId;
    }
    if (conversationId.startsWith('dm_')) {
      return conversationId;
    }
    final myUid = currentUid ?? _currentUserId ?? _authService.getCurrentUserId() ?? '';
    final parts = [myUid, conversationId]..sort();
    return 'dm_${parts[0]}_${parts[1]}';
  }

  Future<List<String>> _resolveParticipantIds({
    required String conversationId,
    required bool isGroup,
    required String currentUid,
  }) async {
    if (!isGroup) {
      final list = [currentUid, conversationId]..sort();
      return list;
    }
    final isar = await _localDbService.database;
    final conv = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(conversationId)
        .findFirst();
    if (conv != null && conv.memberIds.isNotEmpty) {
      final set = Set<String>.from(conv.memberIds)..add(currentUid);
      return set.toList();
    }
    return [currentUid];
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final appKey = dotenv.env['AGORA_CHAT_APP_KEY'];
    final appId = dotenv.env['AGORA_APP_ID'] ?? '5532d37e639245b78935fd9aebdf45a8';

    try {
      ChatOptions options;
      if (appKey != null && appKey.isNotEmpty && appKey.contains('#')) {
        options = ChatOptions.withAppKey(
          appKey,
          autoLogin: false,
          debugMode: false,
        );
      } else {
        options = ChatOptions.withAppId(
          appId,
          autoLogin: false,
          debugMode: false,
        );
      }

      await ChatClient.getInstance.init(options);
      await ChatClient.getInstance.startCallback();

      // Register listener for incoming Agora Chat messages & lifecycle events
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
              final targetId = msg.attributes?['localMessageId']?.toString() ?? msg.msgId;
              final convId = msg.conversationId ?? msg.to ?? '';
              await _updateMessageStatus(targetId, ChatMessageStatus.delivered, conversationId: convId);
            }
          },
          onMessagesRead: (List<ChatMessage> messages) async {
            for (final msg in messages) {
              final targetId = msg.attributes?['localMessageId']?.toString() ?? msg.msgId;
              final convId = msg.conversationId ?? msg.to ?? '';
              await _updateMessageStatus(targetId, ChatMessageStatus.read, conversationId: convId);
            }
          },
          onMessagesRecalled: (List<ChatMessage> messages) async {
            for (final msg in messages) {
              final conversationId = msg.conversationId ?? msg.to ?? '';
              await deleteMessage(
                conversationId: conversationId,
                messageId: msg.msgId,
              );
            }
          },
          onMessageReactionDidChange: (List<ChatMessageReactionEvent> list) async {
            for (final event in list) {
              _notifyThreadUpdated(event.conversationId);
            }
            await _syncConversationsFromLocal();
          },
        ),
      );

      _initialized = true;
      developer.log('Agora Chat SDK successfully initialized', name: 'AgoraChatService');
    } catch (e, st) {
      developer.log('Agora Chat init warning: $e', name: 'AgoraChatService', stackTrace: st);
      // Mark initialized to allow local-first operation even if Agora servers unreachable
      _initialized = true;
    }
  }

  @override
  Future<void> login(String userId) async {
    await initialize();

    final agoraUsername = _sanitizeAgoraUid(userId);
    final isLoggedIn = await ChatClient.getInstance.isLoginBefore();
    if (isLoggedIn) {
      final currentLoggedIn = await ChatClient.getInstance.getCurrentUserId() ??
          ChatClient.getInstance.currentUserId;
      if (currentLoggedIn != null &&
          currentLoggedIn.isNotEmpty &&
          currentLoggedIn != agoraUsername) {
        await ChatClient.getInstance.logout(true);
      }
    }

    final stillLoggedIn = await ChatClient.getInstance.isLoginBefore();
    if (!stillLoggedIn) {
      final token = dotenv.env['AGORA_CHAT_TOKEN']?.trim();
      if (token == null || token.isEmpty) {
        developer.log(
          'Agora Chat authentication token not configured in .env (AGORA_CHAT_TOKEN). Operating in offline/local-first mode.',
          name: 'AgoraChatService',
        );
      } else {
        try {
          await ChatClient.getInstance.loginWithAgoraToken(agoraUsername, token);
          developer.log('Logged into Agora Chat as: $agoraUsername', name: 'AgoraChatService');
        } catch (e, st) {
          developer.log(
            'Failed to log into Agora Chat server: $e. Operating in local-first mode.',
            name: 'AgoraChatService',
            stackTrace: st,
          );
        }
      }
    } else {
      developer.log('Already logged into Agora Chat as: $agoraUsername', name: 'AgoraChatService');
    }

    // Start Cloud Firestore real-time sync for live messaging
    _startFirestoreSync(userId);

    // Sync conversations and messages from Agora Chat SDK into local database (if available)
    await _syncFromAgora();
    await _syncConversationsFromLocal();
  }

  void _startFirestoreSync(String userId) {
    _firestoreChatsSub?.cancel();
    for (final sub in _firestoreMessageSubs.values) {
      sub.cancel();
    }
    _firestoreMessageSubs.clear();

    try {
      _firestoreChatsSub = _chatRepository.watchChatsForUser(userId).listen(
        (chatDocs) async {
          await _handleFirestoreChatsSnapshot(chatDocs, userId);
        },
        onError: (e, st) {
          developer.log('Firestore chat sync listener warning: $e',
              name: 'AgoraChatService', error: e, stackTrace: st);
        },
      );
    } catch (e, st) {
      developer.log('Failed to start Firestore chat sync: $e',
          name: 'AgoraChatService', error: e, stackTrace: st);
    }
  }

  Future<void> _handleFirestoreChatsSnapshot(
    List<ChatDoc> chatDocs,
    String currentUid,
  ) async {
    final isar = await _localDbService.database;

    for (final doc in chatDocs) {
      final data = doc.data;
      final chatId = doc.id;
      final isGroup = data['isGroup'] == true;
      final participantIds = List<String>.from(data['participantIds'] ?? []);

      String localConvId;
      if (isGroup) {
        localConvId = chatId;
      } else {
        final partnerUid = participantIds.firstWhere(
          (id) => id != currentUid,
          orElse: () => '',
        );
        if (partnerUid.isEmpty) continue;
        localConvId = partnerUid;
      }

      String? partnerName;
      String? partnerAvatar;
      if (!isGroup) {
        if (data['senderNames'] is Map) {
          partnerName = data['senderNames'][localConvId]?.toString();
        }
        if (data['senderAvatars'] is Map) {
          partnerAvatar = data['senderAvatars'][localConvId]?.toString();
        }
      }

      final groupName = data['name']?.toString() ?? 'Group Chat';
      final groupAvatar = data['avatarUrl']?.toString();
      final lastMsg = data['lastMessage']?.toString() ?? '';
      DateTime? lastMsgTime;
      if (data['lastMessageTimestamp'] is DateTime) {
        lastMsgTime = data['lastMessageTimestamp'] as DateTime;
      } else if (data['lastMessageTimestamp'] is String) {
        lastMsgTime = DateTime.tryParse(data['lastMessageTimestamp']);
      }

      await isar.writeTxn(() async {
        final existingConv = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(localConvId)
            .findFirst();

        final conv = existingConv ?? LocalChatConversation();
        conv.conversationId = localConvId;
        if (isGroup) {
          conv.name = groupName;
          conv.avatarUrl = groupAvatar;
          conv.isGroup = true;
          conv.ownerId = data['ownerId']?.toString();
          conv.adminIds = List<String>.from(data['adminIds'] ?? []);
          conv.memberIds = participantIds;
          conv.description = data['description']?.toString();
        } else {
          if (partnerName != null && partnerName.isNotEmpty) {
            conv.name = partnerName;
          } else if (conv.name.isEmpty || conv.name == 'User') {
            conv.name = 'User';
          }
          if (partnerAvatar != null && partnerAvatar.isNotEmpty) {
            conv.avatarUrl = partnerAvatar;
          }
          conv.isGroup = false;
          final members = Set<String>.from(conv.memberIds)
            ..add(currentUid)
            ..add(localConvId);
          conv.memberIds = members.toList();
        }

        if (lastMsg.isNotEmpty) {
          conv.lastMessage = lastMsg;
        }
        if (lastMsgTime != null) {
          conv.lastMessageTimestamp = lastMsgTime;
          conv.updatedAt = lastMsgTime;
        }

        await isar.localChatConversations.put(conv);
      });

      _subscribeToFirestoreMessages(
        chatId: chatId,
        localConvId: localConvId,
        isGroup: isGroup,
        currentUid: currentUid,
      );
    }

    await _syncConversationsFromLocal();
  }

  void _subscribeToFirestoreMessages({
    required String chatId,
    required String localConvId,
    required bool isGroup,
    required String currentUid,
  }) {
    if (_firestoreMessageSubs.containsKey(chatId)) return;

    final sub = _chatRepository.watchMessages(chatId).listen(
      (changes) async {
        await _handleFirestoreMessagesSnapshot(
          changes: changes,
          chatId: chatId,
          localConvId: localConvId,
          isGroup: isGroup,
          currentUid: currentUid,
        );
      },
      onError: (e, st) {
        developer.log('Firestore messages listener error for $chatId: $e',
            name: 'AgoraChatService');
      },
    );

    _firestoreMessageSubs[chatId] = sub;
  }

  Future<void> _handleFirestoreMessagesSnapshot({
    required List<ChatDocChange> changes,
    required String chatId,
    required String localConvId,
    required String currentUid,
    required bool isGroup,
  }) async {
    final isar = await _localDbService.database;

    // The first snapshot for a chat replays the entire history as `added`
    // events; counting unread for them inflates the badge on every cold
    // start until it is manually cleared. Only count unread after the
    // initial replay has been processed.
    final isInitialReplay = !_initialMessageSnapshotsSeen.contains(chatId);

    for (final change in changes) {
      final doc = change.doc;
      if (doc == null) continue;
      final data = doc.data;

      final msgId = data['id']?.toString() ?? doc.id;
      final senderId = data['senderId']?.toString() ?? '';
      final senderName = data['senderName']?.toString() ?? 'User';
      final senderAvatar = data['senderAvatar']?.toString();
      final type = ChatMessageType.fromString(data['type']?.toString() ?? 'text');
      final content = data['content']?.toString() ?? '';
      final isEdited = data['isEdited'] == true;
      final isDeleted = data['isDeleted'] == true;

      DateTime ts = DateTime.now();
      if (data['timestamp'] is DateTime) {
        ts = data['timestamp'] as DateTime;
      } else if (data['timestamp'] is String) {
        ts = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
      }

      Map<String, List<String>> parsedReactions = {};
      if (data['reactions'] is Map) {
        final rMap = data['reactions'] as Map;
        rMap.forEach((k, v) {
          if (v is List) {
            parsedReactions[k.toString()] = v.map((e) => e.toString()).toList();
          }
        });
      }

      ChatSharePayload? sharePayload;
      if (data['sharePayload'] is Map) {
        try {
          sharePayload = ChatSharePayload.fromMap(
            Map<String, dynamic>.from(data['sharePayload']),
          );
        } catch (_) {}
      }

      if (change.type == ChatDocChangeType.modified) {
        await isar.writeTxn(() async {
          final existing = await isar.localChatMessages
              .filter()
              .messageIdEqualTo(msgId)
              .findFirst();
          if (existing != null) {
            existing.content = content;
            existing.isEdited = isEdited;
            existing.isDeleted = isDeleted;
            existing.reactionsJson = jsonEncode(parsedReactions);
            existing.status = ChatMessageStatus.delivered.name;
            await isar.localChatMessages.put(existing);
          }
        });
        _notifyThreadUpdated(localConvId);
        continue;
      }

      if (change.type == ChatDocChangeType.removed) {
        await isar.writeTxn(() async {
          final existing = await isar.localChatMessages
              .filter()
              .messageIdEqualTo(msgId)
              .findFirst();
          if (existing != null) {
            existing.isDeleted = true;
            existing.content = 'This message was deleted';
            await isar.localChatMessages.put(existing);
          }
        });
        _notifyThreadUpdated(localConvId);
        continue;
      }

      // Handle added / initial message
      final model = ChatMessageModel(
        id: msgId,
        conversationId: localConvId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        type: type,
        content: content,
        timestamp: ts,
        status: senderId == currentUid ? ChatMessageStatus.sent : ChatMessageStatus.delivered,
        reactions: parsedReactions,
        isEdited: isEdited,
        isDeleted: isDeleted,
        fileName: data['fileName']?.toString(),
        fileSize: data['fileSize'] is int ? data['fileSize'] as int : null,
        sharePayload: sharePayload,
        replyToId: data['replyToId']?.toString(),
        replyToSender: data['replyToSender']?.toString(),
        replyToText: data['replyToText']?.toString(),
      );

      final isNewToSession = _syncedMessageIds.add(msgId);

      await _persistMessageLocally(
        model,
        isGroup: isGroup,
        countUnread: !isInitialReplay,
      );

      // Trigger local foreground notification for incoming messages from others
      if (isNewToSession && senderId != currentUid && DateTime.now().difference(ts).inMinutes < 2) {
        final conv = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(localConvId)
            .findFirst();
        final isMuted = conv?.isMuted ?? false;
        if (!isMuted) {
          final notifyTitle = isGroup
              ? (conv != null && conv.name.isNotEmpty
                  ? '${conv.name} ($senderName)'
                  : senderName)
              : senderName;
          final notifyBody = type == ChatMessageType.text ? content : '[${type.name}]';
          await LocalNotificationService.showNotification(
            title: notifyTitle,
            body: notifyBody,
            largeIcon: senderAvatar,
            payload: {
              'type': 'chat_message',
              'targetId': localConvId,
              'senderName': isGroup ? (conv?.name ?? 'Group') : senderName,
              'isGroup': isGroup.toString(),
            },
          );
        }
      }
    }

    // The initial replay has been processed; subsequent snapshots may
    // count unread.
    if (isInitialReplay) {
      _initialMessageSnapshotsSeen.add(chatId);
    }

    _notifyThreadUpdated(localConvId);
    await _syncConversationsFromLocal();
  }

  Future<void> _syncFromAgora() async {
    try {
      final isLogged = await ChatClient.getInstance.isLoginBefore();
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
        developer.log('Agora getConversationsFromServer notice (local-first): $e', name: 'AgoraChatService');
      }

      for (final conv in agoraConvs) {
        try {
          final messages = await conv.loadMessages(startMsgId: '', loadCount: 50);
          for (final msg in messages) {
            await _handleIncomingAgoraMessage(msg, triggerNotification: false);
          }
        } catch (e) {
          developer.log('Error loading messages for conv ${conv.id}: $e', name: 'AgoraChatService');
        }
      }
    } catch (e) {
      developer.log('Agora sync error: $e', name: 'AgoraChatService');
    }
  }

  @override
  Future<void> logout() async {
    _currentUserId = null;
    await _firestoreChatsSub?.cancel();
    _firestoreChatsSub = null;
    for (final sub in _firestoreMessageSubs.values) {
      await sub.cancel();
    }
    _firestoreMessageSubs.clear();
    _syncedMessageIds.clear();
    _initialMessageSnapshotsSeen.clear();

    try {
      await ChatClient.getInstance.logout(true);
    } catch (_) {}
  }

  Future<void> _handleIncomingAgoraMessage(
    ChatMessage msg, {
    bool triggerNotification = true,
  }) async {
    try {
      final conversationId = msg.conversationId ?? msg.from ?? '';
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

      final isGroup = msg.chatType == ChatType.GroupChat;
      final model = ChatMessageModel(
        id: msg.msgId,
        conversationId: conversationId,
        senderId: msg.from ?? '',
        senderName: msg.attributes?['senderName']?.toString() ?? msg.from ?? 'User',
        senderAvatar: msg.attributes?['senderAvatar']?.toString(),
        type: msgType,
        content: textContent,
        timestamp: DateTime.fromMillisecondsSinceEpoch(msg.serverTime),
        status: ChatMessageStatus.delivered,
        fileName: fileName,
        fileSize: fileSize,
        replyToId: msg.attributes?['replyToId']?.toString(),
        replyToSender: msg.attributes?['replyToSender']?.toString(),
        replyToText: msg.attributes?['replyToText']?.toString(),
      );

      await _persistMessageLocally(model, isGroup: isGroup);

      // Dispatch local foreground notification if receiver is not sender and chat is not muted
      if (triggerNotification) {
        final currentUid = _authService.getCurrentUserId();
        if (model.senderId != currentUid) {
          final isar = await _localDbService.database;
          final conv = await isar.localChatConversations
              .filter()
              .conversationIdEqualTo(conversationId)
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
          .conversationIdEqualTo(model.conversationId)
          .findFirst();

      final conv = existingConv ?? LocalChatConversation();
      conv.conversationId = model.conversationId;
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
      if (countUnread && model.senderId != currentUid) {
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

      // 3. For DMs, also materialize counterpart conversation row for the recipient
      if (!isGroup && model.senderId.isNotEmpty && model.conversationId.isNotEmpty) {
        final counterpartConvId = model.senderId;
        final existingCounterpart = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(counterpartConvId)
            .findFirst();

        final counterpart = existingCounterpart ?? LocalChatConversation();
        counterpart.conversationId = counterpartConvId;
        if (counterpart.name.isEmpty || counterpart.name == 'User') {
          counterpart.name = model.senderName.isNotEmpty ? model.senderName : 'User';
        }
        if (model.senderAvatar != null && model.senderAvatar!.isNotEmpty) {
          counterpart.avatarUrl = model.senderAvatar;
        }
        counterpart.isGroup = false;
        counterpart.lastMessage = model.type == ChatMessageType.text
            ? model.content
            : '[${model.type.name}]';
        counterpart.lastMessageTimestamp = model.timestamp;
        counterpart.updatedAt = DateTime.now();
        if (model.senderId == currentUid) {
          counterpart.unreadCount = counterpart.unreadCount + 1;
        }
        final cMembers = Set<String>.from(counterpart.memberIds);
        cMembers.add(model.senderId);
        cMembers.add(model.conversationId);
        counterpart.memberIds = cMembers.toList();

        await isar.localChatConversations.put(counterpart);
      }
    });

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(model.conversationId);
    if (!isGroup && model.senderId.isNotEmpty) {
      _notifyThreadUpdated(model.senderId);
    }
  }

  void _notifyThreadUpdated(String conversationId) async {
    final controller = _messagesControllers[conversationId];
    if (controller != null && !controller.isClosed) {
      final messages = await getMessages(conversationId);
      controller.add(messages);
    }
  }

  Future<void> _syncConversationsFromLocal() async {
    final conversations = await getConversations();
    if (!_conversationsController.isClosed) {
      _conversationsController.add(conversations);
    }
  }

  @override
  Stream<List<ChatConversationModel>> watchConversations() {
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
          .conversationIdEqualTo(currentUid)
          .and()
          .not()
          .senderIdEqualTo(currentUid)
          .findAll();

      final senders = <String, LocalChatMessage>{};
      for (final m in incomingDmMessages) {
        if (!senders.containsKey(m.senderId) ||
            m.timestamp.isAfter(senders[m.senderId]!.timestamp)) {
          senders[m.senderId] = m;
        }
      }

      for (final entry in senders.entries) {
        final senderUid = entry.key;
        final latestMsg = entry.value;
        final existingPartnerConv = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(senderUid)
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
    for (final c in locals) {
      // Don't show DM with self or conversations the current user is not a participant of
      if (currentUid != null && currentUid.isNotEmpty) {
        if (!c.isGroup) {
          if (c.conversationId == currentUid) continue;
          if (c.memberIds.isNotEmpty && !c.memberIds.contains(currentUid)) continue;
        } else {
          if (c.memberIds.isNotEmpty && !c.memberIds.contains(currentUid)) continue;
        }
      }

      String resolvedName = c.name;
      String? resolvedAvatar = c.avatarUrl;

      // If DM and name or avatar is missing or generic, resolve from cached LocalProfile
      if (!c.isGroup &&
          (resolvedName.isEmpty ||
              resolvedName == 'User' ||
              resolvedAvatar == null ||
              resolvedAvatar.isEmpty)) {
        final profile = await isar.localProfiles
            .filter()
            .uidEqualTo(c.conversationId)
            .findFirst();
        if (profile != null) {
          if (profile.displayName.isNotEmpty) {
            resolvedName = profile.displayName;
          }
          if (profile.photoURL != null && profile.photoURL!.isNotEmpty) {
            resolvedAvatar = profile.photoURL;
          }
        } else {
          final partnerMsg = await isar.localChatMessages
              .filter()
              .senderIdEqualTo(c.conversationId)
              .findFirst();
          if (partnerMsg != null && partnerMsg.senderName.isNotEmpty) {
            resolvedName = partnerMsg.senderName;
            resolvedAvatar ??= partnerMsg.senderAvatar;
          }
        }
      }

      results.add(
        ChatConversationModel(
          id: c.conversationId,
          name: resolvedName.isNotEmpty ? resolvedName : (c.isGroup ? 'Group Chat' : 'User'),
          avatarUrl: resolvedAvatar,
          isGroup: c.isGroup,
          lastMessage: c.lastMessage,
          lastMessageTimestamp: c.lastMessageTimestamp,
          unreadCount: c.unreadCount,
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
      final conv = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId)
          .findFirst();
      if (conv != null) {
        conv.unreadCount = 0;
        await isar.localChatConversations.put(conv);
      }
    });

    try {
      final agoraConv = await ChatClient.getInstance.chatManager.getConversation(conversationId);
      await agoraConv?.markAllMessagesAsRead();
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId)
          .deleteAll();
      await isar.localChatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .deleteAll();
    });

    try {
      await ChatClient.getInstance.chatManager.deleteConversation(conversationId);
    } catch (_) {}

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> toggleMuteConversation(String conversationId) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final conv = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId)
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
    if (!_messagesControllers.containsKey(conversationId)) {
      _messagesControllers[conversationId] =
          StreamController<List<ChatMessageModel>>.broadcast();
    }
    _notifyThreadUpdated(conversationId);
    return _messagesControllers[conversationId]!.stream;
  }

  @override
  Future<List<ChatMessageModel>> getMessages(String conversationId) async {
    final isar = await _localDbService.database;
    final currentUid = _authService.getCurrentUserId() ?? '';

    // Fetch all messages for this thread:
    // Either stored directly under conversationId,
    // or sent between conversationId and currentUid (counterpart DM)
    var locals = await isar.localChatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .or()
        .group((q) => q
            .conversationIdEqualTo(currentUid)
            .and()
            .senderIdEqualTo(conversationId))
        .sortByTimestamp()
        .findAll();

    // If local Isar has no messages, lazily fetch from Agora Chat SDK
    if (locals.isEmpty) {
      try {
        final conv = await ChatClient.getInstance.chatManager.getConversation(conversationId);
        if (conv != null) {
          final msgs = await conv.loadMessages(startMsgId: '', loadCount: 50);
          for (final msg in msgs) {
            await _handleIncomingAgoraMessage(msg, triggerNotification: false);
          }
          locals = await isar.localChatMessages
              .filter()
              .conversationIdEqualTo(conversationId)
              .or()
              .group((q) => q
                  .conversationIdEqualTo(currentUid)
                  .and()
                  .senderIdEqualTo(conversationId))
              .sortByTimestamp()
              .findAll();
        }
      } catch (e) {
        developer.log('Notice loading messages on demand from Agora: $e', name: 'AgoraChatService');
      }
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

  Future<void> _dispatchPushNotification({
    required String recipientUid,
    required String title,
    required String body,
    required String conversationId,
    bool isGroup = false,
  }) async {
    if (_cloudFunctionsService == null) return;
    try {
      final user = _authService.getCurrentUser();
      await _cloudFunctionsService.httpsCallable('sendNotification').call({
        'recipientUid': recipientUid,
        'title': title,
        'body': body,
        'type': 'chat_message',
        'action': 'open_chat',
        'targetId': conversationId,
        'senderUid': user?.uid ?? '',
        'senderName': user?.displayName ?? 'InkLink User',
        'senderPhotoUrl': user?.photoURL,
        'isPushOnly': true,
        'extraData': {'isGroup': isGroup.toString()},
      });
    } catch (e) {
      developer.log('Chat push dispatch notice: $e', name: 'AgoraChatService');
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

    _syncedMessageIds.add(messageId);
    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );
    final participants = await _resolveParticipantIds(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );

    // Sync to Cloud Firestore for real-time delivery
    bool firestorePersisted = false;
    try {
      const now = chatServerTimestamp;
      await _chatRepository.mergeChat(firestoreChatId, {
        'id': firestoreChatId,
        'isGroup': isGroup,
        'participantIds': participants,
        'lastMessage': text,
        'lastMessageTimestamp': now,
        'lastSenderId': currentUid,
        'lastSenderName': currentName,
        'updatedAt': now,
        'senderNames': {currentUid: currentName},
        if (currentAvatar != null && currentAvatar.isNotEmpty)
          'senderAvatars': {currentUid: currentAvatar},
        if (conversationName != null && conversationName.isNotEmpty)
          'name': conversationName,
        if (conversationAvatar != null && conversationAvatar.isNotEmpty)
          'avatarUrl': conversationAvatar,
      });

      await _chatRepository.setMessage(firestoreChatId, messageId, {
        'id': messageId,
        'conversationId': conversationId,
        'senderId': currentUid,
        'senderName': currentName,
        if (currentAvatar != null) 'senderAvatar': currentAvatar,
        'type': 'text',
        'content': text,
        'timestamp': now,
        'status': 'sent',
        'participantIds': participants,
        'reactions': {},
        'isEdited': false,
        'isDeleted': false,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      });

      firestorePersisted = true;
      await _updateMessageStatus(messageId, ChatMessageStatus.sent, conversationId: conversationId);
    } catch (e, st) {
      developer.log('Firestore send text warning: $e',
          name: 'AgoraChatService', error: e, stackTrace: st);
    }

    // Agora Chat SDK Send (parallel transport / local-first fallback)
    try {
      final agoraMsg = ChatMessage.createTxtSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        content: text,
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      agoraMsg.attributes = {
        'senderName': currentName,
        'senderAvatar': currentAvatar ?? '',
        'localMessageId': messageId,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      };
      final isLogged = await ChatClient.getInstance.isLoginBefore();
      if (isLogged) {
        try {
          await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
        } catch (e) {
          developer.log('Agora send text warning: $e', name: 'AgoraChatService');
        }
      }
      await _updateMessageStatus(
        messageId,
        firestorePersisted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        conversationId: conversationId,
      );

      if (!isGroup) {
        _dispatchPushNotification(
          recipientUid: conversationId,
          title: currentName,
          body: text,
          conversationId: conversationId,
        );
      }

      // Only report sent when the durable store (Firestore) persisted the
      // message; otherwise mark failed so the UI can offer a retry.
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    } catch (e) {
      developer.log('Agora send text failure: $e', name: 'AgoraChatService');
      if (!firestorePersisted) {
        await _updateMessageStatus(
          messageId,
          ChatMessageStatus.failed,
          conversationId: conversationId,
        );
      }
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    }
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

    _syncedMessageIds.add(messageId);
    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );
    final participants = await _resolveParticipantIds(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );

    // Sync to Cloud Firestore
    bool firestorePersisted = false;
    try {
      const now = chatServerTimestamp;
      await _chatRepository.mergeChat(firestoreChatId, {
        'id': firestoreChatId,
        'isGroup': isGroup,
        'participantIds': participants,
        'lastMessage': '[image]',
        'lastMessageTimestamp': now,
        'lastSenderId': currentUid,
        'lastSenderName': currentName,
        'updatedAt': now,
        'senderNames': {currentUid: currentName},
        if (currentAvatar != null && currentAvatar.isNotEmpty)
          'senderAvatars': {currentUid: currentAvatar},
        if (conversationName != null && conversationName.isNotEmpty)
          'name': conversationName,
        if (conversationAvatar != null && conversationAvatar.isNotEmpty)
          'avatarUrl': conversationAvatar,
      });

      await _chatRepository.setMessage(firestoreChatId, messageId, {
        'id': messageId,
        'conversationId': conversationId,
        'senderId': currentUid,
        'senderName': currentName,
        if (currentAvatar != null) 'senderAvatar': currentAvatar,
        'type': 'image',
        'content': filePath,
        'timestamp': now,
        'status': 'sent',
        'participantIds': participants,
        'reactions': {},
        'isEdited': false,
        'isDeleted': false,
        if (fileName.isNotEmpty) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      });

      firestorePersisted = true;
      await _updateMessageStatus(messageId, ChatMessageStatus.sent, conversationId: conversationId);
    } catch (e, st) {
      developer.log('Firestore send image warning: $e',
          name: 'AgoraChatService', error: e, stackTrace: st);
    }

    try {
      final agoraMsg = ChatMessage.createImageSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        filePath: filePath,
        displayName: fileName,
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      agoraMsg.attributes = {
        'senderName': currentName,
        'senderAvatar': currentAvatar ?? '',
        'localMessageId': messageId,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      };
      final isLogged = await ChatClient.getInstance.isLoginBefore();
      if (isLogged) {
        try {
          await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
        } catch (e) {
          developer.log('Agora send image warning: $e', name: 'AgoraChatService');
        }
      }
      await _updateMessageStatus(
        messageId,
        firestorePersisted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        conversationId: conversationId,
      );

      if (!isGroup) {
        _dispatchPushNotification(
          recipientUid: conversationId,
          title: currentName,
          body: '📷 Sent an image',
          conversationId: conversationId,
        );
      }

      // Only report sent when the durable store (Firestore) persisted the
      // message; otherwise mark failed so the UI can offer a retry.
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    } catch (e) {
      developer.log('Agora send image failure: $e', name: 'AgoraChatService');
      if (!firestorePersisted) {
        await _updateMessageStatus(
          messageId,
          ChatMessageStatus.failed,
          conversationId: conversationId,
        );
      }
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    }
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

    _syncedMessageIds.add(messageId);
    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );
    final participants = await _resolveParticipantIds(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );

    // Sync to Cloud Firestore
    bool firestorePersisted = false;
    try {
      const now = chatServerTimestamp;
      await _chatRepository.mergeChat(firestoreChatId, {
        'id': firestoreChatId,
        'isGroup': isGroup,
        'participantIds': participants,
        'lastMessage': '[gif]',
        'lastMessageTimestamp': now,
        'lastSenderId': currentUid,
        'lastSenderName': currentName,
        'updatedAt': now,
        'senderNames': {currentUid: currentName},
        if (currentAvatar != null && currentAvatar.isNotEmpty)
          'senderAvatars': {currentUid: currentAvatar},
        if (conversationName != null && conversationName.isNotEmpty)
          'name': conversationName,
        if (conversationAvatar != null && conversationAvatar.isNotEmpty)
          'avatarUrl': conversationAvatar,
      });

      await _chatRepository.setMessage(firestoreChatId, messageId, {
        'id': messageId,
        'conversationId': conversationId,
        'senderId': currentUid,
        'senderName': currentName,
        if (currentAvatar != null) 'senderAvatar': currentAvatar,
        'type': 'gif',
        'content': gifUrl,
        'timestamp': now,
        'status': 'sent',
        'participantIds': participants,
        'reactions': {},
        'isEdited': false,
        'isDeleted': false,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      });

      firestorePersisted = true;
      await _updateMessageStatus(messageId, ChatMessageStatus.sent, conversationId: conversationId);
    } catch (e, st) {
      developer.log('Firestore send GIF warning: $e',
          name: 'AgoraChatService', error: e, stackTrace: st);
    }

    try {
      final agoraMsg = ChatMessage.createCustomSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        event: 'gif',
        params: {'payload': gifUrl},
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      agoraMsg.attributes = {
        'senderName': currentName,
        'senderAvatar': currentAvatar ?? '',
        'localMessageId': messageId,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      };
      final isLogged = await ChatClient.getInstance.isLoginBefore();
      if (isLogged) {
        try {
          await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
        } catch (e) {
          developer.log('Agora send gif warning: $e', name: 'AgoraChatService');
        }
      }
      await _updateMessageStatus(
        messageId,
        firestorePersisted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        conversationId: conversationId,
      );

      if (!isGroup) {
        _dispatchPushNotification(
          recipientUid: conversationId,
          title: currentName,
          body: '🎬 Sent a GIF',
          conversationId: conversationId,
        );
      }

      // Only report sent when the durable store (Firestore) persisted the
      // message; otherwise mark failed so the UI can offer a retry.
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    } catch (e) {
      developer.log('Agora send GIF failure: $e', name: 'AgoraChatService');
      if (!firestorePersisted) {
        await _updateMessageStatus(
          messageId,
          ChatMessageStatus.failed,
          conversationId: conversationId,
        );
      }
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    }
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

    _syncedMessageIds.add(messageId);
    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );
    final participants = await _resolveParticipantIds(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );

    // Sync to Cloud Firestore
    bool firestorePersisted = false;
    try {
      const now = chatServerTimestamp;
      await _chatRepository.mergeChat(firestoreChatId, {
        'id': firestoreChatId,
        'isGroup': isGroup,
        'participantIds': participants,
        'lastMessage': '[file] $fileName',
        'lastMessageTimestamp': now,
        'lastSenderId': currentUid,
        'lastSenderName': currentName,
        'updatedAt': now,
        'senderNames': {currentUid: currentName},
        if (currentAvatar != null && currentAvatar.isNotEmpty)
          'senderAvatars': {currentUid: currentAvatar},
        if (conversationName != null && conversationName.isNotEmpty)
          'name': conversationName,
        if (conversationAvatar != null && conversationAvatar.isNotEmpty)
          'avatarUrl': conversationAvatar,
      });

      await _chatRepository.setMessage(firestoreChatId, messageId, {
        'id': messageId,
        'conversationId': conversationId,
        'senderId': currentUid,
        'senderName': currentName,
        if (currentAvatar != null) 'senderAvatar': currentAvatar,
        'type': 'file',
        'content': filePath,
        'timestamp': now,
        'status': 'sent',
        'participantIds': participants,
        'reactions': {},
        'isEdited': false,
        'isDeleted': false,
        'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      });

      firestorePersisted = true;
      await _updateMessageStatus(messageId, ChatMessageStatus.sent, conversationId: conversationId);
    } catch (e, st) {
      developer.log('Firestore send file warning: $e',
          name: 'AgoraChatService', error: e, stackTrace: st);
    }

    try {
      final agoraMsg = ChatMessage.createFileSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        filePath: filePath,
        displayName: fileName,
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      agoraMsg.attributes = {
        'senderName': currentName,
        'senderAvatar': currentAvatar ?? '',
        'localMessageId': messageId,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      };
      final isLogged = await ChatClient.getInstance.isLoginBefore();
      if (isLogged) {
        try {
          await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
        } catch (e) {
          developer.log('Agora send file warning: $e', name: 'AgoraChatService');
        }
      }
      await _updateMessageStatus(
        messageId,
        firestorePersisted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        conversationId: conversationId,
      );

      if (!isGroup) {
        _dispatchPushNotification(
          recipientUid: conversationId,
          title: currentName,
          body: '📎 Sent a file: $fileName',
          conversationId: conversationId,
        );
      }

      // Only report sent when the durable store (Firestore) persisted the
      // message; otherwise mark failed so the UI can offer a retry.
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    } catch (e) {
      developer.log('Agora send file failure: $e', name: 'AgoraChatService');
      if (!firestorePersisted) {
        await _updateMessageStatus(
          messageId,
          ChatMessageStatus.failed,
          conversationId: conversationId,
        );
      }
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    }
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

    _syncedMessageIds.add(messageId);
    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );
    final participants = await _resolveParticipantIds(
      conversationId: conversationId,
      isGroup: isGroup,
      currentUid: currentUid,
    );

    // Sync to Cloud Firestore
    bool firestorePersisted = false;
    try {
      const now = chatServerTimestamp;
      await _chatRepository.mergeChat(firestoreChatId, {
        'id': firestoreChatId,
        'isGroup': isGroup,
        'participantIds': participants,
        'lastMessage': isBoard
            ? '🎨 Shared board: ${payload.title}'
            : '💼 Shared workspace: ${payload.title}',
        'lastMessageTimestamp': now,
        'lastSenderId': currentUid,
        'lastSenderName': currentName,
        'updatedAt': now,
        'senderNames': {currentUid: currentName},
        if (currentAvatar != null && currentAvatar.isNotEmpty)
          'senderAvatars': {currentUid: currentAvatar},
        if (conversationName != null && conversationName.isNotEmpty)
          'name': conversationName,
        if (conversationAvatar != null && conversationAvatar.isNotEmpty)
          'avatarUrl': conversationAvatar,
      });

      await _chatRepository.setMessage(firestoreChatId, messageId, {
        'id': messageId,
        'conversationId': conversationId,
        'senderId': currentUid,
        'senderName': currentName,
        if (currentAvatar != null) 'senderAvatar': currentAvatar,
        'type': isBoard ? 'board_share' : 'workspace_share',
        'content': payload.toJsonString(),
        'sharePayload': payload.toMap(),
        'timestamp': now,
        'status': 'sent',
        'participantIds': participants,
        'reactions': {},
        'isEdited': false,
        'isDeleted': false,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      });

      firestorePersisted = true;
      await _updateMessageStatus(messageId, ChatMessageStatus.sent, conversationId: conversationId);
    } catch (e, st) {
      developer.log('Firestore send share warning: $e',
          name: 'AgoraChatService', error: e, stackTrace: st);
    }

    try {
      final agoraMsg = ChatMessage.createCustomSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        event: isBoard ? 'board_share' : 'workspace_share',
        params: {'payload': payload.toJsonString()},
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      agoraMsg.attributes = {
        'senderName': currentName,
        'senderAvatar': currentAvatar ?? '',
        'localMessageId': messageId,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToSender != null) 'replyToSender': replyToSender,
        if (replyToText != null) 'replyToText': replyToText,
      };
      final isLogged = await ChatClient.getInstance.isLoginBefore();
      if (isLogged) {
        try {
          await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
        } catch (e) {
          developer.log('Agora send share warning: $e', name: 'AgoraChatService');
        }
      }
      await _updateMessageStatus(
        messageId,
        firestorePersisted ? ChatMessageStatus.sent : ChatMessageStatus.failed,
        conversationId: conversationId,
      );

      if (!isGroup) {
        _dispatchPushNotification(
          recipientUid: conversationId,
          title: currentName,
          body: isBoard
              ? '🎨 Shared board: ${payload.title}'
              : '💼 Shared workspace: ${payload.title}',
          conversationId: conversationId,
        );
      }

      // Only report sent when the durable store (Firestore) persisted the
      // message; otherwise mark failed so the UI can offer a retry.
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    } catch (e) {
      developer.log('Agora send share card failure: $e', name: 'AgoraChatService');
      if (!firestorePersisted) {
        await _updateMessageStatus(
          messageId,
          ChatMessageStatus.failed,
          conversationId: conversationId,
        );
      }
      return model.copyWith(
        status: firestorePersisted
            ? ChatMessageStatus.sent
            : ChatMessageStatus.failed,
      );
    }
  }

  Future<void> _updateMessageStatus(
    String messageId,
    ChatMessageStatus status, {
    String? conversationId,
  }) async {
    final isar = await _localDbService.database;
    String? targetConvId = conversationId;
    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        msg.status = status.name;
        targetConvId ??= msg.conversationId;
        await isar.localChatMessages.put(msg);
      }
    });

    if (targetConvId != null && targetConvId!.isNotEmpty) {
      _notifyThreadUpdated(targetConvId!);
    }
  }

  @override
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final isLoggedIn = await ChatClient.getInstance.isLoginBefore();
    if (isLoggedIn) {
      try {
        await ChatClient.getInstance.chatManager.addReaction(
          messageId: messageId,
          reaction: emoji,
        );
      } catch (_) {}
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

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: conversationId.startsWith('group_'),
      currentUid: currentUid,
    );
    try {
      await _chatRepository
          .updateMessage(firestoreChatId, messageId, {'reactions': reactions});
    } catch (e) {
      developer.log('Firestore reaction sync warning: $e', name: 'AgoraChatService');
    }

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
    final isLoggedIn = await ChatClient.getInstance.isLoginBefore();
    if (isLoggedIn) {
      try {
        await ChatClient.getInstance.chatManager.removeReaction(
          messageId: messageId,
          reaction: emoji,
        );
      } catch (_) {}
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

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: conversationId.startsWith('group_'),
      currentUid: currentUid,
    );
    try {
      await _chatRepository
          .updateMessage(firestoreChatId, messageId, {'reactions': reactions});
    } catch (e) {
      developer.log('Firestore remove reaction warning: $e', name: 'AgoraChatService');
    }

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
    try {
      await ChatClient.getInstance.chatManager.modifyMessage(
        messageId: messageId,
        msgBody: ChatTextMessageBody(content: newContent),
      );
    } catch (_) {}

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

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: conversationId.startsWith('group_'),
    );
    try {
      await _chatRepository
          .updateMessage(firestoreChatId, messageId, {
        'content': newContent,
        'isEdited': true,
      });
    } catch (e) {
      developer.log('Firestore edit sync warning: $e', name: 'AgoraChatService');
    }

    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final conv = await ChatClient.getInstance.chatManager.getConversation(conversationId);
      if (conv != null) {
        await conv.deleteMessage(messageId);
      }
    } catch (_) {}

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
    });

    final firestoreChatId = _getFirestoreChatId(
      conversationId: conversationId,
      isGroup: conversationId.startsWith('group_'),
    );
    try {
      await _chatRepository
          .updateMessage(firestoreChatId, messageId, {
        'content': 'This message was deleted',
        'isDeleted': true,
      });
    } catch (e) {
      developer.log('Firestore delete sync warning: $e', name: 'AgoraChatService');
    }

    _notifyThreadUpdated(conversationId);
  }

  // ============================================================
  // GROUP CHAT MANAGEMENT
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
    try {
      final options = ChatGroupOptions(
        style: ChatGroupStyle.PublicJoinNeedApproval,
        maxCount: 200,
      );
      final group = await ChatClient.getInstance.groupManager.createGroup(
        groupName: name,
        desc: description,
        options: options,
        inviteMembers: memberIds.map(_sanitizeAgoraUid).toList(),
      );
      if (group.groupId.isNotEmpty) {
        agoraGroupId = group.groupId;
      }
    } catch (e) {
      developer.log('Agora createGroup notice (fallback to Firestore): $e', name: 'AgoraChatService');
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

    try {
      const now = chatServerTimestamp;
      await _chatRepository.setChat(groupId, {
        'id': groupId,
        'isGroup': true,
        'name': name,
        'description': description,
        if (iconUrl != null && iconUrl.isNotEmpty) 'avatarUrl': iconUrl,
        'ownerId': currentUid,
        'adminIds': [currentUid],
        'participantIds': allMembers,
        'lastMessage': 'Group created',
        'lastMessageTimestamp': now,
        'updatedAt': now,
      });
    } catch (e) {
      developer.log('Firestore createGroup warning: $e', name: 'AgoraChatService');
    }

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

    try {
      if (name != null && name.isNotEmpty) {
        await ChatClient.getInstance.groupManager.changeGroupName(groupId, name);
      }
      if (description != null) {
        await ChatClient.getInstance.groupManager.changeGroupDescription(groupId, description);
      }
    } catch (_) {}

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

    try {
      final updates = <String, dynamic>{
        'updatedAt': chatServerTimestamp,
      };
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (iconUrl != null && iconUrl.isNotEmpty) updates['avatarUrl'] = iconUrl;
      await _chatRepository.updateChat(groupId, updates);
    } catch (e) {
      developer.log('Firestore updateGroupInfo warning: $e', name: 'AgoraChatService');
    }

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

    try {
      await ChatClient.getInstance.groupManager.addMembers(
        groupId,
        memberIds.map(_sanitizeAgoraUid).toList(),
      );
    } catch (_) {}

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

    try {
      await _chatRepository.updateChat(groupId, {
        'participantIds': ChatArrayOp.union(memberIds),
        'updatedAt': chatServerTimestamp,
      });
    } catch (e) {
      developer.log('Firestore addGroupMembers warning: $e', name: 'AgoraChatService');
    }

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

    try {
      await ChatClient.getInstance.groupManager.removeMembers(
        groupId,
        [_sanitizeAgoraUid(memberId)],
      );
    } catch (_) {}

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

    try {
      await _chatRepository.updateChat(groupId, {
        'participantIds': ChatArrayOp.remove([memberId]),
        'adminIds': ChatArrayOp.remove([memberId]),
        'updatedAt': chatServerTimestamp,
      });
    } catch (e) {
      developer.log('Firestore removeGroupMember warning: $e', name: 'AgoraChatService');
    }

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

    try {
      await ChatClient.getInstance.groupManager.addAdmin(
        groupId,
        _sanitizeAgoraUid(memberId),
      );
    } catch (_) {}

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

    try {
      await _chatRepository.updateChat(groupId, {
        'adminIds': ChatArrayOp.union([memberId]),
        'updatedAt': chatServerTimestamp,
      });
    } catch (e) {
      developer.log('Firestore promoteAdmin warning: $e', name: 'AgoraChatService');
    }

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

    try {
      await ChatClient.getInstance.groupManager.removeAdmin(
        groupId,
        _sanitizeAgoraUid(memberId),
      );
    } catch (_) {}

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

    try {
      await _chatRepository.updateChat(groupId, {
        'adminIds': ChatArrayOp.remove([memberId]),
        'updatedAt': chatServerTimestamp,
      });
    } catch (e) {
      developer.log('Firestore demoteAdmin warning: $e', name: 'AgoraChatService');
    }

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

    try {
      await ChatClient.getInstance.groupManager.changeOwner(
        groupId,
        _sanitizeAgoraUid(newOwnerId),
      );
    } catch (_) {}

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

    try {
      await _chatRepository.updateChat(groupId, {
        'ownerId': newOwnerId,
        'adminIds': ChatArrayOp.union([newOwnerId]),
        'updatedAt': chatServerTimestamp,
      });
    } catch (e) {
      developer.log('Firestore transferGroupOwner warning: $e', name: 'AgoraChatService');
    }

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final currentUid = _authService.getCurrentUserId() ?? '';

    try {
      await ChatClient.getInstance.groupManager.leaveGroup(groupId);
    } catch (_) {}

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

    try {
      await _chatRepository.updateChat(groupId, {
        'participantIds': ChatArrayOp.remove([currentUid]),
        'adminIds': ChatArrayOp.remove([currentUid]),
        'updatedAt': chatServerTimestamp,
      });
    } catch (e) {
      developer.log('Firestore leaveGroup warning: $e', name: 'AgoraChatService');
    }

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

    try {
      await ChatClient.getInstance.groupManager.destroyGroup(groupId);
    } catch (_) {}

    try {
      await _chatRepository.deleteChat(groupId);
    } catch (e) {
      developer.log('Firestore destroyGroup warning: $e', name: 'AgoraChatService');
    }

    await deleteConversation(groupId);
    await _syncConversationsFromLocal();
  }

  @override
  Future<void> dispose() async {
    await logout();
    await _conversationsController.close();
    for (final c in _messagesControllers.values) {
      await c.close();
    }
    _messagesControllers.clear();
  }
}
