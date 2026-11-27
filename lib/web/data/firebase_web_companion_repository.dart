import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/firestore_paths.dart';
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
import 'web_companion_repository.dart';
import 'web_mappers.dart';

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
          usesPassword: user.providerData.any((p) => p.providerId == 'password'),
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

  // ── Boards ──────────────────────────────────────────────────────────────

  /// The user's owned and joined boards, kept live.
  @override
  Stream<List<Board>> watchMyBoards() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _myBoardIndex(uid).asyncMap((index) async {
      final boards = await _fetchBoards(index.all.toList());
      return boards
          .map(
            (b) => b.copyWith(
              currentUserRole: index.owned.contains(b.id) || b.ownerId == uid
                  ? 'owner'
                  : b.currentUserRole,
            ),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
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

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions.httpsCallable(name).call(data);
      final body = result.data;
      if (body is Map && body['success'] == false) {
        throw (body['message'] as String?) ??
            'That did not work. Please try again.';
      }
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
      default:
        return e.message ?? 'Sign-in failed. Please try again.';
    }
  }
}
