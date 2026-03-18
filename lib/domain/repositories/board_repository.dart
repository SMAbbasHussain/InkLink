import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';
import 'dart:async';
import '../../core/database/database_service.dart';
import '../../core/database/collections/local_board.dart';
import '../models/board.dart';

class BoardRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _dbService;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownedBoardsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _joinedBoardsSub;
  String? _syncUserId;

  BoardRepository({required DatabaseService dbService})
    : _dbService = dbService;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Starts long-lived sync from Firestore -> Isar for the current user.
  /// UI should read from Isar streams only.
  Future<void> startBoardsSync() async {
    final uid = currentUserId;
    if (uid == null) {
      await stopBoardsSync();
      return;
    }

    if (_syncUserId == uid &&
        _ownedBoardsSub != null &&
        _joinedBoardsSub != null) {
      return;
    }

    await stopBoardsSync();
    _syncUserId = uid;

    _ownedBoardsSub = _db
        .collection('boards')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          _syncBoardsToLocal(snapshot.docs);
        });

    _joinedBoardsSub = _db
        .collection('boards')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
          _syncBoardsToLocal(snapshot.docs);
        });
  }

  Future<void> stopBoardsSync() async {
    await _ownedBoardsSub?.cancel();
    await _joinedBoardsSub?.cancel();
    _ownedBoardsSub = null;
    _joinedBoardsSub = null;
    _syncUserId = null;
  }

  Stream<List<Board>> getOwnedBoards() {
    return _watchLocalBoards(owned: true);
  }

  Stream<List<Board>> getJoinedBoards() {
    return _watchLocalBoards(owned: false);
  }

  Stream<List<Board>> _watchLocalBoards({required bool owned}) {
    // Convert Future<Isar> to Stream, then expand into the Isar Watcher
    return _dbService.database.asStream().asyncExpand((isar) {
      final queryBuilder = isar.localBoards.filter();

      final filterQuery = owned
          ? queryBuilder.ownerIdEqualTo(currentUserId ?? '')
          : queryBuilder
                .membersElementEqualTo(currentUserId ?? '')
                .and()
                .not()
                .ownerIdEqualTo(currentUserId ?? '');

      return filterQuery
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true) // This ensures data flows as soon as Bloc listens
          .map((localBoards) => localBoards.map((lb) => Board(
                id: lb.boardId,
                title: lb.title,
                ownerId: lb.ownerId,
                members: lb.members,
                createdAt: lb.createdAt,
                updatedAt: lb.updatedAt,
              )).toList());
    });
  }

  Stream<Board?> getBoardById(String boardId) async* {
    final isar = await _dbService.database;

    yield* isar.localBoards
        .filter()
        .boardIdEqualTo(boardId)
        .watch(fireImmediately: true)
        .map((boards) {
          if (boards.isEmpty) return null;
          final lb = boards.first;
          return Board(
            id: lb.boardId,
            title: lb.title,
            ownerId: lb.ownerId,
            members: lb.members,
            createdAt: lb.createdAt,
            updatedAt: lb.updatedAt,
          );
        })
        .asBroadcastStream();
  }

   Future<void> _syncBoardsToLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final isar = await _dbService.database;
    final Map<String, LocalBoard> updates = {};

    for (var doc in docs) {
      final data = doc.data();
      final boardId = doc.id;
      final board = LocalBoard()
        ..boardId = boardId
        ..title = data['title'] ?? data['name'] ?? 'Untitled Board'
        ..ownerId = data['ownerId'] ?? ''
        ..members = List<String>.from(data['members'] ?? [])
        ..createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..updatedAt =
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..isSynced = true;
      updates[boardId] = board;
    }

    await isar.writeTxn(() async {
      for (var board in updates.values) {
        await isar.localBoards.putByBoardId(board);
      }
    });
  }

  Future<String> createNewBoard([String name = 'Untitled Board']) async {
    if (currentUserId == null) throw Exception("User not authenticated");

    final docRef = _db.collection('boards').doc();
    final now = DateTime.now();

    final boardData = {
      'boardId': docRef.id,
      'title': name,
      'name': name, // Maintain backward compatibility
      'ownerId': currentUserId,
      'members': [currentUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastEditedBy': currentUserId,
    };

    // Save to Firestore
    await docRef.set(boardData);

    // Save locally
    final isar = await _dbService.database;
    final newLocalBoard = LocalBoard()
      ..boardId = docRef.id
      ..title = name
      ..ownerId = currentUserId!
      ..members = [currentUserId!]
      ..createdAt = now
      ..updatedAt = now
      ..isSynced = true;

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(newLocalBoard);
    });

    return docRef.id;
  }

  Future<void> joinBoard(String boardId) async {
    if (currentUserId == null) throw Exception("User not authenticated");

    final docRef = _db.collection('boards').doc(boardId);

    try {
      await docRef.update({
        'members': FieldValue.arrayUnion([currentUserId]),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied while joining board');
      }
      if (e.code == 'not-found') {
        throw Exception('Board does not exist');
      }
      rethrow;
    }
  }

  Future<void> renameBoard(String boardId, String newName) async {
    if (currentUserId == null) return;

    // Optimistic local update
    final isar = await _dbService.database;
    final board = await isar.localBoards.getByBoardId(boardId);
    if (board != null) {
      board.title = newName;
      board.updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.localBoards.putByBoardId(board);
      });
    }

    // Remote update
    await _db.collection('boards').doc(boardId).update({
      'title': newName,
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBoard(String boardId) async {
    if (currentUserId == null) return;

    // Delete locally
    final isar = await _dbService.database;
    await isar.writeTxn(() async {
      await isar.localBoards.deleteByBoardId(boardId);
    });

    // Delete remotely
    await _db.collection('boards').doc(boardId).delete();
  }
}
