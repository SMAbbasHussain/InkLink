import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/widgets/color_picker_sheet.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

Widget _harness({
  required ValueChanged<Color?> onResult,
  Color initialColor = Colors.red,
  List<Color> recentColors = const [],
  double initialOpacity = 1.0,
  Map<String, List<Color>> palettes = const {},
  ValueChanged<Map<String, List<Color>>>? onPalettesChanged,
}) {
  return MaterialApp(
    theme: InkTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final picked = await showCanvasColorPicker(
                context,
                initialColor: initialColor,
                recentColors: recentColors,
                initialOpacity: initialOpacity,
                palettes: palettes,
                onPalettesChanged: onPalettesChanged,
              );
              onResult(picked);
            },
            child: const Text('Open picker'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('returns a tapped recent color', (tester) async {
    Color? result;
    await tester.pumpWidget(
      _harness(
        onResult: (value) => result = value,
        recentColors: const [Colors.blue, Colors.green],
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey('recent-0')));
    await _tapVisible(tester, find.text('Use color'));

    expect(result?.value, Colors.blue.value);
  });

  testWidgets('returns the color typed into the hex field', (tester) async {
    Color? result;
    await tester.pumpWidget(_harness(onResult: (value) => result = value));

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('color-hex-field')),
      '00FF00',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Use color'));

    expect(result?.value, const Color(0xFF00FF00).value);
  });

  testWidgets('returns the opacity chosen on the slider', (tester) async {
    Color? result;
    await tester.pumpWidget(_harness(onResult: (value) => result = value));

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final slider = find.byKey(const ValueKey('color-opacity-slider'));
    await tester.ensureVisible(slider);
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
    await tester.pump();
    await _tapVisible(tester, find.text('Use color'));

    expect(result, isNotNull);
    expect(result!.a, lessThan(0.05));
  });

  testWidgets('palette selection returns its colour', (tester) async {
    Color? result;
    await tester.pumpWidget(
      _harness(
        onResult: (value) => result = value,
        palettes: const {
          'Ink': [Colors.teal],
        },
        initialOpacity: 0.5,
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('palette-swatch-Ink-0')),
    );
    await _tapVisible(tester, find.text('Use color'));

    expect(result?.withValues(alpha: 1).value, Colors.teal.value);
    expect(result?.a, 0.5);
  });

  testWidgets('save color adds an opaque swatch to a palette', (tester) async {
    Map<String, List<Color>>? saved;
    await tester.pumpWidget(
      _harness(
        onResult: (_) {},
        initialColor: Colors.green,
        palettes: const {
          'Ink': [Colors.red],
        },
        onPalettesChanged: (palettes) => saved = palettes,
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('palette-save-color')),
    );
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Ink'));
    await tester.pumpAndSettle();

    expect(saved?['Ink']?.map((color) => color.value), [
      Colors.red.value,
      Colors.green.value,
    ]);
    expect(saved?['Ink']?.every((color) => color.a == 1), isTrue);
  });

  testWidgets('cancel returns no color', (tester) async {
    var called = false;
    Color? result;
    await tester.pumpWidget(
      _harness(
        onResult: (value) {
          called = true;
          result = value;
        },
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Cancel'));

    expect(called, isTrue);
    expect(result, isNull);
  });
}
