part of 'canvas_screen.dart';

enum _ElementKind { stroke, shape, text, image, stickyNote, connector }

class _CanvasElement {
  final String id;
  final int z;
  final _ElementKind kind;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String brushType;
  final CanvasShapeType? shapeType;
  final Offset center;
  final double size;
  final double width;
  final double height;
  final String imageBase64;
  final bool isFilled;
  final String text;
  final double rotation;
  final String? startElementId;
  final Offset startPoint;
  final String startAnchor;
  final String? endElementId;
  final Offset endPoint;
  final String endAnchor;
  final String lineStyle;
  final bool hasArrowhead;
  final Map<String, dynamic> data;

  Rect? get bounds {
    if (kind == _ElementKind.image || kind == _ElementKind.stickyNote) {
      return Rect.fromCenter(center: center, width: width, height: height)
          .inflate(8);
    }
    if (kind == _ElementKind.connector) {
      return Rect.fromPoints(startPoint, endPoint).inflate(strokeWidth + 12);
    }
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
    this.z = 0,
    required this.kind,
    this.points = const [],
    required this.color,
    this.strokeWidth = 2,
    this.opacity = 1,
    this.brushType = 'solid',
    this.shapeType,
    this.center = Offset.zero,
    this.size = 0,
    this.width = 100,
    this.height = 100,
    this.imageBase64 = '',
    this.isFilled = false,
    this.text = '',
    this.rotation = 0,
    this.startElementId,
    this.startPoint = Offset.zero,
    this.startAnchor = 'center',
    this.endElementId,
    this.endPoint = Offset.zero,
    this.endAnchor = 'center',
    this.lineStyle = 'straight',
    this.hasArrowhead = true,
    this.data = const {},
  });

  factory _CanvasElement.stroke({
    required String id,
    int z = 0,
    required List<Offset> points,
    required Color color,
    required double strokeWidth,
    required double opacity,
    required String brushType,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      z: z,
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
    int z = 0,
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
      z: z,
      kind: _ElementKind.shape,
      shapeType: shapeType,
      center: center,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      isFilled: isFilled,
      rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
      data: data,
    );
  }

  factory _CanvasElement.text({
    required String id,
    int z = 0,
    required Offset center,
    required String text,
    required Color color,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      z: z,
      kind: _ElementKind.text,
      center: center,
      text: text,
      color: color,
      data: data,
    );
  }

  factory _CanvasElement.image({
    required String id,
    int z = 0,
    required Offset center,
    required double width,
    required double height,
    required String imageBase64,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      z: z,
      kind: _ElementKind.image,
      center: center,
      width: width,
      height: height,
      imageBase64: imageBase64,
      color: Colors.transparent,
      data: data,
    );
  }

  factory _CanvasElement.stickyNote({
    required String id,
    int z = 0,
    required Offset center,
    required double width,
    required double height,
    required String text,
    required Color color,
    double rotation = 0,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      z: z,
      kind: _ElementKind.stickyNote,
      center: center,
      size: math.max(width, height),
      width: width,
      height: height,
      text: text,
      color: color,
      rotation: rotation,
      data: data,
    );
  }

  factory _CanvasElement.connector({
    required String id,
    int z = 0,
    String? startElementId,
    required Offset startPoint,
    String startAnchor = 'center',
    String? endElementId,
    required Offset endPoint,
    String endAnchor = 'center',
    String lineStyle = 'straight',
    required Color color,
    required double strokeWidth,
    bool hasArrowhead = true,
    Map<String, dynamic> data = const {},
  }) {
    final center = Offset(
      (startPoint.dx + endPoint.dx) / 2,
      (startPoint.dy + endPoint.dy) / 2,
    );
    final dist = (endPoint - startPoint).distance;
    return _CanvasElement._(
      id: id,
      z: z,
      kind: _ElementKind.connector,
      center: center,
      size: dist,
      width: (endPoint.dx - startPoint.dx).abs(),
      height: (endPoint.dy - startPoint.dy).abs(),
      startElementId: startElementId,
      startPoint: startPoint,
      startAnchor: startAnchor,
      endElementId: endElementId,
      endPoint: endPoint,
      endAnchor: endAnchor,
      lineStyle: lineStyle,
      color: color,
      strokeWidth: strokeWidth,
      hasArrowhead: hasArrowhead,
      data: data,
    );
  }

  _CanvasElement copyWith({
    int? z,
    List<Offset>? points,
    Offset? center,
    double? size,
    double? width,
    double? height,
    Color? color,
    double? strokeWidth,
    double? rotation,
    String? text,
    Map<String, dynamic>? data,
    bool? isFilled,
  }) {
    return _CanvasElement._(
      id: id,
      z: z ?? this.z,
      kind: kind,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity,
      brushType: brushType,
      shapeType: shapeType,
      center: center ?? this.center,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      imageBase64: imageBase64,
      isFilled: isFilled ?? this.isFilled,
      text: text ?? this.text,
      rotation: rotation ?? this.rotation,
      startElementId: startElementId,
      startPoint: startPoint,
      startAnchor: startAnchor,
      endElementId: endElementId,
      endPoint: endPoint,
      endAnchor: endAnchor,
      lineStyle: lineStyle,
      hasArrowhead: hasArrowhead,
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
  final bool isDrawingShape;
  final Offset? shapeDrawStart;
  final Offset? shapeDrawCurrent;
  final CanvasShapeType? pendingShapeType;

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
    this.isDrawingShape = false,
    this.shapeDrawStart,
    this.shapeDrawCurrent,
    this.pendingShapeType,
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
        case _ElementKind.image:
          _paintImage(canvas, element);
          break;
        case _ElementKind.stickyNote:
          _paintStickyNote(canvas, element);
          break;
        case _ElementKind.connector:
          _paintConnector(canvas, element);
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

    // Draw shape creation preview
    if (isDrawingShape && shapeDrawStart != null && shapeDrawCurrent != null) {
      _paintShapeDrawPreview(canvas, shapeDrawStart!, shapeDrawCurrent!);
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
      case CanvasShapeType.arrow:
        final p = Path();
        final halfW = s * 0.65;
        final halfH = s * 0.35;
        final headLen = s * 0.42;
        final shaftThickness = halfH * 0.45;

        final left = c.dx - halfW;
        final right = c.dx + halfW;
        final headStart = right - headLen;

        p.moveTo(left, c.dy - shaftThickness / 2);
        p.lineTo(headStart, c.dy - shaftThickness / 2);
        p.lineTo(headStart, c.dy - halfH);
        p.lineTo(right, c.dy);
        p.lineTo(headStart, c.dy + halfH);
        p.lineTo(headStart, c.dy + shaftThickness / 2);
        p.lineTo(left, c.dy + shaftThickness / 2);
        p.close();

        canvas.drawPath(p, paint);
        break;
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

  void _paintShapeDrawPreview(Canvas canvas, Offset start, Offset current) {
    final rect = Rect.fromPoints(start, current);
    final dashPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, dashPaint);

    if (pendingShapeType == CanvasShapeType.arrow) {
      final angle = math.atan2(current.dy - start.dy, current.dx - start.dx);
      canvas.drawLine(start, current, dashPaint);
      const headLen = 14.0;
      final arrowPath = Path()
        ..moveTo(current.dx, current.dy)
        ..lineTo(
          current.dx - headLen * math.cos(angle - 0.45),
          current.dy - headLen * math.sin(angle - 0.45),
        )
        ..lineTo(
          current.dx - headLen * math.cos(angle + 0.45),
          current.dy - headLen * math.sin(angle + 0.45),
        )
        ..close();
      final fillPaint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawPath(arrowPath, fillPaint);
    }

    // Draw size label near the center
    final size = math.max((current.dx - start.dx).abs(), (current.dy - start.dy).abs());
    final sizeText = TextSpan(
      text: size.toStringAsFixed(0),
      style: const TextStyle(
        color: Colors.blueAccent,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
    final tp = TextPainter(
      text: sizeText,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.bottom + 4));
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

  void _paintImage(Canvas canvas, _CanvasElement element) {
    final rect = Rect.fromCenter(
      center: element.center,
      width: element.width,
      height: element.height,
    );
    final fillPaint = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    final textSpan = TextSpan(
      text: '[Image: ${element.width.toInt()}x${element.height.toInt()}]',
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  Offset _resolveAnchor(String? elementId, String anchor, Offset fallback) {
    if (elementId == null) return fallback;
    final target = elements.where((e) => e.id == elementId).firstOrNull;
    if (target == null) return fallback;

    Rect targetBounds;
    if (target.kind == _ElementKind.shape) {
      targetBounds = Rect.fromCenter(
        center: target.center,
        width: target.size * 1.2,
        height: target.size * 1.2,
      );
    } else if (target.kind == _ElementKind.stickyNote || target.kind == _ElementKind.image) {
      targetBounds = Rect.fromCenter(
        center: target.center,
        width: target.width,
        height: target.height,
      );
    } else if (target.bounds != null) {
      targetBounds = target.bounds!;
    } else {
      return target.center;
    }

    switch (anchor) {
      case 'top':
        return Offset(targetBounds.center.dx, targetBounds.top);
      case 'bottom':
        return Offset(targetBounds.center.dx, targetBounds.bottom);
      case 'left':
        return Offset(targetBounds.left, targetBounds.center.dy);
      case 'right':
        return Offset(targetBounds.right, targetBounds.center.dy);
      case 'center':
      default:
        return targetBounds.center;
    }
  }

  void _paintStickyNote(Canvas canvas, _CanvasElement element) {
    canvas.save();
    if (element.rotation != 0) {
      canvas.translate(element.center.dx, element.center.dy);
      canvas.rotate(element.rotation);
      canvas.translate(-element.center.dx, -element.center.dy);
    }

    final rect = Rect.fromCenter(
      center: element.center,
      width: element.width,
      height: element.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // 1. Double soft drop shadow (ambient + elevation)
    final ambientShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), ambientShadowPaint);

    final dropShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect.shift(const Offset(2, 6)), dropShadowPaint);

    // 2. Paper gradient body (subtle natural top-to-bottom lighting)
    final hsl = HSLColor.fromColor(element.color);
    final topColor =
        hsl.withLightness((hsl.lightness + 0.03).clamp(0.0, 1.0)).toColor();
    final bottomColor =
        hsl.withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0)).toColor();

    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [topColor, bottomColor],
      )
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bodyPaint);

    // 3. Top adhesive strip
    final tapeHeight = math.min(22.0, rect.height * 0.15);
    final tapeRect = Rect.fromLTWH(rect.left, rect.top, rect.width, tapeHeight);
    final tapeRRect = RRect.fromRectAndCorners(
      tapeRect,
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
    );
    final tapePaint = Paint()
      ..color = Colors.white.withOpacity(0.20)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(tapeRRect, tapePaint);

    final tapeLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(rect.left, rect.top + tapeHeight),
      Offset(rect.right, rect.top + tapeHeight),
      tapeLinePaint,
    );

    // 4. Subtle bottom-right paper curl effect
    const curlSize = 14.0;
    final curlPath = Path()
      ..moveTo(rect.right - curlSize, rect.bottom)
      ..lineTo(rect.right, rect.bottom - curlSize)
      ..lineTo(rect.right - curlSize, rect.bottom - curlSize)
      ..close();
    final curlShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(curlPath.shift(const Offset(-1, -1)), curlShadowPaint);

    final curlPaint = Paint()
      ..color =
          hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawPath(curlPath, curlPaint);

    // 5. Crisp subtle paper border
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    // 6. Refined text typography with comfortable padding
    if (element.text.isNotEmpty) {
      final textSpan = TextSpan(
        text: element.text,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: ((element.height - tapeHeight - 12) / 19).floor().clamp(1, 30),
        ellipsis: '...',
      )..layout(maxWidth: math.max(20, element.width - 24));

      textPainter.paint(
        canvas,
        Offset(rect.left + 12, rect.top + tapeHeight + 6),
      );
    }

    canvas.restore();
  }

  void _paintConnector(Canvas canvas, _CanvasElement element) {
    final start = _resolveAnchor(element.startElementId, element.startAnchor, element.startPoint);
    final end = _resolveAnchor(element.endElementId, element.endAnchor, element.endPoint);

    final linePaint = Paint()
      ..color = element.color
      ..strokeWidth = element.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(start.dx, start.dy);

    if (element.lineStyle == 'curved') {
      final dx = (end.dx - start.dx).abs();
      final dy = (end.dy - start.dy).abs();
      final ctrlOffset = math.max(dx, dy) * 0.45;
      final cp1 = Offset(start.dx + (end.dx > start.dx ? ctrlOffset : -ctrlOffset), start.dy);
      final cp2 = Offset(end.dx - (end.dx > start.dx ? ctrlOffset : -ctrlOffset), end.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    } else if (element.lineStyle == 'orthogonal') {
      final midX = (start.dx + end.dx) / 2;
      path.lineTo(midX, start.dy);
      path.lineTo(midX, end.dy);
      path.lineTo(end.dx, end.dy);
    } else {
      path.lineTo(end.dx, end.dy);
    }

    canvas.drawPath(path, linePaint);

    if (element.hasArrowhead) {
      final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
      const arrowLen = 14.0;
      const arrowAngle = 0.45;

      final arrowPath = Path();
      arrowPath.moveTo(end.dx, end.dy);
      arrowPath.lineTo(
        end.dx - arrowLen * math.cos(angle - arrowAngle),
        end.dy - arrowLen * math.sin(angle - arrowAngle),
      );
      arrowPath.lineTo(
        end.dx - arrowLen * math.cos(angle + arrowAngle),
        end.dy - arrowLen * math.sin(angle + arrowAngle),
      );
      arrowPath.close();

      final arrowPaint = Paint()
        ..color = element.color
        ..style = PaintingStyle.fill;
      canvas.drawPath(arrowPath, arrowPaint);
    }

    if (selectedShapeId == element.id) {
      final highlightPaint = Paint()
        ..color = Colors.blueAccent.withOpacity(0.5)
        ..strokeWidth = element.strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, highlightPaint);
    }
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
        oldDelegate.viewportOffset != viewportOffset ||
        oldDelegate.isDrawingShape != isDrawingShape ||
        oldDelegate.shapeDrawStart != shapeDrawStart ||
        oldDelegate.shapeDrawCurrent != shapeDrawCurrent;
  }
}
