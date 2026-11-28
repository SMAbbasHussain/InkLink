import 'dart:async';
import 'dart:typed_data';

import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/friends/friend.dart';
import 'package:inklink/domain/models/friends/friend_request.dart';
import 'package:inklink/domain/models/invitation/board_invitation.dart';
import 'package:inklink/domain/models/notification/in_app_notification.dart';
import 'package:inklink/domain/models/user_model.dart';
import 'package:inklink/domain/models/workspace.dart';
import 'package:inklink/web/data/web_account.dart';
import 'package:inklink/web/data/web_account_settings.dart';
import 'package:inklink/web/data/web_board_ops.dart';
import 'package:inklink/web/data/web_mappers.dart';
import 'package:inklink/web/data/web_workspace_ops.dart';
import 'package:inklink/web/domain/web_companion_service.dart';

/// Test-only in-memory implementation of [WebCompanionService] for widget and
/// Cubit tests without live Firebase backends.
class FakeWebCompanionService implements WebCompanionService {
  FakeWebCompanionService({bool signedIn = true, DateTime? now})
    : _now = now ?? DateTime.now() {
    if (signedIn) _account = _defaultAccount;
    _seed();
  }

  final DateTime _now;
  WebAccount? _account;
  final _authController = StreamController<WebAccount?>.broadcast();

