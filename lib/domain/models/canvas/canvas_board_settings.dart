import 'package:flutter/material.dart';

/// Background patterns painted behind the art.
enum CanvasBackgroundPattern { none, dots, grid, lines, isometric }

/// Axis for a user-placed guide line on the canvas (F-18).
enum CanvasGuideAxis { horizontal, vertical }

/// Symmetry mode for live mirrored/radial drawing (F-18).
enum CanvasSymmetryMode { none, vertical, horizontal, radial }

/// A single ruler guide line in world coordinates.
class CanvasGuide {
  final String id;
  final CanvasGuideAxis axis;

  /// World Y for [CanvasGuideAxis.horizontal], world X for [CanvasGuideAxis.vertical].
  final double position;

  const CanvasGuide({
    required this.id,
    required this.axis,
    required this.position,
  });

  CanvasGuide copyWith({
    String? id,
    CanvasGuideAxis? axis,
    double? position,
  }) => CanvasGuide(
    id: id ?? this.id,
    axis: axis ?? this.axis,
    position: position ?? this.position,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'axis': axis.name,
    'position': position,
  };

  static CanvasGuide? fromMap(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    final axisName = data['axis'] as String?;
    final pos = (data['position'] as num?)?.toDouble();
    if (id == null || id.isEmpty || pos == null || !pos.isFinite) return null;
    final axis = CanvasGuideAxis.values.firstWhere(
      (v) => v.name == axisName,
      orElse: () => CanvasGuideAxis.horizontal,
    );
    return CanvasGuide(id: id, axis: axis, position: pos);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasGuide &&
          id == other.id &&
          axis == other.axis &&
          (position - other.position).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(id, axis, position);
}

/// Board-level look, page, guide, snapping, and symmetry settings (F-18, F-19).
///
/// Persisted as a `board_settings` CRDT payload with a stable id so every
/// collaborator sees the same background, page bounds, guides, and symmetry
/// axes, and undo covers changes like any other board edit.
class CanvasBoardSettings {
  static const String crdtType = 'board_settings';
  static const String crdtId = 'board_settings';

  final Color backgroundColor;
  final CanvasBackgroundPattern backgroundPattern;
  final double patternSpacing;
  final bool pageBoundsEnabled;
  final double pageWidth;
  final double pageHeight;

  // F-18: Rulers, guides, snapping, symmetry, and perspective guides.
  final bool rulersEnabled;
  final bool snapEnabled;
  final double snapDistance;
  final List<CanvasGuide> guides;
  final CanvasSymmetryMode symmetryMode;
  final Offset symmetryCenter;
  final int symmetryCount;
  final bool perspectiveEnabled;
  final List<Offset> vanishingPoints;
  final bool inkSpillEnabled;

