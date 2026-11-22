import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/brush_preset.dart';
import '../models/canvas_element.dart';
import '../../../domain/models/canvas/canvas_board_settings.dart';
import '../../../domain/models/canvas/canvas_shape_type.dart';

export '../../../domain/services/canvas/canvas_render_utils.dart';

/// Single source of truth for canvas element geometry.
///
/// The painter, hit-testing, eraser, connector anchors, selection overlay and
/// exporters all resolve sizes and bounds here so they cannot drift apart.
/// Text keeps its historical convention: [TextElement.center] is the top-left
/// corner of the text box, not its middle.
class CanvasTextLayout {
  const CanvasTextLayout._(this.painter, this.size);

  final TextPainter painter;
  final Size size;

  static const double defaultFontSize = 16;
  static const int defaultFontWeight = 600;
  static const double defaultLineHeight = 1.2;
  static const double defaultMaxWidth = 220;
  static const double defaultPadding = 4;

  static FontWeight fontWeightFromValue(int value) {
    final index = ((value / 100).round() - 1).clamp(
      0,
      FontWeight.values.length - 1,
    );
    return FontWeight.values[index];
  }

  static TextAlign textAlignFromName(String name) {
    switch (name) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  static String textAlignName(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
        return 'right';
      case TextAlign.justify:
        return 'justify';
      default:
        return 'left';
    }
  }

  /// Lays out [text] exactly the way the canvas paints it.
  ///
  /// [maxWidth] is the wrapping width; [maxLines] of 0 means unlimited.
  static CanvasTextLayout layout({
    required String text,
    double fontSize = defaultFontSize,
    int fontWeight = defaultFontWeight,
    String? fontFamily,
    String textAlign = 'left',
    double lineHeight = defaultLineHeight,
    double maxWidth = defaultMaxWidth,
    int maxLines = 0,
    Color color = const Color(0xFF000000),
  }) {
    final safeWidth = maxWidth.isFinite && maxWidth > 0
        ? maxWidth
        : defaultMaxWidth;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeightFromValue(fontWeight),
          fontFamily: fontFamily,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlignFromName(textAlign),
      maxLines: maxLines > 0 ? maxLines : null,
      ellipsis: maxLines > 0 ? '…' : null,
    )..layout(maxWidth: safeWidth);
    return CanvasTextLayout._(painter, Size(painter.width, painter.height));
  }

  static CanvasTextLayout forElement(TextElement element) {
    return layout(
      text: element.text,
      fontSize: element.fontSize,
      fontWeight: element.fontWeight,
      fontFamily: element.fontFamily,
      textAlign: element.textAlign,
      lineHeight: element.lineHeight,
      maxWidth: element.width > 0 ? element.width : defaultMaxWidth,
      maxLines: element.maxLines,
      color: element.color,
    );
  }
}

/// The on-canvas box of a text element, anchored at its top-left point and
/// sized from the persisted measurements (falling back to a live layout).
Rect textElementRect(TextElement element) {
  final measured = element.width > 0 && element.height > 0
      ? null
      : CanvasTextLayout.forElement(element);
  final width = element.width > 0
      ? element.width
      : (measured?.size.width ?? CanvasTextLayout.defaultMaxWidth);
  final height = element.height > 0
      ? element.height
      : (measured?.size.height ?? CanvasTextLayout.defaultFontSize);
  return Rect.fromLTWH(element.center.dx, element.center.dy, width, height);
}

/// Legacy per-type aspect ratios used only when a shape payload has no
/// explicit width/height (old boards). New shapes carry width/height and are
/// rendered from those, so these are creation/migration defaults, not render
/// rules.
(double, double) shapeLegacyAspect(ShapeElementRectType type) {
  switch (type) {
    case ShapeElementRectType.rectangle:
      return (1.35, 0.8);
    case ShapeElementRectType.ellipse:
      return (1.3, 0.85);
    case ShapeElementRectType.arrow:
      return (1.3, 0.7);
    case ShapeElementRectType.other:
      return (1.0, 1.0);
  }
}

/// The on-canvas box of a shape. Explicit width/height win; otherwise the
/// legacy `size × aspect` derivation keeps old boards identical. Line/arrow
/// store a flat segment (height 0) once width/height are written.
Rect shapeElementRect(ShapeElement element) {
  final aspect = shapeLegacyAspect(element.rectType);
  final explicit = element.width > 0 || element.height > 0;
  final width = explicit ? element.width : element.size * aspect.$1;
  final height = explicit ? element.height : element.size * aspect.$2;
  return Rect.fromCenter(center: element.center, width: width, height: height);
}

/// Small helper so the aspect switch above reads as data, not a shape import.
enum ShapeElementRectType { rectangle, ellipse, arrow, other }

extension ShapeRectTypeX on ShapeElement {
  ShapeElementRectType get rectType {
    switch (shapeType.name) {
      case 'rectangle':
        return ShapeElementRectType.rectangle;
      case 'ellipse':
        return ShapeElementRectType.ellipse;
      case 'arrow':
        return ShapeElementRectType.arrow;
      default:
        return ShapeElementRectType.other;
    }
  }

  bool get isLinear =>
      shapeType == CanvasShapeType.line || shapeType == CanvasShapeType.arrow;
}

/// The shape outline in its local frame: centred on the origin and unrotated.
///
/// The painter and exporters translate/rotate the canvas around it; hit tests
/// inverse-rotate the tap into this frame. Sharing one path keeps painting,
/// selection, erasing and export from drifting apart.
Path buildShapePath(ShapeElement element) {
  final rect = shapeElementRect(element);
  final hw = rect.width / 2;
  final hh = rect.height / 2;
  final local = Rect.fromCenter(
    center: Offset.zero,
    width: rect.width,
    height: rect.height,
  );
  final path = Path();
  switch (element.shapeType) {
    case CanvasShapeType.square:
    case CanvasShapeType.rectangle:
      if (element.borderRadius > 0) {
        path.addRRect(
          RRect.fromRectAndRadius(local, Radius.circular(element.borderRadius)),
        );
      } else {
        path.addRect(local);
      }
    case CanvasShapeType.circle:
    case CanvasShapeType.ellipse:
      path.addOval(local);
    case CanvasShapeType.triangle:
      path
        ..moveTo(0, -hh)
        ..lineTo(-hw, hh)
        ..lineTo(hw, hh)
        ..close();
    case CanvasShapeType.diamond:
      path
        ..moveTo(0, -hh)
        ..lineTo(hw, 0)
        ..lineTo(0, hh)
        ..lineTo(-hw, 0)
        ..close();
    case CanvasShapeType.star:
      for (var i = 0; i < 5; i++) {
        final outerAngle = (math.pi / 2) + i * (2 * math.pi / 5);
        final innerAngle = outerAngle + (math.pi / 5);
        final outer = Offset(
          math.cos(outerAngle) * hw,
          -math.sin(outerAngle) * hh,
        );
        final inner = Offset(
          math.cos(innerAngle) * hw * 0.5,
          -math.sin(innerAngle) * hh * 0.5,
        );
        if (i == 0) {
          path.moveTo(outer.dx, outer.dy);
        } else {
          path.lineTo(outer.dx, outer.dy);
        }
        path.lineTo(inner.dx, inner.dy);
      }
      path.close();
    case CanvasShapeType.pentagon:
      _addRegularPolygon(path, 5, hw, hh);
    case CanvasShapeType.hexagon:
      _addRegularPolygon(path, 6, hw, hh);
    case CanvasShapeType.semicircle:
      // Top-half pie, matching the interactive painter's drawArc(pi, pi).
      path
        ..moveTo(0, 0)
        ..lineTo(-hw, 0)
        ..arcTo(local, math.pi, math.pi, false)
        ..close();
    case CanvasShapeType.line:
    case CanvasShapeType.arrow:
      path
        ..moveTo(-hw, 0)
        ..lineTo(hw, 0);
  }
  if (element.flipH || element.flipV) {
    final sx = element.flipH ? -1.0 : 1.0;
    final sy = element.flipV ? -1.0 : 1.0;
    return path.transform(Matrix4.diagonal3Values(sx, sy, 1.0).storage);
  }
  return path;
}

void _addRegularPolygon(Path path, int sides, double hw, double hh) {
  for (var i = 0; i < sides; i++) {
    final angle = (math.pi / 2) + i * (2 * math.pi / sides);
    final point = Offset(math.cos(angle) * hw, -math.sin(angle) * hh);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
}

/// Converts [source] into a dashed path using [pattern] (on, off, … lengths).
/// Flutter has no native dash paint, so this walks each contour's metrics.
/// An empty/invalid pattern returns [source] unchanged (solid).
Path dashPath(Path source, List<double>? pattern) {
  if (pattern == null) return source;
  final lengths = pattern.where((d) => d.isFinite && d > 0).toList();
  if (lengths.length < 2) return source;
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var index = 0;
    var draw = true;
    while (distance < metric.length) {
      final len = lengths[index % lengths.length];
      final end = math.min(distance + len, metric.length);
      if (draw && end > distance) {
        result.addPath(metric.extractPath(distance, end), Offset.zero);
      }
      distance = end;
      draw = !draw;
      index++;
    }
  }
  return result;
}

