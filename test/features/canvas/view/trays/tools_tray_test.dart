import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/trays/tools_tray.dart';
import 'package:inklink/features/canvas/view/widgets/sliding_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Widget buildTestWidget({
    required bool isOpen,
    bool canEdit = true,
    VoidCallback? onClearAll,
    VoidCallback? onUndo,
    VoidCallback? onRedo,
    VoidCallback? onCanvasSettings,
    VoidCallback? onHistory,
    VoidCallback? onRequestUndo,
    VoidCallback? onExport,
  }) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: Scaffold(
        body: Stack(
          children: [
            ToolsTray(
              isOpen: isOpen,
              canEdit: canEdit,
              onUndo: onUndo ?? () {},
              onRedo: onRedo ?? () {},
              onClearAll: onClearAll,
              onCanvasSettings: onCanvasSettings,
              onHistory: onHistory,
              onRequestUndo: onRequestUndo,
              onExport: onExport,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('ToolsTray sits on bottom-left and shows Clear All when provided', (
    tester,
  ) async {
    var clearAllCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onClearAll: () => clearAllCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    final tray = tester.widget<SlidingTray>(find.byType(SlidingTray));
    expect(tray.direction, TrayDirection.left);
    expect(find.text('Board & History'), findsOneWidget);
    expect(find.text('Clear All'), findsOneWidget);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    expect(clearAllCalled, isTrue);
  });

  testWidgets('ToolsTray hides Clear All button when onClearAll is null', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(isOpen: true, onClearAll: null));
    await tester.pumpAndSettle();

    expect(find.text('Clear All'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
  });

  testWidgets('ToolsTray shows History and Canvas Settings for board owners', (
    tester,
  ) async {
    var historyCalled = false;
    var settingsCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onCanvasSettings: () => settingsCalled = true,
        onClearAll: () {},
        onHistory: () => historyCalled = true,
        onExport: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canvas Settings'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.ensureVisible(find.text('Canvas Settings'));
    await tester.tap(find.text('Canvas Settings'));
    await tester.pumpAndSettle();
    expect(settingsCalled, isTrue);

    await tester.ensureVisible(find.text('History'));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(historyCalled, isTrue);
  });

  testWidgets('ToolsTray shows Request undo for editors and invokes callback', (
    tester,
  ) async {
    var requestUndoCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onRequestUndo: () => requestUndoCalled = true,
        onExport: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request undo'), findsOneWidget);
    expect(find.text('History'), findsNothing);

    await tester.ensureVisible(find.text('Request undo'));
    await tester.tap(find.text('Request undo'));
    await tester.pumpAndSettle();
    expect(requestUndoCalled, isTrue);
  });

  testWidgets('ToolsTray hides edit actions when canEdit is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        canEdit: false,
        onClearAll: () {},
        onCanvasSettings: () {},
        onRequestUndo: () {},
        onExport: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsNothing);
    expect(find.text('Redo'), findsNothing);
    expect(find.text('Canvas Settings'), findsNothing);
    expect(find.text('Clear All'), findsNothing);
    expect(find.text('Request undo'), findsNothing);
    expect(find.text('Export & Share'), findsOneWidget);
  });
}
