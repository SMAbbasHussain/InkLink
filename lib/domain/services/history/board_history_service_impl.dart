import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloud_functions_service.dart';
import '../../../core/utils/network_config.dart';
import '../../models/history/board_operation.dart';
import '../../models/history/revert_plan.dart';
import 'board_history_service.dart';

/// Thin socket transport abstraction so the service can be unit-tested
/// without opening real sockets (mirrors `BoardChatSocket`).
abstract class BoardHistorySocket {
  bool get connected;
  void connect();
  void disconnect();
  void dispose();
  void on(String event, void Function(dynamic data) handler);
  void once(String event, void Function(dynamic data) handler);
  void emit(String event, [dynamic data]);
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic response) ack,
  });
}

class _LiveBoardHistorySocket implements BoardHistorySocket {
  final io.Socket _socket;
  _LiveBoardHistorySocket(this._socket);

  @override
  bool get connected => _socket.connected;

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void dispose() => _socket.dispose();

  @override
  void on(String event, void Function(dynamic data) handler) =>
      _socket.on(event, handler);

  @override
  void once(String event, void Function(dynamic data) handler) =>
      _socket.once(event, handler);

  @override
  void emit(String event, [dynamic data]) => _socket.emit(event, data);

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic response) ack,
  }) {
    _socket.emitWithAck(event, data, ack: ack);
  }
}

typedef BoardHistorySocketFactory = BoardHistorySocket Function(String token);

class BoardHistoryServiceImpl implements BoardHistoryService {
  /// Bounded in-memory block cache (D15) — the client never mirrors all logs.
  static const int _blockCacheCapacity = 20;

  final AuthService _authService;
  final CloudFunctionsService? _cloudFunctionsService;
  final BoardHistorySocketFactory _socketFactory;
  final Duration _connectTimeout;

  final LinkedHashMap<String, List<BoardOperation>> _blockCache =
      LinkedHashMap<String, List<BoardOperation>>();

  BoardHistorySocket? _socket;
  String? _connectedUserId;
  Future<bool>? _connectingFuture;
  String? _connectingUserId;
  int _connectGeneration = 0;
  int _reconnectAttempts = 0;
  bool _reconnectScheduled = false;
  bool _disposed = false;

  BoardHistoryServiceImpl({
    required AuthService authService,
    CloudFunctionsService? cloudFunctionsService,
    BoardHistorySocketFactory? socketFactory,
    Duration connectTimeout = const Duration(seconds: 5),
  }) : _authService = authService,
       _cloudFunctionsService = cloudFunctionsService,
       _connectTimeout = connectTimeout,
       _socketFactory = socketFactory ?? _defaultSocketFactory;

  static BoardHistorySocket _defaultSocketFactory(String token) {
    final socket = io.io(
      resolveWebSocketUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          // Reconnection is owned here: the built-in auto-reconnect would keep
          // reusing the token frozen at creation time.
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );
    return _LiveBoardHistorySocket(socket);
  }

  // ──────────────────────────────────────────────
  // Connection lifecycle
  // ──────────────────────────────────────────────

  Duration get _reconnectDelay =>
      Duration(seconds: math.min(30, 1 << _reconnectAttempts.clamp(0, 5)));