/// A filled arrowhead triangle with its tip at [tip], pointing along
/// [direction] (radians). Shared by the painter and exporters.
Path shapeArrowheadPath(Offset tip, double direction, double length) {
  final pts = shapeArrowheadPoints(tip, direction, length);
  return Path()
    ..moveTo(pts[0].dx, pts[0].dy)
    ..lineTo(pts[1].dx, pts[1].dy)
    ..lineTo(pts[2].dx, pts[2].dy)
    ..close();
}

/// The three vertices (tip first) of [shapeArrowheadPath], for vector export.
List<Offset> shapeArrowheadPoints(Offset tip, double direction, double length) {
  const spread = 0.45;
  final back1 =
      tip -
      Offset(math.cos(direction - spread), math.sin(direction - spread)) *
          length;
  final back2 =
      tip -
      Offset(math.cos(direction + spread), math.sin(direction + spread)) *
          length;
  return <Offset>[tip, back1, back2];
}

/// Renders a shape exactly the same way on the interactive canvas and in
/// PNG/PDF export: independent fill and stroke paints, stroke opacity, dashes,
/// arrowheads for line/arrow, and a centred, clipped label.
/// Builds the shader for a gradient fill, or null for a solid/none fill.
ui.Shader? buildShapeFillShader(ShapeElement shape, Rect rect) {
  final mode = shape.effectiveFillMode;
  if (mode != 'linear' && mode != 'radial') return null;
  final colors = [shape.resolvedGradientStart, shape.resolvedGradientEnd];
  if (mode == 'radial') {
    return ui.Gradient.radial(
      Offset.zero,
      math.max(rect.width, rect.height) / 2,
      colors,
    );
  }
  final angle = shape.gradientAngle * math.pi / 180;
  final direction = Offset(math.cos(angle), math.sin(angle));
  final half =
      math.sqrt(rect.width * rect.width + rect.height * rect.height) / 2;
  return ui.Gradient.linear(-direction * half, direction * half, colors);
}

void paintShapeElement(Canvas canvas, ShapeElement shape) {
  final rect = shapeElementRect(shape);
  final path = buildShapePath(shape);
  final hw = rect.width / 2;

  canvas.save();
  canvas.translate(shape.center.dx, shape.center.dy);
  if (shape.rotation != 0) canvas.rotate(shape.rotation);

  if (shape.effectiveFillMode != 'none' && !shape.isLinear) {
    final paint = Paint()..style = PaintingStyle.fill;
    final shader = buildShapeFillShader(shape, rect);
    if (shader != null) {
      paint.shader = shader;
    } else {
      paint.color = shape.resolvedFillColor;
    }
    canvas.drawPath(path, paint);
  }

  final strokeColor = shape.resolvedStrokeColor.withValues(
    alpha: shape.strokeOpacity.clamp(0.0, 1.0),
  );
  if (shape.strokeWidth > 0) {
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outline = dashPath(path, shape.dashPattern);
    canvas.drawPath(outline, strokePaint);
  }

  if (shape.isLinear) {
    final headLen = math.min(18.0, hw * 0.45).clamp(8.0, 24.0);
    final headPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    final endX = shape.flipH ? -hw : hw;
    final endDir = shape.flipH ? math.pi : 0.0;
    final startX = -endX;
    final startDir = shape.flipH ? 0.0 : math.pi;
    if (shape.endArrowhead) {
      canvas.drawPath(
        shapeArrowheadPath(Offset(endX, 0), endDir, headLen),
        headPaint,
      );
    }
    if (shape.startArrowhead) {
      canvas.drawPath(
        shapeArrowheadPath(Offset(startX, 0), startDir, headLen),
        headPaint,
      );
    }
  }

  if (shape.label.isNotEmpty) {
    _paintShapeLabel(canvas, shape, rect);
  }

  canvas.restore();
}

void _paintShapeLabel(Canvas canvas, ShapeElement shape, Rect rect) {
  const padding = 6.0;
  final maxWidth = math.max(1.0, rect.width - padding * 2);
  final maxHeight = math.max(1.0, rect.height - padding * 2);
  final lineHeight = CanvasTextLayout.defaultLineHeight;
  final maxLines = math.max(
    1,
    (maxHeight / (shape.labelFontSize * lineHeight)).floor(),
  );
  final layout = CanvasTextLayout.layout(
    text: shape.label,
    fontSize: shape.labelFontSize,
    fontWeight: shape.labelFontWeight,
    textAlign: shape.labelTextAlign,
    lineHeight: lineHeight,
    maxWidth: maxWidth,
    maxLines: maxLines,
    color: shape.labelColor ?? const Color(0xFF000000),
  );
  // TextPainter.width can shrink to the intrinsic text width, so centre the
  // laid-out block within the box rather than trusting textAlign alone.
  final double dx;
  switch (shape.labelTextAlign) {
    case 'left':
      dx = -maxWidth / 2;
    case 'right':
      dx = maxWidth / 2 - layout.size.width;
    default:
      dx = -layout.size.width / 2;
  }
  layout.painter.paint(canvas, Offset(dx, -layout.size.height / 2));
}

/// Samples a path outline into a polyline for proximity hit-testing.
List<Offset> _samplePathOutline(Path path, {double step = 4.0}) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    final count = math.max(2, (metric.length / step).ceil());
    for (var i = 0; i <= count; i++) {
      final tangent = metric.getTangentForOffset(metric.length * (i / count));
      if (tangent != null) points.add(tangent.position);
    }
  }
  return points;
}

/// Whether [point] lands on the shape as painted: interior for closed shapes,
/// the stroked segment for line/arrow, with a stroke-width tolerance.
bool shapeContainsPoint(
  ShapeElement element,
  Offset point, {
  double tolerance = 0,
}) {
  final local =
      rotatePoint(point, element.center, -element.rotation) - element.center;
  final rect = shapeElementRect(element);
  final tol = element.strokeWidth / 2 + tolerance;
  if (element.isLinear) {
    final hw = rect.width / 2;
    return distanceToSegment(local, Offset(-hw, 0), Offset(hw, 0)) <= tol;
  }
  final path = buildShapePath(element);
  if (path.contains(local)) return true;
  if (!path.getBounds().inflate(tol).contains(local)) return false;
  return distanceToPolyline(_samplePathOutline(path), local) <= tol;
}

/// Rotates [point] around [pivot] by [angle] radians.
Offset rotatePoint(Offset point, Offset pivot, double angle) {
  if (angle == 0) return point;
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  final dx = point.dx - pivot.dx;
  final dy = point.dy - pivot.dy;
  return Offset(pivot.dx + dx * cos - dy * sin, pivot.dy + dx * sin + dy * cos);
}

