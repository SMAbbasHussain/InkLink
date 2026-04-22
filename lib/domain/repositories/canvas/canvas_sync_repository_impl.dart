import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar_community/isar.dart';

import '../../../core/database/collections/local_crdt_update.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'canvas_sync_repository.dart';

class FirestoreCanvasSyncRepository implements CanvasSyncRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  FirestoreCanvasSyncRepository({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(update);
    });
  }

  @override
  Future<void> markCrdtUpdateSynced(String updateId) async {
    final isar = await _localDatabaseService.database;
    final existing = await isar.localCrdtUpdates.getByUpdateId(updateId);
    if (existing == null) return;

    existing.isSynced = true;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(existing);
    });
  }

  @override
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).findAll();
  }

  @override
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(String boardId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestoreService
          .collection('boards')
          .doc(boardId)
          .collection('crdt_updates')
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return <LocalCrdtUpdate>[];
      rethrow;
    }

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return LocalCrdtUpdate()
            ..updateId = doc.id
            ..boardId = data['boardId'] ?? boardId
            ..payloadBase64 = data['payloadBase64'] ?? ''
            ..sourceClientId = data['sourceClientId'] ?? ''
            ..appliedAt =
                (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now()
            ..isSynced = true;
        })
        .toList(growable: false);
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchLocalCrdtUpdates(String boardId) async* {
    final isar = await _localDatabaseService.database;
    yield* isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByAppliedAt()
        .watch(fireImmediately: true);
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchRemoteCrdtUpdates(String boardId) async* {
    yield* _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                return LocalCrdtUpdate()
                  ..updateId = doc.id
                  ..boardId = data['boardId'] ?? boardId
                  ..payloadBase64 = data['payloadBase64'] ?? ''
                  ..sourceClientId = data['sourceClientId'] ?? ''
                  ..appliedAt =
                      (data['appliedAt'] as Timestamp?)?.toDate() ??
                      DateTime.now()
                  ..isSynced = true;
              })
              .toList(growable: false);
        });
  }

  @override
  Future<void> writeRemoteCrdtUpdate({
    required String boardId,
    required String updateId,
    required String payloadBase64,
    required String sourceClientId,
  }) async {
    await _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates')
        .doc(updateId)
        .set({
          'boardId': boardId,
          'payloadBase64': payloadBase64,
          'sourceClientId': sourceClientId,
          'appliedAt': FieldValue.serverTimestamp(),
        });
  }
}
