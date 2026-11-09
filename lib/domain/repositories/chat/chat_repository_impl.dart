import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../core/database/collections/local_chat_conversation.dart';
import '../../../core/database/collections/local_chat_message.dart';
import '../../../core/database/collections/local_profile.dart';
import '../../../core/database/local_database_service.dart';
import '../../models/chat/chat_conversation_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../models/chat/chat_share_payload.dart';
import 'chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final LocalDatabaseService _localDbService;

  ChatRepositoryImpl({required LocalDatabaseService localDatabaseService})
      : _localDbService = localDatabaseService;

  /// Mirrors Agora username normalization exclusively for SDK -> UID boundary
  /// lookups; never used to equate two Firebase UIDs.
  static String sanitizeAgoraUsername(String uid) {
    return uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
  }

  /// Bijective length-prefixed storage keys scoping Isar records by exact
  /// signed-in Firebase UID and exact peer/group/message ID.
  static String dmKey(String ownerUid, String peerUid) =>
      'dm:${ownerUid.length}:$ownerUid:$peerUid';

  static String groupKey(String ownerUid, String groupId) =>
      'grp:${ownerUid.length}:$ownerUid:$groupId';

  static String msgKey(String ownerUid, String messageId) =>
      'msg:${ownerUid.length}:$ownerUid:$messageId';

  static ({String ownerUid, String targetId})? _parseScopedKey(
    String raw,
    String prefix,
  ) {
    final head = '$prefix:';
    if (!raw.startsWith(head)) return null;
    final lenEnd = raw.indexOf(':', head.length);
    if (lenEnd <= head.length) return null;
    final ownerLen = int.tryParse(raw.substring(head.length, lenEnd));
    if (ownerLen == null || ownerLen < 0) return null;
    final sepIndex = lenEnd + 1 + ownerLen;
    if (raw.length <= sepIndex || raw[sepIndex] != ':') return null;
    final ownerUid = raw.substring(lenEnd + 1, sepIndex);
    final targetId = raw.substring(sepIndex + 1);
    return (ownerUid: ownerUid, targetId: targetId);
  }

  static ({String? ownerUid, String targetId, bool isGroup, bool isScoped})
      _unwrapConvKey(LocalChatConversation conv) {
    final dm = _parseScopedKey(conv.conversationId, 'dm');
    if (dm != null) {
      return (
        ownerUid: dm.ownerUid,
        targetId: dm.targetId,
        isGroup: false,
        isScoped: true,
      );
    }
    final grp = _parseScopedKey(conv.conversationId, 'grp');
    if (grp != null) {
      return (
        ownerUid: grp.ownerUid,
        targetId: grp.targetId,
        isGroup: true,
        isScoped: true,
      );
    }
    return (
      ownerUid: null,
      targetId: conv.conversationId,
      isGroup: conv.isGroup,
      isScoped: false,
    );
  }

  static ({String? ownerUid, String targetId, bool isGroup, bool isScoped})
      _unwrapConvIdString(String rawConversationId, {bool fallbackIsGroup = false}) {
    final dm = _parseScopedKey(rawConversationId, 'dm');
    if (dm != null) {
      return (
        ownerUid: dm.ownerUid,
        targetId: dm.targetId,
        isGroup: false,
        isScoped: true,
      );
    }
    final grp = _parseScopedKey(rawConversationId, 'grp');
    if (grp != null) {
      return (
        ownerUid: grp.ownerUid,
        targetId: grp.targetId,
        isGroup: true,
        isScoped: true,
      );
    }
    return (
      ownerUid: null,
      targetId: rawConversationId,
      isGroup: fallbackIsGroup,
      isScoped: false,
    );
  }

  static ({String? ownerUid, String messageId, bool isScoped}) _unwrapMsgKey(
    String rawMessageId,
  ) {
    final parsed = _parseScopedKey(rawMessageId, 'msg');
    if (parsed != null) {
      return (
        ownerUid: parsed.ownerUid,
        messageId: parsed.targetId,
        isScoped: true,
      );
    }
    return (ownerUid: null, messageId: rawMessageId, isScoped: false);
  }

  static bool _isGroupMemberAuthorized(
    LocalChatConversation conv,
    String currentUid,
  ) {
    if (currentUid.isEmpty) return false;
    return conv.ownerId == currentUid ||
        conv.adminIds.contains(currentUid) ||
        conv.memberIds.contains(currentUid);
  }

  static bool _isConversationAuthorizedForUser(
    LocalChatConversation conv,
    String currentUid,
  ) {
    if (currentUid.isEmpty) return false;
    final unwrapped = _unwrapConvKey(conv);
    if (unwrapped.targetId.isEmpty) return false;

    if (unwrapped.isScoped) {
      if (unwrapped.ownerUid != currentUid) return false;
      if (!unwrapped.isGroup) {
        if (unwrapped.targetId == currentUid) return false;
        if (conv.memberIds.isNotEmpty && !conv.memberIds.contains(currentUid)) {
          return false;
        }
        return true;
      }
      return _isGroupMemberAuthorized(conv, currentUid);
    }

    // Legacy unscoped rows require strict, exact case-sensitive membership.
    if (!conv.isGroup) {
      if (conv.conversationId == currentUid) return false;
      return conv.memberIds.length == 2 &&
          conv.memberIds.contains(currentUid) &&
          conv.memberIds.contains(conv.conversationId);
    }
    return _isGroupMemberAuthorized(conv, currentUid);
  }

  Future<LocalChatConversation?> _findAuthorizedConversation(
    Isar isar, {
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return null;

    final scopedGroup = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(
          groupKey(currentUid, conversationId),
          caseSensitive: true,
        )
        .findFirst();
    if (scopedGroup != null) return scopedGroup;

    final scopedDm = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(
          dmKey(currentUid, conversationId),
          caseSensitive: true,
        )
        .findFirst();
    if (scopedDm != null) return scopedDm;

    final legacy = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(conversationId, caseSensitive: true)
        .findFirst();
    if (legacy != null && _isConversationAuthorizedForUser(legacy, currentUid)) {
      return legacy;
    }
    return null;
  }

  Future<LocalChatMessage?> _findAuthorizedMessageById(
    Isar isar, {
    required String currentUid,
    required String messageId,
  }) async {
    if (currentUid.isEmpty || messageId.isEmpty) return null;
    final scoped = await isar.localChatMessages
        .filter()
        .messageIdEqualTo(msgKey(currentUid, messageId), caseSensitive: true)
        .findFirst();
    if (scoped != null) return scoped;

    final legacy = await isar.localChatMessages
        .filter()
        .messageIdEqualTo(messageId, caseSensitive: true)
        .findFirst();
    if (legacy != null) {
      final msgUnwrapped = _unwrapMsgKey(legacy.messageId);
      final convUnwrapped = _unwrapConvIdString(legacy.conversationId);
      if (!msgUnwrapped.isScoped && !convUnwrapped.isScoped) {
        if (legacy.senderId == currentUid ||
            legacy.conversationId == currentUid) {
          return legacy;
        }
        final legacyConv = await _findAuthorizedConversation(
          isar,
          currentUid: currentUid,
          conversationId: legacy.conversationId,
        );
        if (legacyConv != null) return legacy;
      }
    }
    return null;
  }

  @override
  Future<void> ensureDmConversationExists({
    required String currentUid,
    required String peerUid,
    String? name,
    String? avatarUrl,
    DateTime? activityTimestamp,
  }) async {
    if (currentUid.isEmpty || peerUid.isEmpty || peerUid == currentUid) return;

    final isar = await _localDbService.database;
    final key = dmKey(currentUid, peerUid);
    final existing = await isar.localChatConversations
        .filter()
        .conversationIdEqualTo(key, caseSensitive: true)
        .findFirst();

    String? profileName = name;
    String? profileAvatar = avatarUrl;
    if ((profileName == null || profileName.isEmpty) ||
        (profileAvatar == null || profileAvatar.isEmpty)) {
      final profile = await isar.localProfiles
          .filter()
          .uidEqualTo(peerUid, caseSensitive: true)
          .findFirst();
      if (profile != null) {
        if ((profileName == null || profileName.isEmpty) &&
            profile.displayName.isNotEmpty) {
          profileName = profile.displayName;
        }
        if ((profileAvatar == null || profileAvatar.isEmpty) &&
            profile.photoURL != null &&
            profile.photoURL!.isNotEmpty) {
          profileAvatar = profile.photoURL;
        }
      }
    }

    await isar.writeTxn(() async {
      final conv = existing ?? LocalChatConversation();
      conv
        ..conversationId = key
        ..name = (existing != null &&
                existing.name.isNotEmpty &&
                existing.name != 'User')
            ? existing.name
            : (profileName != null && profileName.isNotEmpty
                ? profileName
                : 'User')
        ..avatarUrl = existing?.avatarUrl ?? profileAvatar
        ..isGroup = false
        ..lastMessage = existing?.lastMessage
        ..lastMessageTimestamp =
            existing?.lastMessageTimestamp ?? activityTimestamp
        ..updatedAt = existing?.updatedAt ?? activityTimestamp
        ..unreadCount = existing?.unreadCount ?? 0
        ..isMuted = existing?.isMuted ?? false
        ..memberIds = [currentUid, peerUid];

      await isar.localChatConversations.put(conv);
    });
  }

  @override
  Future<void> ingestGroups({
    required String currentUid,
    required List<SyncedGroupInfo> groups,
    bool pruneMissingServerGroups = false,
  }) async {
    if (currentUid.isEmpty) return;
    if (groups.isEmpty && !pruneMissingServerGroups) return;

    final isar = await _localDbService.database;
    final syncedGroupIds = groups.map((g) => g.groupId).toSet();

    await isar.writeTxn(() async {
      for (final g in groups) {
        if (g.groupId.isEmpty) continue;
        final key = groupKey(currentUid, g.groupId);
        var existing = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(key, caseSensitive: true)
            .findFirst();

        LocalChatConversation? legacyToRemove;
        if (existing == null) {
          final legacy = await isar.localChatConversations
              .filter()
              .conversationIdEqualTo(g.groupId, caseSensitive: true)
              .findFirst();
          if (legacy != null &&
              !_unwrapConvKey(legacy).isScoped &&
              legacy.isGroup) {
            existing = LocalChatConversation()
              ..lastMessage = legacy.lastMessage
              ..lastMessageTimestamp = legacy.lastMessageTimestamp
              ..updatedAt = legacy.updatedAt
              ..unreadCount = legacy.unreadCount
              ..isMuted = legacy.isMuted
              ..name = legacy.name
              ..avatarUrl = legacy.avatarUrl
              ..description = legacy.description
              ..ownerId = legacy.ownerId
              ..adminIds = List<String>.from(legacy.adminIds)
              ..memberIds = List<String>.from(legacy.memberIds);
            legacyToRemove = legacy;
          }
        }

        final conv = existing ?? LocalChatConversation();
        conv
          ..conversationId = key
          ..isGroup = true
          ..lastMessage = existing?.lastMessage
          ..lastMessageTimestamp =
              existing?.lastMessageTimestamp ?? g.activityTimestamp
          ..updatedAt = existing?.updatedAt ?? g.activityTimestamp
          ..unreadCount = existing?.unreadCount ?? 0
          ..isMuted = existing?.isMuted ?? false;

        if (g.name != null && g.name!.isNotEmpty) {
          conv.name = g.name!;
        } else if (conv.name.isEmpty) {
          conv.name = 'Group Chat';
        }
        if (g.avatarUrl != null && g.avatarUrl!.isNotEmpty) {
          conv.avatarUrl = g.avatarUrl;
        }
        if (g.description != null) {
          conv.description = g.description;
        }
        if (g.ownerId != null && g.ownerId!.isNotEmpty) {
          conv.ownerId = g.ownerId;
        }

        // Replace cached admin list rather than falling back to stale admins
        // when the refreshed admin list is empty.
        if (g.adminsProvided) {
          conv.adminIds =
              g.adminIds.where((id) => id.isNotEmpty).toSet().toList();
        }

        // Replace cached member list with authoritative server roster instead
        // of unioning with `existing.memberIds`.
        if (g.membersProvided) {
          final memberSet = <String>{
            ...g.memberIds.where((id) => id.isNotEmpty),
            ...conv.adminIds,
            if (conv.ownerId != null && conv.ownerId!.isNotEmpty) conv.ownerId!,
            if (g.includeCurrentUser) currentUid,
          };
          conv.memberIds = memberSet.toList();
        } else {
          final memberSet = <String>{
            ...conv.memberIds.where((id) => id.isNotEmpty),
            ...conv.adminIds,
            if (conv.ownerId != null && conv.ownerId!.isNotEmpty) conv.ownerId!,
            if (g.includeCurrentUser) currentUid,
          };
          conv.memberIds = memberSet.toList();
        }

        if (legacyToRemove?.id != null) {
          await isar.localChatConversations.delete(legacyToRemove!.id!);
        }
        await isar.localChatConversations.put(conv);
      }

      if (pruneMissingServerGroups) {
        final allGroupRows = await isar.localChatConversations
            .filter()
            .isGroupEqualTo(true)
            .findAll();
        for (final row in allGroupRows) {
          final unwrapped = _unwrapConvKey(row);
          if (unwrapped.isScoped && unwrapped.ownerUid != currentUid) continue;
          if (!unwrapped.isScoped &&
              !_isGroupMemberAuthorized(row, currentUid)) {
            continue;
          }
          // Preserve locally created offline-only groups (`group_<uuid>`)
          if (unwrapped.targetId.startsWith('group_')) continue;
          if (!syncedGroupIds.contains(unwrapped.targetId) && row.id != null) {
            await isar.localChatConversations.delete(row.id!);
          }
        }
      }
    });
  }

  @override
  Future<List<ChatConversationModel>> getConversations({
    required String currentUid,
    bool Function(String peerUid)? isOnlineResolver,
  }) async {
    if (currentUid.isEmpty) return const [];
    final isar = await _localDbService.database;

    // Auto-repair legacy incoming DM messages addressed to exact `currentUid`
    final legacyIncoming = await isar.localChatMessages
        .filter()
        .conversationIdEqualTo(currentUid, caseSensitive: true)
        .and()
        .not()
        .senderIdEqualTo(currentUid, caseSensitive: true)
        .findAll();

    if (legacyIncoming.isNotEmpty) {
      // Group strictly by exact Firebase UID `senderId`, never by sanitized ID.
      final latestBySender = <String, LocalChatMessage>{};
      for (final m in legacyIncoming) {
        if (m.senderId.isEmpty) continue;
        final prev = latestBySender[m.senderId];
        if (prev == null || m.timestamp.isAfter(prev.timestamp)) {
          latestBySender[m.senderId] = m;
        }
      }

      for (final entry in latestBySender.entries) {
        final senderUid = entry.key;
        final latestMsg = entry.value;
        final scopedKey = dmKey(currentUid, senderUid);
        final existingPartnerConv = await isar.localChatConversations
            .filter()
            .conversationIdEqualTo(scopedKey, caseSensitive: true)
            .findFirst();

        if (existingPartnerConv == null) {
          final conv = LocalChatConversation()
            ..conversationId = scopedKey
            ..name =
                latestMsg.senderName.isNotEmpty ? latestMsg.senderName : 'User'
            ..avatarUrl = latestMsg.senderAvatar
            ..isGroup = false
            ..lastMessage = latestMsg.type == 'text'
                ? latestMsg.content
                : '[${latestMsg.type}]'
            ..lastMessageTimestamp = latestMsg.timestamp
            ..unreadCount = 1
            ..memberIds = [currentUid, senderUid]
            ..updatedAt = latestMsg.timestamp;

          await isar.writeTxn(() async {
            await isar.localChatConversations.put(conv);
          });
        } else {
          final isNewer = existingPartnerConv.lastMessageTimestamp == null ||
              latestMsg.timestamp
                  .isAfter(existingPartnerConv.lastMessageTimestamp!);
          if (isNewer) {
            await isar.writeTxn(() async {
              existingPartnerConv
                ..memberIds = [currentUid, senderUid]
                ..lastMessage = latestMsg.type == 'text'
                    ? latestMsg.content
                    : '[${latestMsg.type}]'
                ..lastMessageTimestamp = latestMsg.timestamp
                ..updatedAt = latestMsg.timestamp;
              if ((existingPartnerConv.name.isEmpty ||
                      existingPartnerConv.name == 'User') &&
                  latestMsg.senderName.isNotEmpty) {
                existingPartnerConv.name = latestMsg.senderName;
              }
              existingPartnerConv.avatarUrl ??= latestMsg.senderAvatar;
              await isar.localChatConversations.put(existingPartnerConv);
            });
          }
        }
      }
    }

    final locals = await isar.localChatConversations.where().findAll();
    final authorized = <LocalChatConversation>[];
    for (final c in locals) {
      if (_isConversationAuthorizedForUser(c, currentUid)) {
        authorized.add(c);
      }
    }

    // Sort active conversations descending by `updatedAt`; keep empty
    // conversations (`updatedAt == null`) at the bottom.
    authorized.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;
      if (aTime != null && bTime != null) {
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }
      // Prefer scoped row over legacy unscoped row if both exist
      final aScoped = _unwrapConvKey(a).isScoped;
      final bScoped = _unwrapConvKey(b).isScoped;
      if (aScoped != bScoped) return aScoped ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    final results = <ChatConversationModel>[];
    final seenConvKeys = <String>{};

    for (final c in authorized) {
      final unwrapped = _unwrapConvKey(c);
      final targetId = unwrapped.targetId;
      if (targetId.isEmpty) continue;
      if (!unwrapped.isGroup && targetId == currentUid) continue;

      // Deduplicate strictly by exact conversation type + exact ID (never by
      // sanitized Agora username).
      final dedupKey = unwrapped.isGroup ? 'grp:$targetId' : 'dm:$targetId';
      if (!seenConvKeys.add(dedupKey)) continue;

      String resolvedName = c.name;
      String? resolvedAvatar = c.avatarUrl;

      if (!unwrapped.isGroup) {
        final profile = await isar.localProfiles
            .filter()
            .uidEqualTo(targetId, caseSensitive: true)
            .findFirst();
        if (profile != null) {
          if ((resolvedName.isEmpty ||
                  resolvedName == 'User' ||
                  resolvedName == targetId) &&
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
            resolvedName == targetId ||
            resolvedAvatar == null ||
            resolvedAvatar.isEmpty) {
          final scopedPartnerMsg = await isar.localChatMessages
              .filter()
              .conversationIdEqualTo(
                dmKey(currentUid, targetId),
                caseSensitive: true,
              )
              .and()
              .senderIdEqualTo(targetId, caseSensitive: true)
              .findFirst();
          if (scopedPartnerMsg != null &&
              scopedPartnerMsg.senderName.isNotEmpty) {
            resolvedName = scopedPartnerMsg.senderName;
            resolvedAvatar ??= scopedPartnerMsg.senderAvatar;
          }
        }
      }

      final isOnline =
          !unwrapped.isGroup && (isOnlineResolver?.call(targetId) ?? false);

      results.add(
        ChatConversationModel(
          id: targetId,
          name: resolvedName.isNotEmpty
              ? resolvedName
              : (unwrapped.isGroup ? 'Group Chat' : 'User'),
          avatarUrl: resolvedAvatar,
          isGroup: unwrapped.isGroup,
          lastMessage: c.lastMessage,
          lastMessageTimestamp: c.lastMessageTimestamp,
          unreadCount: c.unreadCount,
          isOnline: isOnline,
          isMuted: c.isMuted,
          memberIds: List<String>.from(c.memberIds),
          adminIds: List<String>.from(c.adminIds),
          ownerId: c.ownerId,
          description: c.description,
        ),
      );
    }

    return results;
  }

  bool _verifyThreadMessageAuthorization(
    LocalChatMessage row, {
    required String currentUid,
    required String conversationId,
    required bool isGroup,
    required bool hasAuthorizedLegacyConv,
  }) {
    if (currentUid.isEmpty || conversationId.isEmpty) return false;
    final msgUnwrapped = _unwrapMsgKey(row.messageId);
    if (msgUnwrapped.isScoped && msgUnwrapped.ownerUid != currentUid) {
      return false;
    }

    final convUnwrapped =
        _unwrapConvIdString(row.conversationId, fallbackIsGroup: isGroup);
    if (convUnwrapped.isScoped) {
      if (convUnwrapped.ownerUid != currentUid) return false;
      if (convUnwrapped.isGroup != isGroup) return false;
      if (convUnwrapped.targetId != conversationId) return false;
      if (!isGroup) {
        return row.senderId == currentUid || row.senderId == conversationId;
      }
      return true;
    }

    // Legacy unscoped rows: verify exact case-sensitive ownership.
    if (isGroup) {
      return hasAuthorizedLegacyConv && row.conversationId == conversationId;
    }
    if (row.senderId == currentUid && row.conversationId == conversationId) {
      return true;
    }
    if (row.senderId == conversationId && row.conversationId == currentUid) {
      return true;
    }
    if (hasAuthorizedLegacyConv &&
        row.senderId == conversationId &&
        row.conversationId == conversationId) {
      return true;
    }
    return false;
  }

  @override
  Future<List<ChatMessageModel>> getMessagesForThread({
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return const [];
    final isar = await _localDbService.database;

    final authConv = await _findAuthorizedConversation(
      isar,
      currentUid: currentUid,
      conversationId: conversationId,
    );
    final isGroup = authConv != null
        ? _unwrapConvKey(authConv).isGroup
        : conversationId.startsWith('group_');

    if (!isGroup && conversationId == currentUid) {
      return const [];
    }
    if (isGroup &&
        authConv != null &&
        !_isGroupMemberAuthorized(authConv, currentUid)) {
      return const [];
    }

    final scopedKey = isGroup
        ? groupKey(currentUid, conversationId)
        : dmKey(currentUid, conversationId);

    final scopedRows = await isar.localChatMessages
        .filter()
        .conversationIdEqualTo(scopedKey, caseSensitive: true)
        .sortByTimestamp()
        .findAll();

    final hasAuthorizedLegacyConv = authConv != null &&
        !_unwrapConvKey(authConv).isScoped &&
        _isConversationAuthorizedForUser(authConv, currentUid);

    final legacyRows = await isar.localChatMessages
        .filter()
        .conversationIdEqualTo(conversationId, caseSensitive: true)
        .or()
        .group((q) => q
            .conversationIdEqualTo(currentUid, caseSensitive: true)
            .and()
            .senderIdEqualTo(conversationId, caseSensitive: true))
        .sortByTimestamp()
        .findAll();

    final byMessageId = <String, LocalChatMessage>{};
    for (final row in [...legacyRows, ...scopedRows]) {
      if (!_verifyThreadMessageAuthorization(
        row,
        currentUid: currentUid,
        conversationId: conversationId,
        isGroup: isGroup,
        hasAuthorizedLegacyConv: hasAuthorizedLegacyConv,
      )) {
        continue;
      }
      final unwrappedMsg = _unwrapMsgKey(row.messageId);
      // Scoped rows come second and supersede any legacy duplicate.
      byMessageId[unwrappedMsg.messageId] = row;
    }

    final ordered = byMessageId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return ordered
        .map((m) => _mapLocalMessage(m, targetConversationId: conversationId))
        .toList();
  }

  ChatMessageModel _mapLocalMessage(
    LocalChatMessage m, {
    required String targetConversationId,
  }) {
    final parsedReactions = <String, List<String>>{};
    if (m.reactionsJson != null && m.reactionsJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(m.reactionsJson!);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is List) {
              parsedReactions[k.toString()] =
                  v.map((e) => e.toString()).toList();
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
      id: _unwrapMsgKey(m.messageId).messageId,
      conversationId: targetConversationId,
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
    if (currentUid.isEmpty || model.conversationId.isEmpty) return;
    if (!isGroup && model.conversationId == currentUid) return;

    final isar = await _localDbService.database;
    final scopedMsgId = msgKey(currentUid, model.id);
    final scopedConvId = isGroup
        ? groupKey(currentUid, model.conversationId)
        : dmKey(currentUid, model.conversationId);

    await isar.writeTxn(() async {
      final existingMsg = await isar.localChatMessages
          .filter()
          .messageIdEqualTo(scopedMsgId, caseSensitive: true)
          .findFirst();

      final localMsg = existingMsg ?? LocalChatMessage();
      localMsg
        ..messageId = scopedMsgId
        ..conversationId = scopedConvId
        ..senderId = model.senderId
        ..senderName = model.senderName
        ..senderAvatar = model.senderAvatar
        ..type = model.type.asString
        ..content = model.content
        ..timestamp = model.timestamp
        ..status = model.status.name
        ..reactionsJson = jsonEncode(model.reactions)
        ..isEdited = model.isEdited
        ..isDeleted = model.isDeleted
        ..fileName = model.fileName
        ..fileSize = model.fileSize
        ..sharePayloadJson = model.sharePayload?.toJsonString()
        ..replyToId = model.replyToId
        ..replyToSender = model.replyToSender
        ..replyToText = model.replyToText;

      await isar.localChatMessages.put(localMsg);

      final existingConv = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(scopedConvId, caseSensitive: true)
          .findFirst();

      final conv = existingConv ?? LocalChatConversation();
      conv.conversationId = scopedConvId;

      final isFromSelf = model.senderId == currentUid;

      if (conversationName != null && conversationName.isNotEmpty) {
        conv.name = conversationName;
      } else if (isGroup) {
        if (conv.name.isEmpty) conv.name = 'Group Chat';
      } else if (!isFromSelf &&
          model.senderName.isNotEmpty &&
          (conv.name.isEmpty ||
              conv.name == 'User' ||
              conv.name == model.conversationId)) {
        conv.name = model.senderName;
      } else if (conv.name.isEmpty) {
        conv.name = 'User';
      }

      if (conversationAvatar != null && conversationAvatar.isNotEmpty) {
        conv.avatarUrl = conversationAvatar;
      } else if (!isGroup &&
          !isFromSelf &&
          model.senderAvatar != null &&
          model.senderAvatar!.isNotEmpty &&
          (conv.avatarUrl == null || conv.avatarUrl!.isEmpty)) {
        conv.avatarUrl = model.senderAvatar;
      }

      conv.isGroup = isGroup || conv.isGroup;

      final isNewerOrEqual = conv.lastMessageTimestamp == null ||
          !model.timestamp.isBefore(conv.lastMessageTimestamp!);
      if (isNewerOrEqual) {
        conv.lastMessage = model.type == ChatMessageType.text
            ? model.content
            : '[${model.type.name}]';
        conv.lastMessageTimestamp = model.timestamp;
        conv.updatedAt = countUnread ? DateTime.now() : model.timestamp;
      } else {
        conv.updatedAt ??= conv.lastMessageTimestamp ?? model.timestamp;
      }

      // Only increment unread count for genuinely new unread messages, not
      // repeated re-persistence of an already-stored message.
      if (countUnread && !isFromSelf && existingMsg == null) {
        conv.unreadCount = conv.unreadCount + 1;
      }

      if (!conv.isGroup) {
        conv.memberIds = [currentUid, model.conversationId];
      } else if (conv.memberIds.isEmpty) {
        conv.memberIds = <String>{
          currentUid,
          if (model.senderId.isNotEmpty) model.senderId,
        }.toList();
      }

      await isar.localChatConversations.put(conv);
    });
  }

  @override
  Future<String?> updateMessageStatus({
    required String currentUid,
    required String messageId,
    String? fallbackMessageId,
    required ChatMessageStatus status,
    String? conversationId,
  }) async {
    if (currentUid.isEmpty) return conversationId;
    final isar = await _localDbService.database;
    String? resolvedConvId = conversationId;

    await isar.writeTxn(() async {
      var msg = await _findAuthorizedMessageById(
        isar,
        currentUid: currentUid,
        messageId: messageId,
      );
      if (msg == null &&
          fallbackMessageId != null &&
          fallbackMessageId != messageId) {
        msg = await _findAuthorizedMessageById(
          isar,
          currentUid: currentUid,
          messageId: fallbackMessageId,
        );
      }

      if (msg != null) {
        msg.status = status.name;
        resolvedConvId ??= _unwrapConvIdString(msg.conversationId).targetId;
        await isar.localChatMessages.put(msg);
      } else if (status == ChatMessageStatus.read &&
          resolvedConvId != null &&
          resolvedConvId!.isNotEmpty) {
        final dmScoped = dmKey(currentUid, resolvedConvId!);
        final grpScoped = groupKey(currentUid, resolvedConvId!);
        final unreadMsgs = await isar.localChatMessages
            .filter()
            .group((q) => q
                .conversationIdEqualTo(dmScoped, caseSensitive: true)
                .or()
                .conversationIdEqualTo(grpScoped, caseSensitive: true))
            .and()
            .senderIdEqualTo(currentUid, caseSensitive: true)
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

    return resolvedConvId;
  }

  @override
  Future<void> markOutgoingMessagesAsRead({
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return;
    final isar = await _localDbService.database;
    final dmScoped = dmKey(currentUid, conversationId);
    final grpScoped = groupKey(currentUid, conversationId);

    await isar.writeTxn(() async {
      final sentMsgs = await isar.localChatMessages
          .filter()
          .group((q) => q
              .conversationIdEqualTo(dmScoped, caseSensitive: true)
              .or()
              .conversationIdEqualTo(grpScoped, caseSensitive: true))
          .and()
          .senderIdEqualTo(currentUid, caseSensitive: true)
          .and()
          .not()
          .statusEqualTo(ChatMessageStatus.read.name)
          .findAll();

      for (final msg in sentMsgs) {
        msg.status = ChatMessageStatus.read.name;
        await isar.localChatMessages.put(msg);
      }
    });
  }

  @override
  Future<void> markMessageRecalled({
    required String currentUid,
    required String messageId,
  }) async {
    if (currentUid.isEmpty || messageId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final msg = await _findAuthorizedMessageById(
        isar,
        currentUid: currentUid,
        messageId: messageId,
      );
      if (msg != null) {
        msg
          ..isDeleted = true
          ..content = 'This message was deleted';
        await isar.localChatMessages.put(msg);
      }
    });
  }

  @override
  Future<void> updateMessageContent({
    required String currentUid,
    required String messageId,
    required String newContent,
  }) async {
    if (currentUid.isEmpty || messageId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final msg = await _findAuthorizedMessageById(
        isar,
        currentUid: currentUid,
        messageId: messageId,
      );
      if (msg != null) {
        msg
          ..content = newContent
          ..isEdited = true;
        await isar.localChatMessages.put(msg);
      }
    });
  }

  @override
  Future<void> setMessageReactions({
    required String currentUid,
    required String messageId,
    required Map<String, List<String>> reactions,
  }) async {
    if (currentUid.isEmpty || messageId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final msg = await _findAuthorizedMessageById(
        isar,
        currentUid: currentUid,
        messageId: messageId,
      );
      if (msg != null) {
        msg.reactionsJson = jsonEncode(reactions);
        await isar.localChatMessages.put(msg);
      }
    });
  }

  @override
  Future<({String? conversationId, String? senderId})> addReactionLocally({
    required String currentUid,
    required String messageId,
    required String reactorUid,
    required String emoji,
  }) async {
    if (currentUid.isEmpty || messageId.isEmpty) {
      return (conversationId: null, senderId: null);
    }
    final isar = await _localDbService.database;
    String? targetConvId;
    String? targetSenderId;

    await isar.writeTxn(() async {
      final msg = await _findAuthorizedMessageById(
        isar,
        currentUid: currentUid,
        messageId: messageId,
      );
      if (msg != null) {
        targetConvId = _unwrapConvIdString(msg.conversationId).targetId;
        targetSenderId = msg.senderId;

        final reactions = <String, List<String>>{};
        if (msg.reactionsJson != null && msg.reactionsJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.reactionsJson!);
            if (decoded is Map) {
              decoded.forEach((k, v) {
                if (v is List) {
                  reactions[k.toString()] =
                      v.map((e) => e.toString()).toList();
                }
              });
            }
          } catch (_) {}
        }

        reactions.forEach((_, v) => v.remove(reactorUid));
        reactions.removeWhere((_, v) => v.isEmpty);

        final users = reactions[emoji] ?? <String>[];
        if (!users.contains(reactorUid)) {
          users.add(reactorUid);
          reactions[emoji] = users;
        }

        msg.reactionsJson = jsonEncode(reactions);
        await isar.localChatMessages.put(msg);
      }
    });

    return (conversationId: targetConvId, senderId: targetSenderId);
  }

  @override
  Future<({String? conversationId, String? senderId})> removeReactionLocally({
    required String currentUid,
    required String messageId,
    required String reactorUid,
    required String emoji,
  }) async {
    if (currentUid.isEmpty || messageId.isEmpty) {
      return (conversationId: null, senderId: null);
    }
    final isar = await _localDbService.database;
    String? targetConvId;
    String? targetSenderId;

    await isar.writeTxn(() async {
      final msg = await _findAuthorizedMessageById(
        isar,
        currentUid: currentUid,
        messageId: messageId,
      );
      if (msg != null) {
        targetConvId = _unwrapConvIdString(msg.conversationId).targetId;
        targetSenderId = msg.senderId;

        final reactions = <String, List<String>>{};
        if (msg.reactionsJson != null && msg.reactionsJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(msg.reactionsJson!);
            if (decoded is Map) {
              decoded.forEach((k, v) {
                if (v is List) {
                  reactions[k.toString()] =
                      v.map((e) => e.toString()).toList();
                }
              });
            }
          } catch (_) {}
        }

        final users = reactions[emoji];
        if (users != null) {
          users.remove(reactorUid);
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

    return (conversationId: targetConvId, senderId: targetSenderId);
  }

  @override
  Future<void> markConversationAsRead({
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final conv = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: conversationId,
      );
      if (conv != null) {
        conv.unreadCount = 0;
        await isar.localChatConversations.put(conv);
      }
    });
  }

  @override
  Future<void> deleteConversation({
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return;
    final isar = await _localDbService.database;
    final dmScoped = dmKey(currentUid, conversationId);
    final grpScoped = groupKey(currentUid, conversationId);

    await isar.writeTxn(() async {
      await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(dmScoped, caseSensitive: true)
          .or()
          .conversationIdEqualTo(grpScoped, caseSensitive: true)
          .deleteAll();

      final legacy = await isar.localChatConversations
          .filter()
          .conversationIdEqualTo(conversationId, caseSensitive: true)
          .findFirst();
      if (legacy != null &&
          legacy.id != null &&
          _isConversationAuthorizedForUser(legacy, currentUid)) {
        await isar.localChatConversations.delete(legacy.id!);
      }

      await isar.localChatMessages
          .filter()
          .conversationIdEqualTo(dmScoped, caseSensitive: true)
          .or()
          .conversationIdEqualTo(grpScoped, caseSensitive: true)
          .deleteAll();
    });
  }

  @override
  Future<void> toggleMuteConversation({
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final conv = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: conversationId,
      );
      if (conv != null) {
        conv.isMuted = !conv.isMuted;
        await isar.localChatConversations.put(conv);
      }
    });
  }

  @override
  Future<ChatConversationModel?> getConversation({
    required String currentUid,
    required String conversationId,
  }) async {
    if (currentUid.isEmpty || conversationId.isEmpty) return null;
    final isar = await _localDbService.database;
    final conv = await _findAuthorizedConversation(
      isar,
      currentUid: currentUid,
      conversationId: conversationId,
    );
    if (conv == null) return null;
    final unwrapped = _unwrapConvKey(conv);
    return ChatConversationModel(
      id: unwrapped.targetId,
      name: conv.name,
      avatarUrl: conv.avatarUrl,
      isGroup: unwrapped.isGroup,
      lastMessage: conv.lastMessage,
      lastMessageTimestamp: conv.lastMessageTimestamp,
      unreadCount: conv.unreadCount,
      isMuted: conv.isMuted,
      memberIds: List<String>.from(conv.memberIds),
      adminIds: List<String>.from(conv.adminIds),
      ownerId: conv.ownerId,
      description: conv.description,
    );
  }

  @override
  Future<bool> isGroupConversation({
    required String currentUid,
    required String conversationId,
  }) async {
    if (conversationId.isEmpty) return false;
    if (currentUid.isNotEmpty) {
      final isar = await _localDbService.database;
      final conv = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: conversationId,
      );
      if (conv != null) {
        return _unwrapConvKey(conv).isGroup;
      }
    }
    return conversationId.startsWith('group_');
  }

  @override
  Future<List<ChatMessageModel>> getQueuedOutgoingMessages({
    required String currentUid,
  }) async {
    if (currentUid.isEmpty) return const [];
    final isar = await _localDbService.database;
    final queued = await isar.localChatMessages
        .filter()
        .senderIdEqualTo(currentUid, caseSensitive: true)
        .group((q) => q
            .statusEqualTo(ChatMessageStatus.sending.name)
            .or()
            .statusEqualTo(ChatMessageStatus.failed.name))
        .sortByTimestamp()
        .findAll();

    final results = <ChatMessageModel>[];
    for (final row in queued) {
      final msgUnwrapped = _unwrapMsgKey(row.messageId);
      if (msgUnwrapped.isScoped && msgUnwrapped.ownerUid != currentUid) {
        continue;
      }
      final convUnwrapped = _unwrapConvIdString(row.conversationId);
      if (convUnwrapped.isScoped && convUnwrapped.ownerUid != currentUid) {
        continue;
      }
      if (convUnwrapped.targetId.isEmpty) continue;
      results.add(
        _mapLocalMessage(row, targetConversationId: convUnwrapped.targetId),
      );
    }
    return results;
  }

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
    final allMembers = <String>{
      ...memberIds.where((m) => m.isNotEmpty),
      if (currentUid.isNotEmpty) currentUid,
    }.toList();

    final isar = await _localDbService.database;
    final key = groupKey(currentUid, groupId);
    await isar.writeTxn(() async {
      final groupConv = LocalChatConversation()
        ..conversationId = key
        ..name = name
        ..description = description
        ..avatarUrl = iconUrl
        ..isGroup = true
        ..ownerId = currentUid
        ..adminIds = [if (currentUid.isNotEmpty) currentUid]
        ..memberIds = allMembers
        ..unreadCount = 0
        ..isMuted = false
        ..lastMessage = 'Group created'
        ..lastMessageTimestamp = createdAt
        ..updatedAt = createdAt;

      await isar.localChatConversations.put(groupConv);
    });

    return ChatConversationModel(
      id: groupId,
      name: name,
      description: description,
      avatarUrl: iconUrl,
      isGroup: true,
      ownerId: currentUid,
      adminIds: [if (currentUid.isNotEmpty) currentUid],
      memberIds: allMembers,
      lastMessage: 'Group created',
      lastMessageTimestamp: createdAt,
    );
  }

  @override
  Future<void> updateGroupInfoLocally({
    required String currentUid,
    required String groupId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final target = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: groupId,
      );
      if (target != null && _unwrapConvKey(target).isGroup) {
        if (name != null && name.isNotEmpty) target.name = name;
        if (description != null) target.description = description;
        if (iconUrl != null) target.avatarUrl = iconUrl;
        target.updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });
  }

  @override
  Future<void> addGroupMembersLocally({
    required String currentUid,
    required String groupId,
    required List<String> memberIds,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final target = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: groupId,
      );
      if (target != null && _unwrapConvKey(target).isGroup) {
        final currentMembers = Set<String>.from(target.memberIds)
          ..addAll(memberIds.where((m) => m.isNotEmpty));
        target
          ..memberIds = currentMembers.toList()
          ..updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });
  }

  @override
  Future<void> removeGroupMemberLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty || memberId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final target = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: groupId,
      );
      if (target != null && _unwrapConvKey(target).isGroup) {
        final currentMembers = List<String>.from(target.memberIds)
          ..remove(memberId);
        final currentAdmins = List<String>.from(target.adminIds)
          ..remove(memberId);
        target
          ..memberIds = currentMembers
          ..adminIds = currentAdmins
          ..updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });
  }

  @override
  Future<void> promoteGroupAdminLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty || memberId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final target = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: groupId,
      );
      if (target != null && _unwrapConvKey(target).isGroup) {
        final currentAdmins = Set<String>.from(target.adminIds)..add(memberId);
        target
          ..adminIds = currentAdmins.toList()
          ..updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });
  }

  @override
  Future<void> demoteGroupAdminLocally({
    required String currentUid,
    required String groupId,
    required String memberId,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty || memberId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final target = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: groupId,
      );
      if (target != null && _unwrapConvKey(target).isGroup) {
        final currentAdmins = List<String>.from(target.adminIds)
          ..remove(memberId);
        target
          ..adminIds = currentAdmins
          ..updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });
  }

  @override
  Future<void> transferGroupOwnerLocally({
    required String currentUid,
    required String groupId,
    required String newOwnerId,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty || newOwnerId.isEmpty) return;
    final isar = await _localDbService.database;
    await isar.writeTxn(() async {
      final target = await _findAuthorizedConversation(
        isar,
        currentUid: currentUid,
        conversationId: groupId,
      );
      if (target != null && _unwrapConvKey(target).isGroup) {
        final currentAdmins = Set<String>.from(target.adminIds)
          ..add(newOwnerId);
        target
          ..ownerId = newOwnerId
          ..adminIds = currentAdmins.toList()
          ..updatedAt = DateTime.now();
        await isar.localChatConversations.put(target);
      }
    });
  }

  @override
  Future<void> leaveGroupLocally({
    required String currentUid,
    required String groupId,
  }) async {
    if (currentUid.isEmpty || groupId.isEmpty) return;
    await deleteConversation(currentUid: currentUid, conversationId: groupId);
  }

  @override
  Future<String> resolveUniqueUidForAgoraUsername(
    String agoraUsername, {
    required String currentUid,
    String? currentAgoraUsername,
    Iterable<String> additionalCandidates = const [],
  }) async {
    if (agoraUsername.isEmpty) return agoraUsername;
    final targetNormalized = agoraUsername.toLowerCase();

    final candidates = <String>{};
    if (currentUid.isNotEmpty) {
      final selfMatches = currentAgoraUsername != null &&
              currentAgoraUsername.isNotEmpty
          ? currentAgoraUsername.toLowerCase() == targetNormalized
          : sanitizeAgoraUsername(currentUid) == targetNormalized;
      if (selfMatches) {
        candidates.add(currentUid);
      }
    }

    for (final c in additionalCandidates) {
      if (c.isNotEmpty && sanitizeAgoraUsername(c) == targetNormalized) {
        candidates.add(c);
      }
    }

    try {
      final isar = await _localDbService.database;
      final profiles = await isar.localProfiles.where().findAll();
      for (final p in profiles) {
        if (p.uid.isNotEmpty &&
            sanitizeAgoraUsername(p.uid) == targetNormalized) {
          candidates.add(p.uid);
        }
      }

      if (currentUid.isNotEmpty) {
        final convs = await isar.localChatConversations.where().findAll();
        for (final c in convs) {
          if (!_isConversationAuthorizedForUser(c, currentUid)) continue;
          final unwrapped = _unwrapConvKey(c);
          if (!unwrapped.isGroup &&
              unwrapped.targetId.isNotEmpty &&
              sanitizeAgoraUsername(unwrapped.targetId) == targetNormalized) {
            candidates.add(unwrapped.targetId);
          }
          for (final m in c.memberIds) {
            if (m.isNotEmpty && sanitizeAgoraUsername(m) == targetNormalized) {
              candidates.add(m);
            }
          }
          for (final a in c.adminIds) {
            if (a.isNotEmpty && sanitizeAgoraUsername(a) == targetNormalized) {
              candidates.add(a);
            }
          }
          if (c.ownerId != null &&
              c.ownerId!.isNotEmpty &&
              sanitizeAgoraUsername(c.ownerId!) == targetNormalized) {
            candidates.add(c.ownerId!);
          }
        }
      }
    } catch (_) {}

    // Only resolve when a single distinct Firebase UID maps to `agoraUsername`.
    // When 0 or >=2 distinct UIDs collide onto the same normalized Agora ID,
    // refuse to conflate them.
    if (candidates.length == 1) {
      return candidates.single;
    }
    return agoraUsername;
  }

  @override
  Future<Map<String, ChatMemberProfile>> getMemberProfiles(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return const {};
    try {
      final isar = await _localDbService.database;
      final profiles = await isar.localProfiles.getAllByUid(uids);
      final map = <String, ChatMemberProfile>{};
      for (final p in profiles) {
        if (p != null && p.uid.isNotEmpty) {
          map[p.uid] = ChatMemberProfile(
            uid: p.uid,
            displayName: p.displayName,
            photoURL: p.photoURL,
            email: p.email,
          );
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }
}

