import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/services/canvas/board_chat_service_impl.dart';
import 'package:inklink/features/canvas/models/board_chat_message.dart';

class _FakeUser implements User {
  @override
  final String uid;

  @override
  final String? displayName;

  @override
  String? get photoURL => null;

  _FakeUser({
    required this.uid,
    this.displayName,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  String? currentUid;
  String? displayName;
  Future<String?> Function(String? uid)? tokenProvider;

  _FakeAuthService({
    this.currentUid,
    this.displayName = 'Tester',
  });

  @override
  String? getCurrentUserId() => currentUid;

  @override
  User? getCurrentUser() {
    final uid = currentUid;
    if (uid == null) return null;
    return _FakeUser(uid: uid, displayName: displayName);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (tokenProvider != null) {
      return tokenProvider!(currentUid);
    }
    final uid = currentUid;
    return uid == null ? null : 'token-for-$uid';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBoardChatSocket implements BoardChatSocket {
  final String token;
  bool _connected = false;
  bool connectCalled = false;
  bool disconnectCalled = false;
  bool disposeCalled = false;

  final List<({String event, dynamic data})> emitted = [];
  final List<
      ({
        String event,
        dynamic data,
        void Function(dynamic response) ack,
      })> ackEmits = [];

  final Map<String, List<void Function(dynamic)>> _onHandlers = {};
  final Map<String, List<void Function(dynamic)>> _onceHandlers = {};

  void Function(
    String event,
    dynamic data,
    void Function(dynamic response) ack,
  )? onEmitWithAck;

  _FakeBoardChatSocket(this.token);

  @override
  bool get connected => _connected && !disposeCalled && !disconnectCalled;

  @override
  void connect() {
    connectCalled = true;
  }

  @override
  void disconnect() {
    disconnectCalled = true;
    _connected = false;
  }

  @override
  void dispose() {
    disposeCalled = true;
    _connected = false;
    _onHandlers.clear();
    _onceHandlers.clear();
  }

  @override
  void on(String event, void Function(dynamic data) handler) {
    _onHandlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void once(String event, void Function(dynamic data) handler) {
    _onceHandlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void emit(String event, [dynamic data]) {
    emitted.add((event: event, data: data));
  }

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic response) ack,
  }) {
    ackEmits.add((event: event, data: data, ack: ack));
    onEmitWithAck?.call(event, data, ack);
  }

  void completeHandshake() {
    if (disposeCalled) return;
    _connected = true;
    final onceList = List<void Function(dynamic)>.from(
      _onceHandlers.remove('connect') ?? const [],
    );
    for (final h in onceList) {
      h(null);
    }
    final onList = List<void Function(dynamic)>.from(
      _onHandlers['connect'] ?? const [],
    );
    for (final h in onList) {
      h(null);
    }
  }

  void triggerEvent(String event, dynamic data) {
    final handlers = List<void Function(dynamic)>.from(
      _onHandlers[event] ?? const [],
    );
    for (final h in handlers) {
      h(data);
    }
  }
}

void main() {
  group('BoardChatServiceImpl identity isolation', () {
    late _FakeAuthService authService;
    late List<_FakeBoardChatSocket> createdSockets;
    late BoardChatServiceImpl service;

    setUp(() {
      authService = _FakeAuthService(currentUid: 'user-A', displayName: 'Alice');
      createdSockets = [];
      service = BoardChatServiceImpl(
        authService: authService,
        connectTimeout: const Duration(milliseconds: 250),
        socketFactory: (token) {
          final socket = _FakeBoardChatSocket(token);
          createdSockets.add(socket);
          return socket;
        },
      );
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'account switch while connect is in flight does not reuse previous user socket',
      () async {
        // User A initiates connect('board-1'); socket A handshake stays pending.
        final userAConnectFuture = service.connect('board-1');
        await Future<void>.delayed(Duration.zero);

        expect(createdSockets, hasLength(1));
        final socketA = createdSockets[0];
        expect(socketA.token, 'token-for-user-A');
        expect(socketA.connectCalled, isTrue);

        // Before socket A completes handshake, Firebase auth switches to User B.
        authService.currentUid = 'user-B';
        authService.displayName = 'Bob';

        // User B sends a message while socket A's handshake is still in flight.
        final sendFuture = service.sendMessage(
          boardId: 'board-1',
          text: 'Hello from User B',
        );
        await Future<void>.delayed(Duration.zero);

        // A second socket authenticated with User B's token must be created.
        expect(createdSockets, hasLength(2));
        final socketB = createdSockets[1];
        expect(socketB.token, 'token-for-user-B');

        socketB.onEmitWithAck = (event, data, ack) {
          if (event == 'board_chat_message') {
            ack({
              'status': 'success',
              'message': {
                'id': 'msg-b1',
                'boardId': 'board-1',
                'senderUid': 'user-B',
                'senderName': 'Bob',
                'text': 'Hello from User B',
                'timestamp': 1730000000000,
              },
            });
          }
        };

        // Complete socket B's handshake first, then let stale socket A finish.
        socketB.completeHandshake();
        await Future<void>.delayed(Duration.zero);
        socketA.completeHandshake();

        await userAConnectFuture;
        final sent = await sendFuture;

        expect(sent.id, 'msg-b1');
        expect(sent.senderUid, 'user-B');

        // Stale socket A must have been torn down and never used for operations.
        expect(socketA.disposeCalled, isTrue);
        expect(socketA.ackEmits, isEmpty);
        expect(
          socketA.emitted.where((e) => e.event == 'watch_board'),
          isEmpty,
        );

        // Socket B carried User B's send operation.
        expect(socketB.disposeCalled, isFalse);
        expect(socketB.ackEmits, hasLength(1));
        expect(socketB.ackEmits.single.event, 'board_chat_message');
      },
    );

    test(
      'stale caller awaiting in-flight token/connect is rejected if account switches',
      () async {
        final tokenCompleterA = Completer<String?>();
        authService.tokenProvider = (uid) {
          if (uid == 'user-A') return tokenCompleterA.future;
          return Future.value('token-for-$uid');
        };

        // User A requests history and send while token fetch is still pending.
        final historyFutureA = service.getChatHistory('board-1');
        final sendFutureA = service.sendMessage(
          boardId: 'board-1',
          text: 'Should not send under User B',
        );
        // Attach error expectation immediately before completing futures.
        final sendExpectation = expectLater(sendFutureA, throwsStateError);

        await Future<void>.delayed(Duration.zero);

        // Switch active account to User B before User A's token resolves.
        authService.currentUid = 'user-B';
        tokenCompleterA.complete('token-for-user-A');

        final historyA = await historyFutureA;
        expect(historyA, isEmpty);
        await sendExpectation;
        expect(createdSockets, isEmpty);
      },
    );

    test(
      'concurrent operations for the same UID share a single in-flight connection',
      () async {
        final connect1 = service.connect('board-1');
        final historyFuture = service.getChatHistory('board-1');
        await Future<void>.delayed(Duration.zero);

        expect(createdSockets, hasLength(1));
        final socket = createdSockets.single;
        socket.onEmitWithAck = (event, data, ack) {
          if (event == 'get_board_chat_history') {
            ack({
              'status': 'success',
              'messages': [
                {
                  'id': 'm1',
                  'boardId': 'board-1',
                  'senderUid': 'user-A',
                  'senderName': 'Alice',
                  'text': 'Cached msg',
                  'timestamp': 1730000000100,
                },
              ],
            });
          }
        };

        socket.completeHandshake();
        await connect1;
        final history = await historyFuture;

        expect(createdSockets, hasLength(1));
        expect(history, hasLength(1));
        expect(history.single.text, 'Cached msg');
      },
    );

    test(
      'incoming board_chat_message events from previous account socket are ignored',
      () async {
        final received = <BoardChatMessage>[];
        final sub = service.watchChatMessages('board-1').listen(received.add);

        final connectA = service.connect('board-1');
        await Future<void>.delayed(Duration.zero);
        final socketA = createdSockets.single;
        socketA.completeHandshake();
        await connectA;

        // Valid message while User A is active is delivered.
        socketA.triggerEvent('board_chat_message', {
          'id': 'msg-a',
          'boardId': 'board-1',
          'senderUid': 'peer-1',
          'senderName': 'Peer',
          'text': 'For Alice',
          'timestamp': 1730000000001,
        });
        await Future<void>.delayed(Duration.zero);
        expect(received.map((m) => m.id), ['msg-a']);

        // Switch auth to User B: messages arriving on socketA before reconnect
        // must be dropped immediately.
        authService.currentUid = 'user-B';
        socketA.triggerEvent('board_chat_message', {
          'id': 'msg-leaked',
          'boardId': 'board-1',
          'senderUid': 'peer-1',
          'senderName': 'Peer',
          'text': 'Must not leak to Bob',
          'timestamp': 1730000000002,
        });
        await Future<void>.delayed(Duration.zero);
        expect(received.map((m) => m.id), ['msg-a']);

        await sub.cancel();
      },
    );

    test(
      'disconnect invalidates in-flight handshake and disposes late socket',
      () async {
        final connectFuture = service.connect('board-1');
        await Future<void>.delayed(Duration.zero);

        final socket = createdSockets.single;
        await service.disconnect();

        socket.completeHandshake();
        await connectFuture;

        expect(socket.disposeCalled, isTrue);
        expect(
          socket.emitted.where((e) => e.event == 'watch_board'),
          isEmpty,
        );
      },
    );
  });
}

