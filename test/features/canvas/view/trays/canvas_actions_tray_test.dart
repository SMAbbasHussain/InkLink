import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_toolbar_action.dart';
import 'package:inklink/features/canvas/view/trays/canvas_actions_tray.dart';
import 'package:inklink/features/canvas/view/widgets/sliding_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Widget buildTestWidget({
    required bool isOpen,
    bool canEdit = true,
    List<CanvasToolbarAction> bottomBarActions =
        CanvasToolbarAction.defaultBottomBarActions,
    required ValueChanged<CanvasToolbarAction> onActionSelected,
    VoidCallback? onCustomizeBottomBar,
  }) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: Scaffold(
        body: Stack(
          children: [
            CanvasActionsTray(
              isOpen: isOpen,
              canEdit: canEdit,
              bottomBarActions: bottomBarActions,
              onActionSelected: onActionSelected,
              onCustomizeBottomBar: onCustomizeBottomBar,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('CanvasActionsTray sits on bottom-right and shows all customizable tools without shapes grid or board controls', (
    tester,
  ) async {
    final tapped = <CanvasToolbarAction>[];
    var customized = false;

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onActionSelected: tapped.add,
        onCustomizeBottomBar: () => customized = true,
      ),
    );
    await tester.pumpAndSettle();

    final tray = tester.widget<SlidingTray>(find.byType(SlidingTray));
    expect(tray.direction, TrayDirection.right);

    expect(find.text('Canvas Tools'), findsOneWidget);
    expect(find.text('MORE TOOLS'), findsOneWidget);
    expect(find.text('ON BOTTOM BAR'), findsOneWidget);

    // Authoritative controls stay in bottom-left ToolsTray, not here:
    expect(find.text('History'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Clear All'), findsNothing);

    // Shapes grid options are in the popup, not embedded in the tray:
    expect(find.text('Semicircle'), findsNothing);
    expect(find.text('Pentagon'), findsNothing);

    // Off-bar & on-bar canvas actions are all present:
    expect(find.text('Layers'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Table'), findsOneWidget);

    await tester.tap(find.text('Layers'));
    await tester.pump();
    expect(tapped.last, CanvasToolbarAction.layers);

    await tester.tap(find.byTooltip('Customize bottom bar'));
    await tester.pump();
    expect(customized, isTrue);
  });

  testWidgets('CanvasActionsTray section grids ignore MediaQuery top padding gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 48)),
        child: MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                CanvasActionsTray(
                  isOpen: true,
                  onActionSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelRect = tester.getRect(find.text('MORE TOOLS'));
    final gridRect = tester.getRect(find.byType(GridView).first);
    // Gap between MORE TOOLS header and the GridView is exactly SizedBox(height: 6),
    // not inflated by the 48px MediaQuery top padding.
    expect(gridRect.top - labelRect.bottom, closeTo(6.0, 0.5));
  });

  testWidgets('CanvasActionsTray disables edit actions while keeping read-only actions active for viewers', (
    tester,
  ) async {
    final tapped = <CanvasToolbarAction>[];

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        canEdit: false,
        onActionSelected: tapped.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Templates'));
    await tester.pump();
    expect(tapped, isEmpty);

    await tester.tap(find.text('Layers'));
    await tester.pump();
    expect(tapped, [CanvasToolbarAction.layers]);
  });
}
