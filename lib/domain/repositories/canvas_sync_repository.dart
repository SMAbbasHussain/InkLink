import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isar/isar.dart';
import 'dart:async';
import '../../core/database/database_service.dart';
import '../../core/database/collections/local_operation.dart';
import '../models/canvas_operation.dart';

class CanvasSyncRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _dbService;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _remoteBoardSubs = {};

  CanvasSyncRepository({required DatabaseService dbService})
    : _dbService = dbService;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  /// Push an operation to Isar locally, then to Firestore
  Future<void> pushOperation(CanvasOperation op) async {
    if (currentUserId == null) return;

    final isar = await _dbService.database;

    // Save locally
    final localOp = LocalOperation()
      ..opId = op.opId
      ..boardId = op.boardId
      ..objectId = op.objectId
      ..type = op.type
      ..action = op.action
      ..data = op.data
      ..timestamp = op.timestamp
      ..clientId = op.clientId
      ..isSynced = false;

    await isar.writeTxn(() async {
      await isar.localOperations.putByOpId(localOp);
    });

    // Push to Firestore
    try {
      await _db
          .collection('boards')
          .doc(op.boardId)
          .collection('operations')
          .doc(op.opId)
          .set(op.toMap());

      // Mark as synced
      await isar.writeTxn(() async {
        localOp.isSynced = true;
        await isar.localOperations.putByOpId(localOp);
      });
    } catch (e) {
      // Offline or error - the operation is still saved in Isar (isSynced = false)
      // A background sync worker can retry pushing `isSynced == false` operations later
    }
  }

  /// Listen to operations from Firestore (to fetch what others are drawing)
  /// AND fetch local offline operations.
  Stream<List<CanvasOperation>> listenToOperations(String boardId) async* {
    if (currentUserId == null) {
      yield [];
      return;
    }

    await hydrateBoardOperations(boardId);
    startRemoteSync(boardId);

    // Stream from Isar for local changes and immediate startup
    final isar = await _dbService.database;

    yield* isar.localOperations
        .filter()
        .boardIdEqualTo(boardId)
        .sortByTimestamp()
        .watch(fireImmediately: true)
        .map((localOps) {
          return localOps
              .map(
                (lOp) => CanvasOperation(
                  opId: lOp.opId,
                  boardId: lOp.boardId,
                  objectId: lOp.objectId,
                  type: lOp.type,
                  action: lOp.action,
                  data: lOp.data,
                  timestamp: lOp.timestamp,
                  clientId: lOp.clientId,
                ),
              )
              .toList();
        });
  }

  Future<void> hydrateBoardOperations(String boardId) async {
    final snapshot = await _db
        .collection('boards')
        .doc(boardId)
        .collection('operations')
        .get();

    if (snapshot.docs.isEmpty) return;

    final isar = await _dbService.database;
    final List<LocalOperation> opsToSave = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final lOp = LocalOperation()
        ..opId = doc.id
        ..boardId = data['boardId'] ?? boardId
        ..objectId = data['objectId'] ?? ''
        ..type = data['type'] ?? ''
        ..action = data['action'] ?? ''
        ..data = data['data'] ?? ''
        ..timestamp = data['timestamp'] ?? ''
        ..clientId = data['clientId'] ?? ''
        ..isSynced = true;
      opsToSave.add(lOp);
    }

    await isar.writeTxn(() async {
      for (final op in opsToSave) {
        await isar.localOperations.putByOpId(op);
      }
    });
  }

  /// Background listener to pull new remote operations to Isar
  void startRemoteSync(String boardId) {
    if (_remoteBoardSubs.containsKey(boardId)) {
      return;
    }

    final sub = _db
        .collection('boards')
        .doc(boardId)
        .collection('operations')
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isEmpty) return;

          final isar = await _dbService.database;
          final List<LocalOperation> opsToSave = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();

            final lOp = LocalOperation()
              ..opId = doc.id
              ..boardId = data['boardId'] ?? boardId
              ..objectId = data['objectId'] ?? ''
              ..type = data['type'] ?? ''
              ..action = data['action'] ?? ''
              ..data = data['data'] ?? ''
              ..timestamp = data['timestamp'] ?? ''
              ..clientId = data['clientId'] ?? ''
              ..isSynced = true;

            opsToSave.add(lOp);
          }

          if (opsToSave.isNotEmpty) {
            await isar.writeTxn(() async {
              for (var op in opsToSave) {
                await isar.localOperations.putByOpId(op);
              }
            });
          }
        });

    _remoteBoardSubs[boardId] = sub;
  }

  Future<void> stopRemoteSync(String boardId) async {
    final sub = _remoteBoardSubs.remove(boardId);
    await sub?.cancel();
  }
}
