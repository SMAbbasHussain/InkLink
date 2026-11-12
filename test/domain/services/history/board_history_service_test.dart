import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/domain/services/history/board_history_service.dart';
import 'package:inklink/domain/services/history/board_history_service_impl.dart';

/// Socket double: records every request and answers from a scripted table.
class _FakeSocket implements BoardHistorySocket {
  final Map<String, void Function(dynamic)> _handlers = {};
  final List<Map<String, dynamic>> requests = [];
  final Map<String, dynamic> Function(String event, Map<String, dynamic> data)
  responder;
  bool _connected = false;

  _FakeSocket(this.responder);

  @override
  bool get connected => _connected;

  @override
  void connect() {
    _connected = true;
    final onConnect = _handlers['connect'];
    if (onConnect != null) onConnect(null);
  }

  @override
  void disconnect() => _connected = false;

  @override
  void dispose() => _connected = false;

  @override
  void on(String event, void Function(dynamic data) handler) {
    _handlers[event] = handler;
  }

  @override
  void once(String event, void Function(dynamic data) handler) {
    _handlers[event] = handler;
  }

  @override
  void emit(String event, [dynamic data]) {}

  @override
  void emitWithAck(
    String event,
    dynamic data, {
    required void Function(dynamic response) ack,
  }) {
    final payload = <String, dynamic>{};
    if (data is Map) payload.addAll(Map<String, dynamic>.from(data));
    requests.add({'event': event, ...payload});
    final reply = responder(event, payload);
    scheduleMicrotask(() => ack(reply));
  }
}

class _FakeAuthService implements AuthService {
  String? uid = 'owner-1';
  String? token = 'token';

  @override
  String? getCurrentUserId() => uid;

  @override
  User? getCurrentUser() => null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => token;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeAuthService auth;
  late _FakeSocket socket;
  late BoardHistoryServiceImpl service;
  late List<String> askedBlocks;

  BoardHistoryServiceImpl build() {
    auth = _FakeAuthService();
    askedBlocks = [];
    socket = _FakeSocket((event, data) {
      switch (event) {
        case 'history_get_block':
          final blockId = data['blockId'] as String;
          askedBlocks.add(blockId);
          return {
            'status': 'success',
            'block': {'blockId': blockId},
            'ops': [
              {
                'version': 1,
                'elementId': 'e',
                'action': 'upsert',
                'payloadBase64': '',
              },
            ],
          };
        case 'history_get_user_ops':
          return {
            'status': 'success',
            'ops': [
              {'version': 10, 'action': 'upsert'},
              {'version': 9, 'action': 'delete'},
            ],
            'hasMore': true,
            'nextBeforeVersion': 9,
          };
        case 'history_preview_version':
          return {
            'status': 'success',
            'version': 42,
            'stateUpdate': base64Encode(Uint8List.fromList([1, 2, 3])),
            'elementCount': 7,
          };
        case 'history_plan_revert':
          return {
            'status': 'success',
            'plan': {
              'planId': 'plan_1',
              'mode': data['mode'],
              'baseVersion': 100,
              'requestId': data['requestId'],
              'items': [
                {'elementId': 'e-1', 'kind': 'delete', 'conflict': false},
              ],
            },
          };
        case 'history_apply_revert':
          return {
            'status': 'success',
            'appliedVersion': 101,
            'reverted': ['e-1'],
            'skipped': ['e-2'],
            'requestId': data['requestId'],
          };
        case 'history_undo_own':
          return {
            'status': 'success',
            'appliedVersion': 55,
            'reverted': ['e-9'],
            'skipped': <String>[],
          };
        default:
          return {'status': 'error', 'message': 'unknown_event_for_test'};
      }
    });
    return BoardHistoryServiceImpl(
      authService: auth,
      socketFactory: (_) => socket,
      connectTimeout: const Duration(milliseconds: 200),
    );
  }

  setUp(() {
    service = build();
  });

  tearDown(() => service.dispose());

