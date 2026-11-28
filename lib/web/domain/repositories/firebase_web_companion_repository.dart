import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/firestore_batch_fetcher.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/friends/friend.dart';
import '../../../domain/models/friends/friend_request.dart';
import '../../../domain/models/invitation/board_invitation.dart';
import '../../../domain/models/notification/in_app_notification.dart';
import '../../../domain/models/user_model.dart';
import '../../../domain/models/workspace.dart';
import '../../../domain/repositories/board/board_repository.dart';
import '../../../domain/repositories/notification/notification_repository.dart';
import '../../core/web_stream_utils.dart';
import '../models/user_board_index.dart';
import '../models/web_account.dart';
import '../models/web_account_settings.dart';
import '../models/web_notification_rules.dart';
import 'web_auth_profile_data_source.dart';
import 'web_board_repository.dart';
import 'web_companion_repository.dart';
import 'web_notification_repository.dart';
import 'web_social_data_source.dart';
import 'web_workspace_data_source.dart';

/// Pure Firebase + browser-preferences implementation of
/// [WebCompanionRepository].
///
/// Composes focused data sources ([WebAuthProfileDataSource],
/// [WebWorkspaceDataSource], [WebSocialDataSource]) and delegates shared board
/// and notification operations to [BoardRepository] (`WebBoardRepository`) and
/// [NotificationRepository] (`WebNotificationRepository`). Contains **no Cloud
/// Functions calls**: privileged operations live in `WebCompanionServiceImpl`
/// and shared `BoardService`.
class FirebaseWebCompanionRepository implements WebCompanionRepository {
  final AuthService _auth;
  final FirestoreService _firestore;
  final BoardRepository _boardRepository;
  late final WebAuthProfileDataSource _authProfile;
  late final WebWorkspaceDataSource _workspaces;
  late final WebSocialDataSource _social;

  Stream<UserBoardIndex>? _boardIndexStream;
  String? _boardIndexUid;

  FirebaseWebCompanionRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
    BoardRepository? boardRepository,
    NotificationRepository? notificationRepository,
  }) : _auth = authService,
       _firestore = firestoreService,
       _boardRepository =
           boardRepository ??
           WebBoardRepository(
             authService: authService,
             firestoreService: firestoreService,
           ) {
    final notifRepo =
        notificationRepository ??
        WebNotificationRepository(
          authService: authService,
          firestoreService: firestoreService,
        );
    final batchFetcher = FirestoreBatchFetcher(
      firestoreService: firestoreService,
    );
    _authProfile = WebAuthProfileDataSource(
      authService: authService,
      firestoreService: firestoreService,
    );
    _workspaces = WebWorkspaceDataSource(
      authService: authService,
      firestoreService: firestoreService,
      batchFetcher: batchFetcher,
      boardIndexForUser: _myBoardIndex,
    );
    _social = WebSocialDataSource(
      authService: authService,
      firestoreService: firestoreService,
      notificationRepository: notifRepo,
    );
  }

  String? get _uid => _auth.getCurrentUserId();

  /// Shared `users/{uid}/boards` index stream reused by the boards list and
  /// every workspace card.
  Stream<UserBoardIndex> _myBoardIndex(String uid) {
    if (_boardIndexStream == null || _boardIndexUid != uid) {
      _boardIndexUid = uid;
      _boardIndexStream = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.userBoardsSubcollection)
          .snapshots()
          .map(
            (snapshot) => UserBoardIndex.fromDocs(
              snapshot.docs.map((d) => MapEntry(d.id, d.data())),
            ),
          )
          .asBroadcastStream();
    }
    return _boardIndexStream!;
  }

  // ── Auth & Profile ──────────────────────────────────────────────────────

  @override
  Stream<WebAccount?> get authChanges => _authProfile.authChanges;

  @override
  WebAccount? get currentUser => _authProfile.currentUser;

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _authProfile.signInWithEmail(email, password);

  @override
  Future<void> signInWithGoogle() => _authProfile.signInWithGoogle();

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) => _authProfile.signUpWithEmail(
    name: name,
    email: email,
    password: password,
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      _authProfile.sendPasswordReset(email);

  @override
  Future<void> resendVerificationEmail() =>
      _authProfile.resendVerificationEmail();

  @override
  Future<bool> reloadEmailVerified() => _authProfile.reloadEmailVerified();

  @override
  Future<void> signOut() => _authProfile.signOut();

  @override
  Stream<UserModel?> watchMyProfile() => _authProfile.watchMyProfile();

  @override
  Future<void> updateProfile({required String name, required String bio}) =>
      _authProfile.updateProfile(name: name, bio: bio);

  @override
  Stream<WebAccountSettings> watchAccountSettings() =>
      _authProfile.watchAccountSettings();

  @override
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) => _authProfile.updatePrivacySettings(
    isProfilePublic: isProfilePublic,
    showOnlineStatus: showOnlineStatus,
    showEmail: showEmail,
  );

  @override
  Future<void> updatePreferredTags(List<String> tags) =>
      _authProfile.updatePreferredTags(tags);

  // ── Boards ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Board>> watchMyBoards() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _myBoardIndex(uid).asyncMap((index) async {
      final boards = await _fetchBoards(index.all.toList());
      final joinedIds = [
        for (final b in boards)
          if (b.ownerId != uid) b.id,
      ];
      final roles = await _joinedRoles(uid, joinedIds);
      return boards
          .map(
            (b) => b.copyWith(
              currentUserRole: index.owned.contains(b.id) || b.ownerId == uid
                  ? Board.roleOwner
                  : (roles[b.id] ?? b.currentUserRole),
            ),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<Map<String, String>> _joinedRoles(
    String uid,
    List<String> boardIds,
  ) async {
    final roles = <String, String>{};
    for (final batch in chunked(boardIds, FirestoreBatchFetcher.chunkSize)) {
      await Future.wait([
        for (final id in batch)
          () async {
            try {
              final member = await _firestore
                  .collection(FirestorePaths.boards)
                  .doc(id)
                  .collection(FirestorePaths.boardMembersSubcollection)
                  .doc(uid)
                  .get();
              final role = member.data()?['role'];
              if (role is String && role.isNotEmpty) roles[id] = role;
            } catch (_) {}
          }(),
      ]);
    }
    return roles;
  }

  Future<List<Board>> _fetchBoards(List<String> ids) async {
    final boards = <Board>[];
    for (final batch in chunked(ids, FirestoreBatchFetcher.chunkSize)) {
      final snap = await _firestore
          .collection(FirestorePaths.boards)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        boards.add(Board.fromMap(doc.data(), doc.id));
      }
    }
    return boards;
  }

  @override
  Future<List<Board>> loadPublicBoards({int limit = 40}) async {
    final page = await _boardRepository.getPublicBoards(limit: limit);
    return List<Board>.of(page.boards)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<String> createBoard({
    required String name,
    String visibility = Board.visibilityPrivate,
    String privateJoinPolicy = Board.policyOwnerOnlyInvite,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
  }) => _boardRepository.createNewBoard(
    name: name,
    visibility: visibility,
    privateJoinPolicy: privateJoinPolicy,
    whoCanInvite: whoCanInvite,
    defaultLinkJoinRole: defaultLinkJoinRole,
    tags: tags,
    allowMembersToCopy: allowMembersToCopy,
  );

  @override
  Future<void> renameBoard(String boardId, String newName) =>
      _boardRepository.renameBoard(boardId, newName);

  @override
  Future<void> setBoardArchived(String boardId, {required bool archived}) =>
      archived
      ? _boardRepository.archiveBoard(boardId)
      : _boardRepository.unarchiveBoard(boardId);

  @override
  Future<void> duplicateBoard(String boardId, {String? customTitle}) async {
    await _boardRepository.duplicateBoard(boardId, customTitle: customTitle);
  }

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) =>
      _boardRepository.updateBoardTags(boardId, tags);

  // ── Workspaces ──────────────────────────────────────────────────────────

  @override
  Stream<List<Workspace>> watchMyWorkspaces() =>
      _workspaces.watchMyWorkspaces();

  @override
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) =>
      _workspaces.watchWorkspaceBoards(workspaceId);

  @override
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId) =>
      _workspaces.watchWorkspaceMembers(workspaceId);

  @override
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) => _workspaces.updateWorkspaceMemberRole(
    workspaceId: workspaceId,
    memberUid: memberUid,
    role: role,
  );

  @override
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  }) => _workspaces.removeWorkspaceMember(
    workspaceId: workspaceId,
    memberUid: memberUid,
  );

  // ── Invites, Friends & Notifications ────────────────────────────────────

  @override
  Stream<List<BoardInvitation>> watchBoardInvites() =>
      _social.watchBoardInvites();

  @override
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites() =>
      _social.watchWorkspaceInvites();

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() =>
      _social.watchIncomingFriendRequests();

  @override
  Stream<List<Friend>> watchFriends() => _social.watchFriends();

  @override
  Future<List<Friend>> searchUsersByEmail(String email) =>
      _social.searchUsersByEmail(email);

  @override
  Stream<List<Friend>> watchBlockedUsers() => _social.watchBlockedUsers();

  @override
  Stream<List<InAppNotification>> watchNotifications() =>
      _social.watchNotifications();

  @override
  Future<void> deleteNotification(String notificationId) =>
      _social.deleteNotification(notificationId);

  @override
  Stream<List<InAppNotification>> watchNotificationsWithReadState() =>
      combineLatest2(
        watchNotifications(),
        watchReadNotificationIds(),
        applyReadState,
      );

  @override
  Stream<Set<String>> watchReadNotificationIds() =>
      _social.watchReadNotificationIds();

  @override
  Future<void> markNotificationRead(String id) =>
      _social.markNotificationRead(id);

  @override
  Future<void> markAllNotificationsRead(Iterable<String> ids) =>
      _social.markAllNotificationsRead(ids);
}
