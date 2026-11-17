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

/// Computed geometry (center, size, rotation, width, height) for shape
/// creation and preview.
///
/// Keeps the starting point [start] strictly fixed as the anchor so the shape
/// expands away from where the user started rather than drifting or sliding.
/// [width]/[height] are the true box dimensions: rectangle and ellipse use the
/// drag box directly (free aspect), regular shapes stay uniform, and line/arrow
/// are flat segments ([height] == 0). [size] is retained for legacy callers.
class ShapeGeometry {
  final Offset center;
  final double size;
  final double rotation;
  final double width;
  final double height;

  const ShapeGeometry({
    required this.center,
    required this.size,
    required this.rotation,
    this.width = 0,
    this.height = 0,
  });

  static ShapeGeometry compute({
    required CanvasShapeType shapeType,
    required Offset start,
    required Offset current,
  }) {
    final absDx = (current.dx - start.dx).abs();
    final absDy = (current.dy - start.dy).abs();
    final dragDistance = (current - start).distance;

    if (shapeType == CanvasShapeType.arrow ||
        shapeType == CanvasShapeType.line) {
      final length = dragDistance.clamp(1.0, 1200.0);
      final rotation = math.atan2(current.dy - start.dy, current.dx - start.dx);
      final center = Offset(
        (start.dx + current.dx) / 2,
        (start.dy + current.dy) / 2,
      );
      return ShapeGeometry(
        center: center,
        // Legacy arrow size kept the 1.3 head proportion; the true segment
        // length lives in width so the flat box renders at the drag length.
        size: shapeType == CanvasShapeType.arrow ? length / 1.3 : length,
        rotation: rotation,
        width: length,
        height: 0,
      );
    }

    final signX = current.dx >= start.dx ? 1.0 : -1.0;
    final signY = current.dy >= start.dy ? 1.0 : -1.0;
    final double width;
    final double height;

    switch (shapeType) {
      case CanvasShapeType.rectangle:
      case CanvasShapeType.ellipse:
        width = absDx.clamp(1.0, 1200.0);
        height = absDy.clamp(1.0, 1200.0);
        break;
      default:
        final uniform = math.max(absDx, absDy).clamp(1.0, 1200.0);
        width = uniform;
        height = uniform;
        break;
    }

    final center = Offset(
      start.dx + signX * (width / 2),
      start.dy + signY * (height / 2),
    );

    return ShapeGeometry(
      center: center,
      size: math.max(width, height),
      rotation: 0.0,
      width: width,
      height: height,
    );
  }
}