  group('block cache (D15)', () {
    test('scopes cache keys by board, not by block id alone', () async {
      // Block ids are version ranges and repeat across boards.
      await service.getBlock('board-a', 'block_000001_000500');
      await service.getBlock('board-a', 'block_000001_000500');
      expect(askedBlocks.length, 1, reason: 'same board/block must be cached');

      final forBoardB = await service.getBlock(
        'board-b',
        'block_000001_000500',
      );
      expect(askedBlocks.length, 2, reason: 'other board must not reuse cache');
      expect(forBoardB.single.version, 1);
    });

    test('evicts the least recently used block beyond 20 entries', () async {
      for (var i = 0; i < 20; i++) {
        await service.getBlock('b', 'block_${i.toString().padLeft(2, '0')}');
      }
      expect(askedBlocks.length, 20);

      // Touch the oldest so the *second* one becomes least recently used.
      await service.getBlock('b', 'block_00');
      expect(askedBlocks.length, 20);

      await service.getBlock('b', 'block_20');
      expect(askedBlocks.length, 21);

      await service.getBlock('b', 'block_00');
      expect(askedBlocks.length, 21, reason: 'recently touched entry kept');

      await service.getBlock('b', 'block_01');
      expect(askedBlocks.length, 22, reason: 'least recent entry evicted');
    });
  });

  group('reads', () {
    test('getUserOps passes paging and parses the page', () async {
      final page = await service.getUserOps(
        'b',
        'alice',
        beforeVersion: 10,
        limit: 2,
      );

      final request = socket.requests.last;
      expect(request['event'], 'history_get_user_ops');
      expect(request['targetUid'], 'alice');
      expect(request['beforeVersion'], 10);
      expect(request['limit'], 2);
      expect(page.ops.length, 2);
      expect(page.hasMore, isTrue);
      expect(page.nextBeforeVersion, 9);
    });

    test('previewVersion decodes the state update and version', () async {
      final preview = await service.previewVersion('b', 42);
      expect(preview.version, 42);
      expect(preview.elementCount, 7);
      expect(preview.stateUpdateBytes, [1, 2, 3]);
      expect(socket.requests.last['version'], 42);
    });
  });

  group('revert', () {
    test('planRevert forwards the mode/target and parses items', () async {
      final plan = await service.planRevert(
        'b',
        mode: 'restore',
        targetVersion: 42,
      );
      expect(plan.planId, 'plan_1');
      expect(plan.mode, 'restore');
      expect(plan.items.single.elementId, 'e-1');
      expect(socket.requests.last['targetVersion'], 42);
    });

    test('planRevert attaches the undo request id', () async {
      final plan = await service.planRevert(
        'b',
        mode: 'user',
        requestId: 'req-7',
      );
      expect(plan.requestId, 'req-7');
      expect(socket.requests.last['requestId'], 'req-7');
    });

    test('applyRevert reports applied and skipped elements', () async {
      final result = await service.applyRevert(
        'b',
        planId: 'plan_1',
        decisions: const {'e-1': 'revert'},
        requestId: 'req-7',
      );
      expect(result.appliedVersion, 101);
      expect(result.reverted, ['e-1']);
      expect(result.skipped, ['e-2']);
      expect(socket.requests.last['decisions'], {'e-1': 'revert'});
    });

    test('undoOwn only sends updateIds when it has some', () async {
      await service.undoOwn('b');
      expect(socket.requests.last.containsKey('updateIds'), isFalse);

      await service.undoOwn('b', updateIds: ['u-1']);
      expect(socket.requests.last['updateIds'], ['u-1']);
    });
  });

  group('error handling', () {
    test('server error tokens surface as HistoryServiceException', () async {
      final failing = build();
      failing.dispose();
      socket = _FakeSocket((_, _) => {
        'status': 'error',
        'message': 'forbidden',
      });
      final scoped = BoardHistoryServiceImpl(
        authService: auth,
        socketFactory: (_) => socket,
        connectTimeout: const Duration(milliseconds: 200),
      );

      await expectLater(
        scoped.previewVersion('b', 1),
        throwsA(
          isA<HistoryServiceException>().having(
            (e) => e.code,
            'code',
            'forbidden',
          ),
        ),
      );
      scoped.dispose();
    });

    test('signed-out calls fail fast without a socket round trip', () async {
      auth.uid = null;
      await expectLater(
        service.getBlock('b', 'block_1'),
        throwsA(
          isA<HistoryServiceException>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(socket.requests, isEmpty);
    });
  });
}
