import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/auth_service.dart';
import '../../../core/utils/network_config.dart';
import '../../models/canvas/crdt_update.dart';
import 'canvas_sync_repository.dart';
import 'crdt_local_store.dart';

class FirestoreCanvasSyncRepository implements CanvasSyncRepository {
  final AuthService _authService;
  final CrdtLocalStore _store;
  static const int _maxPayloadBase64Length = 900000;
  // Socket.IO client (optional). When present and connected, we'll prefer websocket transport.
  io.Socket? _socket;
  String? _connectedUserId;
  String? _connectingUserId;
  Future<bool>? _connectingFuture;
  int _connectGeneration = 0;
  bool _isSingleUserBoard = false;
  final Map<String, int> _watchedBoardRefCounts = <String, int>{};
  // The server only joins the board room after authorizing the member. Keep
  // the confirmation per socket so a reconnect/replacement re-watches, and
  // retry when the membership/access cache has not caught up yet.
  final Map<String, String> _watchConfirmedSocketIds = <String, String>{};
  final Map<String, Timer> _watchRetryTimers = <String, Timer>{};
  final Map<String, int> _watchAttempts = <String, int>{};
  final Set<String> _watchInFlight = <String>{};
  final Map<String, void Function(dynamic)> _updateHandlers =
      <String, void Function(dynamic)>{};
  final Map<String, void Function(dynamic)> _previewHandlers =
      <String, void Function(dynamic)>{};
  final Map<String, List<LocalCrdtUpdate>> _inboundUpdateBuffers =
      <String, List<LocalCrdtUpdate>>{};
  final Map<String, int> _serverBoardVersions = <String, int>{};
  final Map<String, int> _highestAppliedVersionPerBoard = <String, int>{};
  final Map<String, bool> _gapRecoveryInFlight = <String, bool>{};
  final Map<String, List<LocalCrdtUpdate>> _pendingOutOfOrderUpdates =
      <String, List<LocalCrdtUpdate>>{};
  Timer? _versionPeriodicCheckTimer;
  StreamController<List<LocalCrdtUpdate>>? _peerUpdatesController;
  io.Socket? _handlersBoundSocket;
  StreamController<List<LocalCrdtUpdate>>? _socketUpdatesController;
  StreamController<List<LocalCrdtUpdate>>? _socketPreviewController;

  FirestoreCanvasSyncRepository({
    required this._authService,
    required this._store,
  });

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {
    _isSingleUserBoard = isSingleUser;
  }

  @override
  String? get currentUserId => _authService.getCurrentUserId();

