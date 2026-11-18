import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/canvas/canvas_render_utils.dart';
import 'package:inklink/features/canvas/models/brush_preset.dart';

void main() {
  group('DeterministicBrushRandom', () {
    test('produces reproducible sequences for identical seeds', () {
      final rng1 = DeterministicBrushRandom(12345);
      final rng2 = DeterministicBrushRandom(12345);

      final seq1 = List.generate(20, (_) => rng1.nextDouble());
      final seq2 = List.generate(20, (_) => rng2.nextDouble());

      expect(seq1, equals(seq2));
    });

    test('produces different sequences for different seeds', () {
      final rng1 = DeterministicBrushRandom(111);
      final rng2 = DeterministicBrushRandom(222);

      final v1 = rng1.nextDouble();
      final v2 = rng2.nextDouble();

      expect(v1, isNot(equals(v2)));
    });

    test('range produces values within bounds', () {
      final rng = DeterministicBrushRandom(42);
      for (var i = 0; i < 50; i++) {
        final val = rng.range(5.0, 15.0);
        expect(val, greaterThanOrEqualTo(5.0));
        expect(val, lessThan(15.0));
      }
    });
  });

  group('resampleStroke', () {
    final defaultStyle = resolveBrushStyle(
      brushType: 'solid',
      strokeWidth: 10.0,
      strokeOpacity: 1.0,
    );

    test('returns empty list for empty input', () {
      final result = resampleStroke(
        points: const [],
        pressures: const [],
        baseWidth: 10.0,
        baseOpacity: 1.0,
        style: defaultStyle,
      );
      expect(result, isEmpty);
    });

    test('handles single point input', () {
      final result = resampleStroke(
        points: const [Offset(10, 20)],
        pressures: const [0.8],
        baseWidth: 10.0,
        baseOpacity: 1.0,
        style: defaultStyle,
      );
      expect(result.length, 1);
      expect(result.first.position, const Offset(10, 20));
      expect(result.first.pressure, 0.8);
      expect(result.first.radius, greaterThan(0));
    });

    test('resamples a straight line at expected spacing', () {
      final points = [const Offset(0, 0), const Offset(100, 0)];
      final result = resampleStroke(
        points: points,
        pressures: const [1.0, 1.0],
        baseWidth: 10.0,
        baseOpacity: 1.0,
        style: defaultStyle,
        spacingOverride: 0.5,
      );

      expect(result.length, greaterThan(15));
      expect(result.first.position, const Offset(0, 0));
      expect(result.last.position.dx, closeTo(100, 3.0));
    });

    test('interpolates pressures across stroke points', () {
      final customStyle = CanvasBrushStyle(
        width: 10.0,
        opacity: 1.0,
        cap: StrokeCap.round,
        blendMode: BlendMode.srcOver,
        blurSigma: 0.0,
        texture: BrushTexture.none,
        spacing: 0.2,
        jitter: 0.0,
        pressureAffectsSize: true,
        pressureAffectsOpacity: true,
        taperStart: 0.0,
        taperEnd: 0.0,
      );

      final points = [
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(100, 0),
      ];
      final pressures = [0.2, 1.0, 0.2];
      final result = resampleStroke(
        points: points,
        pressures: pressures,
        baseWidth: 10.0,
        baseOpacity: 1.0,
        style: customStyle,
      );

      final mid = result[result.length ~/ 2];
      expect(mid.pressure, greaterThan(result.first.pressure));
      expect(mid.radius, greaterThan(result.first.radius));
    });

    test('taper scales down radius at extremities', () {
      final taperedStyle = CanvasBrushStyle(
        width: 10.0,
        opacity: 1.0,
        cap: StrokeCap.round,
        blendMode: BlendMode.srcOver,
        blurSigma: 0.0,
        texture: BrushTexture.none,
        spacing: 0.2,
        jitter: 0.0,
        pressureAffectsSize: false,
        pressureAffectsOpacity: false,
        taperStart: 0.3,
        taperEnd: 0.3,
      );

      final points = [
        const Offset(0, 0),
        const Offset(50, 0),
        const Offset(100, 0),
      ];
      final result = resampleStroke(
        points: points,
        pressures: const [1.0, 1.0, 1.0],
        baseWidth: 10.0,
        baseOpacity: 1.0,
        style: taperedStyle,
      );

      expect(result.first.radius, lessThan(result[result.length ~/ 2].radius));
      expect(result.last.radius, lessThan(result[result.length ~/ 2].radius));
    });
  });

  group('paintCanvasStroke', () {
    late PictureRecorder recorder;
    late Canvas canvas;

    setUp(() {
      recorder = PictureRecorder();
      canvas = Canvas(recorder);
    });

    tearDown(() {
      recorder.endRecording();
    });

    test('paints without throwing for empty and single point', () {
      expect(
        () => paintCanvasStroke(
          canvas: canvas,
          points: const [],
          color: Colors.blue,
          strokeWidth: 4,
          strokeOpacity: 1,
          brushType: 'solid',
        ),
        returnsNormally,
      );

      expect(
        () => paintCanvasStroke(
          canvas: canvas,
          points: const [Offset(20, 20)],
          color: Colors.blue,
          strokeWidth: 4,
          strokeOpacity: 1,
          brushType: 'solid',
        ),
        returnsNormally,
      );
    });

    test('renders all 8 presets without errors', () {
      final samplePoints = [
        const Offset(10, 10),
        const Offset(25, 30),
        const Offset(50, 45),
        const Offset(80, 20),
      ];
      final samplePressures = [0.4, 0.8, 1.0, 0.5];

      final presetIds = [
        'solid',
        'pencil',
        'textured',
        'marker',
        'highlighter',
        'watercolor',
        'airbrush',
        'charcoal',
      ];

      for (final id in presetIds) {
        expect(
          () => paintCanvasStroke(
            canvas: canvas,
            points: samplePoints,
            pressures: samplePressures,
            color: Colors.purple,
            strokeWidth: 8,
            strokeOpacity: 0.85,
            brushType: id,
            brushId: id,
            textureSeed: 99,
          ),
          returnsNormally,
          reason: 'Preset $id should render normally',
        );
      }
    });

    test('handles 1000 points performantly without throwing', () {
      final largePoints = List.generate(
        1000,
        (i) => Offset(i.toDouble(), 50 + 20 * math.sin(i / 10)),
      );
      final largePressures = List.generate(
        1000,
        (i) => 0.5 + 0.5 * math.cos(i / 20),
      );

      final stopwatch = Stopwatch()..start();
      paintCanvasStroke(
        canvas: canvas,
        points: largePoints,
        pressures: largePressures,
        color: Colors.teal,
        strokeWidth: 6,
        strokeOpacity: 1.0,
        brushType: 'watercolor',
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(400));
    });
  });
}
