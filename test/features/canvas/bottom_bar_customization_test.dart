import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/canvas_toolbar_preferences.dart';
import 'package:inklink/domain/models/canvas/canvas_toolbar_action.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/bottom_bar_customizer_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CanvasToolbarAction & CanvasToolbarPreferences', () {
    test('decodeIds returns defaults when null, deduplicates, and computes off-bar actions', () {
      expect(
        CanvasToolbarAction.decodeIds(null),
        CanvasToolbarAction.defaultBottomBarActions,
      );

      final parsed = CanvasToolbarAction.decodeIds([
        'layers',
        'templates',
        'layers', // duplicate ignored
        'unknown_tool', // invalid ignored
        'pen',
      ]);
      expect(parsed, [
        CanvasToolbarAction.layers,
        CanvasToolbarAction.templates,
        CanvasToolbarAction.pen,
      ]);

      final offBar = CanvasToolbarAction.actionsNotOnBar(parsed);
      expect(offBar, isNot(contains(CanvasToolbarAction.layers)));
      expect(offBar, isNot(contains(CanvasToolbarAction.templates)));
      expect(offBar, isNot(contains(CanvasToolbarAction.pen)));
      expect(offBar.length, CanvasToolbarAction.values.length - 3);
    });

    test('CanvasToolbarPreferences saves and restores ordered actions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = CanvasToolbarPreferences(prefs: prefs);

      expect(
        await store.getBottomBarActions(),
        CanvasToolbarAction.defaultBottomBarActions,
      );

      const custom = [
        CanvasToolbarAction.templates,
        CanvasToolbarAction.layers,
        CanvasToolbarAction.pen,
      ];
      await store.setBottomBarActions(custom);

      expect(await store.getBottomBarActions(), custom);
    });
  });

  group('BottomBarCustomizerSheet', () {
    testWidgets('adds, reorders, resets, and saves custom bottom bar actions', (
      tester,
    ) async {
      List<CanvasToolbarAction>? saved;

      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    saved = await showBottomBarCustomizerSheet(
                      context,
                      initialActions: const [
                        CanvasToolbarAction.select,
                        CanvasToolbarAction.pen,
                      ],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Customize Bottom Bar'), findsOneWidget);
      expect(find.text('Preview (2 pinned)'), findsOneWidget);

      // Add Layers from "IN BOTTOM-RIGHT TRAY" list (highlight/eraser/etc. come first):
      final listScrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Layers'),
        150,
        scrollable: listScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Layers').last);
      await tester.pumpAndSettle();

      expect(find.text('Preview (3 pinned)'), findsOneWidget);

      // Scroll back up to remove Pen (second item):
      await tester.scrollUntilVisible(
        find.text('ON BOTTOM BAR (3)'),
        -150,
        scrollable: listScrollable,
      );
      await tester.pumpAndSettle();
      final removeTooltips = find.byTooltip('Remove from bottom bar');
      expect(removeTooltips, findsNWidgets(3));
      await tester.tap(removeTooltips.at(1));
      await tester.pumpAndSettle();
      expect(find.text('Preview (2 pinned)'), findsOneWidget);

      // Reorder Layers above Select using move-up button:
      final moveUpButtons = find.byTooltip('Move up');
      await tester.tap(moveUpButtons.at(1));
      await tester.pumpAndSettle();

      // Save custom bar [Layers, Select]:
      await tester.tap(find.text('Save bar'));
      await tester.pumpAndSettle();

      expect(saved, [CanvasToolbarAction.layers, CanvasToolbarAction.select]);
    });
  });
}
