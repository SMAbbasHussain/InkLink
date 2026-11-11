import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board_edit_request.dart';

void main() {
  group('BoardEditRequest', () {
    test('parses notification map with extraData correctly', () {
      final map = {
        'id': 'notif_123',
        'type': 'board_edit_request',
        'status': 'pending',
        'targetId': 'b_target',
        'timestamp': Timestamp.fromDate(DateTime(2026, 11, 9, 12, 0)),
        'senderName': 'Fallback Sender',
        'senderPic': 'https://example.com/pic.jpg',
        'extraData': {
          'boardId': 'b_real',
          'boardTitle': 'Project Alpha',
          'requesterUid': 'u_456',
          'requesterName': 'Alice Bob',
          'message': 'Please give me edit access for the demo.',
          'requestType': 'edit',
        },
      };

      final req = BoardEditRequest.fromNotificationMap(map);

      expect(req.id, equals('notif_123'));
      expect(req.boardId, equals('b_real'));
      expect(req.boardTitle, equals('Project Alpha'));
      expect(req.requesterUid, equals('u_456'));
      expect(req.requesterName, equals('Alice Bob'));
      expect(req.requesterPhotoUrl, equals('https://example.com/pic.jpg'));
      expect(req.message, equals('Please give me edit access for the demo.'));
      expect(req.status, equals('pending'));
      expect(req.isPending, isTrue);
      expect(req.isAccepted, isFalse);
      expect(req.isDeclined, isFalse);
      expect(req.createdAt, equals(DateTime(2026, 11, 9, 12, 0)));
    });

    test('falls back to top-level fields and defaults when extraData is empty', () {
      final map = {
        'id': 'notif_999',
        'targetId': 'b_default',
        'title': 'Test Title',
        'senderUid': 'u_sender',
        'senderName': 'Bob Marley',
        'status': 'accepted',
      };

      final req = BoardEditRequest.fromNotificationMap(map, fallbackBoardId: 'b_fallback');

      expect(req.id, equals('notif_999'));
      expect(req.boardId, equals('b_default'));
      expect(req.boardTitle, equals('Test Title'));
      expect(req.requesterUid, equals('u_sender'));
      expect(req.requesterName, equals('Bob Marley'));
      expect(req.message, isEmpty);
      expect(req.status, equals('accepted'));
      expect(req.isPending, isFalse);
      expect(req.isAccepted, isTrue);
    });

    test('handles declined status properly', () {
      final map = {
        'id': 'notif_declined',
        'status': 'declined',
      };

      final req = BoardEditRequest.fromNotificationMap(map);
      expect(req.isDeclined, isTrue);
      expect(req.isPending, isFalse);
    });
  });
}

