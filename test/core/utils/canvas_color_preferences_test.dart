import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/canvas_color_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves recent colors newest first and de-duplicates them', () async {
    final preferences = await CanvasColorPreferences.instance();

    await preferences.saveRecentColors([
      Colors.red,
      Colors.green,
      Colors.red,
    ]);

    final restored = (await CanvasColorPreferences.instance()).getRecentColors();
    expect(restored.map((color) => color.value), [
      Colors.red.value,
      Colors.green.value,
    ]);
  });

  test('caps the recent list at eight colors', () async {
    final preferences = await CanvasColorPreferences.instance();
    final colors = [for (var i = 0; i < 12; i++) Color(0xFF000000 | i)];

    await preferences.saveRecentColors(colors);

    expect(preferences.getRecentColors(), hasLength(8));
  });

  test('returns an empty list before anything is saved', () async {
    final preferences = await CanvasColorPreferences.instance();
    expect(preferences.getRecentColors(), isEmpty);
  });

  test('stores recents as opaque colours', () async {
    final preferences = await CanvasColorPreferences.instance();

    await preferences.saveRecentColors([
      Colors.deepOrange.withValues(alpha: 0.25),
    ]);

    expect(
      preferences.getRecentColors().single.value,
      Colors.deepOrange.value,
    );
  });

  test('round-trips palettes with deduplicated opaque swatches', () async {
    final preferences = await CanvasColorPreferences.instance();

    await preferences.savePalettes({
      ' Ink ': [
        Colors.black.withValues(alpha: 0.4),
        Colors.black,
        Colors.red,
        Colors.red.withValues(alpha: 0.1),
      ],
    });

    final restored = (await CanvasColorPreferences.instance()).getPalettes();
    expect(restored.keys, ['Ink']);
    expect(restored['Ink']!.map((color) => color.value), [
      Colors.black.value,
      Colors.red.value,
    ]);
    expect(restored['Ink']!.every((color) => color.a == 1), isTrue);
  });

  test('adds, renames and deletes palettes', () async {
    final preferences = await CanvasColorPreferences.instance();

    expect(await preferences.addPalette('Ink'), isTrue);
    expect(await preferences.addPalette('Ink'), isFalse);
    expect(await preferences.addPalette('Pastel'), isTrue);
    expect(await preferences.addPalette('Earth'), isTrue);
    expect(await preferences.renamePalette('Ink', 'Pastel'), isFalse);
    expect(await preferences.renamePalette('Ink', 'Ink Wash'), isTrue);

    var palettes = preferences.getPalettes();
    expect(palettes.keys, ['Ink Wash', 'Pastel', 'Earth']);

    await preferences.deletePalette('Pastel');
    palettes = preferences.getPalettes();
    expect(palettes.keys, ['Ink Wash', 'Earth']);
  });

  test('caps palettes and their swatches', () async {
    final preferences = await CanvasColorPreferences.instance();
    for (var i = 0; i < CanvasColorPreferences.maxPalettes; i++) {
      expect(await preferences.addPalette('Palette $i'), isTrue);
    }
    expect(await preferences.addPalette('Overflow'), isFalse);

    for (var i = 0; i < CanvasColorPreferences.maxPaletteColors; i++) {
      expect(
        await preferences.addColorToPalette('Palette 0', Color(0xFF000000 | i)),
        isTrue,
      );
    }
    expect(
      await preferences.addColorToPalette(
        'Palette 0',
        const Color(0xFF00FF00),
      ),
      isFalse,
    );
    expect(
      preferences.getPalettes()['Palette 0'],
      hasLength(CanvasColorPreferences.maxPaletteColors),
    );
  });

  test('adds a palette colour once and ignores duplicates', () async {
    final preferences = await CanvasColorPreferences.instance();
    await preferences.addPalette('Ink');

    expect(
      await preferences.addColorToPalette('Ink', Colors.blue),
      isTrue,
    );
    expect(
      await preferences.addColorToPalette('Ink', Colors.blue),
      isFalse,
    );
    expect(
      await preferences.addColorToPalette(
        'Missing',
        Colors.blue,
      ),
      isFalse,
    );
    expect(preferences.getPalettes()['Ink']!.single.value, Colors.blue.value);
  });
}
