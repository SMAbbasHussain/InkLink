import 'package:flutter/material.dart';

import '../../../domain/models/canvas/canvas_shape_type.dart';

sealed class CanvasElement {
  final String id;
  final int z;

  /// Layer-panel state. These travel with the element payload so visibility,
  /// lock and opacity survive reload and sync through CRDT like any edit.
  final bool hidden;
  final bool locked;
  final double opacity;

  const CanvasElement({
    required this.id,
    required this.z,
    this.hidden = false,
    this.locked = false,
    this.opacity = 1.0,
  });

  Map<String, dynamic> toMap();

  static CanvasElement fromMap(String id, Map<String, dynamic> data) {
    final type = data['type'] as String;
    final z = data['z'] as int? ?? 0;
    switch (type) {
      case 'stroke':
        final rawType = data['brushType'] as String? ?? 'solid';
        final rawId = data['brushId'] as String? ?? rawType;
        return StrokeElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          color: Color(data['color'] as int),
          strokeWidth: (data['strokeWidth'] as num).toDouble(),
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          brushType: rawType,
          brushId: rawId,
          points:
              (data['points'] as List<dynamic>?)
                  ?.map(
                    (p) => Offset(
                      (p['x'] as num).toDouble(),
                      (p['y'] as num).toDouble(),
                    ),
                  )
                  .toList() ??
              [],
          pressures:
              (data['pressures'] as List<dynamic>?)
                  ?.map((p) => (p as num).toDouble())
                  .toList() ??
              const [],
          spacing: (data['spacing'] as num?)?.toDouble() ?? 0.25,
          textureSeed: (data['textureSeed'] as num?)?.toInt() ?? 0,
        );
      case 'shape':
        final shapeType = CanvasShapeType.values.byName(
          data['shapeType'] as String,
        );
        return ShapeElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          shapeType: shapeType,
          center: Offset(
            (data['cx'] as num).toDouble(),
            (data['cy'] as num).toDouble(),
          ),
          size: (data['size'] as num).toDouble(),
          width: (data['width'] as num?)?.toDouble() ?? 0,
          height: (data['height'] as num?)?.toDouble() ?? 0,
          color: Color(data['color'] as int),
          strokeWidth: (data['strokeWidth'] as num).toDouble(),
          strokeOpacity: (data['strokeOpacity'] as num?)?.toDouble() ?? 1.0,
          dashPattern: (data['dashPattern'] as List<dynamic>?)
              ?.map((d) => (d as num).toDouble())
              .toList(growable: false),
          isFilled: data['isFilled'] as bool? ?? false,
          rotation: (data['rotation'] as num?)?.toDouble() ?? 0,
          borderRadius: (data['borderRadius'] as num?)?.toDouble() ?? 0,
          label: data['label'] as String? ?? '',
          labelColor: data['labelColor'] == null
              ? null
              : Color((data['labelColor'] as num).toInt()),
          labelFontSize: (data['labelFontSize'] as num?)?.toDouble() ?? 14,
          labelFontWeight: (data['labelFontWeight'] as num?)?.toInt() ?? 600,
          labelTextAlign: data['labelTextAlign'] as String? ?? 'center',
          startArrowhead: data['startArrowhead'] as bool? ?? false,
          // Legacy arrows always drew a head at the end; preserve that.
          endArrowhead:
              data['endArrowhead'] as bool? ??
              (shapeType == CanvasShapeType.arrow),
        );
      case 'text':
        return TextElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          text: data['text'] as String? ?? '',
          center: Offset(
            (data['cx'] as num?)?.toDouble() ?? 0,
            (data['cy'] as num?)?.toDouble() ?? 0,
          ),
          color: Color((data['color'] as num?)?.toInt() ?? 0xFF000000),
          width: (data['width'] as num?)?.toDouble() ?? 0,
          height: (data['height'] as num?)?.toDouble() ?? 0,
          fontSize: (data['fontSize'] as num?)?.toDouble() ?? 16.0,
          fontWeight: (data['fontWeight'] as num?)?.toInt() ?? 600,
          fontFamily: data['fontFamily'] as String?,
          textAlign: data['textAlign'] as String? ?? 'left',
          lineHeight: (data['lineHeight'] as num?)?.toDouble() ?? 1.2,
          rotation: (data['rotation'] as num?)?.toDouble() ?? 0,
          // Legacy payloads truncated at two lines; new text is unlimited.
          maxLines: (data['maxLines'] as num?)?.toInt() ?? 0,
          autoSize: data['autoSize'] as bool? ?? false,
          backgroundColor: data['backgroundColor'] == null
              ? null
              : Color((data['backgroundColor'] as num).toInt()),
          padding: (data['padding'] as num?)?.toDouble() ?? 4.0,
        );
      case 'image':
        return ImageElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          center: Offset(
            (data['cx'] as num).toDouble(),
            (data['cy'] as num).toDouble(),
          ),
          width: (data['width'] as num).toDouble(),
          height: (data['height'] as num).toDouble(),
          imageBase64: data['imageBase64'] as String? ?? '',
          rotation: (data['rotation'] as num?)?.toDouble() ?? 0,
          flipped: data['flipped'] as bool? ?? false,
          flipV: data['flipV'] as bool? ?? false,
          crop: _parseImageCrop(data),
          borderRadius:
              (data['borderRadius'] as num?)?.toDouble() ??
              ImageElement.defaultBorderRadius,
          borderWidth: (data['borderWidth'] as num?)?.toDouble() ?? 0,
          borderColor: data['borderColor'] == null
              ? ImageElement.defaultBorderColor
              : Color((data['borderColor'] as num).toInt()),
          brightness: (data['brightness'] as num?)?.toDouble() ?? 0,
          contrast: (data['contrast'] as num?)?.toDouble() ?? 0,
          saturation: (data['saturation'] as num?)?.toDouble() ?? 0,
          isReference: data['isReference'] as bool? ?? false,
        );
      case 'sticky_note':
        return StickyNoteElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          center: Offset(
            (data['cx'] as num).toDouble(),
            (data['cy'] as num).toDouble(),
          ),
          width:
              (data['width'] as num?)?.toDouble() ??
              (data['size'] as num?)?.toDouble() ??
              160,
          height:
              (data['height'] as num?)?.toDouble() ??
              (data['size'] as num?)?.toDouble() ??
              160,
          text: data['text'] as String? ?? '',
          color: Color(data['color'] as int? ?? 0xFFFFF9A6),
          rotation: (data['rotation'] as num?)?.toDouble() ?? 0,
          fontSize: (data['fontSize'] as num?)?.toDouble() ?? 14,
          fontWeight: (data['fontWeight'] as num?)?.toInt() ?? 500,
          textColor: Color((data['textColor'] as num?)?.toInt() ?? 0xFF1E293B),
          textAlign: data['textAlign'] as String? ?? 'left',
          autoSize: data['autoSize'] as bool? ?? false,
          authorUid: data['authorUid'] as String?,
        );
      case 'layer':
        return LayerElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          name: data['name'] as String? ?? 'Layer',
          elementIds: (data['elementIds'] as List<dynamic>? ?? const [])
              .map((value) => value as String)
              .toList(growable: false),
        );
      case 'connector':
        return ConnectorElement(
          id: id,
          z: z,
          hidden: data['hidden'] as bool? ?? false,
          locked: data['locked'] as bool? ?? false,
          opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
          startElementId: data['startElementId'] as String?,
          startPoint: Offset(
            (data['sx'] as num).toDouble(),
            (data['sy'] as num).toDouble(),
          ),
          startAnchor: data['startAnchor'] as String? ?? 'center',
          endElementId: data['endElementId'] as String?,
          endPoint: Offset(
            (data['ex'] as num).toDouble(),
            (data['ey'] as num).toDouble(),
          ),
          endAnchor: data['endAnchor'] as String? ?? 'center',
          lineStyle: data['lineStyle'] as String? ?? 'straight',
          color: Color(data['color'] as int? ?? 0xFF000000),
          strokeWidth: (data['strokeWidth'] as num?)?.toDouble() ?? 2.5,
          hasArrowhead:
              data['endArrowhead'] as bool? ??
              data['hasArrowhead'] as bool? ??
              true,
          startArrowhead: data['startArrowhead'] as bool? ?? false,
          cornerRadius: (data['cornerRadius'] as num?)?.toDouble() ?? 0,
          dashPattern: (data['dashPattern'] as List<dynamic>?)
              ?.map((d) => (d as num).toDouble())
              .toList(growable: false),
          label: data['label'] as String? ?? '',
          labelColor: data['labelColor'] == null
              ? null
              : Color((data['labelColor'] as num).toInt()),
          labelFontSize: (data['labelFontSize'] as num?)?.toDouble() ?? 14,
        );
      default:
        throw ArgumentError('Unknown canvas element type: $type');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasElement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          z == other.z &&
          hidden == other.hidden &&
          locked == other.locked &&
          opacity == other.opacity;

  @override
  int get hashCode =>
      id.hashCode ^
      z.hashCode ^
      hidden.hashCode ^
      locked.hashCode ^
      opacity.hashCode;
}

