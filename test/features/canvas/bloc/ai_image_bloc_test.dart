import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/ai/ai_image_result.dart';
import 'package:inklink/domain/services/ai/ai_image_service.dart';
import 'package:inklink/features/canvas/bloc/ai_image_bloc.dart';

AiImageResult _result(String id, {int width = 1024, int height = 1024}) =>
    AiImageResult(
      imageUrl: 'https://cdn.example.test/ai-images/board1/$id.png',
      thumbnailBase64: 'dGh1bWI=',
      width: width,
      height: height,
      provider: 'mock',
      model: 'mock',
      generationId: id,
    );

class _FakeAiImageService implements AiImageService {
  final List<String> calls = [];
  Future<AiImageResult> Function(String kind, String prompt)? onRequest;
  Future<Uint8List> Function(String url)? onFetch;
  int fetchCount = 0;
  String? lastAspectRatio;
  Uint8List? lastMask;
  double? lastStrength;

  Future<AiImageResult> _run(String kind, String prompt) {
    calls.add('$kind:$prompt');
    final handler = onRequest;
    if (handler == null) return Future.value(_result('gen${calls.length}'));
    return handler(kind, prompt);
  }

  @override
  Future<AiImageResult> generateImage({
    required String boardId,
    required String prompt,
    required String aspectRatio,
  }) {
    lastAspectRatio = aspectRatio;
    return _run('generate', prompt);
  }

  @override
  Future<AiImageResult> editImage({
    required String boardId,
    required String sourceImageUrl,
    required String prompt,
    double? strength,
  }) {
    lastStrength = strength;
    return _run('edit', prompt);
  }

  @override
  Future<AiImageResult> inpaintImage({
    required String boardId,
    required String sourceImageUrl,
    required Uint8List maskPng,
    required String prompt,
  }) {
    lastMask = maskPng;
    return _run('inpaint', prompt);
  }

  @override
  Future<Uint8List> fetchImageBytes(String url) {
    fetchCount += 1;
    final handler = onFetch;
    if (handler == null) return Future.value(Uint8List.fromList([1, 2, 3]));
    return handler(url);
  }
}

const _generate = AiImageGenerateRequested(
  boardId: 'board1',
  prompt: '  a red fox  ',
  aspectRatio: '16:9',
  center: Offset(100, 200),
  width: 280,
  height: 157.5,
);

const _sourceUrl = 'https://cdn.example.test/ai-images/board1/gen0.png';

