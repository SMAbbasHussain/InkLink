import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/app_snackbar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSnackBar', () {
    test('defaultDuration is 5 seconds', () {
      expect(AppSnackBar.defaultDuration, equals(const Duration(seconds: 5)));
    });

    test('colors are green for success and red for error', () {
      expect(AppSnackBar.successColor, equals(const Color(0xFF16A34A)));
      expect(AppSnackBar.errorColor, equals(const Color(0xFFDC2626)));
    });

    testWidgets('shows snackbar with 5-second duration and dismisses automatically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showMessage(context, 'Test popup message');
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      // Tap button to show snackbar
      await tester.tap(find.text('Show'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300)); // Finish entry animation

      expect(find.text('Test popup message'), findsOneWidget);

      // Advance past 5 seconds
      await tester.pump(const Duration(seconds: 5, milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500)); // Finish exit animation

      expect(find.text('Test popup message'), findsNothing);
    });

    testWidgets('showSuccess renders green snackbar with check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showSuccess(context, 'Action completed successfully!');
                  },
                  child: const Text('Success'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Action completed successfully!'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, equals(const Color(0xFF16A34A)));

      // Advance past 5s
      await tester.pump(const Duration(seconds: 5, milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Action completed successfully!'), findsNothing);
    });

    testWidgets('showError renders red snackbar with alert icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showError(context, 'Operation failed. Please try again.');
                  },
                  child: const Text('Error'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Operation failed. Please try again.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBar.backgroundColor, equals(const Color(0xFFDC2626)));

      // Advance past 5s
      await tester.pump(const Duration(seconds: 5, milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Operation failed. Please try again.'), findsNothing);
    });

    testWidgets('removes previous snackbar immediately when new one is shown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => AppSnackBar.showSuccess(context, 'First message'),
                      child: const Text('First'),
                    ),
                    ElevatedButton(
                      onPressed: () => AppSnackBar.showError(context, 'Second message'),
                      child: const Text('Second'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('First'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First message'), findsOneWidget);

      // Show second message immediately
      await tester.tap(find.text('Second'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First message'), findsNothing);
      expect(find.text('Second message'), findsOneWidget);

      // Advance 5.5s to clear
      await tester.pump(const Duration(seconds: 5, milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Second message'), findsNothing);
    });
  });
}
