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
  return '$shapeId|$cx|$cy|$size|$rotation|$borderRadius|$color|$filled';
}

Rect? _elementBounds(CanvasElement element) {
  return switch (element) {
    ShapeElement e => Rect.fromCenter(
        center: e.center, width: e.size, height: e.size,
      ),
    TextElement e => Rect.fromCenter(
        center: e.center, width: 180, height: 48,
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

List<List<Offset>> _splitStrokeByErasePath({
  required List<Offset> strokePoints,
  required List<Offset> erasePath,
  required double eraseRadius,
}) {
  if (strokePoints.length < 2 || erasePath.length < 2) {
    return <List<Offset>>[strokePoints];
  }

  final keepMask = List<bool>.filled(strokePoints.length, true);
  for (var i = 0; i < strokePoints.length; i++) {
    final point = strokePoints[i];
    for (var j = 0; j < erasePath.length - 1; j++) {
      final distance = _distanceToSegment(
        point,
        erasePath[j],
        erasePath[j + 1],
      );
      if (distance <= eraseRadius) {
        keepMask[i] = false;
        break;
      }
    }
  }

  final segments = <List<Offset>>[];
  var currentSegment = <Offset>[];

  for (var i = 0; i < strokePoints.length; i++) {
    if (keepMask[i]) {
      currentSegment.add(strokePoints[i]);
    } else {
      if (currentSegment.length >= 2) {
        segments.add(List<Offset>.from(currentSegment));
      }
      currentSegment = <Offset>[];
    }
  }

  if (currentSegment.length >= 2) {
    segments.add(currentSegment);
  }

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
