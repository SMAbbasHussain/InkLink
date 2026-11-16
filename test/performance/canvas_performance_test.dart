import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

void main() {
  test('Given a 6000-object board, then ordering and bounds stay bounded', () {
    final elements = <CanvasElement>[
      for (var i = 0; i < 4000; i++)
        ShapeElement(
          id: 'shape-$i',
          z: i,
          shapeType: CanvasShapeType.rectangle,
          center: Offset((i % 80) * 40.0, (i ~/ 80) * 30.0),
          size: 40,
          color: Colors.black,
        ),
      for (var i = 0; i < 2000; i++)
        StrokeElement(
          id: 'stroke-$i',
          z: 4000 + i,
          color: Colors.black,
          points: const [
            Offset(0, 0),
            Offset(12, 8),
            Offset(24, 4),
            Offset(36, 16),
          ],
        ),
    ];

    final stopwatch = Stopwatch()..start();
    final order = canvasPaintOrder(elements);
    var boundsTotal = 0.0;
    for (final element in order.elements) {
      final bounds = elementBounds(element);
      if (bounds != null) boundsTotal += bounds.width + bounds.height;
    }
    stopwatch.stop();

    expect(order.elements.length, elements.length);
    expect(boundsTotal, greaterThan(0));
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 3)),
      reason:
          'Large-board paint-order and bounds took ${stopwatch.elapsedMilliseconds}ms',
    );
  });
}
