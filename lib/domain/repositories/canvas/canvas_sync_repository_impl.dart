import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
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
  static const int _maxPayloadBase64Length = 900000;

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
  Future<void> clearLocalCrdtUpdatesForBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).deleteAll();
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
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) async {
    final isar = await _localDatabaseService.database;
    final existing = await isar.localCrdtUpdates.getByUpdateId(updateId);
    if (existing == null) return;

    existing.isDeleted = isDeleted;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(existing);
    });
  }

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate(
    String boardId,
    String elementId,
  ) async {
    final isar = await _localDatabaseService.database;
    final updates = await isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .findAll();

    // Find the first non-deleted update for this element
    for (final update in updates) {
      if (update.elementId == elementId && !update.isDeleted) {
        return update;
      }
    }
    return null;
  }

  @override
  Future<DateTime?> getLatestLocalCrdtUpdateAt(String boardId) async {
    final isar = await _localDatabaseService.database;
    final latest = await isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .sortByAppliedAtDesc()
        .findFirst();
    return latest?.appliedAt;
  }

  @override
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required String payloadBase64,
  }) async {
    // Update locally
    final isar = await _localDatabaseService.database;
    final existing = await isar.localCrdtUpdates.getByUpdateId(updateId);
    if (existing == null) return;

    existing.payloadBase64 = payloadBase64;
    existing.appliedAt = DateTime.now();
    existing.isSynced = false; // Mark for re-sync since payload changed
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(existing);
    });

    // Update remotely
    if (payloadBase64.isEmpty ||
        payloadBase64.length > _maxPayloadBase64Length) {
      return;
    }

    await _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates')
        .doc(updateId)
        .update({
          'payloadBase64': payloadBase64,
          'appliedAt': firestore.FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId) async {
    final isar = await _localDatabaseService.database;
    return isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).findAll();
  }

  @override
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
  }) async {
    firestore.Query<Map<String, dynamic>> query = _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates');

    if (since != null) {
      query = query.where(
        'appliedAt',
        isGreaterThan: firestore.Timestamp.fromDate(since),
      );
    }

    firestore.QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get();
    } on firestore.FirebaseException catch (e) {
      if (e.code == 'permission-denied') return <LocalCrdtUpdate>[];
      rethrow;
    }

    return snapshot.docs
        .map((doc) => _mapRemoteDoc(doc, boardId))
        .whereType<LocalCrdtUpdate>()
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
  Stream<List<LocalCrdtUpdate>> watchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
  }) async* {
    firestore.Query<Map<String, dynamic>> query = _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates');

    if (since != null) {
      query = query.where(
        'appliedAt',
        isGreaterThan: firestore.Timestamp.fromDate(since),
      );
    }

    yield* query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => _mapRemoteDoc(doc, boardId))
          .whereType<LocalCrdtUpdate>()
          .toList(growable: false),
    );
  }

  @override
  Future<void> writeRemoteCrdtUpdate({
    required String boardId,
    required String updateId,
    required String payloadBase64,
    required String sourceClientId,
    String? elementId,
  }) async {
    if (payloadBase64.isEmpty ||
        payloadBase64.length > _maxPayloadBase64Length) {
      return;
    }

    await _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates')
        .doc(updateId)
        .set({
          'boardId': boardId,
          'payloadBase64': payloadBase64,
          'sourceClientId': sourceClientId,
          'elementId': elementId,
          'appliedAt': firestore.FieldValue.serverTimestamp(),
        });
  }

  LocalCrdtUpdate? _mapRemoteDoc(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
    String boardId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final payloadBase64 = (data['payloadBase64'] as String?) ?? '';
    if (!_isValidPayloadBase64(payloadBase64)) {
      return null;
    }

    return LocalCrdtUpdate()
      ..updateId = doc.id
      ..boardId = (data['boardId'] as String?) ?? boardId
      ..elementId = (data['elementId'] as String?)
      ..payloadBase64 = payloadBase64
      ..sourceClientId = (data['sourceClientId'] as String?) ?? ''
      ..appliedAt =
          (data['appliedAt'] as firestore.Timestamp?)?.toDate() ??
          DateTime.now()
      ..isSynced = true;
  }

  bool _isValidPayloadBase64(String payloadBase64) {
    if (payloadBase64.isEmpty ||
        payloadBase64.length > _maxPayloadBase64Length) {
      return false;
    }

    try {
      final decoded = base64Decode(payloadBase64);
      return decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
