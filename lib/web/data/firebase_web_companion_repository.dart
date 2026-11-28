import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/utils/notification_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloud_functions_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/firestore_batch_fetcher.dart';
import '../../core/utils/helpers.dart';
import '../../domain/models/board.dart';
import '../../domain/models/friends/friend.dart';
import '../../domain/models/friends/friend_request.dart';
import '../../domain/models/invitation/board_invitation.dart';
import '../../domain/models/notification/in_app_notification.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/workspace.dart';
import 'web_account.dart';
import 'web_account_settings.dart';
import 'web_board_ops.dart';
import 'web_companion_repository.dart';
import 'web_mappers.dart';
import 'web_workspace_ops.dart';

/// Firebase implementation of [WebCompanionRepository].
///
/// Reads the same Firestore collections as the mobile app and performs every
/// privileged action through the same Cloud Functions, so the companion
/// follows the same rules. Online-only: there is no local database on web.
class FirebaseWebCompanionRepository implements WebCompanionRepository {
  final AuthService _auth;
  final FirestoreService _firestore;
  final CloudFunctionsService _functions;

  FirebaseWebCompanionRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
    required CloudFunctionsService cloudFunctionsService,
  }) : _auth = authService,
       _firestore = firestoreService,
       _functions = cloudFunctionsService,
       _batchFetcher = FirestoreBatchFetcher(
         firestoreService: firestoreService,
       );

  // Reads documents by id in batches, falling back to single reads (the
  // phone's helper; web-safe).
  final FirestoreBatchFetcher _batchFetcher;

  /// Read notification ids for this browser, mirrored from the phone's
  /// shared_preferences approach (Firestore has no `read` write).
  NotificationPreferences? _notificationPrefs;
  Set<String>? _cachedReadIds;
  final _readIdsController = StreamController<Set<String>>.broadcast();

  Future<NotificationPreferences> _readPrefs() async => _notificationPrefs ??=
      NotificationPreferences(prefs: await SharedPreferences.getInstance());

  void _emitReadIds(Set<String> ids) {
    _cachedReadIds = ids;
    if (!_readIdsController.isClosed) _readIdsController.add(ids);
  }

  /// The user's board index (`users/{uid}/boards`), listened to once per
  /// session and shared: the board list and every workspace card join this
  /// stream instead of re-reading the index each time.
  Stream<UserBoardIndex>? _boardIndexStream;
  String? _boardIndexUid;

  Stream<UserBoardIndex> _myBoardIndex(String uid) {
    if (_boardIndexStream == null || _boardIndexUid != uid) {
      _boardIndexUid = uid;
      _boardIndexStream = _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection('boards')
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

  /// Google sign-in through a browser popup (the mobile Google flow does not
  /// run on the web). Only existing InkLink accounts may sign in here.
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

  /// The account the phone would create on first sign-in, created here so a
  /// person invited to a board can join without installing the mobile app.
  /// The profile fields are the phone's (`upsertUserProfile`): the owner may
  /// write their own `users/{uid}` document, so no Cloud Function is needed.
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
      // Failures here must not lose the account that now exists: the profile
      // can be written on the next sign-in and the verify screen can resend.
      try {
        await user.updateDisplayName(trimmedName);
      } catch (_) {}
      await _firestore.collection(FirestorePaths.users).doc(user.uid).set({
        'uid': user.uid,
        'email': normalizedEmail,
        'displayName': trimmedName,
        'photoURL': '',
        'searchKeywords': generateSearchKeywords(trimmedName),
        'friendCount': 0,
        'boardCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      try {
        await _auth.sendEmailVerification();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      throw _authMessage(e);
    }
  }

  /// New accounts are created in the mobile app, which also sets up the
  /// user profile. Signing in here without one would leave a half-made account.
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

  /// Deletes the account through the phone's `deleteUserAccount` function,
  /// then signs out. Nothing is removed locally if the function refuses.
  @override
  Future<void> deleteAccount() async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    await _callData('deleteUserAccount', const {});
    await signOut();
  }

  // ── Profile ─────────────────────────────────────────────────────────────

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

  /// Same fields the mobile profile editor writes.
  @override
  Future<void> updateProfile({
    required String name,
    required String bio,
  }) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final trimmedName = name.trim();
    await _firestore.collection(FirestorePaths.users).doc(uid).update({
      'displayName': trimmedName,
      'bio': bio.trim(),
      'searchKeywords': generateSearchKeywords(trimmedName),
    });
  }

  /// Settings → Privacy / Preferred Content Tags: live from the user document,
  /// which is where the phone writes the same fields.
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

  // ── Boards ──────────────────────────────────────────────────────────────

  /// The user's owned and joined boards, kept live.
  ///
  /// Owned boards are marked `owner` from the index; joined boards read their
  /// own `members/{uid}` document so an editor does not show up as a viewer
  /// on the card (the board document alone does not carry the role).
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

  /// Role from each joined board's member document, read in small batches.
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
                  .collection('members')
                  .doc(uid)
                  .get();
              final role = member.data()?['role'];
              if (role is String && role.isNotEmpty) roles[id] = role;
            } catch (_) {
              // Unreadable member doc: keep the board document's role.
            }
          }(),
      ]);
    }
    return roles;
  }

  Future<List<Board>> _fetchBoards(List<String> ids) async {
    final boards = <Board>[];
    // Reading a board is rule-checked with a member `get()` per document and
    // Firestore allows 10 document reads per query, so this must stay at
    // FirestoreBatchFetcher.chunkSize (10) rather than the 30-value `whereIn`
    // syntax limit.
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

  /// Public boards (newest first after loading), excluding archived ones.
  @override
  Future<List<Board>> loadPublicBoards({int limit = 40}) async {
    final snap = await _firestore
        .collection(FirestorePaths.boards)
        .where('visibility', isEqualTo: 'public')
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => Board.fromMap(d.data(), d.id))
        .where((b) => !b.isArchived)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Creates a board with the same document, owner member row, board index
  /// row and counter the phone writes (`FirestoreBoardRepository`).
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
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final boardRef = _firestore.collection(FirestorePaths.boards).doc();
    final userRef = _firestore.collection(FirestorePaths.users).doc(uid);
    final fields = newBoardFields(
      boardId: boardRef.id,
      uid: uid,
      name: name,
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      tags: tags,
      allowMembersToCopy: allowMembersToCopy,
    );
    fields['createdAt'] = FieldValue.serverTimestamp();
    fields['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.getInstance().runTransaction((transaction) async {
      transaction.set(boardRef, fields);
      transaction.set(boardRef.collection('members').doc(uid), {
        'uid': uid,
        'role': Board.roleOwner,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'boardCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      transaction.set(userRef.collection('boards').doc(boardRef.id), {
        'boardId': boardRef.id,
        'relation': 'owned',
        'addedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return boardRef.id;
  }

  /// Joins a board through the phone's `joinBoardByCode` function, so public
  /// boards, link-joinable private boards and invite-only boards get the same
  /// treatment (invite-only answers with a readable message).
  @override
  Future<void> joinBoard(String boardIdOrCode) async {
    final code = boardIdOrCode.trim();
    if (code.isEmpty) throw 'Please enter a join code.';
    try {
      await _functions.httpsCallable('joinBoardByCode').call({
        'joinCode': code,
      });
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) throw message;
      switch (e.code) {
        case 'failed-precondition':
        case 'permission-denied':
          throw 'This board can only be joined by invitation from the owner.';
        case 'not-found':
          throw 'Board not found. Check the join code and try again.';
        case 'invalid-argument':
          throw 'Invalid join code.';
        case 'unauthenticated':
          throw 'Please sign in and try again.';
        default:
          throw 'Unable to join board right now. Please try again.';
      }
    }
  }

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    final title = normalizeBoardName(newName);
    await _firestore.collection(FirestorePaths.boards).doc(boardId).update({
      'title': title,
      'name': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setBoardArchived(
    String boardId, {
    required bool archived,
  }) async {
    await _firestore.collection(FirestorePaths.boards).doc(boardId).update({
      'isArchived': archived,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setBoardPaused(String boardId, {required bool paused}) async {
    await _firestore.collection(FirestorePaths.boards).doc(boardId).update({
      'isPaused': paused,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Best effort: the function broadcasts the state to collaborators, but the
    // document is already right (same order as the phone's BoardService).
    try {
      await _functions.httpsCallable('setBoardPaused').call({
        'boardId': boardId,
        'isPaused': paused,
      });
    } catch (_) {}
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    final id = boardId.trim();
    if (id.isEmpty) return;
    try {
      await _functions.httpsCallable('deleteBoard').call({'boardId': id});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }

  @override
  Future<void> duplicateBoard(String boardId, {String? customTitle}) async {
    final uid = _uid;
    if (uid == null) throw 'Please sign in again.';
    final boardRef = _firestore.collection(FirestorePaths.boards).doc(boardId);
    final source = await boardRef.get();
    if (!source.exists) throw 'Board not found.';
    final sourceData = source.data() ?? const <String, dynamic>{};
    final isOwner = sourceData['ownerId'] == uid;
    final allowCopy = (sourceData['allowMembersToCopy'] as bool?) ?? false;
    if (!isOwner && !allowCopy) {
      throw 'You do not have permission to copy this board.';
    }

    final copyRef = _firestore.collection(FirestorePaths.boards).doc();
    final userRef = _firestore.collection(FirestorePaths.users).doc(uid);
    final copy = duplicatedBoardFields(
      sourceData,
      newBoardId: copyRef.id,
      uid: uid,
      customTitle: customTitle,
    );
    copy['createdAt'] = FieldValue.serverTimestamp();
    copy['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.getInstance().runTransaction((transaction) async {
      transaction.set(copyRef, copy);
      transaction.set(copyRef.collection('members').doc(uid), {
        'uid': uid,
        'role': Board.roleOwner,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'boardCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      transaction.set(userRef.collection('boards').doc(copyRef.id), {
        'boardId': copyRef.id,
        'relation': 'owned',
        'addedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // The snapshot is written after the copy exists: its rule checks
    // canEditBoard(newBoardId), which cannot see a document created in the
    // same transaction (the phone hit the same limit).
    try {
      final snapshot = await boardRef
          .collection('snapshot')
          .doc('latest')
          .get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = Map<String, dynamic>.from(snapshot.data()!)
          ..['boardId'] = copyRef.id
          ..['updatedAt'] = FieldValue.serverTimestamp();
        await copyRef.collection('snapshot').doc('latest').set(data);
      }
    } catch (_) {
      // The copy is still usable; the canvas republishes its state.
    }
  }

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) async {
    await _firestore.collection(FirestorePaths.boards).doc(boardId).update({
      'tags': normalizeBoardTags(tags),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
    fields['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection(FirestorePaths.boards)
        .doc(boardId)
        .update(fields);
    try {
      await _functions.httpsCallable('updateBoardSettings').call({
        'boardId': boardId,
        'visibility': fields['visibility'],
        'privateJoinPolicy': fields['privateJoinPolicy'],
        'whoCanInvite': normalizeWhoCanInvite(whoCanInvite),
        'defaultLinkJoinRole': normalizeLinkJoinRole(defaultLinkJoinRole),
        'allowMembersToCopy': ?allowMembersToCopy,
      });
    } catch (_) {}
  }

  // ── Workspaces ──────────────────────────────────────────────────────────

  /// The workspaces in the user's `workspaceIds` (owned and joined), kept
  /// live, newest activity first. Same source as the phone's list.
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

  /// The boards in a workspace that the user can open, kept live (the
  /// phone's rules: hidden links skipped, only boards the user has).
  ///
  /// The user's board index is shared with [watchMyBoards] and every other
  /// workspace card, so no card re-reads `users/{uid}/boards`: each one joins
  /// the single shared index stream with its own links.
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
                  index.owned.contains(id) || data['ownerId'] == uid
                  ? 'owner'
                  : null,
            ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  @override
  Future<String> createWorkspace({
    required String name,
    required String description,
  }) async {
    final data = await _callData('createWorkspace', {
      'name': name.trim(),
      'description': description.trim(),
    });
    final id = data['workspaceId'];
    if (id is! String || id.isEmpty) {
      throw 'The workspace could not be created. Please try again.';
    }
    return id;
  }

  @override
  Future<void> updateWorkspace({
    required String workspaceId,
    String? name,
    String? description,
  }) => _call('updateWorkspace', {
    'workspaceId': workspaceId,
    if (name != null) 'name': name.trim(),
    if (description != null) 'description': description.trim(),
  });

  @override
  Future<void> addBoardToWorkspace({
    required String workspaceId,
    required String boardId,
  }) => _call('addBoardToWorkspace', {
    'workspaceId': workspaceId,
    'boardId': boardId,
  });

  @override
  Future<void> removeBoardFromWorkspace({
    required String workspaceId,
    required String boardId,
  }) => _call('removeBoardFromWorkspace', {
    'workspaceId': workspaceId,
    'boardId': boardId,
  });

  /// The workspace's member documents joined with each member's profile, the
  /// same source the phone's settings screen reads.
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

  /// Each member's `users/{uid}` profile, read in parallel. A missing or
  /// unreadable profile must not hide the membership.
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

  @override
  Future<void> inviteToWorkspace({
    required String workspaceId,
    required List<String> userIds,
  }) async {
    final ids = [
      for (final id in userIds)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    if (ids.isEmpty) throw 'Choose someone to invite.';
    await _callData('inviteToWorkspace', {
      'workspaceId': workspaceId,
      'invitedUserIds': ids,
    });
  }

  @override
  Future<void> leaveWorkspace(String workspaceId) => _call('leaveWorkspace', {
    'workspaceId': workspaceId,
    'importedBoardsToKeep': const <String>[],
  });

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      _call('deleteWorkspace', {'workspaceId': workspaceId});

  // ── Invites ─────────────────────────────────────────────────────────────

  @override
  Stream<List<BoardInvitation>> watchBoardInvites() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('board_invites')
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

  @override
  Future<void> acceptBoardInvite(String inviteId) =>
      _call('acceptBoardInvite', {'inviteId': inviteId});

  @override
  Future<void> declineBoardInvite(String inviteId) =>
      _call('declineBoardInvite', {'inviteId': inviteId});

  @override
  Future<void> acceptWorkspaceInvite(String inviteId) =>
      _call('acceptWorkspaceInvite', {'inviteId': inviteId});

  @override
  Future<void> declineWorkspaceInvite(String inviteId) =>
      _call('rejectWorkspaceInvite', {'inviteId': inviteId});

  // ── Friends ─────────────────────────────────────────────────────────────

  @override
  Stream<List<FriendRequest>> watchIncomingFriendRequests() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('friend_requests')
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
        .collection('friends')
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
  Future<void> acceptFriendRequest(String requestId) =>
      _call('acceptFriendRequest', {'requestId': requestId});

  @override
  Future<void> declineFriendRequest(String requestId) =>
      _call('declineFriendRequest', {'requestId': requestId});

  /// The phone's add-friend search: an exact email lookup, excluding yourself.
  @override
  Future<List<Friend>> searchUsersByEmail(String email) async {
    final query = email.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final snap = await _firestore
        .collection(FirestorePaths.users)
        .where('email', isEqualTo: query)
        .limit(5)
        .get();
    final uid = _uid;
    return [
      for (final doc in snap.docs)
        if (doc.id != uid) Friend.fromMap(doc.data(), doc.id),
    ];
  }

  @override
  Future<void> sendFriendRequest(String targetUid) =>
      _call('sendFriendRequest', {'targetUid': targetUid});

  @override
  Future<void> unfriend(String targetUid) =>
      _call('unfriendUser', {'targetUid': targetUid});

  @override
  Stream<List<Friend>> watchBlockedUsers() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('blocked_users')
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
          // Keep blocks whose profile cannot be read, so they can be undone.
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

  @override
  Future<void> blockUser(String targetUid) =>
      _call('blockUser', {'targetUid': targetUid});

  @override
  Future<void> unblockUser(String targetUid) =>
      _call('unblockUser', {'targetUid': targetUid});

  // ── Notifications ───────────────────────────────────────────────────────

  @override
  Stream<List<InAppNotification>> watchNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
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
  Future<void> deleteNotification(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

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

  @override
  Future<void> uploadProfilePhoto(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (bytes.isEmpty) throw 'That image could not be read.';
    await _call('uploadProfilePhoto', {
      'imageData': base64Encode(bytes),
      'filename': filename,
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _call(String name, Map<String, dynamic> data) async {
    await _callData(name, data);
  }

  /// Calls a Cloud Function and returns its response map (empty when the
  /// function returns nothing).
  Future<Map<String, dynamic>> _callData(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final body = result.data;
      if (body is Map && body['success'] == false) {
        throw (body['message'] as String?) ??
            'That did not work. Please try again.';
      }
      return body is Map ? Map<String, dynamic>.from(body) : const {};
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'That did not work. Please try again.';
    }
  }

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
