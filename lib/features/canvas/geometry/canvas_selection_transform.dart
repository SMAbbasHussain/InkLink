import 'dart:math' as math;
import 'dart:ui';

import '../models/canvas_element.dart';
import 'canvas_element_geometry.dart';

/// Serialized payload for [element] scaled from [source] into [target].
///
/// Shapes scale their true width/height independently (free aspect); linear
/// shapes scale their segment length and stay flat. Text keeps its font size
/// and re-wraps into the scaled box (scaling text is an explicit choice, per
/// the implementation guide). Attached connector ends follow their element
/// and are not rewritten.
Map<String, dynamic> scaleElementPayload(
  CanvasElement element,
  Rect source,
  Rect target,
) {
  final data = Map<String, dynamic>.from(element.toMap());
  if (source.width.abs() < 0.01 || source.height.abs() < 0.01) return data;
  final scaleX = target.width / source.width;
  final scaleY = target.height / source.height;
  final uniform = (scaleX.abs() + scaleY.abs()) / 2;

  Offset mapPoint(Offset point) => Offset(
    target.left + (point.dx - source.left) * scaleX,
    target.top + (point.dy - source.top) * scaleY,
  );

  if (element is StrokeElement) {
    data['points'] = [
      for (final point in element.points)
        {'x': mapPoint(point).dx, 'y': mapPoint(point).dy},
    ];
    data['strokeWidth'] = (element.strokeWidth * uniform).clamp(0.5, 64.0);
  } else if (element is ConnectorElement) {
    if (element.startElementId == null) {
      final start = mapPoint(element.startPoint);
      data['sx'] = start.dx;
      data['sy'] = start.dy;
    }
    if (element.endElementId == null) {
      final end = mapPoint(element.endPoint);
      data['ex'] = end.dx;
      data['ey'] = end.dy;
    }
  } else if (element is ShapeElement) {
    final center = mapPoint(element.center);
    data['cx'] = center.dx;
    data['cy'] = center.dy;
    final box = shapeElementRect(element);
    if (element.isLinear) {
      final w = (box.width * uniform).clamp(1.0, 4000.0);
      data['width'] = w;
      data['height'] = 0.0;
      data['size'] = w;
    } else {
      final w = (box.width * scaleX).clamp(1.0, 4000.0);
      final h = (box.height * scaleY).clamp(1.0, 4000.0);
      data['width'] = w;
      data['height'] = h;
      data['size'] = math.max(w, h);
    }
  } else if (element is TextElement) {
    final box = textElementRect(element);
    final topLeft = mapPoint(box.topLeft);
    data['cx'] = topLeft.dx;
    data['cy'] = topLeft.dy;
    data['width'] = (box.width * scaleX).clamp(8.0, 4000.0);
    data['height'] = (box.height * scaleY).clamp(8.0, 4000.0);
  } else if (element is StickyNoteElement) {
    final center = mapPoint(element.center);
    data['cx'] = center.dx;
    data['cy'] = center.dy;
    data['width'] = (element.width * scaleX).clamp(40.0, 2000.0);
    data['height'] = (element.height * scaleY).clamp(40.0, 2000.0);
    data['autoSize'] = false;
  } else if (element is ImageElement) {
    final center = mapPoint(element.center);
    data['cx'] = center.dx;
    data['cy'] = center.dy;
    data['width'] = (element.width * scaleX).clamp(20.0, 4000.0);
    data['height'] = (element.height * scaleY).clamp(20.0, 4000.0);
  }
  return data;
}

/// Serialized payload for [element] rotated around [pivot] by [radians].
///
/// Text orbits by its box centre and gains the delta on its own rotation.
/// Images orbit by centre and gain the delta on their rotation, so a group
/// rotate spins them instead of leaving them upright.
Map<String, dynamic> rotateElementPayload(
  CanvasElement element,
  Offset pivot,
  double radians,
) {
  final data = Map<String, dynamic>.from(element.toMap());
  if (radians == 0) return data;

  Offset rotate(Offset point) => rotatePoint(point, pivot, radians);

  if (element is StrokeElement) {
    data['points'] = [
      for (final point in element.points)
        {'x': rotate(point).dx, 'y': rotate(point).dy},
    ];
  } else if (element is ConnectorElement) {
    if (element.startElementId == null) {
      final start = rotate(element.startPoint);
      data['sx'] = start.dx;
      data['sy'] = start.dy;
    }
    if (element.endElementId == null) {
      final end = rotate(element.endPoint);
      data['ex'] = end.dx;
      data['ey'] = end.dy;
    }
  } else if (element is TextElement) {
    final box = textElementRect(element);
    final center = rotate(box.center);
    data['cx'] = center.dx - box.width / 2;
    data['cy'] = center.dy - box.height / 2;
    data['rotation'] = element.rotation + radians;
  } else if (element is ShapeElement) {
    final center = rotate(element.center);
    data['cx'] = center.dx;
    data['cy'] = center.dy;
    data['rotation'] = element.rotation + radians;
  } else if (element is StickyNoteElement) {
    final center = rotate(element.center);
    data['cx'] = center.dx;
    data['cy'] = center.dy;
    data['rotation'] = element.rotation + radians;
  } else if (element is ImageElement) {
    final center = rotate(element.center);
    data['cx'] = center.dx;
    data['cy'] = center.dy;
    data['rotation'] = element.rotation + radians;
  }
  return data;
}
