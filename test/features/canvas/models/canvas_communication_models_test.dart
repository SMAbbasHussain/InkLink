import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/board_chat_message.dart';
import 'package:inklink/features/canvas/models/canvas_comment.dart';
import 'package:inklink/features/canvas/models/voice_participant.dart';

void main() {
  group('CanvasComment and CanvasCommentReply', () {
    test('serializes and deserializes CanvasComment with pinned position and replies', () {
      final now = DateTime.now();
      final reply = CanvasCommentReply(
        id: 'reply-1',
        authorUid: 'user-2',
        authorName: 'Bob',
        authorPhotoUrl: 'https://example.com/bob.png',
        text: 'Great idea @Alice!',
        createdAt: now,
      );

      final comment = CanvasComment(
        id: 'comment-1',
        boardId: 'board-123',
        canvasPosition: const Offset(150.5, 300.25),
        authorUid: 'user-1',
        authorName: 'Alice',
        authorPhotoUrl: 'https://example.com/alice.png',
        text: 'Let us connect these two modules @Bob',
        createdAt: now,
        replies: [reply],
        mentions: ['Bob'],
      );

      final map = comment.toMap();
      expect(map['id'], 'comment-1');
      expect(map['boardId'], 'board-123');
      expect(map['x'], 150.5);
      expect(map['y'], 300.25);
      expect(map['authorUid'], 'user-1');
      expect(map['authorName'], 'Alice');
      expect(map['authorPhotoUrl'], 'https://example.com/alice.png');
      expect(map['mentions'], ['Bob']);
      expect((map['replies'] as List).length, 1);

      final parsed = CanvasComment.fromMap('comment-1', map);
      expect(parsed.id, 'comment-1');
      expect(parsed.boardId, 'board-123');
      expect(parsed.canvasPosition?.dx, 150.5);
      expect(parsed.canvasPosition?.dy, 300.25);
      expect(parsed.authorUid, 'user-1');
      expect(parsed.authorName, 'Alice');
      expect(parsed.replies.length, 1);
      expect(parsed.replies.first.id, 'reply-1');
      expect(parsed.replies.first.authorName, 'Bob');
      expect(parsed.replies.first.text, 'Great idea @Alice!');
      expect(parsed.mentions, ['Bob']);
    });

    test('CanvasComment without canvasPosition handles board-level comment', () {
      final comment = CanvasComment(
        id: 'board-comment-1',
        boardId: 'board-999',
        authorUid: 'user-admin',
        authorName: 'Admin',
        text: 'Welcome team!',
        createdAt: DateTime.now(),
      );

      final map = comment.toMap();
      expect(map.containsKey('x'), isFalse);
      expect(map.containsKey('y'), isFalse);

      final parsed = CanvasComment.fromMap('board-comment-1', map);
      expect(parsed.canvasPosition, isNull);
      expect(parsed.text, 'Welcome team!');
    });

    test('CanvasComment copyWith updates fields correctly', () {
      final comment = CanvasComment(
        id: 'c1',
        boardId: 'b1',
        authorUid: 'u1',
        authorName: 'User',
        text: 'Initial',
        createdAt: DateTime.now(),
      );

      final updated = comment.copyWith(text: 'Updated text');
      expect(updated.text, 'Updated text');
      expect(updated.id, 'c1');
    });
  });

  group('BoardChatMessage', () {
    test('serializes and deserializes correctly', () {
      const msg = BoardChatMessage(
        id: 'msg-1',
        boardId: 'board-abc',
        senderUid: 'user-sender',
        senderName: 'John',
        senderPhotoUrl: 'https://example.com/john.jpg',
        text: 'Hey everyone, check the top right shape',
        timestamp: 1729000000000,
      );

      final map = msg.toMap();
      expect(map['id'], 'msg-1');
      expect(map['boardId'], 'board-abc');
      expect(map['senderUid'], 'user-sender');
      expect(map['senderName'], 'John');
      expect(map['text'], 'Hey everyone, check the top right shape');
      expect(map['timestamp'], 1729000000000);

      final parsed = BoardChatMessage.fromMap(map);
      expect(parsed.id, 'msg-1');
      expect(parsed.boardId, 'board-abc');
      expect(parsed.senderName, 'John');
      expect(parsed.senderPhotoUrl, 'https://example.com/john.jpg');
      expect(parsed.text, 'Hey everyone, check the top right shape');
      expect(parsed.timestamp, 1729000000000);
    });
  });

  group('VoiceParticipant', () {
    test('serializes, deserializes, and checks copyWith and equality', () {
      const participant = VoiceParticipant(
        uid: 'user-voice-1',
        displayName: 'Alice',
        photoUrl: 'https://example.com/alice.png',
        joinedAt: 1729000000000,
        isSpeaking: false,
        isMuted: false,
      );

      final map = participant.toMap();
      expect(map['uid'], 'user-voice-1');
      expect(map['displayName'], 'Alice');
      expect(map['isSpeaking'], false);
      expect(map['isMuted'], false);

      final parsed = VoiceParticipant.fromMap(map);
      expect(parsed.uid, 'user-voice-1');
      expect(parsed.displayName, 'Alice');
      expect(parsed.isSpeaking, false);
      expect(parsed.isMuted, false);

      final speaking = participant.copyWith(isSpeaking: true);
      expect(speaking.isSpeaking, isTrue);
      expect(speaking.isMuted, isFalse);

      final muted = speaking.copyWith(isMuted: true, isSpeaking: false);
      expect(muted.isMuted, isTrue);
      expect(muted.isSpeaking, isFalse);
    });
  });
}
