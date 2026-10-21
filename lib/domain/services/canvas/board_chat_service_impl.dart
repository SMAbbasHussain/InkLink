import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/services/auth_service.dart';
import '../../../features/canvas/models/board_chat_message.dart';
import 'board_chat_service.dart';

class BoardChatServiceImpl implements BoardChatService {
  final AuthService _authService;
  io.Socket? _socket;
  final StreamController<BoardChatMessage> _chatMessageController =
      StreamController<BoardChatMessage>.broadcast();

  BoardChatServiceImpl({required AuthService authService})
      : _authService = authService;

  @override
  Stream<BoardChatMessage> watchChatMessages(String boardId) {
    return _chatMessageController.stream.where((m) => m.boardId == boardId);
  }

  Future<bool> _ensureConnected() async {
    if (_socket != null && _socket!.connected) return true;

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

    _socket!.on('board_chat_message', (data) {
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

    _socket!.connect();

    final completer = Completer<void>();
    _socket!.onConnect((_) {
      if (!completer.isCompleted) completer.complete();
    });

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 3)),
    ]);

    return _socket != null && _socket!.connected;
  }

  @override
  Future<void> connect(String boardId) async {
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
    await _ensureConnected();
    if (_socket == null || !_socket!.connected) return [];

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
    await _ensureConnected();
    final user = _authService.getCurrentUser();
    final senderName = user?.displayName ?? 'Anonymous';
    final senderPhotoUrl = user?.photoURL;

    final completer = Completer<BoardChatMessage>();

    _socket!.emitWithAck(
      'board_chat_message',
      {
        'boardId': boardId,
        'text': text,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
      },
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
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Chat send timed out'),
    );
  }

  @override
  Future<void> dispose() async {
    _socket?.disconnect();
    _socket = null;
    await _chatMessageController.close();
  }
}
