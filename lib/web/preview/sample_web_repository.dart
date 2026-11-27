import 'dart:async';

import '../../domain/models/board.dart';
import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/notification/in_app_notification.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import '../data/web_account.dart';
import '../data/web_companion_repository.dart';

/// Sample data for the design preview (lib/web/preview/main_web_preview.dart)
/// and the page tests. No Firebase, no network, no real accounts.
///
/// Accept / decline / delete / profile edits change the in-memory lists, so
/// the whole flow can be clicked through.
class SampleWebCompanionRepository implements WebCompanionRepository {
  SampleWebCompanionRepository({bool signedIn = true, DateTime? now})
      : _now = now ?? DateTime.now() {
    if (signedIn) _account = _sampleAccount;
    _seed();
  }

  final DateTime _now;
  WebAccount? _account;
  final _authController = StreamController<WebAccount?>.broadcast();

  static const _sampleAccount = WebAccount(
    uid: 'me',
    email: 'sam.rivera@example.com',
    displayName: 'Sam Rivera',
  );

  late UserModel _profile;
  late List<Board> _myBoards;
  late List<Board> _publicBoards;
  late List<BoardInvitation> _boardInvites;
  late List<WorkspaceInvite> _workspaceInvites;
  late List<FriendRequest> _requests;
  late List<Friend> _friends;
  late List<InAppNotification> _notifications;

  final _profileCtl = StreamController<UserModel?>.broadcast();
  final _boardsCtl = StreamController<List<Board>>.broadcast();
  final _boardInvitesCtl = StreamController<List<BoardInvitation>>.broadcast();
  final _wsInvitesCtl = StreamController<List<WorkspaceInvite>>.broadcast();
  final _requestsCtl = StreamController<List<FriendRequest>>.broadcast();
  final _friendsCtl = StreamController<List<Friend>>.broadcast();
  final _notificationsCtl = StreamController<List<InAppNotification>>.broadcast();

  int _ago(Duration d) => _now.subtract(d).millisecondsSinceEpoch;

  Board _board(
    String id,
    String title, {
    String ownerId = 'me',
    List<String> members = const ['me'],
    String visibility = 'private',
    List<String> tags = const [],
    Duration updated = const Duration(hours: 2),
    bool archived = false,
  }) =>
      Board.fromMap({
        'title': title,
        'ownerId': ownerId,
        'members': members,
        'membersCount': members.length,
        'visibility': visibility,
        'tags': tags,
        'isArchived': archived,
        'createdAt': _ago(const Duration(days: 30)),
        'updatedAt': _ago(updated),
      }, id);