  static const Color defaultBackground = Color(0xFFFFFFFF);
  static const bool defaultPageBounds = false;
  static const double defaultPageWidth = 1414;
  static const double defaultPageHeight = 1000;
  static const double defaultPatternSpacing = 32;
  static const double defaultSnapDistance = 8;
  static const Offset defaultSymmetryCenter = Offset(400, 300);
  static const int defaultSymmetryCount = 4;
  static const bool defaultInkSpill = false;

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
    this.rulersEnabled = false,
    this.snapEnabled = false,
    this.snapDistance = defaultSnapDistance,
    this.guides = const [],
    this.symmetryMode = CanvasSymmetryMode.none,
    this.symmetryCenter = defaultSymmetryCenter,
    this.symmetryCount = defaultSymmetryCount,
    this.perspectiveEnabled = false,
    this.vanishingPoints = const [],
    this.inkSpillEnabled = defaultInkSpill,
  });

  static const CanvasBoardSettings defaults = CanvasBoardSettings();

  CanvasBoardSettings copyWith({
    Color? backgroundColor,
    CanvasBackgroundPattern? backgroundPattern,
    double? patternSpacing,
    bool? pageBoundsEnabled,
    double? pageWidth,
    double? pageHeight,
    bool? rulersEnabled,
    bool? snapEnabled,
    double? snapDistance,
    List<CanvasGuide>? guides,
    CanvasSymmetryMode? symmetryMode,
    Offset? symmetryCenter,
    int? symmetryCount,
    bool? perspectiveEnabled,
    List<Offset>? vanishingPoints,
    bool? inkSpillEnabled,
  }) => CanvasBoardSettings(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    backgroundPattern: backgroundPattern ?? this.backgroundPattern,
    patternSpacing: patternSpacing ?? this.patternSpacing,
    pageBoundsEnabled: pageBoundsEnabled ?? this.pageBoundsEnabled,
    pageWidth: pageWidth ?? this.pageWidth,
    pageHeight: pageHeight ?? this.pageHeight,
    rulersEnabled: rulersEnabled ?? this.rulersEnabled,
    snapEnabled: snapEnabled ?? this.snapEnabled,
    snapDistance: snapDistance ?? this.snapDistance,
    guides: guides ?? this.guides,
    symmetryMode: symmetryMode ?? this.symmetryMode,
    symmetryCenter: symmetryCenter ?? this.symmetryCenter,
    symmetryCount: symmetryCount ?? this.symmetryCount,
    perspectiveEnabled: perspectiveEnabled ?? this.perspectiveEnabled,
    vanishingPoints: vanishingPoints ?? this.vanishingPoints,
    inkSpillEnabled: inkSpillEnabled ?? this.inkSpillEnabled,
  );

  Map<String, dynamic> toMap() => {
    'type': crdtType,
    'backgroundColor': backgroundColor.toARGB32(),
    'pattern': backgroundPattern.name,
    'patternSpacing': patternSpacing,
    'pageBoundsEnabled': pageBoundsEnabled,
    'pageWidth': pageWidth,
    'pageHeight': pageHeight,
    'rulersEnabled': rulersEnabled,
    'snapEnabled': snapEnabled,
    'snapDistance': snapDistance,
    if (guides.isNotEmpty)
      'guides': guides.map((g) => g.toMap()).toList(growable: false),
    'symmetryMode': symmetryMode.name,
    'symmetryCenterX': symmetryCenter.dx,
    'symmetryCenterY': symmetryCenter.dy,
    'symmetryCount': symmetryCount,
    'perspectiveEnabled': perspectiveEnabled,
    if (vanishingPoints.isNotEmpty)
      'vanishingPoints': vanishingPoints
          .map((p) => {'x': p.dx, 'y': p.dy})
          .toList(growable: false),
    'inkSpillEnabled': inkSpillEnabled,
  };

  static CanvasBoardSettings fromMap(Map<String, dynamic> data) {
    final patternName = data['pattern'] as String?;
    final pattern = CanvasBackgroundPattern.values.firstWhere(
      (value) => value.name == patternName,
      orElse: () => CanvasBackgroundPattern.none,
    );
    final symmetryName = data['symmetryMode'] as String?;
    final symmetryMode = CanvasSymmetryMode.values.firstWhere(
      (value) => value.name == symmetryName,
      orElse: () => CanvasSymmetryMode.none,
    );
    double read(String key, double fallback) {
      final value = (data[key] as num?)?.toDouble();
      return value != null && value.isFinite ? value : fallback;
    }

    final rawPageBounds = data['pageBoundsEnabled'];
    final rawRulers = data['rulersEnabled'];
    final rawSnap = data['snapEnabled'];
    final rawPerspective = data['perspectiveEnabled'];
    final rawInkSpill = data['inkSpillEnabled'];

    final parsedGuides = <CanvasGuide>[];
    final rawGuides = data['guides'];
    if (rawGuides is List) {
      for (final item in rawGuides) {
        if (item is Map) {
          final g = CanvasGuide.fromMap(Map<String, dynamic>.from(item));
          if (g != null) parsedGuides.add(g);
        }
      }
    }

    final parsedVanishingPoints = <Offset>[];
    final rawVps = data['vanishingPoints'];
    if (rawVps is List) {
      for (final item in rawVps) {
        if (item is Map) {
          final x = (item['x'] as num?)?.toDouble();
          final y = (item['y'] as num?)?.toDouble();
          if (x != null && y != null && x.isFinite && y.isFinite) {
            parsedVanishingPoints.add(Offset(x, y));
          }
        }
      }
    }

    final symCount =
        ((data['symmetryCount'] as num?)?.toInt() ?? defaultSymmetryCount)
            .clamp(2, 16);

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
      rulersEnabled: rawRulers is bool ? rawRulers : false,
      snapEnabled: rawSnap is bool ? rawSnap : false,
      snapDistance: read('snapDistance', defaultSnapDistance).clamp(2.0, 48.0),
      guides: List<CanvasGuide>.unmodifiable(parsedGuides),
      symmetryMode: symmetryMode,
      symmetryCenter: Offset(
        read('symmetryCenterX', defaultSymmetryCenter.dx),
        read('symmetryCenterY', defaultSymmetryCenter.dy),
      ),
      symmetryCount: symCount,
      perspectiveEnabled: rawPerspective is bool ? rawPerspective : false,
      vanishingPoints: List<Offset>.unmodifiable(parsedVanishingPoints),
      inkSpillEnabled: rawInkSpill is bool ? rawInkSpill : defaultInkSpill,
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
          pageHeight == other.pageHeight &&
          rulersEnabled == other.rulersEnabled &&
          snapEnabled == other.snapEnabled &&
          snapDistance == other.snapDistance &&
          _guidesEqual(guides, other.guides) &&
          symmetryMode == other.symmetryMode &&
          symmetryCenter == other.symmetryCenter &&
          symmetryCount == other.symmetryCount &&
          perspectiveEnabled == other.perspectiveEnabled &&
          _offsetsEqual(vanishingPoints, other.vanishingPoints) &&
          inkSpillEnabled == other.inkSpillEnabled;

  static bool _guidesEqual(List<CanvasGuide> a, List<CanvasGuide> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _offsetsEqual(List<Offset> a, List<Offset> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    backgroundPattern,
    patternSpacing,
    pageBoundsEnabled,
    pageWidth,
    pageHeight,
    rulersEnabled,
    snapEnabled,
    snapDistance,
    Object.hashAll(guides),
    symmetryMode,
    symmetryCenter,
    symmetryCount,
    perspectiveEnabled,
    Object.hashAll(vanishingPoints),
    inkSpillEnabled,
  );
}
