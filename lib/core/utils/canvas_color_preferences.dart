import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the colours recently chosen for the canvas brush and the user's
/// saved artist palettes so both survive restarts.
class CanvasColorPreferences {
  CanvasColorPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  /// Convenience accessor for callers that do not inject preferences.
  static Future<CanvasColorPreferences> instance() async =>
      CanvasColorPreferences(prefs: await SharedPreferences.getInstance());

  static const String _recentColorsKey = 'canvas_recent_colors';
  static const String _palettesKey = 'canvas_color_palettes';
  static const int maxRecentColors = 8;
  static const int maxPalettes = 6;
  static const int maxPaletteColors = 12;

  List<Color> getRecentColors() {
    final stored = _prefs.getStringList(_recentColorsKey) ?? const <String>[];
    final colors = <Color>[];
    for (final entry in stored) {
      final value = int.tryParse(entry, radix: 16);
      if (value == null) continue;
      final color = Color(value);
      if (colors.any((existing) => existing.value == color.value)) continue;
      colors.add(color);
      if (colors.length == maxRecentColors) break;
    }
    return colors;
  }

  Future<void> saveRecentColors(List<Color> colors) {
    final unique = <Color>[];
    for (final color in colors) {
      final opaque = color.withValues(alpha: 1);
      if (unique.any((existing) => existing.value == opaque.value)) continue;
      unique.add(opaque);
      if (unique.length == maxRecentColors) break;
    }
    return _prefs.setStringList(
      _recentColorsKey,
      unique
          .map((color) => color.value.toRadixString(16).padLeft(8, '0'))
          .toList(growable: false),
    );
  }

  /// Saved palettes in insertion order. Palettes and their swatches are
  /// de-duplicated and capped so a corrupt or hand-edited store cannot grow
  /// the picker without bound.
  Map<String, List<Color>> getPalettes() {
    final raw = _prefs.getString(_palettesKey);
    if (raw == null || raw.isEmpty) return <String, List<Color>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, List<Color>>{};
      final palettes = <String, List<Color>>{};
      for (final entry in decoded.entries) {
        if (palettes.length == maxPalettes) break;
        final name = entry.key.trim();
        if (name.isEmpty || palettes.containsKey(name)) continue;
        final values = entry.value;
        if (values is! List) continue;
        palettes[name] = _normalizePaletteColors(values);
      }
      return palettes;
    } catch (_) {
      return <String, List<Color>>{};
    }
  }

  Future<void> savePalettes(Map<String, List<Color>> palettes) {
    final normalized = <String, List<String>>{};
    for (final entry in palettes.entries) {
      if (normalized.length == maxPalettes) break;
      final name = entry.key.trim();
      if (name.isEmpty || normalized.containsKey(name)) continue;
      normalized[name] = [
        for (final color in _normalizePaletteColors(entry.value))
          color.value.toRadixString(16).padLeft(8, '0'),
      ];
    }
    return _prefs.setString(_palettesKey, jsonEncode(normalized));
  }

  /// Adds an empty palette. Returns false when the name is blank, already in
  /// use, or the palette cap has been reached.
  Future<bool> addPalette(String name) async {
    final trimmed = name.trim();
    final palettes = getPalettes();
    if (trimmed.isEmpty ||
        palettes.containsKey(trimmed) ||
        palettes.length >= maxPalettes) {
      return false;
    }
    palettes[trimmed] = <Color>[];
    await savePalettes(palettes);
    return true;
  }

  /// Renames a palette in place. Refuses blank names, collisions and unknown
  /// palettes so callers can report a precise error.
  Future<bool> renamePalette(String oldName, String newName) async {
    final trimmed = newName.trim();
    final palettes = getPalettes();
    if (!palettes.containsKey(oldName) ||
        trimmed.isEmpty ||
        (trimmed != oldName && palettes.containsKey(trimmed))) {
      return false;
    }
    if (trimmed == oldName) return true;
    final renamed = <String, List<Color>>{};
    for (final entry in palettes.entries) {
      renamed[entry.key == oldName ? trimmed : entry.key] = entry.value;
    }
    await savePalettes(renamed);
    return true;
  }

  Future<void> deletePalette(String name) async {
    final palettes = getPalettes();
    if (!palettes.containsKey(name)) return;
    palettes.remove(name);
    await savePalettes(palettes);
  }

  /// Appends [color] to [name] as an opaque swatch. Returns false when the
  /// palette is missing or full, or when the colour is already present.
  Future<bool> addColorToPalette(String name, Color color) async {
    final palettes = getPalettes();
    final colors = palettes[name];
    if (colors == null) return false;
    final opaque = color.withValues(alpha: 1);
    if (colors.any((existing) => existing.value == opaque.value)) return false;
    if (colors.length >= maxPaletteColors) return false;
    palettes[name] = [...colors, opaque];
    await savePalettes(palettes);
    return true;
  }

  List<Color> _normalizePaletteColors(Iterable<dynamic> values) {
    final colors = <Color>[];
    for (final value in values) {
      final Color? color = switch (value) {
        Color swatch => swatch,
        int numeric => Color(numeric),
        String text => switch (int.tryParse(text, radix: 16)) {
          final parsed? => Color(parsed),
          null => null,
        },
        _ => null,
      };
      if (color == null) continue;
      final opaque = color.withValues(alpha: 1);
      if (colors.any((existing) => existing.value == opaque.value)) continue;
      colors.add(opaque);
      if (colors.length == maxPaletteColors) break;
    }
    return colors;
  }
}
