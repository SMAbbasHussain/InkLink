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
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../models/chat/chat_share_payload.dart';
import 'chat_service.dart';

class AgoraChatServiceImpl implements ChatService {
  final LocalDatabaseService _localDbService;
  final AuthService _authService;
  final CloudFunctionsService? _cloudFunctionsService;

  bool _initialized = false;

  final StreamController<List<ChatConversationModel>> _conversationsController =
      StreamController<List<ChatConversationModel>>.broadcast();
  final Map<String, StreamController<List<ChatMessageModel>>> _messagesControllers = {};

  AgoraChatServiceImpl({
    required LocalDatabaseService localDbService,
    required AuthService authService,
    CloudFunctionsService? cloudFunctionsService,
  })  : _localDbService = localDbService,
        _authService = authService,
        _cloudFunctionsService = cloudFunctionsService;

  String _sanitizeAgoraUid(String uid) {
    // Agora Chat usernames accept [a-zA-Z0-9_-]+
    return uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
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

      // Register listener for incoming Agora Chat messages
      ChatClient.getInstance.chatManager.addEventHandler(
        'inklink_chat_handler',
        ChatEventHandler(
          onMessagesReceived: (List<ChatMessage> messages) async {
            for (final msg in messages) {
              await _handleIncomingAgoraMessage(msg);
            }
          },
          onMessageReactionDidChange: (List<ChatMessageReactionEvent> list) async {
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
    try {
      final isLoggedIn = await ChatClient.getInstance.isLoginBefore();
      if (!isLoggedIn) {
        // Attempt login with token if available or fallback
        final token = dotenv.env['AGORA_CHAT_TOKEN'] ?? agoraUsername;
        await ChatClient.getInstance.loginWithAgoraToken(agoraUsername, token);
      }
      developer.log('Logged into Agora Chat as: $agoraUsername', name: 'AgoraChatService');
    } catch (e) {
      developer.log('Agora Chat login notice (operating in local-first mode): $e', name: 'AgoraChatService');
    }

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> logout() async {
    try {
      await ChatClient.getInstance.logout(true);
    } catch (_) {}
  }

  Future<void> _handleIncomingAgoraMessage(ChatMessage msg) async {
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
      );

      await _persistMessageLocally(model, isGroup: isGroup);
    } catch (e) {
      developer.log('Error handling incoming Agora message: $e', name: 'AgoraChatService');
    }
  }

  Future<void> _persistMessageLocally(
    ChatMessageModel model, {
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
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
        conv.name = model.senderName;
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
      if (model.senderId != currentUid) {
        conv.unreadCount = conv.unreadCount + 1;
      }

      await isar.localChatConversations.put(conv);
    });

    await _syncConversationsFromLocal();
    _notifyThreadUpdated(model.conversationId);
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
    final locals = await isar.localChatConversations
        .where()
        .sortByUpdatedAtDesc()
        .findAll();

    return locals.map((c) {
      return ChatConversationModel(
        id: c.conversationId,
        name: c.name,
        avatarUrl: c.avatarUrl,
        isGroup: c.isGroup,
        lastMessage: c.lastMessage,
        lastMessageTimestamp: c.lastMessageTimestamp,
        unreadCount: c.unreadCount,
        isMuted: c.isMuted,
        memberIds: List.from(c.memberIds),
        adminIds: List.from(c.adminIds),
        ownerId: c.ownerId,
        description: c.description,
      );
    }).toList();
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
    final locals = await isar.localChatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByTimestamp()
        .findAll();

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
    );

    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    // Agora Chat SDK Send
    try {
      final agoraMsg = ChatMessage.createTxtSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        content: text,
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      agoraMsg.attributes = {
        'senderName': currentName,
        'senderAvatar': currentAvatar ?? '',
      };
      await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
      await _updateMessageStatus(messageId, ChatMessageStatus.sent);
    } catch (e) {
      developer.log('Agora send text notice: $e', name: 'AgoraChatService');
      await _updateMessageStatus(messageId, ChatMessageStatus.sent);
    }

    if (!isGroup) {
      _dispatchPushNotification(
        recipientUid: conversationId,
        title: currentName,
        body: text,
        conversationId: conversationId,
      );
    }

    return model;
  }

