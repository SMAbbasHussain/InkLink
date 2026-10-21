import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show
        Color,
        FontWeight,
        Offset,
        Radius,
        Rect,
        RRect,
        TextDirection,
        TextPainter,
        TextSpan,
        TextStyle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/canvas/canvas_element.dart';
import '../../models/canvas/canvas_shape_type.dart';

enum BoardExportFormat { png, pdf, svg }

abstract class BoardExportService {
  Future<File> exportBoard({
    required String boardTitle,
    required List<CanvasElement> elements,
    required BoardExportFormat format,
  });

  Future<void> shareBoardFile({
    required File file,
    required String boardTitle,
  });
}

class BoardExportServiceImpl implements BoardExportService {
  const BoardExportServiceImpl();

  @override
  Future<File> exportBoard({
    required String boardTitle,
    required List<CanvasElement> elements,
    required BoardExportFormat format,
  }) async {
    final sanitizedTitle = _sanitizeFileName(boardTitle);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = math.Random().nextInt(1000000).toString().padLeft(6, '0');
    final uniqueSuffix = '${timestamp}_$randomPart';
    final exportDir = await _resolveExportDirectory();

    switch (format) {
      case BoardExportFormat.png:
        final pngBytes = await renderToPng(elements);
        final file = File('${exportDir.path}/${sanitizedTitle}_$uniqueSuffix.png');
        await file.writeAsBytes(pngBytes, flush: true);
        return file;

      case BoardExportFormat.pdf:
        final pdfBytes = await renderToPdf(boardTitle, elements);
        final file = File('${exportDir.path}/${sanitizedTitle}_$uniqueSuffix.pdf');
        await file.writeAsBytes(pdfBytes, flush: true);
        return file;

      case BoardExportFormat.svg:
        final svgString = renderToSvg(boardTitle, elements);
        final file = File('${exportDir.path}/${sanitizedTitle}_$uniqueSuffix.svg');
        await file.writeAsString(svgString, flush: true);
        return file;
    }
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      // 1. Try public Android Download directory
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        if (await publicDownloadDir.exists()) {
          final inkLinkDir = Directory('${publicDownloadDir.path}/InkLink');
          if (!await inkLinkDir.exists()) {
            try {
              await inkLinkDir.create(recursive: true);
            } catch (_) {}
          }
          final targetDir = (await inkLinkDir.exists()) ? inkLinkDir : publicDownloadDir;
          final testFile = File('${targetDir.path}/.test_${DateTime.now().millisecondsSinceEpoch}');
          await testFile.writeAsString('test');
          await testFile.delete();
          return targetDir;
        }
      } catch (_) {}

      // 2. Try public Android Documents directory
      try {
        final publicDocsDir = Directory('/storage/emulated/0/Documents');
        if (await publicDocsDir.exists()) {
          final inkLinkDir = Directory('${publicDocsDir.path}/InkLink');
          if (!await inkLinkDir.exists()) {
            try {
              await inkLinkDir.create(recursive: true);
            } catch (_) {}
          }
          final targetDir = (await inkLinkDir.exists()) ? inkLinkDir : publicDocsDir;
          final testFile = File('${targetDir.path}/.test_${DateTime.now().millisecondsSinceEpoch}');
          await testFile.writeAsString('test');
          await testFile.delete();
          return targetDir;
        }
      } catch (_) {}

