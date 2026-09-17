import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/friends/blocked_user.dart';
import 'package:inklink/domain/models/friends/friend.dart';
import 'package:inklink/domain/models/friends/friend_request.dart';
import 'package:inklink/domain/models/invitation/board_invitation.dart';
import 'package:inklink/domain/models/notification/in_app_notification.dart';
import 'package:inklink/domain/models/user_model.dart';
import 'package:inklink/domain/models/workspace_board.dart';

void main() {
  group('Friend Domain Model', () {
    test('instantiates and serializes with map-like and typed access', () {
      final friend = Friend(
        uid: 'user_123',
        displayName: 'Alice',
        email: 'alice@example.com',
        photoURL: 'https://example.com/alice.png',
        friendCount: 5,
        boardCount: 3,
        isOnline: true,
      );

      expect(friend.uid, 'user_123');
      expect(friend.displayName, 'Alice');
      expect(friend['uid'], 'user_123');
      expect(friend['displayName'], 'Alice');
      expect(friend['email'], 'alice@example.com');
      expect(friend['isOnline'], true);

      final map = friend.toMap();
      final reconstructed = Friend.fromMap(map);
      expect(reconstructed, equals(friend));
    });
  });

  group('FriendRequest Domain Model', () {
    test('instantiates and serializes correctly', () {
      final now = DateTime(2026, 9, 17, 12, 0, 0);
      final request = FriendRequest(
        id: 'req_1',
        fromUid: 'user_1',
        toUid: 'user_2',
        senderName: 'Bob',
        senderPic: 'https://example.com/bob.png',
        timestamp: now,
      );

      expect(request.id, 'req_1');
      expect(request['fromUid'], 'user_1');
      expect(request['senderName'], 'Bob');
      expect(request.status, 'pending');

      final map = request.toMap();
      final fromMap = FriendRequest.fromMap(map);
      expect(fromMap.id, 'req_1');
      expect(fromMap.fromUid, 'user_1');
      expect(fromMap.senderName, 'Bob');
    });
  });

  group('BlockedUser Domain Model', () {
    test('instantiates and serializes correctly', () {
      final blocked = BlockedUser(
        blockedUid: 'spammer_1',
        blockerUid: 'me_1',
        displayName: 'Spammer',
      );

      expect(blocked.blockedUid, 'spammer_1');
      expect(blocked['blockedUid'], 'spammer_1');
      expect(blocked['displayName'], 'Spammer');

      final map = blocked.toMap();
      final fromMap = BlockedUser.fromMap(map);
      expect(fromMap.blockedUid, 'spammer_1');
      expect(fromMap.blockerUid, 'me_1');
    });
  });

  group('BoardInvitation Domain Model', () {
    test('instantiates and round-trips correctly', () {
      final now = DateTime(2026, 9, 17, 10, 0, 0);
      final invite = BoardInvitation(
        id: 'inv_100',
        boardId: 'board_abc',
        boardTitle: 'Design System',
        fromUid: 'lead_1',
        toUid: 'designer_1',
        senderName: 'Lead Designer',
        targetRole: 'editor',
        timestamp: now,
      );

      expect(invite.id, 'inv_100');
      expect(invite['boardTitle'], 'Design System');
      expect(invite['targetRole'], 'editor');

      final map = invite.toMap();
      final parsed = BoardInvitation.fromMap(map);
      expect(parsed.id, 'inv_100');
      expect(parsed.boardId, 'board_abc');
      expect(parsed.targetRole, 'editor');
    });
  });

  group('InAppNotification Domain Model', () {
    test('instantiates and round-trips correctly', () {
      final now = DateTime(2026, 9, 17, 8, 30, 0);
      final notif = InAppNotification(
        id: 'notif_1',
        uid: 'user_99',
        timestamp: now,
        type: 'board_invite',
        title: 'New Invitation',
        body: 'You have been invited to collaborate',
        senderDisplayName: 'Alice',
      );

      expect(notif.id, 'notif_1');
      expect(notif['title'], 'New Invitation');
      expect(notif['senderDisplayName'], 'Alice');
      expect(notif.read, isFalse);

      final map = notif.toMap();
      final parsed = InAppNotification.fromMap(map);
      expect(parsed.id, 'notif_1');
      expect(parsed.title, 'New Invitation');
      expect(parsed.body, 'You have been invited to collaborate');
    });
  });

  group('Pure Board Model', () {
    test('creates Board without cloud_firestore dependency and parses timestamps/dates', () {
      final now = DateTime(2026, 9, 17, 16, 0, 0);
      final board = Board(
        id: 'board_main',
        title: 'Architecture Review',
        ownerId: 'owner_1',
        members: ['owner_1', 'member_2'],
        createdAt: now,
        updatedAt: now,
      );

      expect(board.id, 'board_main');
      expect(board.title, 'Architecture Review');
      expect(board.createdAt, now);

      final map = board.toMap();
      expect(map['title'], 'Architecture Review');
      expect(map['createdAt'], now);

      final fromMap = Board.fromMap(map, 'board_main');
      expect(fromMap.title, 'Architecture Review');
      expect(fromMap.ownerId, 'owner_1');
    });
  });

  group('Pure UserModel', () {
    test('creates UserModel without Isar framework annotations', () {
      final now = DateTime(2026, 9, 17, 16, 0, 0);
      final user = UserModel(
        uid: 'user_pure',
        displayName: 'Pure Developer',
        email: 'pure@example.com',
        bio: 'Clean Architecture advocate',
        createdAt: now,
        friendCount: 12,
        boardCount: 4,
      );

      expect(user.uid, 'user_pure');
      expect(user.displayName, 'Pure Developer');
      expect(user['displayName'], 'Pure Developer');
      expect(user['friendCount'], 12);

      final map = user.toMap();
      final fromMap = UserModel.fromMap(map, 'user_pure');
      expect(fromMap.displayName, 'Pure Developer');
      expect(fromMap.friendCount, 12);
    });
  });

  group('Pure WorkspaceBoard Model', () {
    test('creates and parses WorkspaceBoard without cloud_firestore dependency', () {
      final now = DateTime(2026, 9, 17, 16, 0, 0);
      final wb = WorkspaceBoard(
        boardId: 'b_1',
        source: WorkspaceBoard.sourceWorkspaceNative,
        addedBy: 'admin_1',
        addedAt: now,
        visibilityInWorkspace: 'workspace_members',
        updatedAt: now,
      );

      expect(wb.isWorkspaceNative, isTrue);
      expect(wb.isImported, isFalse);

      final map = wb.toMap();
      final fromMap = WorkspaceBoard.fromMap(map);
      expect(fromMap.boardId, 'b_1');
      expect(fromMap.source, WorkspaceBoard.sourceWorkspaceNative);
    });
  });
}
