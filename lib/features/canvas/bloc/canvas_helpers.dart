part of 'canvas_bloc.dart';

class _EraserResult {
  final List<CanvasElement> nextElements;
  final List<String> deletedElementIds;
  final List<CanvasElement> createdStrokes;

  const _EraserResult({
    required this.nextElements,
    required this.deletedElementIds,
    required this.createdStrokes,
  });
}

/// A collaborator's live eraser position. Eraser gestures are never board
/// elements, so they are relayed as a transient ghost ring instead of ink.
class RemoteEraserCursor {
  final Offset position;
  final double radius;
  final DateTime updatedAt;

  const RemoteEraserCursor({
    required this.position,
    required this.radius,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteEraserCursor &&
          position == other.position &&
          radius == other.radius;

  @override
  int get hashCode => Object.hash(position, radius);
}

/// Local state for a single eraser drag.
///
/// The erase is re-applied on every pointer sample so the ink disappears under
/// the eraser immediately, but nothing is persisted until the drag ends. That
/// keeps one CRDT commit per gesture (no per-fragment flicker) while tracking
/// which elements were erased and which fragment ids this drag created.
class _EraserSession {
  final String previewId;
  final double radius;
  final Set<String> baseElementIds;
  final Set<String> erasedIds = <String>{};
  final Set<String> createdIds = <String>{};
  final List<Offset> path = <Offset>[];

  _EraserSession({
    required this.previewId,
    required this.radius,
    required this.baseElementIds,
  });

  void absorb(_EraserResult result) {
    erasedIds.addAll(result.deletedElementIds);
    createdIds.addAll(result.createdStrokes.map((stroke) => stroke.id));
  }
}

class _QueuedPreviewPublish {
  Timer? timer;
  bool dirty = false;
  String previewId = '';
  String elementId = '';
  Uint8List payload = Uint8List(0);
}

double _normalizeRotation(double value) {
  if (value.isNaN || value.isInfinite) return 0.0;
  final twoPi = math.pi * 2;
  var normalized = value % twoPi;
  if (normalized < 0) {
    normalized += twoPi;
  }
  return normalized;
}

double? _toDoubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    return value.trim().toLowerCase() == 'true';
  }
  return false;
}

String _shapeFingerprint(String shapeId, Map<String, dynamic> data) {
  final cx = ((data['cx'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(3);
  final cy = ((data['cy'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(3);
  final size = ((data['size'] as num?)?.toDouble() ?? 64.0).toStringAsFixed(
    3,
  );
  final rotation = _normalizeRotation(
    (data['rotation'] as num?)?.toDouble() ?? 0.0,
  ).toStringAsFixed(5);
  final borderRadius = ((data['borderRadius'] as num?)?.toDouble() ?? 0.0)
      .toStringAsFixed(3);
  final color = ((data['color'] as num?)?.toInt() ?? 0).toString();
  final filled = _parseBool(data['isFilled']).toString();
  final z = ((data['z'] as num?)?.toInt() ?? 0).toString();
  return '$shapeId|$cx|$cy|$size|$rotation|$borderRadius|$color|$filled|$z';
}

/// Measures the on-canvas bounds of [text] using the exact style and layout
/// constraints that CanvasPainter._paintText draws with (fontSize 16, w600,
/// maxLines 2, ellipsis, maxWidth 220), so persisted bounds match the render.
Size measureTextElementBounds(String text) {
  final textSpan = TextSpan(
    text: text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '...',
  )..layout(maxWidth: 220);
  return Size(textPainter.width, textPainter.height);
}

Rect? _elementBounds(CanvasElement element) {
  return switch (element) {
    ShapeElement e => Rect.fromCenter(
        center: e.center, width: e.size, height: e.size,
      ),
    // Text is painted from its center point as the top-left origin, so the
    // bounds rect starts there too.
    TextElement e => Rect.fromLTWH(
        e.center.dx,
        e.center.dy,
        e.width > 0 ? e.width : 180,
        e.height > 0 ? e.height : 48,
      ),
    ImageElement e => Rect.fromCenter(
        center: e.center, width: e.width, height: e.height,
      ),
    _ => null,
  };
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  if (dx == 0 && dy == 0) {
    return (point - start).distance;
  }

  final lengthSquared = (dx * dx) + (dy * dy);
  final t =
      (((point.dx - start.dx) * dx) + ((point.dy - start.dy) * dy)) /
      lengthSquared;
  final clampedT = t.clamp(0.0, 1.0);
  final projection = Offset(
    start.dx + (clampedT * dx),
    start.dy + (clampedT * dy),
  );
  return (point - projection).distance;
}

Rect? _erasePathBounds(List<Offset> erasePath, double radius) {
  if (erasePath.isEmpty) return null;
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final point in erasePath) {
    if (point.dx < minX) minX = point.dx;
    if (point.dy < minY) minY = point.dy;
    if (point.dx > maxX) maxX = point.dx;
    if (point.dy > maxY) maxY = point.dy;
  }
  if (!minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite) {
    return null;
  }
  return Rect.fromLTRB(minX - radius, minY - radius, maxX + radius, maxY + radius);
}

Rect _strokeBounds(List<Offset> points, double pad) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final point in points) {
    if (point.dx < minX) minX = point.dx;
    if (point.dy < minY) minY = point.dy;
    if (point.dx > maxX) maxX = point.dx;
    if (point.dy > maxY) maxY = point.dy;
  }
  return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
}

Offset _lerpOffset(Offset start, Offset end, double t) {
  return Offset(
    start.dx + (end.dx - start.dx) * t,
    start.dy + (end.dy - start.dy) * t,
  );
}

bool _pointWithinErasePath(Offset point, List<Offset> path, double radius) {
  for (var i = 0; i < path.length - 1; i++) {
    final start = path[i];
    final end = path[i + 1];
    if (point.dx < math.min(start.dx, end.dx) - radius ||
        point.dx > math.max(start.dx, end.dx) + radius ||
        point.dy < math.min(start.dy, end.dy) - radius ||
        point.dy > math.max(start.dy, end.dy) + radius) {
      continue;
    }
    if (_distanceToSegment(point, start, end) <= radius) return true;
  }
  return false;
}

bool _samePointList(List<Offset> a, List<Offset> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).distanceSquared > 0.000001) return false;
  }
  return true;
}

