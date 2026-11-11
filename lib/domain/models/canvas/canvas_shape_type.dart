import 'dart:math' as math;
import 'dart:ui';

enum CanvasShapeType {
  square,
  rectangle,
  circle,
  ellipse,
  triangle,
  diamond,
  star,
  pentagon,
  hexagon,
  line,
  semicircle,
  arrow,
}

/// Computed geometry (center, size, rotation) for shape creation and preview.
///
/// Keeps the starting point [start] strictly fixed as the anchor so the shape
/// expands away from where the user started rather than drifting or sliding.
class ShapeGeometry {
  final Offset center;
  final double size;
  final double rotation;

  const ShapeGeometry({
    required this.center,
    required this.size,
    required this.rotation,
  });

  static ShapeGeometry compute({
    required CanvasShapeType shapeType,
    required Offset start,
    required Offset current,
  }) {
    final absDx = (current.dx - start.dx).abs();
    final absDy = (current.dy - start.dy).abs();
    final dragDistance = (current - start).distance;

    if (shapeType == CanvasShapeType.arrow) {
      final size = (dragDistance / 1.3).clamp(1.0, 1200.0);
      final rotation = math.atan2(current.dy - start.dy, current.dx - start.dx);
      final center = Offset(
        (start.dx + current.dx) / 2,
        (start.dy + current.dy) / 2,
      );
      return ShapeGeometry(
        center: center,
        size: size,
        rotation: rotation,
      );
    }

    if (shapeType == CanvasShapeType.line) {
      final size = dragDistance.clamp(1.0, 1200.0);
      final rotation = math.atan2(current.dy - start.dy, current.dx - start.dx);
      final center = Offset(
        (start.dx + current.dx) / 2,
        (start.dy + current.dy) / 2,
      );
      return ShapeGeometry(
        center: center,
        size: size,
        rotation: rotation,
      );
    }

    final signX = current.dx >= start.dx ? 1.0 : -1.0;
    final signY = current.dy >= start.dy ? 1.0 : -1.0;
    final double size;
    final double width;
    final double height;

    switch (shapeType) {
      case CanvasShapeType.rectangle:
        size = math.max(absDx / 1.35, absDy / 0.8).clamp(1.0, 1200.0);
        width = size * 1.35;
        height = size * 0.8;
        break;
      case CanvasShapeType.ellipse:
        size = math.max(absDx / 1.3, absDy / 0.85).clamp(1.0, 1200.0);
        width = size * 1.3;
        height = size * 0.85;
        break;
      default:
        size = math.max(absDx, absDy).clamp(1.0, 1200.0);
        width = size;
        height = size;
        break;
    }

    final center = Offset(
      start.dx + signX * (width / 2),
      start.dy + signY * (height / 2),
    );

    return ShapeGeometry(
      center: center,
      size: size,
      rotation: 0.0,
    );
  }
}

