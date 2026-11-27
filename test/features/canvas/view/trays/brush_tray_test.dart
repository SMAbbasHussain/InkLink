import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/trays/brush_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

Widget _host(BrushTray tray) {
  return MaterialApp(
    theme: InkTheme.light(),
    home: Scaffold(body: Stack(children: [tray])),
  );
}

void main() {
  testWidgets('tapping a preset invokes the preset callback', (tester) async {
    String? selected;
    CanvasToolMode? mode;
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 5,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'solid',
          eraserEraseEverything: false,
          onStrokeWidthChanged: (_) {},
          onColorSelected: (_) {},
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (id) => selected = id,
          onToolModeChanged: (value) => mode = value,
          onEraserEraseEverythingChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final preset = find.byKey(const ValueKey('brush-preset-pencil'));
    await tester.ensureVisible(preset);
    await tester.pumpAndSettle();
    await tester.tap(preset);
    await tester.pumpAndSettle();

    expect(selected, 'pencil');
    expect(mode, CanvasToolMode.doodle);
  });

  testWidgets('highlighter preset asks for highlight mode', (tester) async {
    CanvasToolMode? mode;
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 5,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'solid',
          eraserEraseEverything: false,
          onStrokeWidthChanged: (_) {},
          onColorSelected: (_) {},
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (_) {},
          onToolModeChanged: (value) => mode = value,
          onEraserEraseEverythingChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('brush-preset-highlighter')),
      120,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.tap(find.byKey(const ValueKey('brush-preset-highlighter')));
    await tester.pumpAndSettle();

    expect(mode, CanvasToolMode.highlight);
  });

  testWidgets('stylus pressure switch triggers callback', (tester) async {
    bool? pressureEnabled;
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 4,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'solid',
          eraserEraseEverything: false,
          stylusPressureEnabled: true,
          onStrokeWidthChanged: (_) {},
          onColorSelected: (_) {},
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (_) {},
          onStylusPressureChanged: (v) => pressureEnabled = v,
          onEraserEraseEverythingChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pressureSwitch = find.byKey(const ValueKey('stylusPressureSwitch'));
    await tester.ensureVisible(pressureSwitch);
    await tester.pumpAndSettle();
    await tester.tap(pressureSwitch);
    await tester.pumpAndSettle();

    expect(pressureEnabled, isFalse);
  });

  testWidgets(
    'Given a stabilizer slider, When dragged, Then the value updates',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      double? strength;
      await tester.pumpWidget(
        _host(
          BrushTray(
            isOpen: true,
            strokeWidth: 5,
            selectedColor: Colors.black,
            brushOpacity: 1,
            brushType: 'solid',
            eraserEraseEverything: false,
            onStrokeWidthChanged: (_) {},
            onColorSelected: (_) {},
            onOpacityChanged: (_) {},
            onBrushPresetSelected: (_) {},
            onEraserEraseEverythingChanged: (_) {},
            onStabilizerChanged: (value) => strength = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('brush-stabilizer'));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(finder));
      await tester.pumpAndSettle();
      expect(strength, closeTo(0.45, 0.05));
    },
  );

  testWidgets('Given live stabilization, Then post-smoothing is disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 5,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'solid',
          eraserEraseEverything: false,
          stabilizerStrength: 0.5,
          smoothDoodlesEnabled: true,
          onStrokeWidthChanged: (_) {},
          onColorSelected: (_) {},
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (_) {},
          onEraserEraseEverythingChanged: (_) {},
          onSmoothDoodlesChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('brush-smooth-after')),
    );
    expect(toggle.onChanged, isNull);
    expect(toggle.value, isFalse);
  });

  testWidgets('Given eraser mode, Then brush-only input controls are hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 5,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'eraser',
          eraserEraseEverything: false,
          onStrokeWidthChanged: (_) {},
          onColorSelected: (_) {},
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (_) {},
          onEraserEraseEverythingChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brush-stabilizer')), findsNothing);
    expect(find.byKey(const ValueKey('brush-smooth-after')), findsNothing);
  });

  testWidgets('stroke width slider uses preset min and max bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 8,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'marker',
          eraserEraseEverything: false,
          onStrokeWidthChanged: (_) {},
          onColorSelected: (_) {},
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (_) {},
          onEraserEraseEverythingChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(slider.min, greaterThanOrEqualTo(2.0));
    expect(slider.max, greaterThan(20.0));
  });

  testWidgets('toggles between recent colors and palettes and between palettes', (
    tester,
  ) async {
    Color? picked;
    await tester.pumpWidget(
      _host(
        BrushTray(
          isOpen: true,
          strokeWidth: 5,
          selectedColor: Colors.black,
          brushOpacity: 1,
          brushType: 'solid',
          eraserEraseEverything: false,
          recentColors: const [Colors.red],
          palettes: const {
            'Warm': [Colors.orange],
            'Cool': [Colors.blue],
          },
          onStrokeWidthChanged: (_) {},
          onColorSelected: (c) => picked = c,
          onOpacityChanged: (_) {},
          onBrushPresetSelected: (_) {},
          onEraserEraseEverythingChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom Color'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('brush-preset-solid')),
        matching: find.textContaining('px ·'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('brush-colors-palettes-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brush-palette-tab-Warm')), findsOneWidget);
    expect(find.byKey(const ValueKey('brush-palette-tab-Cool')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('brush-palette-tab-Cool')));
    await tester.pumpAndSettle();

    // Tap the blue swatch from the Cool palette.
    final coolSwatch = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == Colors.blue,
    );
    await tester.tap(coolSwatch.first);
    await tester.pumpAndSettle();
    expect(picked, Colors.blue);
  });
}
