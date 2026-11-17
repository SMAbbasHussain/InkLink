import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_toolbar_action.dart';
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
    testWidgets('default bar shows core useful subset and leaves rest for tray', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: true,
            onToolSelected: (_) {},
            onStickyNote: () {},
            onMore: () {},
          ),
        ),
      );

      for (final label in const [
        'Select',
        'Hand',
        'Pen',
        'Eraser',
        'Shape',
        'Sticky',
        'Text',
        'More',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      // Moved to tray by default:
      for (final label in const ['Highlight', 'Fill', 'Layers', 'Templates', 'Table']) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('every custom action is reachable in chosen order', (tester) async {
      final selectedTools = <CanvasToolMode>[];
      final selectedActions = <CanvasToolbarAction>[];

      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: true,
            actions: CanvasToolbarAction.values,
            onToolSelected: selectedTools.add,
            onActionSelected: selectedActions.add,
            onMore: () {},
          ),
        ),
      );

      for (final action in [
        CanvasToolbarAction.select,
        CanvasToolbarAction.hand,
        CanvasToolbarAction.pen,
        CanvasToolbarAction.layers,
        CanvasToolbarAction.templates,
      ]) {
        final labelFinder = find.text(action.shortLabel);
        await tester.ensureVisible(labelFinder);
        await tester.tap(labelFinder);
        await tester.pump();
        expect(selectedActions.last, action);
      }
    });

    testWidgets('1 or 2 pinned items shrink-wraps cleanly without stretching or breaking', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.doodle,
            canEdit: true,
            actions: const [CanvasToolbarAction.pen],
            onToolSelected: (_) {},
            onMore: () {},
          ),
        ),
      );

      final barSize1 = tester.getSize(find.byType(CanvasToolbar));
      // 2 buttons (Pen + More) * 44 + 12 horizontal padding = 100px
      expect(barSize1.width, lessThan(140));
      expect(barSize1.height, 56);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: true,
            actions: const [
              CanvasToolbarAction.pen,
              CanvasToolbarAction.layers,
            ],
            onToolSelected: (_) {},
            onMore: () {},
          ),
        ),
      );

      final barSize2 = tester.getSize(find.byType(CanvasToolbar));
      // 3 buttons (Pen + Layers + More) * 44 + 12 horizontal padding = 144px
      expect(barSize2.width, lessThan(180));
      expect(barSize2.height, 56);
      expect(tester.takeException(), isNull);
    });

    testWidgets('viewer sees edit tools disabled while read-only tools stay active', (
      tester,
    ) async {
      final invoked = <CanvasToolbarAction>[];
      await tester.pumpWidget(
        _wrap(
          CanvasToolbar(
            activeTool: CanvasToolMode.select,
            canEdit: false,
            actions: const [
              CanvasToolbarAction.select,
              CanvasToolbarAction.hand,
              CanvasToolbarAction.layers,
              CanvasToolbarAction.pen,
              CanvasToolbarAction.templates,
            ],
            onToolSelected: (_) {},
            onActionSelected: invoked.add,
            onMore: () {},
          ),
        ),
      );

      await tester.tap(find.text('Pen'));
      await tester.tap(find.text('Templates'));
      await tester.pump();
      expect(invoked, isEmpty);

      await tester.tap(find.text('Select'));
      await tester.tap(find.text('Hand'));
      await tester.tap(find.text('Layers'));
      await tester.pump();
      expect(invoked, [
        CanvasToolbarAction.select,
        CanvasToolbarAction.hand,
        CanvasToolbarAction.layers,
      ]);
    });
  });
}
