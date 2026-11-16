import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/models/canvas/canvas_shape_type.dart';

/// Geometry inferred from a held freehand stroke.
class QuickShapeMatch {
  final CanvasShapeType shapeType;
  final Offset center;
  final double width;
  final double height;
  final double rotation;

  const QuickShapeMatch({
    required this.shapeType,
    required this.center,
    required this.width,
    required this.height,
    this.rotation = 0,
  });
}

/// Recognizes a rough line, rectangle or ellipse from a raw stroke.
///
/// Deliberately conservative: open squiggles and loose scribbles return null so
/// QuickShape never replaces normal handwriting. Callers should only invoke
/// this after the hold gesture has already passed.
QuickShapeMatch? recognizeQuickShape(List<Offset> points) {
  if (points.length < 12) return null;

  var minX = points.first.dx;
  var minY = points.first.dy;
  var maxX = points.first.dx;
  var maxY = points.first.dy;
  for (final point in points.skip(1)) {
    minX = math.min(minX, point.dx);
    minY = math.min(minY, point.dy);
    maxX = math.max(maxX, point.dx);
    maxY = math.max(maxY, point.dy);
  }
  final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
  final diagonal = math.sqrt(
    bounds.width * bounds.width + bounds.height * bounds.height,
  );
  if (diagonal < 24) return null;

  final first = points.first;
  final last = points.last;
  final closed = (last - first).distance <= math.max(14, diagonal * 0.18);

  if (!closed) {
    final chord = last - first;
    final length = chord.distance;
    if (length < 24) return null;
    var maxDeviation = 0.0;
    for (final point in points) {
      maxDeviation = math.max(
        maxDeviation,
        _distanceToInfiniteLine(point, first, last),
      );
    }
    if (maxDeviation <= math.max(6, length * 0.05)) {
      return QuickShapeMatch(
        shapeType: CanvasShapeType.line,
        center: (first + last) / 2,
        width: length,
        height: 0,
        rotation: math.atan2(chord.dy, chord.dx),
      );
    }
    return null;
  }

  // Check the ellipse first: a rectangle's corners are far from its own
  // circumscribed ellipse, while an ellipse's points are always near its
  // bounding box (which makes a naive border test ambiguous).
  final radiusX = bounds.width / 2;
  final radiusY = bounds.height / 2;
  if (radiusX < 8 || radiusY < 8) return null;
  var normalizedError = 0.0;
  var maxNormalizedError = 0.0;
  for (final point in points) {
    final nx = (point.dx - bounds.center.dx) / radiusX;
    final ny = (point.dy - bounds.center.dy) / radiusY;
    final error = (math.sqrt(nx * nx + ny * ny) - 1).abs();
    normalizedError += error;
    maxNormalizedError = math.max(maxNormalizedError, error);
  }
  if (normalizedError / points.length <= 0.1 && maxNormalizedError <= 0.2) {
    return QuickShapeMatch(
      shapeType: CanvasShapeType.ellipse,
      center: bounds.center,
      width: bounds.width,
      height: bounds.height,
    );
  }

  final borderTolerance = math.max(8, diagonal * 0.08);
  var nearBorder = 0;
  for (final point in points) {
    final distance = math.min(
      math.min((point.dx - bounds.left).abs(), (point.dx - bounds.right).abs()),
      math.min((point.dy - bounds.top).abs(), (point.dy - bounds.bottom).abs()),
    );
    if (distance <= borderTolerance) nearBorder++;
  }
  final corners = [
    bounds.topLeft,
    bounds.topRight,
    bounds.bottomLeft,
    bounds.bottomRight,
  ];
  var cornerHits = 0;
  for (final corner in corners) {
    if (points.any(
      (point) => (point - corner).distance <= borderTolerance * 1.8,
    )) {
      cornerHits++;
    }
  }
  if (nearBorder >= points.length * 0.8 && cornerHits >= 4) {
    return QuickShapeMatch(
      shapeType: CanvasShapeType.rectangle,
      center: bounds.center,
      width: bounds.width,
      height: bounds.height,
    );
  }

  return null;
}

double _distanceToInfiniteLine(Offset point, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length < 1e-6) return (point - a).distance;
  return ((point.dx - a.dx) * dy - (point.dy - a.dy) * dx).abs() / length;
}