/// Axis-aligned bounds of [rect] after rotating it around its centre.
Rect rotatedRectBounds(Rect rect, double rotation) {
  if (rotation == 0) return rect;
  final center = rect.center;
  final corners = <Offset>[
    rotatePoint(rect.topLeft, center, rotation),
    rotatePoint(rect.topRight, center, rotation),
    rotatePoint(rect.bottomRight, center, rotation),
    rotatePoint(rect.bottomLeft, center, rotation),
  ];
  var minX = corners.first.dx;
  var minY = corners.first.dy;
  var maxX = corners.first.dx;
  var maxY = corners.first.dy;
  for (final corner in corners.skip(1)) {
    if (corner.dx < minX) minX = corner.dx;
    if (corner.dy < minY) minY = corner.dy;
    if (corner.dx > maxX) maxX = corner.dx;
    if (corner.dy > maxY) maxY = corner.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// The on-canvas box of a frame. Frames are plain sections: no title strip
/// and no painted label, matching how Figma frames read on a canvas.
Rect frameRect(FrameElement frame) => Rect.fromCenter(
  center: frame.center,
  width: math.max(1, frame.width),
  height: math.max(1, frame.height),
);

/// Whether [element] sits fully inside [frame]'s box.
///
/// Membership is geometric in v1 (no per-element parent field). A small slack
/// keeps stroked shapes from falling out of their frame. Layers and the frame
/// itself never belong to a frame.
bool frameContainsElement(FrameElement frame, CanvasElement element) {
  if (identical(frame, element) || element is LayerElement) return false;
  final bounds = elementBounds(element);
  if (bounds == null) return false;
  final box = frameRect(frame).inflate(2);
  return box.contains(bounds.topLeft) && box.contains(bounds.bottomRight);
}

List<CanvasElement> elementsContainedByFrame(
  FrameElement frame,
  Iterable<CanvasElement> elements,
) => elements
    .where((element) => frameContainsElement(frame, element))
    .toList(growable: false);

/// Returns the screen-space viewport offset delta needed to auto-pan the
/// canvas when a dragged pointer approaches any edge or corner of [canvasSize].
/// Returns `Offset.zero` when [localPosition] is inside the central safe area.
Offset canvasEdgeAutoPanDelta({
  required Offset localPosition,
  required Size canvasSize,
  double edgeMargin = 56.0,
  double maxStep = 12.0,
}) {
  if (canvasSize.width <= 0 || canvasSize.height <= 0 || edgeMargin <= 0) {
    return Offset.zero;
  }
  double panX = 0.0;
  if (localPosition.dx < edgeMargin) {
    final t = ((edgeMargin - localPosition.dx) / edgeMargin).clamp(0.0, 1.0);
    panX = maxStep * t;
  } else if (localPosition.dx > canvasSize.width - edgeMargin) {
    final t = ((localPosition.dx - (canvasSize.width - edgeMargin)) / edgeMargin)
        .clamp(0.0, 1.0);
    panX = -maxStep * t;
  }

  double panY = 0.0;
  if (localPosition.dy < edgeMargin) {
    final t = ((edgeMargin - localPosition.dy) / edgeMargin).clamp(0.0, 1.0);
    panY = maxStep * t;
  } else if (localPosition.dy > canvasSize.height - edgeMargin) {
    final t = ((localPosition.dy - (canvasSize.height - edgeMargin)) / edgeMargin)
        .clamp(0.0, 1.0);
    panY = -maxStep * t;
  }

  if (panX == 0.0 && panY == 0.0) return Offset.zero;
  return Offset(panX, panY);
}

/// The id of the frame [element] sits on: its explicit `frameId` when that
/// frame still exists. Background elements that only overlap geometrically
/// never belong to a frame unless explicitly dragged onto or captured by it.
/// Frames and layers never have a host.
String? hostFrameId(CanvasElement element, Iterable<CanvasElement> all) {
  if (element is FrameElement || element is LayerElement) return null;
  final targetId = element.frameId;
  if (targetId == null) return null;
  for (final candidate in all) {
    if (candidate is FrameElement && candidate.id == targetId) {
      return candidate.id;
    }
  }
  return null;
}

/// Whether any part of [element]'s bounds overlaps [frame]'s box.
bool frameOverlapsElement(FrameElement frame, CanvasElement element) {
  if (identical(frame, element) ||
      element is FrameElement ||
      element is LayerElement) {
    return false;
  }
  final bounds = elementBounds(element);
  if (bounds == null) return false;
  return frameRect(frame).overlaps(bounds);
}

/// Returns the clipping [FrameElement] that should clip [element] (its attached
/// `frameId` when that frame has `clipContents` enabled), or `null` if none.
FrameElement? enclosingClipFrame(
  CanvasElement element,
  List<FrameElement> clipFrames,
) {
  if (clipFrames.isEmpty ||
      element is FrameElement ||
      element is LayerElement ||
      element.frameId == null) {
    return null;
  }
  final bounds = elementBounds(element);
  if (bounds == null) return null;
  for (final frame in clipFrames.reversed) {
    if (frame.id == element.frameId &&
        frame.clipContents &&
        frameRect(frame).overlaps(bounds)) {
      return frame;
    }
  }
  return null;
}

/// Paints the background paper pattern (dots, grid, lines, isometric) inside
/// [worldRect] in world coordinates so live canvas and exports match.
void paintBoardBackgroundPattern(
  Canvas canvas,
  Rect worldRect,
  CanvasBoardSettings settings, {
  double strokeScale = 1.0,
}) {
  if (settings.backgroundPattern == CanvasBackgroundPattern.none) return;
  final step = settings.patternSpacing > 0 ? settings.patternSpacing : 32.0;
  if (step * strokeScale < 4) return;
  final isDark = settings.backgroundColor.computeLuminance() < 0.4;
  final color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1);
  final paint = Paint()
    ..color = color
    ..strokeWidth = 1.0 / (strokeScale > 0 ? strokeScale : 1.0);
  final firstX = (worldRect.left / step).floorToDouble() * step;
  final firstY = (worldRect.top / step).floorToDouble() * step;

  canvas.save();
  canvas.clipRect(worldRect);
  switch (settings.backgroundPattern) {
    case CanvasBackgroundPattern.none:
      break;
    case CanvasBackgroundPattern.dots:
      final dots = Paint()..color = color;
      final radius = 1.3 / (strokeScale > 0 ? strokeScale : 1.0);
      for (var x = firstX; x <= worldRect.right; x += step) {
        for (var y = firstY; y <= worldRect.bottom; y += step) {
          canvas.drawCircle(Offset(x, y), radius, dots);
        }
      }
      break;
    case CanvasBackgroundPattern.grid:
      for (var x = firstX; x <= worldRect.right; x += step) {
        canvas.drawLine(
          Offset(x, worldRect.top),
          Offset(x, worldRect.bottom),
          paint,
        );
      }
      for (var y = firstY; y <= worldRect.bottom; y += step) {
        canvas.drawLine(
          Offset(worldRect.left, y),
          Offset(worldRect.right, y),
          paint,
        );
      }
      break;
    case CanvasBackgroundPattern.lines:
      for (var y = firstY; y <= worldRect.bottom; y += step) {
        canvas.drawLine(
          Offset(worldRect.left, y),
          Offset(worldRect.right, y),
          paint,
        );
      }
      break;
    case CanvasBackgroundPattern.isometric:
      final isoStep = step * 1.5;
      final h = worldRect.height;
      final start = (worldRect.left - h) / isoStep;
      final firstIso = start.floorToDouble() * isoStep;
      for (var x = firstIso; x <= worldRect.right + h; x += isoStep) {
        canvas.drawLine(
          Offset(x, worldRect.top),
          Offset(x + h, worldRect.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(x, worldRect.bottom),
          Offset(x + h, worldRect.top),
          paint,
        );
      }
      break;
  }
  canvas.restore();
}

/// Paints a frame identically on the interactive canvas and in PNG/PDF
/// export: an opaque paper surface tinted with the frame colour and a border.
/// Frames carry no heading.
void paintFrameElement(Canvas canvas, FrameElement frame) {
  final rect = frameRect(frame);
  final radius = math.min(
    frame.cornerRadius,
    math.min(rect.width, rect.height) / 2,
  );
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  final color = frame.color;
  final fillColor = Color.alphaBlend(
    color.withValues(alpha: 0.12),
    const Color(0xFFFFFFFF),
  );

  canvas.drawRRect(rrect, Paint()..color = fillColor);
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

/// Bounds of any element, including rotation and stroke width.
Rect? elementBounds(CanvasElement element, {double padding = 0}) {
  switch (element) {
    case StrokeElement e:
      if (e.points.isEmpty) return null;
      final style = resolveBrushStyle(
        brushType: e.brushId.isNotEmpty ? e.brushId : e.brushType,
        strokeWidth: e.strokeWidth,
        strokeOpacity: e.opacity,
      );
      final effectiveWidth = math.max(e.strokeWidth, style.width);
      final blurPad = style.blurSigma > 0 ? style.blurSigma * 2 : 0.0;
      final jitterPad = style.jitter > 0
          ? (effectiveWidth / 2) * style.jitter
          : 0.0;
      var minX = e.points.first.dx;
      var minY = e.points.first.dy;
      var maxX = e.points.first.dx;
      var maxY = e.points.first.dy;
      for (final point in e.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
      return Rect.fromLTRB(
        minX,
        minY,
        maxX,
        maxY,
      ).inflate(effectiveWidth / 2 + blurPad + jitterPad + padding);
    case ShapeElement e:
      return rotatedRectBounds(
        shapeElementRect(e),
        e.rotation,
      ).inflate(e.strokeWidth / 2 + padding);
    case TextElement e:
      return rotatedRectBounds(textElementRect(e), e.rotation).inflate(padding);
    case ImageElement e:
      return rotatedRectBounds(
        Rect.fromCenter(
          center: e.center,
          width: e.width > 0 ? e.width : 100,
          height: e.height > 0 ? e.height : 100,
        ),
        e.rotation,
      ).inflate(padding);
    case StickyNoteElement e:
      return rotatedRectBounds(
        Rect.fromCenter(
          center: e.center,
          width: e.width > 0 ? e.width : 160,
          height: e.height > 0 ? e.height : 160,
        ),
        e.rotation,
      ).inflate(padding);
    case FrameElement e:
      return frameRect(e).inflate(1.5 + padding);
    case TableElement e:
      return rotatedRectBounds(
        tableElementRect(e),
        e.rotation,
      ).inflate(e.borderWidth / 2 + padding);
    case ConnectorElement e:
      final points = connectorPolyline(
        e.startPoint,
        e.endPoint,
        e.lineStyle,
        cornerRadius: e.cornerRadius,
      );
      var minX = points.first.dx;
      var minY = points.first.dy;
      var maxX = points.first.dx;
      var maxY = points.first.dy;
      for (final point in points.skip(1)) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
      return Rect.fromLTRB(
        minX,
        minY,
        maxX,
        maxY,
      ).inflate(e.strokeWidth + padding);
    case LayerElement _:
      return null;
  }
}

/// Distance from [point] to the segment [start]–[end].
double distanceToSegment(Offset point, Offset start, Offset end) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return (point - start).distance;
  final t =
      (((point.dx - start.dx) * dx) + ((point.dy - start.dy) * dy)) /
      lengthSquared;
  final clamped = t.clamp(0.0, 1.0);
  return (point - Offset(start.dx + clamped * dx, start.dy + clamped * dy))
      .distance;
}

/// Closed interior path for a hand-drawn shape, or null when the stroke is
/// still open.
///
/// The start and end have to meet within a small tolerance so an open arc or
/// squiggle can never be treated as an enclosed region. The tolerance scales
/// with the ink width, which also bridges the natural gap left by a quick
/// hand-drawn circle.
Path? strokeClosedFillPath(
  StrokeElement stroke, {
  double closureTolerance = 24,
}) {
  if (stroke.points.length < 3) return null;
  final tolerance = math.max(stroke.strokeWidth * 3.0, closureTolerance);
  if ((stroke.points.last - stroke.points.first).distance > tolerance) {
    return null;
  }
  return Path()..addPolygon(stroke.points, true);
}

/// Whether [point] is inside the area enclosed by a closed freehand stroke.
///
/// [closureTolerance] is a world-space gap allowance; callers pass a
/// screen-constant value divided by the viewport scale so a visually closed
/// loop remains fillable at every zoom level.
bool strokeContainsClosedRegion(
  StrokeElement stroke,
  Offset point, {
  double closureTolerance = 24,
}) {
  final path = strokeClosedFillPath(stroke, closureTolerance: closureTolerance);
  if (path == null || !path.getBounds().contains(point)) return false;
  return path.contains(point);
}

/// Shortest distance from [point] to a sampled polyline.
double distanceToPolyline(List<Offset> points, Offset point) {
  if (points.isEmpty) return double.infinity;
  if (points.length == 1) return (point - points.first).distance;
  var best = double.infinity;
  for (var i = 0; i < points.length - 1; i++) {
    final distance = distanceToSegment(point, points[i], points[i + 1]);
    if (distance < best) best = distance;
  }
  return best;
}

/// Samples the path a connector is actually painted along.
///
/// Mirrors [connectorPath]: curved connectors are cubics whose control points
/// sit on the horizontal chord, orthogonal ones step through the midpoint with
/// optional rounded corners. Used for hit-testing, marquee selection and
/// arrowhead orientation.
List<Offset> connectorPolyline(
  Offset start,
  Offset end,
  String lineStyle, {
  int samples = 24,
  double cornerRadius = 0,
}) {
  if (_isCurvedConnector(lineStyle)) {
    final (cp1, cp2) = _curvedControls(start, end);
    return <Offset>[
      for (var i = 0; i <= samples; i++)
        _cubicAt(start, cp1, cp2, end, i / samples),
    ];
  }
  if (_isOrthogonalConnector(lineStyle)) {
    if (cornerRadius <= 0) return _orthogonalSteps(start, end);
    return _samplePath(
      connectorPath(start, end, lineStyle, cornerRadius: cornerRadius),
      samples: samples,
    );
  }
  return <Offset>[start, end];
}

bool _isCurvedConnector(String lineStyle) =>
    lineStyle == 'curved' || lineStyle == 'bezier';

bool _isOrthogonalConnector(String lineStyle) =>
    lineStyle == 'orthogonal' || lineStyle == 'step';

(Offset, Offset) _curvedControls(Offset start, Offset end) {
  final dx = (end.dx - start.dx).abs();
  final dy = (end.dy - start.dy).abs();
  final controlOffset = math.max(dx, dy) * 0.45;
  final sign = end.dx > start.dx ? 1.0 : -1.0;
  return (
    Offset(start.dx + sign * controlOffset, start.dy),
    Offset(end.dx - sign * controlOffset, end.dy),
  );
}

List<Offset> _orthogonalSteps(Offset start, Offset end) {
  final midX = (start.dx + end.dx) / 2;
  return <Offset>[start, Offset(midX, start.dy), Offset(midX, end.dy), end];
}

/// Walks a connector's outline once, emitting the same drawing commands to
/// whichever sink is listening, so the Flutter [Path] and SVG path data are
/// built from identical geometry.
void _traceConnector(
  Offset start,
  Offset end,
  String lineStyle,
  double cornerRadius, {
  required void Function(Offset p) moveTo,
  required void Function(Offset p) lineTo,
  required void Function(Offset control, Offset p) quadTo,
  required void Function(Offset c1, Offset c2, Offset p) cubicTo,
}) {
  moveTo(start);
  if (_isCurvedConnector(lineStyle)) {
    final (cp1, cp2) = _curvedControls(start, end);
    cubicTo(cp1, cp2, end);
    return;
  }
  if (!_isOrthogonalConnector(lineStyle)) {
    lineTo(end);
    return;
  }
  final points = _orthogonalSteps(start, end);
  for (var i = 1; i < points.length - 1; i++) {
    final prev = points[i - 1];
    final curr = points[i];
    final next = points[i + 1];
    final inVec = curr - prev;
    final outVec = next - curr;
    final inLen = inVec.distance;
    final outLen = outVec.distance;
    if (cornerRadius <= 0 || inLen < 1e-6 || outLen < 1e-6) {
      lineTo(curr);
      continue;
    }
    // Clamped to half of each adjoining segment so corners never overlap.
    final r = math.min(cornerRadius, math.min(inLen, outLen) / 2);
    lineTo(curr - inVec / inLen * r);
    quadTo(curr, curr + outVec / outLen * r);
  }
  lineTo(end);
}

/// The exact path a connector is painted along, shared by the painter, the
/// creation preview and every exporter so the rendered curve cannot drift.
///
/// Curved connectors are cubics with control points on the horizontal chord;
/// orthogonal ones step through the midpoint with optional rounded corners;
/// anything else is a straight segment.
Path connectorPath(
  Offset start,
  Offset end,
  String lineStyle, {
  double cornerRadius = 0,
}) {
  final path = Path();
  _traceConnector(
    start,
    end,
    lineStyle,
    cornerRadius,
    moveTo: (p) => path.moveTo(p.dx, p.dy),
    lineTo: (p) => path.lineTo(p.dx, p.dy),
    quadTo: (c, p) => path.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy),
    cubicTo: (c1, c2, p) =>
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy),
  );
  return path;
}

/// [connectorPath] as SVG path data (`d` attribute), offset by [origin].
String connectorSvgPathData(
  Offset start,
  Offset end,
  String lineStyle, {
  double cornerRadius = 0,
  Offset origin = Offset.zero,
}) {
  final out = <String>[];
  String xy(Offset p) =>
      '${_svgNum(p.dx - origin.dx)} ${_svgNum(p.dy - origin.dy)}';
  _traceConnector(
    start,
    end,
    lineStyle,
    cornerRadius,
    moveTo: (p) => out.add('M ${xy(p)}'),
    lineTo: (p) => out.add('L ${xy(p)}'),
    quadTo: (c, p) => out.add('Q ${xy(c)} ${xy(p)}'),
    cubicTo: (c1, c2, p) => out.add('C ${xy(c1)} ${xy(c2)} ${xy(p)}'),
  );
  return out.join(' ');
}

String _svgNum(double v) {
  final rounded = (v * 100).roundToDouble() / 100;
  return rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

/// Evenly samples a single-contour [path] into a polyline for hit-testing.
List<Offset> _samplePath(Path path, {int samples = 24}) {
  final metric = _firstMetric(path);
  if (metric == null || metric.length <= 0) {
    final b = path.getBounds();
    return <Offset>[b.topLeft, b.bottomRight];
  }
  return <Offset>[
    for (var i = 0; i <= samples; i++)
      metric.getTangentForOffset(metric.length * i / samples)!.position,
  ];
}

/// The point halfway along the painted connector path, where its label sits.
Offset connectorMidpoint(
  Offset start,
  Offset end,
  String lineStyle, {
  double cornerRadius = 0,
}) {
  final path = connectorPath(start, end, lineStyle, cornerRadius: cornerRadius);
  final metric = _firstMetric(path);
  if (metric == null || metric.length <= 0) return (start + end) / 2;
  final tangent = metric.getTangentForOffset(metric.length / 2);
  return tangent?.position ?? (start + end) / 2;
}

// PathMetrics is single-pass, so it must be read through one iterator.
PathMetric? _firstMetric(Path path) {
  final iterator = path.computeMetrics().iterator;
  return iterator.moveNext() ? iterator.current : null;
}

/// Filled arrowhead triangles (tip first) for the enabled connector ends,
/// oriented along the path tangent and sized from [strokeWidth].
List<List<Offset>> connectorArrowheads(
  Offset start,
  Offset end,
  String lineStyle, {
  required double strokeWidth,
  double cornerRadius = 0,
  bool startArrowhead = false,
  bool endArrowhead = true,
}) {
  if (!startArrowhead && !endArrowhead) return const <List<Offset>>[];
  final points = connectorPolyline(
    start,
    end,
    lineStyle,
    cornerRadius: cornerRadius,
  );
  if (points.length < 2) return const <List<Offset>>[];
  final headLen = (strokeWidth * 4).clamp(12.0, 26.0);
  double towards(Offset from, Offset to) =>
      math.atan2(to.dy - from.dy, to.dx - from.dx);
  return <List<Offset>>[
    if (endArrowhead)
      shapeArrowheadPoints(
        end,
        towards(points[points.length - 2], points.last),
        headLen,
      ),
    if (startArrowhead)
      shapeArrowheadPoints(start, towards(points[1], points.first), headLen),
  ];
}

/// A laid-out connector label and the pill drawn behind it.
class ConnectorLabelBox {
  const ConnectorLabelBox._(this.layout, this.pill);

  static const double paddingH = 8;
  static const double paddingV = 4;
  static const double cornerRadius = 6;
  static const double maxWidth = 240;
  static const Color fill = Color(0xFFF8FAFC);
  static const double borderAlpha = 0.35;

  final CanvasTextLayout layout;
  final Rect pill;

  Offset get center => pill.center;

  /// Top-left corner the text is painted from.
  Offset get textOrigin => Offset(
    pill.center.dx - layout.size.width / 2,
    pill.center.dy - layout.size.height / 2,
  );

  static ConnectorLabelBox compute(
    Offset center,
    String text,
    Color color,
    double fontSize,
  ) {
    final layout = CanvasTextLayout.layout(
      text: text,
      fontSize: fontSize,
      fontWeight: 600,
      textAlign: 'center',
      maxWidth: maxWidth,
      maxLines: 1,
      color: color,
    );
    final pill = Rect.fromCenter(
      center: center,
      width: layout.size.width + paddingH * 2,
      height: layout.size.height + paddingV * 2,
    );
    return ConnectorLabelBox._(layout, pill);
  }
}

/// The label box for a connector, or null when it has no label.
ConnectorLabelBox? connectorLabelBox(
  Offset start,
  Offset end,
  String lineStyle, {
  required String label,
  required Color color,
  double cornerRadius = 0,
  double fontSize = 14,
}) {
  if (label.isEmpty) return null;
  return ConnectorLabelBox.compute(
    connectorMidpoint(start, end, lineStyle, cornerRadius: cornerRadius),
    label,
    color,
    fontSize,
  );
}

/// Renders a connector identically on the interactive canvas and in PNG/PDF
/// export: the shared path, optional dashes, arrowheads at either end oriented
/// along the path tangent, and a centred label pill at the path midpoint.
///
/// [start] and [end] are the already-resolved anchor points in canvas space.
void paintConnectorElement(
  Canvas canvas,
  Offset start,
  Offset end, {
  required String lineStyle,
  required Color color,
  required double strokeWidth,
  double cornerRadius = 0,
  List<double>? dashPattern,
  bool startArrowhead = false,
  bool endArrowhead = true,
  String label = '',
  Color? labelColor,
  double labelFontSize = 14,
}) {
  final path = connectorPath(start, end, lineStyle, cornerRadius: cornerRadius);
  if (strokeWidth > 0) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dashPath(path, dashPattern), strokePaint);
  }

  final heads = connectorArrowheads(
    start,
    end,
    lineStyle,
    strokeWidth: strokeWidth,
    cornerRadius: cornerRadius,
    startArrowhead: startArrowhead,
    endArrowhead: endArrowhead,
  );
  if (heads.isNotEmpty) {
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final head in heads) {
      canvas.drawPath(Path()..addPolygon(head, true), headPaint);
    }
  }

  final box = connectorLabelBox(
    start,
    end,
    lineStyle,
    label: label,
    color: labelColor ?? color,
    cornerRadius: cornerRadius,
    fontSize: labelFontSize,
  );
  if (box == null) return;
  final rrect = RRect.fromRectAndRadius(
    box.pill,
    const Radius.circular(ConnectorLabelBox.cornerRadius),
  );
  final textColor = labelColor ?? color;
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = ConnectorLabelBox.fill
      ..style = PaintingStyle.fill,
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = textColor.withValues(alpha: ConnectorLabelBox.borderAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  box.layout.painter.paint(canvas, box.textOrigin);
}

