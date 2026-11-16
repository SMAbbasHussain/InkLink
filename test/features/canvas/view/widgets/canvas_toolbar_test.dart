import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/widgets/canvas_toolbar.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: InkTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('CanvasToolbar', () {
    testWidgets('every primary tool is reachable in one tap', (tester) async {
      final selected = <CanvasToolMode>[];
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: true,
            onToolSelected: selected.add,
            onStickyNote: () {},
            onImage: () {},
            onMore: () {},
          ),
        ),
      );

      for (final entry in const <(String, CanvasToolMode)>[
        ('Pen', CanvasToolMode.doodle),
        ('Highlight', CanvasToolMode.highlight),
        ('Eraser', CanvasToolMode.eraser),
        ('Shape', CanvasToolMode.shape),
        ('Arrow', CanvasToolMode.arrow),
        ('Text', CanvasToolMode.text),
      ]) {
        await tester.tap(find.text(entry.$1));
        await tester.pump();
        expect(selected.last, entry.$2, reason: '${entry.$1} tool');
      }

      await tester.tap(find.text('Select'));
      await tester.pump();
      expect(selected.last, CanvasToolMode.select);
    });

    testWidgets('frame tool is one tap for editors and hidden for viewers',
        (tester) async {
      var frames = 0;
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: true,
            onToolSelected: (_) {},
            onStickyNote: () {},
            onFrame: () => frames++,
            onImage: () {},
            onMore: () {},
          ),
        ),
      );
      await tester.tap(find.text('Frame'));
      await tester.pump();
      expect(frames, 1);

      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: false,
            onToolSelected: (_) {},
            onStickyNote: () {},
            onFrame: () => frames++,
            onImage: () {},
            onMore: () {},
          ),
        ),
      );
      await tester.tap(find.text('Frame'));
      await tester.pump();
      expect(frames, 1, reason: 'viewers cannot add frames');
    });

    testWidgets('viewer sees edit tools disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: false,
            onToolSelected: (_) => taps++,
            onStickyNote: () {},
            onImage: () {},
            onMore: () {},
          ),
        ),
      );

      // Tapping a disabled tool must not dispatch anything.
      await tester.tap(find.text('Pen'));
      await tester.pump();
      expect(taps, 0);

      // Select remains available for inspecting a board.
      await tester.tap(find.text('Select'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('hand tool is one tap for editors and viewers', (tester) async {
      final selected = <CanvasToolMode>[];
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: true,
            onToolSelected: selected.add,
            onStickyNote: () {},
            onImage: () {},
            onMore: () {},
          ),
        ),
      );
      await tester.tap(find.text('Hand'));
      await tester.pump();
      expect(selected.last, CanvasToolMode.hand);

      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: false,
            onToolSelected: selected.add,
            onStickyNote: () {},
            onImage: () {},
            onMore: () {},
          ),
        ),
      );
      await tester.tap(find.text('Hand'));
      await tester.pump();
      expect(selected.last, CanvasToolMode.hand,
          reason: 'viewers can still pan');
    });
  });
}