  static const _defaultAccount = WebAccount(
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
  late List<Friend> _blocked;
  late List<Friend> _directory;
  late List<InAppNotification> _notifications;
  late List<(Workspace, List<String>)> _workspaces;
  final Set<String> _readIds = <String>{};
  late Map<String, List<WorkspaceMember>> _workspaceMembers;
  final Map<String, Set<String>> _sentWorkspaceInvites = {};
  WebAccountSettings _accountSettings = WebAccountSettings.defaults;
  final Set<String> _sentRequests = <String>{};
  int _idCounter = 0;

  final _profileCtl = StreamController<UserModel?>.broadcast();
  final _boardsCtl = StreamController<List<Board>>.broadcast();
  final _boardInvitesCtl = StreamController<List<BoardInvitation>>.broadcast();
  final _wsInvitesCtl = StreamController<List<WorkspaceInvite>>.broadcast();
  final _requestsCtl = StreamController<List<FriendRequest>>.broadcast();
  final _friendsCtl = StreamController<List<Friend>>.broadcast();
  final _blockedCtl = StreamController<List<Friend>>.broadcast();
  final _notificationsCtl =
      StreamController<List<InAppNotification>>.broadcast();
  final _readIdsCtl = StreamController<Set<String>>.broadcast();
  final _workspacesCtl = StreamController<List<Workspace>>.broadcast();
  final _workspaceMembersCtl = StreamController<void>.broadcast();
  final _accountSettingsCtl = StreamController<WebAccountSettings>.broadcast();

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
    bool paused = false,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    bool allowMembersToCopy = false,
    String currentUserRole = Board.roleOwner,
  }) => Board.fromMap({
    'title': title,
    'ownerId': ownerId,
    'members': members,
    'membersCount': members.length,
    'visibility': visibility,
    'tags': tags,
    'isArchived': archived,
    'isPaused': paused,
    'joinViaCodeEnabled': visibility == 'public',
    'invitePolicy': {
      'whoCanInvite': whoCanInvite,
      'defaultLinkJoinRole': defaultLinkJoinRole,
    },
    'allowMembersToCopy': allowMembersToCopy,
    'createdAt': _ago(const Duration(days: 30)),
    'updatedAt': _ago(updated),
    'currentUserRole': currentUserRole,
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
      _board(
        'b1',
        'Q3 roadmap',
        members: const ['me', 'u1', 'u2', 'u3'],
        tags: const ['planning', 'team'],
        updated: const Duration(minutes: 12),
      ),
      _board(
        'b2',
        'Landing page wireframes',
        members: const ['me', 'u2'],
        visibility: 'public',
        tags: const ['design', 'web'],
        updated: const Duration(hours: 3),
      ),
      _board(
        'b3',
        'Sprint retro',
        ownerId: 'u1',
        members: const ['u1', 'me', 'u4'],
        tags: const ['team'],
        updated: const Duration(days: 1),
        currentUserRole: Board.roleEditor,
      ),
      _board(
        'b4',
        'Character sketches',
        members: const ['me'],
        visibility: 'public',
        tags: const ['art'],
        updated: const Duration(days: 2),
      ),
      _board(
        'b5',
        'Kitchen remodel ideas',
        ownerId: 'u3',
        members: const ['u3', 'me'],
        updated: const Duration(days: 5),
        currentUserRole: Board.roleViewer,
      ),
      _board(
        'b6',
        'Old brainstorm',
        members: const ['me', 'u1'],
        archived: true,
        updated: const Duration(days: 40),
      ),
    ];

    _publicBoards = [
      _myBoards[1],
      _myBoards[3],
      _board(
        'p1',
        'City sketch walk',
        ownerId: 'u5',
        members: const ['u5', 'u6', 'u7'],
        visibility: 'public',
        tags: const ['art', 'travel'],
        updated: const Duration(hours: 5),
        currentUserRole: Board.roleViewer,
      ),
      _board(
        'p2',
        'Open-source logo jam',
        ownerId: 'u6',
        members: const ['u6', 'u8'],
        visibility: 'public',
        tags: const ['design', 'logo'],
        updated: const Duration(days: 1),
        currentUserRole: Board.roleViewer,
      ),
      _board(
        'p3',
        'Physics study notes',
        ownerId: 'u7',
        members: const ['u7'],
        visibility: 'public',
        tags: const ['study'],
        updated: const Duration(days: 3),
        currentUserRole: Board.roleViewer,
      ),
      _board(
        'p4',
        'Board game prototype',
        ownerId: 'u8',
        members: const ['u8', 'u5'],
        visibility: 'public',
        tags: const ['games', 'design'],
        updated: const Duration(days: 4),
        currentUserRole: Board.roleViewer,
      ),
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

    _directory = [
      for (final f in const [
        ('u1', 'Alex Kim', 'alex.kim@example.com'),
        ('u2', 'Mia Torres', 'mia.torres@example.com'),
        ('u3', 'Noah Patel', 'noah.patel@example.com'),
        ('u4', 'Lena Novak', 'lena.novak@example.com'),
        ('u5', 'Priya Shah', 'priya.shah@example.com'),
        ('u6', 'Omar Haddad', 'omar.haddad@example.com'),
        ('u7', 'Jordan Lee', 'jordan.lee@example.com'),
        ('u8', 'Elena Rossi', 'elena.rossi@example.com'),
      ])
        Friend.fromMap({
          'uid': f.$1,
          'displayName': f.$2,
          'email': f.$3,
          'boardCount': f.$1.hashCode.abs() % 10 + 1,
          'friendCount': f.$1.hashCode.abs() % 6 + 1,
        }),
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

    _blocked = [];

    InAppNotification n(
      String id,
      String type,
      String title,
      String body,
      Duration ago, {
      String? sender,
      bool read = false,
    }) => InAppNotification.fromMap({
      'uid': 'me',
      'type': type,
      'title': title,
      'body': body,
      'senderDisplayName': sender,
      'read': read,
      'timestamp': _ago(ago),
    }, id);

    _notifications = [
      n(
        'n1',
        'board_invite',
        'Priya Shah invited you to a board',
        'Open-source logo jam',
        const Duration(hours: 1),
        sender: 'Priya Shah',
      ),
      n(
        'n2',
        'mention',
        'Alex Kim mentioned you',
        '"@Sam can you check the timeline?" on Q3 roadmap',
        const Duration(hours: 3),
        sender: 'Alex Kim',
      ),
      n(
        'n3',
        'workspace_invite',
        'Alex Kim invited you to a workspace',
        'Invitation to join "Design Team"',
        const Duration(days: 1),
        sender: 'Alex Kim',
        read: true,
      ),
      n(
        'n4',
        'role_updated',
        'Your role changed',
        'You are now an editor on Sprint retro',
        const Duration(days: 3),
        read: true,
      ),
      n(
        'n5',
        'friend_request_accepted',
        'Mia Torres accepted your friend request',
        'You are now friends on InkLink.',
        const Duration(days: 9),
        sender: 'Mia Torres',
        read: true,
      ),
    ];

    _workspaces = [
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
        <String>['b1', 'b2', 'b3'],
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
        <String>['b5'],
      ),
    ];

    _workspaceMembers = {
      'w-product': [
        _member('me', 'owner', 'Sam Rivera', 'sam.rivera@example.com'),
        _member('u2', 'editor', 'Alex Kim', 'alex.kim@example.com'),
        _member('u3', 'member', 'Noah Patel', 'noah.patel@example.com'),
        _member('u4', 'viewer', 'Mia Torres', 'mia.torres@example.com'),
      ],
      'w-home': [
        _member('u3', 'owner', 'Noah Patel', 'noah.patel@example.com'),
        _member('me', 'member', 'Sam Rivera', 'sam.rivera@example.com'),
      ],
    };
  }

  WorkspaceMember _member(String uid, String role, String name, String email) =>
      WorkspaceMember(
        uid: uid,
        role: role,
        status: 'active',
        joinedAt: _now.subtract(const Duration(days: 30)),
        displayName: name,
        email: email,
      );

  Stream<T> _live<T>(StreamController<T> ctl, T Function() value) async* {
    yield value();
    yield* ctl.stream;
  }

  void _emitBoards() => _boardsCtl.add(List.of(_myBoards));

  Board? _boardById(String id) =>
      _myBoards.where((b) => b.id == id).firstOrNull;

  void _replaceBoard(String id, Board Function(Board board) update) {
    final index = _myBoards.indexWhere((b) => b.id == id);
    if (index < 0) return;
    _myBoards[index] = update(_myBoards[index]);
    _emitBoards();
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
    if (password.length < 6) throw 'Incorrect email or password.';
    _account = _defaultAccount;
    _authController.add(_account);
  }

  @override
  Future<void> signInWithGoogle() => signInWithEmail('', 'secret12');

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw 'Please enter your name.';
    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.contains('@')) {
      throw 'That email address is not valid.';
    }
    if (password.length < 6) {
      throw 'Use at least 6 characters for your password.';
    }
    if (normalizedEmail == _defaultAccount.email) {
      throw 'An account already exists for that email. Sign in instead.';
    }
    _account = WebAccount(
      uid: 'new-user',
      email: normalizedEmail,
      displayName: trimmedName,
      emailVerified: false,
      usesPassword: true,
    );
    _authController.add(_account);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> resendVerificationEmail() async {}

  @override
  Future<bool> reloadEmailVerified() async {
    final account = _account;
    if (account == null) return false;
    if (!account.emailVerified) {
      _account = WebAccount(
        uid: account.uid,
        email: account.email,
        displayName: account.displayName,
        emailVerified: true,
        usesPassword: account.usesPassword,
      );
      _authController.add(_account);
    }
    return true;
  }

  @override
  Future<void> signOut() async {
    _account = null;
    _authController.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    await signOut();
  }

  // ── Profile & Account Settings ──────────────────────────────────────────

  @override
  Stream<UserModel?> watchMyProfile() => _live(_profileCtl, () => _profile);

  @override
  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {
    _profile = UserModel.fromFirestore({
      ..._profile.toMap(),
      'displayName': name.trim(),
      'bio': bio.trim(),
    }, 'me');
    _profileCtl.add(_profile);
  }

  @override
  Future<void> uploadProfilePhoto(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (bytes.isEmpty) throw 'That image could not be read.';
    _profile = UserModel.fromFirestore({
      ..._profile.toMap(),
      'photoURL': 'https://example.com/profile/$filename',
    }, 'me');
    _profileCtl.add(_profile);
  }

  @override
  Stream<WebAccountSettings> watchAccountSettings() =>
      _live(_accountSettingsCtl, () => _accountSettings);

  @override
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) async {
    _accountSettings = _accountSettings.copyWith(
      isProfilePublic: isProfilePublic,
      showOnlineStatus: showOnlineStatus,
      showEmail: showEmail,
    );
    _accountSettingsCtl.add(_accountSettings);
  }

  @override
  Future<void> updatePreferredTags(List<String> tags) async {
    _accountSettings = _accountSettings.copyWith(preferredTags: List.of(tags));
    _accountSettingsCtl.add(_accountSettings);
  }

  // ── Boards ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Board>> watchMyBoards() =>
      _live(_boardsCtl, () => List.of(_myBoards));

  @override
  Future<List<Board>> loadPublicBoards({int limit = 40}) async =>
      _publicBoards.take(limit).toList();

  @override
  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  }) async {
    final id = 'new-${++_idCounter}';
    final fields = newBoardFields(
      boardId: id,
      uid: 'me',
      name: name,
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      tags: tags,
      allowMembersToCopy: allowMembersToCopy,
    );
    _myBoards.insert(
      0,
      Board.fromMap({
        ...fields,
        'createdAt': _ago(Duration.zero),
        'updatedAt': _ago(Duration.zero),
        'currentUserRole': Board.roleOwner,
      }, id),
    );
    _emitBoards();
    return id;
  }

  @override
  Future<void> joinBoard(String boardIdOrCode) async {
    final id = boardIdOrCode.trim();
    if (id.isEmpty) throw 'Please enter a join code.';
    final existing = _boardById(id);
    if (existing != null) {
      if (existing.members.contains('me')) return;
      _replaceBoard(
        id,
        (b) => b.copyWith(
          members: [...b.members, 'me'],
          membersCount: b.membersCount + 1,
        ),
      );
      return;
    }
    final publicBoard = _publicBoards.where((b) => b.id == id).firstOrNull;
    if (publicBoard == null) {
      throw 'Board not found. Check the join code and try again.';
    }
    _myBoards.insert(
      0,
      publicBoard.copyWith(
        members: [...publicBoard.members, 'me'],
        membersCount: publicBoard.membersCount + 1,
        currentUserRole: Board.roleViewer,
      ),
    );
    _emitBoards();
  }

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    final title = normalizeBoardName(newName);
    _replaceBoard(boardId, (b) => b.copyWith(title: title));
  }

  @override
  Future<void> setBoardArchived(
    String boardId, {
    required bool archived,
  }) async {
    _replaceBoard(boardId, (b) => b.copyWith(isArchived: archived));
  }

  @override
  Future<void> setBoardPaused(String boardId, {required bool paused}) async {
    _replaceBoard(boardId, (b) => b.copyWith(isPaused: paused));
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    _myBoards.removeWhere((b) => b.id == boardId);
    _emitBoards();
  }

  @override
  Future<void> duplicateBoard(String boardId, {String? customTitle}) async {
    final source = _boardById(boardId);
    if (source == null) throw 'Board not found.';
    final id = 'copy-${++_idCounter}';
    final fields = duplicatedBoardFields(
      source.toMap(),
      newBoardId: id,
      uid: 'me',
      customTitle: customTitle,
    );
    _myBoards.insert(
      0,
      Board.fromMap({
        ...fields,
        'createdAt': _ago(Duration.zero),
        'updatedAt': _ago(Duration.zero),
        'currentUserRole': Board.roleOwner,
      }, id),
    );
    _emitBoards();
  }

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) async {
    _replaceBoard(boardId, (b) => b.copyWith(tags: normalizeBoardTags(tags)));
  }

  @override
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  }) async {
    final fields = boardSettingsFields(
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      allowMembersToCopy: allowMembersToCopy,
    );
    _replaceBoard(
      boardId,
      (b) => b.copyWith(
        visibility: fields['visibility'] as String,
        privateJoinPolicy: fields['privateJoinPolicy'] as String,
        joinViaCodeEnabled: fields['joinViaCodeEnabled'] as bool,
        whoCanInvite: whoCanInvite,
        defaultLinkJoinRole: defaultLinkJoinRole,
        allowMembersToCopy: allowMembersToCopy,
      ),
    );
  }

  // ── Workspaces ──────────────────────────────────────────────────────────

  @override
  Stream<List<Workspace>> watchMyWorkspaces() =>
      _live(_workspacesCtl, () => [for (final (w, _) in _workspaces) w]);

  @override
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) {
    final ids =
        _workspaces.where((e) => e.$1.id == workspaceId).firstOrNull?.$2 ??
        const <String>[];
    return Stream.value([
      for (final id in ids) ..._myBoards.where((b) => b.id == id),
    ]);
  }

  void _emitWorkspaces() =>
      _workspacesCtl.add([for (final (w, _) in _workspaces) w]);

  @override
  Future<String> createWorkspace({
    required String name,
    required String description,
  }) async {
    final id = 'ws-${++_idCounter}';
    _workspaces.insert(0, (
      Workspace(
        id: id,
        ownerId: 'me',
        name: name.trim(),
        description: description.trim(),
        memberCount: 1,
        boardCount: 0,
        createdAt: _now,
        updatedAt: _now,
        currentUserRole: 'owner',
      ),
      <String>[],
    ));
    _emitWorkspaces();
    return id;
  }

  @override
  Future<void> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  }) async {
    final index = _workspaces.indexWhere((e) => e.$1.id == workspaceId);
    if (index < 0) return;
    final (workspace, boards) = _workspaces[index];
    final trimmedName = name?.trim();
    _workspaces[index] = (
      workspace.copyWith(
        name: trimmedName?.isNotEmpty == true ? trimmedName : null,
        description: description?.trim(),
        updatedAt: _now,
      ),
      boards,
    );
    _emitWorkspaces();
  }

  @override
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  }) async {
    final index = _workspaces.indexWhere((e) => e.$1.id == workspaceId);
    if (index < 0 || _boardById(boardId) == null) return;
    final (workspace, boards) = _workspaces[index];
    if (boards.contains(boardId)) return;
    final next = [...boards, boardId];
    _workspaces[index] = (
      workspace.copyWith(boardCount: next.length, updatedAt: _now),
      next,
    );
    _emitWorkspaces();
  }

  @override
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  }) async {
    final index = _workspaces.indexWhere((e) => e.$1.id == workspaceId);
    if (index < 0) return;
    final (workspace, boards) = _workspaces[index];
    final next = boards.where((id) => id != boardId).toList();
    _workspaces[index] = (
      workspace.copyWith(boardCount: next.length, updatedAt: _now),
      next,
    );
    _emitWorkspaces();
  }

  @override
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(
    String workspaceId,
  ) async* {
    yield _membersOf(workspaceId);
    yield* _workspaceMembersCtl.stream.map((_) => _membersOf(workspaceId));
  }

  List<WorkspaceMember> _membersOf(String workspaceId) =>
      sortWorkspaceMembers(_workspaceMembers[workspaceId] ?? const []);

  Workspace? _workspaceById(String id) =>
      _workspaces.where((entry) => entry.$1.id == id).firstOrNull?.$1;

  void _requireWorkspaceOwner(String workspaceId, String action) {
    final workspace = _workspaceById(workspaceId);
    if (workspace == null) throw 'Workspace not found.';
    if (workspace.ownerId != _account?.uid) {
      throw 'Only the workspace owner can $action.';
    }
  }

  void _setWorkspaceMemberCount(String workspaceId, int count) {
    final index = _workspaces.indexWhere((entry) => entry.$1.id == workspaceId);
    if (index < 0) return;
    final (workspace, boards) = _workspaces[index];
    _workspaces[index] = (
      workspace.copyWith(memberCount: count, updatedAt: _now),
      boards,
    );
    _emitWorkspaces();
  }

  @override
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) async {
    _requireWorkspaceOwner(workspaceId, 'change member roles');
    final normalized = role.trim().toLowerCase();
    if (!isAssignableWorkspaceRole(normalized)) {
      throw 'Choose a valid workspace role.';
    }
    final members = _workspaceMembers[workspaceId] ?? const <WorkspaceMember>[];
    final index = members.indexWhere((member) => member.uid == memberUid);
    if (index < 0) throw 'That member is no longer in this workspace.';
    if (members[index].role == 'owner') {
      throw "The workspace owner's role cannot be changed.";
    }
    _workspaceMembers[workspaceId] = List<WorkspaceMember>.of(members)
      ..[index] = members[index].copyWith(role: normalized);
    _workspaceMembersCtl.add(null);
  }

  @override
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  }) async {
    _requireWorkspaceOwner(workspaceId, 'remove members');
    final workspace = _workspaceById(workspaceId)!;
    final members = _workspaceMembers[workspaceId] ?? const <WorkspaceMember>[];
    final index = members.indexWhere((member) => member.uid == memberUid);
    if (index < 0) throw 'That member is no longer in this workspace.';
    if (members[index].role == 'owner' || memberUid == workspace.ownerId) {
      throw 'The workspace owner cannot be removed.';
    }
    _workspaceMembers[workspaceId] = List<WorkspaceMember>.of(members)
      ..removeAt(index);
    _setWorkspaceMemberCount(workspaceId, members.length - 1);
    _workspaceMembersCtl.add(null);
  }

  @override
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> userIds,
  }) async {
    _requireWorkspaceOwner(workspaceId, 'invite members');
    final members = _workspaceMembers[workspaceId] ?? const <WorkspaceMember>[];
    final memberUids = {for (final member in members) member.uid};
    final invited = _sentWorkspaceInvites.putIfAbsent(
      workspaceId,
      () => <String>{},
    );
    var added = 0;
    for (final raw in userIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      final user = _directory
          .where((candidate) => candidate.uid == id)
          .firstOrNull;
      if (user == null) throw 'No user found with that id.';
      if (memberUids.contains(id) || invited.contains(id)) continue;
      invited.add(id);
      added++;
    }
    if (added == 0) throw 'Everyone you picked is already in this workspace.';
  }

  @override
  Future<void> leaveWorkspace(String workspaceId) async {
    final workspace = _workspaceById(workspaceId);
    if (workspace == null) throw 'Workspace not found.';
    final uid = _account?.uid;
    if (uid == null) throw 'Please sign in again.';
    if (workspace.ownerId == uid) {
      throw 'The workspace owner cannot leave; delete the workspace instead.';
    }
    _workspaceMembers[workspaceId] = [
      for (final member in _workspaceMembers[workspaceId] ?? const [])
        if (member.uid != uid) member,
    ];
    _workspaces.removeWhere((entry) => entry.$1.id == workspaceId);
    _workspaceMembersCtl.add(null);
    _emitWorkspaces();
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    _requireWorkspaceOwner(workspaceId, 'delete the workspace');
    _workspaces.removeWhere((entry) => entry.$1.id == workspaceId);
    _workspaceMembers.remove(workspaceId);
    _workspaceMembersCtl.add(null);
    _emitWorkspaces();
  }

  // ── Invites ─────────────────────────────────────────────────────────────

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
  Future<void> declineBoardInvite(String inviteId) =>
      acceptBoardInvite(inviteId);

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) async {
    _workspaceInvites.removeWhere((i) => i.id == inviteId);
    _wsInvitesCtl.add(List.of(_workspaceInvites));
  }

  @override
  Future<void> declineWorkspaceInvite(String inviteId) =>
      acceptWorkspaceInvite(inviteId);

  // ── Friends ─────────────────────────────────────────────────────────────

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() =>
      _live(_requestsCtl, () => List.of(_requests));

  @override
  Stream<List<Friend>> watchFriends() =>
      _live(_friendsCtl, () => List.of(_friends));

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    final request = _requests.where((r) => r.id == requestId).firstOrNull;
    _requests.removeWhere((r) => r.id == requestId);
    _requestsCtl.add(List.of(_requests));
    if (request != null) {
      _friends.add(
        Friend.fromMap({
          'uid': request.fromUid,
          'displayName': request.senderName,
        }),
      );
      _friendsCtl.add(List.of(_friends));
    }
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    _requests.removeWhere((r) => r.id == requestId);
    _requestsCtl.add(List.of(_requests));
  }

  @override
  Future<List<Friend>> searchUsersByEmail(String email) async {
    final query = email.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final user in _directory)
        if ((user.email ?? '').toLowerCase() == query &&
            !_friends.any((f) => f.uid == user.uid))
          user,
    ];
  }

  @override
  Future<void> sendFriendRequest(String targetUid) async {
    if (_sentRequests.contains(targetUid)) {
      throw 'You already sent this person a request.';
    }
    _sentRequests.add(targetUid);
  }

  @override
  Future<void> unfriend(String targetUid) async {
    _friends.removeWhere((f) => f.uid == targetUid);
    _friendsCtl.add(List.of(_friends));
  }

  @override
  Stream<List<Friend>> watchBlockedUsers() =>
      _live(_blockedCtl, () => List.of(_blocked));

  @override
  Future<void> blockUser(String targetUid) async {
    final friend = _friends.where((f) => f.uid == targetUid).firstOrNull;
    _friends.removeWhere((f) => f.uid == targetUid);
    _friendsCtl.add(List.of(_friends));
    if (!_blocked.any((f) => f.uid == targetUid)) {
      _blocked.add(friend ?? Friend(uid: targetUid, displayName: targetUid));
      _blockedCtl.add(List.of(_blocked));
    }
  }

  @override
  Future<void> unblockUser(String targetUid) async {
    _blocked.removeWhere((f) => f.uid == targetUid);
    _blockedCtl.add(List.of(_blocked));
  }

  // ── Notifications ───────────────────────────────────────────────────────

  @override
  Stream<List<InAppNotification>> watchNotifications() =>
      _live(_notificationsCtl, () => List.of(_notifications));

  @override
  Stream<List<InAppNotification>> watchNotificationsWithReadState() =>
      combineLatest2(
        watchNotifications(),
        watchReadNotificationIds(),
        applyReadState,
      );

  @override
  Stream<Set<String>> watchReadNotificationIds() async* {
    yield {..._readIds};
    yield* _readIdsCtl.stream;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    if (id.isEmpty || !_readIds.add(id)) return;
    _readIdsCtl.add({..._readIds});
  }

  @override
  Future<void> markAllNotificationsRead(Iterable<String> ids) async {
    final before = _readIds.length;
    _readIds.addAll(ids.where((id) => id.isNotEmpty));
    if (_readIds.length != before) _readIdsCtl.add({..._readIds});
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    _notificationsCtl.add(List.of(_notifications));
    _readIds.remove(notificationId);
  }
}
