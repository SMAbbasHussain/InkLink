import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/notification/in_app_notification.dart';
import 'package:inklink/web/data/web_mappers.dart';

/// Fixes found while reviewing the web companion with a real account.
void main() {
  group('boardRoleLabel', () {
    test('owner, member and public', () {
      expect(
        boardRoleLabel(
          ownerId: 'me',
          memberIds: const ['me'],
          currentUid: 'me',
        ),
        'Owner',
      );
      expect(
        boardRoleLabel(
          ownerId: 'x',
          memberIds: const ['x', 'me'],
          currentUid: 'me',
        ),
        'Member',
      );
      // A public board the user has not joined must not say "Member".
      expect(
        boardRoleLabel(
          ownerId: 'x',
          memberIds: const ['x', 'y'],
          currentUid: 'me',
        ),
        'Public',
      );
      expect(
        boardRoleLabel(ownerId: 'x', memberIds: const [], currentUid: null),
        'Public',
      );
    });

    test('the user\'s own board list is always Owner or Member', () {
      expect(
        boardRoleLabel(
          ownerId: 'x',
          memberIds: const [],
          currentUid: 'me',
          knownMember: true,
        ),
        'Member',
      );
    });
  });

  group('notification sender fields', () {
    test('fills the model fields from the names the Cloud Functions write', () {
      final data = withNotificationSenderFields({
        'type': 'workspace_invite',
        'title': 'Faha Ahmed invited you to a workspace',
        'fromUid': 'u1',
        'senderName': 'Faha Ahmed',
        'senderPic': 'https://example.test/p.png',
      });
      final n = InAppNotification.fromMap(data, 'n1');
      expect(n.senderUid, 'u1');
      expect(n.senderDisplayName, 'Faha Ahmed');
      expect(n.senderPhotoUrl, 'https://example.test/p.png');
      expect(initialsOf(n.senderDisplayName), 'FA');
    });

    test('never overwrites fields that are already set', () {
      final data = withNotificationSenderFields({
        'senderDisplayName': 'Kept',
        'senderName': 'Ignored',
      });
      expect(data['senderDisplayName'], 'Kept');
    });

    test('does not change the original map', () {
      final original = <String, dynamic>{'senderName': 'A'};
      withNotificationSenderFields(original);
      expect(original.containsKey('senderDisplayName'), isFalse);
    });
  });

  test('notificationKindOf maps the Cloud Function types', () {
    expect(notificationKindOf('board_invite'), NotificationKind.invite);
    expect(notificationKindOf('workspace_invite'), NotificationKind.invite);
    expect(notificationKindOf('friend_request'), NotificationKind.friend);
    expect(
      notificationKindOf('friend_request_accepted'),
      NotificationKind.friend,
    );
    expect(notificationKindOf('mention'), NotificationKind.mention);
    expect(notificationKindOf('role_updated'), NotificationKind.access);
    expect(
      notificationKindOf('board_access_declined'),
      NotificationKind.access,
    );
    expect(notificationKindOf('member_removed'), NotificationKind.access);
    expect(notificationKindOf('board_deleted'), NotificationKind.board);
    expect(notificationKindOf('undo_request'), NotificationKind.board);
    expect(notificationKindOf('something_new'), NotificationKind.other);
  });
}
