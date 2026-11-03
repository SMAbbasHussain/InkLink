import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/auth_service.dart';
import '../../../core/utils/network_config.dart';
import '../../../features/canvas/models/board_chat_message.dart';
import 'board_chat_service.dart';

/// Thin socket transport abstraction so [BoardChatServiceImpl] can be
/// deterministically unit-tested without opening real network sockets.
abstract class BoardChatSocket {
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

class _LiveBoardChatSocket implements BoardChatSocket {
  final io.Socket _socket;
  _LiveBoardChatSocket(this._socket);

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

typedef BoardChatSocketFactory = BoardChatSocket Function(String token);

class BoardChatServiceImpl implements BoardChatService {
  final AuthService _authService;
  final BoardChatSocketFactory _socketFactory;
  final Duration _connectTimeout;

  BoardChatSocket? _socket;
  final StreamController<BoardChatMessage> _chatMessageController =
      StreamController<BoardChatMessage>.broadcast();

  /// Board whose room should be re-subscribed after a reconnect.
  String? _watchedBoardId;
  String? _connectedUserId;
  String? _connectingUserId;
  Future<bool>? _connectingFuture;
  int _connectGeneration = 0;
  int _reconnectAttempts = 0;
  bool _reconnectScheduled = false;
  bool _disposed = false;

  BoardChatServiceImpl({
    required AuthService authService,
    BoardChatSocketFactory? socketFactory,
    Duration connectTimeout = const Duration(seconds: 5),
  })  : _authService = authService,
        _connectTimeout = connectTimeout,
        _socketFactory = socketFactory ?? _defaultSocketFactory;

  static BoardChatSocket _defaultSocketFactory(String token) {
    final socket = io.io(
      resolveWebSocketUrl(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          // Reconnection is owned by this service: the built-in
          // auto-reconnect would reuse the token frozen at creation time and
          // fail forever once that token expires.
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );
    return _LiveBoardChatSocket(socket);
  }

  @override
  Stream<BoardChatMessage> watchChatMessages(String boardId) {
    return _chatMessageController.stream.where((m) => m.boardId == boardId);
  }

  BoardChatSocket _buildSocket(String token, String boundUserId, int gen) {
    final socket = _socketFactory(token);

    socket.on('board_chat_message', (data) {
      // Drop messages from superseded sockets or previous accounts.
      if (_disposed ||
          !identical(_socket, socket) ||
          _connectedUserId != boundUserId ||
          _authService.getCurrentUserId() != boundUserId) {
        return;
      }
      try {
        if (data is Map) {
          final message =
              BoardChatMessage.fromMap(Map<String, dynamic>.from(data));
          if (!_chatMessageController.isClosed) {
            _chatMessageController.add(message);
          }
        }
      } catch (e) {
        developer.log(
          'Error parsing chat message: $e',
          name: 'BoardChatService',
        );
      }
    });

    socket.on('disconnect', (data) {
      if (_disposed || gen != _connectGeneration) return;
      developer.log(
        'Socket disconnected; scheduling reconnect with fresh token',
        name: 'BoardChatService',
      );
      _scheduleReconnect();
    });

    socket.on('connect_error', (data) {
      if (_disposed || gen != _connectGeneration) return;
      developer.log(
        'Socket connect_error: $data; scheduling reconnect with fresh token',
        name: 'BoardChatService',
      );
      _scheduleReconnect();
    });

    return socket;
  }

  /// Capped exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
  Duration get _reconnectDelay =>
      Duration(seconds: math.min(30, 1 << _reconnectAttempts.clamp(0, 5)));

  void _scheduleReconnect() {
    if (_disposed || _reconnectScheduled || _watchedBoardId == null) return;
    _reconnectScheduled = true;
    final delay = _reconnectDelay;
    _reconnectAttempts++;
    Future.delayed(delay, () {
      _reconnectScheduled = false;
      if (_disposed || _watchedBoardId == null) return;
      final currentUid = _authService.getCurrentUserId();
      if (currentUid == null || currentUid.isEmpty) return;
      if (_socket != null &&
          _socket!.connected &&
          _connectedUserId == currentUid) {
        return;
      }
      unawaited(_ensureConnected());
    });
  }

  void _teardownSocket([BoardChatSocket? specificSocket]) {
    final stale = specificSocket ?? _socket;
    if (specificSocket == null || identical(_socket, specificSocket)) {
      _socket = null;
      _connectedUserId = null;
    }
    if (stale == null) return;
    try {
      // dispose() disconnects and clears all listeners so stale handlers
      // can't fire on the abandoned socket.
      stale.dispose();
    } catch (e) {
      developer.log(
        'Stale socket dispose failed: $e',
        name: 'BoardChatService',
      );
      try {
        stale.disconnect();
      } catch (_) {}
    }
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

    // Reject callers whose captured UID already differs from the live auth UID.
    if (_authService.getCurrentUserId() != currentUid) {
      return false;
    }

    if (_socket != null &&
        _socket!.connected &&
        _connectedUserId == currentUid) {
      return true;
    }

    // Reuse an in-flight connection ONLY if it was initiated for `currentUid`.
    if (_connectingFuture != null && _connectingUserId == currentUid) {
      final ok = await _connectingFuture!;
      return ok && _isActiveIdentity(currentUid);
    }

    // Either no connection is in flight, or an in-flight connection belongs to
    // a previous UID — supersede it and authenticate a fresh socket for `currentUid`.
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
    // Tear down any stale socket — its auth token is frozen at creation, so
    // reconnecting it would fail forever after the token expires or on user switch.
    _teardownSocket();

    final token = await _authService.getIdToken();
    if (_disposed ||
        gen != _connectGeneration ||
        token == null ||
        token.isEmpty ||
        _authService.getCurrentUserId() != targetUid) {
      return false;
    }

    final socket = _buildSocket(token, targetUid, gen);
    socket.connect();

    final completer = Completer<void>();
    socket.once('connect', (_) {
      if (!completer.isCompleted) completer.complete();
    });

    await Future.any([
      completer.future,
      Future.delayed(_connectTimeout),
    ]);

    // Verify neither disposal nor an account switch superseded this attempt
    // while awaiting the handshake.
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
      // Re-subscribe to the board room after (re)connecting — the server
      // never re-subscribes rooms on its own, and without this the client
      // sits "connected" but receives nothing.
      final boardId = _watchedBoardId;
      if (boardId != null) {
        socket.emit('watch_board', boardId);
      }
      return true;
    }

    _teardownSocket(socket);
    _scheduleReconnect();
    return false;
  }

