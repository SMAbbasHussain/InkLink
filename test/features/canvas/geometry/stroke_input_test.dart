import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/stroke_input.dart';

void main() {
  group('pressure normalization', () {
    test('Given a stylus range, When sampled, Then pressure is normalized', () {
      expect(
        normalizePointerPressure(
          kind: PointerDeviceKind.stylus,
          pressure: 512,
          pressureMin: 0,
          pressureMax: 1024,
        ),
        0.5,
      );
      expect(
        normalizePointerPressure(
          kind: PointerDeviceKind.invertedStylus,
          pressure: 6,
          pressureMin: 2,
          pressureMax: 10,
        ),
        0.5,
      );
    });

    test('Given touch or mouse, When sampled, Then pressure stays full', () {
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        expect(
          normalizePointerPressure(
            kind: kind,
            pressure: 0.2,
            pressureMin: 0,
            pressureMax: 1,
          ),
          1,
        );
      }
    });

    test('Given invalid or absent range, Then pressure falls back to full', () {
      for (final max in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          normalizePointerPressure(
            kind: PointerDeviceKind.stylus,
            pressure: 0.5,
            pressureMin: 0,
            pressureMax: max,
          ),
          1,
        );
      }
    });

    test(
      'Given pressure outside range, Then it stays drawable and bounded',
      () {
        for (final (raw, expected) in [(-2.0, minStylusPressure), (5.0, 1.0)]) {
          expect(
            normalizePointerPressure(
              kind: PointerDeviceKind.stylus,
              pressure: raw,
              pressureMin: 0,
              pressureMax: 1,
            ),
            expected,
          );
        }
      },
    );
  });

  group('live stabilizer', () {
    test('Given strength zero, Then raw input and endpoint are unchanged', () {
      final filter = StrokeStabilizer(strength: 0);
      expect(filter.add(Offset.zero), [Offset.zero]);
      expect(filter.add(const Offset(10, 3)), [const Offset(10, 3)]);
      expect(filter.finish(), isEmpty);
    });

    test(
      'Given EMA strength, Then input is smoothed and endpoint restored',
      () {
        final filter = StrokeStabilizer(strength: 0.5);
        filter.add(Offset.zero);
        expect(filter.add(const Offset(10, 0)), [const Offset(5, 0)]);
        expect(filter.add(const Offset(20, 0)), [const Offset(12.5, 0)]);
        expect(filter.finish(), [const Offset(20, 0)]);
      },
    );

    test('Given a sharp turn, Then the raw corner is preserved', () {
      final filter = StrokeStabilizer(strength: 0.8);
      filter.add(Offset.zero);
      filter.add(const Offset(20, 0));
      expect(filter.add(const Offset(20, 20)), [
        const Offset(20, 0),
        const Offset(20, 20),
      ]);
    });

    test('Given a pause, Then the filter resets to the raw point', () {
      final filter = StrokeStabilizer(strength: 0.8);
      filter.add(Offset.zero, elapsed: Duration.zero);
      filter.add(
        const Offset(20, 0),
        elapsed: const Duration(milliseconds: 10),
      );
      expect(
        filter.add(
          const Offset(30, 0),
          elapsed: const Duration(milliseconds: 250),
        ),
        [const Offset(30, 0)],
      );
    });

    test('Given tiny jitter, Then it does not reset the filter', () {
      final filter = StrokeStabilizer(strength: 0.5);
      filter.add(Offset.zero);
      filter.add(const Offset(2, 0));
      expect(filter.add(const Offset(2, 2)), [const Offset(1.5, 1)]);
    });

    test(
      'Given continuous fine-grained curve steps, Then no raw corner spike is injected',
      () {
        final filter = StrokeStabilizer(strength: 0.75);
        filter.add(Offset.zero);
        // Simulate dense 2px pointer samples along a curve that turns > 60 deg
        // over multiple steps. Each step is < minCornerSegment (6.0), so the
        // stabilizer must smooth continuously rather than emitting raw pairs.
        const rawSamples = [
          Offset(2, 0),
          Offset(4, 0.5),
          Offset(6, 1.5),
          Offset(7.5, 3.0),
          Offset(8.5, 5.0),
          Offset(9.0, 7.0),
          Offset(9.0, 9.0),
        ];
        for (final sample in rawSamples) {
          final emitted = filter.add(sample);
          expect(emitted.length, 1);
        }
      },
    );
  });

  test('Given post-smoothing, Then count and endpoints are preserved', () {
    const points = [Offset.zero, Offset(10, 8), Offset(20, 0), Offset(30, 0)];
    final smoothed = smoothStrokePoints(points);
    expect(smoothed.length, points.length);
    expect(smoothed.first, points.first);
    expect(smoothed.last, points.last);
    expect(smoothed[1].dy, closeTo(8 / 3, 1e-9));
  });
}