Offset _cubicAt(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final mt = 1 - t;
  final a = mt * mt * mt;
  final b = 3 * mt * mt * t;
  final c = 3 * mt * t * t;
  final d = t * t * t;
  return Offset(
    a * p0.dx + b * p1.dx + c * p2.dx + d * p3.dx,
    a * p0.dy + b * p1.dy + c * p2.dy + d * p3.dy,
  );
}

/// Whether [point] lands on the element as it is painted.
///
/// Callers pass a screen-constant tolerance so thin strokes stay tappable
/// without widening the rendered geometry.
bool elementContains(
  CanvasElement element,
  Offset point, {
  double tolerance = 0,
}) {
  switch (element) {
    case StrokeElement e:
      if (e.points.isEmpty) return false;
      final style = resolveBrushStyle(
        brushType: e.brushId.isNotEmpty ? e.brushId : e.brushType,
        strokeWidth: e.strokeWidth,
        strokeOpacity: e.opacity,
      );
      final effectiveWidth = math.max(e.strokeWidth, style.width);
      final blurPad = style.blurSigma > 0 ? style.blurSigma : 0.0;
      final jitterPad = style.jitter > 0
          ? (effectiveWidth / 2) * style.jitter
          : 0.0;
      return distanceToPolyline(e.points, point) <=
          effectiveWidth / 2 + blurPad + jitterPad + tolerance;
    case ConnectorElement e:
      return distanceToPolyline(
            connectorPolyline(
              e.startPoint,
              e.endPoint,
              e.lineStyle,
              cornerRadius: e.cornerRadius,
            ),
            point,
          ) <=
          e.strokeWidth / 2 + tolerance;
    case TextElement e:
      final rect = textElementRect(e);
      return rect
          .inflate(tolerance)
          .contains(rotatePoint(point, rect.center, -e.rotation));
    case ShapeElement e:
      return shapeContainsPoint(e, point, tolerance: tolerance);
    case ImageElement e:
      return Rect.fromCenter(
        center: e.center,
        width: e.width > 0 ? e.width : 100,
        height: e.height > 0 ? e.height : 100,
      ).inflate(tolerance).contains(rotatePoint(point, e.center, -e.rotation));
    case LayerElement _:
      return false;
    // Frames are structural: the eraser and generic hit-testing ignore their
    // interior. The screen selects a frame through its title bar or border.
    case FrameElement _:
      return false;
    case StickyNoteElement e:
      final rect = Rect.fromCenter(
        center: e.center,
        width: e.width > 0 ? e.width : 160,
        height: e.height > 0 ? e.height : 160,
      );
      return rect
          .inflate(tolerance)
          .contains(rotatePoint(point, e.center, -e.rotation));
    case TableElement e:
      final rect = tableElementRect(e);
      return rect
          .inflate(tolerance + e.borderWidth / 2)
          .contains(rotatePoint(point, e.center, -e.rotation));
  }
}

