import 'dart:convert';
import 'chat_share_payload.dart';

enum ChatMessageType {
  text,
  image,
  gif,
  file,
  boardShare,
  workspaceShare;

  static ChatMessageType fromString(String? value) {
    switch (value) {
      case 'image':
        return ChatMessageType.image;
      case 'gif':
        return ChatMessageType.gif;
      case 'file':
        return ChatMessageType.file;
      case 'board_share':
      case 'boardShare':
        return ChatMessageType.boardShare;
      case 'workspace_share':
      case 'workspaceShare':
        return ChatMessageType.workspaceShare;
      default:
        return ChatMessageType.text;
    }
  }

  String get asString {
    switch (this) {
      case ChatMessageType.image:
        return 'image';
      case ChatMessageType.gif:
        return 'gif';
      case ChatMessageType.file:
        return 'file';
      case ChatMessageType.boardShare:
        return 'board_share';
      case ChatMessageType.workspaceShare:
        return 'workspace_share';
      case ChatMessageType.text:
        return 'text';
    }
  }
}

enum ChatMessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  static ChatMessageStatus fromString(String? value) {
    switch (value) {
      case 'sending':
        return ChatMessageStatus.sending;
      case 'delivered':
        return ChatMessageStatus.delivered;
      case 'read':
        return ChatMessageStatus.read;
      case 'failed':
        return ChatMessageStatus.failed;
      default:
        return ChatMessageStatus.sent;
    }
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;
  final ChatMessageStatus status;
  final Map<String, List<String>> reactions;
  final bool isEdited;
  final bool isDeleted;
  final int? fileSize;
  final String? fileName;
  final ChatSharePayload? sharePayload;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.type,
    required this.content,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.reactions = const {},
    this.isEdited = false,
    this.isDeleted = false,
    this.fileSize,
    this.fileName,
    this.sharePayload,
  });

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    ChatMessageType? type,
    String? content,
    DateTime? timestamp,
    ChatMessageStatus? status,
    Map<String, List<String>>? reactions,
    bool? isEdited,
    bool? isDeleted,
    int? fileSize,
    String? fileName,
    ChatSharePayload? sharePayload,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      fileSize: fileSize ?? this.fileSize,
      fileName: fileName ?? this.fileName,
      sharePayload: sharePayload ?? this.sharePayload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type.asString,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'reactions': reactions,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'fileSize': fileSize,
      'fileName': fileName,
      'sharePayload': sharePayload?.toMap(),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    final rawReactions = map['reactions'];
    final Map<String, List<String>> parsedReactions = {};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        if (v is List) {
          parsedReactions[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    ChatSharePayload? parsedPayload;
    if (map['sharePayload'] is Map) {
      parsedPayload = ChatSharePayload.fromMap(
        Map<String, dynamic>.from(map['sharePayload'] as Map),
      );
    } else if (map['type'] == 'board_share' || map['type'] == 'workspace_share') {
      try {
        parsedPayload = ChatSharePayload.fromJsonString(map['content']?.toString() ?? '');
      } catch (_) {}
    }

    return ChatMessageModel(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversationId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'User',
      senderAvatar: map['senderAvatar']?.toString(),
      type: ChatMessageType.fromString(map['type']?.toString()),
      content: map['content']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(map['timestamp'].toString()))
          : DateTime.now(),
      status: ChatMessageStatus.fromString(map['status']?.toString()),
      reactions: parsedReactions,
      isEdited: map['isEdited'] == true,
      isDeleted: map['isDeleted'] == true,
      fileSize: map['fileSize'] != null ? int.tryParse(map['fileSize'].toString()) : null,
      fileName: map['fileName']?.toString(),
      sharePayload: parsedPayload,
    );
  }

  String toJsonString() => jsonEncode(toMap());
}
