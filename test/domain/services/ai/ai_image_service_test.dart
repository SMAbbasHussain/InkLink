import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inklink/core/services/cloud_functions_service.dart';
import 'package:inklink/domain/models/ai/ai_image_result.dart';
import 'package:inklink/domain/services/ai/ai_image_service.dart';

class _FakeResult implements HttpsCallableResult<dynamic> {
  @override
  final dynamic data;
  _FakeResult(this.data);
}

class _FakeCallable implements HttpsCallable {
  final Future<dynamic> Function(dynamic params) handler;
  _FakeCallable(this.handler);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = await handler(parameters);
    return _FakeResult(data) as HttpsCallableResult<T>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCloudFunctionsService implements CloudFunctionsService {
  final List<({String name, dynamic params})> calls = [];
  Future<dynamic> Function(String name, dynamic params) handler;

  _FakeCloudFunctionsService(this.handler);

  @override
  HttpsCallable httpsCallable(String functionName) {
    return _FakeCallable((params) {
      calls.add((name: functionName, params: params));
      return handler(functionName, params);
    });
  }

  @override
  FirebaseFunctions getInstance() => throw UnimplementedError();
}

Map<String, dynamic> _successResponse({String id = 'gen1'}) => {
  'success': true,
  'imageUrl': 'https://cdn.example.test/ai-images/board1/$id.png',
  'thumbnailBase64': 'dGh1bWI=',
  'width': 1280,
  'height': 720,
  'provider': 'mock',
  'model': 'mock',
  'generationId': id,
};

FirebaseException _functionsError(String code, [String? message]) =>
    FirebaseException(plugin: 'firebase_functions', code: code, message: message);

void main() {
  group('AiImageResult.fromMap', () {
    test('parses a full response', () {
      final result = AiImageResult.fromMap(_successResponse());
      expect(result.imageUrl, 'https://cdn.example.test/ai-images/board1/gen1.png');
      expect(result.thumbnailBase64, 'dGh1bWI=');
      expect(result.width, 1280);
      expect(result.height, 720);
      expect(result.provider, 'mock');
      expect(result.model, 'mock');
      expect(result.generationId, 'gen1');
    });

    test('tolerates numeric types and missing optional fields', () {
      final result = AiImageResult.fromMap({
        'imageUrl': 'https://cdn.example.test/a.png',
        'width': 512.0,
        'height': '512',
      });
      expect(result.width, 512);
      expect(result.height, 512);
      expect(result.thumbnailBase64, '');
      expect(result.generationId, '');
    });

    test('rejects a response without a URL or size', () {
      expect(() => AiImageResult.fromMap({'width': 1, 'height': 1}), throwsFormatException);
      expect(
        () => AiImageResult.fromMap({'imageUrl': 'https://x/y.png', 'width': 0, 'height': 10}),
        throwsFormatException,
      );
    });
  });

  group('AiImageServiceImpl callables', () {
    test('generateImage calls generateAiImage with a trimmed prompt', () async {
      final functions = _FakeCloudFunctionsService((name, params) async => _successResponse());
      final service = AiImageServiceImpl(cloudFunctionsService: functions);

      final result = await service.generateImage(
        boardId: 'board1',
        prompt: '  a red fox  ',
        aspectRatio: '16:9',
      );

      expect(result.generationId, 'gen1');
      expect(functions.calls.single.name, 'generateAiImage');
      expect(functions.calls.single.params, {
        'boardId': 'board1',
        'prompt': 'a red fox',
        'aspectRatio': '16:9',
      });
    });

    test('editImage calls editAiImage and only sends strength when given', () async {
      final functions = _FakeCloudFunctionsService((name, params) async => _successResponse());
      final service = AiImageServiceImpl(cloudFunctionsService: functions);

      await service.editImage(
        boardId: 'board1',
        sourceImageUrl: 'https://cdn.example.test/ai-images/board1/gen1.png',
        prompt: 'at night',
      );
      await service.editImage(
        boardId: 'board1',
        sourceImageUrl: 'https://cdn.example.test/ai-images/board1/gen1.png',
        prompt: 'at night',
        strength: 0.4,
      );

      expect(functions.calls.first.name, 'editAiImage');
      expect((functions.calls.first.params as Map).containsKey('strength'), isFalse);
      expect((functions.calls.last.params as Map)['strength'], 0.4);
    });

    test('inpaintImage sends the mask as base64', () async {
      final functions = _FakeCloudFunctionsService((name, params) async => _successResponse());
      final service = AiImageServiceImpl(cloudFunctionsService: functions);
      final mask = Uint8List.fromList([137, 80, 78, 71]);

      await service.inpaintImage(
        boardId: 'board1',
        sourceImageUrl: 'https://cdn.example.test/ai-images/board1/gen1.png',
        maskPng: mask,
        prompt: 'a tree',
      );

      expect(functions.calls.single.name, 'inpaintAiImage');
      expect((functions.calls.single.params as Map)['maskBase64'], base64Encode(mask));
    });

    test('success != true becomes a readable error', () async {
      final functions = _FakeCloudFunctionsService((name, params) async => {'success': false});
      final service = AiImageServiceImpl(cloudFunctionsService: functions);

      expect(
        () => service.generateImage(boardId: 'b', prompt: 'p', aspectRatio: '1:1'),
        throwsA(isA<AiImageException>()),
      );
    });

    test('a malformed success response becomes a readable error', () async {
      final functions = _FakeCloudFunctionsService((name, params) async => {'success': true});
      final service = AiImageServiceImpl(cloudFunctionsService: functions);

      expect(
        () => service.generateImage(boardId: 'b', prompt: 'p', aspectRatio: '1:1'),
        throwsA(
          isA<AiImageException>().having(
            (e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });

    Future<AiImageException> errorFor(Object thrown) async {
      final functions = _FakeCloudFunctionsService((name, params) async => throw thrown);
      final service = AiImageServiceImpl(cloudFunctionsService: functions);
      try {
        await service.generateImage(boardId: 'b', prompt: 'p', aspectRatio: '1:1');
      } on AiImageException catch (e) {
        return e;
      }
      fail('expected an AiImageException');
    }

    test('daily limit keeps the server message and is flagged', () async {
      final error = await errorFor(
        _functionsError(
          'resource-exhausted',
          "You have reached today's limit of 20 AI images. Try again tomorrow.",
        ),
      );
      expect(error.isLimitReached, isTrue);
      expect(error.message, contains('limit of 20 AI images'));
      expect(error.toString(), error.message);
    });

    test('maps each function error code to a clear message', () async {
      final expectations = <String, String>{
        'failed-precondition': 'not set up on the server',
        'deadline-exceeded': 'took too long',
        'unavailable': 'unavailable',
        'unauthenticated': 'sign in again',
        'internal': 'request failed',
      };
      for (final entry in expectations.entries) {
        final error = await errorFor(_functionsError(entry.key, 'raw server text'));
        expect(error.code, entry.key);
        expect(error.message, contains(entry.value), reason: entry.key);
        expect(error.isLimitReached, isFalse);
      }
    });

    test('permission-denied and invalid-argument show the server explanation', () async {
      final denied = await errorFor(
        _functionsError('permission-denied', 'Viewers cannot use AI images.'),
      );
      expect(denied.message, 'Viewers cannot use AI images.');

      final invalid = await errorFor(_functionsError('invalid-argument', 'Please enter a prompt.'));
      expect(invalid.message, 'Please enter a prompt.');

      final bare = await errorFor(_functionsError('permission-denied'));
      expect(bare.message, contains('edit access'));
    });

    test('unknown failures (for example offline) become a connection message', () async {
      final error = await errorFor(Exception('SocketException: failed host lookup'));
      expect(error.code, isNull);
      expect(error.message, contains('Check your connection'));
    });
  });

  group('AiImageServiceImpl.fetchImageBytes', () {
    AiImageServiceImpl serviceWith(MockClient client) => AiImageServiceImpl(
      cloudFunctionsService: _FakeCloudFunctionsService((name, params) async => null),
      httpClient: client,
    );

    test('downloads once and then serves from the cache', () async {
      var requests = 0;
      final service = serviceWith(
        MockClient((request) async {
          requests += 1;
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );

      final first = await service.fetchImageBytes('https://cdn.example.test/a.png');
      final second = await service.fetchImageBytes('https://cdn.example.test/a.png');

      expect(first, [1, 2, 3]);
      expect(second, [1, 2, 3]);
      expect(requests, 1);
    });

    test('concurrent requests for the same URL share one download', () async {
      var requests = 0;
      final service = serviceWith(
        MockClient((request) async {
          requests += 1;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response.bytes([9], 200);
        }),
      );

      final results = await Future.wait([
        service.fetchImageBytes('https://cdn.example.test/a.png'),
        service.fetchImageBytes('https://cdn.example.test/a.png'),
      ]);

      expect(results.every((bytes) => bytes.single == 9), isTrue);
      expect(requests, 1);
    });

    test('evicts the least recently used image when the cache is full', () async {
      final requested = <String>[];
      final service = serviceWith(
        MockClient((request) async {
          requested.add(request.url.toString());
          return http.Response.bytes([1], 200);
        }),
      );

      for (var i = 0; i < 24; i++) {
        await service.fetchImageBytes('https://cdn.example.test/$i.png');
      }
      // Touch image 0 so image 1 becomes the oldest, then overflow the cache.
      await service.fetchImageBytes('https://cdn.example.test/0.png');
      await service.fetchImageBytes('https://cdn.example.test/new.png');
      requested.clear();

      await service.fetchImageBytes('https://cdn.example.test/0.png');
      expect(requested, isEmpty, reason: 'image 0 is still cached');
      await service.fetchImageBytes('https://cdn.example.test/1.png');
      expect(requested, ['https://cdn.example.test/1.png'], reason: 'image 1 was evicted');
    });

    test('a failed download throws and is not cached', () async {
      var requests = 0;
      final service = serviceWith(
        MockClient((request) async {
          requests += 1;
          return requests == 1 ? http.Response('nope', 404) : http.Response.bytes([7], 200);
        }),
      );

      await expectLater(
        service.fetchImageBytes('https://cdn.example.test/a.png'),
        throwsA(isA<AiImageException>()),
      );
      expect(await service.fetchImageBytes('https://cdn.example.test/a.png'), [7]);
    });

    test('network errors and non-http addresses throw a readable error', () async {
      final service = serviceWith(MockClient((request) async => throw Exception('offline')));

      await expectLater(
        service.fetchImageBytes('https://cdn.example.test/a.png'),
        throwsA(
          isA<AiImageException>().having((e) => e.message, 'message', contains('connection')),
        ),
      );
      await expectLater(
        service.fetchImageBytes('file:///etc/passwd'),
        throwsA(isA<AiImageException>()),
      );
      await expectLater(service.fetchImageBytes('not a url'), throwsA(isA<AiImageException>()));
    });
  });
}
