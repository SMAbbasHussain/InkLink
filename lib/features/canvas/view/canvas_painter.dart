part of 'canvas_screen.dart';

enum _ElementKind { stroke, shape, text }

class _CanvasElement {
  final String id;
  final _ElementKind kind;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String brushType;
  final CanvasShapeType? shapeType;
  final Offset center;
  final double size;
  final bool isFilled;
  final String text;
  final Map<String, dynamic> data;

  Rect? get bounds {
    if (points.isEmpty) return null;
    double minX = points.first.dx;
    double minY = points.first.dy;
    double maxX = points.first.dx;
    double maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(strokeWidth + 8);
  }

  const _CanvasElement._({
    required this.id,
    required this.kind,
    this.points = const [],
    required this.color,
    this.strokeWidth = 2,
    this.opacity = 1,
    this.brushType = 'solid',
    this.shapeType,
    this.center = Offset.zero,
    this.size = 0,
    this.isFilled = false,
    this.text = '',
    this.data = const {},
  });

  factory _CanvasElement.stroke({
    required String id,
    required List<Offset> points,
    required Color color,
    required double strokeWidth,
    required double opacity,
    required String brushType,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.stroke,
      points: points,
      color: color,
      strokeWidth: strokeWidth,
      opacity: opacity,
      brushType: brushType,
      data: data,
    );
  }

  factory _CanvasElement.shape({
    required String id,
    required CanvasShapeType shapeType,
    required Offset center,
    required double size,
    required Color color,
    required double strokeWidth,
    required bool isFilled,
    required Map<String, dynamic> data,
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.shape,
      shapeType: shapeType,
      center: center,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      isFilled: isFilled,
      data: data,
    );
  }

  factory _CanvasElement.text({
    required String id,
    required Offset center,
    required String text,
    required Color color,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.text,
      center: center,
      text: text,
      color: color,
      data: data,
    );
  }