/// Highlighter strokes are wide, translucent markers. The painter and both
/// exporters use these helpers so a highlighted stroke looks the same on
/// screen, in PNG/PDF and in SVG.
const double highlighterWidthMultiplier = 2.5;
const double highlighterOpacityMultiplier = 0.35;
const double highlighterMinWidth = 8;
const double highlighterMaxWidth = 72;

double highlighterStrokeWidth(double strokeWidth) =>
    (strokeWidth * highlighterWidthMultiplier)
        .clamp(highlighterMinWidth, highlighterMaxWidth)
        .toDouble();

/// Marker strokes are a little wider and slightly translucent, but still
/// solid enough to read as ink rather than a highlight.
const double markerWidthMultiplier = 1.4;
const double markerOpacityMultiplier = 0.9;

double markerStrokeWidth(double strokeWidth) =>
    strokeWidth * markerWidthMultiplier;

double markerStrokeOpacity(double strokeOpacity) {
  final scaled = (strokeOpacity * markerOpacityMultiplier).clamp(0.0, 1.0);
  return (scaled * 1000).round() / 1000;
}

double highlighterStrokeOpacity(double strokeOpacity) {
  final scaled = (strokeOpacity * highlighterOpacityMultiplier).clamp(0.0, 1.0);
  // Round to three decimals so exported opacity values stay readable.
  return (scaled * 1000).round() / 1000;
}

/// One paint band in a [CanvasPaintOrder]. [layer] is null for the Default
/// band, which holds every element that no layer claims.
class CanvasPaintBand {
  final LayerElement? layer;

  /// Members in bottom-to-top paint order (ascending `z`, then id).
  final List<CanvasElement> elements;

  const CanvasPaintBand({required this.layer, required this.elements});

  String get label => layer?.name ?? 'Default';

  bool get isHidden => layer?.hidden ?? false;
  bool get isLocked => layer?.locked ?? false;

  bool contains(String elementId) =>
      elements.any((element) => element.id == elementId);
}

/// Layer compositing applied to each member when it is painted.
class CanvasLayerPaintEffect {
  final String blendMode;
  final double opacity;

  const CanvasLayerPaintEffect({this.blendMode = 'normal', this.opacity = 1});

  bool get isIdentity => blendMode == 'normal' && opacity >= 1;
}

BlendMode canvasBlendModeForName(String name) => switch (name) {
  'multiply' => BlendMode.multiply,
  'screen' => BlendMode.screen,
  'overlay' => BlendMode.overlay,
  'darken' => BlendMode.darken,
  'lighten' => BlendMode.lighten,
  _ => BlendMode.srcOver,
};

/// The canvas paint order: layers are bands, not just organisation.
///
/// The Default band (ungrouped elements) is always the bottom-most band so
/// creating a layer never silently pushes existing art above it. Layers then
/// stack by ascending `z`; inside every band elements keep their own `z`
/// order. Stale membership ids are ignored, and an element listed by several
/// layers belongs to the lowest layer that lists it.
class CanvasPaintOrder {
  /// Bands in paint order, bottom first. The last band is topmost.
  final List<CanvasPaintBand> bands;

  const CanvasPaintOrder(this.bands);