void main() {
  late _FakeAiImageService service;

  setUp(() => service = _FakeAiImageService());

  test('starts idle with nothing in progress', () {
    final bloc = AiImageBloc(aiImageService: service);
    expect(bloc.state.status, AiImageStatus.idle);
    expect(bloc.state.placeholders, isEmpty);
    expect(bloc.state.isBusy, isFalse);
    expect(bloc.state.failureMessage, isNull);
    bloc.close();
  });

  group('generate', () {
    blocTest<AiImageBloc, AiImageState>(
      'success: shows a placeholder, then removes it and publishes the image',
      build: () => AiImageBloc(aiImageService: service),
      act: (bloc) => bloc.add(_generate),
      verify: (bloc) {
        expect(service.calls, ['generate:a red fox']);
        expect(service.lastAspectRatio, '16:9');
      },
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.generating)
            .having((s) => s.placeholders.length, 'placeholders', 1)
            .having((s) => s.placeholders.single.prompt, 'prompt', 'a red fox')
            .having((s) => s.placeholders.single.center, 'center', const Offset(100, 200))
            .having((s) => s.placeholders.single.width, 'width', 280)
            .having(
              (s) => s.generatingPlaceholderId,
              'generatingPlaceholderId',
              isNotNull,
            )
            .having((s) => s.isGenerating, 'isGenerating', isTrue),
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.success)
            .having((s) => s.placeholders, 'placeholders', isEmpty)
            .having((s) => s.generatingPlaceholderId, 'generatingPlaceholderId', isNull)
            .having((s) => s.lastCompletion!.isInsert, 'isInsert', isTrue)
            .having((s) => s.lastCompletion!.prompt, 'prompt', 'a red fox')
            .having((s) => s.lastCompletion!.result.generationId, 'id', 'gen1')
            .having(
              (s) => s.lastCompletion!.placeholder!.center,
              'placeholder center',
              const Offset(100, 200),
            )
            .having((s) => s.lastFailure, 'lastFailure', isNull),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'failure: removes the placeholder and reports the message',
      build: () {
        service.onRequest = (kind, prompt) async => throw const AiImageException(
          'The AI service took too long to respond. Please try again.',
          code: 'deadline-exceeded',
        );
        return AiImageBloc(aiImageService: service);
      },
      act: (bloc) => bloc.add(_generate),
      expect: () => [
        isA<AiImageState>().having((s) => s.placeholders.length, 'placeholders', 1),
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.failure)
            .having((s) => s.placeholders, 'placeholders', isEmpty)
            .having((s) => s.isBusy, 'isBusy', isFalse)
            .having((s) => s.failureMessage, 'message', contains('took too long'))
            .having((s) => s.lastFailure!.isLimitReached, 'limit', isFalse)
            .having((s) => s.lastCompletion, 'lastCompletion', isNull),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'daily limit reached: flagged, friendly message, placeholder removed',
      build: () {
        service.onRequest = (kind, prompt) async => throw const AiImageException(
          "You have reached today's limit of 20 AI images. Try again tomorrow.",
          code: 'resource-exhausted',
        );
        return AiImageBloc(aiImageService: service);
      },
      act: (bloc) => bloc.add(_generate),
      skip: 1,
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.failure)
            .having((s) => s.placeholders, 'placeholders', isEmpty)
            .having((s) => s.lastFailure!.isLimitReached, 'limit', isTrue)
            .having((s) => s.failureMessage, 'message', contains('limit of 20')),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'unexpected errors still remove the placeholder with a generic message',
      build: () {
        service.onRequest = (kind, prompt) async => throw StateError('boom');
        return AiImageBloc(aiImageService: service);
      },
      act: (bloc) => bloc.add(_generate),
      skip: 1,
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.placeholders, 'placeholders', isEmpty)
            .having((s) => s.failureMessage, 'message', contains('request failed')),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'an empty prompt does nothing',
      build: () => AiImageBloc(aiImageService: service),
      act: (bloc) => bloc.add(
        const AiImageGenerateRequested(
          boardId: 'board1',
          prompt: '   ',
          aspectRatio: '1:1',
          center: Offset.zero,
          width: 280,
          height: 280,
        ),
      ),
      expect: () => const <AiImageState>[],
      verify: (_) => expect(service.calls, isEmpty),
    );

    test('two generations run at once; each removes only its own placeholder', () async {
      final first = Completer<AiImageResult>();
      final second = Completer<AiImageResult>();
      service.onRequest = (kind, prompt) => prompt == 'first' ? first.future : second.future;
      final bloc = AiImageBloc(aiImageService: service);

      AiImageGenerateRequested request(String prompt, Offset center) => AiImageGenerateRequested(
        boardId: 'board1',
        prompt: prompt,
        aspectRatio: '1:1',
        center: center,
        width: 280,
        height: 280,
      );
      bloc.add(request('first', const Offset(1, 1)));
      bloc.add(request('second', const Offset(2, 2)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.placeholders.map((p) => p.prompt), ['first', 'second']);
      expect(
        bloc.state.placeholders.map((p) => p.id).toSet().length,
        2,
        reason: 'placeholder ids are unique',
      );

      second.complete(_result('genB'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.placeholders.map((p) => p.prompt), ['first']);
      expect(bloc.state.lastCompletion!.placeholder!.center, const Offset(2, 2));
      final firstSequence = bloc.state.lastCompletion!.sequence;

      first.completeError(const AiImageException('nope'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.placeholders, isEmpty);
      expect(bloc.state.status, AiImageStatus.failure);
      expect(bloc.state.lastFailure!.sequence, greaterThan(firstSequence));
      // The earlier success is still there for the view to have applied.
      expect(bloc.state.lastCompletion!.result.generationId, 'genB');
      await bloc.close();
    });
  });

  group('edit, repaint and regenerate', () {
    blocTest<AiImageBloc, AiImageState>(
      'edit: marks the element busy, then publishes a replacement',
      build: () => AiImageBloc(aiImageService: service),
      act: (bloc) => bloc.add(
        const AiImageEditRequested(
          boardId: 'board1',
          elementId: 'img1',
          sourceImageUrl: _sourceUrl,
          prompt: ' at night ',
          strength: 0.4,
        ),
      ),
      verify: (_) {
        expect(service.calls, ['edit:at night']);
        expect(service.lastStrength, 0.4);
      },
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.generating)
            .having((s) => s.busyElementIds, 'busy', {'img1'})
            .having((s) => s.placeholders, 'placeholders', isEmpty)
            .having((s) => s.isGenerating, 'isGenerating', isFalse)
            .having((s) => s.isBusy, 'isBusy', isTrue),
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.success)
            .having((s) => s.busyElementIds, 'busy', isEmpty)
            .having((s) => s.lastCompletion!.isInsert, 'isInsert', isFalse)
            .having((s) => s.lastCompletion!.elementId, 'elementId', 'img1')
            .having((s) => s.lastCompletion!.prompt, 'prompt', 'at night'),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'repaint: sends the mask and publishes a replacement',
      build: () => AiImageBloc(aiImageService: service),
      act: (bloc) => bloc.add(
        AiImageInpaintRequested(
          boardId: 'board1',
          elementId: 'img1',
          sourceImageUrl: _sourceUrl,
          maskPng: Uint8List.fromList([137, 80, 78, 71]),
          prompt: 'a tree',
        ),
      ),
      skip: 1,
      verify: (_) {
        expect(service.calls, ['inpaint:a tree']);
        expect(service.lastMask, [137, 80, 78, 71]);
      },
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.lastCompletion!.elementId, 'elementId', 'img1')
            .having((s) => s.busyElementIds, 'busy', isEmpty),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'regenerate: runs the same prompt again and replaces the element',
      build: () => AiImageBloc(aiImageService: service),
      act: (bloc) => bloc.add(
        const AiImageRegenerateRequested(
          boardId: 'board1',
          elementId: 'img1',
          prompt: 'a red fox',
          aspectRatio: '9:16',
        ),
      ),
      skip: 1,
      verify: (_) {
        expect(service.calls, ['generate:a red fox']);
        expect(service.lastAspectRatio, '9:16');
      },
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.lastCompletion!.elementId, 'elementId', 'img1')
            .having((s) => s.lastCompletion!.placeholder, 'placeholder', isNull)
            .having((s) => s.placeholders, 'placeholders', isEmpty),
      ],
    );

    blocTest<AiImageBloc, AiImageState>(
      'failure: clears the busy mark and leaves no completion',
      build: () {
        service.onRequest = (kind, prompt) async =>
            throw const AiImageException('The AI image service is unavailable.');
        return AiImageBloc(aiImageService: service);
      },
      act: (bloc) => bloc.add(
        const AiImageEditRequested(
          boardId: 'board1',
          elementId: 'img1',
          sourceImageUrl: _sourceUrl,
          prompt: 'at night',
        ),
      ),
      skip: 1,
      expect: () => [
        isA<AiImageState>()
            .having((s) => s.status, 'status', AiImageStatus.failure)
            .having((s) => s.busyElementIds, 'busy', isEmpty)
            .having((s) => s.lastCompletion, 'lastCompletion', isNull)
            .having((s) => s.failureMessage, 'message', contains('unavailable')),
      ],
    );

    test('a second request for the same image is ignored while one is running', () async {
      final pending = Completer<AiImageResult>();
      service.onRequest = (kind, prompt) => pending.future;
      final bloc = AiImageBloc(aiImageService: service);
      const edit = AiImageEditRequested(
        boardId: 'board1',
        elementId: 'img1',
        sourceImageUrl: _sourceUrl,
        prompt: 'at night',
      );

      bloc.add(edit);
      await Future<void>.delayed(Duration.zero);
      bloc.add(edit);
      bloc.add(
        const AiImageRegenerateRequested(
          boardId: 'board1',
          elementId: 'img1',
          prompt: 'a fox',
          aspectRatio: '1:1',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.calls, hasLength(1));

      pending.complete(_result('gen9'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.busyElementIds, isEmpty);
      await bloc.close();
    });
  });

  group('image bytes', () {
    blocTest<AiImageBloc, AiImageState>(
      'downloads bytes once per URL',
      build: () => AiImageBloc(aiImageService: service),
      act: (bloc) async {
        bloc.add(const AiImageBytesRequested(_sourceUrl));
        bloc.add(const AiImageBytesRequested(_sourceUrl));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AiImageBytesRequested(_sourceUrl));
      },
      verify: (bloc) {
        expect(service.fetchCount, 1);
        expect(bloc.state.imageBytes[_sourceUrl], [1, 2, 3]);
        // Loading bytes is not an AI request.
        expect(bloc.state.status, AiImageStatus.idle);
      },
      expect: () => [
        isA<AiImageState>().having((s) => s.imageBytes.keys, 'urls', [_sourceUrl]),
      ],
    );

    test('a failed download emits nothing and can be retried', () async {
      var attempts = 0;
      service.onFetch = (url) async {
        attempts += 1;
        if (attempts == 1) throw const AiImageException('offline');
        return Uint8List.fromList([7]);
      };
      final bloc = AiImageBloc(aiImageService: service);

      bloc.add(const AiImageBytesRequested(_sourceUrl));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.imageBytes, isEmpty);
      expect(bloc.state.status, AiImageStatus.idle);

      bloc.add(const AiImageBytesRequested(_sourceUrl));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.imageBytes[_sourceUrl], [7]);
      await bloc.close();
    });
  });

  group('aspect ratio helpers', () {
    test('canvas size keeps the ratio with a 280 longest side', () {
      expect(aiCanvasSizeForAspectRatio('1:1'), const Size(280, 280));
      expect(aiCanvasSizeForAspectRatio('16:9'), const Size(280, 157.5));
      expect(aiCanvasSizeForAspectRatio('9:16'), const Size(157.5, 280));
      expect(aiCanvasSizeForAspectRatio('nonsense'), const Size(280, 280));
      expect(aiCanvasSizeForAspectRatio('0:5'), const Size(280, 280));
    });

    test('nearest aspect ratio picks from the offered list', () {
      expect(aiNearestAspectRatio(280, 280), '1:1');
      expect(aiNearestAspectRatio(400, 225), '16:9');
      expect(aiNearestAspectRatio(157.5, 280), '9:16');
      expect(aiNearestAspectRatio(300, 260), '1:1');
      expect(aiNearestAspectRatio(0, 0), '1:1');
    });
  });
}