class StrokeElement extends CanvasElement {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String brushType;
  final String brushId;
  final List<double> pressures;
  final double spacing;
  final int textureSeed;

  const StrokeElement({
    required super.id,
    required super.z,
    this.points = const [],
    required this.color,
    this.strokeWidth = 5,
    super.hidden,
    super.locked,
    super.opacity,
    this.brushType = 'solid',
    String? brushId,
    this.pressures = const [],
    this.spacing = 0.15,
    this.textureSeed = 0,
  }) : brushId = brushId ?? brushType;

  @override
  Map<String, dynamic> toMap() => {
    'type': 'stroke',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    'color': color.value,
    'strokeWidth': strokeWidth,
    'brushType': brushType,
    'brushId': brushId,
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(growable: false),
    if (pressures.isNotEmpty) 'pressures': pressures,
    'spacing': spacing,
    'textureSeed': textureSeed,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrokeElement &&
          super == other &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          brushType == other.brushType &&
          brushId == other.brushId &&
          spacing == other.spacing &&
          textureSeed == other.textureSeed &&
          _listEquals(points, other.points) &&
          _doubleListEquals(pressures, other.pressures);

  @override
  int get hashCode =>
      super.hashCode ^
      color.hashCode ^
      strokeWidth.hashCode ^
      brushType.hashCode ^
      brushId.hashCode ^
      spacing.hashCode ^
      textureSeed.hashCode ^
      Object.hashAll(points);

  static bool _listEquals(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _doubleListEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-6) return false;
    }
    return true;
  }
}

