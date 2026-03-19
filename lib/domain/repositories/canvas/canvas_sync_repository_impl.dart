import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';

import '../../../core/database/collections/local_crdt_update.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'canvas_sync_repository.dart';

class FirestoreCanvasSyncRepository implements CanvasSyncRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final DatabaseService _dbService;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _remoteCrdtSubs = {};

  FirestoreCanvasSyncRepository({
    required FirestoreService firestoreService,
    required AuthService authService,
    required DatabaseService dbService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _dbService = dbService;

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required List<int> payload,
  }) async {
    final userId = currentUserId;
    final isar = await _dbService.database;
    final payloadBase64 = base64Encode(payload);

    final local = LocalCrdtUpdate()
      ..updateId = updateId
      ..boardId = boardId
      ..payloadBase64 = payloadBase64
      ..sourceClientId = userId ?? 'anonymous'
      ..appliedAt = DateTime.now()
      ..isSynced = false;

    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(local);
    });

    if (userId == null) {
      return;
    }

    await _pushSingleUpdate(local, userId);
    await _syncPendingLocalUpdates(boardId, userId);
  }

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) async* {
    if (currentUserId != null) {
      await hydrateCrdtUpdates(boardId);
      startCrdtRemoteSync(boardId);
      await _syncPendingLocalUpdates(boardId, currentUserId!);
    }

    final isar = await _dbService.database;
    yield* isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByAppliedAt()
        .watch(fireImmediately: true);
  }

  @override
  Future<void> hydrateCrdtUpdates(String boardId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestoreService
          .collection('boards')
          .doc(boardId)
          .collection('crdt_updates')
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return;
      rethrow;
    }

    if (snapshot.docs.isEmpty) return;

    final isar = await _dbService.database;
    final updates = <LocalCrdtUpdate>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final update = LocalCrdtUpdate()
        ..updateId = doc.id
        ..boardId = data['boardId'] ?? boardId
        ..payloadBase64 = data['payloadBase64'] ?? ''
        ..sourceClientId = data['sourceClientId'] ?? ''
        ..appliedAt =
            (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
        ..isSynced = true;
      updates.add(update);
    }

    await isar.writeTxn(() async {
      for (final update in updates) {
        await isar.localCrdtUpdates.putByUpdateId(update);
      }
    });
  }

  @override
  void startCrdtRemoteSync(String boardId) {
    if (currentUserId == null) return;
    if (_remoteCrdtSubs.containsKey(boardId)) return;

    final sub = _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates')
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.docs.isEmpty) return;

            final isar = await _dbService.database;
            final updates = <LocalCrdtUpdate>[];

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final update = LocalCrdtUpdate()
                ..updateId = doc.id
                ..boardId = data['boardId'] ?? boardId
                ..payloadBase64 = data['payloadBase64'] ?? ''
                ..sourceClientId = data['sourceClientId'] ?? ''
                ..appliedAt =
                    (data['appliedAt'] as Timestamp?)?.toDate() ??
                    DateTime.now()
                ..isSynced = true;
              updates.add(update);
            }

            await isar.writeTxn(() async {
              for (final update in updates) {
                await isar.localCrdtUpdates.putByUpdateId(update);
              }
            });
          },
          onError: (error, stackTrace) {
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              return;
            }
          },
        );

    _remoteCrdtSubs[boardId] = sub;
  }

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {
    final sub = _remoteCrdtSubs.remove(boardId);
    await sub?.cancel();
  }

  Future<void> _syncPendingLocalUpdates(String boardId, String userId) async {
    final isar = await _dbService.database;
    final localUpdates = await isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .findAll();

    for (final local in localUpdates) {
      if (local.isSynced) continue;
      await _pushSingleUpdate(local, userId);
    }
  }

  Future<void> _pushSingleUpdate(LocalCrdtUpdate local, String userId) async {
    final isar = await _dbService.database;

    try {
      await _firestoreService
          .collection('boards')
          .doc(local.boardId)
          .collection('crdt_updates')
          .doc(local.updateId)
          .set({
            'boardId': local.boardId,
            'payloadBase64': local.payloadBase64,
            'sourceClientId': userId,
            'appliedAt': FieldValue.serverTimestamp(),
          });

      await isar.writeTxn(() async {
        local.isSynced = true;
        await isar.localCrdtUpdates.putByUpdateId(local);
      });
    } catch (_) {
      // Keep unsynced for retry on next sync opportunity.
    }
  }
}
