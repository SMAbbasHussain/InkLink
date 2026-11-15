import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/models/brush_preset.dart';

void main() {
  group('brush preset lookup', () {
    test('exposes the required painter families', () {
      expect(
        brushPresets.map((preset) => preset.id),
        containsAll(<String>[
          'solid',
          'pencil',
          'textured',
          'marker',
          'highlighter',
          'watercolor',
          'airbrush',
          'charcoal',
        ]),
      );
    });

    test('known ids resolve to their preset', () {
      expect(brushPresetFor('watercolor'), watercolorPreset);
      expect(brushPresetFor('marker'), markerPreset);
      expect(brushPresetFor('highlighter'), highlighterPreset);
      expect(brushPresetFor('airbrush'), airbrushPreset);
      expect(brushPresetFor('charcoal'), charcoalPreset);
      expect(brushPresetFor('pen'), penPreset);
    });

    test('unknown ids fall back to the pen', () {
      expect(brushPresetFor('future-brush'), penPreset);
      expect(brushPresetFor('eraser'), penPreset);
    });
  });

  group('resolved brush style', () {
    test('solid keeps the entered width and opacity', () {
      final style = resolveBrushStyle(
        brushType: 'solid',
        strokeWidth: 5,
        strokeOpacity: 1,
      );
      expect(style.width, 5);
      expect(style.opacity, 1);
      expect(style.blurSigma, 0);
      expect(style.texture, BrushTexture.none);
      expect(style.cap, StrokeCap.round);
      expect(style.blendMode, BlendMode.srcOver);
    });

    test('watercolor matches the painter wash profile', () {
      final style = resolveBrushStyle(
        brushType: 'watercolor',
        strokeWidth: 8,
        strokeOpacity: 0.9,
      );
      expect(style.width, 10);
      expect(style.opacity, 0.405);
      expect(style.blurSigma, 2.5);
      expect(style.texture, BrushTexture.wash);
    });

    test('textured keeps its historical width and opacity scale', () {
      final style = resolveBrushStyle(
        brushType: 'textured',
        strokeWidth: 5,
        strokeOpacity: 1,
      );
      expect(style.width, closeTo(4.75, 1e-9));
      expect(style.opacity, 0.8);
    });

    test('pencil is narrower and grain-labeled', () {
      final style = resolveBrushStyle(
        brushType: 'pencil',
        strokeWidth: 5,
        strokeOpacity: 1,
      );
      expect(style.width, 4);
      expect(style.opacity, 1);
      expect(style.texture, BrushTexture.grain);
    });

    test('highlighter and marker keep their exported values', () {
      final highlighter = resolveBrushStyle(
        brushType: 'highlighter',
        strokeWidth: 10,
        strokeOpacity: 0.8,
      );
      expect(highlighter.width, 25);
      expect(highlighter.opacity, 0.28);
      expect(highlighter.cap, StrokeCap.square);
      expect(highlighter.blendMode, BlendMode.multiply);

      final marker = resolveBrushStyle(
        brushType: 'marker',
        strokeWidth: 10,
        strokeOpacity: 0.8,
      );
      expect(marker.width, 14);
      expect(marker.opacity, 0.72);
    });

    test('airbrush and charcoal resolve with expected properties', () {
      final airbrush = resolveBrushStyle(
        brushType: 'airbrush',
        strokeWidth: 10,
        strokeOpacity: 0.5,
      );
      expect(airbrush.blurSigma, greaterThan(0));
      expect(airbrush.texture, BrushTexture.wash);
      expect(airbrush.spacing, airbrushPreset.spacing);

      final charcoal = resolveBrushStyle(
        brushType: 'charcoal',
        strokeWidth: 8,
        strokeOpacity: 0.9,
      );
      expect(charcoal.jitter, greaterThan(0));
      expect(charcoal.texture, BrushTexture.grain);
      expect(charcoal.spacing, charcoalPreset.spacing);
    });

    test('presets declare valid minWidth and maxWidth bounds', () {
      for (final preset in brushPresets) {
        expect(preset.minWidth, greaterThan(0));
        expect(preset.maxWidth, greaterThanOrEqualTo(preset.minWidth));
        expect(preset.defaultWidth, greaterThanOrEqualTo(preset.minWidth));
        expect(preset.defaultWidth, lessThanOrEqualTo(preset.maxWidth));
        expect(preset.spacing, greaterThan(0));
      }
    });

    test('unknown persisted type renders with pen semantics', () {
      final style = resolveBrushStyle(
        brushType: 'mystery',
        strokeWidth: 7,
        strokeOpacity: 0.5,
      );
      expect(style.width, 7);
      expect(style.opacity, 0.5);
      expect(style.texture, BrushTexture.none);
    });
  });
}
