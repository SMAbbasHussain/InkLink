import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:isar_community/isar.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/database/collections/local_canvas_sync_state.dart';
import '../../../core/database/collections/local_crdt_update.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import 'canvas_sync_repository.dart';

class FirestoreCanvasSyncRepository implements CanvasSyncRepository {
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;
  static const int _maxPayloadBase64Length = 900000;
  // Socket.IO client (optional). When present and connected, we'll prefer websocket transport.
  io.Socket? _socket;
  bool _isSingleUserBoard = false;
  StreamController<List<LocalCrdtUpdate>>? _socketUpdatesController;
  StreamController<List<LocalCrdtUpdate>>? _socketPreviewController;

  FirestoreCanvasSyncRepository({
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _authService = authService,
       _localDatabaseService = localDatabaseService;

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {
    _isSingleUserBoard = isSingleUser;
  }

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.putByUpdateId(update);
      final existing =
          await isar.localCanvasSyncStates.getByBoardId(update.boardId);
      await isar.localCanvasSyncStates.putByBoardId(
        (existing ?? LocalCanvasSyncState()..boardId = update.boardId)
          ..lastSyncedAppliedAt = update.appliedAt,
      );
    });
  }

  @override
  Future<void> clearLocalCrdtUpdatesForBoard(String boardId) async {
    final isar = await _localDatabaseService.database;
    await isar.writeTxn(() async {
      await isar.localCrdtUpdates.filter().boardIdEqualTo(boardId).deleteAll();
    });
  }

  Future<bool> _ensureSocketConnected() async {
    if (_socket != null && _socket!.connected) {
      return true;
    }

    final token = await _authService.getIdToken();
    if (token == null) return false;

    final serverUrl = dotenv.env['WEBSOCKET_URL'] ?? 'http://10.0.2.2:3000';
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

    return _socket != null && _socket!.connected;
  }

  void _bindBoardSocketStream({
    required String boardId,
    required StreamController<List<LocalCrdtUpdate>> controller,
    required String eventName,
    required String subscribeLabel,
    required void Function(dynamic data) handleEvent,
  }) {
    _socket!.emit('watch_board', boardId);
    _logWs('SUBSCRIBE SENT', boardId, subscribeLabel);
    _socket!.on(eventName, handleEvent);

    controller.onCancel = () {
      try {
        _socket!.emit('leave_board', boardId);
        _socket!.off(eventName, handleEvent);
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

        final updateData = <String, dynamic>{
          'updateId': updateId,
          'payloadBase64': payloadBase64,
          'sourceClientId': sourceClientId,
          'elementId': existing.elementId,
        };
        if (_isSingleUserBoard) {
          updateData['_singleUser'] = true;
        }

        final ack = await _emitWithAck('crdt_update', {
          'boardId': boardId,
          'update': updateData,
        });

        if (ack != null && ack['status'] == 'success') {
          await markCrdtUpdateSynced(updateId);
          return;
        }
        // Otherwise fall through to Firestore write
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket in-place update failed; leaving unsynced for retry',
        error,
        stackTrace,
        boardId: boardId,
        event: 'crdt_update (in-place)',
        updateId: updateId,
      );
    }
  }

  @override
  Future<String?> getLastSeenCursor(String boardId) async {
    try {
      final isar = await _localDatabaseService.database;
      final syncState = await isar.localCanvasSyncStates.getByBoardId(boardId);
      return syncState?.lastSeenCursor;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required String payloadBase64,
    required String sourceClientId,
  }) async {
    if (payloadBase64.isEmpty ||
        payloadBase64.length > _maxPayloadBase64Length) {
      return;
    }

    try {
      if (_socket != null && _socket!.connected) {
        _logWs(
          'PREVIEW SENT',
          boardId,
          'crdt_preview',
          updateId: previewId,
          elementId: elementId,
        );
        await _emitWithAck('crdt_preview', {
          'boardId': boardId,
          'preview': {
            'previewId': previewId,
            'elementId': elementId,
            'payloadBase64': payloadBase64,
            'sourceClientId': sourceClientId,
          },
        });
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket preview publish failed',
        error,
        stackTrace,
        boardId: boardId,
        event: 'crdt_preview',
        updateId: previewId,
      );
    }
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
    String? lastSeenCursor,
    bool preferSocket = true,
  }) async {
    if (preferSocket) {
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
          // Load stored cursor from local sync state if not provided
          String? cursor = lastSeenCursor;
          if (cursor == null) {
            final isar = await _localDatabaseService.database;
            final syncState =
                await isar.localCanvasSyncStates.getByBoardId(boardId);
            cursor = syncState?.lastSeenCursor;
          }

          final result = await _fetchWithCursor(boardId, cursor);
          return result;
        }
      } catch (error, stackTrace) {
        _logError(
          'Socket-based remote fetch setup failed',
          error,
          stackTrace,
          boardId: boardId,
          event: 'sync_offline (fetch)',
        );
      }
    }

    return <LocalCrdtUpdate>[];
  }

  /// Fetches remote updates using cursor-based sync (supports snapshot + deltas).
  /// Handles pagination via [hasMore] flag from the server using a loop.
  Future<List<LocalCrdtUpdate>> _fetchWithCursor(
    String boardId,
    String? cursor,
  ) async {
    final allUpdates = <LocalCrdtUpdate>[];
    String? currentCursor = cursor;
    const int maxPages = 10;
    int pages = 0;

    while (pages < maxPages) {
      pages++;
      final response = await _emitWithAck('sync_offline', {
        'boardId': boardId,
        if (currentCursor != null && currentCursor.isNotEmpty)
          'lastSeenCursor': currentCursor,
      });

      if (response == null || response['status'] != 'success') {
        if (response != null && response['status'] == 'fallback_required') {
          throw 'fallback_required';
        }
        throw 'socket_sync_failed';
      }

      final source = response['source'] as String?;

      // --- Handle snapshot-first responses ---
      if (source == 'snapshot_with_deltas' || source == 'snapshot_only') {
        final snapshotData = response['snapshot'] as Map<String, dynamic>?;
        if (snapshotData != null) {
          final stateUpdate = snapshotData['stateUpdate'] as String?;
          if (stateUpdate != null && stateUpdate.isNotEmpty) {
            allUpdates.add(LocalCrdtUpdate()
              ..updateId = '__snapshot__${snapshotData['lastAppliedVersion'] ?? 0}'
              ..boardId = boardId
              ..elementId = null
              ..payloadBase64 = stateUpdate
              ..sourceClientId = '__server_snapshot__'
              ..appliedAt = DateTime.now()
              ..isSynced = true
              ..version = snapshotData['lastAppliedVersion'] as int? ?? 0);
          }
        }
      }

      // --- Parse updates list ---
      final updatesList = (response['updates'] as List?) ?? <dynamic>[];
      for (final data in updatesList) {
        final map = data as Map<String, dynamic>;
        final appliedAtStr = map['appliedAt'] as String? ??
            map['timestamp'] as String?;
        allUpdates.add(LocalCrdtUpdate()
          ..updateId = (map['updateId'] as String?) ?? ''
          ..boardId = (map['boardId'] as String?) ?? boardId
          ..elementId = map['elementId'] as String?
          ..payloadBase64 = map['payloadBase64'] as String? ?? ''
          ..sourceClientId = map['sourceClientId'] as String? ?? ''
          ..appliedAt = appliedAtStr != null
              ? DateTime.tryParse(appliedAtStr) ?? DateTime.now()
              : DateTime.now()
          ..isSynced = true
          ..version = (map['version'] as num?)?.toInt() ?? 0);
      }

      // --- Store cursor ---
      final newCursor = response['cursor'] as String?;
      if (newCursor != null && newCursor.isNotEmpty) {
        currentCursor = newCursor;
        await _saveCursor(boardId, newCursor);
      }

      final hasMore = response['hasMore'] as bool? ?? false;
      if (!hasMore) {
        _logWs(
          'UPDATE RESPONSE RECEIVED',
          boardId,
          'sync_offline',
          updateCount: allUpdates.length,
          source: source,
          cursor: currentCursor,
        );
        return allUpdates;
      }
    }

    // Max pages reached — return what we have
    return allUpdates;
  }

  Future<void> _saveCursor(String boardId, String cursor) async {
    if (cursor.isEmpty) return;
    try {
      final isar = await _localDatabaseService.database;
      await isar.writeTxn(() async {
        final existing =
            await isar.localCanvasSyncStates.getByBoardId(boardId);
        await isar.localCanvasSyncStates.putByBoardId(
          (existing ?? LocalCanvasSyncState()..boardId = boardId)
            ..lastSeenCursor = cursor,
        );
      });
    } catch (_) {}
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchRemoteCanvasPreviews(
    String boardId,
  ) async* {
    try {
      await _ensureSocketConnected();

      if (_socket != null && _socket!.connected) {
        _socketPreviewController?.close();
        _socketPreviewController = StreamController<List<LocalCrdtUpdate>>();

        void handlePreview(dynamic data) {
          try {
            final map = data as Map<String, dynamic>;
            if ((map['boardId'] as String?) == boardId) {
              final payload = (map['preview'] as Map<String, dynamic>?) ?? {};
              final preview = LocalCrdtUpdate()
                ..updateId =
                    (payload['previewId'] as String?) ??
                    (map['id'] as String?) ??
                    ''
                ..boardId = boardId
                ..elementId = payload['elementId'] as String?
                ..payloadBase64 = payload['payloadBase64'] as String? ?? ''
                ..sourceClientId = payload['sourceClientId'] as String? ?? ''
                ..appliedAt = DateTime.now()
                ..isSynced = true;
              _socketPreviewController?.add([preview]);
            }
          } catch (error, stackTrace) {
            _logError(
              'Failed to parse inbound preview payload',
              error,
              stackTrace,
              boardId: boardId,
              event: 'crdt_preview',
            );
          }
        }

        _bindBoardSocketStream(
          boardId: boardId,
          controller: _socketPreviewController!,
          eventName: 'crdt_preview',
          subscribeLabel: 'watch_board (preview)',
          handleEvent: handlePreview,
        );

        yield* _socketPreviewController!.stream;
        return;
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket preview setup failed',
        error,
        stackTrace,
        boardId: boardId,
        event: 'crdt_preview',
      );
    }
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
      await _ensureSocketConnected();

      if (_socket != null && _socket!.connected) {
        _socketUpdatesController?.close();
        _socketUpdatesController = StreamController<List<LocalCrdtUpdate>>();

        void handleUpdate(dynamic data) {
          try {
            final map = data as Map<String, dynamic>;
            if ((map['boardId'] as String?) == boardId) {
              final payload = (map['update'] as Map<String, dynamic>?) ?? {};
              final version = (payload['version'] as num?)?.toInt() ?? 0;
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
                ..isSynced = true
                ..version = version;
              _logWs(
                'UPDATE RECEIVED',
                boardId,
                'crdt_update',
                updateId: update.updateId,
                elementId: update.elementId,
                detail: 'version=$version',
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

        _bindBoardSocketStream(
          boardId: boardId,
          controller: _socketUpdatesController!,
          eventName: 'crdt_update',
          subscribeLabel: 'watch_board',
          handleEvent: handleUpdate,
        );

        yield* _socketUpdatesController!.stream;
        return;
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket watchRemote setup failed',
        error,
        stackTrace,
        boardId: boardId,
        event: 'watch_board',
      );
    }
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

      // If socket send/ack fails, keep the update unsynced for retry
    if (socketConnected) {
      try {
        _logWs(
          'UPDATE SENT',
          boardId,
          'crdt_update',
          updateId: updateId,
          elementId: elementId,
        );

        final updateData = <String, dynamic>{
          'updateId': updateId,
          'payloadBase64': payloadBase64,
          'sourceClientId': sourceClientId,
          'elementId': elementId,
        };
        if (_isSingleUserBoard) {
          updateData['_singleUser'] = true;
        }

        final ack = await _emitWithAck('crdt_update', {
          'boardId': boardId,
          'update': updateData,
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
  }

  @override
  Future<bool> batchSyncPendingUpdates(String boardId, String userId) async {
    final pending = await getLocalCrdtUpdates(boardId);
    final toSync = pending.where((u) => !u.isSynced).toList();
    if (toSync.isEmpty) return true;
    // Push each pending update to server via socket
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
        // Clean up old synced entries and update sync state
        try {
          final isar = await _localDatabaseService.database;
          await isar.writeTxn(() async {
            await isar.localCrdtUpdates
                .filter()
                .boardIdEqualTo(boardId)
                .isSyncedEqualTo(true)
                .appliedAtLessThan(DateTime.now().subtract(const Duration(hours: 1)))
                .deleteAll();
          });
          final latest = await isar.localCrdtUpdates
              .filter()
              .boardIdEqualTo(boardId)
              .sortByAppliedAtDesc()
              .findFirst();
          if (latest != null) {
            final existing =
                await isar.localCanvasSyncStates.getByBoardId(boardId);
            await isar.writeTxn(() async {
              await isar.localCanvasSyncStates.putByBoardId(
                (existing ?? LocalCanvasSyncState()..boardId = boardId)
                  ..lastSyncedAppliedAt = latest.appliedAt,
              );
            });
          }
        } catch (_) {}
        return true;
      }
    } catch (error, stackTrace) {
      _logError(
        'Socket batch sync failed',
        error,
        stackTrace,
        boardId: boardId,
        event: 'crdt_update (batch)',
      );
    }

    return false;
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

  @override
  Future<void> persistCursorForBoard(String boardId) async {
    try {
      final isar = await _localDatabaseService.database;
      final latest = await isar.localCrdtUpdates
          .filter()
          .boardIdEqualTo(boardId)
          .sortByAppliedAtDesc()
          .findFirst();
      if (latest == null) return;
      if (latest.version == 0) return;

      // Use "0-0" as the stream ID prefix so the server's XREAD returns all
      // entries from the start.  The client's CRDT adapter deduplicates by
      // updateId, so re-applying already-seen updates is safe.  This avoids
      // mismatch between the client's appliedAt timestamp and the server's
      // Redis stream entry IDs.
      final cursor = '0-0:${latest.version}';

      final existing =
          await isar.localCanvasSyncStates.getByBoardId(boardId);
      await isar.writeTxn(() async {
        await isar.localCanvasSyncStates.putByBoardId(
          (existing ?? LocalCanvasSyncState()..boardId = boardId)
            ..lastSeenCursor = cursor,
        );
      });
    } catch (_) {}
  }

  /// Send explicit logout handshake to the server.
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

  /// Disconnect WebSocket locally.
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
    String? cursor,
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
      if (cursor != null) '[cursor] $cursor',
    ];

    developer.log(lines.join(' | '), name: 'CanvasWebSocket::$title');
  }
}