class ShapeElement extends CanvasElement {
  final CanvasShapeType shapeType;
  final Offset center;

  /// Legacy single dimension. Kept in sync as `max(width, height)` for new
  /// payloads; old payloads carry only this and derive width/height from the
  /// per-type aspect ratio (see [shapeElementRect]).
  final double size;

  /// Explicit box dimensions. 0 means "derive from [size] and the legacy
  /// aspect". When either is set the pair is used as-is, so line/arrow can
  /// store a flat segment (height 0) and rectangles can be non-uniform.
  final double width;
  final double height;
  final Color color;
  final double strokeWidth;

  /// Opacity applied to the outline only; the fill keeps [color]'s alpha.
  final double strokeOpacity;

  /// Dash lengths in logical pixels (on, off, …). null/empty means solid.
  final List<double>? dashPattern;
  final bool isFilled;
  final double rotation;
  final double borderRadius;

  /// Centered label drawn inside the shape. Empty means no label.
  final String label;
  final Color? labelColor;
  final double labelFontSize;
  final int labelFontWeight;
  final String labelTextAlign;

  /// Arrowheads for line/arrow shapes. Legacy `arrow` payloads default
  /// [endArrowhead] to true so they keep their head on read.
  final bool startArrowhead;
  final bool endArrowhead;

  const ShapeElement({
    required super.id,
    required super.z,
    super.hidden,
    super.locked,
    super.opacity,
    required this.shapeType,
    required this.center,
    required this.size,
    required this.color,
    this.width = 0,
    this.height = 0,
    this.strokeWidth = 2,
    this.strokeOpacity = 1,
    this.dashPattern,
    this.isFilled = false,
    this.rotation = 0,
    this.borderRadius = 0,
    this.label = '',
    this.labelColor,
    this.labelFontSize = 14,
    this.labelFontWeight = 600,
    this.labelTextAlign = 'center',
    this.startArrowhead = false,
    this.endArrowhead = false,
  });

