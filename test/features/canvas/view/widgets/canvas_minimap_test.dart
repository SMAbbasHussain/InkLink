import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/widgets/canvas_minimap.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  const note = StickyNoteElement(
    id: 'a',
    z: 0,
    center: Offset(200, 200),
    text: 'A',
    width: 200,
    height: 200,
  );

  test('Given a board, Then world points round-trip through the minimap', () {
    final projection = MinimapProjection.fit(
      elements: const [note],
      size: const Size(160, 100),
    );

    for (final world in const [Offset(0, 0), Offset(200, 200), Offset(-80, 40)]) {
      final local = projection.toMinimap(world);
      final back = projection.toWorld(local);
      expect(back.dx, closeTo(world.dx, 0.001));
      expect(back.dy, closeTo(world.dy, 0.001));
    }
  });

  test('Given a viewport, Then its minimap rect is clipped to the widget', () {
    final projection = MinimapProjection.fit(
      elements: const [note],
      size: const Size(160, 100),
    );
    final rect = projection.viewportRect(
      viewportOffset: Offset.zero,
      viewportScale: 1,
      viewportSize: const Size(800, 600),
    );

    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(160));
    expect(rect.bottom, lessThanOrEqualTo(100));
    expect(rect.width, greaterThan(0));
  });

  testWidgets('Given a tap on the minimap, Then it jumps to that world point',
      (tester) async {
    Offset? jump;
    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: Scaffold(
          body: Center(
            child: CanvasMinimap(
              elements: const [note],
              viewportScale: 1,
              viewportOffset: Offset.zero,
              viewportSize: const Size(800, 600),
              onJump: (world) => jump = world,
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(CanvasMinimap));
    await tester.tapAt(box.center);
    await tester.pump();

    expect(jump, isNotNull);
    expect(jump!.dx, closeTo(200, 15));
    expect(jump!.dy, closeTo(200, 15));
  });
}
