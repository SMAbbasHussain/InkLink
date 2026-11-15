import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../geometry/canvas_element_geometry.dart';

/// The procedural texture a brush family simulates.
///
/// Only [BrushTexture.wash] currently changes rendering (a soft blur).
/// [BrushTexture.grain] is metadata for the pencil/textured families; the
/// canvas and exporters render them with their width/opacity profile today.
enum BrushTexture { none, grain, wash }

/// A selectable brush family.
///
/// [id] is persisted verbatim as `StrokeElement.brushType`, so legacy ids
/// (`solid`, `textured`, `watercolor`, `marker`, `highlighter`) keep loading
/// with their historical appearance. Unknown ids resolve to [penPreset].
class BrushPreset {
  final String id;
  final String label;
  final IconData icon;
  final double defaultWidth;
  final double defaultOpacity;
  final double widthMultiplier;
  final double opacityMultiplier;
  final BrushTexture texture;
  final BlendMode blendMode;
  final StrokeCap cap;
  final double blurSigma;
  final String description;
  final double spacing;
  final double jitter;
  final bool pressureAffectsSize;
  final bool pressureAffectsOpacity;
  final double taperStart;
  final double taperEnd;
  final double minWidth;
  final double maxWidth;
  final bool isEraser;

  const BrushPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.defaultWidth,
    required this.defaultOpacity,
    required this.widthMultiplier,
    required this.opacityMultiplier,
    required this.texture,
    required this.blendMode,
    required this.cap,
    required this.blurSigma,
    required this.description,
    this.spacing = 0.15,
    this.jitter = 0.0,
    this.pressureAffectsSize = true,
    this.pressureAffectsOpacity = false,
    this.taperStart = 0.0,
    this.taperEnd = 0.0,
    this.minWidth = 1.0,
    this.maxWidth = 48.0,
    this.isEraser = false,
  });
}

const BrushPreset penPreset = BrushPreset(
  id: 'solid',
  label: 'Pen',
  icon: LucideIcons.penLine,
  defaultWidth: 5,
  defaultOpacity: 1,
  widthMultiplier: 1,
  opacityMultiplier: 1,
  texture: BrushTexture.none,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 0,
  spacing: 0.1,
  jitter: 0.0,
  pressureAffectsSize: true,
  pressureAffectsOpacity: false,
  taperStart: 0.06,
  taperEnd: 0.06,
  minWidth: 1.0,
  maxWidth: 48.0,
  description: 'Clean, opaque ink',
);

const BrushPreset pencilPreset = BrushPreset(
  id: 'pencil',
  label: 'Pencil',
  icon: LucideIcons.pencil,
  defaultWidth: 3,
  defaultOpacity: 0.9,
  widthMultiplier: 0.8,
  opacityMultiplier: 1,
  texture: BrushTexture.grain,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 0,
  spacing: 0.18,
  jitter: 0.4,
  pressureAffectsSize: true,
  pressureAffectsOpacity: true,
  taperStart: 0.04,
  taperEnd: 0.04,
  minWidth: 1.0,
  maxWidth: 36.0,
  description: 'Fine, dry line with grain',
);

const BrushPreset texturedPreset = BrushPreset(
  id: 'textured',
  label: 'Textured',
  icon: LucideIcons.brush,
  defaultWidth: 6,
  defaultOpacity: 1,
  widthMultiplier: 0.95,
  opacityMultiplier: 0.8,
  texture: BrushTexture.grain,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 0,
  spacing: 0.2,
  jitter: 0.6,
  pressureAffectsSize: true,
  pressureAffectsOpacity: true,
  taperStart: 0.02,
  taperEnd: 0.02,
  minWidth: 2.0,
  maxWidth: 48.0,
  description: 'Soft grain and tooth',
);

const BrushPreset markerPreset = BrushPreset(
  id: 'marker',
  label: 'Marker',
  icon: LucideIcons.penTool,
  defaultWidth: 14,
  defaultOpacity: 0.9,
  widthMultiplier: markerWidthMultiplier,
  opacityMultiplier: markerOpacityMultiplier,
  texture: BrushTexture.none,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 0,
  spacing: 0.12,
  jitter: 0.0,
  pressureAffectsSize: false,
  pressureAffectsOpacity: false,
  taperStart: 0.0,
  taperEnd: 0.0,
  minWidth: 4.0,
  maxWidth: 64.0,
  description: 'Broad, consistent stroke',
);

const BrushPreset highlighterPreset = BrushPreset(
  id: 'highlighter',
  label: 'Highlighter',
  icon: LucideIcons.highlighter,
  defaultWidth: 10,
  defaultOpacity: 0.8,
  widthMultiplier: highlighterWidthMultiplier,
  opacityMultiplier: highlighterOpacityMultiplier,
  texture: BrushTexture.none,
  blendMode: BlendMode.multiply,
  cap: StrokeCap.square,
  blurSigma: 0,
  spacing: 0.15,
  jitter: 0.0,
  pressureAffectsSize: false,
  pressureAffectsOpacity: false,
  taperStart: 0.0,
  taperEnd: 0.0,
  minWidth: 4.0,
  maxWidth: 64.0,
  description: 'Wide translucent wash',
);