  /// Visible members only: hiding a layer hides every element in its band.
  Iterable<CanvasElement> get elements =>
      bands.where((band) => !band.isHidden).expand((b) => b.elements);

  /// Members of locked layers, which hit-testing must ignore.
  Set<String> get lockedElementIds => {
    for (final band in bands)
      if (band.isLocked) ...band.elements.map((element) => element.id),
  };

  CanvasPaintBand? bandFor(String elementId) {
    for (final band in bands) {
      if (band.contains(elementId)) return band;
    }
    return null;
  }

  bool isInHigherBand(String elementId, String thanElementId) {
    final index = bands.indexWhere((band) => band.contains(elementId));
    final other = bands.indexWhere((band) => band.contains(thanElementId));
    if (index < 0 || other < 0) return false;
    return index > other;
  }
}

int _comparePaintZ(CanvasElement a, CanvasElement b) {
  if (a.z != b.z) return a.z.compareTo(b.z);
  return a.id.compareTo(b.id);
}

/// Resolves layers-as-bands ordering for painting, hit-testing, export and
/// the layers tray. Elements are painted in list order, so the last entry is
/// topmost.
CanvasPaintOrder canvasPaintOrder(List<CanvasElement> elements) {
  final layers = elements.whereType<LayerElement>().toList()
    ..sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
  final members = <String, CanvasElement>{
    for (final element in elements)
      if (element is! LayerElement) element.id: element,
  };

  // First layer (lowest z) that lists an id owns it; later duplicates and
  // stale ids are ignored.
  final owner = <String, LayerElement>{};
  for (final layer in layers) {
    for (final id in layer.elementIds) {
      owner.putIfAbsent(id, () => layer);
    }
  }

  final defaultBand = <CanvasElement>[];
  final byLayer = <String, List<CanvasElement>>{
    for (final layer in layers) layer.id: <CanvasElement>[],
  };
  for (final element in members.values) {
    final layer = owner[element.id];
    if (layer == null) {
      defaultBand.add(element);
    } else {
      byLayer[layer.id]!.add(element);
    }
  }
  defaultBand.sort(_comparePaintZ);

  List<CanvasElement> orderBandWithFrames(List<CanvasElement> sortedBand) {
    final bandFrames = sortedBand.whereType<FrameElement>().toList(
      growable: false,
    );
    if (bandFrames.isEmpty) return sortedBand;
    final bandFrameIds = {for (final f in bandFrames) f.id};
    final ordered = <CanvasElement>[];
    for (final element in sortedBand) {
      if (element is FrameElement) continue;
      if (element.frameId == null || !bandFrameIds.contains(element.frameId)) {
        ordered.add(element);
      }
    }
    for (final frame in bandFrames) {
      ordered.add(frame);
      for (final element in sortedBand) {
        if (element is! FrameElement && element.frameId == frame.id) {
          ordered.add(element);
        }
      }
    }
    return ordered;
  }

  final bands = <CanvasPaintBand>[
    CanvasPaintBand(
      layer: null,
      elements: List.unmodifiable(orderBandWithFrames(defaultBand)),
    ),
  ];
  for (final layer in layers) {
    final band = byLayer[layer.id]!..sort(_comparePaintZ);
    bands.add(
      CanvasPaintBand(
        layer: layer,
        elements: List.unmodifiable(orderBandWithFrames(band)),
      ),
    );
  }
  return CanvasPaintOrder(List.unmodifiable(bands));
}

/// Convenience wrapper for callers that only need the flattened order.
List<CanvasElement> orderedElementsForPaint(List<CanvasElement> elements) =>
    canvasPaintOrder(elements).elements.toList(growable: false);

/// Resolves per-member compositing for layers with a blend mode or opacity.
/// Hidden layers are omitted, matching [CanvasPaintOrder.elements].
Map<String, CanvasLayerPaintEffect> layerPaintEffects(
  List<CanvasElement> elements,
) {
  final result = <String, CanvasLayerPaintEffect>{};
  for (final band in canvasPaintOrder(elements).bands) {
    final layer = band.layer;
    if (layer == null || band.isHidden) continue;
    final effect = CanvasLayerPaintEffect(
      blendMode: layer.blendMode,
      opacity: layer.opacity.clamp(0.0, 1.0),
    );
    if (effect.isIdentity) continue;
    for (final element in band.elements) {
      result[element.id] = effect;
    }
  }
  return result;
}

/// Union of every element's bounds; empty when nothing has geometry.
Rect? elementsBounds(Iterable<CanvasElement> elements) {
  Rect? union;
  for (final element in elements) {
    final bounds = elementBounds(element);
    if (bounds == null) continue;
    union = union == null ? bounds : union.expandToInclude(bounds);
  }
  return union;
}

/// Returns the unrotated anchor box and rotation angle (radians) for
/// [element], or `null` if [element] does not expose box anchors.
(Rect, double)? connectorTargetBox(
  CanvasElement element, {
  Offset? overrideCenter,
}) {
  switch (element) {
    case ShapeElement e:
      final base = shapeElementRect(e);
      final box = overrideCenter == null
          ? base
          : Rect.fromCenter(
              center: overrideCenter,
              width: base.width,
              height: base.height,
            );
      return (box, e.rotation);
    case TextElement e:
      final base = textElementRect(e);
      final box = overrideCenter == null
          ? base
          : Rect.fromLTWH(
              overrideCenter.dx,
              overrideCenter.dy,
              base.width,
              base.height,
            );
      return (box, e.rotation);
    case ImageElement e:
      return (
        Rect.fromCenter(
          center: overrideCenter ?? e.center,
          width: e.width > 0 ? e.width : 100,
          height: e.height > 0 ? e.height : 100,
        ),
        e.rotation,
      );
    case StickyNoteElement e:
      return (
        Rect.fromCenter(
          center: overrideCenter ?? e.center,
          width: e.width > 0 ? e.width : 160,
          height: e.height > 0 ? e.height : 160,
        ),
        e.rotation,
      );
    case FrameElement e:
      final base = frameRect(e);
      return (
        overrideCenter == null
            ? base
            : Rect.fromCenter(
                center: overrideCenter,
                width: base.width,
                height: base.height,
              ),
        0.0,
      );
    case TableElement e:
      final base = tableElementRect(e);
      return (
        overrideCenter == null
            ? base
            : Rect.fromCenter(
                center: overrideCenter,
                width: base.width,
                height: base.height,
              ),
        e.rotation,
      );
    case StrokeElement _:
    case ConnectorElement _:
    case LayerElement _:
      return null;
  }
}

/// Resolves a connector endpoint attached to [target] (or returns [fallback]).
Offset resolveConnectorAnchorPoint(
  CanvasElement? target,
  String anchor,
  Offset fallback, {
  Offset? towards,
  Offset? overrideCenter,
}) {
  if (target == null) return fallback;
  final boxAndRotation = connectorTargetBox(
    target,
    overrideCenter: overrideCenter,
  );
  if (boxAndRotation == null) return fallback;
  final (box, rotation) = boxAndRotation;

  var effectiveAnchor = anchor;
  if (effectiveAnchor == 'auto' && towards != null) {
    final localTowards = rotation == 0
        ? towards
        : rotatePoint(towards, box.center, -rotation);
    final dx = localTowards.dx - box.center.dx;
    final dy = localTowards.dy - box.center.dy;
    if (dx.abs() > dy.abs()) {
      effectiveAnchor = dx > 0 ? 'right' : 'left';
    } else {
      effectiveAnchor = dy > 0 ? 'bottom' : 'top';
    }
  }

  final localPoint = switch (effectiveAnchor) {
    'top' => Offset(box.center.dx, box.top),
    'bottom' => Offset(box.center.dx, box.bottom),
    'left' => Offset(box.left, box.center.dy),
    'right' => Offset(box.right, box.center.dy),
    _ => box.center,
  };
  return rotation == 0
      ? localPoint
      : rotatePoint(localPoint, box.center, rotation);
}

/// Resolves both endpoints `(start, end)` of [connector] against [elementById].
(Offset, Offset) resolveConnectorEndpoints(
  ConnectorElement connector,
  Map<String, CanvasElement> elementById,
) {
  final startTarget = connector.startElementId == null
      ? null
      : elementById[connector.startElementId!];
  final endTarget = connector.endElementId == null
      ? null
      : elementById[connector.endElementId!];

  final startCenter = resolveConnectorAnchorPoint(
    startTarget,
    'center',
    connector.startPoint,
  );
  final endCenter = resolveConnectorAnchorPoint(
    endTarget,
    'center',
    connector.endPoint,
  );

  final start = resolveConnectorAnchorPoint(
    startTarget,
    connector.startAnchor,
    connector.startPoint,
    towards: endCenter,
  );
  final end = resolveConnectorAnchorPoint(
    endTarget,
    connector.endAnchor,
    connector.endPoint,
    towards: startCenter,
  );
  return (start, end);
}

/// Unrotated on-canvas box of an image (what [ImageElement.crop] maps onto).
Rect imageElementRect(ImageElement e) => Rect.fromCenter(
  center: e.center,
  width: e.width > 0 ? e.width : 100,
  height: e.height > 0 ? e.height : 100,
);

/// Smallest crop edge, as a fraction of the source image.
const double kMinImageCropFraction = 0.02;

