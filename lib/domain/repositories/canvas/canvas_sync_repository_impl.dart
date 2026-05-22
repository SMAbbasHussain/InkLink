import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:isar_community/isar.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

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
  // Socket.IO client (optional). When present and connected, we'll prefer websocket transport.
  io.Socket? _socket;
  StreamController<List<LocalCrdtUpdate>>? _socketUpdatesController;

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
        .sortByAppliedAtDesc()
        .findAll();

    // Find the latest non-deleted update for this element.
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
    if (payloadBase64.isEmpty ||
        payloadBase64.length > _maxPayloadBase64Length) {
      return;
    }

    // Update locally only for payloads that will also be sent remotely.
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
    bool preferSocket = true,
  }) async {
    if (preferSocket) {
      // Try socket-backed pull first when possible (offline queue on server)
      try {
        if (_socket == null || !_socket!.connected) {
          // attempt to connect lazily
          final token = await _authService.getIdToken();
          if (token != null) {
            final serverUrl =
                dotenv.env['WEBSOCKET_URL'] ?? 'http://10.0.2.2:3000';
            _socket = io.io(
              serverUrl,
              io.OptionBuilder()
                  .setTransports(['websocket'])
                  .setAuth({'token': token})
                  .disableAutoConnect()
                  .build(),
            );
            _socket!.connect();
            // small timeout to let socket connect
            final connectCompleter = Completer<void>();
            _socket!.onConnect((_) {
              if (!connectCompleter.isCompleted) connectCompleter.complete();
            });
            await Future.any([
              connectCompleter.future,
              Future.delayed(const Duration(seconds: 2)),
            ]);
          }
        }

        if (_socket != null && _socket!.connected) {
          final completer = Completer<List<LocalCrdtUpdate>>();
          _logWs(
            'UPDATE REQUEST SENT',
            boardId,
            'sync_offline (fetch)',
            since: since?.toIso8601String(),
          );
          _socket!.emitWithAck(
            'sync_offline',
            {'boardId': boardId, 'since': since?.toIso8601String()},
            ack: (dynamic response) {
              if (response != null && response['status'] == 'success') {
                final updates =
                    (response['updates'] as List?)
                        ?.map((dynamic data) {
                          final map = data as Map<String, dynamic>;
                          final appliedAtStr =
                              map['appliedAt'] as String? ??
                              map['timestamp'] as String?;
                          return LocalCrdtUpdate()
                            ..updateId =
                                (map['updateId'] as String?) ??
                                (map['id'] as String?) ??
                                ''
                            ..boardId = (map['boardId'] as String?) ?? boardId
                            ..elementId = map['elementId'] as String?
                            ..payloadBase64 =
                                map['payloadBase64'] as String? ?? ''
                            ..sourceClientId =
                                map['sourceClientId'] as String? ?? ''
                            ..appliedAt = appliedAtStr != null
                                ? DateTime.tryParse(appliedAtStr) ??
                                      DateTime.now()
                                : DateTime.now()
                            ..isSynced = true;
                        })
                        .toList(growable: false) ??
                    <LocalCrdtUpdate>[];
                _logWs(
                  'UPDATE RESPONSE RECEIVED',
                  boardId,
                  'sync_offline',
                  updateCount: updates.length,
                  source: response['source'] as String?,
                );
                completer.complete(updates);
              } else if (response != null &&
                  response['status'] == 'fallback_required') {
                _logWs(
                  'UPDATE RESPONSE RECEIVED',
                  boardId,
                  'sync_offline',
                  detail: 'fallback_required',
                );
                completer.completeError('fallback_required');
              } else {
                completer.completeError('socket_sync_failed');
              }
            },
          );

          try {
            return await completer.future.timeout(const Duration(seconds: 5));
          } catch (_) {
            // fall through to Firestore fallback below
          }
        }
      } catch (_) {
        // ignore and fallback to Firestore
      }
    }

    firestore.Query<Map<String, dynamic>> query = _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates');

    // On fresh login (no local updates yet), fetch ALL updates from Firestore.
    // Otherwise, fetch only since the last local update.
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
    // Prefer socket stream when available
    try {
      if (_socket == null || !_socket!.connected) {
        final token = await _authService.getIdToken();
        if (token != null) {
          final serverUrl =
              dotenv.env['WEBSOCKET_URL'] ?? 'http://10.0.2.2:3000';
          _socket = io.io(
            serverUrl,
            io.OptionBuilder()
                .setTransports(['websocket'])
                .setAuth({'token': token})
                .disableAutoConnect()
                .build(),
          );
          _socket!.connect();
          final connectCompleter = Completer<void>();
          _socket!.onConnect((_) {
            if (!connectCompleter.isCompleted) connectCompleter.complete();
          });
          await Future.any([
            connectCompleter.future,
            Future.delayed(const Duration(seconds: 2)),
          ]);
        }
      }

      if (_socket != null && _socket!.connected) {
        _socket!.emit('watch_board', boardId);
        _logWs('SUBSCRIBE SENT', boardId, 'watch_board');
        _socketUpdatesController?.close();
        _socketUpdatesController = StreamController<List<LocalCrdtUpdate>>();

        void handleUpdate(dynamic data) {
          try {
            final map = data as Map<String, dynamic>;
            if ((map['boardId'] as String?) == boardId) {
              final payload = (map['update'] as Map<String, dynamic>?) ?? {};
              final update = LocalCrdtUpdate()
                ..updateId =
                    (payload['updateId'] as String?) ??
                    (map['id'] as String?) ??
                    ''
                ..boardId = boardId
                ..elementId = payload['elementId'] as String?
                ..payloadBase64 = payload['payloadBase64'] as String? ?? ''
                ..sourceClientId = payload['sourceClientId'] as String? ?? ''
                ..appliedAt = DateTime.now()
                ..isSynced = true;
              _logWs(
                'UPDATE RECEIVED',
                boardId,
                'crdt_update',
                updateId: update.updateId,
                elementId: update.elementId,
              );
              _socketUpdatesController?.add([update]);
            }
          } catch (_) {
            // ignore bad messages
          }
        }

        _socket!.on('crdt_update', handleUpdate);

        _socketUpdatesController!.onCancel = () {
          try {
            _socket!.emit('leave_board', boardId);
            _socket!.off('crdt_update', handleUpdate);
          } catch (_) {}
        };

        yield* _socketUpdatesController!.stream;
        return;
      }
    } catch (_) {
      // fall through to Firestore snapshots
    }

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

    // If socket connected, emit update to server which will persist and relay
    try {
      if (_socket != null && _socket!.connected) {
        _logWs(
          'UPDATE SENT',
          boardId,
          'crdt_update',
          updateId: updateId,
          elementId: elementId,
        );
        _socket!.emit('crdt_update', {
          'boardId': boardId,
          'update': {
            'updateId': updateId,
            'payloadBase64': payloadBase64,
            'sourceClientId': sourceClientId,
            'elementId': elementId,
          },
        });
        return;
      }
    } catch (_) {
      // ignore and fallback to Firestore
    }
    // Fallback to Firestore write if socket unavailable
    await _firestoreService
        .collection('boards')
        .doc(boardId)
        .collection('crdt_updates')
        .doc(updateId)
        .set({
          'updateId': updateId,
          'boardId': boardId,
          'payloadBase64': payloadBase64,
          'sourceClientId': sourceClientId,
          'elementId': elementId,
          'appliedAt': firestore.FieldValue.serverTimestamp(),
        });
  }

  // Helper to detect permission errors, mirroring the service layer implementation.
  bool _isPermissionDenied(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('missing or insufficient permissions');
  }

  @override
  Future<bool> batchSyncPendingUpdates(String boardId, String userId) async {
    final pending = await getLocalCrdtUpdates(boardId);
    final toSync = pending.where((u) => !u.isSynced).toList();
    if (toSync.isEmpty) return true;
    // If socket connected, push each pending update to server for relay + persistence
    try {
      if (_socket != null && _socket!.connected) {
        for (final local in toSync) {
          _logWs(
            'UPDATE SENT',
            boardId,
            'crdt_update',
            updateId: local.updateId,
            elementId: local.elementId,
          );
          _socket!.emit('crdt_update', {
            'boardId': boardId,
            'update': {
              'updateId': local.updateId,
              'payloadBase64': local.payloadBase64,
              'sourceClientId': userId,
              'elementId': local.elementId,
            },
          });
        }
        for (final local in toSync) {
          await markCrdtUpdateSynced(local.updateId);
        }
        return true;
      }
    } catch (_) {
      // ignore and fallback to Firestore
    }

    final batch = _firestoreService.getInstance().batch();
    for (final local in toSync) {
      final docRef = _firestoreService
          .collection('boards')
          .doc(boardId)
          .collection('crdt_updates')
          .doc(local.updateId);
      batch.set(docRef, {
        'updateId': local.updateId,
        'boardId': boardId,
        'payloadBase64': local.payloadBase64,
        'sourceClientId': userId,
        'elementId': local.elementId,
        'appliedAt': firestore.FieldValue.serverTimestamp(),
      });
    }
    try {
      await batch.commit();
      // Mark all as synced
      for (final local in toSync) {
        await markCrdtUpdateSynced(local.updateId);
      }
      return true;
    } catch (error) {
      if (_isPermissionDenied(error)) {
        return false;
      }
      rethrow;
    }
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

    final appliedAt =
        (data['appliedAt'] as firestore.Timestamp?)?.toDate() ??
        (data['timestamp'] as firestore.Timestamp?)?.toDate();
    if (appliedAt == null) {
      return null;
    }

    final updateId = (data['updateId'] as String?)?.trim();

    return LocalCrdtUpdate()
      ..updateId = (updateId != null && updateId.isNotEmpty) ? updateId : doc.id
      ..boardId = (data['boardId'] as String?) ?? boardId
      ..elementId = (data['elementId'] as String?)
      ..payloadBase64 = payloadBase64
      ..sourceClientId = (data['sourceClientId'] as String?) ?? ''
      ..appliedAt = appliedAt
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

  /// Disconnect WebSocket on logout.
  /// Server will clear Redis queues for this user automatically on disconnect.
  @override
  Future<void> disconnectSocket() async {
    if (_socket != null && _socket!.connected) {
      _socket!.disconnect();
      _socket = null;
      _socketUpdatesController?.close();
      _socketUpdatesController = null;
    }
  }

  void _logWs(
    String title,
    String boardId,
    String event, {
    String? updateId,
    String? elementId,
    String? since,
    String? source,
    int? updateCount,
    String? detail,
  }) {
    final lines = <String>[
      '[event] $event',
      '[board] $boardId',
      if (updateId != null) '[updateId] $updateId',
      if (elementId != null)
        '[elementId] ${elementId.isEmpty ? 'n/a' : elementId}',
      if (since != null) '[since] $since',
      if (source != null) '[source] $source',
      if (updateCount != null) '[updates] $updateCount',
      if (detail != null) '[detail] $detail',
    ];

    developer.log(lines.join(' | '), name: 'CanvasWebSocket::$title');
  }
}
