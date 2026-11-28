import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/firestore_batch_fetcher.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/notification_preferences.dart';
import '../../domain/models/board.dart';
import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/notification/in_app_notification.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import '../../domain/repositories/board/board_repository.dart';
import '../../domain/repositories/notification/notification_repository.dart';
import '../canvas/web_board_repository.dart';
import '../canvas/web_canvas_support.dart';
import 'web_account.dart';
import 'web_account_settings.dart';
import 'web_board_ops.dart';
import 'web_companion_repository.dart';
import 'web_mappers.dart';
import 'web_workspace_ops.dart';

/// Pure Firebase + browser-preferences implementation of
/// [WebCompanionRepository].
///
/// Delegates shared board persistence to [BoardRepository] (`WebBoardRepository`)
/// and notification deletion to [NotificationRepository]
/// (`WebNotificationRepository`), eliminating duplicated Firestore writes.
/// Contains **no Cloud Functions calls**: privileged operations live in
/// `WebCompanionServiceImpl` (and shared `BoardService`).
class FirebaseWebCompanionRepository implements WebCompanionRepository {
  final AuthService _auth;
  final FirestoreService _firestore;
  final BoardRepository _boardRepository;
  final NotificationRepository _notificationRepository;
  final FirestoreBatchFetcher _batchFetcher;

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
           ),
       _notificationRepository =
           notificationRepository ??
           WebNotificationRepository(
             authService: authService,
             firestoreService: firestoreService,
           ),
       _batchFetcher = FirestoreBatchFetcher(
         firestoreService: firestoreService,
       );

  /// Read notification ids for this browser, mirrored from mobile's
  /// `SharedPreferences` approach.
  NotificationPreferences? _notificationPrefs;
  Set<String>? _cachedReadIds;
  final _readIdsController = StreamController<Set<String>>.broadcast();

  Future<NotificationPreferences> _readPrefs() async => _notificationPrefs ??=
      NotificationPreferences(prefs: await SharedPreferences.getInstance());

  void _emitReadIds(Set<String> ids) {
    _cachedReadIds = ids;
    if (!_readIdsController.isClosed) _readIdsController.add(ids);
  }

  /// Shared `users/{uid}/boards` index stream reused by the boards list and
  /// every workspace card.
  Stream<UserBoardIndex>? _boardIndexStream;
  String? _boardIndexUid;

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

  // ── Auth ────────────────────────────────────────────────────────────────

  static WebAccount? _toAccount(User? user) => user == null
      ? null
      : WebAccount(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          emailVerified: user.emailVerified,
          usesPassword: user.providerData.any(
            (p) => p.providerId == 'password',
          ),
        );

  @override
  Stream<WebAccount?> get authChanges =>
      _auth.getInstance().authStateChanges().map(_toAccount);

  @override
  WebAccount? get currentUser => _toAccount(_auth.getCurrentUser());

  String? get _uid => _auth.getCurrentUserId();

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.getInstance().signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _requireExistingAccount();
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _auth.getInstance().signInWithPopup(GoogleAuthProvider());
      await _requireExistingAccount();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      throw _authMessage(e);
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw 'Please enter your name.';
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final credential = await _auth
          .getInstance()
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
      final user = credential.user;
      if (user == null) {
        throw 'Could not create your account. Please try again.';
      }
      try {
        await user.updateDisplayName(trimmedName);
      } catch (_) {}
      await _firestore.collection(FirestorePaths.users).doc(user.uid).set({
        FirestorePaths.uid: user.uid,
        FirestorePaths.email: normalizedEmail,
        FirestorePaths.displayName: trimmedName,
        FirestorePaths.photoURL: '',
        FirestorePaths.searchKeywords: generateSearchKeywords(trimmedName),
        FirestorePaths.friendCount: 0,
        FirestorePaths.boardCount: 0,
        FirestorePaths.createdAt: FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      try {
        await _auth.sendEmailVerification();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  Future<void> _requireExistingAccount() async {
    final uid = _uid;
    if (uid == null) return;
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();
    if (!doc.exists) {
      await signOut();
      throw 'No InkLink account found. Please create your account in the InkLink mobile app first.';
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  @override
  Future<void> resendVerificationEmail() => _auth.sendEmailVerification();

  @override
  Future<bool> reloadEmailVerified() async {
    final user = _auth.getCurrentUser();
    if (user == null) return false;
    await user.reload();
    return _auth.getCurrentUser()?.emailVerified ?? false;
  }

  @override
  Future<void> signOut() => _auth.getInstance().signOut();

  // ── Profile & Account Settings ──────────────────────────────────────────

  @override
  Stream<UserModel?> watchMyProfile() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? UserModel.fromFirestore(doc.data()!, uid) : null,
        );
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final trimmedName = name.trim();
    await _firestore.collection(FirestorePaths.users).doc(uid).update({
      FirestorePaths.displayName: trimmedName,
      FirestorePaths.bio: bio.trim(),
      FirestorePaths.searchKeywords: generateSearchKeywords(trimmedName),
    });
  }

  @override
  Stream<WebAccountSettings> watchAccountSettings() {
    final uid = _uid;
    if (uid == null) return Stream.value(WebAccountSettings.defaults);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .map((doc) => WebAccountSettings.fromMap(doc.data()));
  }

  @override
  Future<void> updatePrivacySettings({
    required bool isProfilePublic,
    required bool showOnlineStatus,
    required bool showEmail,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .update(
          const WebAccountSettings()
              .copyWith(
                isProfilePublic: isProfilePublic,
                showOnlineStatus: showOnlineStatus,
                showEmail: showEmail,
              )
              .privacyFields(),
        );
  }

  @override
  Future<void> updatePreferredTags(List<String> tags) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    await _firestore.collection(FirestorePaths.users).doc(uid).update({
      'preferredTags': List<String>.of(tags),
    });
  }

  // ── Boards (shared index + delegation to BoardRepository) ───────────────

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
  Stream<List<Workspace>> watchMyWorkspaces() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids =
              ((snapshot.data()?[FirestorePaths.workspaceIds] as List?) ??
                      const [])
                  .whereType<String>()
                  .where((id) => id.isNotEmpty)
                  .toList();
          if (ids.isEmpty) return const <Workspace>[];
          final result = await _batchFetcher.fetchDocumentsByIdSet(
            collectionPath: FirestorePaths.workspaces,
            ids: ids,
            trackMissingIds: false,
          );
          return [
            for (final entry in result.docsById.entries)
              _workspaceFrom(entry.key, entry.value, uid),
          ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });
  }

  Workspace _workspaceFrom(String id, Map<String, dynamic> data, String uid) {
    DateTime date(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();
    return Workspace(
      id: id,
      ownerId: (data[FirestorePaths.ownerId] as String?) ?? '',
      name: (data[FirestorePaths.name] as String?) ?? '',
      description: (data[FirestorePaths.description] as String?) ?? '',
      memberCount: (data[FirestorePaths.memberCount] as num?)?.toInt() ?? 0,
      boardCount: (data[FirestorePaths.boardCount] as num?)?.toInt() ?? 0,
      createdAt: date(data[FirestorePaths.createdAt]),
      updatedAt: date(data[FirestorePaths.updatedAt]),
      currentUserRole: data[FirestorePaths.ownerId] == uid ? 'owner' : 'member',
    );
  }

  @override
  Stream<List<Board>> watchWorkspaceBoards(String workspaceId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    final links = _firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceBoardsSubcollection)
        .snapshots();
    final combined =
        combineLatest2<
          QuerySnapshot<Map<String, dynamic>>,
          UserBoardIndex,
          (QuerySnapshot<Map<String, dynamic>>, UserBoardIndex)
        >(
          links,
          _myBoardIndex(uid),
          (linkSnapshot, index) => (linkSnapshot, index),
        );
    return combined.asyncMap((pair) async {
      final linkSnapshot = pair.$1;
      final index = pair.$2;
      final ids = visibleWorkspaceBoardIds(
        linkSnapshot.docs.map((d) => MapEntry(d.id, d.data())),
        index.all,
      );
      if (ids.isEmpty) return const <Board>[];
      final result = await _batchFetcher.fetchDocumentsByIdSet(
        collectionPath: FirestorePaths.boards,
        ids: ids,
        trackMissingIds: false,
      );
      return [
        for (final id in ids)
          if (result.docsById[id] case final data?)
            Board.fromMap(data, id).copyWith(
              currentUserRole:
                  index.owned.contains(id) ||
                      data[FirestorePaths.ownerId] == uid
                  ? Board.roleOwner
                  : null,
            ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  @override
  Stream<List<WorkspaceMember>> watchWorkspaceMembers(String workspaceId) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId)
        .collection(FirestorePaths.workspaceMembersSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final docs = snapshot.docs;
          final profiles = await _workspaceMemberProfiles([
            for (final doc in docs)
              (doc.data()[FirestorePaths.uid] as String?) ?? doc.id,
          ]);
          final members = <WorkspaceMember>[];
          for (final doc in docs) {
            final data = doc.data();
            final memberUid = (data[FirestorePaths.uid] as String?) ?? doc.id;
            final profile = profiles[memberUid];
            members.add(
              WorkspaceMember(
                uid: memberUid,
                role: (data['role'] as String?) ?? 'member',
                status: (data[FirestorePaths.status] as String?) ?? 'active',
                joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
                displayName: profile?[FirestorePaths.displayName] as String?,
                email: profile?[FirestorePaths.email] as String?,
                photoUrl: profile?[FirestorePaths.photoURL] as String?,
              ),
            );
          }
          return sortWorkspaceMembers(members);
        });
  }

  Future<Map<String, Map<String, dynamic>>> _workspaceMemberProfiles(
    List<String> uids,
  ) async {
    final profiles = <String, Map<String, dynamic>>{};
    await Future.wait([
      for (final id in uids)
        () async {
          try {
            final doc = await _firestore
                .collection(FirestorePaths.users)
                .doc(id)
                .get();
            final data = doc.data();
            if (data != null) profiles[id] = data;
          } on FirebaseException {
            // Keep the membership without a profile.
          }
        }(),
    ]);
    return profiles;
  }

  @override
  Future<void> updateWorkspaceMemberRole({
    required String workspaceId,
    required String memberUid,
    required String role,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final normalized = role.trim().toLowerCase();
    if (!isAssignableWorkspaceRole(normalized)) {
      throw 'Choose a valid workspace role.';
    }
    final workspaceRef = _firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);
    try {
      final workspace = await workspaceRef.get();
      final ownerId = workspace.data()?[FirestorePaths.ownerId] as String?;
      if (ownerId != uid) {
        throw 'Only the workspace owner can change member roles.';
      }
      if (memberUid == ownerId) {
        throw "The workspace owner's role cannot be changed.";
      }
      await workspaceRef
          .collection(FirestorePaths.workspaceMembersSubcollection)
          .doc(memberUid)
          .update({'role': normalized});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Only the workspace owner can change member roles.';
      }
      throw 'That role could not be changed. Please try again.';
    }
  }

  @override
  Future<void> removeWorkspaceMember({
    required String workspaceId,
    required String memberUid,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final firestore = _firestore.getInstance();
    final workspaceRef = firestore
        .collection(FirestorePaths.workspaces)
        .doc(workspaceId);
    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(workspaceRef);
        final ownerId = snapshot.data()?[FirestorePaths.ownerId] as String?;
        if (ownerId != uid) {
          throw 'Only the workspace owner can remove members.';
        }
        if (memberUid == ownerId) {
          throw 'The workspace owner cannot be removed.';
        }
        transaction.delete(
          workspaceRef
              .collection(FirestorePaths.workspaceMembersSubcollection)
              .doc(memberUid),
        );
        transaction.update(workspaceRef, {
          FirestorePaths.memberCount: FieldValue.increment(-1),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw 'Only the workspace owner can remove members.';
      }
      throw 'That member could not be removed. Please try again.';
    }
  }

  // ── Invites ─────────────────────────────────────────────────────────────

  @override
  Stream<List<BoardInvitation>> watchBoardInvites() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.boardInvites)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) =>
              s.docs
                  .map((d) => BoardInvitation.fromMap(d.data(), d.id))
                  .where(
                    (i) =>
                        i.expiresAt == null ||
                        i.expiresAt!.isAfter(DateTime.now()),
                  )
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  @override
  Stream<List<WorkspaceInvite>> watchWorkspaceInvites() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.workspaceInvites)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            return WorkspaceInvite(
              id: d.id,
              workspaceId: (data[FirestorePaths.workspaceId] as String?) ?? '',
              fromUid: (data[FirestorePaths.fromUid] as String?) ?? '',
              toUid: (data[FirestorePaths.toUid] as String?) ?? '',
              senderName:
                  (data[FirestorePaths.senderName] as String?) ??
                  (data[FirestorePaths.fromUid] as String?) ??
                  'InkLink User',
              senderPhotoUrl: data[FirestorePaths.senderPic] as String?,
              workspaceName:
                  (data[FirestorePaths.name] as String?) ?? 'Workspace',
              status: (data[FirestorePaths.status] as String?) ?? 'pending',
              timestamp:
                  (data[FirestorePaths.timestamp] as Timestamp?)?.toDate() ??
                  DateTime.now(),
            );
          }).toList(),
        );
  }

  // ── Friends ─────────────────────────────────────────────────────────────

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.friendRequests)
        .where(FirestorePaths.toUid, isEqualTo: uid)
        .where(FirestorePaths.status, isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => FriendRequest.fromMap(d.data(), d.id)).toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  @override
  Stream<List<Friend>> watchFriends() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.friendsSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs
              .map((d) => d.id)
              .where((id) => id.isNotEmpty && id != uid)
              .toList();
          final friends = <Friend>[];
          for (final batch in chunked(ids)) {
            final users = await _firestore
                .collection(FirestorePaths.users)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            for (final doc in users.docs) {
              friends.add(Friend.fromMap(doc.data(), doc.id));
            }
          }
          friends.sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
          return friends;
        });
  }

  @override
  Future<List<Friend>> searchUsersByEmail(String email) async {
    final query = email.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final snap = await _firestore
        .collection(FirestorePaths.users)
        .where(FirestorePaths.email, isEqualTo: query)
        .limit(5)
        .get();
    final uid = _uid;
    return [
      for (final doc in snap.docs)
        if (doc.id != uid) Friend.fromMap(doc.data(), doc.id),
    ];
  }

  @override
  Stream<List<Friend>> watchBlockedUsers() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.blockedUsers)
        .where('blockerUid', isEqualTo: uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = [
            for (final doc in snapshot.docs)
              (doc.data()['blockedUid'] as String?)?.trim() ?? '',
          ].where((id) => id.isNotEmpty).toList();
          final friends = <Friend>[];
          for (final batch in chunked(ids)) {
            final users = await _firestore
                .collection(FirestorePaths.users)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            for (final doc in users.docs) {
              friends.add(Friend.fromMap(doc.data(), doc.id));
            }
          }
          for (final id in ids) {
            if (!friends.any((f) => f.uid == id)) {
              friends.add(Friend(uid: id, displayName: id));
            }
          }
          friends.sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
          return friends;
        });
  }

  // ── Notifications ───────────────────────────────────────────────────────

  @override
  Stream<List<InAppNotification>> watchNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.notificationsSubcollection)
        .orderBy(FirestorePaths.timestamp, descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .where((d) => isFeedNotification(d.data()))
              .map(
                (d) => InAppNotification.fromMap(
                  withNotificationSenderFields(d.data()),
                  d.id,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> deleteNotification(String notificationId) =>
      _notificationRepository.deleteNotification(notificationId);

  @override
  Stream<List<InAppNotification>> watchNotificationsWithReadState() =>
      combineLatest2(
        watchNotifications(),
        watchReadNotificationIds(),
        applyReadState,
      );

  @override
  Stream<Set<String>> watchReadNotificationIds() async* {
    final uid = _uid;
    if (uid == null) {
      yield const <String>{};
      return;
    }
    final prefs = await _readPrefs();
    _cachedReadIds = await prefs.getReadNotificationIds(uid);
    yield _cachedReadIds!;
    yield* _readIdsController.stream;
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final uid = _uid;
    if (uid == null || id.isEmpty) return;
    final prefs = await _readPrefs();
    await prefs.markAsRead(id, uid);
    final current = _cachedReadIds ?? await prefs.getReadNotificationIds(uid);
    _emitReadIds({...current, id});
  }

  @override
  Future<void> markAllNotificationsRead(Iterable<String> ids) async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await _readPrefs();
    final next = <String>{...?_cachedReadIds};
    for (final id in ids) {
      if (id.isEmpty || next.contains(id)) continue;
      await prefs.markAsRead(id, uid);
      next.add(id);
    }
    _emitReadIds(next);
  }

  // ── Error translation ───────────────────────────────────────────────────

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'popup-blocked':
        return 'Your browser blocked the sign-in popup. Please allow popups for this site.';
      case 'account-exists-with-different-credential':
        return 'This email already uses a different sign-in method.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Sign in instead.';
      case 'weak-password':
        return 'Use at least 6 characters for your password.';
      case 'operation-not-allowed':
        return 'Email sign-up is not available right now. Please try again later.';
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }
}
