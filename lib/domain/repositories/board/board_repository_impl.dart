import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/collections/local_board.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../models/board.dart';
import 'board_repository.dart';

class FirestoreBoardRepository implements BoardRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final CloudFunctionsService _functionsService;
  final DatabaseService _dbService;
  static const String crdtEngine = 'crdt_v1';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownedBoardsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _joinedBoardsSub;
  String? _syncUserId;
  Set<String> _ownedBoardIds = <String>{};
  Set<String> _joinedBoardIds = <String>{};

  FirestoreBoardRepository({
    required FirestoreService firestoreService,
    required AuthService authService,
    required CloudFunctionsService functionsService,
    required DatabaseService dbService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _functionsService = functionsService,
       _dbService = dbService;

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
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

    _ownedBoardsSub = _firestoreService
        .collection('boards')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            _syncBoardsToLocal(snapshot.docs, isOwnedSnapshot: true);
          },
          onError: (error, stackTrace) {
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              return;
            }
          },
        );

    _joinedBoardsSub = _firestoreService
        .collection('boards')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen(
          (snapshot) {
            _syncBoardsToLocal(snapshot.docs, isOwnedSnapshot: false);
          },
          onError: (error, stackTrace) {
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              return;
            }
          },
        );
  }

  @override
  Future<void> stopBoardsSync() async {
    await _ownedBoardsSub?.cancel();
    await _joinedBoardsSub?.cancel();
    _ownedBoardsSub = null;
    _joinedBoardsSub = null;
    _syncUserId = null;
    _ownedBoardIds = <String>{};
    _joinedBoardIds = <String>{};
  }

  @override
  Stream<List<Board>> getOwnedBoards() {
    return _watchLocalBoards(owned: true);
  }

  @override
  Stream<List<Board>> getJoinedBoards() {
    return _watchLocalBoards(owned: false);
  }

  Stream<List<Board>> _watchLocalBoards({required bool owned}) {
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
          .watch(fireImmediately: true)
          .map(
            (localBoards) => localBoards
                .map(
                  (lb) => Board(
                    id: lb.boardId,
                    title: lb.title,
                    ownerId: lb.ownerId,
                    members: lb.members,
                    previewPath: lb.previewPath,
                    createdAt: lb.createdAt,
                    updatedAt: lb.updatedAt,
                  ),
                )
                .toList(),
          );
    });
  }

  @override
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
            previewPath: lb.previewPath,
            createdAt: lb.createdAt,
            updatedAt: lb.updatedAt,
          );
        })
        .asBroadcastStream();
  }

  Future<void> _syncBoardsToLocal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool isOwnedSnapshot,
  }) async {
    final uid = _syncUserId;
    if (uid == null) return;

    final isar = await _dbService.database;
    final updates = <String, LocalBoard>{};
    final snapshotIds = <String>{};

    for (final doc in docs) {
      final data = doc.data();
      final boardId = doc.id;
      snapshotIds.add(boardId);
      final board = LocalBoard()
        ..boardId = boardId
        ..title = data['title'] ?? data['name'] ?? 'Untitled Board'
        ..ownerId = data['ownerId'] ?? ''
        ..members = List<String>.from(data['members'] ?? [])
        ..engine = data['engine'] ?? crdtEngine
        ..previewPath = (await isar.localBoards.getByBoardId(
          boardId,
        ))?.previewPath
        ..createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..updatedAt =
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..isSynced = true;
      updates[boardId] = board;
    }

    if (isOwnedSnapshot) {
      _ownedBoardIds = snapshotIds;
    } else {
      _joinedBoardIds = snapshotIds;
    }

    final visibleBoardIds = <String>{..._ownedBoardIds, ..._joinedBoardIds};

    await isar.writeTxn(() async {
      for (final board in updates.values) {
        await isar.localBoards.putByBoardId(board);
      }

      final ownedLocals = await isar.localBoards
          .filter()
          .ownerIdEqualTo(uid)
          .findAll();
      final memberLocals = await isar.localBoards
          .filter()
          .membersElementEqualTo(uid)
          .findAll();

      final potentiallyVisibleLocals = <int, LocalBoard>{
        for (final board in ownedLocals) board.id: board,
        for (final board in memberLocals) board.id: board,
      }.values;

      for (final localBoard in potentiallyVisibleLocals) {
        if (!visibleBoardIds.contains(localBoard.boardId)) {
          await isar.localBoards.delete(localBoard.id);
        }
      }
    });
  }

  @override
  Future<String> createNewBoard({
    String name = 'Untitled Board',
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final docRef = _firestoreService.collection('boards').doc();
    final now = DateTime.now();

    final boardData = {
      'boardId': docRef.id,
      'title': name,
      'name': name,
      'ownerId': currentUserId,
      'members': [currentUserId],
      'engine': crdtEngine,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastEditedBy': currentUserId,
    };

    await docRef.set(boardData);

    final isar = await _dbService.database;
    final newLocalBoard = LocalBoard()
      ..boardId = docRef.id
      ..title = name
      ..ownerId = currentUserId!
      ..members = [currentUserId!]
      ..engine = crdtEngine
      ..previewPath = null
      ..createdAt = now
      ..updatedAt = now
      ..isSynced = true;

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(newLocalBoard);
    });

    if (invitedUserIds.isNotEmpty) {
      try {
        await _functionsService.httpsCallable('sendBoardInvite').call({
          'boardId': docRef.id,
          'boardTitle': name,
          'invitedUserIds': invitedUserIds,
          'inviteExpiryHours': inviteExpiryHours,
        });
      } catch (_) {
        // Do not fail board creation if invite notification fails.
      }
    }

    return docRef.id;
  }

  @override
  Future<void> joinBoard(String boardId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final docRef = _firestoreService.collection('boards').doc(boardId);

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

  @override
  Future<void> renameBoard(String boardId, String newName) async {
    if (currentUserId == null) return;

    final isar = await _dbService.database;
    final board = await isar.localBoards.getByBoardId(boardId);
    if (board != null) {
      board.title = newName;
      board.updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.localBoards.putByBoardId(board);
      });
    }

    await _firestoreService.collection('boards').doc(boardId).update({
      'title': newName,
      'name': newName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteBoard(String boardId) async {
    if (currentUserId == null) return;

    final isar = await _dbService.database;
    await isar.writeTxn(() async {
      await isar.localBoards.deleteByBoardId(boardId);
    });

    await _firestoreService.collection('boards').doc(boardId).delete();
  }

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {
    if (currentUserId == null || boardId.isEmpty || pngBytes.isEmpty) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final previewsDir = Directory(
      '${directory.path}${Platform.pathSeparator}inklink${Platform.pathSeparator}board_previews',
    );
    if (!await previewsDir.exists()) {
      await previewsDir.create(recursive: true);
    }

    final previewFile = File(
      '${previewsDir.path}${Platform.pathSeparator}$boardId.png',
    );
    await previewFile.writeAsBytes(pngBytes, flush: true);

    final isar = await _dbService.database;
    final localBoard = await isar.localBoards.getByBoardId(boardId);
    if (localBoard == null) return;

    localBoard.previewPath = previewFile.path;
    localBoard.updatedAt = DateTime.now();

    await _firestoreService.collection('boards').doc(boardId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await isar.writeTxn(() async {
      await isar.localBoards.putByBoardId(localBoard);
    });
  }

  @override
  Stream<String?> watchBoardPreview(String boardId) {
    return _dbService.database.asStream().asyncExpand((isar) {
      return isar.localBoards
          .filter()
          .boardIdEqualTo(boardId)
          .watch(fireImmediately: true)
          .map((boards) => boards.isEmpty ? null : boards.first.previewPath);
    });
  }
}
