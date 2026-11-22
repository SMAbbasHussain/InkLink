import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_board_settings.dart';

void main() {
  group('CanvasBoardSettings', () {
    test('Given custom settings, Then the payload round-trips every field', () {
      const settings = CanvasBoardSettings(
        backgroundColor: Color(0xFF1E293B),
        backgroundPattern: CanvasBackgroundPattern.grid,
        patternSpacing: 48,
        pageBoundsEnabled: true,
        pageWidth: 1000,
        pageHeight: 700,
        inkSpillEnabled: true,
      );

      final parsed = CanvasBoardSettings.fromMap(settings.toMap());

      expect(parsed, settings);
      expect(parsed.inkSpillEnabled, isTrue);
      expect(parsed.toMap()['type'], CanvasBoardSettings.crdtType);
    });

    test('Given default settings, Then inkSpillEnabled is off by default', () {
      expect(CanvasBoardSettings.defaults.inkSpillEnabled, isFalse);
      expect(CanvasBoardSettings.fromMap(const {}).inkSpillEnabled, isFalse);
    });

    test('Given legacy or malformed data, Then defaults and clamps apply', () {
      final legacy = CanvasBoardSettings.fromMap(const {});
      expect(legacy, CanvasBoardSettings.defaults);

      final malformed = CanvasBoardSettings.fromMap(const {
        'pattern': 'not-a-pattern',
        'patternSpacing': 2,
        'pageWidth': -5,
        'pageHeight': 999999,
        'pageBoundsEnabled': 'yes',
      });
      expect(malformed.backgroundPattern, CanvasBackgroundPattern.none);
      expect(malformed.patternSpacing, 8);
      expect(malformed.pageWidth, 100);
      expect(malformed.pageHeight, 10000);
      expect(malformed.pageBoundsEnabled, isFalse);
      expect(malformed.backgroundColor, CanvasBoardSettings.defaultBackground);
    });

    test('Given a copy, Then unchanged fields survive', () {
      final settings = CanvasBoardSettings.defaults.copyWith(
        backgroundPattern: CanvasBackgroundPattern.dots,
      );
      expect(settings.backgroundPattern, CanvasBackgroundPattern.dots);
      expect(settings.backgroundColor, CanvasBoardSettings.defaultBackground);
      expect(settings.pageWidth, CanvasBoardSettings.defaultPageWidth);
    });

    test('Given page presets, Then every preset has a positive box', () {
      expect(CanvasBoardSettings.pagePresets, isNotEmpty);
      for (final (name, width, height) in CanvasBoardSettings.pagePresets) {
        expect(name, isNotEmpty);
        expect(width, greaterThan(0));
        expect(height, greaterThan(0));
      }
    });
  });
}
