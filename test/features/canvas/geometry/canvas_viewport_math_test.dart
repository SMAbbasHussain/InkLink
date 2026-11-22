import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_viewport_math.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';

void main() {
  test('Given extreme scales, Then zoom clamps to 0.1–4×', () {
    expect(clampCanvasZoom(0.05), minCanvasZoom);
    expect(clampCanvasZoom(8), maxCanvasZoom);
    expect(clampCanvasZoom(1.75), 1.75);
  });

  test('Given a focal point, Then the same world point stays under it', () {
    const focal = Offset(320, 180);
    const world = Offset(120, -40);
    const scale = 2.5;

    final offset = canvasOffsetForZoom(
      focalPoint: focal,
      worldPoint: world,
      scale: scale,
    );
    final back = worldPointForViewport(
      localPoint: focal,
      viewportOffset: offset,
      scale: scale,
    );

    expect(back.dx, closeTo(world.dx, 0.0001));
    expect(back.dy, closeTo(world.dy, 0.0001));
  });

  test(
    'Given a pinch, Then the world point under the pinch stays anchored',
    () {
      const focal = Offset(240, 160);
      const startOffset = Offset(40, 20);
      const startScale = 1.0;
      const nextScale = 2.0;
      final before = worldPointForViewport(
        localPoint: focal,
        viewportOffset: startOffset,
        scale: startScale,
      );
      final offset = canvasOffsetForPinch(
        startFocal: focal,
        startOffset: startOffset,
        startScale: startScale,
        nextScale: nextScale,
      );
      final after = worldPointForViewport(
        localPoint: focal,
        viewportOffset: offset,
        scale: nextScale,
      );

      expect(after.dx, closeTo(before.dx, 0.0001));
      expect(after.dy, closeTo(before.dy, 0.0001));
      expect(offset, const Offset(-160, -120));
    },
  );

  test(
    'Given wheel deltas, Then up zooms in, down zooms out and bounds hold',
    () {
      expect(canvasZoomForScrollDelta(1, -120), greaterThan(1));
      expect(canvasZoomForScrollDelta(1, 120), lessThan(1));
      expect(canvasZoomForScrollDelta(1, -100000), maxCanvasZoom);
      expect(canvasZoomForScrollDelta(1, 100000), minCanvasZoom);
    },
  );

  test('Given a wheel scroll without a zoom modifier, Then the board pans', () {
    expect(
      canvasOffsetForPan(const Offset(100, 50), const Offset(10, -20)),
      const Offset(90, 70),
    );
  });

  test(
    'Given hand, Space, two pointers or a viewer, Then the camera moves',
    () {
      bool starts({
        CanvasToolMode tool = CanvasToolMode.doodle,
        bool space = false,
        int pointers = 1,
        bool canEdit = true,
        bool forcePan = false,
      }) => startsCanvasTransform(
        tool: tool,
        spacePressed: space,
        pointerCount: pointers,
        canEdit: canEdit,
        forceOneFingerPan: forcePan,
      );

      expect(starts(tool: CanvasToolMode.hand), isTrue);
      expect(starts(space: true), isTrue);
      expect(starts(pointers: 2), isTrue);
      expect(starts(canEdit: false), isTrue);
      expect(starts(forcePan: true), isTrue);
      expect(starts(), isFalse);
    },
  );

  test('Given a scale, Then the chip shows a rounded percentage', () {
    expect(canvasZoomPercentLabel(1), '100%');
    expect(canvasZoomPercentLabel(1.333), '133%');
    expect(canvasZoomPercentLabel(10), '400%');
  });
}
