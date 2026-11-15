import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/brush_preset.dart';
import '../models/canvas_element.dart';
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
void paintShapeElement(Canvas canvas, ShapeElement shape) {
  final rect = shapeElementRect(shape);
  final path = buildShapePath(shape);
  final hw = rect.width / 2;

  canvas.save();
  canvas.translate(shape.center.dx, shape.center.dy);
  if (shape.rotation != 0) canvas.rotate(shape.rotation);

  if (shape.isFilled && !shape.isLinear) {
    canvas.drawPath(
      path,
      Paint()
        ..color = shape.color
        ..style = PaintingStyle.fill,
    );
  }

  final strokeColor = shape.color.withValues(
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
    if (shape.endArrowhead) {
      canvas.drawPath(shapeArrowheadPath(Offset(hw, 0), 0, headLen), headPaint);
    }
    if (shape.startArrowhead) {
      canvas.drawPath(
        shapeArrowheadPath(Offset(-hw, 0), math.pi, headLen),
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
    case StickyNoteElement e:
      final rect = Rect.fromCenter(
        center: e.center,
        width: e.width > 0 ? e.width : 160,
        height: e.height > 0 ? e.height : 160,
      );
      return rect
          .inflate(tolerance)
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

  bool contains(String elementId) =>
      elements.any((element) => element.id == elementId);
}

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

  Iterable<CanvasElement> get elements => bands.expand((b) => b.elements);

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

  final bands = <CanvasPaintBand>[
    CanvasPaintBand(layer: null, elements: List.unmodifiable(defaultBand)),
  ];
  for (final layer in layers) {
    final band = byLayer[layer.id]!..sort(_comparePaintZ);
    bands.add(CanvasPaintBand(layer: layer, elements: List.unmodifiable(band)));
  }
  return CanvasPaintOrder(List.unmodifiable(bands));
}

/// Convenience wrapper for callers that only need the flattened order.
List<CanvasElement> orderedElementsForPaint(List<CanvasElement> elements) =>
    canvasPaintOrder(elements).elements.toList(growable: false);

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
