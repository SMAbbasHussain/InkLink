import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/firestore_batch_fetcher.dart';
import '../../../domain/models/board.dart';
import '../../../domain/repositories/board/board_repository.dart';
import '../../../domain/services/board/board_rules.dart';
import '../../core/web_stream_utils.dart';
import '../models/user_board_index.dart';
import 'web_board_discovery_data_source.dart';

/// Firestore-only [BoardRepository] for the web target (no Isar, no local
/// files, and no Cloud Functions calls — callable orchestration stays in
/// [BoardService]).
///
/// Shared by both the web canvas (`SharedCanvasDependencies`) and the web
/// companion (`FirebaseWebCompanionRepository`).
class WebBoardRepository implements BoardRepository {
  final FirestoreService _db;
  final AuthService _authService;
  final WebBoardDiscoveryDataSource _discovery;

  WebBoardRepository({
    required this._authService,
    required FirestoreService firestoreService,
  }) : _db = firestoreService,
       _discovery = WebBoardDiscoveryDataSource(
         firestoreService: firestoreService,
       );

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  String get _requireUid {
    final uid = currentUserId;
    if (uid == null) throw StateError('Please sign in again.');
    return uid;
  }

  @override
  Stream<Board?> getBoardById(String boardId) {
    final id = boardId.trim();
    if (id.isEmpty) return Stream<Board?>.value(null);
    return _db
        .collection(FirestorePaths.boards)
        .doc(id)
        .snapshots()
        .asyncMap<Board?>((doc) async {
          if (!doc.exists) return null;
          final data = Map<String, dynamic>.of(doc.data() ?? const {});
          data['currentUserRole'] = await _resolveRole(
            id,
            (data[FirestorePaths.ownerId] as String?) ?? '',
          );
          return Board.fromMap(data, doc.id);
        })
        .transform(
          StreamTransformer<Board?, Board?>.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is FirebaseException &&
                  (error.code == 'permission-denied' ||
                      error.code == 'not-found')) {
                sink.add(null);
                return;
              }
              sink.addError(error, stack);
            },
          ),
        );
  }

  Future<String> _resolveRole(String boardId, String ownerId) async {
    final uid = currentUserId;
    if (uid == null) return Board.roleViewer;
    if (ownerId == uid) return Board.roleOwner;
    try {
      final member = await _db
          .collection(FirestorePaths.boards)
          .doc(boardId)
          .collection(FirestorePaths.boardMembersSubcollection)
          .doc(uid)
          .get();
      final role = member.data()?['role'];
      if (role == Board.roleEditor || role == Board.roleOwner) {
        return role as String;
      }
    } catch (_) {}
    return Board.roleViewer;
  }

  @override
  Stream<List<BoardMember>> getBoardMembers(String boardId) {
    return _db
        .collection(FirestorePaths.boards)
        .doc(boardId)
        .collection(FirestorePaths.boardMembersSubcollection)
        .snapshots()
        .asyncMap((snapshot) async {
          final uids = [for (final d in snapshot.docs) d.id];
          final profiles = await _profiles(uids);
          return [
            for (final d in snapshot.docs)
              BoardMember(
                uid: d.id,
                role: d.data()['role'] as String? ?? Board.roleViewer,
                status: d.data()[FirestorePaths.status] as String? ?? 'active',
                joinedAt: d.data()['joinedAt'] is Timestamp
                    ? (d.data()['joinedAt'] as Timestamp).toDate()
                    : null,
                displayName:
                    profiles[d.id]?[FirestorePaths.displayName] as String?,
                email: profiles[d.id]?[FirestorePaths.email] as String?,
                photoUrl: profiles[d.id]?[FirestorePaths.photoURL] as String?,
              ),
          ];
        })
        .transform(
          StreamTransformer<List<BoardMember>, List<BoardMember>>.fromHandlers(
            handleError: (error, stack, sink) {
              if (error is FirebaseException &&
                  (error.code == 'permission-denied' ||
                      error.code == 'not-found')) {
                sink.add(const <BoardMember>[]);
                return;
              }
              sink.addError(error, stack);
            },
          ),
        );
  }

  Future<Map<String, Map<String, dynamic>>> _profiles(List<String> uids) async {
    final out = <String, Map<String, dynamic>>{};
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
      try {
        final snap = await _db
            .collection(FirestorePaths.users)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          out[doc.id] = doc.data();
        }
      } catch (_) {}
    }
    return out;
  }

  // ── Local-only members (no Isar cache or local preview files on web) ─────

  @override
  Future<void> activateBoard(String boardId) async {}

  @override
  Future<void> deactivateBoard() async {}

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<void> removeBoardSync(String boardId) async {}

  @override
  Future<void> startBoardsSync() async {}

  @override
  Future<void> stopBoardsSync() async {}

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  Stream<String?> watchBoardPreview(String boardId) =>
      Stream<String?>.value(null);

  // ── Board list ──────────────────────────────────────────────────────────

  @override
  Future<int> countBoardsForUser(String userId) async {
    try {
      final user = await _db.collection(FirestorePaths.users).doc(userId).get();
      final count = user.data()?[FirestorePaths.boardCount];
      if (count is num) return count.toInt();
      final aggregate = await _db
          .collection(FirestorePaths.boards)
          .where(FirestorePaths.ownerId, isEqualTo: userId)
          .count()
          .get();
      return aggregate.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Stream<List<Board>> getOwnedBoards() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.boards)
        .where(FirestorePaths.ownerId, isEqualTo: uid)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs)
              Board.fromMap(
                doc.data(),
                doc.id,
              ).copyWith(currentUserRole: Board.roleOwner),
          ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
        );
  }

  @override
  Stream<List<Board>> getJoinedBoards() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.userBoardsSubcollection)
        .snapshots()
        .asyncMap((snap) async {
          final index = UserBoardIndex.fromDocs(
            snap.docs.map((d) => MapEntry(d.id, d.data())),
          );
          if (index.joined.isEmpty) return const <Board>[];
          final byId = {
            for (final board in await _fetchBoards(index.joined.toList()))
              board.id: board,
          };
          final out = <Board>[];
          for (final id in index.joined) {
            final board = byId[id];
            if (board == null) continue;
            out.add(
              board.copyWith(
                currentUserRole: await _resolveRole(id, board.ownerId),
              ),
            );
          }
          out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return out;
        });
  }

  Future<List<Board>> _fetchBoards(List<String> ids) async {
    final boards = <Board>[];
    for (final batch in chunked(ids, FirestoreBatchFetcher.chunkSize)) {
      final snap = await _db
          .collection(FirestorePaths.boards)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        boards.add(Board.fromMap(doc.data(), doc.id));
      }
    }
    return boards;
  }

  // ── Board lifecycle (pure Firestore data access) ────────────────────────

  @override
  Future<String> createNewBoard({
    String name = 'Untitled Board',
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required List<String> tags,
    bool allowMembersToCopy = false,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) async {
    final uid = _requireUid;
    final boardRef = _db.collection(FirestorePaths.boards).doc();
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
    await _writeOwnedBoard(boardRef, uid, fields);
    return boardRef.id;
  }

  Future<void> _writeOwnedBoard(
    DocumentReference<Map<String, dynamic>> boardRef,
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final firestore = _db.getInstance();
    final userRef = firestore.collection(FirestorePaths.users).doc(uid);
    fields[FirestorePaths.createdAt] = FieldValue.serverTimestamp();
    fields[FirestorePaths.updatedAt] = FieldValue.serverTimestamp();
    await firestore.runTransaction((transaction) async {
      transaction.set(boardRef, fields);
      transaction.set(
        boardRef.collection(FirestorePaths.boardMembersSubcollection).doc(uid),
        {
          FirestorePaths.uid: uid,
          'role': Board.roleOwner,
          FirestorePaths.status: 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
      );
      transaction.set(userRef, {
        FirestorePaths.boardCount: FieldValue.increment(1),
      }, SetOptions(merge: true));
      transaction.set(
        userRef
            .collection(FirestorePaths.userBoardsSubcollection)
            .doc(boardRef.id),
        {
          FirestorePaths.boardId: boardRef.id,
          'relation': 'owned',
          'addedAt': FieldValue.serverTimestamp(),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> joinBoard(String boardId) async {
    final id = boardId.trim();
    if (id.isEmpty) throw 'Please enter a join code.';
    final uid = _requireUid;
    final firestore = _db.getInstance();
    final boardRef = _db.collection(FirestorePaths.boards).doc(id);
    final userRef = firestore.collection(FirestorePaths.users).doc(uid);

    await firestore.runTransaction((transaction) async {
      final boardDoc = await transaction.get(boardRef);
      if (!boardDoc.exists) {
        throw 'Board not found. Check the join code and try again.';
      }
      final data = boardDoc.data() ?? const <String, dynamic>{};
      final members = List<String>.from(data['members'] ?? const []);
      if (members.contains(uid)) return;

      final visibility =
          (data[FirestorePaths.visibility] as String?) ??
          Board.visibilityPrivate;
      final privateJoinPolicy =
          (data[FirestorePaths.privateJoinPolicy] as String?) ??
          Board.policyOwnerOnlyInvite;
      if (!boardJoinViaCodeEnabled(
        visibility: visibility,
        privateJoinPolicy: privateJoinPolicy,
      )) {
        throw 'This board can only be joined by invitation from the owner.';
      }

      final invitePolicy =
          data[FirestorePaths.invitePolicy] as Map<String, dynamic>?;
      final defaultRole = normalizeLinkJoinRole(
        (invitePolicy?[FirestorePaths.defaultLinkJoinRole] as String?) ??
            Board.roleViewer,
      );

      transaction.update(boardRef, {
        'members': FieldValue.arrayUnion([uid]),
        FirestorePaths.memberCount: FieldValue.increment(1),
        'membersCount': FieldValue.increment(1),
        FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        boardRef.collection(FirestorePaths.boardMembersSubcollection).doc(uid),
        {
          FirestorePaths.uid: uid,
          'role': defaultRole,
          FirestorePaths.status: 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        userRef.collection(FirestorePaths.userBoardsSubcollection).doc(id),
        {
          FirestorePaths.boardId: id,
          'relation': 'joined',
          'addedAt': FieldValue.serverTimestamp(),
          FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    if (currentUserId == null) return;
    final title = normalizeBoardName(newName);
    await _db.collection(FirestorePaths.boards).doc(boardId).update({
      FirestorePaths.title: title,
      FirestorePaths.name: title,
      FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    final id = boardId.trim();
    if (id.isEmpty) return;
  }

  @override
  Future<void> archiveBoard(String boardId) =>
      _setBooleanFlag(boardId, field: 'isArchived', value: true);

  @override
  Future<void> unarchiveBoard(String boardId) =>
      _setBooleanFlag(boardId, field: 'isArchived', value: false);

  @override
  Future<void> setBoardPaused(String boardId, {required bool isPaused}) =>
      _setBooleanFlag(boardId, field: 'isPaused', value: isPaused);

  Future<void> _setBooleanFlag(
    String boardId, {
    required String field,
    required bool value,
  }) async {
    if (currentUserId == null) throw StateError('Please sign in again.');
    await _db.collection(FirestorePaths.boards).doc(boardId).update({
      field: value,
      FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> duplicateBoard(String boardId, {String? customTitle}) async {
    final uid = _requireUid;
    final sourceRef = _db.collection(FirestorePaths.boards).doc(boardId);
    final source = await sourceRef.get();
    if (!source.exists) throw 'Board not found.';
    final sourceData = source.data() ?? const <String, dynamic>{};
    final isOwner = sourceData[FirestorePaths.ownerId] == uid;
    final allowCopy = (sourceData['allowMembersToCopy'] as bool?) ?? false;
    if (!isOwner && !allowCopy) {
      throw 'You do not have permission to copy this board.';
    }

    final copyRef = _db.collection(FirestorePaths.boards).doc();
    final fields = duplicatedBoardFields(
      sourceData,
      newBoardId: copyRef.id,
      uid: uid,
      customTitle: customTitle,
    );
    await _writeOwnedBoard(copyRef, uid, fields);

    try {
      final snapshot = await sourceRef
          .collection(FirestorePaths.boardSnapshotSubcollection)
          .doc(FirestorePaths.boardSnapshotLatestDoc)
          .get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = Map<String, dynamic>.from(snapshot.data()!)
          ..[FirestorePaths.boardId] = copyRef.id
          ..[FirestorePaths.updatedAt] = FieldValue.serverTimestamp();
        await copyRef
            .collection(FirestorePaths.boardSnapshotSubcollection)
            .doc(FirestorePaths.boardSnapshotLatestDoc)
            .set(data);
      }
    } catch (_) {}

    return copyRef.id;
  }

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) async {
    _requireUid;
    await _db.collection(FirestorePaths.boards).doc(boardId).update({
      FirestorePaths.tags: normalizeBoardTags(tags),
      FirestorePaths.updatedAt: FieldValue.serverTimestamp(),
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
    _requireUid;
    final fields = boardSettingsFields(
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      allowMembersToCopy: allowMembersToCopy,
    );
    fields[FirestorePaths.updatedAt] = FieldValue.serverTimestamp();
    await _db.collection(FirestorePaths.boards).doc(boardId).update(fields);
  }

  // ── Discovery (delegated) ───────────────────────────────────────────────

  @override
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) => _discovery.getPublicBoards(
    tag: tag,
    sort: sort,
    lastDocCursor: lastDocCursor,
    limit: limit,
  );

  @override
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) => _discovery.getRecommendedPublicBoards(
    preferredTags: preferredTags,
    limit: limit,
  );
}
