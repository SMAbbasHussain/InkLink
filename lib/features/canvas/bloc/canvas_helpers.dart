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
  // Compare the rendered box, not the raw width/height/size: a legacy
  // `size`-only payload and its migrated explicit width/height render the
  // same, so migrating on first edit is not itself a user-visible change.
  final parsed = CanvasElement.fromMap(shapeId, data);
  final double boxWidth;
  final double boxHeight;
  if (parsed is ShapeElement) {
    final box = shapeElementRect(parsed);
    boxWidth = box.width;
    boxHeight = box.height;
  } else {
    boxWidth = (data['width'] as num?)?.toDouble() ?? 0.0;
    boxHeight = (data['height'] as num?)?.toDouble() ?? 0.0;
  }
  final size = math.max(boxWidth, boxHeight).toStringAsFixed(3);
  final width = boxWidth.toStringAsFixed(3);
  final height = boxHeight.toStringAsFixed(3);
  final strokeWidth = ((data['strokeWidth'] as num?)?.toDouble() ?? 0.0)
      .toStringAsFixed(3);
  final opacity = ((data['opacity'] as num?)?.toDouble() ?? 1.0)
      .toStringAsFixed(3);
  final strokeOpacity = ((data['strokeOpacity'] as num?)?.toDouble() ?? 1.0)
      .toStringAsFixed(3);
  final rotation = _normalizeRotation(
    (data['rotation'] as num?)?.toDouble() ?? 0.0,
  ).toStringAsFixed(5);
  final borderRadius = ((data['borderRadius'] as num?)?.toDouble() ?? 0.0)
      .toStringAsFixed(3);
  final color = ((data['color'] as num?)?.toInt() ?? 0).toString();
  final filled = _parseBool(data['isFilled']).toString();
  final hidden = _parseBool(data['hidden']).toString();
  final locked = _parseBool(data['locked']).toString();
  final flipped = _parseBool(data['flipped']).toString();
  final text = (data['text'] as String?) ?? '';
  final z = ((data['z'] as num?)?.toInt() ?? 0).toString();
  final dash =
      (data['dashPattern'] as List?)
          ?.map((e) => ((e as num).toDouble()).toStringAsFixed(3))
          .join(',') ??
      '';
  final label = (data['label'] as String?) ?? '';
  final labelColor = ((data['labelColor'] as num?)?.toInt() ?? -1).toString();
  final labelFontSize = ((data['labelFontSize'] as num?)?.toDouble() ?? 14.0)
      .toStringAsFixed(3);
  final labelFontWeight = ((data['labelFontWeight'] as num?)?.toInt() ?? 600)
      .toString();
  final labelTextAlign = (data['labelTextAlign'] as String?) ?? 'center';
  final startArrowhead = _parseBool(data['startArrowhead']).toString();
  final endArrowhead = _parseBool(data['endArrowhead']).toString();
  return '$shapeId|$cx|$cy|$size|$width|$height|$strokeWidth|$opacity|$strokeOpacity|$rotation|$borderRadius|$color|$filled|$hidden|$locked|$flipped|$z|$text|$dash|$label|$labelColor|$labelFontSize|$labelFontWeight|$labelTextAlign|$startArrowhead|$endArrowhead';
}

/// Applies pending shape edits from sliders/UI onto [data] with the same
/// clamps the dedicated events use, so preview and commit cannot drift.
void _applyPendingShapeEdits(
  Map<String, dynamic> data,
  Map<String, dynamic> pending,
) {
  for (final entry in pending.entries) {
    final key = entry.key;
    if (key == 'rotation') {
      final rotation = _toDoubleValue(entry.value);
      if (rotation != null) data[key] = _normalizeRotation(rotation);
    } else if (key == 'size') {
      final size = _toDoubleValue(entry.value);
      if (size != null) data[key] = size.clamp(24.0, 320.0);
    } else if (key == 'width' || key == 'height') {
      final value = _toDoubleValue(entry.value);
      if (value != null) data[key] = value.clamp(1.0, 4000.0);
    } else if (key == 'borderRadius') {
      final borderRadius = _toDoubleValue(entry.value);
      if (borderRadius != null) {
        final size = _toDoubleValue(data['size']) ?? 64.0;
        final maxRadius = (size / 2).clamp(0.0, 180.0);
        data[key] = borderRadius.clamp(0.0, maxRadius);
      }
    } else if (key == 'strokeWidth') {
      final value = _toDoubleValue(entry.value);
      if (value != null) data[key] = value.clamp(0.0, 64.0);
    } else if (key == 'strokeOpacity' || key == 'opacity') {
      final value = _toDoubleValue(entry.value);
      if (value != null) data[key] = value.clamp(0.0, 1.0);
    } else if (key == 'labelFontSize') {
      final value = _toDoubleValue(entry.value);
      if (value != null) data[key] = value.clamp(6.0, 96.0);
    } else {
      data[key] = entry.value;
    }
  }
}

/// Measures the on-canvas bounds of [text] using the same layout the painter
/// and the text tool use, so persisted bounds match the render.
Size measureTextElementBounds(String text) {
  final layout = CanvasTextLayout.layout(text: text);
  return layout.size;
}

/// Eraser bounds delegate to the shared geometry so erasing, selection and
/// painting agree about where an element is.
Rect? _elementBounds(CanvasElement element) => elementBounds(element);

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
  return Rect.fromLTRB(
    minX - radius,
    minY - radius,
    maxX + radius,
    maxY + radius,
  );
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
