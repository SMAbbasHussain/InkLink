import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/firestore_batch_fetcher.dart';
import '../../domain/models/board.dart';
import '../../domain/repositories/board/board_repository.dart';
import '../data/web_board_ops.dart';
import '../data/web_mappers.dart';

/// Firestore-only [BoardRepository] for the web canvas (no Isar, no local
/// files).
///
/// Every member is implemented, so the canvas, the companion pages and the
/// board dialogs all share this one class with no runtime "not available on
/// the web" fallbacks. Writes mirror `FirestoreBoardRepository`, so a board
/// created, copied or re-configured in a browser is the same document the
/// phone reads.
class WebBoardRepository implements BoardRepository {
  final FirestoreService _db;
  final AuthService _authService;

  WebBoardRepository({
    required this._authService,
    required FirestoreService firestoreService,
  }) : _db = firestoreService;

  static const String _members = 'members';
  static const String _boards = 'boards';

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  String get _requireUid {
    final uid = currentUserId;
    if (uid == null) throw StateError('Please sign in again.');
    return uid;
  }

  /// The board, with `currentUserRole` resolved like the phone repository:
  /// owner by `ownerId`, otherwise the member document's role (viewer by
  /// default). Emits null when the board is gone or can't be read.
  @override
  Stream<Board?> getBoardById(String boardId) {
    final id = boardId.trim();
    if (id.isEmpty) return Stream<Board?>.value(null);
    return _db
        .collection(_boards)
        .doc(id)
        .snapshots()
        .asyncMap<Board?>((doc) async {
          if (!doc.exists) return null;
          final data = Map<String, dynamic>.of(doc.data() ?? const {});
          data['currentUserRole'] = await _resolveRole(
            id,
            (data['ownerId'] as String?) ?? '',
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
          .collection(_boards)
          .doc(boardId)
          .collection(_members)
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
        .collection(_boards)
        .doc(boardId)
        .collection(_members)
        .snapshots()
        .asyncMap((snapshot) async {
          final uids = [for (final d in snapshot.docs) d.id];
          final profiles = await _profiles(uids);
          return [
            for (final d in snapshot.docs)
              BoardMember(
                uid: d.id,
                role: d.data()['role'] as String? ?? 'viewer',
                status: d.data()['status'] as String? ?? 'active',
                joinedAt: d.data()['joinedAt'] is Timestamp
                    ? (d.data()['joinedAt'] as Timestamp).toDate()
                    : null,
                displayName: profiles[d.id]?['displayName'] as String?,
                email: profiles[d.id]?['email'] as String?,
                photoUrl: profiles[d.id]?['photoURL'] as String?,
              ),
          ];
        })
        .transform(
          StreamTransformer<List<BoardMember>, List<BoardMember>>.fromHandlers(
            handleError: (error, stack, sink) {
              // As on phones: a deleted/unreadable board means "no members".
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
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          out[doc.id] = doc.data();
        }
      } catch (_) {}
    }
    return out;
  }

  // ── Local-only members (no cache, previews or live sync on the web) ──────

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

  /// Board previews are local files on a phone; the web keeps none, so this is
  /// a no-op and [watchBoardPreview] always emits null (documented on the
  /// boards page, which uses the sticky-note cards instead of thumbnails).
  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  Stream<String?> watchBoardPreview(String boardId) =>
      Stream<String?>.value(null);

  // ── Board list ──────────────────────────────────────────────────────────

  @override
  Future<int> countBoardsForUser(String userId) async {
    try {
      final user = await _db.collection('users').doc(userId).get();
      final count = user.data()?['boardCount'];
      if (count is num) return count.toInt();
      final aggregate = await _db
          .collection(_boards)
          .where('ownerId', isEqualTo: userId)
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
        .collection(_boards)
        .where('ownerId', isEqualTo: uid)
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
        .collection('users')
        .doc(uid)
        .collection('boards')
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
          .collection(_boards)
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        boards.add(Board.fromMap(doc.data(), doc.id));
      }
    }
    return boards;
  }

  // ── Board lifecycle ─────────────────────────────────────────────────────

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
    final firestore = _db.getInstance();
    final boardRef = _db.collection(_boards).doc();
    final userRef = firestore.collection('users').doc(uid);
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

    await firestore.runTransaction((transaction) async {
      transaction.set(boardRef, fields);
      transaction.set(boardRef.collection(_members).doc(uid), {
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

  @override
  Future<void> joinBoard(String boardId) async {
    final id = boardId.trim();
    if (id.isEmpty) throw 'Please enter a join code.';
    try {
      await _db.getHttpsCallable('joinBoardByCode').call({'joinCode': id});
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      if (message != null && message.isNotEmpty) throw message;
      throw switch (e.code) {
        'failed-precondition' || 'permission-denied' =>
          'This board can only be joined by invitation from the owner.',
        'not-found' => 'Board not found. Check the join code and try again.',
        'invalid-argument' => 'Invalid join code.',
        _ => 'Unable to join board right now. Please try again.',
      };
    }
  }

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    if (currentUserId == null) return;
    final title = normalizeBoardName(newName);
    await _db.collection(_boards).doc(boardId).update({
      'title': title,
      'name': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    final id = boardId.trim();
    if (id.isEmpty) return;
    try {
      await _db.getHttpsCallable('deleteBoard').call({'boardId': id});
    } on FirebaseFunctionsException catch (e) {
      if (e.code != 'not-found') rethrow;
    }
  }

  @override
  Future<void> archiveBoard(String boardId) =>
      _setBooleanFlag(boardId, field: 'isArchived', value: true);

  @override
  Future<void> unarchiveBoard(String boardId) =>
      _setBooleanFlag(boardId, field: 'isArchived', value: false);

  @override
  Future<void> setBoardPaused(String boardId, {required bool isPaused}) async {
    await _setBooleanFlag(boardId, field: 'isPaused', value: isPaused);
    try {
      await _db.getHttpsCallable('setBoardPaused').call({
        'boardId': boardId,
        'isPaused': isPaused,
      });
    } on FirebaseFunctionsException {
      // The document is already right; the call only broadcasts.
    }
  }

  Future<void> _setBooleanFlag(
    String boardId, {
    required String field,
    required bool value,
  }) async {
    if (currentUserId == null) throw StateError('Please sign in again.');
    await _db.collection(_boards).doc(boardId).update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> duplicateBoard(String boardId, {String? customTitle}) async {
    final uid = _requireUid;
    final firestore = _db.getInstance();
    final sourceRef = _db.collection(_boards).doc(boardId);
    final source = await sourceRef.get();
    if (!source.exists) throw 'Board not found.';
    final sourceData = source.data() ?? const <String, dynamic>{};
    final isOwner = sourceData['ownerId'] == uid;
    final allowCopy = (sourceData['allowMembersToCopy'] as bool?) ?? false;
    if (!isOwner && !allowCopy) {
      throw 'You do not have permission to copy this board.';
    }

    final copyRef = _db.collection(_boards).doc();
    final userRef = firestore.collection('users').doc(uid);
    final fields = duplicatedBoardFields(
      sourceData,
      newBoardId: copyRef.id,
      uid: uid,
      customTitle: customTitle,
    );
    fields['createdAt'] = FieldValue.serverTimestamp();
    fields['updatedAt'] = FieldValue.serverTimestamp();

    await firestore.runTransaction((transaction) async {
      transaction.set(copyRef, fields);
      transaction.set(copyRef.collection(_members).doc(uid), {
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

    // Written after the copy exists: the snapshot rule resolves the new board
    // with get() and cannot see a document created in the same transaction.
    try {
      final snapshot = await sourceRef
          .collection('snapshot')
          .doc('latest')
          .get();
      if (snapshot.exists && snapshot.data() != null) {
        final data = Map<String, dynamic>.from(snapshot.data()!)
          ..['boardId'] = copyRef.id
          ..['updatedAt'] = FieldValue.serverTimestamp();
        await copyRef.collection('snapshot').doc('latest').set(data);
      }
    } catch (_) {}

    return copyRef.id;
  }

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) async {
    _requireUid;
    await _db.collection(_boards).doc(boardId).update({
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
    _requireUid;
    final fields = boardSettingsFields(
      visibility: visibility,
      privateJoinPolicy: privateJoinPolicy,
      whoCanInvite: whoCanInvite,
      defaultLinkJoinRole: defaultLinkJoinRole,
      allowMembersToCopy: allowMembersToCopy,
    );
    fields['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection(_boards).doc(boardId).update(fields);
  }

  // ── Discovery ───────────────────────────────────────────────────────────

  @override
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(_boards)
        .where('visibility', isEqualTo: Board.visibilityPublic);

    final normalizedTag = tag?.trim().toLowerCase();
    if (normalizedTag != null && normalizedTag.isNotEmpty) {
      query = query.where('tags', arrayContains: normalizedTag);
    }

    if (sort == PublicBoardSort.popular) {
      query = query
          .orderBy('membersCount', descending: true)
          .orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    if (lastDocCursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(lastDocCursor);
    }

    final snapshot = await query.limit(limit).get();
    final boards = snapshot.docs
        .map((doc) => Board.fromMap(doc.data(), doc.id))
        .where((b) => !b.isArchived)
        .toList();

    return PublicBoardsPage(
      boards: boards,
      lastDocCursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  @override
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) async {
    final cleaned = preferredTags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .take(10)
        .toList();
    if (cleaned.isEmpty) {
      return (await getPublicBoards(limit: limit)).boards;
    }
    try {
      final snapshot = await _db
          .collection(_boards)
          .where('visibility', isEqualTo: Board.visibilityPublic)
          .where('tags', arrayContainsAny: cleaned)
          .limit(limit * 2)
          .get();
      final boards = snapshot.docs
          .map((doc) => Board.fromMap(doc.data(), doc.id))
          .where((b) => !b.isArchived)
          .toList();
      final preferred = preferredTags
          .map((t) => t.trim().toLowerCase())
          .toSet();
      boards.sort((a, b) {
        final aMatches = a.tags
            .where((t) => preferred.contains(t.toLowerCase()))
            .length;
        final bMatches = b.tags
            .where((t) => preferred.contains(t.toLowerCase()))
            .length;
        if (bMatches != aMatches) return bMatches.compareTo(aMatches);
        return b.membersCount.compareTo(a.membersCount);
      });
      return boards.take(limit).toList();
    } catch (_) {
      return (await getPublicBoards(limit: limit)).boards;
    }
  }
}