  void _teardownSocket([BoardHistorySocket? specificSocket]) {
    final stale = specificSocket ?? _socket;
    if (specificSocket == null || identical(_socket, specificSocket)) {
      _socket = null;
      _connectedUserId = null;
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

  void _scheduleReconnect() {
    if (_disposed || _reconnectScheduled) return;
    _reconnectScheduled = true;
    final delay = _reconnectDelay;
    _reconnectAttempts++;
    Future.delayed(delay, () {
      _reconnectScheduled = false;
      if (_disposed) return;
      final currentUid = _authService.getCurrentUserId();
      if (currentUid == null || currentUid.isEmpty) return;
      if (_socket != null && _socket!.connected) return;
      unawaited(_ensureConnected(expectedUid: currentUid));
    });
  }

  bool _isActiveIdentity(String expectedUid) {
    return !_disposed &&
        expectedUid.isNotEmpty &&
        _socket != null &&
        _socket!.connected &&
        _connectedUserId == expectedUid &&
        _authService.getCurrentUserId() == expectedUid;
  }

  Future<bool> _ensureConnected({String? expectedUid}) async {
    if (_disposed) return false;
    final currentUid = expectedUid ?? _authService.getCurrentUserId();
    if (currentUid == null || currentUid.isEmpty) {
      _connectGeneration++;
      _connectingFuture = null;
      _connectingUserId = null;
      _teardownSocket();
      return false;
    }
    if (_authService.getCurrentUserId() != currentUid) return false;
    if (_socket != null &&
        _socket!.connected &&
        _connectedUserId == currentUid) {
      return true;
    }
    if (_connectingFuture != null && _connectingUserId == currentUid) {
      final ok = await _connectingFuture!;
      return ok && _isActiveIdentity(currentUid);
    }

    final gen = ++_connectGeneration;
    _connectingUserId = currentUid;
    final future = _performConnect(currentUid, gen);
    _connectingFuture = future;
    try {
      final ok = await future;
      return ok && _isActiveIdentity(currentUid);
    } finally {
      if (identical(_connectingFuture, future)) {
        _connectingFuture = null;
        _connectingUserId = null;
      }
    }
  }

  Future<bool> _performConnect(String targetUid, int gen) async {
    _teardownSocket();

    final token = await _authService.getIdToken();
    if (_disposed ||
        gen != _connectGeneration ||
        token == null ||
        token.isEmpty ||
        _authService.getCurrentUserId() != targetUid) {
      return false;
    }

    final socket = _socketFactory(token);
    socket.on('disconnect', (_) {
      if (_disposed || gen != _connectGeneration) return;
      _scheduleReconnect();
    });
    socket.on('connect_error', (_) {
      if (_disposed || gen != _connectGeneration) return;
      _scheduleReconnect();
    });
    socket.connect();

    final completer = Completer<void>();
    socket.once('connect', (_) {
      if (!completer.isCompleted) completer.complete();
    });
    await Future.any([completer.future, Future.delayed(_connectTimeout)]);

    if (_disposed ||
        gen != _connectGeneration ||
        _authService.getCurrentUserId() != targetUid) {
      _teardownSocket(socket);
      return false;
    }
    if (socket.connected) {
      _socket = socket;
      _connectedUserId = targetUid;
      _reconnectAttempts = 0;
      return true;
    }
    _teardownSocket(socket);
    _scheduleReconnect();
    return false;
  }

  Future<Map<String, dynamic>> _request(
    String event,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final callerUid = _authService.getCurrentUserId();
    if (callerUid == null || callerUid.isEmpty) {
      throw const HistoryServiceException('unauthenticated');
    }
    final connected = await _ensureConnected(expectedUid: callerUid);
    if (!connected || !_isActiveIdentity(callerUid)) {
      throw const HistoryServiceException('socket_unavailable');
    }
    final socket = _socket;
    if (socket == null) {
      throw const HistoryServiceException('socket_unavailable');
    }

    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic response) {
        if (completer.isCompleted) return;
        if (response is Map) {
          completer.complete(Map<String, dynamic>.from(response));
        } else {
          completer.complete({
            'status': 'error',
            'message': 'invalid_response',
          });
        }
      },
    );

    final response = await completer.future.timeout(
      timeout,
      onTimeout: () => {'status': 'error', 'message': 'timeout'},
    );
    if (response['status'] != 'success') {
      throw HistoryServiceException(
        (response['message'] as String?) ?? 'unknown_error',
      );
    }
    return response;
  }

  // ──────────────────────────────────────────────
  // Reads
  // ──────────────────────────────────────────────

