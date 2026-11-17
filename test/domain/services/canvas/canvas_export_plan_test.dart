import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_element.dart';
import 'package:inklink/domain/models/canvas/canvas_export_options.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';

void main() {
  const service = BoardExportServiceImpl();

  const a = StickyNoteElement(
    id: 'a',
    z: 0,
    center: Offset(100, 100),
    text: 'A',
    width: 100,
    height: 100,
  );
  const b = StickyNoteElement(
    id: 'b',
    z: 1,
    center: Offset(400, 100),
    text: 'B',
    width: 100,
    height: 100,
  );
  const connector = ConnectorElement(
    id: 'c',
    z: 2,
    startPoint: Offset(150, 100),
    endPoint: Offset(350, 100),
    startElementId: 'a',
    endElementId: 'b',
  );
  const all = [a, b, connector];

  test('Given board scope, Then all visible elements with padding are used',
      () {
    final plan = service.buildExportPlan(
      elements: all,
      options: const CanvasExportOptions(scale: 2),
    );

    expect(plan.elements, all);
    expect(plan.bounds, service.computeElementsBounds(all).inflate(16));
    expect(plan.scale, 2);
  });

  test('Given a selection, Then only selected elements (and attached '
      'connectors) are exported', () {
    final plan = service.buildExportPlan(
      elements: all,
      options: const CanvasExportOptions(scope: CanvasExportScope.selection),
      selectedIds: {'a', 'b'},
    );

    expect(plan.elements.map((e) => e.id), containsAll(['a', 'b', 'c']));
    expect(
      plan.bounds,
      service.computeElementsBounds(const [a, b, connector]).inflate(16),
    );
  });

  test('Given no selection, Then selection scope throws a clear error', () {
    expect(
      () => service.buildExportPlan(
        elements: all,
        options: const CanvasExportOptions(
          scope: CanvasExportScope.selection,
        ),
      ),
      throwsA(
        isA<CanvasExportException>().having(
          (error) => error.message,
          'message',
          contains('Select something'),
        ),
      ),
    );
  });

  test('Given a frame, Then only fully contained elements are included', () {
    const frame = FrameElement(
      id: 'frame',
      z: -1,
      center: Offset(100, 100),
      width: 200,
      height: 200,
      title: 'Section',
    );
    const inside = StickyNoteElement(
      id: 'inside',
      z: 0,
      center: Offset(100, 100),
      text: 'Inside',
      width: 40,
      height: 40,
    );
    const outside = StickyNoteElement(
      id: 'outside',
      z: 1,
      center: Offset(500, 500),
      text: 'Outside',
    );

    final plan = service.buildExportPlan(
      elements: const [frame, inside, outside],
      options: const CanvasExportOptions(
        scope: CanvasExportScope.frame,
        frameId: 'frame',
      ),
    );

    expect(plan.elements.map((e) => e.id), containsAll(['frame', 'inside']));
    expect(plan.elements.map((e) => e.id), isNot(contains('outside')));
    expect(plan.bounds.center, const Offset(100, 100));
    expect(plan.bounds.width, 200 + 32);
  });

  test('Given a missing frame, Then frame scope throws', () {
    expect(
      () => service.buildExportPlan(
        elements: all,
        options: const CanvasExportOptions(
          scope: CanvasExportScope.frame,
          frameId: 'missing',
        ),
      ),
      throwsA(isA<CanvasExportException>()),
    );
  });

  test('Given a huge area, Then the plan is rejected instead of silently '
      'downscaled', () {
    const huge = StickyNoteElement(
      id: 'huge',
      z: 0,
      center: Offset.zero,
      text: 'Huge',
      width: 9000,
      height: 100,
    );

    expect(
      () => service.buildExportPlan(
        elements: const [huge],
        options: const CanvasExportOptions(scale: 2),
      ),
      throwsA(
        isA<CanvasExportException>().having(
          (error) => error.message,
          'message',
          contains('8192'),
        ),
      ),
    );
  });

  test('Given out-of-range scales, Then the plan clamps to 1–4×', () {
    final low = service.buildExportPlan(
      elements: all,
      options: const CanvasExportOptions(scale: 0),
    );
    final high = service.buildExportPlan(
      elements: all,
      options: const CanvasExportOptions(scale: 10),
    );

    expect(low.scale, CanvasExportOptions.minScale);
    expect(high.scale, CanvasExportOptions.maxScale);
  });

  test('Given transparent or background-off choices, Then transparency is on',
      () {
    expect(
      const CanvasExportOptions(transparentBackground: true)
          .hasTransparentBackground,
      isTrue,
    );
    expect(
      const CanvasExportOptions(includeBackground: false)
          .hasTransparentBackground,
      isTrue,
    );
    expect(
      const CanvasExportOptions().hasTransparentBackground,
      isFalse,
    );
  });

  test('Given file-unsafe titles, Then names are sanitized', () {
    expect(service.sanitizeExportFileName('My Board: Q3/Q4'), 'My_Board__Q3_Q4');
    expect(service.sanitizeExportFileName('   '), 'board');
    expect(service.sanitizeExportFileName('a' * 80).length, 50);
  });
}