  @override
  Future<void> connect(String boardId) async {
    final callerUid = _authService.getCurrentUserId();
    if (callerUid == null || callerUid.isEmpty) {
      _watchedBoardId = null;
      _teardownSocket();
      return;
    }
    _watchedBoardId = boardId;
    final connected = await _ensureConnected(expectedUid: callerUid);
    if (connected && _isActiveIdentity(callerUid)) {
      _socket!.emit('watch_board', boardId);
    }
  }

  @override
  Future<List<BoardChatMessage>> getChatHistory(
    String boardId, {
    int limit = 50,
  }) async {
    final callerUid = _authService.getCurrentUserId();
    if (callerUid == null || callerUid.isEmpty) return [];

    final connected = await _ensureConnected(expectedUid: callerUid);
    if (!connected || !_isActiveIdentity(callerUid)) return [];

    final boundSocket = _socket!;
    final completer = Completer<List<BoardChatMessage>>();
    boundSocket.emitWithAck(
      'get_board_chat_history',
      {'boardId': boardId, 'limit': limit},
      ack: (dynamic res) {
        if (_authService.getCurrentUserId() != callerUid) {
          if (!completer.isCompleted) completer.complete([]);
          return;
        }
        try {
          if (res is Map && res['status'] == 'success') {
            final rawList = (res['messages'] as List?) ?? [];
            final messages = rawList
                .map(
                  (m) => BoardChatMessage.fromMap(
                    Map<String, dynamic>.from(m as Map),
                  ),
                )
                .toList();
            if (!completer.isCompleted) completer.complete(messages);
            return;
          }
          if (!completer.isCompleted) completer.complete([]);
        } catch (e) {
          developer.log(
            'Error reading chat history: $e',
            name: 'BoardChatService',
          );
          if (!completer.isCompleted) completer.complete([]);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => [],
    );
  }

  @override
  Future<BoardChatMessage> sendMessage({
    required String boardId,
    required String text,
  }) async {
    final callerUid = _authService.getCurrentUserId();
    if (callerUid == null || callerUid.isEmpty) {
      throw StateError('Cannot send board chat message while signed out.');
    }

    final connected = await _ensureConnected(expectedUid: callerUid);
    if (!connected || !_isActiveIdentity(callerUid)) {
      throw StateError(
        'Chat server is unreachable or active account changed. Please retry.',
      );
    }

    final user = _authService.getCurrentUser();
    if (user != null && user.uid != callerUid) {
      throw StateError('Authenticated user changed before message send.');
    }
    final senderName = user?.displayName ?? 'Anonymous';
    final senderPhotoUrl = user?.photoURL;

    final completer = Completer<BoardChatMessage>();

    final payload = {
      'boardId': boardId,
      'text': text,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'message': {
        'text': text,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
      },
    };

    _socket!.emitWithAck(
      'board_chat_message',
      payload,
      ack: (dynamic res) {
        try {
          if (res is Map && res['status'] == 'success') {
            final msgData = res['message'] as Map?;
            if (msgData != null) {
              final msg = BoardChatMessage.fromMap(
                Map<String, dynamic>.from(msgData),
              );
              if (!completer.isCompleted) completer.complete(msg);
              return;
            }
          }
          throw Exception(res is Map ? res['message'] : 'Failed to send');
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'Chat send timed out. The server did not acknowledge the message.',
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _connectGeneration++;
    _watchedBoardId = null;
    _connectingFuture = null;
    _connectingUserId = null;
    _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _chatMessageController.close();
  }
}