/// Splits [strokePoints] into the polylines that survive a sweep of an eraser
/// of [eraseRadius] along [erasePath].
///
/// Every stroke segment is clipped where it enters and leaves the eraser
/// swath, so the hole matches the swept area and no line is left bridging the
/// erased gap. (Filtering whole points instead used to leave the line intact
/// whenever the eraser crossed between two samples, and it made the ink
/// reappear across the hole.)
///
/// Returns the original list instance when nothing is erased, so callers can
/// detect untouched strokes cheaply.
List<List<Offset>> splitStrokeByEraserPath({
  required List<Offset> strokePoints,
  required List<Offset> erasePath,
  required double eraseRadius,
}) {
  if (strokePoints.isEmpty) return const <List<Offset>>[];
  if (eraseRadius <= 0 || erasePath.isEmpty) {
    return <List<Offset>>[strokePoints];
  }
  // A tap erases a disc: treat the single point as a zero-length segment.
  final path = erasePath.length == 1
      ? <Offset>[erasePath.first, erasePath.first]
      : erasePath;
  final bounds = _erasePathBounds(path, eraseRadius);
  if (bounds == null) return <List<Offset>>[strokePoints];

  final sampleStep = math.max(1.0, eraseRadius / 2);
  final segments = <List<Offset>>[];
  var current = <Offset>[];
  var erasedAnything = false;

  void flush() {
    if (current.length >= 2) segments.add(current);
    current = <Offset>[];
  }

  void add(Offset point) {
    if (current.isEmpty || (current.last - point).distanceSquared > 0.000001) {
      current.add(point);
    }
  }

  for (var i = 0; i < strokePoints.length - 1; i++) {
    final start = strokePoints[i];
    final end = strokePoints[i + 1];
    final length = (end - start).distance;
    if (length <= 0.0001) {
      if (_pointWithinErasePath(start, path, eraseRadius)) {
        erasedAnything = true;
        flush();
      } else {
        add(start);
      }
      continue;
    }
    if (!Rect.fromPoints(start, end).overlaps(bounds)) {
      add(start);
      add(end);
      continue;
    }
    final steps = math.max(1, (length / sampleStep).ceil());
    var touched = false;
    for (var s = 0; s <= steps; s++) {
      final point = _lerpOffset(start, end, s / steps);
      if (_pointWithinErasePath(point, path, eraseRadius)) {
        touched = true;
        break;
      }
    }
    if (!touched) {
      add(start);
      add(end);
      continue;
    }
    erasedAnything = true;
    for (var s = 0; s <= steps; s++) {
      final point = _lerpOffset(start, end, s / steps);
      if (_pointWithinErasePath(point, path, eraseRadius)) {
        flush();
      } else {
        add(point);
      }
    }
  }
  flush();

  if (!erasedAnything) return <List<Offset>>[strokePoints];
  return segments;
}

bool _elementTouchesErasePath(
  CanvasElement element,
  List<Offset> points,
  double brushRadius,
) {
  if (element is StrokeElement) {
    final strokePoints = element.points;
    if (strokePoints.length < 2 || points.isEmpty) return false;

    final strokeRadius = element.strokeWidth;
    for (final erasePoint in points) {
      for (var i = 0; i < strokePoints.length - 1; i++) {
        final distance = _distanceToSegment(
          erasePoint,
          strokePoints[i],
          strokePoints[i + 1],
        );
        if (distance <= brushRadius + (strokeRadius / 2)) {
          return true;
        }
      }
    }
    return false;
  }

  final bounds = _elementBounds(element);
  if (bounds == null) return false;
  for (final erasePoint in points) {
    if (bounds.inflate(brushRadius).contains(erasePoint)) {
      return true;
    }
  }
  return false;
}

int _readElementOrder({
  required String elementId,
  required Map<String, dynamic> payload,
  required Map<String, int> currentOrder,
  required int fallbackOrder,
}) {
  final explicit = (payload['z'] as num?)?.toInt();
  if (explicit != null) return explicit;

  if (currentOrder.containsKey(elementId)) {
    return currentOrder[elementId]!;
  }

  return fallbackOrder;
}
