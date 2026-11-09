import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/trays/tools_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Widget buildTestWidget({
    required bool isOpen,
    VoidCallback? onClearAll,
    VoidCallback? onUndo,
    VoidCallback? onRedo,
  }) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: Scaffold(
        body: Stack(
          children: [
            ToolsTray(
              isOpen: isOpen,
              onUndo: onUndo ?? () {},
              onRedo: onRedo ?? () {},
              onClearAll: onClearAll,
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
}

