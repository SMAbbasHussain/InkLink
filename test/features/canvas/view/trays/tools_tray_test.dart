import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/trays/tools_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Widget buildTestWidget({
    required bool isOpen,
    bool canEdit = true,
    VoidCallback? onClearAll,
    VoidCallback? onUndo,
    VoidCallback? onRedo,
    VoidCallback? onAddStickyNote,
    VoidCallback? onAddConnector,
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
              onAddStickyNote: onAddStickyNote,
              onAddConnector: onAddConnector,
              onExport: onExport,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('ToolsTray shows Clear All button when onClearAll is provided', (tester) async {
    var clearAllCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onClearAll: () {
          clearAllCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clear All'), findsOneWidget);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(clearAllCalled, isTrue);
  });

  testWidgets('ToolsTray hides Clear All button when onClearAll is null', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        onClearAll: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clear All'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
  });

  testWidgets('ToolsTray hides edit actions when canEdit is false', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isOpen: true,
        canEdit: false,
        onClearAll: () {},
        onAddStickyNote: () {},
        onAddConnector: () {},
        onExport: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsNothing);
    expect(find.text('Redo'), findsNothing);
    expect(find.text('Sticky Note'), findsNothing);
    expect(find.text('Connector / Link'), findsNothing);
    expect(find.text('Clear All'), findsNothing);
    expect(find.text('Export & Share'), findsOneWidget);
  });
}

