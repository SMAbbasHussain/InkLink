import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shape Rotation Polar Angle Tracking', () {
    test('Clockwise rotation smoothly accumulates past 90, 180, and 270 degrees without reversing', () {
      const center = Offset(200, 200);
      const radius = 100.0;
      var currentRotation = 0.0;

      // Start drag at top handle (0 degrees rotation relative to handle, angle = -pi/2)
      final startTouch = center + const Offset(0, -radius);
      var prevTouchAngle = math.atan2(
        startTouch.dy - center.dy,
        startTouch.dx - center.dx,
      );

      // Verify initial angle is -pi/2
      expect(prevTouchAngle, closeTo(-math.pi / 2, 1e-4));

      // Simulate dragging around the circle clockwise in 1-degree increments up to 360 degrees
      final recordedRotations = <double>[];
      for (int deg = 1; deg <= 360; deg++) {
        final rad = (deg * math.pi / 180) - (math.pi / 2);
        final currentTouch = center + Offset(radius * math.cos(rad), radius * math.sin(rad));

        final currentTouchAngle = math.atan2(
          currentTouch.dy - center.dy,
          currentTouch.dx - center.dx,
        );

        var angleDiff = currentTouchAngle - prevTouchAngle;
        while (angleDiff > math.pi) {
          angleDiff -= 2 * math.pi;
        }
        while (angleDiff < -math.pi) {
          angleDiff += 2 * math.pi;
        }

        prevTouchAngle = currentTouchAngle;
        currentRotation += angleDiff;
        recordedRotations.add(currentRotation);
      }

      // Check monotonicity: every step should strictly increase (clockwise)
      for (int i = 1; i < recordedRotations.length; i++) {
        expect(
          recordedRotations[i],
          greaterThan(recordedRotations[i - 1]),
          reason: 'Rotation should monotonically increase at degree $i',
        );
      }

      // Check key milestones
      // At 90 degrees (~pi/2 rad)
      expect(recordedRotations[89], closeTo(math.pi / 2, 1e-3));
      // At 180 degrees (~pi rad)
      expect(recordedRotations[179], closeTo(math.pi, 1e-3));
      // At 270 degrees (~3*pi/2 rad = 4.712 rad) - user specifically called out 270 degrees!
      expect(recordedRotations[269], closeTo(3 * math.pi / 2, 1e-3));
      // At 360 degrees (~2*pi rad)
      expect(recordedRotations[359], closeTo(2 * math.pi, 1e-3));
    });

    test('Counter-clockwise rotation smoothly accumulates past -90, -180, and -270 degrees', () {
      const center = Offset(200, 200);
      const radius = 100.0;
      var currentRotation = 0.0;

      final startTouch = center + const Offset(0, -radius);
      var prevTouchAngle = math.atan2(
        startTouch.dy - center.dy,
        startTouch.dx - center.dx,
      );

      final recordedRotations = <double>[];
      for (int deg = 1; deg <= 360; deg++) {
        final rad = -(deg * math.pi / 180) - (math.pi / 2);
        final currentTouch = center + Offset(radius * math.cos(rad), radius * math.sin(rad));

        final currentTouchAngle = math.atan2(
          currentTouch.dy - center.dy,
          currentTouch.dx - center.dx,
        );

        var angleDiff = currentTouchAngle - prevTouchAngle;
        while (angleDiff > math.pi) {
          angleDiff -= 2 * math.pi;
        }
        while (angleDiff < -math.pi) {
          angleDiff += 2 * math.pi;
        }

        prevTouchAngle = currentTouchAngle;
        currentRotation += angleDiff;
        recordedRotations.add(currentRotation);
      }

      for (int i = 1; i < recordedRotations.length; i++) {
        expect(
          recordedRotations[i],
          lessThan(recordedRotations[i - 1]),
          reason: 'Counter-clockwise rotation should monotonically decrease at degree $i',
        );
      }

      expect(recordedRotations[89], closeTo(-math.pi / 2, 1e-3));
      expect(recordedRotations[179], closeTo(-math.pi, 1e-3));
      expect(recordedRotations[269], closeTo(-3 * math.pi / 2, 1e-3));
      expect(recordedRotations[359], closeTo(-2 * math.pi, 1e-3));
    });
  });
}

