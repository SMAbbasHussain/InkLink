import 'package:flutter/material.dart';

class CanvasCommentReply {
  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;

  const CanvasCommentReply({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorUid': authorUid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CanvasCommentReply.fromMap(Map<String, dynamic> map) {
    return CanvasCommentReply(
      id: map['id'] as String? ?? '',
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Anonymous',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }
}

class CanvasComment {
  final String id;
  final String boardId;
  final Offset? canvasPosition; // Optional (x, y) pin on the whiteboard
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<CanvasCommentReply> replies;
  final List<String> mentions; // Usernames or UIDs mentioned

  const CanvasComment({
    required this.id,
    required this.boardId,
    this.canvasPosition,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.replies = const [],
    this.mentions = const [],
  });

  CanvasComment copyWith({
    String? id,
    String? boardId,
    Offset? canvasPosition,
    String? authorUid,
    String? authorName,
    String? authorPhotoUrl,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CanvasCommentReply>? replies,
    List<String>? mentions,
  }) {
    return CanvasComment(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      canvasPosition: canvasPosition ?? this.canvasPosition,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replies: replies ?? this.replies,
      mentions: mentions ?? this.mentions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boardId': boardId,
      if (canvasPosition != null) ...{
        'x': canvasPosition!.dx,
        'y': canvasPosition!.dy,
      },
      'authorUid': authorUid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
      'replies': replies.map((r) => r.toMap()).toList(),
      'mentions': mentions,
    };
  }

  factory CanvasComment.fromMap(String id, Map<String, dynamic> map) {
    Offset? pos;
    if (map.containsKey('x') && map.containsKey('y')) {
      final x = (map['x'] as num).toDouble();
      final y = (map['y'] as num).toDouble();
      pos = Offset(x, y);
    }

    final rawReplies = map['replies'] as List<dynamic>? ?? [];
    final replies = rawReplies
        .map((r) => CanvasCommentReply.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();

    final rawMentions = map['mentions'] as List<dynamic>? ?? [];
    final mentions = rawMentions.map((m) => m.toString()).toList();

    return CanvasComment(
      id: id,
      boardId: map['boardId'] as String? ?? '',
      canvasPosition: pos,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Anonymous',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      replies: replies,
      mentions: mentions,
    );
  }
}