const BrushPreset watercolorPreset = BrushPreset(
  id: 'watercolor',
  label: 'Watercolor',
  icon: LucideIcons.droplet,
  defaultWidth: 8,
  defaultOpacity: 0.9,
  widthMultiplier: 1.25,
  opacityMultiplier: 0.45,
  texture: BrushTexture.wash,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 2.5,
  spacing: 0.25,
  jitter: 0.3,
  pressureAffectsSize: true,
  pressureAffectsOpacity: true,
  taperStart: 0.08,
  taperEnd: 0.08,
  minWidth: 3.0,
  maxWidth: 64.0,
  description: 'Layered wash with soft edges',
);

const BrushPreset airbrushPreset = BrushPreset(
  id: 'airbrush',
  label: 'Airbrush',
  icon: LucideIcons.wind,
  defaultWidth: 16,
  defaultOpacity: 0.7,
  widthMultiplier: 1.4,
  opacityMultiplier: 0.5,
  texture: BrushTexture.wash,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 4.0,
  spacing: 0.15,
  jitter: 1.0,
  pressureAffectsSize: true,
  pressureAffectsOpacity: true,
  taperStart: 0.05,
  taperEnd: 0.05,
  minWidth: 6.0,
  maxWidth: 80.0,
  description: 'Soft diffuse spray',
);

const BrushPreset charcoalPreset = BrushPreset(
  id: 'charcoal',
  label: 'Charcoal',
  icon: LucideIcons.flame,
  defaultWidth: 10,
  defaultOpacity: 0.95,
  widthMultiplier: 1.1,
  opacityMultiplier: 0.85,
  texture: BrushTexture.grain,
  blendMode: BlendMode.srcOver,
  cap: StrokeCap.round,
  blurSigma: 0,
  spacing: 0.22,
  jitter: 0.8,
  pressureAffectsSize: true,
  pressureAffectsOpacity: true,
  taperStart: 0.03,
  taperEnd: 0.03,
  minWidth: 2.0,
  maxWidth: 56.0,
  description: 'Rich grainy texture',
);

/// Presets shown in the brush picker, ordered from driest to wettest.
const List<BrushPreset> brushPresets = <BrushPreset>[
  penPreset,
  pencilPreset,
  texturedPreset,
  markerPreset,
  highlighterPreset,
  watercolorPreset,
  airbrushPreset,
  charcoalPreset,
];

/// Resolves a persisted brush type to a preset, falling back to the pen so
/// unknown future/legacy ids never render as invisible or crash.
BrushPreset brushPresetFor(String id) {
  if (id == 'pen' || id == 'solid') return penPreset;
  for (final preset in brushPresets) {
    if (preset.id == id) return preset;
  }
  return penPreset;
}

double _roundOpacity(double value) =>
    (value.clamp(0.0, 1.0) * 1000).round() / 1000;

/// Fully resolved stroke style shared by the canvas painter and exporters.
///
/// Keeping this in one place means a change to a preset cannot make the
/// on-screen stroke drift from PNG/PDF/SVG output.
class CanvasBrushStyle {
  final double width;
  final double opacity;
  final BlendMode blendMode;
  final StrokeCap cap;
  final double blurSigma;
  final BrushTexture texture;
  final double spacing;
  final double jitter;
  final bool pressureAffectsSize;
  final bool pressureAffectsOpacity;
  final double taperStart;
  final double taperEnd;

  const CanvasBrushStyle({
    required this.width,
    required this.opacity,
    required this.blendMode,
    required this.cap,
    required this.blurSigma,
    required this.texture,
    this.spacing = 0.15,
    this.jitter = 0.0,
    this.pressureAffectsSize = true,
    this.pressureAffectsOpacity = false,
    this.taperStart = 0.0,
    this.taperEnd = 0.0,
  });
}

CanvasBrushStyle resolveBrushStyle({
  required String brushType,
  required double strokeWidth,
  required double strokeOpacity,
}) {
  final preset = brushPresetFor(brushType);
  final double width;
  final double opacity;
  switch (preset.id) {
    case 'highlighter':
      width = highlighterStrokeWidth(strokeWidth);
      opacity = highlighterStrokeOpacity(strokeOpacity);
      break;
    case 'marker':
      width = markerStrokeWidth(strokeWidth);
      opacity = markerStrokeOpacity(strokeOpacity);
      break;
    default:
      width = strokeWidth * preset.widthMultiplier;
      opacity = _roundOpacity(strokeOpacity * preset.opacityMultiplier);
  }
  return CanvasBrushStyle(
    width: width,
    opacity: opacity,
    blendMode: preset.blendMode,
    cap: preset.cap,
    blurSigma: preset.blurSigma,
    texture: preset.texture,
    spacing: preset.spacing,
    jitter: preset.jitter,
    pressureAffectsSize: preset.pressureAffectsSize,
    pressureAffectsOpacity: preset.pressureAffectsOpacity,
    taperStart: preset.taperStart,
    taperEnd: preset.taperEnd,
  );
}

/// SVG filter id used to approximate [BrushTexture.wash] in vector exports.
const String watercolorBlurFilterId = 'watercolor-blur';

/// SVG `stdDeviation` that best matches the painter's [BrushPreset.blurSigma].
const double watercolorBlurStdDeviation = 1.25;