  _CanvasElement copyWith({
    List<Offset>? points,
    Offset? center,
    double? size,
    Map<String, dynamic>? data,
    bool? isFilled,
  }) {
    return _CanvasElement._(
      id: id,
      kind: kind,
      points: points ?? this.points,
      color: color,
      strokeWidth: strokeWidth,
      opacity: opacity,
      brushType: brushType,
      shapeType: shapeType,
      center: center ?? this.center,
      size: size ?? this.size,
      isFilled: isFilled ?? this.isFilled,
      text: text,
      data: data ?? this.data,
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<_CanvasElement> elements;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final String currentBrushType;
  final String? selectedShapeId;
  final double viewportScale;
  final Offset viewportOffset;
  final bool showEraserPreview;

  const _CanvasPainter({
    required this.elements,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentBrushType,
    required this.selectedShapeId,
    required this.viewportScale,
    required this.viewportOffset,
    required this.showEraserPreview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);
    canvas.scale(viewportScale);

    for (final element in elements) {
      switch (element.kind) {
        case _ElementKind.stroke:
          if (selectedShapeId == element.id) {
            _paintStrokeHighlight(canvas, element);
          }
          _paintStroke(
            canvas,
            element.points,
            element.color,
            element.strokeWidth,
            opacity: element.opacity,
            brushType: element.brushType,
          );
          break;
        case _ElementKind.shape:
          _paintShape(canvas, element);
          break;
        case _ElementKind.text:
          _paintText(canvas, element);
          break;
      }
    }

    if (currentPoints.length > 1) {
      if (currentBrushType != 'eraser') {
        _paintStroke(
          canvas,
          currentPoints,
          currentColor,
          currentStrokeWidth,
          opacity: 1,
          brushType: currentBrushType,
        );
      } else if (showEraserPreview) {
        _paintEraserPreview(canvas, currentPoints.last, currentStrokeWidth);
      }
    }

    canvas.restore();
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width, {
    required double opacity,
    required String brushType,
  }) {
    final effectiveWidth = brushType == 'watercolor'
        ? width * 1.25
        : brushType == 'textured'
        ? width * 0.95
        : width;
    final effectiveOpacity = brushType == 'watercolor'
        ? opacity * 0.45
        : brushType == 'textured'
        ? opacity * 0.8
        : opacity;
    final paint = Paint()
      ..color = color.withOpacity(effectiveOpacity.clamp(0, 1))
      ..strokeWidth = effectiveWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = brushType == 'watercolor'
          ? const MaskFilter.blur(BlurStyle.normal, 2.5)
          : null;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _paintStrokeHighlight(Canvas canvas, _CanvasElement element) {
    final points = element.points;
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = element.strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _paintShape(Canvas canvas, _CanvasElement element) {
    final paint = Paint()
      ..color = element.color
      ..style = element.isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth;

    final highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final c = element.center;
    final s = element.size;
    final borderRadius =
        (element.data['borderRadius'] as num?)?.toDouble() ?? 0.0;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    final rotation = (element.data['rotation'] as num?)?.toDouble() ?? 0.0;
    canvas.rotate(rotation);
    canvas.translate(-c.dx, -c.dy);

    switch (element.shapeType!) {
      case CanvasShapeType.square:
        final rect = Rect.fromCenter(center: c, width: s, height: s);
        if (borderRadius > 0) {
          final clamped = borderRadius.clamp(0.0, s / 2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(clamped)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        break;
      case CanvasShapeType.rectangle:
        final rect = Rect.fromCenter(
          center: c,
          width: s * 1.35,
          height: s * 0.8,
        );
        if (borderRadius > 0) {
          final clamped = borderRadius.clamp(
            0.0,
            math.min(rect.width, rect.height) / 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(clamped)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        break;
      case CanvasShapeType.circle:
        canvas.drawCircle(c, s / 2, paint);
        break;
      case CanvasShapeType.ellipse:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: s * 1.3, height: s * 0.85),
          paint,
        );
        break;
      case CanvasShapeType.triangle:
        final p = Path()
          ..moveTo(c.dx, c.dy - s / 2)
          ..lineTo(c.dx - s / 2, c.dy + s / 2)
          ..lineTo(c.dx + s / 2, c.dy + s / 2)
          ..close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.diamond:
        final p = Path()
          ..moveTo(c.dx, c.dy - s / 2)
          ..lineTo(c.dx - s / 2, c.dy)
          ..lineTo(c.dx, c.dy + s / 2)
          ..lineTo(c.dx + s / 2, c.dy)
          ..close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.star:
        final p = Path();
        for (int i = 0; i < 5; i++) {
          final outerAngle = (math.pi / 2) + i * (2 * math.pi / 5);
          final innerAngle = outerAngle + (math.pi / 5);
          final outer = Offset(
            c.dx + math.cos(outerAngle) * (s / 2),
            c.dy - math.sin(outerAngle) * (s / 2),
          );
          final inner = Offset(
            c.dx + math.cos(innerAngle) * (s / 4),
            c.dy - math.sin(innerAngle) * (s / 4),
          );
          if (i == 0) {
            p.moveTo(outer.dx, outer.dy);
          } else {
            p.lineTo(outer.dx, outer.dy);
          }
          p.lineTo(inner.dx, inner.dy);
        }
        p.close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.pentagon:
        final p = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 5);
          final point = Offset(
            c.dx + math.cos(angle) * (s / 2),
            c.dy - math.sin(angle) * (s / 2),
          );
          if (i == 0) {
            p.moveTo(point.dx, point.dy);
          } else {
            p.lineTo(point.dx, point.dy);
          }
        }
        p.close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.line:
        canvas.drawLine(
          Offset(c.dx - s / 2, c.dy),
          Offset(c.dx + s / 2, c.dy),
          paint,
        );
        break;
      case CanvasShapeType.hexagon:
        final p = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 6);
          final point = Offset(
            c.dx + math.cos(angle) * (s / 2),
            c.dy - math.sin(angle) * (s / 2),
          );
          if (i == 0) {
            p.moveTo(point.dx, point.dy);
          } else {
            p.lineTo(point.dx, point.dy);
          }
        }
        p.close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.semicircle:
        final rect = Rect.fromCenter(center: c, width: s, height: s);
        canvas.drawArc(rect, math.pi, math.pi, true, paint);
        break;
    }

    if (selectedShapeId == element.id) {
      canvas.drawCircle(c, (s / 2) + 10, highlightPaint);
    }

    canvas.restore();
  }

  void _paintEraserPreview(Canvas canvas, Offset position, double radius) {
    final previewPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(position, radius, previewPaint);
  }

  void _paintText(Canvas canvas, _CanvasElement element) {
    final textSpan = TextSpan(
      text: element.text,
      style: TextStyle(
        color: element.color,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: 220);

    textPainter.paint(canvas, Offset(element.center.dx, element.center.dy));
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth ||
        oldDelegate.currentBrushType != currentBrushType ||
        oldDelegate.selectedShapeId != selectedShapeId ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.viewportOffset != viewportOffset;
  }
}
