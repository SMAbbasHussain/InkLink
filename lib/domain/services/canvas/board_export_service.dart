import 'dart:async';
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

import '../../../features/canvas/models/canvas_element.dart';
import '../../../features/canvas/view/trays/canvas_shape_type.dart';

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
    final exportDir = await _resolveExportDirectory();

    switch (format) {
      case BoardExportFormat.png:
        final pngBytes = await renderToPng(elements);
        final file = File('${exportDir.path}/${sanitizedTitle}_$timestamp.png');
        await file.writeAsBytes(pngBytes, flush: true);
        return file;

      case BoardExportFormat.pdf:
        final pdfBytes = await renderToPdf(boardTitle, elements);
        final file = File('${exportDir.path}/${sanitizedTitle}_$timestamp.pdf');
        await file.writeAsBytes(pdfBytes, flush: true);
        return file;

      case BoardExportFormat.svg:
        final svgString = renderToSvg(boardTitle, elements);
        final file = File('${exportDir.path}/${sanitizedTitle}_$timestamp.svg');
        await file.writeAsString(svgString, flush: true);
        return file;
    }
  }

  Future<Directory> _resolveExportDirectory() async {
    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        if (await publicDownloadDir.exists()) {
          final inkLinkDir = Directory('${publicDownloadDir.path}/InkLink');
          if (!await inkLinkDir.exists()) {
            await inkLinkDir.create(recursive: true);
          }
          final testFile = File('${inkLinkDir.path}/.test_${DateTime.now().millisecondsSinceEpoch}');
          await testFile.writeAsString('test');
          await testFile.delete();
          return inkLinkDir;
        }
      } catch (_) {}
    }

    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && await downloads.exists()) {
        return downloads;
      }
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null && await ext.exists()) {
        final inkLinkDir = Directory('${ext.path}/InkLink');
        if (!await inkLinkDir.exists()) {
          await inkLinkDir.create(recursive: true);
        }
        return inkLinkDir;
      }
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      final inkLinkDir = Directory('${docs.path}/InkLink');
      if (!await inkLinkDir.exists()) {
        await inkLinkDir.create(recursive: true);
      }
      return inkLinkDir;
    } catch (_) {}

    return await getTemporaryDirectory();
  }

  @override
  Future<void> shareBoardFile({
    required File file,
    required String boardTitle,
  }) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exported board: $boardTitle from InkLink',
      subject: 'InkLink Board Export: $boardTitle',
    );
  }

  // ──────────────────────────────────────────────
  // PNG Render Pipeline
  // ──────────────────────────────────────────────

  Future<Uint8List> renderToPng(List<CanvasElement> elements) async {
    final bounds = computeElementsBounds(elements);
    const double scale = 2.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, bounds.width * scale, bounds.height * scale),
    );

    // Scale up for high-resolution retina output
    canvas.scale(scale);
    // Translate origin to top-left of elements bounding box
    canvas.translate(-bounds.left, -bounds.top);

    // Background canvas rect
    final bgPaint = ui.Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(bounds, bgPaint);

    final sorted = List<CanvasElement>.from(elements)
      ..sort((a, b) => a.z.compareTo(b.z));

    for (final element in sorted) {
      _paintElement(canvas, element);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      math.max(1, (bounds.width * scale).ceil()),
      math.max(1, (bounds.height * scale).ceil()),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _paintElement(ui.Canvas canvas, CanvasElement element) {
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
        _paintConnector(canvas, connector);
        break;
      case ImageElement image:
        _paintImagePlaceholder(canvas, image);
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

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        ui.Paint()
          ..color = stroke.color.withOpacity(stroke.opacity.clamp(0.0, 1.0))
          ..style = ui.PaintingStyle.fill,
      );
      return;
    }

    final path = ui.Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
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
      canvas.rotate(shape.rotation * math.pi / 180);
    }

    final half = shape.size / 2;
    final rect = Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size);

    switch (shape.shapeType) {
      case CanvasShapeType.square:
        canvas.drawRect(rect, paint);
        break;
      case CanvasShapeType.rectangle:
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
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size * 0.7),
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
        final path = _createStarPath(half);
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.pentagon:
        final path = ui.Path();
        for (int i = 0; i < 5; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 5);
          final point = Offset(
            math.cos(angle) * half,
            -math.sin(angle) * half,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.hexagon:
        final path = ui.Path();
        for (int i = 0; i < 6; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 6);
          final point = Offset(
            math.cos(angle) * half,
            -math.sin(angle) * half,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
      case CanvasShapeType.semicircle:
        final arcRect = Rect.fromCenter(center: Offset.zero, width: shape.size, height: shape.size);
        canvas.drawArc(arcRect, math.pi, math.pi, true, paint);
        break;
      case CanvasShapeType.line:
        canvas.drawLine(Offset(-half, 0), Offset(half, 0), paint);
        break;
      case CanvasShapeType.arrow:
        _paintArrow(canvas, Offset(-half, 0), Offset(half, 0), paint);
        break;
    }
    canvas.restore();
  }

  void _paintArrow(ui.Canvas canvas, Offset start, Offset end, ui.Paint paint) {
    // Shaft line
    canvas.drawLine(start, end, paint);
    // Arrowhead
    const arrowSize = 14.0;
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

    final arrowPath = ui.Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    final fillPaint = ui.Paint()
      ..color = paint.color
      ..style = ui.PaintingStyle.fill;
    canvas.drawPath(arrowPath, fillPaint);
  }

  ui.Path _createStarPath(double radius) {
    final path = ui.Path();
    const int points = 5;
    final double innerRadius = radius * 0.45;
    double angle = -math.pi / 2;
    const double step = math.pi / points;

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

  void _paintText(ui.Canvas canvas, TextElement text) {
    if (text.text.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.text,
        style: TextStyle(
          color: text.color,
          fontSize: 18,
          fontWeight: FontWeight.normal,
        ),
      ),
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
      canvas.rotate(sticky.rotation * math.pi / 180);
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

    // Note card
    final notePaint = ui.Paint()..color = sticky.color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      notePaint,
    );

    // Border
    final borderPaint = ui.Paint()
      ..color = const Color(0x30000000)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Note text
    if (sticky.text.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: sticky.text,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 8,
      )..layout(maxWidth: sticky.width - 20);

      textPainter.paint(
        canvas,
        Offset(-sticky.width / 2 + 10, -sticky.height / 2 + 12),
      );
    }
    canvas.restore();
  }

  void _paintConnector(ui.Canvas canvas, ConnectorElement connector) {
    final paint = ui.Paint()
      ..color = connector.color
      ..strokeWidth = connector.strokeWidth
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;

    final start = connector.startPoint;
    final end = connector.endPoint;

    if (connector.lineStyle == 'step') {
      final midX = (start.dx + end.dx) / 2;
      final path = ui.Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(midX, start.dy)
        ..lineTo(midX, end.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    } else if (connector.lineStyle == 'bezier') {
      final midX = (start.dx + end.dx) / 2;
      final path = ui.Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
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
    final pageImageBytes = await renderPdfPageImage(boardTitle, elements);
    final imageProvider = pw.MemoryImage(pageImageBytes);

    final pdf = pw.Document(
      title: _sanitizeToAscii(boardTitle),
      author: 'InkLink',
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Image(
                imageProvider,
                fit: pw.BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> renderPdfPageImage(
    String boardTitle,
    List<CanvasElement> elements,
  ) async {
    const double pageWidth = 1600.0;
    const double pageHeight = 1131.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, pageWidth, pageHeight),
    );

    // Page background
    final bgPaint = ui.Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(const Rect.fromLTWH(0, 0, pageWidth, pageHeight), bgPaint);

    // Header: Board Title
    final displayTitle = boardTitle.trim().isEmpty ? 'Board' : boardTitle.trim();
    final titlePainter = TextPainter(
      text: TextSpan(
        text: displayTitle,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 950);
    titlePainter.paint(canvas, const Offset(48, 32));

    // Header: Subtitle
    final subtitlePainter = TextPainter(
      text: const TextSpan(
        text: 'InkLink Collaborative Whiteboard',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subtitlePainter.paint(canvas, const Offset(48, 70));

    // Header: Export Date Badge
    final exportDate = DateTime.now().toLocal().toString().split('.').first;
    final datePainter = TextPainter(
      text: TextSpan(
        text: 'Exported: $exportDate',
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    datePainter.paint(canvas, Offset(pageWidth - 48 - datePainter.width, 42));

    // Header divider line
    final dividerPaint = ui.Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      const Offset(48, 102),
      const Offset(pageWidth - 48, 102),
      dividerPaint,
    );

    // Content container area
    const contentLeft = 48.0;
    const contentTop = 118.0;
    const contentWidth = pageWidth - (contentLeft * 2);
    const contentHeight = pageHeight - contentTop - 64.0;
    final contentRect = const Rect.fromLTWH(
      contentLeft,
      contentTop,
      contentWidth,
      contentHeight,
    );

    // Background card for canvas elements
    final cardBgPaint = ui.Paint()..color = const Color(0xFFFAFAFA);
    final cardBorderPaint = ui.Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(contentRect, const Radius.circular(8)),
      cardBgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(contentRect, const Radius.circular(8)),
      cardBorderPaint,
    );

    final bounds = computeElementsBounds(elements);
    final scaleX = (contentWidth - 40) / bounds.width;
    final scaleY = (contentHeight - 40) / bounds.height;
    final fitScale = math.min(scaleX, scaleY).clamp(0.01, 3.0);
    final fittedWidth = bounds.width * fitScale;
    final fittedHeight = bounds.height * fitScale;
    final elemOffsetX = contentLeft + (contentWidth - fittedWidth) / 2;
    final elemOffsetY = contentTop + (contentHeight - fittedHeight) / 2;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(contentRect, const Radius.circular(8)),
    );
    canvas.translate(elemOffsetX, elemOffsetY);
    canvas.scale(fitScale, fitScale);
    canvas.translate(-bounds.left, -bounds.top);

    final sorted = List<CanvasElement>.from(elements)
      ..sort((a, b) => a.z.compareTo(b.z));
    for (final element in sorted) {
      _paintElement(canvas, element);
    }
    canvas.restore();

    // Footer divider line
    canvas.drawLine(
      const Offset(48, pageHeight - 50),
      const Offset(pageWidth - 48, pageHeight - 50),
      dividerPaint,
    );

    // Footer Text Left
    final footerLeft = TextPainter(
      text: const TextSpan(
        text: 'Exported from InkLink • Layout integrity preserved',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerLeft.paint(canvas, const Offset(48, pageHeight - 38));

    // Footer Text Right
    final footerRight = TextPainter(
      text: const TextSpan(
        text: 'Page 1 of 1',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerRight.paint(canvas, Offset(pageWidth - 48 - footerRight.width, pageHeight - 38));

    final picture = recorder.endRecording();
    final image = await picture.toImage(pageWidth.toInt(), pageHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  String _sanitizeToAscii(String input) {
    final buffer = StringBuffer();
    for (final char in input.runes) {
      if (char >= 32 && char <= 126) {
        buffer.writeCharCode(char);
      } else {
        buffer.write('_');
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? 'Board' : result;
  }

  // ──────────────────────────────────────────────
  // SVG Vector Serializer Pipeline
  // ──────────────────────────────────────────────

  String renderToSvg(String boardTitle, List<CanvasElement> elements) {
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
    buffer.writeln('  <defs>');
    buffer.writeln('    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">');
    buffer.writeln('      <polygon points="0 0, 10 3.5, 0 7" fill="#333333" />');
    buffer.writeln('    </marker>');
    buffer.writeln('  </defs>');
    buffer.writeln('  <!-- Background -->');
    buffer.writeln('  <rect width="100%" height="100%" fill="#ffffff" />');
    buffer.writeln('  <!-- Canvas Elements -->');
    buffer.writeln('  <g transform="translate($offsetX, $offsetY)">');

    final sorted = List<CanvasElement>.from(elements)
      ..sort((a, b) => a.z.compareTo(b.z));

    for (final element in sorted) {
      _serializeSvgElement(buffer, element);
    }

    buffer.writeln('  </g>');
    buffer.writeln('</svg>');

    return buffer.toString();
  }

  void _serializeSvgElement(StringBuffer buffer, CanvasElement element) {
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
        _serializeSvgConnector(buffer, connector);
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

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      buffer.writeln(
        '    <circle cx="${p.dx}" cy="${p.dy}" r="${stroke.strokeWidth / 2}" fill="$colorHex" opacity="$opacity" />',
      );
      return;
    }

    final d = StringBuffer('M ${stroke.points.first.dx} ${stroke.points.first.dy}');
    for (int i = 1; i < stroke.points.length; i++) {
      d.write(' L ${stroke.points[i].dx} ${stroke.points[i].dy}');
    }

    buffer.writeln(
      '    <path d="$d" fill="none" stroke="$colorHex" stroke-width="${stroke.strokeWidth}" stroke-linecap="round" stroke-linejoin="round" opacity="$opacity" />',
    );
  }

  void _serializeSvgShape(StringBuffer buffer, ShapeElement shape) {
    final colorHex = _colorToHex(shape.color);
    final fill = shape.isFilled ? colorHex : 'none';
    final stroke = colorHex;
    final strokeWidth = shape.strokeWidth;
    final cx = shape.center.dx;
    final cy = shape.center.dy;
    final half = shape.size / 2;
    final rotAttr = shape.rotation != 0 ? ' transform="rotate(${shape.rotation} $cx $cy)"' : '';

    switch (shape.shapeType) {
      case CanvasShapeType.square:
        final x = cx - half;
        final y = cx - half;
        buffer.writeln(
          '    <rect x="$x" y="$y" width="${shape.size}" height="${shape.size}" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.rectangle:
        final x = cx - half;
        final y = cx - half;
        final rx = shape.borderRadius;
        buffer.writeln(
          '    <rect x="$x" y="$y" width="${shape.size}" height="${shape.size}" rx="$rx" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.circle:
        buffer.writeln(
          '    <circle cx="$cx" cy="$cy" r="$half" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.ellipse:
        final ry = half * 0.7;
        buffer.writeln(
          '    <ellipse cx="$cx" cy="$cy" rx="$half" ry="$ry" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
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
        final points = <String>[];
        for (int i = 0; i < 5; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 5);
          final px = (cx + math.cos(angle) * half).toStringAsFixed(1);
          final py = (cy - math.sin(angle) * half).toStringAsFixed(1);
          points.add('$px,$py');
        }
        buffer.writeln(
          '    <polygon points="${points.join(' ')}" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.hexagon:
        final points = <String>[];
        for (int i = 0; i < 6; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 6);
          final px = (cx + math.cos(angle) * half).toStringAsFixed(1);
          final py = (cy - math.sin(angle) * half).toStringAsFixed(1);
          points.add('$px,$py');
        }
        buffer.writeln(
          '    <polygon points="${points.join(' ')}" fill="$fill" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
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
          '    <line x1="${cx - half}" y1="$cy" x2="${cx + half}" y2="$cy" stroke="$stroke" stroke-width="$strokeWidth"$rotAttr />',
        );
        break;
      case CanvasShapeType.arrow:
        buffer.writeln(
          '    <line x1="${cx - half}" y1="$cy" x2="${cx + half}" y2="$cy" stroke="$stroke" stroke-width="$strokeWidth" marker-end="url(#arrowhead)"$rotAttr />',
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
    final rotAttr = sticky.rotation != 0 ? ' transform="rotate(${sticky.rotation} $cx $cy)"' : '';
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

  void _serializeSvgConnector(StringBuffer buffer, ConnectorElement connector) {
    final colorHex = _colorToHex(connector.color);
    final start = connector.startPoint;
    final end = connector.endPoint;
    final marker = connector.hasArrowhead ? ' marker-end="url(#arrowhead)"' : '';

    if (connector.lineStyle == 'step') {
      final midX = (start.dx + end.dx) / 2;
      final d = 'M ${start.dx} ${start.dy} L $midX ${start.dy} L $midX ${end.dy} L ${end.dx} ${end.dy}';
      buffer.writeln(
        '    <path d="$d" fill="none" stroke="$colorHex" stroke-width="${connector.strokeWidth}" stroke-linecap="round"$marker />',
      );
    } else if (connector.lineStyle == 'bezier') {
      final midX = (start.dx + end.dx) / 2;
      final d = 'M ${start.dx} ${start.dy} C $midX ${start.dy}, $midX ${end.dy}, ${end.dx} ${end.dy}';
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
    if (image.imageBase64.isNotEmpty) {
      buffer.writeln(
        '    <image x="$x" y="$y" width="${image.width}" height="${image.height}" href="data:image/png;base64,${image.imageBase64}" />',
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

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    bool hasAny = false;

    for (final element in elements) {
      switch (element) {
        case StrokeElement stroke:
          for (final p in stroke.points) {
            hasAny = true;
            if (p.dx - stroke.strokeWidth < minX) minX = p.dx - stroke.strokeWidth;
            if (p.dy - stroke.strokeWidth < minY) minY = p.dy - stroke.strokeWidth;
            if (p.dx + stroke.strokeWidth > maxX) maxX = p.dx + stroke.strokeWidth;
            if (p.dy + stroke.strokeWidth > maxY) maxY = p.dy + stroke.strokeWidth;
          }
          break;
        case ShapeElement shape:
          hasAny = true;
          final half = shape.size / 2 + shape.strokeWidth;
          if (shape.center.dx - half < minX) minX = shape.center.dx - half;
          if (shape.center.dy - half < minY) minY = shape.center.dy - half;
          if (shape.center.dx + half > maxX) maxX = shape.center.dx + half;
          if (shape.center.dy + half > maxY) maxY = shape.center.dy + half;
          break;
        case TextElement text:
          hasAny = true;
          const approxW = 120.0;
          const approxH = 36.0;
          if (text.center.dx - approxW / 2 < minX) minX = text.center.dx - approxW / 2;
          if (text.center.dy - approxH / 2 < minY) minY = text.center.dy - approxH / 2;
          if (text.center.dx + approxW / 2 > maxX) maxX = text.center.dx + approxW / 2;
          if (text.center.dy + approxH / 2 > maxY) maxY = text.center.dy + approxH / 2;
          break;
        case StickyNoteElement sticky:
          hasAny = true;
          final halfW = sticky.width / 2 + 10;
          final halfH = sticky.height / 2 + 10;
          if (sticky.center.dx - halfW < minX) minX = sticky.center.dx - halfW;
          if (sticky.center.dy - halfH < minY) minY = sticky.center.dy - halfH;
          if (sticky.center.dx + halfW > maxX) maxX = sticky.center.dx + halfW;
          if (sticky.center.dy + halfH > maxY) maxY = sticky.center.dy + halfH;
          break;
        case ConnectorElement connector:
          hasAny = true;
          final pad = connector.strokeWidth + 20;
          final left = math.min(connector.startPoint.dx, connector.endPoint.dx) - pad;
          final top = math.min(connector.startPoint.dy, connector.endPoint.dy) - pad;
          final right = math.max(connector.startPoint.dx, connector.endPoint.dx) + pad;
          final bottom = math.max(connector.startPoint.dy, connector.endPoint.dy) + pad;
          if (left < minX) minX = left;
          if (top < minY) minY = top;
          if (right > maxX) maxX = right;
          if (bottom > maxY) maxY = bottom;
          break;
        case ImageElement image:
          hasAny = true;
          final halfW = image.width / 2;
          final halfH = image.height / 2;
          if (image.center.dx - halfW < minX) minX = image.center.dx - halfW;
          if (image.center.dy - halfH < minY) minY = image.center.dy - halfH;
          if (image.center.dx + halfW > maxX) maxX = image.center.dx + halfW;
          if (image.center.dy + halfH > maxY) maxY = image.center.dy + halfH;
          break;
      }
    }

    if (!hasAny || minX.isInfinite || minY.isInfinite) {
      return const Rect.fromLTWH(0, 0, 1000, 700);
    }

    final raw = Rect.fromLTRB(minX, minY, maxX, maxY);
    // Add margin around elements
    final bounds = raw.inflate(48.0);
    final w = math.max(300.0, bounds.width);
    final h = math.max(200.0, bounds.height);
    return Rect.fromLTWH(bounds.left, bounds.top, w, h);
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  String _sanitizeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'board' : cleaned;
  }

  String _colorToHex(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
