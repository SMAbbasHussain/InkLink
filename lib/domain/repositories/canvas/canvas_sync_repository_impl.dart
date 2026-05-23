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
    // Use only previously-synced rows to compute the local 'since' cursor.
    // This avoids client-clock based local entries skewing hydration windows.
    final latest = await isar.localCrdtUpdates
        .filter()
        .boardIdEqualTo(boardId)
        .isSyncedEqualTo(true)
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

    final sourceClientId = _authService.getCurrentUserId() ?? '';

    try {
      if (_socket != null && _socket!.connected) {
        _logWs(
          'UPDATE SENT',
          boardId,
          'crdt_update (in-place)',
          updateId: updateId,
          elementId: existing.elementId,
        );

        final ack = await _emitWithAck('crdt_update', {
          'boardId': boardId,
          'update': {
            'updateId': updateId,
            'payloadBase64': payloadBase64,
            'sourceClientId': sourceClientId,
            'elementId': existing.elementId,
          },
        });

        if (ack != null && ack['status'] == 'success') {
          await markCrdtUpdateSynced(updateId);
          return;
        }
        // Otherwise fall through to Firestore write
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket in-place update failed; falling back to Firestore write',
        error,
        stackTrace,
        boardId: boardId,
        event: 'crdt_update (in-place)',
        updateId: updateId,
      );
    }

    // Fallback to Firestore if websocket is unavailable.
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
          'elementId': existing.elementId,
          'appliedAt': firestore.FieldValue.serverTimestamp(),
        }, firestore.SetOptions(merge: true));

    await markCrdtUpdateSynced(updateId);
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
          } catch (error, stackTrace) {
            _logError(
              'Socket sync_offline fetch timed out/failed; falling back to Firestore query',
              error,
              stackTrace,
              boardId: boardId,
              event: 'sync_offline (fetch)',
            );
          }
        }
      } catch (error, stackTrace) {
        _logError(
          'Socket-based remote fetch setup failed; falling back to Firestore query',
          error,
          stackTrace,
          boardId: boardId,
          event: 'sync_offline (fetch)',
        );
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
          } catch (error, stackTrace) {
            _logError(
              'Failed to parse inbound socket crdt_update payload',
              error,
              stackTrace,
              boardId: boardId,
              event: 'crdt_update',
            );
          }
        }

        _socket!.on('crdt_update', handleUpdate);

        _socketUpdatesController!.onCancel = () {
          try {
            _socket!.emit('leave_board', boardId);
            _socket!.off('crdt_update', handleUpdate);
          } catch (error, stackTrace) {
            _logError(
              'Failed while unsubscribing from board socket stream',
              error,
              stackTrace,
              boardId: boardId,
              event: 'leave_board',
            );
          }
        };

        yield* _socketUpdatesController!.stream;
        return;
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket watchRemote setup failed; falling back to Firestore snapshots',
        error,
        stackTrace,
        boardId: boardId,
        event: 'watch_board',
      );
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

    final socketConnected = _socket != null && _socket!.connected;

    // Prefer socket when connected. If socket send/ack fails, keep the update
    // unsynced for retry and avoid immediate Firestore fallback writes that may
    // fail with stale permission context after role changes.
    if (socketConnected) {
      try {
        _logWs(
          'UPDATE SENT',
          boardId,
          'crdt_update',
          updateId: updateId,
          elementId: elementId,
        );

        final ack = await _emitWithAck('crdt_update', {
          'boardId': boardId,
          'update': {
            'updateId': updateId,
            'payloadBase64': payloadBase64,
            'sourceClientId': sourceClientId,
            'elementId': elementId,
          },
        });

        if (ack != null && ack['status'] == 'success') {
          await markCrdtUpdateSynced(updateId);
          return;
        }

        developer.log(
          'Socket ack missing/failed for writeRemote; leaving update unsynced for retry | [event] crdt_update [board] $boardId [updateId] $updateId',
          name: 'CanvasWebSocket::WARN',
          level: 900,
        );
        return;
      } catch (error, stackTrace) {
        _logError(
          'Socket writeRemote failed; leaving update unsynced for retry',
          error,
          stackTrace,
          boardId: boardId,
          event: 'crdt_update',
          updateId: updateId,
        );
        return;
      }
    }

    // Fallback to Firestore write only when socket is unavailable.
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
    await markCrdtUpdateSynced(updateId);
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
          final ack = await _emitWithAck('crdt_update', {
            'boardId': boardId,
            'update': {
              'updateId': local.updateId,
              'payloadBase64': local.payloadBase64,
              'sourceClientId': userId,
              'elementId': local.elementId,
            },
          });
          if (ack != null && ack['status'] == 'success') {
            await markCrdtUpdateSynced(local.updateId);
          } else {
            // If any ack fails, stop and let retry happen later
            return false;
          }
        }
        return true;
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket batch sync failed; falling back to Firestore batch write',
        error,
        stackTrace,
        boardId: boardId,
        event: 'crdt_update (batch)',
      );
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
    } catch (error, stackTrace) {
      _logError(
        'Invalid payloadBase64 encountered during validation',
        error,
        stackTrace,
        event: 'payload_validation',
      );
      return false;
    }
  }

  /// Disconnect WebSocket on logout.
  /// Helper to emit an event and await server ack (with timeout).
  Future<Map<String, dynamic>?> _emitWithAck(
    String event,
    dynamic payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_socket == null || !_socket!.connected) return null;
    final completer = Completer<Map<String, dynamic>?>();
    try {
      _socket!.emitWithAck(
        event,
        payload,
        ack: (dynamic response) {
          try {
            completer.complete(response as Map<String, dynamic>?);
          } catch (error, stackTrace) {
            _logError(
              'Socket ack response type-cast failed',
              error,
              stackTrace,
              event: event,
            );
            completer.complete(null);
          }
        },
      );
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (error, stackTrace) {
      _logError(
        'emitWithAck failed before receiving response',
        error,
        stackTrace,
        event: event,
      );
      return null;
    }
  }

  /// Send explicit logout handshake to the server. Server will clear server-side
  /// queues only when an explicit logout is received.
  @override
  Future<void> logoutSocket() async {
    if (_socket != null && _socket!.connected) {
      try {
        final response = await _emitWithAck('logout', null);
        if (response == null || response['status'] != 'success') {
          developer.log(
            'Logout ack missing or unsuccessful: ${response ?? 'null'}',
            name: 'CanvasWebSocket::LOGOUT',
            level: 900,
          );
        }
      } catch (error, stackTrace) {
        _logError(
          'logoutSocket failed while waiting for server ack',
          error,
          stackTrace,
          event: 'logout',
        );
      }
    }
  }

  void _logError(
    String message,
    Object error,
    StackTrace stackTrace, {
    String? boardId,
    String? event,
    String? updateId,
  }) {
    final contextParts = <String>[
      if (event != null) '[event] $event',
      if (boardId != null) '[board] $boardId',
      if (updateId != null) '[updateId] $updateId',
    ];
    final context = contextParts.isEmpty ? '' : ' ${contextParts.join(' ')}';
    developer.log(
      '$message$context',
      name: 'CanvasWebSocket::ERROR',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  /// Disconnect WebSocket locally. Server will NOT clear user queues on simple
  /// disconnects; queues are preserved until an explicit `logout` is received.
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
