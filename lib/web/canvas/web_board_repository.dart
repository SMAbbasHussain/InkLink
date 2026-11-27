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
class WebBoardRepository implements BoardRepository {
  final FirestoreService _db;
  final AuthService _authService;

  WebBoardRepository({
    required this._authService,
    required FirestoreService firestoreService,
  }) : _db = firestoreService;

  static const String _members = 'members';

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

  /// Everything else (board list, create, delete, discovery) is handled
  /// by the web companion and is not used from the canvas.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'WebBoardRepository.${invocation.memberName} is not available on the web '
    'canvas.',
  );
}