  @override
  Future<ChatMessageModel> sendImageMessage({
    required String conversationId,
    required String filePath,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
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
    );

    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

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
      };
      await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
      await _updateMessageStatus(messageId, ChatMessageStatus.sent);
    } catch (_) {
      await _updateMessageStatus(messageId, ChatMessageStatus.sent);
    }

    if (!isGroup) {
      _dispatchPushNotification(
        recipientUid: conversationId,
        title: currentName,
        body: '📷 Sent an image',
        conversationId: conversationId,
      );
    }

    return model;
  }

  @override
  Future<ChatMessageModel> sendGifMessage({
    required String conversationId,
    required String gifUrl,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
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
      status: ChatMessageStatus.sent,
    );

    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    try {
      final agoraMsg = ChatMessage.createCustomSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        event: 'gif',
        params: {'payload': gifUrl},
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
    } catch (_) {}

    if (!isGroup) {
      _dispatchPushNotification(
        recipientUid: conversationId,
        title: currentName,
        body: '🎬 Sent a GIF',
        conversationId: conversationId,
      );
    }

    return model;
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
      status: ChatMessageStatus.sent,
      fileName: fileName,
      fileSize: fileSize,
    );

    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    try {
      final agoraMsg = ChatMessage.createFileSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        filePath: filePath,
        displayName: fileName,
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
    } catch (_) {}

    if (!isGroup) {
      _dispatchPushNotification(
        recipientUid: conversationId,
        title: currentName,
        body: '📎 Sent a file: $fileName',
        conversationId: conversationId,
      );
    }

    return model;
  }

  @override
  Future<ChatMessageModel> sendShareCardMessage({
    required String conversationId,
    required ChatSharePayload payload,
    bool isGroup = false,
    String? conversationName,
    String? conversationAvatar,
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
      status: ChatMessageStatus.sent,
      sharePayload: payload,
    );

    await _persistMessageLocally(
      model,
      isGroup: isGroup,
      conversationName: conversationName,
      conversationAvatar: conversationAvatar,
    );

    try {
      final agoraMsg = ChatMessage.createCustomSendMessage(
        targetId: _sanitizeAgoraUid(conversationId),
        event: isBoard ? 'board_share' : 'workspace_share',
        params: {'payload': payload.toJsonString()},
        chatType: isGroup ? ChatType.GroupChat : ChatType.Chat,
      );
      await ChatClient.getInstance.chatManager.sendMessage(agoraMsg);
    } catch (_) {}

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

    return model;
  }

  Future<void> _updateMessageStatus(String messageId, ChatMessageStatus status) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        msg.status = status.name;
        await isar.localChatMessages.put(msg);
      }
    });
  }

  @override
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'me';
    final isar = await _localDbService.database;

    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        Map<String, List<String>> reactions = {};
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

        final users = reactions[emoji] ?? [];
        if (!users.contains(currentUid)) {
          users.add(currentUid);
          reactions[emoji] = users;
        }

        msg.reactionsJson = jsonEncode(reactions);
        await isar.localChatMessages.put(msg);
      }
    });

    try {
      await ChatClient.getInstance.chatManager.addReaction(
        messageId: messageId,
        reaction: emoji,
      );
    } catch (_) {}

    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final currentUid = _authService.getCurrentUserId() ?? 'me';
    final isar = await _localDbService.database;

    await isar.writeTxn(() async {
      final msg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      if (msg != null) {
        Map<String, List<String>> reactions = {};
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

    try {
      await ChatClient.getInstance.chatManager.removeReaction(
        messageId: messageId,
        reaction: emoji,
      );
    } catch (_) {}

    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
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

    try {
      await ChatClient.getInstance.chatManager.modifyMessage(
        messageId: messageId,
        msgBody: ChatTextMessageBody(content: newContent),
      );
    } catch (_) {}

    _notifyThreadUpdated(conversationId);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
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

    try {
      final conv = await ChatClient.getInstance.chatManager.getConversation(conversationId);
      await conv?.deleteMessage(messageId);
    } catch (_) {}

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
    final groupId = 'group_${const Uuid().v4().substring(0, 8)}';
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
      final options = ChatGroupOptions(
        style: ChatGroupStyle.PublicJoinNeedApproval,
        maxCount: 200,
      );
      await ChatClient.getInstance.groupManager.createGroup(
        groupName: name,
        desc: description,
        options: options,
        inviteMembers: memberIds.map(_sanitizeAgoraUid).toList(),
      );
    } catch (e) {
      developer.log('Agora create group notice: $e', name: 'AgoraChatService');
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
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        if (name != null && name.isNotEmpty) group.name = name;
        if (description != null) group.description = description;
        if (iconUrl != null) group.avatarUrl = iconUrl;
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    try {
      if (name != null) {
        await ChatClient.getInstance.groupManager.changeGroupName(groupId, name);
      }
      if (description != null) {
        await ChatClient.getInstance.groupManager.changeGroupDescription(groupId, description);
      }
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> addGroupMembers({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        final currentMembers = Set<String>.from(group.memberIds);
        currentMembers.addAll(memberIds);
        group.memberIds = currentMembers.toList();
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    try {
      await ChatClient.getInstance.groupManager.addMembers(
        groupId,
        memberIds.map(_sanitizeAgoraUid).toList(),
      );
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String memberId,
  }) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        final currentMembers = List<String>.from(group.memberIds);
        currentMembers.remove(memberId);
        final currentAdmins = List<String>.from(group.adminIds);
        currentAdmins.remove(memberId);
        group.memberIds = currentMembers;
        group.adminIds = currentAdmins;
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    try {
      await ChatClient.getInstance.groupManager.removeMembers(
        groupId,
        [_sanitizeAgoraUid(memberId)],
      );
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> promoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        final currentAdmins = Set<String>.from(group.adminIds);
        currentAdmins.add(memberId);
        group.adminIds = currentAdmins.toList();
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    try {
      await ChatClient.getInstance.groupManager.addAdmin(
        groupId,
        _sanitizeAgoraUid(memberId),
      );
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> demoteAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        final currentAdmins = List<String>.from(group.adminIds);
        currentAdmins.remove(memberId);
        group.adminIds = currentAdmins;
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    try {
      await ChatClient.getInstance.groupManager.removeAdmin(
        groupId,
        _sanitizeAgoraUid(memberId),
      );
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> transferGroupOwner({
    required String groupId,
    required String newOwnerId,
  }) async {
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final group = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(groupId)
          .findFirst();
      if (group != null) {
        group.ownerId = newOwnerId;
        final currentAdmins = Set<String>.from(group.adminIds);
        currentAdmins.add(newOwnerId);
        group.adminIds = currentAdmins.toList();
        group.updatedAt = DateTime.now();
        await isar.localChatConversations.put(group);
      }
    });

    try {
      await ChatClient.getInstance.groupManager.changeOwner(
        groupId,
        _sanitizeAgoraUid(newOwnerId),
      );
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final currentUid = _authService.getCurrentUserId() ?? '';
    await removeGroupMember(groupId: groupId, memberId: currentUid);

    try {
      await ChatClient.getInstance.groupManager.leaveGroup(groupId);
    } catch (_) {}

    await _syncConversationsFromLocal();
  }

  @override
  Future<void> destroyGroup(String groupId) async {
    await deleteConversation(groupId);

    try {
      await ChatClient.getInstance.groupManager.destroyGroup(groupId);
    } catch (_) {}

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