  @override
  Future<List<BoardOperation>> getBlock(String boardId, String blockId) async {
    // Block ids are only version ranges (`block_000001_000500`), so they repeat
    // across boards — always scope the cache key by board.
    final cacheKey = '$boardId/$blockId';
    final cached = _blockCache.remove(cacheKey);
    if (cached != null) {
      _blockCache[cacheKey] = cached; // mark most-recently used
      return cached;
    }

    final response = await _request('history_get_block', {
      'boardId': boardId,
      'blockId': blockId,
    });

    final rawOps = response['ops'];
    final ops = <BoardOperation>[];
    if (rawOps is List) {
      for (final entry in rawOps) {
        if (entry is Map) {
          ops.add(BoardOperation.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }

    _blockCache[cacheKey] = ops;
    while (_blockCache.length > _blockCacheCapacity) {
      _blockCache.remove(_blockCache.keys.first);
    }
    return ops;
  }

  @override
  Future<UserOpsPage> getUserOps(
    String boardId,
    String targetUid, {
    DateTime? fromTime,
    DateTime? toTime,
    int? beforeVersion,
    int limit = 50,
  }) async {
    final response = await _request('history_get_user_ops', {
      'boardId': boardId,
      'targetUid': targetUid,
      if (fromTime != null) 'fromTime': fromTime.toUtc().toIso8601String(),
      if (toTime != null) 'toTime': toTime.toUtc().toIso8601String(),
      if (beforeVersion != null) 'beforeVersion': beforeVersion,
      'limit': limit,
    });

    final rawOps = response['ops'];
    final ops = <BoardOperation>[];
    if (rawOps is List) {
      for (final entry in rawOps) {
        if (entry is Map) {
          ops.add(BoardOperation.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return UserOpsPage(
      ops: ops,
      hasMore: response['hasMore'] == true,
      nextBeforeVersion: (response['nextBeforeVersion'] as num?)?.toInt(),
    );
  }

  @override
  Future<HistoryPreview> previewVersion(String boardId, int version) async {
    final response = await _request(
      'history_preview_version',
      {'boardId': boardId, 'version': version},
      timeout: const Duration(seconds: 30),
    );
    final encoded = (response['stateUpdate'] as String?) ?? '';
    return HistoryPreview(
      version: (response['version'] as num?)?.toInt() ?? version,
      stateUpdateBytes: encoded.isEmpty
          ? Uint8List(0)
          : base64Decode(encoded),
      elementCount: (response['elementCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ──────────────────────────────────────────────
  // Revert
  // ──────────────────────────────────────────────

  @override
  Future<RevertPlan> planRevert(
    String boardId, {
    required String mode,
    int? targetVersion,
    String? targetUid,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? elementIds,
    String? requestId,
  }) async {
    final response = await _request(
      'history_plan_revert',
      {
        'boardId': boardId,
        'mode': mode,
        if (targetVersion != null) 'targetVersion': targetVersion,
        if (targetUid != null) 'targetUid': targetUid,
        if (fromTime != null) 'fromTime': fromTime.toUtc().toIso8601String(),
        if (toTime != null) 'toTime': toTime.toUtc().toIso8601String(),
        if (elementIds != null) 'elementIds': elementIds,
        if (requestId != null) 'requestId': requestId,
      },
      timeout: const Duration(seconds: 45),
    );
    final plan = response['plan'];
    if (plan is! Map) {
      throw const HistoryServiceException('invalid_response');
    }
    return RevertPlan.fromMap(Map<String, dynamic>.from(plan));
  }

  @override
  Future<RevertResult> applyRevert(
    String boardId, {
    required String planId,
    required Map<String, String> decisions,
    String? requestId,
  }) async {
    final response = await _request(
      'history_apply_revert',
      {
        'boardId': boardId,
        'planId': planId,
        'decisions': decisions,
        if (requestId != null) 'requestId': requestId,
      },
      timeout: const Duration(seconds: 45),
    );
    return RevertResult(
      appliedVersion: (response['appliedVersion'] as num?)?.toInt() ?? 0,
      reverted: (response['reverted'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      skipped: (response['skipped'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }

  @override
  Future<RevertResult> undoOwn(String boardId, {List<String>? updateIds}) async {
    final response = await _request(
      'history_undo_own',
      {
        'boardId': boardId,
        if (updateIds != null && updateIds.isNotEmpty) 'updateIds': updateIds,
      },
      timeout: const Duration(seconds: 45),
    );
    return RevertResult(
      appliedVersion: (response['appliedVersion'] as num?)?.toInt() ?? 0,
      reverted: (response['reverted'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      skipped: (response['skipped'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }

  // ──────────────────────────────────────────────
  // Undo requests (callables live in Cloud Functions)
  // ──────────────────────────────────────────────

  @override
  Future<String> submitUndoRequest({
    required String boardId,
    required List<String> elementIds,
    required String reason,
    DateTime? fromTime,
    DateTime? toTime,
  }) async {
    final functions = _cloudFunctionsService;
    if (functions == null) {
      throw const HistoryServiceException('functions_unavailable');
    }
    try {
      final response = await functions.httpsCallable('submitUndoRequest').call({
        'boardId': boardId,
        'targetElementIds': elementIds,
        'reason': reason,
        if (fromTime != null) 'timeRangeStart': fromTime.toUtc().toIso8601String(),
        if (toTime != null) 'timeRangeEnd': toTime.toUtc().toIso8601String(),
      });
      final data = response.data;
      if (data is Map && data['requestId'] != null) {
        return data['requestId'].toString();
      }
      return '';
    } catch (error) {
      developer.log(
        'submitUndoRequest failed: $error',
        name: 'BoardHistoryService',
      );
      throw HistoryServiceException('submit_failed', error.toString());
    }
  }

  @override
  Future<void> resolveUndoRequest({
    required String boardId,
    required String requestId,
    required String status,
    String? note,
    int? appliedVersion,
  }) async {
    final functions = _cloudFunctionsService;
    if (functions == null) {
      throw const HistoryServiceException('functions_unavailable');
    }
    try {
      await functions.httpsCallable('resolveUndoRequest').call({
        'boardId': boardId,
        'requestId': requestId,
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (appliedVersion != null) 'appliedVersion': appliedVersion,
      });
    } catch (error) {
      developer.log(
        'resolveUndoRequest failed: $error',
        name: 'BoardHistoryService',
      );
      throw HistoryServiceException('resolve_failed', error.toString());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectGeneration++;
    _connectingFuture = null;
    _connectingUserId = null;
    _blockCache.clear();
    _teardownSocket();
  }
}
