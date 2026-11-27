import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../domain/models/board.dart';
import '../../domain/repositories/board/board_repository.dart';

/// Firestore-only [BoardRepository] for the web canvas (no Isar, no local
/// files). It implements what the canvas path uses (`CanvasServiceImpl`
/// and the `BoardServiceImpl` calls the canvas makes); the board list,
/// creation and settings stay in the web companion's own repository.
///
/// Every [BoardRepository] member is implemented explicitly (no
/// `noSuchMethod`), so adding a member to the interface shows up here as a
/// compile error instead of a runtime failure in the browser.
class WebBoardRepository implements BoardRepository {
  final FirestoreService _db;
  final AuthService _authService;

  WebBoardRepository({
    required this._authService,
    required FirestoreService firestoreService,
  }) : _db = firestoreService;

  static const String _members = 'members';

  UnsupportedError _unsupported(String method) => UnsupportedError(
    'WebBoardRepository.$method is not available on the web canvas.',
  );

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  /// The board, with `currentUserRole` resolved like the phone repository:
  /// owner by `ownerId`, otherwise the member document's role (viewer by
  /// default). Emits null when the board is gone or can't be read.
  @override
  Stream<Board?> getBoardById(String boardId) {
    final id = boardId.trim();
    if (id.isEmpty) return Stream<Board?>.value(null);
    return _db
        .collection('boards')
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
          .collection('boards')
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
        .collection('boards')
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

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    if (currentUserId == null) return;
    await _db.collection('boards').doc(boardId).update({
      'title': newName,
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // No local cache, previews or live board list on the web canvas.
  @override
  Future<void> activateBoard(String boardId) async {}

  @override
  Future<void> deactivateBoard() async {}

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<void> removeBoardSync(String boardId) async {}

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  Stream<String?> watchBoardPreview(String boardId) =>
      Stream<String?>.value(null);

  @override
  Future<void> startBoardsSync() async {}

  @override
  Future<void> stopBoardsSync() async {}

  // ── Board list, creation and discovery (the web companion's job) ─────────
  //
  // These are the rest of [BoardRepository]. The canvas never reaches them —
  // the companion has its own repository — but they are listed explicitly so
  // the compiler keeps this class in step with the interface.

  @override
  Future<int> countBoardsForUser(String userId) =>
      throw _unsupported('countBoardsForUser');

  @override
  Stream<List<Board>> getOwnedBoards() => throw _unsupported('getOwnedBoards');

  @override
  Stream<List<Board>> getJoinedBoards() =>
      throw _unsupported('getJoinedBoards');

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
  }) => throw _unsupported('createNewBoard');

  @override
  Future<void> joinBoard(String boardId) => throw _unsupported('joinBoard');

  @override
  Future<void> deleteBoard(String boardId) => throw _unsupported('deleteBoard');

  @override
  Future<void> archiveBoard(String boardId) =>
      throw _unsupported('archiveBoard');

  @override
  Future<void> unarchiveBoard(String boardId) =>
      throw _unsupported('unarchiveBoard');

  @override
  Future<void> setBoardPaused(String boardId, {required bool isPaused}) =>
      throw _unsupported('setBoardPaused');

  @override
  Future<String> duplicateBoard(String boardId, {String? customTitle}) =>
      throw _unsupported('duplicateBoard');

  @override
  Future<void> updateBoardTags(String boardId, List<String> tags) =>
      throw _unsupported('updateBoardTags');

  @override
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  }) => throw _unsupported('updateBoardSettings');

  @override
  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) => throw _unsupported('getPublicBoards');

  @override
  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) => throw _unsupported('getRecommendedPublicBoards');
}