  @override
  Map<String, dynamic> toMap() => {
    'type': 'shape',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    'shapeType': shapeType.name,
    'cx': center.dx,
    'cy': center.dy,
    'size': size,
    'width': width,
    'height': height,
    'color': color.value,
    'strokeWidth': strokeWidth,
    'strokeOpacity': strokeOpacity,
    if (dashPattern != null) 'dashPattern': dashPattern,
    'isFilled': isFilled,
    'rotation': rotation,
    'borderRadius': borderRadius,
    'label': label,
    if (labelColor != null) 'labelColor': labelColor!.value,
    'labelFontSize': labelFontSize,
    'labelFontWeight': labelFontWeight,
    'labelTextAlign': labelTextAlign,
    'startArrowhead': startArrowhead,
    'endArrowhead': endArrowhead,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShapeElement &&
          super == other &&
          shapeType == other.shapeType &&
          center == other.center &&
          size == other.size &&
          width == other.width &&
          height == other.height &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          strokeOpacity == other.strokeOpacity &&
          _dashEquals(dashPattern, other.dashPattern) &&
          isFilled == other.isFilled &&
          rotation == other.rotation &&
          borderRadius == other.borderRadius &&
          label == other.label &&
          labelColor == other.labelColor &&
          labelFontSize == other.labelFontSize &&
          labelFontWeight == other.labelFontWeight &&
          labelTextAlign == other.labelTextAlign &&
          startArrowhead == other.startArrowhead &&
          endArrowhead == other.endArrowhead;

  @override
  int get hashCode =>
      super.hashCode ^
      shapeType.hashCode ^
      center.hashCode ^
      size.hashCode ^
      width.hashCode ^
      height.hashCode ^
      color.hashCode ^
      strokeWidth.hashCode ^
      strokeOpacity.hashCode ^
      Object.hashAll(dashPattern ?? const []) ^
      isFilled.hashCode ^
      rotation.hashCode ^
      borderRadius.hashCode ^
      label.hashCode ^
      labelColor.hashCode ^
      labelFontSize.hashCode ^
      labelFontWeight.hashCode ^
      labelTextAlign.hashCode ^
      startArrowhead.hashCode ^
      endArrowhead.hashCode;

  static bool _dashEquals(List<double>? a, List<double>? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-6) return false;
    }
    return true;
  }
}

class TextElement extends CanvasElement {
  final String text;

  /// Top-left corner of the text box.
  ///
  /// The field has always been called `center`, but the painter draws from it
  /// as the top-left origin. The name is kept so existing payloads keep
  /// loading; use [textElementRect] for the actual drawn box.
  final Offset center;
  final Color color;

  // Measured layout bounds, persisted so selection/erase overlays match
  // the drawn text; 0 means unknown (fall back to measuring).
  final double width;
  final double height;

  final double fontSize;
  final int fontWeight;
  final String? fontFamily;
  final String textAlign;
  final double lineHeight;
  final double rotation;

  /// 0 means unlimited lines.
  final int maxLines;
  final bool autoSize;
  final Color? backgroundColor;
  final double padding;

  const TextElement({
    required super.id,
    required super.z,
    super.hidden,
    super.locked,
    super.opacity,
    this.text = '',
    required this.center,
    required this.color,
    this.width = 0,
    this.height = 0,
    this.fontSize = 16.0,
    this.fontWeight = 600,
    this.fontFamily,
    this.textAlign = 'left',
    this.lineHeight = 1.2,
    this.rotation = 0,
    this.maxLines = 0,
    this.autoSize = false,
    this.backgroundColor,
    this.padding = 4.0,
  });