      // 3. Fallback to external storage directory
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final inkLinkDir = Directory('${extDir.path}/InkLink');
          if (!await inkLinkDir.exists()) {
            await inkLinkDir.create(recursive: true);
          }
          return inkLinkDir;
        }
      } catch (_) {}
    }

    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final inkLinkDir = Directory('${docsDir.path}/InkLink');
        if (!await inkLinkDir.exists()) {
          await inkLinkDir.create(recursive: true);
        }
        return inkLinkDir;
      } catch (_) {}
    }

    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final inkLinkDir = Directory('${downloadsDir.path}/InkLink');
        if (!await inkLinkDir.exists()) {
          await inkLinkDir.create(recursive: true);
        }
        return inkLinkDir;
      }
    } catch (_) {}

    final appDocDir = await getApplicationDocumentsDirectory();
    final inkLinkDir = Directory('${appDocDir.path}/InkLink');
    if (!await inkLinkDir.exists()) {
      await inkLinkDir.create(recursive: true);
    }
    return inkLinkDir;
  }

  @override
  Future<void> shareBoardFile({
    required File file,
    required String boardTitle,
  }) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      text: 'Exported board "$boardTitle" from InkLink',
      subject: boardTitle,
    );
  }

  String _sanitizeFileName(String title) {
    var sanitized = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    if (sanitized.isEmpty) {
      sanitized = 'board';
    }
    if (sanitized.length > 50) {
      sanitized = sanitized.substring(0, 50);
    }
    return sanitized;
  }

  // ──────────────────────────────────────────────
  // PNG Render Pipeline
  // ──────────────────────────────────────────────

  Future<Uint8List> renderToPng(
    List<CanvasElement> elements, {
    double scale = 2.0,
  }) async {
    final elementMap = {for (final e in elements) e.id: e};
    final bounds = computeElementsBounds(elements);

    // Pre-decode base64 images for raster rendering (Comment 10)
    final decodedImages = <String, ui.Image>{};
    for (final el in elements) {
      if (el is ImageElement && el.imageBase64.isNotEmpty) {
        try {
          final cleanBase64 = el.imageBase64.trim().replaceAll(RegExp(r'\s+'), '');
          if (RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64)) {
            final bytes = base64Decode(cleanBase64);
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            decodedImages[el.id] = frame.image;
          }
        } catch (_) {}
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Enforce maximum dimension and pixel area to prevent OOM on large coordinate spans (Comment 11)
    const double maxDimension = 4096.0;
    const double maxArea = 4096.0 * 4096.0;

    double effectiveScale = scale;
    final rawW = bounds.width * effectiveScale;
    final rawH = bounds.height * effectiveScale;
    if (rawW > maxDimension || rawH > maxDimension || (rawW * rawH) > maxArea) {
      final dimScale = math.min(maxDimension / bounds.width, maxDimension / bounds.height);
      final areaScale = math.sqrt(maxArea / (bounds.width * bounds.height));
      effectiveScale = math.min(dimScale, areaScale);
    }
    effectiveScale = math.max(0.05, effectiveScale);

    // Scale up for high-resolution retina output
    canvas.scale(effectiveScale);
    // Translate origin to top-left of elements bounding box
    canvas.translate(-bounds.left, -bounds.top);

    // Background canvas rect
    final bgPaint = ui.Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(bounds, bgPaint);

    final sorted = List<CanvasElement>.from(elements)
      ..sort((a, b) => a.z.compareTo(b.z));

    for (final element in sorted) {
      _paintElement(canvas, element, elementMap, decodedImages);
    }

    final picture = recorder.endRecording();
    final outWidth = math.max(1, (bounds.width * effectiveScale).ceil());
    final outHeight = math.max(1, (bounds.height * effectiveScale).ceil());
    final image = await picture.toImage(outWidth, outHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _paintElement(
    ui.Canvas canvas,
    CanvasElement element,
    Map<String, CanvasElement> elementMap,
    Map<String, ui.Image> decodedImages,
  ) {
    switch (element) {
      case StrokeElement stroke:
        _paintStroke(canvas, stroke);
        break;
      case ShapeElement shape:
        _paintShape(canvas, shape);
        break;
      case TextElement text:
        _paintText(canvas, text);
        break;
      case StickyNoteElement sticky:
        _paintStickyNote(canvas, sticky);
        break;
      case ConnectorElement connector:
        _paintConnector(canvas, connector, elementMap);
        break;
      case ImageElement image:
        _paintImage(canvas, image, decodedImages[image.id]);
        break;
    }
  }

  void _paintStroke(ui.Canvas canvas, StrokeElement stroke) {
    if (stroke.points.isEmpty) return;
    final paint = ui.Paint()
      ..color = stroke.color.withOpacity(stroke.opacity.clamp(0.0, 1.0))
      ..strokeWidth = stroke.strokeWidth
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;

    if (stroke.brushType == 'highlighter') {
      paint.color = stroke.color.withOpacity(0.4);
      paint.strokeWidth = stroke.strokeWidth * 2.5;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint);
      return;
    }

    final path = ui.Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      final p0 = stroke.points[i - 1];
      final p1 = stroke.points[i];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _paintShape(ui.Canvas canvas, ShapeElement shape) {
    final paint = ui.Paint()
      ..color = shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = shape.isFilled ? ui.PaintingStyle.fill : ui.PaintingStyle.stroke;

    canvas.save();
    canvas.translate(shape.center.dx, shape.center.dy);
    if (shape.rotation != 0) {
      // Rotation in ShapeElement is already in radians (Comment 16)
      canvas.rotate(shape.rotation);
    }

    final half = shape.size / 2;

    switch (shape.shapeType) {
      case CanvasShapeType.square:
        final rect = Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size);
        canvas.drawRect(rect, paint);
        break;
      case CanvasShapeType.rectangle:
        // Use canvas painter dimensions: size * 1.35 by size * 0.8 (Comment 19)
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: shape.size * 1.35,
          height: shape.size * 0.8,
        );
        if (shape.borderRadius > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(shape.borderRadius)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        break;
      case CanvasShapeType.circle:
        canvas.drawCircle(Offset.zero, half, paint);
        break;
      case CanvasShapeType.ellipse:
        // Use canvas painter dimensions: size * 1.3 by size * 0.85 (Comment 19)
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: shape.size * 1.3,
            height: shape.size * 0.85,
          ),
          paint,
        );
        break;
      case CanvasShapeType.triangle:
        final path = ui.Path()
          ..moveTo(0, -half)
          ..lineTo(half, half)
          ..lineTo(-half, half)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.diamond:
        final path = ui.Path()
          ..moveTo(0, -half)
          ..lineTo(half, 0)
          ..lineTo(0, half)
          ..lineTo(-half, 0)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.star:
        final path = _getStarPath(half);
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.pentagon:
        final path = _getPolygonPath(5, half);
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.hexagon:
        final path = _getPolygonPath(6, half);
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.semicircle:
        final path = ui.Path()
          ..arcTo(
            Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size),
            0,
            math.pi,
            true,
          )
          ..close();
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.line:
        canvas.drawLine(Offset(-half, 0), Offset(half, 0), paint);
        break;
      case CanvasShapeType.arrow:
        canvas.drawLine(Offset(-half, 0), Offset(half, 0), paint);
        _paintArrowHead(canvas, Offset(-half, 0), Offset(half, 0), shape.color);
        break;
    }

    canvas.restore();
  }

  ui.Path _getStarPath(double radius) {
    const points = 5;
    final innerRadius = radius * 0.45;
    final path = ui.Path();
    double angle = -math.pi / 2;
    const step = math.pi / points;

    for (int i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? radius : innerRadius;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    return path;
  }

  ui.Path _getPolygonPath(int sides, double radius) {
    final path = ui.Path();
    double angle = -math.pi / 2;
    final step = (2 * math.pi) / sides;

    for (int i = 0; i < sides; i++) {
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    return path;
  }

  void _paintText(ui.Canvas canvas, TextElement text) {
    if (text.text.isEmpty) return;
    final textSpan = TextSpan(
      text: text.text,
      style: TextStyle(
        color: text.color,
        fontSize: 18.0,
        fontWeight: FontWeight.w500,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(text.center.dx - textPainter.width / 2, text.center.dy - textPainter.height / 2),
    );
  }

  void _paintStickyNote(ui.Canvas canvas, StickyNoteElement sticky) {
    canvas.save();
    canvas.translate(sticky.center.dx, sticky.center.dy);
    if (sticky.rotation != 0) {
      // Rotation is already in radians (Comment 16)
      canvas.rotate(sticky.rotation);
    }

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: sticky.width,
      height: sticky.height,
    );

    // Subtle drop shadow
    final shadowPaint = ui.Paint()
      ..color = const Color(0x25000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(2, 3), const Radius.circular(8)),
      shadowPaint,
    );

    // Sticky background
    final bgPaint = ui.Paint()..color = sticky.color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bgPaint);

    // Subtle border
    final borderPaint = ui.Paint()
      ..color = const Color(0x1F000000)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // Sticky Note Text
    if (sticky.text.isNotEmpty) {
      final textSpan = TextSpan(
        text: sticky.text,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: math.max(1, (sticky.height / 20).floor()),
        ellipsis: '...',
      )..layout(maxWidth: math.max(10.0, sticky.width - 24.0));

      textPainter.paint(
        canvas,
        Offset(-sticky.width / 2 + 12.0, -sticky.height / 2 + 12.0),
      );
    }

    canvas.restore();
  }

  (Offset, Offset) _resolveConnectorEndpoints(
    ConnectorElement connector,
    Map<String, CanvasElement> elementMap,
  ) {
    final startRaw = _resolveAnchor(
      elementMap[connector.startElementId],
      'center',
      connector.startPoint,
    );
    final endRaw = _resolveAnchor(
      elementMap[connector.endElementId],
      'center',
      connector.endPoint,
    );
    final start = _resolveAnchor(
      elementMap[connector.startElementId],
      connector.startAnchor,
      connector.startPoint,
      towards: endRaw,
    );
    final end = _resolveAnchor(
      elementMap[connector.endElementId],
      connector.endAnchor,
      connector.endPoint,
      towards: startRaw,
    );
    return (start, end);
  }

  Offset _resolveAnchor(
    CanvasElement? target,
    String anchor,
    Offset fallback, {
    Offset? towards,
  }) {
    if (target == null) return fallback;

    final Rect targetBounds;
    if (target is ShapeElement) {
      final w = target.shapeType == CanvasShapeType.rectangle
          ? target.size * 1.35
          : (target.shapeType == CanvasShapeType.ellipse ? target.size * 1.3 : target.size);
      final h = target.shapeType == CanvasShapeType.rectangle
          ? target.size * 0.8
          : (target.shapeType == CanvasShapeType.ellipse ? target.size * 0.85 : target.size);
      targetBounds = Rect.fromCenter(center: target.center, width: w, height: h);
    } else if (target is StickyNoteElement) {
      targetBounds = Rect.fromCenter(
        center: target.center,
        width: target.width > 0 ? target.width : 150,
        height: target.height > 0 ? target.height : 150,
      );
    } else if (target is ImageElement) {
      targetBounds = Rect.fromCenter(
        center: target.center,
        width: target.width > 0 ? target.width : 150,
        height: target.height > 0 ? target.height : 150,
      );
    } else {
      return fallback;
    }

    String effectiveAnchor = anchor;
    if (effectiveAnchor == 'auto' && towards != null) {
      final dx = towards.dx - targetBounds.center.dx;
      final dy = towards.dy - targetBounds.center.dy;
      if (dx.abs() > dy.abs()) {
        effectiveAnchor = dx > 0 ? 'right' : 'left';
      } else {
        effectiveAnchor = dy > 0 ? 'bottom' : 'top';
      }
    }

    switch (effectiveAnchor) {
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

  void _paintConnector(
    ui.Canvas canvas,
    ConnectorElement connector,
    Map<String, CanvasElement> elementMap,
  ) {
    // Resolve attached anchors so connector connects directly to shape boundaries (Comment 14)
    final (start, end) = _resolveConnectorEndpoints(connector, elementMap);

    final paint = ui.Paint()
      ..color = connector.color
      ..strokeWidth = connector.strokeWidth
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;

    final isStep = connector.lineStyle == 'step' || connector.lineStyle == 'orthogonal';
    final isCurved = connector.lineStyle == 'bezier' || connector.lineStyle == 'curved';

    if (isStep) {
      final midX = (start.dx + end.dx) / 2;
      final path = ui.Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(midX, start.dy)
        ..lineTo(midX, end.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    } else if (isCurved) {
      final dx = (end.dx - start.dx).abs();
      final dy = (end.dy - start.dy).abs();
      final ctrlOffset = math.max(dx, dy) * 0.45;
      final cp1 = Offset(start.dx + (end.dx > start.dx ? ctrlOffset : -ctrlOffset), start.dy);
      final cp2 = Offset(end.dx - (end.dx > start.dx ? ctrlOffset : -ctrlOffset), end.dy);
      final path = ui.Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(start, end, paint);
    }

    if (connector.hasArrowhead) {
      _paintArrowHead(canvas, start, end, connector.color);
    }
  }

  void _paintArrowHead(ui.Canvas canvas, Offset start, Offset end, Color color) {
    const arrowSize = 12.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    const arrowAngle = 25 * math.pi / 180;

    final p1 = Offset(
      end.dx - arrowSize * math.cos(angle - arrowAngle),
      end.dy - arrowSize * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      end.dx - arrowSize * math.cos(angle + arrowAngle),
      end.dy - arrowSize * math.sin(angle + arrowAngle),
    );

    final path = ui.Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    final fillPaint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  void _paintImage(
    ui.Canvas canvas,
    ImageElement image,
    ui.Image? decodedImage,
  ) {
    if (decodedImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
      final dst = Rect.fromCenter(
        center: image.center,
        width: image.width,
        height: image.height,
      );
      canvas.drawImageRect(decodedImage, src, dst, ui.Paint());
    } else {
      _paintImagePlaceholder(canvas, image);
    }
  }

  void _paintImagePlaceholder(ui.Canvas canvas, ImageElement image) {
    final rect = Rect.fromCenter(
      center: image.center,
      width: image.width,
      height: image.height,
    );
    final bgPaint = ui.Paint()..color = const Color(0xFFF1F5F9);
    final borderPaint = ui.Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🖼 Image',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(rect.center.dx - textPainter.width / 2, rect.center.dy - textPainter.height / 2),
    );
  }

  // ──────────────────────────────────────────────
  // PDF Render Pipeline
  // ──────────────────────────────────────────────

  Future<Uint8List> renderToPdf(
    String boardTitle,
    List<CanvasElement> elements,
  ) async {
    final pdf = pw.Document(
      title: boardTitle,
      author: 'InkLink',
      creator: 'InkLink Collaborative Whiteboard',
    );

    // Rasterize canvas image to embed into PDF
    final pngBytes = await renderToPng(elements, scale: 2.0);
    final pdfImage = pw.MemoryImage(pngBytes);

    final creationDate = DateTime.now();
    final formattedDate =
        '${creationDate.year}-${creationDate.month.toString().padLeft(2, '0')}-${creationDate.day.toString().padLeft(2, '0')}';

    final ttfBase = pw.Font.helvetica();
    final ttfBold = pw.Font.helveticaBold();

    final safeTitle = _sanitizePdfString(boardTitle);
    final safeBrand = _sanitizePdfString('InkLink Whiteboard');
    final safeDate = _sanitizePdfString('Exported: $formattedDate');
    final safeElementCount = _sanitizePdfString('${elements.length} elements');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: ttfBase,
          bold: ttfBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        safeTitle,
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 22,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        safeDate,
                        style: pw.TextStyle(
                          font: ttfBase,
                          fontSize: 10,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F1F5F9'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      safeBrand,
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 10,
                        color: PdfColor.fromHex('#475569'),
                      ),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 12),

              // Canvas Content Image
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(
                    pdfImage,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    safeElementCount,
                    style: pw.TextStyle(
                      font: ttfBase,
                      fontSize: 9,
                      color: PdfColor.fromHex('#94A3B8'),
                    ),
                  ),
                  pw.Text(
                    _sanitizePdfString('Page 1 of 1'),
                    style: pw.TextStyle(
                      font: ttfBase,
                      fontSize: 9,
                      color: PdfColor.fromHex('#94A3B8'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String _sanitizePdfString(String input) {
    final buffer = StringBuffer();
    for (final char in input.runes) {
      if (char <= 0x00FF && char != 0x007F) {
        buffer.writeCharCode(char);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }

  // ──────────────────────────────────────────────
  // SVG Vector Pipeline
  // ──────────────────────────────────────────────

  String renderToSvg(
    String boardTitle,
    List<CanvasElement> elements,
  ) {
    final elementMap = {for (final e in elements) e.id: e};
    final bounds = computeElementsBounds(elements);
    final width = bounds.width.ceil();
    final height = bounds.height.ceil();
    final offsetX = -bounds.left;
    final offsetY = -bounds.top;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" width="$width" height="$height">',
    );

    // Dynamically generate colored arrowhead markers for each arrow/connector color (Comment 20)
    final arrowColors = <String>{};
    for (final el in elements) {
      if (el is ConnectorElement && el.hasArrowhead) {
        arrowColors.add(_colorToHex(el.color));
      } else if (el is ShapeElement && el.shapeType == CanvasShapeType.arrow) {
        arrowColors.add(_colorToHex(el.color));
      }
    }
    buffer.writeln('  <defs>');
    if (arrowColors.isEmpty) {
      buffer.writeln('    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">');
      buffer.writeln('      <polygon points="0 0, 10 3.5, 0 7" fill="#333333" />');
      buffer.writeln('    </marker>');
    } else {
      final firstColor = arrowColors.first;
      buffer.writeln('    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">');
      buffer.writeln('      <polygon points="0 0, 10 3.5, 0 7" fill="$firstColor" />');
      buffer.writeln('    </marker>');
      for (final colorHex in arrowColors) {
        final id = 'arrowhead_${colorHex.replaceAll('#', '')}';
        buffer.writeln('    <marker id="$id" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">');
        buffer.writeln('      <polygon points="0 0, 10 3.5, 0 7" fill="$colorHex" />');
        buffer.writeln('    </marker>');
      }
    }
    buffer.writeln('  </defs>');

    buffer.writeln('  <!-- Background -->');
    buffer.writeln('  <rect width="100%" height="100%" fill="#ffffff" />');
    buffer.writeln('  <!-- Canvas Elements -->');
    buffer.writeln('  <g transform="translate($offsetX, $offsetY)">');

    final sorted = List<CanvasElement>.from(elements)
      ..sort((a, b) => a.z.compareTo(b.z));

    for (final element in sorted) {
      _serializeSvgElement(buffer, element, elementMap);
    }

    buffer.writeln('  </g>');
    buffer.writeln('</svg>');

    return buffer.toString();
  }

  void _serializeSvgElement(
    StringBuffer buffer,
    CanvasElement element,
    Map<String, CanvasElement> elementMap,
  ) {
    switch (element) {
      case StrokeElement stroke:
        _serializeSvgStroke(buffer, stroke);
        break;
      case ShapeElement shape:
        _serializeSvgShape(buffer, shape);
        break;
      case TextElement text:
        _serializeSvgText(buffer, text);
        break;
      case StickyNoteElement sticky:
        _serializeSvgStickyNote(buffer, sticky);
        break;
      case ConnectorElement connector:
        _serializeSvgConnector(buffer, connector, elementMap);
        break;
      case ImageElement image:
        _serializeSvgImage(buffer, image);
        break;
    }
  }

  void _serializeSvgStroke(StringBuffer buffer, StrokeElement stroke) {
    if (stroke.points.isEmpty) return;
    final colorHex = _colorToHex(stroke.color);
    final opacity = stroke.opacity.clamp(0.0, 1.0);
    final strokeWidth = stroke.brushType == 'highlighter' ? stroke.strokeWidth * 2.5 : stroke.strokeWidth;
    final strokeOpacity = stroke.brushType == 'highlighter' ? 0.4 : opacity;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      buffer.writeln(
        '    <circle cx="${p.dx}" cy="${p.dy}" r="${strokeWidth / 2}" fill="$colorHex" opacity="$strokeOpacity" />',
      );
      return;
    }

    final pathData = StringBuffer();
    pathData.write('M ${stroke.points.first.dx} ${stroke.points.first.dy}');
    for (int i = 1; i < stroke.points.length; i++) {
      pathData.write(' L ${stroke.points[i].dx} ${stroke.points[i].dy}');
    }

    buffer.writeln(
      '    <path d="$pathData" fill="none" stroke="$colorHex" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round" opacity="$strokeOpacity" />',
    );
  }

  void _serializeSvgShape(StringBuffer buffer, ShapeElement shape) {
    final colorHex = _colorToHex(shape.color);
    final fill = shape.isFilled ? colorHex : 'none';
    // Omit stroke for filled shapes unless unfilled (Comment 21)
    final stroke = shape.isFilled ? 'none' : colorHex;
    final strokeWidth = shape.isFilled ? 0 : shape.strokeWidth;
    final cx = shape.center.dx;
    final cy = shape.center.dy;
    final half = shape.size / 2;
    // SVG transform expects degrees! Convert radians to degrees (Comment 16)
    final deg = shape.rotation * 180 / math.pi;
    final rotAttr = shape.rotation != 0 ? ' transform="rotate($deg $cx $cy)"' : '';

    switch (shape.shapeType) {
      case CanvasShapeType.square:
        final x = cx - half;
        final y = cy - half; // Fix Comment 18: use cy
        buffer.writeln(
          '    <rect x="$x" y="$y" width="${shape.size}" height="${shape.size}" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.rectangle:
        final rectW = shape.size * 1.35; // Fix Comment 19: proper dimensions
        final rectH = shape.size * 0.8;
        final x = cx - rectW / 2;
        final y = cy - rectH / 2; // Fix Comment 18: use cy
        final rx = shape.borderRadius;
        buffer.writeln(
          '    <rect x="$x" y="$y" width="$rectW" height="$rectH" rx="$rx" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.circle:
        buffer.writeln(
          '    <circle cx="$cx" cy="$cy" r="$half" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.ellipse:
        final rx = (shape.size * 1.3) / 2; // Fix Comment 19: proper dimensions
        final ry = (shape.size * 0.85) / 2;
        buffer.writeln(
          '    <ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.triangle:
        final p1 = '$cx,${cy - half}';
        final p2 = '${cx + half},${cy + half}';
        final p3 = '${cx - half},${cy + half}';
        buffer.writeln(
          '    <polygon points="$p1 $p2 $p3" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.diamond:
        final p1 = '$cx,${cy - half}';
        final p2 = '${cx + half},$cy';
        final p3 = '$cx,${cy + half}';
        final p4 = '${cx - half},$cy';
        buffer.writeln(
          '    <polygon points="$p1 $p2 $p3 $p4" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.star:
        final pointsStr = _getStarPointsString(cx, cy, half);
        buffer.writeln(
          '    <polygon points="$pointsStr" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.pentagon:
        final pointsStr = _getPolygonPointsString(5, cx, cy, half);
        buffer.writeln(
          '    <polygon points="$pointsStr" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.hexagon:
        final pointsStr = _getPolygonPointsString(6, cx, cy, half);
        buffer.writeln(
          '    <polygon points="$pointsStr" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.semicircle:
        final d = 'M ${cx - half} $cy A $half $half 0 0 1 ${cx + half} $cy Z';
        buffer.writeln(
          '    <path d="$d" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.line:
        buffer.writeln(
          '    <line x1="${cx - half}" y1="$cy" x2="${cx + half}" y2="$cy" stroke="$colorHex" stroke-width="${shape.strokeWidth}"$rotAttr />',
        );
        break;
      case CanvasShapeType.arrow:
        final markerId = 'arrowhead_${colorHex.replaceAll('#', '')}';
        buffer.writeln(
          '    <line x1="${cx - half}" y1="$cy" x2="${cx + half}" y2="$cy" stroke="$colorHex" stroke-width="${shape.strokeWidth}" marker-end="url(#$markerId)"$rotAttr />',
        );
        break;
    }
  }

  String _getStarPointsString(double cx, double cy, double radius) {
    const points = 5;
    final innerRadius = radius * 0.45;
    double angle = -math.pi / 2;
    const step = math.pi / points;
    final parts = <String>[];

    for (int i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? radius : innerRadius;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      parts.add('${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');
      angle += step;
    }
    return parts.join(' ');
  }

  String _getPolygonPointsString(int sides, double cx, double cy, double radius) {
    double angle = -math.pi / 2;
    final step = (2 * math.pi) / sides;
    final parts = <String>[];

    for (int i = 0; i < sides; i++) {
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      parts.add('${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');
      angle += step;
    }
    return parts.join(' ');
  }

  void _serializeSvgText(StringBuffer buffer, TextElement text) {
    if (text.text.isEmpty) return;
    final colorHex = _colorToHex(text.color);
    final escaped = _escapeXml(text.text);
    buffer.writeln(
      '    <text x="${text.center.dx}" y="${text.center.dy}" fill="$colorHex" font-size="18" font-family="sans-serif" text-anchor="middle" dominant-baseline="middle">$escaped</text>',
    );
  }

  void _serializeSvgStickyNote(StringBuffer buffer, StickyNoteElement sticky) {
    final colorHex = _colorToHex(sticky.color);
    final cx = sticky.center.dx;
    final cy = sticky.center.dy;
    final x = cx - sticky.width / 2;
    final y = cy - sticky.height / 2;
    final deg = sticky.rotation * 180 / math.pi; // Convert radians to degrees (Comment 16)
    final rotAttr = sticky.rotation != 0 ? ' transform="rotate($deg $cx $cy)"' : '';
    final escaped = _escapeXml(sticky.text);

    buffer.writeln('    <g$rotAttr>');
    buffer.writeln(
      '      <rect x="$x" y="$y" width="${sticky.width}" height="${sticky.height}" rx="8" fill="$colorHex" stroke="#D1D5DB" stroke-width="1" />',
    );
    if (escaped.isNotEmpty) {
      buffer.writeln(
        '      <text x="${x + 12}" y="${y + 24}" fill="#1E293B" font-size="13" font-family="sans-serif">$escaped</text>',
      );
    }
    buffer.writeln('    </g>');
  }

  void _serializeSvgConnector(
    StringBuffer buffer,
    ConnectorElement connector,
    Map<String, CanvasElement> elementMap,
  ) {
    final (start, end) = _resolveConnectorEndpoints(connector, elementMap);
    final colorHex = _colorToHex(connector.color);
    final markerId = 'arrowhead_${colorHex.replaceAll('#', '')}';
    final marker = connector.hasArrowhead ? ' marker-end="url(#$markerId)"' : '';

    final isStep = connector.lineStyle == 'step' || connector.lineStyle == 'orthogonal';
    final isCurved = connector.lineStyle == 'bezier' || connector.lineStyle == 'curved';

    if (isStep) {
      final midX = (start.dx + end.dx) / 2;
      final d = 'M ${start.dx} ${start.dy} L $midX ${start.dy} L $midX ${end.dy} L ${end.dx} ${end.dy}';
      buffer.writeln(
        '    <path d="$d" fill="none" stroke="$colorHex" stroke-width="${connector.strokeWidth}" stroke-linecap="round"$marker />',
      );
    } else if (isCurved) {
      final dx = (end.dx - start.dx).abs();
      final dy = (end.dy - start.dy).abs();
      final ctrlOffset = math.max(dx, dy) * 0.45;
      final cp1 = Offset(start.dx + (end.dx > start.dx ? ctrlOffset : -ctrlOffset), start.dy);
      final cp2 = Offset(end.dx - (end.dx > start.dx ? ctrlOffset : -ctrlOffset), end.dy);
      final d = 'M ${start.dx} ${start.dy} C ${cp1.dx} ${cp1.dy}, ${cp2.dx} ${cp2.dy}, ${end.dx} ${end.dy}';
      buffer.writeln(
        '    <path d="$d" fill="none" stroke="$colorHex" stroke-width="${connector.strokeWidth}" stroke-linecap="round"$marker />',
      );
    } else {
      buffer.writeln(
        '    <line x1="${start.dx}" y1="${start.dy}" x2="${end.dx}" y2="${end.dy}" stroke="$colorHex" stroke-width="${connector.strokeWidth}" stroke-linecap="round"$marker />',
      );
    }
  }

  void _serializeSvgImage(StringBuffer buffer, ImageElement image) {
    final x = image.center.dx - image.width / 2;
    final y = image.center.dy - image.height / 2;
    final cleanBase64 = image.imageBase64.trim().replaceAll(RegExp(r'\s+'), '');
    final isValidBase64 = cleanBase64.isNotEmpty &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64);

    if (isValidBase64) {
      buffer.writeln(
        '    <image x="$x" y="$y" width="${image.width}" height="${image.height}" href="data:image/png;base64,$cleanBase64" />',
      );
    } else {
      buffer.writeln(
        '    <rect x="$x" y="$y" width="${image.width}" height="${image.height}" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5" />',
      );
    }
  }

  // ──────────────────────────────────────────────
  // Bounding Box Calculation
  // ──────────────────────────────────────────────

  Rect computeElementsBounds(List<CanvasElement> elements) {
    if (elements.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1000, 700);
    }

    final elementMap = {for (final e in elements) e.id: e};
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    bool hasAny = false;

    void includePoint(double x, double y) {
      hasAny = true;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    void includeRotatedRect(Offset center, double width, double height, double rotation, [double padding = 0]) {
      final halfW = width / 2 + padding;
      final halfH = height / 2 + padding;
      if (rotation == 0) {
        includePoint(center.dx - halfW, center.dy - halfH);
        includePoint(center.dx + halfW, center.dy + halfH);
        return;
      }
      final cos = math.cos(rotation);
      final sin = math.sin(rotation);
      for (final dx in [-halfW, halfW]) {
        for (final dy in [-halfH, halfH]) {
          final rx = center.dx + dx * cos - dy * sin;
          final ry = center.dy + dx * sin + dy * cos;
          includePoint(rx, ry);
        }
      }
    }

    for (final element in elements) {
      switch (element) {
        case StrokeElement stroke:
          for (final p in stroke.points) {
            includePoint(p.dx - stroke.strokeWidth, p.dy - stroke.strokeWidth);
            includePoint(p.dx + stroke.strokeWidth, p.dy + stroke.strokeWidth);
          }
          break;
        case ShapeElement shape:
          final double w;
          final double h;
          switch (shape.shapeType) {
            case CanvasShapeType.rectangle:
              w = shape.size * 1.35;
              h = shape.size * 0.8;
              break;
            case CanvasShapeType.ellipse:
              w = shape.size * 1.3;
              h = shape.size * 0.85;
              break;
            default:
              w = shape.size;
              h = shape.size;
              break;
          }
          includeRotatedRect(shape.center, w, h, shape.rotation, shape.strokeWidth);
          break;
        case TextElement text:
          final tp = TextPainter(
            text: TextSpan(
              text: text.text,
              style: const TextStyle(fontSize: 18.0),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final textW = tp.width + 16.0;
          final textH = tp.height + 16.0;
          includeRotatedRect(text.center, textW, textH, 0.0);
          break;
        case StickyNoteElement sticky:
          includeRotatedRect(sticky.center, sticky.width, sticky.height, sticky.rotation, 10.0);
          break;
        case ConnectorElement connector:
          final (start, end) = _resolveConnectorEndpoints(connector, elementMap);
          final pad = connector.strokeWidth + 20.0;
          includePoint(start.dx - pad, start.dy - pad);
          includePoint(start.dx + pad, start.dy + pad);
          includePoint(end.dx - pad, end.dy - pad);
          includePoint(end.dx + pad, end.dy + pad);
          if (connector.lineStyle == 'step' || connector.lineStyle == 'orthogonal') {
            final midX = (start.dx + end.dx) / 2;
            includePoint(midX - pad, start.dy - pad);
            includePoint(midX + pad, end.dy + pad);
          } else if (connector.lineStyle == 'bezier' || connector.lineStyle == 'curved') {
            final dx = (end.dx - start.dx).abs();
            final dy = (end.dy - start.dy).abs();
            final ctrlOffset = math.max(dx, dy) * 0.45;
            final cp1 = Offset(start.dx + (end.dx > start.dx ? ctrlOffset : -ctrlOffset), start.dy);
            final cp2 = Offset(end.dx - (end.dx > start.dx ? ctrlOffset : -ctrlOffset), end.dy);
            includePoint(cp1.dx - pad, cp1.dy - pad);
            includePoint(cp2.dx + pad, cp2.dy + pad);
          }
          break;
        case ImageElement image:
          includeRotatedRect(image.center, image.width, image.height, 0.0);
          break;
      }
    }

    if (!hasAny || minX.isInfinite || minY.isInfinite) {
      return const Rect.fromLTWH(0, 0, 1000, 700);
    }

    final raw = Rect.fromLTRB(minX, minY, maxX, maxY);
    const padding = 60.0;
    return Rect.fromLTRB(
      raw.left - padding,
      raw.top - padding,
      raw.right + padding,
      raw.bottom + padding,
    );
  }

  String _colorToHex(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