/// Clamps a normalized crop into the source image with a minimum size.
Rect clampImageCrop(Rect crop) {
  const minSize = kMinImageCropFraction;
  final left = crop.left.isFinite ? crop.left.clamp(0.0, 1.0 - minSize) : 0.0;
  final top = crop.top.isFinite ? crop.top.clamp(0.0, 1.0 - minSize) : 0.0;
  final right = crop.right.isFinite
      ? crop.right.clamp(left + minSize, 1.0)
      : 1.0;
  final bottom = crop.bottom.isFinite
      ? crop.bottom.clamp(top + minSize, 1.0)
      : 1.0;
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Re-crops [image] to [newCrop] without changing the on-canvas scale.
///
/// Pixels per canvas unit stay constant, so the box grows or shrinks with the
/// crop and the kept pixels stay exactly where they were on the board, through
/// any rotation and flip.
ImageElement applyImageCrop(ImageElement image, Rect newCrop) {
  final crop = clampImageCrop(newCrop);
  final old = image.crop;
  final box = imageElementRect(image);
  final fullWidth = box.width / old.width;
  final fullHeight = box.height / old.height;
  var dx = (crop.center.dx - old.center.dx) * fullWidth;
  var dy = (crop.center.dy - old.center.dy) * fullHeight;
  if (image.flipped) dx = -dx;
  if (image.flipV) dy = -dy;
  final shift = rotatePoint(Offset(dx, dy), Offset.zero, image.rotation);
  return image.copyWith(
    crop: crop,
    center: image.center + shift,
    width: fullWidth * crop.width,
    height: fullHeight * crop.height,
  );
}

/// Source rectangle in decoded-image pixels for [crop].
Rect imageCropSourceRect(Rect crop, Size imageSize) => Rect.fromLTRB(
  crop.left * imageSize.width,
  crop.top * imageSize.height,
  crop.right * imageSize.width,
  crop.bottom * imageSize.height,
);

/// 4x5 colour matrix (row-major, offsets in 0–255) for the image filters.
///
/// Saturation mixes towards Rec. 709 luminance, then contrast scales around
/// mid-grey, then brightness adds a flat offset. All inputs are in -1…1.
List<double> imageColorMatrix({
  double brightness = 0,
  double contrast = 0,
  double saturation = 0,
}) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final s = 1 + saturation.clamp(-1.0, 1.0);
  final f = 1 + contrast.clamp(-1.0, 1.0);
  final offset = 128 * (1 - f) + 128 * brightness.clamp(-1.0, 1.0);
  final inv = 1 - s;
  return <double>[
    f * (lr * inv + s),
    f * (lg * inv),
    f * (lb * inv),
    0,
    offset,
    f * (lr * inv),
    f * (lg * inv + s),
    f * (lb * inv),
    0,
    offset,
    f * (lr * inv),
    f * (lg * inv),
    f * (lb * inv + s),
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// Paints an image element exactly as the board shows it: crop, rotation,
/// flips, rounded clip, colour filters, reference fade and border.
///
/// Element-level opacity is applied by the caller's layer, as for every other
/// element. [placeholder] draws in the unflipped frame when [decoded] is null.
void paintImageElement(
  Canvas canvas,
  ImageElement e,
  ui.Image? decoded, {
  void Function(Canvas canvas, Rect rect, RRect rrect)? placeholder,
}) {
  final rect = imageElementRect(e);
  final radius = e.borderRadius
      .clamp(0.0, math.min(rect.width, rect.height) / 2)
      .toDouble();
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

  canvas.save();
  canvas.translate(e.center.dx, e.center.dy);
  if (e.rotation != 0) canvas.rotate(e.rotation);
  canvas.translate(-e.center.dx, -e.center.dy);
  if (e.isReference) {
    canvas.saveLayer(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: ImageElement.referenceOpacity),
    );
  }

  if (decoded != null) {
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.translate(e.center.dx, e.center.dy);
    if (e.flipped || e.flipV) {
      canvas.scale(e.flipped ? -1 : 1, e.flipV ? -1 : 1);
    }
    canvas.translate(-e.center.dx, -e.center.dy);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (e.hasFilters) {
      paint.colorFilter = ColorFilter.matrix(
        imageColorMatrix(
          brightness: e.brightness,
          contrast: e.contrast,
          saturation: e.saturation,
        ),
      );
    }
    final src = imageCropSourceRect(
      e.crop,
      Size(decoded.width.toDouble(), decoded.height.toDouble()),
    );
    canvas.drawImageRect(decoded, src, rect, paint);
    canvas.restore();
  } else if (placeholder != null) {
    placeholder(canvas, rect, rrect);
  }

  if (e.borderWidth > 0) {
    final inset = math.min(
      e.borderWidth / 2,
      math.min(rect.width, rect.height) / 2,
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      rrect.deflate(inset),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.borderWidth
        ..color = e.borderColor,
    );
    canvas.restore();
  }
  if (e.isReference) canvas.restore();
  canvas.restore();
}

Rect stickyNoteRect(StickyNoteElement note) => Rect.fromCenter(
  center: note.center,
  width: note.width,
  height: note.height,
);

double stickyNoteTapeHeight(StickyNoteElement note) =>
    math.min(22, note.height * 0.15);

Rect stickyNoteTextRect(StickyNoteElement note) {
  final rect = stickyNoteRect(note);
  return Rect.fromLTWH(
    rect.left + 12,
    rect.top + stickyNoteTapeHeight(note) + 6,
    math.max(1, rect.width - 24),
    math.max(1, rect.height - stickyNoteTapeHeight(note) - 18),
  );
}

(Color, Color, Color) stickyNotePaperColors(StickyNoteElement note) {
  final hsl = HSLColor.fromColor(note.color);
  Color shade(double delta) =>
      hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  return (shade(0.03), shade(-0.05), shade(-0.10));
}

CanvasTextLayout stickyNoteTextLayout(StickyNoteElement note) {
  final width = stickyNoteTextRect(note).width;
  final layout = CanvasTextLayout.layout(
    text: note.text,
    fontSize: note.fontSize,
    fontWeight: note.fontWeight,
    textAlign: note.textAlign,
    lineHeight: 1.4,
    color: note.textColor,
    maxWidth: width,
  );
  layout.painter.layout(minWidth: width, maxWidth: width);
  return layout;
}

StickyNoteElement fitStickyNoteHeight(StickyNoteElement note) {
  if (!note.autoSize) return note;
  final layout = stickyNoteTextLayout(note);
  final height = math
      .max(note.height, layout.painter.height + 40)
      .ceilToDouble()
      .clamp(80.0, 480.0);
  layout.painter.dispose();
  return note.copyWith(height: height);
}

void paintStickyNoteElement(Canvas canvas, StickyNoteElement note) {
  final rect = stickyNoteRect(note);
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
  final (top, bottom, curl) = stickyNotePaperColors(note);
  canvas.save();
  canvas.translate(note.center.dx, note.center.dy);
  canvas.rotate(note.rotation);
  canvas.translate(-note.center.dx, -note.center.dy);
  canvas.drawRRect(
    rrect.shift(const Offset(0, 2)),
    Paint()
      ..color = const Color(0x0F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawRRect(
    rrect.shift(const Offset(2, 6)),
    Paint()
      ..color = const Color(0x1F000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
        top,
        bottom,
      ]),
  );
  final tapeHeight = stickyNoteTapeHeight(note);
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTWH(rect.left, rect.top, rect.width, tapeHeight),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
    ),
    Paint()..color = const Color(0x33FFFFFF),
  );
  canvas.drawLine(
    Offset(rect.left, rect.top + tapeHeight),
    Offset(rect.right, rect.top + tapeHeight),
    Paint()
      ..color = const Color(0x0A000000)
      ..strokeWidth = 1,
  );
  final curlPath = Path()
    ..moveTo(rect.right - 14, rect.bottom)
    ..lineTo(rect.right, rect.bottom - 14)
    ..lineTo(rect.right - 14, rect.bottom - 14)
    ..close();
  canvas.drawPath(
    curlPath.shift(const Offset(-1, -1)),
    Paint()
      ..color = const Color(0x14000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawPath(curlPath, Paint()..color = curl);
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = const Color(0x12000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  if (note.text.isNotEmpty) {
    final layout = stickyNoteTextLayout(note);
    canvas.save();
    canvas.clipRect(stickyNoteTextRect(note));
    layout.painter.paint(canvas, stickyNoteTextRect(note).topLeft);
    canvas.restore();
    layout.painter.dispose();
  }
  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// F-16: Table geometry & shared renderer
// ─────────────────────────────────────────────────────────────────────────────

/// Unrotated bounding box of [table].
Rect tableElementRect(TableElement table) => Rect.fromCenter(
  center: table.center,
  width: math.max(TableElement.minCellWidth * table.columns, table.width),
  height: math.max(TableElement.minCellHeight * table.rows, table.height),
);

/// Cumulative column X coordinates from `rect.left` to `rect.right` (len = columns + 1).
List<double> tableColumnOffsets(TableElement table, [Rect? rect]) {
  final box = rect ?? tableElementRect(table);
  final fracs = table.resolvedColumnFractions;
  final xs = <double>[box.left];
  var acc = 0.0;
  for (var i = 0; i < fracs.length; i++) {
    acc += fracs[i];
    xs.add(i == fracs.length - 1 ? box.right : box.left + box.width * acc);
  }
  return xs;
}

/// Cumulative row Y coordinates from `rect.top` to `rect.bottom` (len = rows + 1).
List<double> tableRowOffsets(TableElement table, [Rect? rect]) {
  final box = rect ?? tableElementRect(table);
  final fracs = table.resolvedRowFractions;
  final ys = <double>[box.top];
  var acc = 0.0;
  for (var i = 0; i < fracs.length; i++) {
    acc += fracs[i];
    ys.add(i == fracs.length - 1 ? box.bottom : box.top + box.height * acc);
  }
  return ys;
}

/// Unrotated bounds of cell `(row, col)` inside [table].
Rect tableCellRect(TableElement table, int row, int col) {
  final rect = tableElementRect(table);
  final xs = tableColumnOffsets(table, rect);
  final ys = tableRowOffsets(table, rect);
  final r = row.clamp(0, table.rows - 1);
  final c = col.clamp(0, table.columns - 1);
  return Rect.fromLTRB(xs[c], ys[r], xs[c + 1], ys[r + 1]);
}

/// Returns `(row, col)` if [point] falls inside [table], otherwise `null`.
(int, int)? tableHitTestCell(TableElement table, Offset point) {
  final local = rotatePoint(point, table.center, -table.rotation);
  final rect = tableElementRect(table);
  if (!rect.contains(local)) return null;
  final xs = tableColumnOffsets(table, rect);
  final ys = tableRowOffsets(table, rect);
  var col = table.columns - 1;
  for (var c = 0; c < table.columns; c++) {
    if (local.dx <= xs[c + 1]) {
      col = c;
      break;
    }
  }
  var row = table.rows - 1;
  for (var r = 0; r < table.rows; r++) {
    if (local.dy <= ys[r + 1]) {
      row = r;
      break;
    }
  }
  return (row, col);
}

/// Renders a [TableElement] identically on canvas, PNG, and PDF.
void paintTableElement(Canvas canvas, TableElement table) {
  final rect = tableElementRect(table);
  final xs = tableColumnOffsets(table, rect);
  final ys = tableRowOffsets(table, rect);

  canvas.save();
  if (table.rotation != 0) {
    canvas.translate(table.center.dx, table.center.dy);
    canvas.rotate(table.rotation);
    canvas.translate(-table.center.dx, -table.center.dy);
  }

  // Table background
  canvas.drawRect(rect, Paint()..color = table.backgroundColor);

  // Header row background
  if (table.headerRow && ys.length >= 2) {
    canvas.drawRect(
      Rect.fromLTRB(rect.left, ys[0], rect.right, ys[1]),
      Paint()..color = table.headerBackgroundColor,
    );
  }

  // Per-cell backgrounds & text
  for (var r = 0; r < table.rows; r++) {
    for (var c = 0; c < table.columns; c++) {
      final cell = table.cellAt(r, c);
      final cellRect = Rect.fromLTRB(xs[c], ys[r], xs[c + 1], ys[r + 1]);
      if (cell.backgroundColor != null) {
        canvas.drawRect(cellRect, Paint()..color = cell.backgroundColor!);
      }
      if (cell.text.isEmpty) continue;
      final pad = math.min(
        table.cellPadding,
        math.min(cellRect.width, cellRect.height) * 0.25,
      );
      final contentRect = cellRect.deflate(pad);
      if (contentRect.width <= 1 || contentRect.height <= 1) continue;
      final isHeader = table.headerRow && r == 0;
      final weight = cell.fontWeight ?? (isHeader ? 700 : 400);
      final layout = CanvasTextLayout.layout(
        text: cell.text,
        fontSize: table.fontSize,
        fontWeight: weight,
        textAlign: cell.textAlign,
        lineHeight: 1.25,
        maxWidth: contentRect.width,
        color: cell.textColor ?? table.textColor,
      );
      layout.painter.layout(
        minWidth: contentRect.width,
        maxWidth: contentRect.width,
      );
      canvas.save();
      canvas.clipRect(contentRect);
      final dy = contentRect.top +
          math.max(0.0, (contentRect.height - layout.painter.height) / 2);
      layout.painter.paint(canvas, Offset(contentRect.left, dy));
      canvas.restore();
      layout.painter.dispose();
    }
  }

  // Grid lines & outer border
  final borderPaint = Paint()
    ..color = table.borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = table.borderWidth;
  for (var c = 1; c < table.columns; c++) {
    canvas.drawLine(
      Offset(xs[c], rect.top),
      Offset(xs[c], rect.bottom),
      borderPaint,
    );
  }
  for (var r = 1; r < table.rows; r++) {
    canvas.drawLine(
      Offset(rect.left, ys[r]),
      Offset(rect.right, ys[r]),
      borderPaint,
    );
  }
  canvas.drawRect(rect, borderPaint);
  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// F-18: Symmetry & Snapping geometry helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Computes the mirrored/radial duplicate points for [point] according to
/// [settings]. The returned list does NOT include [point] itself.
List<Offset> symmetryMirroredCopies(
  Offset point,
  CanvasBoardSettings settings,
) {
  switch (settings.symmetryMode) {
    case CanvasSymmetryMode.none:
      return const [];
    case CanvasSymmetryMode.vertical:
      final cx = settings.symmetryCenter.dx;
      return [Offset(2 * cx - point.dx, point.dy)];
    case CanvasSymmetryMode.horizontal:
      final cy = settings.symmetryCenter.dy;
      return [Offset(point.dx, 2 * cy - point.dy)];
    case CanvasSymmetryMode.radial:
      final count = settings.symmetryCount.clamp(2, 16);
      final center = settings.symmetryCenter;
      final result = <Offset>[];
      final stepAngle = (2 * math.pi) / count;
      for (var i = 1; i < count; i++) {
        result.add(rotatePoint(point, center, stepAngle * i));
      }
      return result;
  }
}

/// Computes mirrored/radial copies of an entire polyline path according to
/// [settings]. Does NOT include [points] itself.
List<List<Offset>> symmetryMirroredPolylines(
  List<Offset> points,
  CanvasBoardSettings settings,
) {
  if (settings.symmetryMode == CanvasSymmetryMode.none || points.isEmpty) {
    return const [];
  }
  if (settings.symmetryMode == CanvasSymmetryMode.radial) {
    final count = settings.symmetryCount.clamp(2, 16);
    final center = settings.symmetryCenter;
    final stepAngle = (2 * math.pi) / count;
    return [
      for (var i = 1; i < count; i++)
        [for (final p in points) rotatePoint(p, center, stepAngle * i)],
    ];
  }
  final mirrored = <Offset>[
    for (final p in points) ...symmetryMirroredCopies(p, settings),
  ];
  return [mirrored];
}

/// Snaps a dragged selection's [proposedBounds] to enabled grid intersections
/// and ruler guides, returning the adjusted movement delta offset from the
/// proposed position.
Offset snapBoundsAdjustment(
  Rect proposedBounds,
  CanvasBoardSettings settings, {
  double viewportScale = 1.0,
}) {
  if (!settings.snapEnabled) return Offset.zero;
  final scale = viewportScale > 0.05 ? viewportScale : 1.0;
  final threshold = settings.snapDistance / scale;
  final grid = settings.patternSpacing > 0 ? settings.patternSpacing : 32.0;

  double bestDx = 0;
  var minAbsDx = threshold + 1;
  final xCandidates = <double>[
    proposedBounds.left,
    proposedBounds.center.dx,
    proposedBounds.right,
  ];
  // Snap X to guides first, then grid lines
  for (final x in xCandidates) {
    for (final guide in settings.guides) {
      if (guide.axis != CanvasGuideAxis.vertical) continue;
      final diff = guide.position - x;
      if (diff.abs() <= threshold && diff.abs() < minAbsDx) {
        minAbsDx = diff.abs();
        bestDx = diff;
      }
    }
    if (settings.backgroundPattern != CanvasBackgroundPattern.none) {
      final snappedX = (x / grid).roundToDouble() * grid;
      final diff = snappedX - x;
      if (diff.abs() <= threshold && diff.abs() < minAbsDx) {
        minAbsDx = diff.abs();
        bestDx = diff;
      }
    }
  }

  double bestDy = 0;
  var minAbsDy = threshold + 1;
  final yCandidates = <double>[
    proposedBounds.top,
    proposedBounds.center.dy,
    proposedBounds.bottom,
  ];
  for (final y in yCandidates) {
    for (final guide in settings.guides) {
      if (guide.axis != CanvasGuideAxis.horizontal) continue;
      final diff = guide.position - y;
      if (diff.abs() <= threshold && diff.abs() < minAbsDy) {
        minAbsDy = diff.abs();
        bestDy = diff;
      }
    }
    if (settings.backgroundPattern != CanvasBackgroundPattern.none) {
      final snappedY = (y / grid).roundToDouble() * grid;
      final diff = snappedY - y;
      if (diff.abs() <= threshold && diff.abs() < minAbsDy) {
        minAbsDy = diff.abs();
        bestDy = diff;
      }
    }
  }

  return Offset(bestDx, bestDy);
}
