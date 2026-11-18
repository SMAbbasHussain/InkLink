import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_selection_transform.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

void main() {
  group('scaleElementPayload', () {
    test('maps a shape centre and scales width/height independently', () {
      const shape = ShapeElement(
        id: 's',
        z: 0,
        shapeType: CanvasShapeType.square,
        center: Offset(50, 50),
        size: 40,
        color: Colors.black,
      );
      final data = scaleElementPayload(
        shape,
        const Rect.fromLTWH(0, 0, 100, 100),
        const Rect.fromLTWH(0, 0, 200, 100),
      );
      final scaled = CanvasElement.fromMap('s', data) as ShapeElement;
      expect(scaled.center, const Offset(100, 50));
      // Legacy square (aspect 1:1) 40x40; sx 2, sy 1 -> 80x40, size = max.
      expect(scaled.width, closeTo(80, 0.001));
      expect(scaled.height, closeTo(40, 0.001));
      expect(scaled.size, closeTo(80, 0.001));
    });

    test('keeps a linear shape flat when scaled non-uniformly', () {
      const arrow = ShapeElement(
        id: 'a',
        z: 0,
        shapeType: CanvasShapeType.arrow,
        center: Offset(50, 50),
        size: 40,
        width: 100,
        height: 0,
        color: Colors.black,
      );
      final data = scaleElementPayload(
        arrow,
        const Rect.fromLTWH(0, 0, 100, 100),
        const Rect.fromLTWH(0, 0, 200, 300),
      );
      final scaled = CanvasElement.fromMap('a', data) as ShapeElement;
      // uniform = (2 + 3) / 2 = 2.5 -> length 250, height stays 0.
      expect(scaled.width, closeTo(250, 0.001));
      expect(scaled.height, 0);
      expect(scaled.size, closeTo(250, 0.001));
    });

    test('scales stroke points and width', () {
      const stroke = StrokeElement(
        id: 'p',
        z: 0,
        color: Colors.black,
        strokeWidth: 4,
        points: [Offset(10, 10), Offset(20, 20)],
      );
      final data = scaleElementPayload(
        stroke,
        const Rect.fromLTWH(0, 0, 100, 100),
        const Rect.fromLTWH(0, 0, 200, 50),
      );
      final scaled = CanvasElement.fromMap('p', data) as StrokeElement;
      expect(scaled.points, [const Offset(20, 5), const Offset(40, 10)]);
      expect(scaled.strokeWidth, closeTo(5, 0.001));
    });

    test('scales the text box but not the font size', () {
      const text = TextElement(
        id: 't',
        z: 0,
        text: 'hello',
        center: Offset(0, 0),
        color: Colors.black,
        width: 100,
        height: 40,
        fontSize: 16,
      );
      final data = scaleElementPayload(
        text,
        const Rect.fromLTWH(0, 0, 100, 40),
        const Rect.fromLTWH(0, 0, 200, 80),
      );
      final scaled = CanvasElement.fromMap('t', data) as TextElement;
      expect(scaled.width, closeTo(200, 0.001));
      expect(scaled.height, closeTo(80, 0.001));
      expect(scaled.fontSize, 16);
    });

    test('leaves attached connector ends alone', () {
      const connector = ConnectorElement(
        id: 'c',
        z: 0,
        startElementId: 'a',
        startPoint: Offset(0, 0),
        endElementId: 'b',
        endPoint: Offset(50, 50),
      );
      final data = scaleElementPayload(
        connector,
        const Rect.fromLTWH(0, 0, 100, 100),
        const Rect.fromLTWH(100, 100, 200, 200),
      );
      final scaled = CanvasElement.fromMap('c', data) as ConnectorElement;
      expect(scaled.startElementId, 'a');
      expect(scaled.endElementId, 'b');
      expect(scaled.startPoint, Offset.zero);
      expect(scaled.endPoint, const Offset(50, 50));
    });
  });

  group('rotateElementPayload', () {
    test('rotates a shape centre and adds to its own rotation', () {
      const shape = ShapeElement(
        id: 's',
        z: 0,
        shapeType: CanvasShapeType.square,
        center: Offset(10, 0),
        size: 40,
        color: Colors.black,
      );
      final data = rotateElementPayload(
        shape,
        Offset.zero,
        math.pi / 2,
      );
      final rotated = CanvasElement.fromMap('s', data) as ShapeElement;
      expect(rotated.center.dx, closeTo(0, 1e-6));
      expect(rotated.center.dy, closeTo(10, 1e-6));
      expect(rotated.rotation, closeTo(math.pi / 2, 1e-6));
    });

    test('orbits a text box around the pivot and keeps its box size', () {
      const text = TextElement(
        id: 't',
        z: 0,
        text: 'hello',
        center: Offset(0, 0),
        color: Colors.black,
        width: 100,
        height: 40,
      );
      // Box centre (50, 20) rotated 90deg about the origin -> (-20, 50).
      final data = rotateElementPayload(text, Offset.zero, math.pi / 2);
      final rotated = CanvasElement.fromMap('t', data) as TextElement;
      expect(rotated.center.dx, closeTo(-70, 1e-6));
      expect(rotated.center.dy, closeTo(30, 1e-6));
      expect(rotated.width, 100);
      expect(rotated.height, 40);
      expect(rotated.rotation, closeTo(math.pi / 2, 1e-6));
    });

    test('spins an image and keeps its flip metadata', () {
      const image = ImageElement(
        id: 'img',
        z: 0,
        center: Offset(10, 0),
        width: 40,
        height: 20,
        imageBase64: '',
        flipped: true,
      );

      final data = rotateElementPayload(image, Offset.zero, math.pi / 2);
      final rotated = CanvasElement.fromMap('img', data) as ImageElement;

      expect(rotated.center.dx, closeTo(0, 1e-6));
      expect(rotated.center.dy, closeTo(10, 1e-6));
      expect(rotated.rotation, closeTo(math.pi / 2, 1e-6));
      expect(rotated.flipped, isTrue);
    });

    test('rotates stroke points', () {
      const stroke = StrokeElement(
        id: 'p',
        z: 0,
        color: Colors.black,
        points: [Offset(10, 0), Offset(0, 10)],
      );
      final data = rotateElementPayload(stroke, Offset.zero, math.pi / 2);
      final rotated = CanvasElement.fromMap('p', data) as StrokeElement;
      expect(rotated.points[0].dx, closeTo(0, 1e-6));
      expect(rotated.points[0].dy, closeTo(10, 1e-6));
      expect(rotated.points[1].dx, closeTo(-10, 1e-6));
    });
  });

  group('shouldDeselectOnCanvasTap', () {
    test('deselects multi-selection when tapping clear board or unselected element', () {
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a', 'b'},
          hitElementId: null,
        ),
        isTrue,
      );
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a', 'b'},
          hitElementId: 'c',
        ),
        isTrue,
      );
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.hand,
          selectedIds: const {'a', 'b'},
          hitElementId: 'c',
        ),
        isTrue,
      );
    });

    test('keeps multi-selection when tapping one of the selected items', () {
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a', 'b'},
          hitElementId: 'a',
        ),
        isFalse,
      );
    });

    test('deselects single selection on clear board only in select mode', () {
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a'},
          hitElementId: null,
        ),
        isTrue,
      );
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a'},
          hitElementId: 'b',
        ),
        isFalse,
      );
      expect(
        shouldDeselectOnCanvasTap(
          tool: CanvasToolMode.hand,
          selectedIds: const {'a'},
          hitElementId: null,
        ),
        isFalse,
      );
    });
  });

  group('shouldDeselectOnCanvasDoubleTap', () {
    test('deselects all items on clear board only in select mode', () {
      expect(
        shouldDeselectOnCanvasDoubleTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a', 'b'},
          hitElementId: null,
        ),
        isTrue,
      );
      expect(
        shouldDeselectOnCanvasDoubleTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a'},
          hitElementId: null,
        ),
        isTrue,
      );
      expect(
        shouldDeselectOnCanvasDoubleTap(
          tool: CanvasToolMode.select,
          selectedIds: const {'a', 'b'},
          hitElementId: 'a',
        ),
        isFalse,
      );
      expect(
        shouldDeselectOnCanvasDoubleTap(
          tool: CanvasToolMode.doodle,
          selectedIds: const {'a', 'b'},
          hitElementId: null,
        ),
        isFalse,
      );
    });
  });
}