  void _seed() {
    _profile = UserModel.fromFirestore({
      'displayName': 'Sam Rivera',
      'email': 'sam.rivera@example.com',
      'bio': 'Product designer. I sketch first and ask questions later.',
      'friendCount': 4,
      'boardCount': 6,
      'createdAt': _ago(const Duration(days: 200)),
    }, 'me');

    _myBoards = [
      _board('b1', 'Q3 roadmap',
          members: const ['me', 'u1', 'u2', 'u3'],
          tags: const ['planning', 'team'],
          updated: const Duration(minutes: 12)),
      _board('b2', 'Landing page wireframes',
          members: const ['me', 'u2'],
          visibility: 'public',
          tags: const ['design', 'web'],
          updated: const Duration(hours: 3)),
      _board('b3', 'Sprint retro',
          ownerId: 'u1',
          members: const ['u1', 'me', 'u4'],
          tags: const ['team'],
          updated: const Duration(days: 1)),
      _board('b4', 'Character sketches',
          members: const ['me'],
          visibility: 'public',
          tags: const ['art'],
          updated: const Duration(days: 2)),
      _board('b5', 'Kitchen remodel ideas',
          ownerId: 'u3',
          members: const ['u3', 'me'],
          updated: const Duration(days: 5)),
      _board('b6', 'Old brainstorm',
          members: const ['me', 'u1'],
          archived: true,
          updated: const Duration(days: 40)),
    ];

    _publicBoards = [
      _myBoards[1],
      _myBoards[3],
      _board('p1', 'City sketch walk',
          ownerId: 'u5',
          members: const ['u5', 'u6', 'u7'],
          visibility: 'public',
          tags: const ['art', 'travel'],
          updated: const Duration(hours: 5)),
      _board('p2', 'Open-source logo jam',
          ownerId: 'u6',
          members: const ['u6', 'u8'],
          visibility: 'public',
          tags: const ['design', 'logo'],
          updated: const Duration(days: 1)),
      _board('p3', 'Physics study notes',
          ownerId: 'u7',
          members: const ['u7'],
          visibility: 'public',
          tags: const ['study'],
          updated: const Duration(days: 3)),
      _board('p4', 'Board game prototype',
          ownerId: 'u8',
          members: const ['u8', 'u5'],
          visibility: 'public',
          tags: const ['games', 'design'],
          updated: const Duration(days: 4)),
    ];

    _boardInvites = [
      BoardInvitation.fromMap({
        'boardId': 'p2',
        'boardTitle': 'Open-source logo jam',
        'fromUid': 'u6',
        'toUid': 'me',
        'senderName': 'Priya Shah',
        'status': 'pending',
        'targetRole': 'editor',
        'timestamp': _ago(const Duration(hours: 1)),
      }, 'bi1'),
    ];

    _workspaceInvites = [
      WorkspaceInvite(
        id: 'wi1',
        workspaceId: 'w1',
        fromUid: 'u1',
        toUid: 'me',
        senderName: 'Alex Kim',
        workspaceName: 'Design Team',
        status: 'pending',
        timestamp: _now.subtract(const Duration(days: 1)),
      ),
    ];

    _requests = [
      FriendRequest.fromMap({
        'fromUid': 'u7',
        'toUid': 'me',
        'senderName': 'Jordan Lee',
        'status': 'pending',
        'timestamp': _ago(const Duration(hours: 4)),
      }, 'fr1'),
    ];

    _friends = [
      for (final f in const [
        ('u1', 'Alex Kim', 9, 6),
        ('u2', 'Mia Torres', 4, 3),
        ('u3', 'Noah Patel', 12, 8),
        ('u4', 'Lena Novak', 2, 2),
      ])
        Friend.fromMap({
          'uid': f.$1,
          'displayName': f.$2,
          'boardCount': f.$3,
          'friendCount': f.$4,
        }),
    ];

    InAppNotification n(String id, String type, String title, String body,
            Duration ago, {String? sender, bool read = false}) =>
        InAppNotification.fromMap({
          'uid': 'me',
          'type': type,
          'title': title,
          'body': body,
          'senderDisplayName': sender,
          'read': read,
          'timestamp': _ago(ago),
        }, id);

    _notifications = [
      n('n1', 'board_invite', 'Priya Shah invited you to a board',
          'Open-source logo jam', const Duration(hours: 1), sender: 'Priya Shah'),
      n('n2', 'mention', 'Alex Kim mentioned you',
          '"@Sam can you check the timeline?" on Q3 roadmap',
          const Duration(hours: 3), sender: 'Alex Kim'),
      n('n3', 'workspace_invite', 'Alex Kim invited you to a workspace',
          'Invitation to join "Design Team"', const Duration(days: 1),
          sender: 'Alex Kim', read: true),
      n('n4', 'role_updated', 'Your role changed', 'You are now an editor on Sprint retro',
          const Duration(days: 3), read: true),
      n('n5', 'friend_request_accepted', 'Mia Torres accepted your friend request',
          'You are now friends on InkLink.', const Duration(days: 9),
          sender: 'Mia Torres', read: true),
    ];
  }

  Stream<T> _live<T>(StreamController<T> ctl, T Function() value) async* {
    yield value();
    yield* ctl.stream;
  }

  // ── Auth ────────────────────────────────────────────────────────────────

  @override
  Stream<WebAccount?> get authChanges async* {
    yield _account;
    yield* _authController.stream;
  }

