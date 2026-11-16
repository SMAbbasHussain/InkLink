part of 'canvas_screen.dart';

enum _ElementKind { stroke, shape, text, image, stickyNote, connector, frame }

class _CanvasElement {
  final String id;
  final int z;
  final _ElementKind kind;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String brushType;
  final String brushId;
  final List<double> pressures;
  final List<double> tilts;
  final double spacing;
  final int textureSeed;
  final CanvasShapeType? shapeType;
  final Offset center;
  final double size;
  final double width;
  final double height;
  final String imageBase64;
  final bool isFilled;
  final String text;
  final double fontSize;
  final int fontWeight;
  final String? fontFamily;
  final String textAlign;
  final double lineHeight;
  final int maxLines;
  final Color? textBackgroundColor;
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

  /// World-space bounds used to composite this element's opacity layer.
  final Rect? layerBounds;

  Rect? get bounds {
    if (kind == _ElementKind.frame) {
      return Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      ).inflate(2);
    }
    if (kind == _ElementKind.image || kind == _ElementKind.stickyNote) {
      return rotatedRectBounds(
        Rect.fromCenter(center: center, width: width, height: height),
        rotation,
      ).inflate(8);
    }
    if (kind == _ElementKind.connector) {
      final sampled = connectorPolyline(startPoint, endPoint, lineStyle);
      var minX = sampled.first.dx;
      var minY = sampled.first.dy;
      var maxX = sampled.first.dx;
      var maxY = sampled.first.dy;
      for (final point in sampled.skip(1)) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(strokeWidth + 12);
    }
    if (kind == _ElementKind.shape) {
      return Rect.fromCenter(center: center, width: size * 1.6, height: size * 1.6)
          .inflate(strokeWidth + 8);
    }
    if (kind == _ElementKind.text) {
      return Rect.fromCenter(
        center: center,
        width: width > 0 ? width : 220,
        height: height > 0 ? height : 72,
      ).inflate(8);
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
    this.brushId = '',
    this.pressures = const [],
    this.tilts = const [],
    this.spacing = 0.25,
    this.textureSeed = 0,
    this.shapeType,
    this.center = Offset.zero,
    this.size = 0,
    this.width = 100,
    this.height = 100,
    this.imageBase64 = '',
    this.isFilled = false,
    this.text = '',
    this.fontSize = 16,
    this.fontWeight = 600,
    this.fontFamily,
    this.textAlign = 'left',
    this.lineHeight = 1.2,
    this.maxLines = 0,
    this.textBackgroundColor,
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
    this.layerBounds,
  });

  factory _CanvasElement.stroke({
    required String id,
    int z = 0,
    required List<Offset> points,
    required Color color,
    required double strokeWidth,
    required double opacity,
    required String brushType,
    String? brushId,
    List<double> pressures = const [],
    List<double> tilts = const [],
    double spacing = 0.25,
    int textureSeed = 0,
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
      brushId: (brushId != null && brushId.isNotEmpty) ? brushId : brushType,
      pressures: pressures,
      tilts: tilts,
      spacing: spacing,
      textureSeed: textureSeed,
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
    double width = 0,
    double height = 0,
    double fontSize = 16,
    int fontWeight = 600,
    String? fontFamily,
    String textAlign = 'left',
    double lineHeight = 1.2,
    double rotation = 0,
    int maxLines = 0,
    Color? backgroundColor,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      z: z,
      kind: _ElementKind.text,
      center: center,
      text: text,
      color: color,
      width: width,
      height: height,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      textAlign: textAlign,
      lineHeight: lineHeight,
      rotation: rotation,
      maxLines: maxLines,
      textBackgroundColor: backgroundColor,
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
      rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
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

  factory _CanvasElement.frame({
    required String id,
    int z = 0,
    required Offset center,
    required double width,
    required double height,
    required String title,
    required Color color,
    double cornerRadius = 12,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      z: z,
      kind: _ElementKind.frame,
      center: center,
      size: math.max(width, height),
      width: width,
      height: height,
      text: title,
      color: color,
      strokeWidth: cornerRadius,
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
    String? brushType,
    String? brushId,
    List<double>? pressures,
    double? spacing,
    int? textureSeed,
    double? rotation,
    String? text,
    Map<String, dynamic>? data,
    bool? isFilled,
    double? opacity,
    Rect? layerBounds,
  }) {
    return _CanvasElement._(
      id: id,
      z: z ?? this.z,
      kind: kind,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      brushType: brushType ?? this.brushType,
      brushId: brushId ?? this.brushId,
      pressures: pressures ?? this.pressures,
      spacing: spacing ?? this.spacing,
      textureSeed: textureSeed ?? this.textureSeed,
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
      layerBounds: layerBounds ?? this.layerBounds,
    );
  }
}

/// Resolves one end of a connector against the element it is attached to.
///
/// The painter, the connector hit test and the selection handles all resolve
/// through this helper so the drawn line, the tappable line and the grabbable
/// handles agree with each other.
Offset _resolveConnectorEnd(
  List<_CanvasElement> elements, {
  required String? elementId,
  required String anchor,
  required Offset fallback,
  Offset? towards,
}) {
  if (elementId == null) return fallback;
  final target = elements.where((e) => e.id == elementId).firstOrNull;
  if (target == null) return fallback;

  final CanvasElement? domainTarget = switch (target.kind) {
    _ElementKind.shape when target.shapeType != null => ShapeElement(
      id: target.id,
      z: target.z,
      shapeType: target.shapeType!,
      center: target.center,
      size: target.size,
      width: (target.data['width'] as num?)?.toDouble() ?? 0.0,
      height: (target.data['height'] as num?)?.toDouble() ?? 0.0,
      color: target.color,
      strokeWidth: target.strokeWidth,
      isFilled: target.isFilled,
      rotation: target.rotation,
    ),
    _ElementKind.stickyNote => StickyNoteElement(
      id: target.id,
      z: target.z,
      center: target.center,
      width: target.width,
      height: target.height,
      color: target.color,
      rotation: target.rotation,
    ),
    _ElementKind.image => ImageElement(
      id: target.id,
      z: target.z,
      center: target.center,
      width: target.width,
      height: target.height,
      rotation: target.rotation,
    ),
    _ElementKind.text => TextElement(
      id: target.id,
      z: target.z,
      center: target.center,
      text: target.text,
      color: target.color,
      width: target.width,
      height: target.height,
      fontSize: target.fontSize,
      fontWeight: target.fontWeight,
      fontFamily: target.fontFamily,
      textAlign: target.textAlign,
      lineHeight: target.lineHeight,
      rotation: target.rotation,
      maxLines: target.maxLines,
    ),
    _ => null,
  };
  if (domainTarget != null) {
    return resolveConnectorAnchorPoint(
      domainTarget,
      anchor,
      fallback,
      towards: towards,
    );
  }
  return target.bounds?.center ?? target.center;
}

class _ConnectorPreviewPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final String lineStyle;
  final Color color;
  final double strokeWidth;
  final Rect? highlight;

  const _ConnectorPreviewPainter({
    required this.start,
    required this.end,
    this.lineStyle = 'straight',
    required this.color,
    required this.strokeWidth,
    this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halo = highlight;
    if (halo != null) {
      final rrect = RRect.fromRectAndRadius(halo, const Radius.circular(10));
      canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.drawPath(
      connectorPath(start, end, lineStyle),
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ConnectorPreviewPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.lineStyle != lineStyle ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.highlight != highlight;
}

class _CanvasPainter extends CustomPainter {
  final List<_CanvasElement> elements;
  final Map<String, ui.Image> decodedImages;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final double currentBrushOpacity;
  final String currentBrushType;
  final String? selectedShapeId;
  final double viewportScale;
  final Offset viewportOffset;
  final bool showEraserPreview;
  final bool isDrawingShape;
  final Offset? shapeDrawStart;
  final Offset? shapeDrawCurrent;
  final CanvasShapeType? pendingShapeType;
  final Color accentColor;
  final String? arrowConnectStartElementId;
  final List<RemoteEraserCursor> remoteEraserCursors;
  final List<double> currentStrokePressures;
  final List<double> currentStrokeTilts;
  final CanvasBoardSettings boardSettings;
  final Map<String, CanvasLayerPaintEffect> layerEffects;
  final Set<String> highlightElementIds;
  final Rect? areaSelectionRect;

  const _CanvasPainter({
    required this.elements,
    this.layerEffects = const {},
    this.decodedImages = const {},
    required this.currentPoints,
    this.currentStrokePressures = const [],
    this.currentStrokeTilts = const [],
    required this.currentColor,
    required this.currentStrokeWidth,
    this.currentBrushOpacity = 1,
    required this.currentBrushType,
    required this.selectedShapeId,
    required this.viewportScale,
    required this.viewportOffset,
    required this.showEraserPreview,
    this.isDrawingShape = false,
    this.shapeDrawStart,
    this.shapeDrawCurrent,
    this.pendingShapeType,
    required this.accentColor,
    this.arrowConnectStartElementId,
    this.remoteEraserCursors = const [],
    this.boardSettings = const CanvasBoardSettings(),
    this.highlightElementIds = const {},
    this.areaSelectionRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBoardBackground(canvas, size);
    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);
    canvas.scale(viewportScale);

    for (final element in elements) {
      // Strokes already carry their alpha in the paint; every other kind is
      // composited through a layer so images and fills fade uniformly.
      final elementOpacity = element.opacity.clamp(0.0, 1.0);
      final layerEffect = layerEffects[element.id];
      final layerOpacity = layerEffect?.opacity ?? 1.0;
      final blendMode = layerEffect == null
          ? BlendMode.srcOver
          : canvasBlendModeForName(layerEffect.blendMode);
      final effectiveOpacity = (elementOpacity * layerOpacity).clamp(0.0, 1.0);
      final bounds = element.layerBounds ?? element.bounds;
      final useLayer =
          bounds != null &&
          ((element.kind != _ElementKind.stroke && effectiveOpacity < 1) ||
              (layerEffect != null &&
                  (layerOpacity < 1 || blendMode != BlendMode.srcOver)));
      if (useLayer) {
        canvas.saveLayer(
          bounds.inflate(8),
          Paint()
            ..blendMode = blendMode
            ..color = Colors.white.withValues(alpha: effectiveOpacity),
        );
      }
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
            brushId: element.brushId,
            pressures: element.pressures,
            tilts: element.tilts,
            spacing: element.spacing,
            textureSeed: element.textureSeed,
            fillColor: element.data['fillColor'] == null
                ? null
                : Color((element.data['fillColor'] as num).toInt()),
          );
          break;
        case _ElementKind.shape:
          _paintShape(canvas, element);
          break;
        case _ElementKind.text:
          _paintText(canvas, element);
          break;
        case _ElementKind.image:
          _paintImage(canvas, element, decodedImages[element.id]);
          break;
        case _ElementKind.stickyNote:
          _paintStickyNote(canvas, element);
          break;
        case _ElementKind.connector:
          _paintConnector(canvas, element);
          break;
        case _ElementKind.frame:
          _paintFrame(canvas, element);
          break;
      }
      if (useLayer) canvas.restore();
    }

    if (highlightElementIds.isNotEmpty) {
      for (final element in elements) {
        if (!highlightElementIds.contains(element.id)) continue;
        final b = element.layerBounds ?? element.bounds;
        if (b != null) _paintHistoryHighlight(canvas, b);
      }
    }

    final marquee = areaSelectionRect;
    if (marquee != null) {
      _paintAreaSelection(canvas, marquee);
    }

    if (arrowConnectStartElementId != null) {
      final startElem = elements
          .where((e) => e.id == arrowConnectStartElementId)
          .firstOrNull;
      if (startElem != null) {
        final ringPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;
        final radius =
            (startElem.kind == _ElementKind.shape
                    ? startElem.size
                    : (startElem.kind == _ElementKind.stickyNote ||
                          startElem.kind == _ElementKind.image)
                    ? math.max(startElem.width, startElem.height)
                    : 80.0) /
                2 +
            10;
        canvas.drawCircle(startElem.center, radius, glowPaint);
        canvas.drawCircle(startElem.center, radius, ringPaint);
      }
    }

    // Collaborators' erasers are shown as ghost rings, never as ink.
    for (final cursor in remoteEraserCursors) {
      _paintRemoteEraserCursor(canvas, cursor.position, cursor.radius);
    }

    if (currentPoints.isNotEmpty) {
      if (currentBrushType != 'eraser') {
        if (currentPoints.length > 1) {
          _paintStroke(
            canvas,
            currentPoints,
            currentColor,
            currentStrokeWidth,
            opacity: currentBrushOpacity,
            brushType: currentBrushType,
            brushId: currentBrushType,
            pressures: currentStrokePressures,
            tilts: currentStrokeTilts,
          );
        }
      } else if (showEraserPreview) {
        // Eraser convention: state.strokeWidth is the eraser *diameter*;
        // the erase hit-test uses radius = strokeWidth / 2. The preview
        // circle must show the same radius, not the full width.
        _paintEraserPreview(canvas, currentPoints.last, currentStrokeWidth / 2);
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
    String? brushId,
    List<double> pressures = const [],
    List<double> tilts = const [],
    double? spacing,
    int textureSeed = 0,
    Color? fillColor,
  }) {
    if (fillColor != null && points.length >= 3) {
      final fillOpacity = (opacity * fillColor.a).clamp(0.0, 1.0);
      canvas.drawPath(
        Path()..addPolygon(points, true),
        Paint()
          ..color = fillColor.withValues(alpha: fillOpacity)
          ..style = PaintingStyle.fill,
      );
    }
    paintCanvasStroke(
      canvas: canvas,
      points: points,
      pressures: pressures,
      tilts: tilts,
      color: color,
      strokeWidth: width,
      strokeOpacity: opacity,
      brushType: brushType,
      brushId: brushId,
      spacing: spacing,
      textureSeed: textureSeed,
    );
  }

  void _paintStrokeHighlight(Canvas canvas, _CanvasElement element) {
    final points = element.points;
    if (points.length < 2) return;
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..strokeWidth = element.strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _paintHistoryHighlight(Canvas canvas, Rect bounds) {
    final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(10));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _paintAreaSelection(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintShape(Canvas canvas, _CanvasElement element) {
    final data = element.data;
    final shapeType = element.shapeType ?? CanvasShapeType.square;
    final labelColorValue = data['labelColor'];
    final shape = ShapeElement(
      id: element.id,
      z: element.z,
      shapeType: shapeType,
      center: element.center,
      size: element.size,
      width: (data['width'] as num?)?.toDouble() ?? 0.0,
      height: (data['height'] as num?)?.toDouble() ?? 0.0,
      color: element.color,
      strokeWidth: element.strokeWidth,
      strokeOpacity: (data['strokeOpacity'] as num?)?.toDouble() ?? 1.0,
      dashPattern: (data['dashPattern'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      isFilled: element.isFilled,
      fillMode:
          (data['fillMode'] as String?) ??
          (element.isFilled ? 'solid' : 'none'),
      fillColor: data['fillColor'] == null
          ? null
          : Color((data['fillColor'] as num).toInt()),
      gradientStart: data['gradientStart'] == null
          ? null
          : Color((data['gradientStart'] as num).toInt()),
      gradientEnd: data['gradientEnd'] == null
          ? null
          : Color((data['gradientEnd'] as num).toInt()),
      gradientAngle: (data['gradientAngle'] as num?)?.toDouble() ?? 0,
      rotation: element.rotation,
      borderRadius: (data['borderRadius'] as num?)?.toDouble() ?? 0.0,
      opacity: (data['opacity'] as num?)?.toDouble() ?? 1.0,
      label: (data['label'] as String?) ?? '',
      labelColor: labelColorValue == null
          ? null
          : Color((labelColorValue as num).toInt()),
      labelFontSize: (data['labelFontSize'] as num?)?.toDouble() ?? 14.0,
      labelFontWeight: (data['labelFontWeight'] as num?)?.toInt() ?? 600,
      labelTextAlign: (data['labelTextAlign'] as String?) ?? 'center',
      startArrowhead: (data['startArrowhead'] as bool?) ?? false,
      endArrowhead:
          (data['endArrowhead'] as bool?) ??
          (shapeType == CanvasShapeType.arrow),
    );
    paintShapeElement(canvas, shape);
  }

  /// Draws the eraser cursor preview. [radius] is the actual erase radius
  /// (state.strokeWidth / 2 — strokeWidth is the eraser diameter).
  void _paintEraserPreview(Canvas canvas, Offset position, double radius) {
    final previewPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(position, radius, previewPaint);
  }

  void _paintRemoteEraserCursor(Canvas canvas, Offset position, double radius) {
    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, ringPaint);
  }

  void _paintShapeDrawPreview(Canvas canvas, Offset start, Offset current) {
    final shapeType = pendingShapeType;
    if (shapeType == null) return;

    final dx = (current.dx - start.dx).abs();
    final dy = (current.dy - start.dy).abs();
    if (dx < 2 && dy < 2) return;

    final geom = ShapeGeometry.compute(
      shapeType: shapeType,
      start: start,
      current: current,
    );

    // Live shape preview with chosen color and stroke width
    final previewElement = _CanvasElement.shape(
      id: '__preview_shape__',
      shapeType: shapeType,
      center: geom.center,
      size: geom.size,
      color: currentColor,
      strokeWidth: currentStrokeWidth > 0 ? currentStrokeWidth : 3.0,
      isFilled: false,
      data: {
        'rotation': geom.rotation,
        'borderRadius': 0.0,
        'width': geom.width,
        'height': geom.height,
        'endArrowhead': shapeType == CanvasShapeType.arrow,
      },
    );
    _paintShape(canvas, previewElement);
  }

  /// Board paper, optional pattern and page bounds, all in screen space
  /// behind the transformed element layer.
  void _paintBoardBackground(Canvas canvas, Size size) {
    final settings = boardSettings;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = settings.backgroundColor,
    );

    final spacing = settings.patternSpacing * viewportScale;
    if (settings.backgroundPattern != CanvasBackgroundPattern.none &&
        spacing >= 4) {
      final isDark = settings.backgroundColor.computeLuminance() < 0.4;
      final color = (isDark ? Colors.white : Colors.black).withValues(
        alpha: 0.1,
      );
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1;
      final startX = viewportOffset.dx % spacing;
      final startY = viewportOffset.dy % spacing;
      switch (settings.backgroundPattern) {
        case CanvasBackgroundPattern.none:
          break;
        case CanvasBackgroundPattern.dots:
          final dots = Paint()..color = color;
          for (var x = startX; x <= size.width; x += spacing) {
            for (var y = startY; y <= size.height; y += spacing) {
              canvas.drawCircle(Offset(x, y), 1.3, dots);
            }
          }
          break;
        case CanvasBackgroundPattern.grid:
          for (var x = startX; x <= size.width; x += spacing) {
            canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
          }
          for (var y = startY; y <= size.height; y += spacing) {
            canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
          }
          break;
        case CanvasBackgroundPattern.lines:
          for (var y = startY; y <= size.height; y += spacing) {
            canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
          }
          break;
        case CanvasBackgroundPattern.isometric:
          final step = spacing * 1.5;
          for (var x = startX - size.height; x <= size.width; x += step) {
            canvas.drawLine(
              Offset(x, 0),
              Offset(x + size.height, size.height),
              paint,
            );
            canvas.drawLine(
              Offset(x, size.height),
              Offset(x + size.height, 0),
              paint,
            );
          }
          break;
      }
    }

    if (!settings.pageBoundsEnabled) return;
    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);
    canvas.scale(viewportScale);
    final page = Rect.fromCenter(
      center: Offset.zero,
      width: settings.pageWidth,
      height: settings.pageHeight,
    );
    canvas.drawRect(page, Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawRect(
      page,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _paintFrame(Canvas canvas, _CanvasElement element) {
    // Shared with PNG/PDF export so the frame cannot drift between views.
    paintFrameElement(
      canvas,
      FrameElement(
        id: element.id,
        z: element.z,
        center: element.center,
        width: element.width,
        height: element.height,
        title: element.text,
        color: element.color,
        cornerRadius: element.strokeWidth,
      ),
    );
  }

  void _paintText(Canvas canvas, _CanvasElement element) {
    if (element.text.isEmpty) return;
    final maxWidth = element.width > 0
        ? element.width
        : CanvasTextLayout.defaultMaxWidth;
    final layout = CanvasTextLayout.layout(
      text: element.text,
      fontSize: element.fontSize,
      fontWeight: element.fontWeight,
      fontFamily: element.fontFamily,
      textAlign: element.textAlign,
      lineHeight: element.lineHeight,
      maxWidth: maxWidth,
      maxLines: element.maxLines,
      color: element.color,
    );
    final boxWidth = element.width > 0 ? element.width : layout.size.width;
    final boxHeight = element.height > 0 ? element.height : layout.size.height;
    final box = Rect.fromLTWH(
      element.center.dx,
      element.center.dy,
      boxWidth,
      boxHeight,
    );

    canvas.save();
    if (element.rotation != 0) {
      canvas.translate(box.center.dx, box.center.dy);
      canvas.rotate(element.rotation);
      canvas.translate(-box.center.dx, -box.center.dy);
    }
    final background = element.textBackgroundColor;
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.inflate(4), const Radius.circular(3)),
        Paint()..color = background,
      );
    }
    layout.painter.paint(canvas, box.topLeft);
    canvas.restore();
  }

  void _paintImage(
    Canvas canvas,
    _CanvasElement element,
    ui.Image? decodedImage,
  ) {
    final parsed = CanvasElement.fromMap(element.id, element.data);
    final base = parsed is ImageElement
        ? parsed
        : ImageElement(id: element.id, z: 0, center: element.center);
    // Transform previews update the mapped element ahead of its payload.
    final image = base.copyWith(
      center: element.center,
      width: element.width > 0 ? element.width : 160.0,
      height: element.height > 0 ? element.height : 160.0,
      rotation: element.rotation,
    );
    paintImageElement(
      canvas,
      image,
      decodedImage,
      placeholder: (canvas, rect, rrect) {
        canvas.drawRRect(
          rrect,
          Paint()..color = Colors.grey.withValues(alpha: 0.18),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = Colors.grey.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: '[Image: ${rect.width.toInt()}x${rect.height.toInt()}]',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      },
    );
  }

  Offset _resolveAnchor(
    String? elementId,
    String anchor,
    Offset fallback, {
    Offset? towards,
  }) {
    return _resolveConnectorEnd(
      elements,
      elementId: elementId,
      anchor: anchor,
      fallback: fallback,
      towards: towards,
    );
  }

  void _paintStickyNote(Canvas canvas, _CanvasElement element) {
    final note =
        CanvasElement.fromMap(element.id, element.data) as StickyNoteElement;
    paintStickyNoteElement(
      canvas,
      note.copyWith(
        center: element.center,
        width: element.width,
        height: element.height,
        color: element.color,
        text: element.text,
        rotation: element.rotation,
      ),
    );
  }

  void _paintConnector(Canvas canvas, _CanvasElement element) {
    final startRaw = _resolveAnchor(
      element.startElementId,
      'center',
      element.startPoint,
    );
    final endRaw = _resolveAnchor(
      element.endElementId,
      'center',
      element.endPoint,
    );
    final start = _resolveAnchor(
      element.startElementId,
      element.startAnchor,
      element.startPoint,
      towards: endRaw,
    );
    final end = _resolveAnchor(
      element.endElementId,
      element.endAnchor,
      element.endPoint,
      towards: startRaw,
    );

    final model = CanvasElement.fromMap(element.id, element.data);
    final connector = model is ConnectorElement ? model : null;
    final cornerRadius = connector?.cornerRadius ?? 0;

    paintConnectorElement(
      canvas,
      start,
      end,
      lineStyle: element.lineStyle,
      color: element.color,
      strokeWidth: element.strokeWidth,
      cornerRadius: cornerRadius,
      dashPattern: connector?.dashPattern,
      startArrowhead: connector?.startArrowhead ?? false,
      endArrowhead: element.hasArrowhead,
      label: connector?.label ?? '',
      labelColor: connector?.labelColor,
      labelFontSize: connector?.labelFontSize ?? 14,
    );

    if (selectedShapeId == element.id) {
      final highlightPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.5)
        ..strokeWidth = element.strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        connectorPath(
          start,
          end,
          element.lineStyle,
          cornerRadius: cornerRadius,
        ),
        highlightPaint,
      );
    }
  }

  static bool _erasureCursorsEqual(
    List<RemoteEraserCursor> a,
    List<RemoteEraserCursor> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _doubleListEquals(List<double> a, List<double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _elementsEqual(List<_CanvasElement> a, List<_CanvasElement> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].z != b[i].z ||
          a[i].kind != b[i].kind ||
          a[i].color != b[i].color ||
          a[i].strokeWidth != b[i].strokeWidth ||
          a[i].center != b[i].center ||
          a[i].points.length != b[i].points.length ||
          a[i].rotation != b[i].rotation ||
          a[i].text != b[i].text) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        !_elementsEqual(oldDelegate.elements, elements) ||
        oldDelegate.decodedImages != decodedImages ||
        oldDelegate.currentPoints != currentPoints ||
        !_doubleListEquals(
          oldDelegate.currentStrokePressures,
          currentStrokePressures,
        ) ||
        !_doubleListEquals(
          oldDelegate.currentStrokeTilts,
          currentStrokeTilts,
        ) ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth ||
        oldDelegate.currentBrushOpacity != currentBrushOpacity ||
        oldDelegate.currentBrushType != currentBrushType ||
        oldDelegate.selectedShapeId != selectedShapeId ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.viewportOffset != viewportOffset ||
        oldDelegate.isDrawingShape != isDrawingShape ||
        oldDelegate.shapeDrawStart != shapeDrawStart ||
        oldDelegate.shapeDrawCurrent != shapeDrawCurrent ||
        oldDelegate.pendingShapeType != pendingShapeType ||
        oldDelegate.arrowConnectStartElementId != arrowConnectStartElementId ||
        !_erasureCursorsEqual(
          oldDelegate.remoteEraserCursors,
          remoteEraserCursors,
        ) ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.boardSettings != boardSettings ||
        !mapEquals(oldDelegate.layerEffects, layerEffects) ||
        !setEquals(oldDelegate.highlightElementIds, highlightElementIds) ||
        oldDelegate.areaSelectionRect != areaSelectionRect;
  }
}
