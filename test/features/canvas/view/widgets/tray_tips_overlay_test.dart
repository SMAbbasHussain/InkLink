import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/widgets/tray_tips_overlay.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('TrayTipsOverlay renders all tray tips, quick access bar info, and dismisses on tap', (
    tester,
  ) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: Scaffold(
          body: Stack(
            children: [
              TrayTipsOverlay(
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify edge tray tips
    expect(find.text('Members & Chat'), findsOneWidget);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Board & History'), findsOneWidget);
    expect(find.text('Canvas Tools'), findsOneWidget);

    // Verify Quick Access Bar highlight
    expect(find.text('Quick Access Bar'), findsOneWidget);
    expect(
      find.text('Tap Pen for brush & color • Tap ••• to customize bottom bar'),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons.panelBottom), findsOneWidget);

    // Verify main card
    expect(find.text('Canvas Gestures & Trays'), findsOneWidget);

    // Tap 'Got it'
    await tester.tap(find.text('Got it'));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}
