import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/auth_service.dart';
import '../../../core/utils/network_config.dart';
import '../../../features/canvas/models/board_chat_message.dart';
import 'board_chat_service.dart';

class BoardChatServiceImpl implements BoardChatService {
  final AuthService _authService;
  io.Socket? _socket;
  final StreamController<BoardChatMessage> _chatMessageController =
      StreamController<BoardChatMessage>.broadcast();

  /// Board whose room should be re-subscribed after a reconnect.
  String? _watchedBoardId;
  int _reconnectAttempts = 0;
  bool _reconnectScheduled = false;
  bool _disposed = false;

  BoardChatServiceImpl({required AuthService authService})
      : _authService = authService;

  @override
  Stream<BoardChatMessage> watchChatMessages(String boardId) {
    return _chatMessageController.stream.where((m) => m.boardId == boardId);
  }

  io.Socket _buildSocket(String token) {
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

    socket.on('board_chat_message', (data) {
      try {
        if (data is Map) {
          final message =
              BoardChatMessage.fromMap(Map<String, dynamic>.from(data));
          _chatMessageController.add(message);
        }
      } catch (e) {
        developer.log('Error parsing chat message: $e', name: 'BoardChatService');
      }
    });

    socket.on('disconnect', (data) {
      developer.log('Socket disconnected; scheduling reconnect with fresh token',
          name: 'BoardChatService');
      _scheduleReconnect();
    });

    socket.on('connect_error', (data) {
      developer.log('Socket connect_error: $data; scheduling reconnect with fresh token',
          name: 'BoardChatService');
      _scheduleReconnect();
    });

    return socket;
  }

  /// Capped exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ...
  Duration get _reconnectDelay =>
      Duration(seconds: math.min(30, 1 << _reconnectAttempts.clamp(0, 5)));

  void _scheduleReconnect() {
    if (_disposed || _reconnectScheduled) return;
    _reconnectScheduled = true;
    final delay = _reconnectDelay;
    _reconnectAttempts++;
    Future.delayed(delay, () {
      _reconnectScheduled = false;
      if (_disposed) return;
      if (_socket != null && _socket!.connected) return;
      unawaited(_ensureConnected());
    });
  }

  void _teardownSocket() {
    final stale = _socket;
    _socket = null;
    if (stale == null) return;
    try {
      // dispose() disconnects and clears all listeners so stale handlers
      // can't fire on the abandoned socket.
      stale.dispose();
    } catch (e) {
      developer.log('Stale socket dispose failed: $e', name: 'BoardChatService');
      try {
        stale.disconnect();
      } catch (_) {}
    }
  }

  Future<bool> _ensureConnected() async {
    if (_socket != null && _socket!.connected) return true;

    // Tear down any stale socket — its auth token is frozen at creation, so
    // reconnecting it would fail forever after the token expires.
    _teardownSocket();

    final token = await _authService.getIdToken();
    if (token == null) return false;

    final socket = _buildSocket(token);
    _socket = socket;
    socket.connect();

    final completer = Completer<void>();
    socket.once('connect', (_) {
      if (!completer.isCompleted) completer.complete();
    });

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 5)),
    ]);

    if (socket.connected) {
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

    _scheduleReconnect();
    return false;
  }

  @override
  Future<void> connect(String boardId) async {
    _watchedBoardId = boardId;
    final connected = await _ensureConnected();
    if (connected && _socket != null) {
      _socket!.emit('watch_board', boardId);
    }
  }

  @override
  Future<List<BoardChatMessage>> getChatHistory(
    String boardId, {
    int limit = 50,
  }) async {
    final connected = await _ensureConnected();
    if (!connected || _socket == null || !_socket!.connected) return [];

    final completer = Completer<List<BoardChatMessage>>();
    _socket!.emitWithAck(
      'get_board_chat_history',
      {'boardId': boardId, 'limit': limit},
      ack: (dynamic res) {
        try {
          if (res is Map && res['status'] == 'success') {
            final rawList = (res['messages'] as List?) ?? [];
            final messages = rawList
                .map((m) => BoardChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
                .toList();
            completer.complete(messages);
            return;
          }
          completer.complete([]);
        } catch (e) {
          developer.log('Error reading chat history: $e', name: 'BoardChatService');
          completer.complete([]);
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
    final connected = await _ensureConnected();
    if (!connected || _socket == null || !_socket!.connected) {
      throw StateError(
        'Chat server is unreachable. Please verify your connection or check that the server is online.',
      );
    }

    final user = _authService.getCurrentUser();
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
              completer.complete(msg);
              return;
            }
          }
          throw Exception(res is Map ? res['message'] : 'Failed to send');
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Chat send timed out. The server did not acknowledge the message.'),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _teardownSocket();
    await _chatMessageController.close();
  }
}
