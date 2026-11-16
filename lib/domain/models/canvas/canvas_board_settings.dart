import 'package:flutter/material.dart';

/// Background patterns painted behind the art.
enum CanvasBackgroundPattern { none, dots, grid, lines, isometric }

/// Board-level look and page settings.
///
/// Persisted as a `board_settings` CRDT payload with a stable id so every
/// collaborator sees the same background and page bounds, and undo covers
/// changes like any other board edit.
class CanvasBoardSettings {
  static const String crdtType = 'board_settings';
  static const String crdtId = 'board_settings';

  final Color backgroundColor;
  final CanvasBackgroundPattern backgroundPattern;
  final double patternSpacing;
  final bool pageBoundsEnabled;
  final double pageWidth;
  final double pageHeight;

  static const Color defaultBackground = Color(0xFFFFFFFF);
  static const bool defaultPageBounds = false;
  static const double defaultPageWidth = 1414;
  static const double defaultPageHeight = 1000;
  static const double defaultPatternSpacing = 32;

  static const List<(String, double, double)> pagePresets = [
    ('Square', 1000, 1000),
    ('16:9', 1600, 900),
    ('A4 landscape', 1123, 794),
    ('Letter landscape', 1056, 816),
  ];

  const CanvasBoardSettings({
    this.backgroundColor = defaultBackground,
    this.backgroundPattern = CanvasBackgroundPattern.none,
    this.patternSpacing = defaultPatternSpacing,
    this.pageBoundsEnabled = defaultPageBounds,
    this.pageWidth = defaultPageWidth,
    this.pageHeight = defaultPageHeight,
  });

  static const CanvasBoardSettings defaults = CanvasBoardSettings();

  CanvasBoardSettings copyWith({
    Color? backgroundColor,
    CanvasBackgroundPattern? backgroundPattern,
    double? patternSpacing,
    bool? pageBoundsEnabled,
    double? pageWidth,
    double? pageHeight,
  }) => CanvasBoardSettings(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    backgroundPattern: backgroundPattern ?? this.backgroundPattern,
    patternSpacing: patternSpacing ?? this.patternSpacing,
    pageBoundsEnabled: pageBoundsEnabled ?? this.pageBoundsEnabled,
    pageWidth: pageWidth ?? this.pageWidth,
    pageHeight: pageHeight ?? this.pageHeight,
  );

  Map<String, dynamic> toMap() => {
    'type': crdtType,
    'backgroundColor': backgroundColor.toARGB32(),
    'pattern': backgroundPattern.name,
    'patternSpacing': patternSpacing,
    'pageBoundsEnabled': pageBoundsEnabled,
    'pageWidth': pageWidth,
    'pageHeight': pageHeight,
  };

  static CanvasBoardSettings fromMap(Map<String, dynamic> data) {
    final patternName = data['pattern'] as String?;
    final pattern = CanvasBackgroundPattern.values.firstWhere(
      (value) => value.name == patternName,
      orElse: () => CanvasBackgroundPattern.none,
    );
    double read(String key, double fallback) {
      final value = (data[key] as num?)?.toDouble();
      return value != null && value.isFinite ? value : fallback;
    }

    final rawPageBounds = data['pageBoundsEnabled'];
    return CanvasBoardSettings(
      backgroundColor: Color(
        (data['backgroundColor'] as num?)?.toInt() ??
            defaultBackground.toARGB32(),
      ),
      backgroundPattern: pattern,
      patternSpacing: read(
        'patternSpacing',
        defaultPatternSpacing,
      ).clamp(8.0, 240.0),
      // CRDT payloads may carry a stringified bool; never cast blindly.
      pageBoundsEnabled: rawPageBounds is bool
          ? rawPageBounds
          : defaultPageBounds,
      pageWidth: read('pageWidth', defaultPageWidth).clamp(100.0, 10000.0),
      pageHeight: read('pageHeight', defaultPageHeight).clamp(100.0, 10000.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasBoardSettings &&
          backgroundColor == other.backgroundColor &&
          backgroundPattern == other.backgroundPattern &&
          patternSpacing == other.patternSpacing &&
          pageBoundsEnabled == other.pageBoundsEnabled &&
          pageWidth == other.pageWidth &&
          pageHeight == other.pageHeight;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    backgroundPattern,
    patternSpacing,
    pageBoundsEnabled,
    pageWidth,
    pageHeight,
  );
}
