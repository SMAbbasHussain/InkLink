import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/notification/in_app_notification.dart';
import 'package:inklink/web/data/web_board_ops.dart';

InAppNotification _notification(
  String id, {
  String type = 'board_invite',
  bool read = false,
  DateTime? at,
}) => InAppNotification(
  id: id,
  uid: 'me',
  timestamp: at ?? DateTime(2026, 11, 1),
  type: type,
  title: 'Title $id',
  read: read,
);

void main() {
  group('board names', () {
    test('trim, fall back and cap', () {
      expect(normalizeBoardName('  Roadmap  '), 'Roadmap');
      expect(normalizeBoardName('   '), 'Untitled Board');
      expect(normalizeBoardName('x' * 200), hasLength(maxBoardNameLength));
    });

    test('validation messages', () {
      expect(validateBoardName(''), 'Please enter a board name.');
      expect(validateBoardName('  '), 'Please enter a board name.');
      expect(validateBoardName('Fine'), isNull);
      expect(validateBoardName('x' * (maxBoardNameLength + 1)), isNotNull);
    });
  });

  group('tags', () {
    test('trim, lower-case, de-duplicate and keep five', () {
      expect(normalizeBoardTags([' Design ', 'design', 'ART', '']), [
        'design',
        'art',
      ]);
      expect(normalizeBoardTags(['a', 'b', 'c', 'd', 'e', 'f']), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
      expect(normalizeBoardTags(const []), isEmpty);
    });
  });

  group('normalization', () {
    test('visibility and private join policy', () {
      expect(normalizeVisibility('public'), Board.visibilityPublic);
      expect(normalizeVisibility('weird'), Board.visibilityPrivate);
      expect(
        normalizePrivateJoinPolicy('link_can_join'),
        Board.policyLinkCanJoin,
      );
      expect(
        normalizePrivateJoinPolicy('anything'),
        Board.policyOwnerOnlyInvite,
      );
    });

    test('invite rights and link role', () {
      expect(
        normalizeWhoCanInvite(Board.inviteAllMembers),
        Board.inviteAllMembers,
      );
      expect(
        normalizeWhoCanInvite(Board.inviteOwnerEditor),
        Board.inviteOwnerEditor,
      );
      expect(normalizeWhoCanInvite('nobody'), Board.inviteOwnerOnly);
      expect(normalizeLinkJoinRole(Board.roleEditor), Board.roleEditor);
      expect(normalizeLinkJoinRole('guest'), Board.roleViewer);
    });

    test('join codes are enabled for public and link-joinable boards', () {
      expect(
        boardJoinViaCodeEnabled(
          visibility: Board.visibilityPublic,
          privateJoinPolicy: Board.policyOwnerOnlyInvite,
        ),
        isTrue,
      );
      expect(
        boardJoinViaCodeEnabled(
          visibility: Board.visibilityPrivate,
          privateJoinPolicy: Board.policyLinkCanJoin,
        ),
        isTrue,
      );
      expect(
        boardJoinViaCodeEnabled(
          visibility: Board.visibilityPrivate,
          privateJoinPolicy: Board.policyOwnerOnlyInvite,
        ),
        isFalse,
      );
    });
  });

  group('newBoardFields', () {
    Map<String, dynamic> fields({
      String visibility = Board.visibilityPrivate,
      String policy = Board.policyOwnerOnlyInvite,
    }) => newBoardFields(
      boardId: 'b1',
      uid: 'me',
      name: '  My board ',
      visibility: visibility,
      privateJoinPolicy: policy,
      whoCanInvite: Board.inviteOwnerEditor,
      defaultLinkJoinRole: Board.roleEditor,
      tags: const [' Design ', 'design', 'Art'],
      allowMembersToCopy: true,
    );

    test('writes the document shape the phone writes', () {
      final data = fields();
      expect(data['boardId'], 'b1');
      expect(data['title'], 'My board');
      expect(data['name'], 'My board');
      expect(data['ownerId'], 'me');
      expect(data['members'], ['me']);
      expect(data['memberCount'], 1);
      expect(data['membersCount'], 1);
      expect(data['engine'], 'crdt_v1');
      expect(data['joinCode'], 'b1');
      expect(data['isArchived'], isFalse);
      expect(data['isPaused'], isFalse);
      expect(data['allowMembersToCopy'], isTrue);
      expect(data['tags'], ['design', 'art']);
      expect(data['invitePolicy'], {
        'whoCanInvite': Board.inviteOwnerEditor,
        'defaultLinkJoinRole': Board.roleEditor,
      });
      expect(data.containsKey('createdAt'), isFalse);
    });

    test('derives joinViaCodeEnabled like the phone', () {
      expect(fields()['joinViaCodeEnabled'], isFalse);
      expect(
        fields(
          visibility: Board.visibilityPrivate,
          policy: Board.policyLinkCanJoin,
        )['joinViaCodeEnabled'],
        isTrue,
      );
      expect(
        fields(visibility: Board.visibilityPublic)['joinViaCodeEnabled'],
        isTrue,
      );
    });
  });

  group('duplicatedBoardFields', () {
    test('the copy is a standalone board owned by the copier', () {
      final source = <String, dynamic>{
        'title': 'Roadmap',
        'ownerId': 'other',
        'members': ['other', 'me', 'third'],
        'membersCount': 3,
        'memberCount': 3,
        'tags': ['planning'],
        'visibility': 'public',
        'previewPath': '/previews/x.png',
        'workspaceId': 'w1',
        'workspaceIds': ['w1'],
        'pendingInvites': ['x@example.com'],
        'invitedUserIds': ['u9'],
        'isArchived': true,
        'isPaused': true,
        'allowMembersToCopy': true,
      };
      final copy = duplicatedBoardFields(
        source,
        newBoardId: 'copy1',
        uid: 'me',
      );
      expect(copy['title'], 'Roadmap (Copy)');
      expect(copy['name'], 'Roadmap (Copy)');
      expect(copy['boardId'], 'copy1');
      expect(copy['joinCode'], 'copy1');
      expect(copy['ownerId'], 'me');
      expect(copy['members'], ['me']);
      expect(copy['membersCount'], 1);
      expect(copy['memberCount'], 1);
      expect(copy['isArchived'], isFalse);
      expect(copy['isPaused'], isFalse);
      expect(copy['allowMembersToCopy'], isFalse);
      expect(copy['tags'], ['planning']);
      expect(copy['visibility'], 'public');
      expect(copy['invitePolicy'], {
        'whoCanInvite': Board.inviteOwnerOnly,
        'defaultLinkJoinRole': Board.roleViewer,
      });
      for (final key in [
        'previewPath',
        'workspaceId',
        'workspaceIds',
        'pendingInvites',
        'invitedUserIds',
      ]) {
        expect(copy.containsKey(key), isFalse, reason: key);
      }
      // The source map is not mutated.
      expect(source['title'], 'Roadmap');
      expect(source['members'], hasLength(3));
    });

    test('a custom title wins', () {
      final copy = duplicatedBoardFields(
        {'title': 'A'},
        newBoardId: 'copy1',
        uid: 'me',
        customTitle: '  Fresh copy  ',
      );
      expect(copy['title'], 'Fresh copy');
    });
  });

  group('boardSettingsFields', () {
    test('nested invite policy and derived join flag', () {
      final fields = boardSettingsFields(
        visibility: Board.visibilityPrivate,
        privateJoinPolicy: Board.policyLinkCanJoin,
        whoCanInvite: Board.inviteAllMembers,
        defaultLinkJoinRole: Board.roleEditor,
        allowMembersToCopy: true,
      );
      expect(fields['visibility'], Board.visibilityPrivate);
      expect(fields['privateJoinPolicy'], Board.policyLinkCanJoin);
      expect(fields['joinViaCodeEnabled'], isTrue);
      expect(fields['invitePolicy'], {
        'whoCanInvite': Board.inviteAllMembers,
        'defaultLinkJoinRole': Board.roleEditor,
      });
      expect(fields['allowMembersToCopy'], isTrue);
    });

    test('leaves allowMembersToCopy alone when not passed', () {
      final fields = boardSettingsFields(
        visibility: Board.visibilityPublic,
        privateJoinPolicy: Board.policyOwnerOnlyInvite,
        whoCanInvite: Board.inviteOwnerOnly,
        defaultLinkJoinRole: Board.roleViewer,
      );
      expect(fields.containsKey('allowMembersToCopy'), isFalse);
    });
  });

  group('notification read state', () {
    test('stored read ids mark notifications read without touching others', () {
      final items = [
        _notification('a'),
        _notification('b', read: true),
        _notification('c'),
      ];
      final withRead = applyReadState(items, {'a'});
      expect(withRead[0].read, isTrue);
      expect(withRead[0].readAt, items[0].timestamp);
      expect(withRead[1].read, isTrue);
      expect(withRead[2].read, isFalse);
      // Originals stay unread.
      expect(items[0].read, isFalse);
      expect(unreadNotificationCount(withRead, const {}), 1);
    });

    test('unread count uses the read overlay', () {
      final items = [_notification('a'), _notification('b')];
      expect(unreadNotificationCount(items, const {}), 2);
      expect(unreadNotificationCount(items, {'a'}), 1);
      expect(unreadNotificationCount(items, {'a', 'b'}), 0);
    });

    test('readAt is kept when present', () {
      final at = DateTime(2026, 1, 1);
      final item = InAppNotification(
        id: 'a',
        uid: 'me',
        timestamp: DateTime(2025, 12, 31),
        type: 'mention',
        title: 'T',
        readAt: at,
      );
      expect(withReadState(item, {'a'}).readAt, at);
    });
  });

  group('notification filters', () {
    test('requests and friends and boards', () {
      expect(
        notificationMatchesFilter('board_invite', NotificationFilter.requests),
        isTrue,
      );
      expect(
        notificationMatchesFilter(
          'friend_request',
          NotificationFilter.requests,
        ),
        isTrue,
      );
      expect(
        notificationMatchesFilter('friend_request', NotificationFilter.friends),
        isTrue,
      );
      expect(
        notificationMatchesFilter(
          'friend_request_accepted',
          NotificationFilter.friends,
        ),
        isTrue,
      );
      expect(
        notificationMatchesFilter('mention', NotificationFilter.boards),
        isTrue,
      );
      expect(
        notificationMatchesFilter('role_updated', NotificationFilter.boards),
        isTrue,
      );
      expect(
        notificationMatchesFilter('board_invite', NotificationFilter.boards),
        isFalse,
      );
      expect(
        notificationMatchesFilter('anything', NotificationFilter.all),
        isTrue,
      );
    });
  });

  group('notification targets', () {
    test('invites, friends, workspace, profile and boards', () {
      expect(notificationTargetOf('board_invite'), NotificationTarget.invites);
      expect(
        notificationTargetOf('workspace_invite'),
        NotificationTarget.workspace,
      );
      expect(
        notificationTargetOf('friend_request'),
        NotificationTarget.friends,
      );
      expect(
        notificationTargetOf('friend_request_accepted'),
        NotificationTarget.friends,
      );
      expect(
        notificationTargetOf('profile_updated'),
        NotificationTarget.profile,
      );
      expect(notificationTargetOf('mention'), NotificationTarget.boards);
      expect(notificationTargetOf('role_updated'), NotificationTarget.boards);
    });
  });
}