  @override
  Map<String, dynamic> toMap() => {
    'type': 'text',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    'text': text,
    'cx': center.dx,
    'cy': center.dy,
    'color': color.value,
    if (width > 0) 'width': width,
    if (height > 0) 'height': height,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    if (fontFamily != null) 'fontFamily': fontFamily,
    'textAlign': textAlign,
    'lineHeight': lineHeight,
    'rotation': rotation,
    'maxLines': maxLines,
    'autoSize': autoSize,
    if (backgroundColor != null) 'backgroundColor': backgroundColor!.value,
    'padding': padding,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextElement &&
          super == other &&
          text == other.text &&
          center == other.center &&
          color == other.color &&
          width == other.width &&
          height == other.height &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          fontFamily == other.fontFamily &&
          textAlign == other.textAlign &&
          lineHeight == other.lineHeight &&
          rotation == other.rotation &&
          maxLines == other.maxLines &&
          autoSize == other.autoSize &&
          backgroundColor == other.backgroundColor &&
          padding == other.padding;

  @override
  int get hashCode =>
      super.hashCode ^
      text.hashCode ^
      center.hashCode ^
      color.hashCode ^
      width.hashCode ^
      height.hashCode ^
      fontSize.hashCode ^
      fontWeight.hashCode ^
      fontFamily.hashCode ^
      textAlign.hashCode ^
      lineHeight.hashCode ^
      rotation.hashCode ^
      maxLines.hashCode ^
      autoSize.hashCode ^
      backgroundColor.hashCode ^
      padding.hashCode;
}

class ImageElement extends CanvasElement {
  final Offset center;
  final double width;
  final double height;
  final String imageBase64;

  /// Clockwise rotation in radians, applied around [center].
  final double rotation;

  /// Horizontal mirror, applied in the image's own rotated frame.
  final bool flipped;

  /// Vertical mirror, applied in the image's own rotated frame.
  final bool flipV;

  /// Visible part of the source image in normalized 0–1 coordinates. The
  /// original pixels are never modified, so crops can be widened again.
  final Rect crop;

  final double borderRadius;
  final double borderWidth;
  final Color borderColor;

  /// Colour adjustments in -1…1; 0 leaves the image untouched.
  final double brightness;
  final double contrast;
  final double saturation;

  /// Tracing reference: drawn faded and locked when enabled.
  final bool isReference;

  static const Rect fullCrop = Rect.fromLTRB(0, 0, 1, 1);
  static const double defaultBorderRadius = 8;
  static const Color defaultBorderColor = Color(0xFF0F172A);
  static const double referenceOpacity = 0.4;

  const ImageElement({
    required super.id,
    required super.z,
    super.hidden,
    super.locked,
    super.opacity,
    required this.center,
    this.width = 100,
    this.height = 100,
    this.imageBase64 = '',
    this.rotation = 0,
    this.flipped = false,
    this.flipV = false,
    this.crop = fullCrop,
    this.borderRadius = defaultBorderRadius,
    this.borderWidth = 0,
    this.borderColor = defaultBorderColor,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.isReference = false,
  });

  bool get hasFilters => brightness != 0 || contrast != 0 || saturation != 0;

