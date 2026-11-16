import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/canvas/canvas_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

void main() {
  test('Given a stroke with tilt, Then the payload round-trips it', () {
    const stroke = StrokeElement(
      id: 's',
      z: 0,
      color: Colors.black,
      points: [Offset(0, 0), Offset(10, 0)],
      pressures: [0.5, 0.8],
      tilts: [0, math.pi / 3],
    );

    final parsed = CanvasElement.fromMap('s', stroke.toMap());

    expect(parsed, stroke);
    expect((parsed as StrokeElement).tilts, [0, math.pi / 3]);
  });

  test('Given a legacy stroke, Then tilts default to empty', () {
    final parsed = CanvasElement.fromMap('s', const {
      'type': 'stroke',
      'color': 0xFF000000,
      'strokeWidth': 4,
      'points': [
        {'x': 0, 'y': 0},
      ],
    });

    expect((parsed as StrokeElement).tilts, isEmpty);
  });

  test('Given a tilted stylus, Then stamps widen but stay bounded', () {
    final style = resolveBrushStyle(
      brushType: 'solid',
      strokeWidth: 10,
      strokeOpacity: 1,
    );
    final points = [for (var i = 0; i <= 10; i++) Offset(i * 10.0, 0)];
    final upright = resampleStroke(
      points: points,
      pressures: List<double>.filled(points.length, 1),
      tilts: List<double>.filled(points.length, 0),
      baseWidth: 10,
      baseOpacity: 1,
      style: style,
    );
    final tilted = resampleStroke(
      points: points,
      pressures: List<double>.filled(points.length, 1),
      tilts: List<double>.filled(points.length, math.pi / 2),
      baseWidth: 10,
      baseOpacity: 1,
      style: style,
    );

    expect(tiltWidthScale(0), 1);
    expect(tiltWidthScale(math.pi / 2), closeTo(1.65, 0.001));
    expect(tilted.first.radius, greaterThan(upright.first.radius));
    expect(tilted.first.radius, closeTo(upright.first.radius * 1.65, 0.01));
  });
}
