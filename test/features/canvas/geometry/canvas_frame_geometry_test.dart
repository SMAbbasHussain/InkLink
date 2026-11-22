import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

void main() {
  group('FrameElement', () {
    test('Given a frame, Then toMap/fromMap round-trip every field', () {
      const frame = FrameElement(
        id: 'frame-1',
        z: 4,
        center: Offset(240, 200),
        width: 480,
        height: 320,
        title: 'Ideation',
        color: Color(0xFF2563EB),
        cornerRadius: 18,
      );

      final parsed = CanvasElement.fromMap('frame-1', frame.toMap());

      expect(parsed, frame);
      expect(parsed, isA<FrameElement>());
    });

    test('Given a legacy payload, Then defaults keep it usable', () {
      final parsed =
          CanvasElement.fromMap('legacy', {'type': 'frame', 'z': 3})
              as FrameElement;

      expect(parsed.width, FrameElement.defaultWidth);
      expect(parsed.height, FrameElement.defaultHeight);
      expect(parsed.title, '');
      expect(parsed.color, const Color(0xFF64748B));
      expect(parsed.z, 3);
    });

    test('Given a frame, Then its bounds include the border', () {
      const frame = FrameElement(
        id: 'f',
        z: 0,
        center: Offset(300, 200),
        width: 400,
        height: 200,
      );

      expect(
        elementBounds(frame),
        Rect.fromCenter(
          center: const Offset(300, 200),
          width: 400,
          height: 200,
        ).inflate(1.5),
      );
      expect(frameRect(frame), const Rect.fromLTWH(100, 100, 400, 200));
    });

    test('Given contained, partial and outside elements, Then only fully '
        'contained elements belong to the frame', () {
      const frame = FrameElement(
        id: 'frame',
        z: 0,
        center: Offset(300, 300),
        width: 400,
        height: 300,
      );
      const inside = StickyNoteElement(
        id: 'inside',
        z: 1,
        center: Offset(300, 300),
      );
      const straddling = StickyNoteElement(
        id: 'straddling',
        z: 2,
        center: Offset(500, 300),
      );
      const outside = StickyNoteElement(
        id: 'outside',
        z: 3,
        center: Offset(900, 900),
      );
      const layer = LayerElement(
        id: 'layer',
        z: 4,
        name: 'Layer',
        elementIds: ['inside'],
      );

      expect(frameContainsElement(frame, frame), isFalse);
      expect(frameContainsElement(frame, layer), isFalse);
      expect(frameContainsElement(frame, inside), isTrue);
      expect(frameContainsElement(frame, straddling), isFalse);
      expect(frameContainsElement(frame, outside), isFalse);
      expect(
        elementsContainedByFrame(frame, [
          frame,
          inside,
          straddling,
          outside,
          layer,
        ]).map((element) => element.id),
        ['inside'],
      );
    });
  });

  group('canvasEdgeAutoPanDelta', () {
    const size = Size(800, 600);

    test('returns zero inside the central safe area', () {
      expect(
        canvasEdgeAutoPanDelta(
          localPosition: const Offset(400, 300),
          canvasSize: size,
        ),
        Offset.zero,
      );
    });

    test('pans diagonally when dragged into any corner', () {
      final topLeft = canvasEdgeAutoPanDelta(
        localPosition: const Offset(0, 0),
        canvasSize: size,
      );
      expect(topLeft.dx, greaterThan(0));
      expect(topLeft.dy, greaterThan(0));

      final topRight = canvasEdgeAutoPanDelta(
        localPosition: const Offset(800, 0),
        canvasSize: size,
      );
      expect(topRight.dx, lessThan(0));
      expect(topRight.dy, greaterThan(0));

      final bottomLeft = canvasEdgeAutoPanDelta(
        localPosition: const Offset(0, 600),
        canvasSize: size,
      );
      expect(bottomLeft.dx, greaterThan(0));
      expect(bottomLeft.dy, lessThan(0));

      final bottomRight = canvasEdgeAutoPanDelta(
        localPosition: const Offset(800, 600),
        canvasSize: size,
      );
      expect(bottomRight.dx, lessThan(0));
      expect(bottomRight.dy, lessThan(0));
    });
  });
}