  ImageElement copyWith({
    int? z,
    bool? hidden,
    bool? locked,
    double? opacity,
    Offset? center,
    double? width,
    double? height,
    String? imageBase64,
    double? rotation,
    bool? flipped,
    bool? flipV,
    Rect? crop,
    double? borderRadius,
    double? borderWidth,
    Color? borderColor,
    double? brightness,
    double? contrast,
    double? saturation,
    bool? isReference,
  }) {
    return ImageElement(
      id: id,
      z: z ?? this.z,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      center: center ?? this.center,
      width: width ?? this.width,
      height: height ?? this.height,
      imageBase64: imageBase64 ?? this.imageBase64,
      rotation: rotation ?? this.rotation,
      flipped: flipped ?? this.flipped,
      flipV: flipV ?? this.flipV,
      crop: crop ?? this.crop,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      isReference: isReference ?? this.isReference,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'type': 'image',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    'cx': center.dx,
    'cy': center.dy,
    'width': width,
    'height': height,
    'imageBase64': imageBase64,
    'rotation': rotation,
    'flipped': flipped,
    'flipV': flipV,
    'cropL': crop.left,
    'cropT': crop.top,
    'cropR': crop.right,
    'cropB': crop.bottom,
    'borderRadius': borderRadius,
    'borderWidth': borderWidth,
    'borderColor': borderColor.toARGB32(),
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'isReference': isReference,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageElement &&
          super == other &&
          center == other.center &&
          width == other.width &&
          height == other.height &&
          imageBase64 == other.imageBase64 &&
          rotation == other.rotation &&
          flipped == other.flipped &&
          flipV == other.flipV &&
          crop == other.crop &&
          borderRadius == other.borderRadius &&
          borderWidth == other.borderWidth &&
          borderColor == other.borderColor &&
          brightness == other.brightness &&
          contrast == other.contrast &&
          saturation == other.saturation &&
          isReference == other.isReference;

  @override
  int get hashCode =>
      super.hashCode ^
      center.hashCode ^
      width.hashCode ^
      height.hashCode ^
      imageBase64.hashCode ^
      rotation.hashCode ^
      flipped.hashCode ^
      Object.hash(
        flipV,
        crop,
        borderRadius,
        borderWidth,
        borderColor,
        brightness,
        contrast,
        saturation,
        isReference,
      );
}

/// Reads a normalized crop, falling back to the full image for legacy or
/// malformed payloads.
Rect _parseImageCrop(Map<String, dynamic> data) {
  double read(String key, double fallback) {
    final value = (data[key] as num?)?.toDouble();
    return value != null && value.isFinite ? value : fallback;
  }

  final l = read('cropL', 0).clamp(0.0, 1.0);
  final t = read('cropT', 0).clamp(0.0, 1.0);
  final r = read('cropR', 1).clamp(0.0, 1.0);
  final b = read('cropB', 1).clamp(0.0, 1.0);
  if (r - l <= 0 || b - t <= 0) return ImageElement.fullCrop;
  return Rect.fromLTRB(l, t, r, b);
}

class StickyNoteElement extends CanvasElement {
  final Offset center;
  final double width;
  final double height;
  final String text;
  final Color color;
  final double rotation;
  final double fontSize;
  final int fontWeight;
  final Color textColor;
  final String textAlign;
  final bool autoSize;
  final String? authorUid;

  const StickyNoteElement({
    required super.id,
    required super.z,
    super.hidden,
    super.locked,
    super.opacity,
    required this.center,
    this.width = 160,
    this.height = 160,
    this.text = '',
    this.color = const Color(0xFFFFF9A6),
    this.rotation = 0,
    this.fontSize = 14,
    this.fontWeight = 500,
    this.textColor = const Color(0xFF1E293B),
    this.textAlign = 'left',
    this.autoSize = false,
    this.authorUid,
  });

  StickyNoteElement copyWith({
    int? z,
    bool? hidden,
    bool? locked,
    double? opacity,
    Offset? center,
    double? width,
    double? height,
    String? text,
    Color? color,
    double? rotation,
    double? fontSize,
    int? fontWeight,
    Color? textColor,
    String? textAlign,
    bool? autoSize,
    String? authorUid,
  }) => StickyNoteElement(
    id: id,
    z: z ?? this.z,
    hidden: hidden ?? this.hidden,
    locked: locked ?? this.locked,
    opacity: opacity ?? this.opacity,
    center: center ?? this.center,
    width: width ?? this.width,
    height: height ?? this.height,
    text: text ?? this.text,
    color: color ?? this.color,
    rotation: rotation ?? this.rotation,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    textColor: textColor ?? this.textColor,
    textAlign: textAlign ?? this.textAlign,
    autoSize: autoSize ?? this.autoSize,
    authorUid: authorUid ?? this.authorUid,
  );

  @override
  Map<String, dynamic> toMap() => {
    'type': 'sticky_note',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    'cx': center.dx,
    'cy': center.dy,
    'width': width,
    'height': height,
    'text': text,
    'color': color.toARGB32(),
    'rotation': rotation,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'textColor': textColor.toARGB32(),
    'textAlign': textAlign,
    'autoSize': autoSize,
    if (authorUid != null) 'authorUid': authorUid,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyNoteElement &&
          super == other &&
          center == other.center &&
          width == other.width &&
          height == other.height &&
          text == other.text &&
          color == other.color &&
          rotation == other.rotation &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          textColor == other.textColor &&
          textAlign == other.textAlign &&
          autoSize == other.autoSize &&
          authorUid == other.authorUid;

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    center,
    width,
    height,
    text,
    color,
    rotation,
    fontSize,
    fontWeight,
    textColor,
    textAlign,
    autoSize,
    authorUid,
  );
}

/// A named group of elements. Layers are organisational: painting still uses
/// each element's own `z`, and membership is stored as element ids on the
/// layer so element payloads stay unchanged.
class LayerElement extends CanvasElement {
  final String name;
  final List<String> elementIds;

  const LayerElement({
    required super.id,
    required super.z,
    super.hidden,
    super.locked,
    super.opacity,
    this.name = 'Layer',
    this.elementIds = const [],
  });

  @override
  Map<String, dynamic> toMap() => {
    'type': 'layer',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    'name': name,
    'elementIds': elementIds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerElement &&
          super == other &&
          name == other.name &&
          elementIds.length == other.elementIds.length &&
          elementIds.indexed.every(
            (entry) => other.elementIds[entry.$1] == entry.$2,
          );

  @override
  int get hashCode =>
      super.hashCode ^ name.hashCode ^ Object.hashAll(elementIds);
}

class ConnectorElement extends CanvasElement {
  final String? startElementId;
  final Offset startPoint;
  final String startAnchor;
  final String? endElementId;
  final Offset endPoint;
  final String endAnchor;
  final String lineStyle;
  final Color color;
  final double strokeWidth;
  final bool hasArrowhead;
  final bool startArrowhead;
  final double cornerRadius;
  final List<double>? dashPattern;
  final String label;
  final Color? labelColor;
  final double labelFontSize;

  const ConnectorElement({
    required super.id,
    required super.z,
    super.hidden,
    super.locked,
    super.opacity,
    this.startElementId,
    required this.startPoint,
    this.startAnchor = 'center',
    this.endElementId,
    required this.endPoint,
    this.endAnchor = 'center',
    this.lineStyle = 'straight',
    this.color = const Color(0xFF000000),
    this.strokeWidth = 2.5,
    this.hasArrowhead = true,
    this.startArrowhead = false,
    this.cornerRadius = 0,
    this.dashPattern,
    this.label = '',
    this.labelColor,
    this.labelFontSize = 14,
  });

  /// `hasArrowhead` is the legacy end-arrow flag; new code reads [endArrowhead].
  bool get endArrowhead => hasArrowhead;

  @override
  Map<String, dynamic> toMap() => {
    'type': 'connector',
    'z': z,
    'hidden': hidden,
    'locked': locked,
    'opacity': opacity,
    if (startElementId != null) 'startElementId': startElementId,
    'sx': startPoint.dx,
    'sy': startPoint.dy,
    'startAnchor': startAnchor,
    if (endElementId != null) 'endElementId': endElementId,
    'ex': endPoint.dx,
    'ey': endPoint.dy,
    'endAnchor': endAnchor,
    'lineStyle': lineStyle,
    'color': color.value,
    'strokeWidth': strokeWidth,
    'hasArrowhead': hasArrowhead,
    'endArrowhead': hasArrowhead,
    'startArrowhead': startArrowhead,
    'cornerRadius': cornerRadius,
    if (dashPattern != null) 'dashPattern': dashPattern,
    'label': label,
    if (labelColor != null) 'labelColor': labelColor!.value,
    'labelFontSize': labelFontSize,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectorElement &&
          super == other &&
          startElementId == other.startElementId &&
          startPoint == other.startPoint &&
          startAnchor == other.startAnchor &&
          endElementId == other.endElementId &&
          endPoint == other.endPoint &&
          endAnchor == other.endAnchor &&
          lineStyle == other.lineStyle &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          hasArrowhead == other.hasArrowhead &&
          startArrowhead == other.startArrowhead &&
          (cornerRadius - other.cornerRadius).abs() < 1e-6 &&
          _dashEquals(dashPattern, other.dashPattern) &&
          label == other.label &&
          labelColor == other.labelColor &&
          (labelFontSize - other.labelFontSize).abs() < 1e-6;

  @override
  int get hashCode =>
      super.hashCode ^
      startElementId.hashCode ^
      startPoint.hashCode ^
      startAnchor.hashCode ^
      endElementId.hashCode ^
      endPoint.hashCode ^
      endAnchor.hashCode ^
      lineStyle.hashCode ^
      color.hashCode ^
      strokeWidth.hashCode ^
      hasArrowhead.hashCode ^
      startArrowhead.hashCode ^
      cornerRadius.hashCode ^
      Object.hashAll(dashPattern ?? const []) ^
      label.hashCode ^
      labelColor.hashCode ^
      labelFontSize.hashCode;

  static bool _dashEquals(List<double>? a, List<double>? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-6) return false;
    }
    return true;
  }
}
