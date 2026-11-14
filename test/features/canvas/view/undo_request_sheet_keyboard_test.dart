import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/widgets/undo_request_sheet.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

void main() {
  Future<void> pumpHarness(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const keyboardHeight = 420.0;
    // The injected MediaQuery wraps the navigator, so the modal sheet route
    // sees the keyboard inset the same way the canvas does.
    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(900, 1200),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showUndoRequestSendSheet(
                  context,
                  targetVersion: 7,
                  stopLabel: 'Before these changes (v7)',
                  elementCount: 3,
                  canSend: true,
                  onSubmit: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('reason field stays above the keyboard and can be dismissed', (
    tester,
  ) async {
    await pumpHarness(tester);

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    // With a 420px keyboard, the reason field — and the send button below it
    // — must sit above the keyboard, not behind it.
    final keyboardTop = 1200 - 420.0;
    expect(
      tester.getBottomLeft(field).dy,
      lessThanOrEqualTo(keyboardTop - 56),
    );

    // There is a visible way to dismiss the keyboard.
    final dismiss = find.byTooltip('Hide keyboard');
    expect(dismiss, findsOneWidget);

    // Focus the field, then hide the keyboard with that button.
    await tester.tap(field);
    await tester.pump();
    final focusedNode = FocusManager.instance.primaryFocus;
    expect(focusedNode, isNotNull);
    expect(focusedNode!.descendants, isEmpty, reason: 'the field is focused');

    await tester.tap(dismiss);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus,
      isNot(same(focusedNode)),
      reason: 'the keyboard dropped',
    );
  });

  testWidgets('tapping another part of the sheet drops the keyboard', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final focusedNode = FocusManager.instance.primaryFocus;
    expect(focusedNode, isNotNull);
    expect(focusedNode!.descendants, isEmpty, reason: 'the field is focused');

    // Tapping the desired-state summary (a plain area of the sheet) drops
    // the keyboard; the summary stays readable.
    await tester.tap(find.text('Restore to version 7'));
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus,
      isNot(same(focusedNode)),
      reason: 'the keyboard dropped',
    );
    expect(find.text('Restore to version 7'), findsOneWidget);
  });
}