  @override
  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update) async {
    await _store.saveUpdateAndSyncedAt(update);
  }

  @override
  Future<void> clearLocalCrdtUpdatesForBoard(String boardId) async {
    await _store.deleteUpdatesForBoard(boardId);
  }

  void _teardownSocket([io.Socket? specificSocket]) {
    final stale = specificSocket ?? _socket;
    if (specificSocket == null || identical(_socket, specificSocket)) {
      _socket = null;
      _connectedUserId = null;
      for (final timer in _watchRetryTimers.values.toList()) {
        timer.cancel();
      }
      _watchRetryTimers.clear();
      _watchConfirmedSocketIds.clear();
      _watchAttempts.clear();
      _watchInFlight.clear();
      _versionPeriodicCheckTimer?.cancel();
      _versionPeriodicCheckTimer = null;
      _handlersBoundSocket = null;
    }
    if (stale == null) return;
    try {
      stale.dispose();
    } catch (_) {
      try {
        stale.disconnect();
      } catch (_) {}
    }
  }

  Future<bool> _ensureSocketConnected() async {
    final currentUid = _authService.getCurrentUserId();
    if (currentUid == null || currentUid.isEmpty) {
      _connectGeneration++;
      _connectingFuture = null;
      _connectingUserId = null;
      _teardownSocket();
      return false;
    }

    if (_socket != null &&
        _socket!.connected &&
        _connectedUserId == currentUid) {
      return true;
    }

    if (_connectingFuture != null && _connectingUserId == currentUid) {
      final ok = await _connectingFuture!;
      return ok &&
          _socket != null &&
          _socket!.connected &&
          _connectedUserId == currentUid &&
          _authService.getCurrentUserId() == currentUid;
    }

    final gen = ++_connectGeneration;
    _connectingUserId = currentUid;
    final future = _performSocketConnect(currentUid, gen);
    _connectingFuture = future;
    try {
      final ok = await future;
      return ok &&
          _socket != null &&
          _socket!.connected &&
          _connectedUserId == currentUid &&
          _authService.getCurrentUserId() == currentUid;
    } finally {
      if (identical(_connectingFuture, future)) {
        _connectingFuture = null;
        _connectingUserId = null;
      }
    }
  }

  Future<bool> _performSocketConnect(String targetUid, int gen) async {
    _teardownSocket();

    final token = await _authService.getIdToken();
    if (gen != _connectGeneration ||
        token == null ||
        token.isEmpty ||
        _authService.getCurrentUserId() != targetUid) {
      return false;
    }

    final serverUrl = resolveWebSocketUrl();
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(3000)
          .build(),
    );
    socket.connect();

    final connectCompleter = Completer<void>();
    socket.onConnect((_) {
      if (!connectCompleter.isCompleted) connectCompleter.complete();
      if (gen != _connectGeneration) return;
      // Make this the active socket before re-watching; _watchBoard needs the
      // authenticated socket to emit and await its acknowledgement.
      _socket = socket;
      _connectedUserId = targetUid;
      _bindStoredSocketHandlers(socket);
      for (final boardId in _watchedBoardRefCounts.keys.toList()) {
        if ((_watchedBoardRefCounts[boardId] ?? 0) > 0) {
          _watchBoard(boardId);
        }
      }
    });

    await Future.any([
      connectCompleter.future,
      // The web keeps no local copy of a board: giving up on a slow first
      // connection would show it empty, so allow it longer than phones.
      Future.delayed(Duration(seconds: kIsWeb ? 10 : 2)),
    ]);

    if (gen != _connectGeneration ||
        _authService.getCurrentUserId() != targetUid) {
      _teardownSocket(socket);
      return false;
    }

    if (socket.connected) {
      _socket = socket;
      _connectedUserId = targetUid;
      _bindStoredSocketHandlers(socket);
      for (final boardId in _watchedBoardRefCounts.keys.toList()) {
        if ((_watchedBoardRefCounts[boardId] ?? 0) > 0) {
          _watchBoard(boardId);
        }
      }
      return true;
    }

    _teardownSocket(socket);
    return false;
  }

  /// Re-attaches the active board listeners when a disconnected socket is
  /// replaced. Listeners are registered on the Socket.IO object, so a new
  /// object would otherwise join the room but never receive its events.
  void _bindStoredSocketHandlers(io.Socket socket) {
    if (identical(_handlersBoundSocket, socket)) return;
    _handlersBoundSocket = socket;
    for (final handler in _updateHandlers.values.toList()) {
      socket.on('crdt_update', handler);
    }
    for (final handler in _previewHandlers.values.toList()) {
      socket.on('crdt_preview', handler);
    }
    socket.off('peer_crdt_updates_requested');
    socket.on('peer_crdt_updates_requested', _handlePeerUpdatesRequested);
    socket.off('peer_crdt_updates_received');
    socket.on('peer_crdt_updates_received', _handlePeerUpdatesReceived);
  }

  /// Ensures this socket is in the board room, waiting for the server's
  /// acknowledgement rather than optimistically assuming the join succeeded.
  /// The server can reject a join while a newly accepted membership is still
  /// propagating, so retry with backoff until it confirms or the board is
  /// closed. `socket.join` is idempotent, making repeat emits safe.
  void _watchBoard(String boardId) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    if (_watchConfirmedSocketIds[boardId] == socket.id) return;
    if (_watchInFlight.contains(boardId)) return;
    _watchRetryTimers.remove(boardId)?.cancel();
    _watchInFlight.add(boardId);

    final current = socket;
    unawaited(() async {
      try {
        final ack = await _emitWithAck(
          'watch_board',
          boardId,
          timeout: const Duration(seconds: 4),
        );
        if (!identical(_socket, current) || !current.connected) return;
        final socketId = current.id;
        if (ack != null && ack['status'] == 'success' && socketId != null) {
          _watchConfirmedSocketIds[boardId] = socketId;
          _watchAttempts.remove(boardId);
          _watchRetryTimers.remove(boardId)?.cancel();
          final version = (ack['currentVersion'] as num?)?.toInt();
          if (version != null && version > 0) {
            _serverBoardVersions[boardId] = version;
          }
          _logWs(
            'WATCH CONFIRMED',
            boardId,
            'watch_board',
            detail: version != null ? 'version=$version' : null,
          );
          return;
        }

        // A malformed board id will never succeed; stop retrying it.
        if (ack != null && ack['message'] == 'invalid_board_id') return;

        final attempt = (_watchAttempts[boardId] ?? 0) + 1;
        _watchAttempts[boardId] = attempt;
        if (attempt >= 12) {
          _logWs(
            'WATCH GAVE UP',
            boardId,
            'watch_board',
            detail: ack == null
                ? 'no_ack'
                : (ack['message']?.toString() ?? 'not_joined'),
          );
          return;
        }
        // 500ms, 1s, 1.5s ... capped at 4s. Membership propagation is usually
        // fast, but a server-side cache may need a few seconds to invalidate.
        final delayMs = 500 * (attempt < 8 ? attempt : 8);
        _watchRetryTimers[boardId]?.cancel();
        _watchRetryTimers[boardId] = Timer(Duration(milliseconds: delayMs), () {
          if ((_watchedBoardRefCounts[boardId] ?? 0) > 0) {
            _watchBoard(boardId);
          }
        });
        _logWs(
          'WATCH RETRY',
          boardId,
          'watch_board',
          detail: ack == null
              ? 'no_ack'
              : (ack['message']?.toString() ?? 'not_joined'),
        );
      } finally {
        _watchInFlight.remove(boardId);
      }
    }());
  }

  void _bindBoardSocketStream({
    required String boardId,
    required StreamController<List<LocalCrdtUpdate>> controller,
    required String eventName,
    required String subscribeLabel,
    required void Function(dynamic data) handleEvent,
  }) {
    final socket = _socket;
    if (socket == null) return;
    final prevCount = _watchedBoardRefCounts[boardId] ?? 0;
    _watchedBoardRefCounts[boardId] = prevCount + 1;
    if (prevCount == 0) {
      _watchConfirmedSocketIds.remove(boardId);
    }
    _logWs('SUBSCRIBE SENT', boardId, subscribeLabel);
    _watchBoard(boardId);
    final handlers = eventName == 'crdt_update'
        ? _updateHandlers
        : _previewHandlers;
    handlers[boardId] = handleEvent;
    if (identical(_handlersBoundSocket, socket)) {
      socket.on(eventName, handleEvent);
    } else {
      _bindStoredSocketHandlers(socket);
    }

    controller.onCancel = () {
      try {
        final remaining = (_watchedBoardRefCounts[boardId] ?? 1) - 1;
        if (remaining <= 0) {
          _watchedBoardRefCounts.remove(boardId);
          _watchRetryTimers.remove(boardId)?.cancel();
          _watchConfirmedSocketIds.remove(boardId);
          _watchAttempts.remove(boardId);
          if (socket.connected) {
            socket.emit('leave_board', boardId);
          }
        } else {
          _watchedBoardRefCounts[boardId] = remaining;
        }
        final handlers = eventName == 'crdt_update'
            ? _updateHandlers
            : _previewHandlers;
        if (identical(handlers[boardId], handleEvent)) {
          handlers.remove(boardId);
        }
        final handlerSocket = identical(_handlersBoundSocket, socket)
            ? socket
            : _handlersBoundSocket;
        handlerSocket?.off(eventName, handleEvent);
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
    final existing = await _store.getByUpdateId(updateId);
    if (existing == null) return;

    existing.isSynced = true;
    await _store.putUpdate(existing);
  }

  @override
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) async {
    final existing = await _store.getByUpdateId(updateId);
    if (existing == null) return;

    existing.isDeleted = isDeleted;
    await _store.putUpdate(existing);
  }

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate(
    String boardId,
    String elementId,
  ) async {
    final updates = await _store.updatesForBoardNewestFirst(boardId);

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
    // Use only previously-synced rows to compute the local 'since' cursor.
    // This avoids client-clock based local entries skewing hydration windows.
    final latest = await _store.latestSyncedUpdate(boardId);
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
    final existing = await _store.getByUpdateId(updateId);
    if (existing == null) return;

    existing.payloadBase64 = payloadBase64;
    existing.appliedAt = DateTime.now();
    existing.isSynced = false; // Mark for re-sync since payload changed
    await _store.putUpdate(existing);

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
      return await _store.getLastSeenCursor(boardId);
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
      if (_socket == null || !_socket!.connected) {
        unawaited(_ensureSocketConnected());
        return;
      }
      _socket!.emit('crdt_preview', {
        'boardId': boardId,
        'preview': {
          'previewId': previewId,
          'elementId': elementId,
          'payloadBase64': payloadBase64,
          'sourceClientId': sourceClientId,
        },
      });
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

  LocalCrdtUpdate _parseRemoteUpdateMap(
    Map<String, dynamic> map,
    String defaultBoardId,
  ) {
    final payload = (map['update'] as Map<String, dynamic>?) ?? map;
    final appliedAtStr =
        payload['appliedAt'] as String? ??
        payload['timestamp'] as String? ??
        map['appliedAt'] as String? ??
        map['timestamp'] as String?;
    final version = (payload['version'] as num?)?.toInt() ??
        (map['version'] as num?)?.toInt() ??
        0;
    return LocalCrdtUpdate()
      ..updateId = (payload['updateId'] as String?) ??
          (map['updateId'] as String?) ??
          (map['id'] as String?) ??
          ''
      ..boardId = (payload['boardId'] as String?) ??
          (map['boardId'] as String?) ??
          defaultBoardId
      ..elementId =
          payload['elementId'] as String? ?? map['elementId'] as String?
      ..action = payload['action'] as String? ?? map['action'] as String?
      ..affectedElementIds =
          ((payload['affectedElementIds'] ?? map['affectedElementIds'])
                  as List?)
              ?.whereType<String>()
              .toList()
      ..payloadBase64 = (payload['payloadBase64'] as String?) ??
          (map['payloadBase64'] as String?) ??
          ''
      ..sourceClientId = (payload['sourceClientId'] as String?) ??
          (map['sourceClientId'] as String?) ??
          ''
      ..appliedAt = appliedAtStr != null
          ? DateTime.tryParse(appliedAtStr) ?? DateTime.now()
          : DateTime.now()
      ..isSynced = true
      ..version = version;
  }

  @override
  Future<int?> preWatchBoard(String boardId) async {
    _inboundUpdateBuffers.putIfAbsent(boardId, () => <LocalCrdtUpdate>[]);
    await _ensureSocketConnected();
    final socket = _socket;
    if (socket != null && socket.connected) {
      if (_updateHandlers[boardId] == null) {
        _updateHandlers[boardId] = (dynamic data) {
          try {
            final map = data as Map<String, dynamic>;
            if ((map['boardId'] as String?) == boardId) {
              final update = _parseRemoteUpdateMap(map, boardId);
              _inboundUpdateBuffers[boardId]?.add(update);
              final h = _highestAppliedVersionPerBoard[boardId] ?? 0;
              if (update.version > h) {
                _highestAppliedVersionPerBoard[boardId] = update.version;
              }
            }
          } catch (_) {}
        };
        if (identical(_handlersBoundSocket, socket)) {
          socket.on('crdt_update', _updateHandlers[boardId]!);
        } else {
          _bindStoredSocketHandlers(socket);
        }
      }
      _watchBoard(boardId);
      final ack = await _emitWithAck(
        'watch_board',
        boardId,
        timeout: const Duration(seconds: 4),
      );
      if (ack != null && ack['status'] == 'success') {
        final ver = (ack['currentVersion'] as num?)?.toInt();
        if (ver != null && ver > 0) {
          _serverBoardVersions[boardId] = ver;
        }
        return ver;
      }
    }
    return _serverBoardVersions[boardId];
  }

  @override
  Future<List<LocalCrdtUpdate>> fetchMissingCrdtUpdates({
    required String boardId,
    int? fromVersion,
    int? toVersion,
    int? sinceVersion,
    List<int>? missingVersions,
  }) async {
    try {
      await _ensureSocketConnected();
      final socket = _socket;
      if (socket == null || !socket.connected) {
        return const <LocalCrdtUpdate>[];
      }
      final payload = <String, dynamic>{
        'boardId': boardId,
        if (fromVersion != null) 'fromVersion': fromVersion,
        if (toVersion != null) 'toVersion': toVersion,
        if (sinceVersion != null) 'sinceVersion': sinceVersion,
        if (missingVersions != null) 'missingVersions': missingVersions,
      };
      final ack = await _emitWithAck(
        'get_missing_crdt_updates',
        payload,
        timeout: const Duration(seconds: 4),
      );
      if (ack != null && ack['status'] == 'success') {
        final updatesList = (ack['updates'] as List?) ?? const [];
        final parsed = <LocalCrdtUpdate>[];
        for (final item in updatesList) {
          if (item is Map<String, dynamic>) {
            parsed.add(_parseRemoteUpdateMap(item, boardId));
          }
        }
        return parsed;
      }
    } catch (e, st) {
      _logError('Failed to fetch missing crdt updates', e, st, boardId: boardId);
    }
    return const <LocalCrdtUpdate>[];
  }

  @override
  void requestPeerCrdtUpdates({
    required String boardId,
    int? fromVersion,
    int? toVersion,
    List<int>? missingVersions,
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('request_peer_crdt_updates', {
      'boardId': boardId,
      if (fromVersion != null) 'fromVersion': fromVersion,
      if (toVersion != null) 'toVersion': toVersion,
      if (missingVersions != null) 'missingVersions': missingVersions,
    });
  }

  @override
  void relayPeerCrdtUpdates({
    required String boardId,
    required List<LocalCrdtUpdate> updates,
    String? targetUid,
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('relay_peer_crdt_updates', {
      'boardId': boardId,
      if (targetUid != null) 'targetUid': targetUid,
      'updates': updates
          .map(
            (u) => {
              'updateId': u.updateId,
              'boardId': u.boardId,
              'elementId': u.elementId,
              'action': u.action,
              'affectedElementIds': u.affectedElementIds,
              'payloadBase64': u.payloadBase64,
              'sourceClientId': u.sourceClientId,
              'timestamp': u.appliedAt.toIso8601String(),
              'version': u.version,
            },
          )
          .toList(),
    });
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchPeerCrdtUpdates(String boardId) {
    _peerUpdatesController ??=
        StreamController<List<LocalCrdtUpdate>>.broadcast();
    return _peerUpdatesController!.stream;
  }

  Future<void> _handlePeerUpdatesRequested(dynamic data) async {
    try {
      final map = data as Map<String, dynamic>;
      final boardId = map['boardId'] as String?;
      final requesterUid = map['requesterUid'] as String?;
      if (boardId == null || requesterUid == null || requesterUid == currentUserId) {
        return;
      }
      final fromVersion = (map['fromVersion'] as num?)?.toInt();
      final toVersion = (map['toVersion'] as num?)?.toInt();
      final missingList = (map['missingVersions'] as List?)
          ?.whereType<num>()
          .map((n) => n.toInt())
          .toSet();

      final local = await _store.updatesForBoard(boardId);
      final matching = local.where((u) {
        if (missingList != null && missingList.contains(u.version)) return true;
        if (fromVersion != null && toVersion != null) {
          return u.version >= fromVersion && u.version <= toVersion;
        }
        if (fromVersion != null) return u.version >= fromVersion;
        return false;
      }).toList();

      if (matching.isNotEmpty) {
        relayPeerCrdtUpdates(
          boardId: boardId,
          updates: matching,
          targetUid: requesterUid,
        );
      }
    } catch (_) {}
  }

  void _handlePeerUpdatesReceived(dynamic data) {
    try {
      final map = data as Map<String, dynamic>;
      final boardId = map['boardId'] as String?;
      final rawUpdates = map['updates'] as List?;
      if (boardId == null || rawUpdates == null) return;
      final updates = <LocalCrdtUpdate>[];
      for (final raw in rawUpdates) {
        if (raw is Map<String, dynamic>) {
          updates.add(_parseRemoteUpdateMap(raw, boardId));
        }
      }
      if (updates.isNotEmpty) {
        _peerUpdatesController?.add(updates);
        for (final u in updates) {
          final h = _highestAppliedVersionPerBoard[boardId] ?? 0;
          if (u.version > h) {
            _highestAppliedVersionPerBoard[boardId] = u.version;
          }
        }
        _socketUpdatesController?.add(updates);
        _drainPendingOutOfOrderUpdates(boardId);
      }
    } catch (_) {}
  }

  void _drainPendingOutOfOrderUpdates(String boardId) {
    final pending = _pendingOutOfOrderUpdates[boardId];
    if (pending == null || pending.isEmpty) return;

    pending.sort((a, b) => a.version.compareTo(b.version));
    final toEmit = <LocalCrdtUpdate>[];

    while (pending.isNotEmpty) {
      final first = pending.first;
      final currentHighest = _highestAppliedVersionPerBoard[boardId] ?? 0;
      if (first.version <= currentHighest) {
        pending.removeAt(0);
      } else if (first.version == currentHighest + 1) {
        pending.removeAt(0);
        _highestAppliedVersionPerBoard[boardId] = first.version;
        toEmit.add(first);
      } else {
        break;
      }
    }

    if (toEmit.isNotEmpty) {
      _socketUpdatesController?.add(toEmit);
    }
  }

  void _triggerGapRecovery(String boardId, int fromVersion, int toVersion) {
    if (_gapRecoveryInFlight[boardId] == true) return;
    _gapRecoveryInFlight[boardId] = true;
    unawaited(() async {
      try {
        _logWs(
          'RECOVERY START',
          boardId,
          'get_missing_crdt_updates',
          detail: 'from=$fromVersion to=$toVersion',
        );
        final missing = await fetchMissingCrdtUpdates(
          boardId: boardId,
          fromVersion: fromVersion,
          toVersion: toVersion,
        );

        if (missing.isNotEmpty) {
          for (final update in missing) {
            await saveLocalCrdtUpdate(update);
            final currentHighest = _highestAppliedVersionPerBoard[boardId] ?? 0;
            if (update.version > currentHighest) {
              _highestAppliedVersionPerBoard[boardId] = update.version;
            }
          }
          _socketUpdatesController?.add(missing);
          _drainPendingOutOfOrderUpdates(boardId);
        } else {
          _logWs(
            'RECOVERY PEER FALLBACK',
            boardId,
            'request_peer_crdt_updates',
            detail: 'from=$fromVersion to=$toVersion',
          );
          requestPeerCrdtUpdates(
            boardId: boardId,
            fromVersion: fromVersion,
            toVersion: toVersion,
          );
        }
      } catch (e, st) {
        _logError('Gap recovery failed', e, st, boardId: boardId);
        requestPeerCrdtUpdates(
          boardId: boardId,
          fromVersion: fromVersion,
          toVersion: toVersion,
        );
      } finally {
        _gapRecoveryInFlight[boardId] = false;
        _drainPendingOutOfOrderUpdates(boardId);
      }
    }());
  }

  void _startVersionPeriodicCheck() {
    _versionPeriodicCheckTimer ??= Timer.periodic(
      const Duration(seconds: 8),
      (_) async {
        final socket = _socket;
        if (socket == null || !socket.connected) return;
        final boardIds = _watchedBoardRefCounts.keys.toList();
        for (final boardId in boardIds) {
          if ((_watchedBoardRefCounts[boardId] ?? 0) <= 0) continue;
          final currentHighest = _highestAppliedVersionPerBoard[boardId] ?? 0;
          if (currentHighest <= 0) continue;
          try {
            final missing = await fetchMissingCrdtUpdates(
              boardId: boardId,
              sinceVersion: currentHighest,
            );
            if (missing.isNotEmpty) {
              _logWs(
                'PERIODIC RECOVERY FOUND UPDATES',
                boardId,
                'get_missing_crdt_updates',
                detail: 'count=${missing.length}',
              );
              for (final update in missing) {
                await saveLocalCrdtUpdate(update);
                final h = _highestAppliedVersionPerBoard[boardId] ?? 0;
                if (update.version > h) {
                  _highestAppliedVersionPerBoard[boardId] = update.version;
                }
              }
              _socketUpdatesController?.add(missing);
              _drainPendingOutOfOrderUpdates(boardId);
            }
          } catch (_) {}
        }
      },
    );
  }

  @override
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId) async {
    return _store.updatesForBoard(boardId);
  }

  @override
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
    String? lastSeenCursor,
    bool preferSocket = true,
    bool ignoreCursor = false,
  }) async {
    if (preferSocket) {
      try {
        await _ensureSocketConnected();

        if (_socket != null && _socket!.connected) {
          // Load stored cursor from local sync state if not provided, unless
          // the caller explicitly requested a full snapshot hydration.
          String? cursor = ignoreCursor ? null : lastSeenCursor;
          if (!ignoreCursor && cursor == null) {
            cursor = await _store.getLastSeenCursor(boardId);
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
            allUpdates.add(
              LocalCrdtUpdate()
                ..updateId =
                    '__snapshot__${snapshotData['lastAppliedVersion'] ?? 0}'
                ..boardId = boardId
                ..elementId = null
                ..payloadBase64 = stateUpdate
                ..sourceClientId = '__server_snapshot__'
                ..appliedAt = DateTime.now()
                ..isSynced = true
                ..version = snapshotData['lastAppliedVersion'] as int? ?? 0,
            );
          }
        }
      }

      // --- Parse updates list ---
      final updatesList = (response['updates'] as List?) ?? <dynamic>[];
      for (final data in updatesList) {
        if (data is Map<String, dynamic>) {
          final u = _parseRemoteUpdateMap(data, boardId);
          allUpdates.add(u);
          final currentHighest = _highestAppliedVersionPerBoard[boardId] ?? 0;
          if (u.version > currentHighest) {
            _highestAppliedVersionPerBoard[boardId] = u.version;
          }
        }
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
      await _store.saveLastSeenCursor(boardId, cursor);
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
    yield* _store.watchUpdatesForBoard(boardId);
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

        if ((_highestAppliedVersionPerBoard[boardId] ?? 0) == 0) {
          final latestUpdate = await _store.highestVersionUpdate(boardId);
          if (latestUpdate != null && latestUpdate.version > 0) {
            _highestAppliedVersionPerBoard[boardId] = latestUpdate.version;
          }
        }

        void handleUpdate(dynamic data) {
          try {
            final map = data as Map<String, dynamic>;
            if ((map['boardId'] as String?) == boardId) {
              final update = _parseRemoteUpdateMap(map, boardId);
              final version = update.version;
              final currentHighest =
                  _highestAppliedVersionPerBoard[boardId] ?? 0;

              _logWs(
                'UPDATE RECEIVED',
                boardId,
                'crdt_update',
                updateId: update.updateId,
                elementId: update.elementId,
                detail: 'version=$version, highest=$currentHighest',
              );

              if (version > 0 &&
                  currentHighest > 0 &&
                  version > currentHighest + 1) {
                _logWs(
                  'GAP DETECTED',
                  boardId,
                  'crdt_update',
                  detail:
                      'missing ${currentHighest + 1}..${version - 1}, got $version',
                );
                _pendingOutOfOrderUpdates
                    .putIfAbsent(boardId, () => <LocalCrdtUpdate>[])
                    .add(update);
                _triggerGapRecovery(boardId, currentHighest + 1, version - 1);
              } else {
                if (version > currentHighest) {
                  _highestAppliedVersionPerBoard[boardId] = version;
                }
                _socketUpdatesController?.add([update]);
                _drainPendingOutOfOrderUpdates(boardId);
              }
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

        final buffered = _inboundUpdateBuffers.remove(boardId);
        if (buffered != null && buffered.isNotEmpty) {
          for (final b in buffered) {
            handleUpdate({
              'boardId': boardId,
              'update': {
                'updateId': b.updateId,
                'elementId': b.elementId,
                'action': b.action,
                'affectedElementIds': b.affectedElementIds,
                'payloadBase64': b.payloadBase64,
                'sourceClientId': b.sourceClientId,
                'version': b.version,
                'timestamp': b.appliedAt.toIso8601String(),
              },
            });
          }
        }

        _startVersionPeriodicCheck();

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
    String action = 'upsert',
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
          'action': action,
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
    final toSync = await _store.unsyncedUpdatesOldestFirst(boardId);
    if (toSync.isEmpty) return true;
    // Push each pending update to server via socket
    try {
      if (_socket != null && _socket!.connected) {
        for (final local in toSync) {
          if (local.payloadBase64.isEmpty ||
              local.payloadBase64.length > _maxPayloadBase64Length) {
            continue;
          }
          _logWs(
            'UPDATE SENT',
            boardId,
            'crdt_update',
            updateId: local.updateId,
            elementId: local.elementId,
          );
          final updateData = <String, dynamic>{
            'updateId': local.updateId,
            'payloadBase64': local.payloadBase64,
            'sourceClientId': userId,
            'elementId': local.elementId,
            'action': local.action ?? 'upsert',
          };
          if (_isSingleUserBoard) {
            updateData['_singleUser'] = true;
          }
          final ack = await _emitWithAck('crdt_update', {
            'boardId': boardId,
            'update': updateData,
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
          await _store.deleteSyncedUpdatesAppliedBefore(
            boardId,
            DateTime.now().subtract(const Duration(hours: 1)),
          );
          final latest = await _store.latestUpdate(boardId);
          if (latest != null) {
            await _store.saveLastSyncedAppliedAt(boardId, latest.appliedAt);
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
      final latest = await _store.latestUpdate(boardId);
      if (latest == null) return;
      if (latest.version == 0) return;

      // Use "0-0" as the stream ID prefix so the server's XREAD returns all
      // entries from the start.  The client's CRDT adapter deduplicates by
      // updateId, so re-applying already-seen updates is safe.  This avoids
      // mismatch between the client's appliedAt timestamp and the server's
      // Redis stream entry IDs.
      final cursor = '0-0:${latest.version}';

      await _store.saveLastSeenCursor(boardId, cursor);
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
    _connectGeneration++;
    _connectingFuture = null;
    _connectingUserId = null;
    _teardownSocket();
    await _socketUpdatesController?.close();
    _socketUpdatesController = null;
    await _socketPreviewController?.close();
    _socketPreviewController = null;
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
