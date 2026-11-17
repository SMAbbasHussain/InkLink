import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/features/canvas/geometry/quick_shape.dart';

List<Offset> _line() => [
  for (var i = 0; i <= 30; i++) Offset(20 + i * 8, 100 + math.sin(i) * 1.2),
];

List<Offset> _rect() {
  const left = 20.0, top = 20.0, right = 220.0, bottom = 140.0;
  return [
    for (var i = 0; i <= 25; i++) Offset(left + i * 8, top),
    for (var i = 1; i <= 15; i++) Offset(right, top + i * 8),
    for (var i = 1; i <= 25; i++) Offset(right - i * 8, bottom),
    for (var i = 1; i <= 15; i++) Offset(left, bottom - i * 8),
    const Offset(left, top),
  ];
}

List<Offset> _ellipse() {
  const cx = 150.0, cy = 100.0, rx = 100.0, ry = 60.0;
  return [
    for (var i = 0; i <= 48; i++)
      Offset(
        cx + rx * math.cos(i / 48 * 2 * math.pi),
        cy + ry * math.sin(i / 48 * 2 * math.pi),
      ),
  ];
}

void main() {
  test('Given a rough horizontal line, Then it snaps to a line', () {
    final match = recognizeQuickShape(_line());
    expect(match, isNotNull);
    expect(match!.shapeType, CanvasShapeType.line);
    expect(match.rotation.abs(), lessThan(0.05));
    expect(match.width, greaterThan(200));
  });

  test('Given a closed rectangle, Then it snaps to a rectangle', () {
    final match = recognizeQuickShape(_rect());
    expect(match, isNotNull);
    expect(match!.shapeType, CanvasShapeType.rectangle);
    expect(match.width, closeTo(200, 2));
    expect(match.height, closeTo(120, 2));
    expect(match.center.dx, closeTo(120, 2));
  });

  test('Given a closed ellipse, Then it snaps to an ellipse', () {
    final match = recognizeQuickShape(_ellipse());
    expect(match, isNotNull);
    expect(match!.shapeType, CanvasShapeType.ellipse);
    expect(match.width, closeTo(200, 3));
    expect(match.height, closeTo(120, 3));
  });

  test('Given handwriting or a squiggle, Then it is left alone', () {
    final squiggle = [
      for (var i = 0; i <= 40; i++) Offset(i * 4.0, 80 + math.sin(i * 0.8) * 30),
    ];
    expect(recognizeQuickShape(squiggle), isNull);
    expect(recognizeQuickShape(const [Offset.zero, Offset(1, 1)]), isNull);
  });

  test('Given a short tap, Then it is not a shape', () {
    expect(
      recognizeQuickShape([for (var i = 0; i < 15; i++) const Offset(5, 5)]),
      isNull,
    );
  });
}