  @override
  WebAccount? get currentUser => _account;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (password.length < 6) throw 'Incorrect email or password.';
    _account = _sampleAccount;
    _authController.add(_account);
  }

  @override
  Future<void> signInWithGoogle() => signInWithEmail('', 'preview');

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> resendVerificationEmail() async {}

  @override
  Future<bool> reloadEmailVerified() async => true;

  @override
  Future<void> signOut() async {
    _account = null;
    _authController.add(null);
  }

  // ── Data ────────────────────────────────────────────────────────────────

  @override
  Stream<UserModel?> watchMyProfile() => _live(_profileCtl, () => _profile);

  @override
  Future<void> updateProfile({required String name, required String bio}) async {
    _profile = UserModel.fromFirestore({
      ..._profile.toMap(),
      'displayName': name.trim(),
      'bio': bio.trim(),
    }, 'me');
    _profileCtl.add(_profile);
  }

  @override
  Stream<List<Board>> watchMyBoards() => _live(_boardsCtl, () => List.of(_myBoards));

  @override
  Future<List<Board>> loadPublicBoards({int limit = 40}) async =>
      _publicBoards.take(limit).toList();

  // Two workspaces: one owned, one shared, each with a few sample boards.
  late final List<(Workspace, List<String>)> _workspaces = [
    (
      Workspace(
        id: 'w-product',
        ownerId: 'me',
        name: 'Product Team',
        description: 'Roadmaps, wireframes and retros.',
        memberCount: 4,
        boardCount: 3,
        createdAt: _now.subtract(const Duration(days: 60)),
        updatedAt: _now.subtract(const Duration(minutes: 12)),
        currentUserRole: 'owner',
      ),
      const ['b1', 'b2', 'b3'],
    ),
    (
      Workspace(
        id: 'w-home',
        ownerId: 'u3',
        name: 'Home Projects',
        description: 'Shared with Noah.',
        memberCount: 2,
        boardCount: 1,
        createdAt: _now.subtract(const Duration(days: 20)),
        updatedAt: _now.subtract(const Duration(days: 5)),
        currentUserRole: 'member',
      ),
      const ['b5'],
    ),
  ];

  @override
  Stream<List<Workspace>> watchMyWorkspaces() =>
      Stream.value([for (final (w, _) in _workspaces) w]);

  @override
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) {
    final ids = _workspaces
            .where((e) => e.$1.id == workspaceId)
            .firstOrNull
            ?.$2 ??
        const <String>[];
    return Stream.value(
      [for (final id in ids) ..._myBoards.where((b) => b.id == id)],
    );
  }

  @override
  Stream<List<BoardInvitation>> watchBoardInvites() =>
      _live(_boardInvitesCtl, () => List.of(_boardInvites));

  @override
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites() =>
      _live(_wsInvitesCtl, () => List.of(_workspaceInvites));

  @override
  Future<void> acceptBoardInvite(String inviteId) async {
    _boardInvites.removeWhere((i) => i.id == inviteId);
    _boardInvitesCtl.add(List.of(_boardInvites));
  }

  @override
  Future<void> declineBoardInvite(String inviteId) => acceptBoardInvite(inviteId);

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) async {
    _workspaceInvites.removeWhere((i) => i.id == inviteId);
    _wsInvitesCtl.add(List.of(_workspaceInvites));
  }

  @override
  Future<void> declineWorkspaceInvite(String inviteId) => acceptWorkspaceInvite(inviteId);

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() =>
      _live(_requestsCtl, () => List.of(_requests));

  @override
  Stream<List<Friend>> watchFriends() => _live(_friendsCtl, () => List.of(_friends));

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    final request = _requests.where((r) => r.id == requestId).firstOrNull;
    _requests.removeWhere((r) => r.id == requestId);
    _requestsCtl.add(List.of(_requests));
    if (request != null) {
      _friends.add(Friend.fromMap({'uid': request.fromUid, 'displayName': request.senderName}));
      _friendsCtl.add(List.of(_friends));
    }
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    _requests.removeWhere((r) => r.id == requestId);
    _requestsCtl.add(List.of(_requests));
  }

  @override
  Stream<List<InAppNotification>> watchNotifications() =>
      _live(_notificationsCtl, () => List.of(_notifications));

  @override
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationsCtl.add(List.of(_notifications));
  }
}
