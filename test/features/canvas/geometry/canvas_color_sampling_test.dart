import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_color_sampling.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

ShapeElement _square({
  required String id,
  required int z,
  required Color color,
  Offset center = const Offset(50, 50),
  double size = 100,
  bool hidden = false,
}) {
  return ShapeElement(
    id: id,
    z: z,
    hidden: hidden,
    shapeType: CanvasShapeType.square,
    center: center,
    size: size,
    color: color,
  );
}

void main() {
  group('sampleCanvasColorAt', () {
    test('returns null over empty canvas', () {
      final elements = <CanvasElement>[
        _square(id: 'a', z: 0, color: Colors.red),
      ];
      expect(sampleCanvasColorAt(elements, const Offset(500, 500)), isNull);
    });

    test('returns the topmost element regardless of list order', () {
      final elements = <CanvasElement>[
        _square(id: 'top', z: 5, color: Colors.blue),
        _square(id: 'bottom', z: 1, color: Colors.red),
      ];
      expect(sampleCanvasColorAt(elements, const Offset(50, 50)), Colors.blue);
    });

    test('skips hidden elements and samples what is beneath', () {
      final elements = <CanvasElement>[
        _square(id: 'hidden', z: 9, color: Colors.blue, hidden: true),
        _square(id: 'visible', z: 1, color: Colors.green),
      ];
      expect(
        sampleCanvasColorAt(elements, const Offset(50, 50)),
        Colors.green,
      );
    });

    test('samples a stroke colour along its path', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 'stroke',
          z: 0,
          color: Color(0xFF123456),
          points: [Offset(0, 0), Offset(100, 0)],
          strokeWidth: 8,
        ),
      ];
      expect(
        sampleCanvasColorAt(elements, const Offset(50, 1)),
        const Color(0xFF123456),
      );
      expect(sampleCanvasColorAt(elements, const Offset(50, 40)), isNull);
    });

    test('prefers a higher layer band over a greater global z', () {
      final elements = <CanvasElement>[
        _square(id: 'default', z: 99, color: Colors.red),
        _square(id: 'layered', z: 0, color: Colors.blue),
        const LayerElement(
          id: 'layer',
          z: 0,
          name: 'Layer',
          elementIds: ['layered'],
        ),
      ];
      expect(sampleCanvasColorAt(elements, const Offset(50, 50)), Colors.blue);
    });
  });
}
