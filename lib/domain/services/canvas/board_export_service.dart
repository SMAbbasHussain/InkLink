import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart'
    show
        Color,
        Offset,
        Radius,
        Rect,
        RRect,
        TextDirection,
        TextPainter,
        TextSpan,
        TextStyle;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/canvas/canvas_element.dart';
import 'canvas_geometry.dart';
import '../../models/canvas/canvas_shape_type.dart';

enum BoardExportFormat { png, pdf, svg }

/// What happened when the exported file was handed to the platform share
/// sheet. "unavailable" means the sheet could not be opened at all, so callers
/// must not claim that it was.
enum BoardShareOutcome { shared, dismissed, unavailable }

abstract class BoardExportService {
  Future<File> exportBoard({
    required String boardTitle,
    required List<CanvasElement> elements,
    required BoardExportFormat format,
  });

  Future<BoardShareOutcome> shareBoardFile({
    required File file,
    required String boardTitle,
    Rect? sharePositionOrigin,
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
    final randomPart = math.Random()
        .nextInt(1000000)
        .toString()
        .padLeft(6, '0');
    final uniqueSuffix = '${timestamp}_$randomPart';
    final exportDir = await _resolveExportDirectory();

    switch (format) {
      case BoardExportFormat.png:
        final pngBytes = await renderToPng(elements);
        final file = File(
          '${exportDir.path}/${sanitizedTitle}_$uniqueSuffix.png',
        );
        await file.writeAsBytes(pngBytes, flush: true);
        return file;

      case BoardExportFormat.pdf:
        final pdfBytes = await renderToPdf(boardTitle, elements);
        final file = File(
          '${exportDir.path}/${sanitizedTitle}_$uniqueSuffix.pdf',
        );
        await file.writeAsBytes(pdfBytes, flush: true);
        return file;

      case BoardExportFormat.svg:
        final svgString = renderToSvg(boardTitle, elements);
        final file = File(
          '${exportDir.path}/${sanitizedTitle}_$uniqueSuffix.svg',
        );
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
          final targetDir = (await inkLinkDir.exists())
              ? inkLinkDir
              : publicDownloadDir;
          final testFile = File(
            '${targetDir.path}/.test_${DateTime.now().millisecondsSinceEpoch}',
          );
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
          final targetDir = (await inkLinkDir.exists())
              ? inkLinkDir
              : publicDocsDir;
          final testFile = File(
            '${targetDir.path}/.test_${DateTime.now().millisecondsSinceEpoch}',
          );
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
  Future<BoardShareOutcome> shareBoardFile({
    required File file,
    required String boardTitle,
    Rect? sharePositionOrigin,
  }) async {
    if (!await file.exists()) {
      throw Exception('Exported file not found: ${file.path}');
    }
    final ShareResult result;
    try {
      result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: _mimeTypeForFile(file))],
          subject: boardTitle,
          title: boardTitle,
          // Required to anchor the popover on iPad/Mac; without it the native
          // share sheet silently fails to present.
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } on UnimplementedError {
      // Platform has no file sharing at all (e.g. older Windows builds).
      return BoardShareOutcome.unavailable;
    } on MissingPluginException {
      return BoardShareOutcome.unavailable;
    } on PlatformException {
      return BoardShareOutcome.unavailable;
    }
    return switch (result.status) {
      ShareResultStatus.success => BoardShareOutcome.shared,
      ShareResultStatus.dismissed => BoardShareOutcome.dismissed,
      ShareResultStatus.unavailable => BoardShareOutcome.unavailable,
    };
  }

  String _mimeTypeForFile(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.pdf')) return 'application/pdf';
    if (path.endsWith('.svg')) return 'image/svg+xml';
    if (path.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
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
          final cleanBase64 = el.imageBase64.trim().replaceAll(
            RegExp(r'\s+'),
            '',
          );
          if (RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64)) {
            final bytes = base64Decode(cleanBase64);
            final codec = await ui.instantiateImageCodec(bytes);
            try {
              decodedImages[el.id] = (await codec.getNextFrame()).image;
            } finally {
              codec.dispose();
            }
          }
        } catch (_) {}
      }
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Enforce maximum dimension and pixel area to prevent OOM on large coordinate spans (Comment 11)
      const double maxDimension = 4096.0;
      const double maxArea = 4096.0 * 4096.0;

      double effectiveScale = scale;
      final rawW = bounds.width * effectiveScale;
      final rawH = bounds.height * effectiveScale;
      if (rawW > maxDimension ||
          rawH > maxDimension ||
          (rawW * rawH) > maxArea) {
        final dimScale = math.min(
          maxDimension / bounds.width,
          maxDimension / bounds.height,
        );
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

      final sorted = orderedElementsForPaint(elements);

      for (final element in sorted) {
        if (element.hidden) continue;
        final opacity = element.opacity.clamp(0.0, 1.0);
        final bounds = elementBounds(element);
        final useLayer =
            opacity < 1 && element is! StrokeElement && bounds != null;
        if (useLayer) {
          canvas.saveLayer(
            bounds.inflate(8),
            ui.Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
          );
        }
        _paintElement(canvas, element, elementMap, decodedImages);
        if (useLayer) canvas.restore();
      }

      final picture = recorder.endRecording();
      final outWidth = math.max(1, (bounds.width * effectiveScale).ceil());
      final outHeight = math.max(1, (bounds.height * effectiveScale).ceil());
      try {
        final image = await picture.toImage(outWidth, outHeight);
        try {
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          return byteData!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      for (final image in decodedImages.values) {
        image.dispose();
      }
    }
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
      case LayerElement _:
        // Layers are organisational and never draw ink.
        break;
    }
  }

  void _paintStroke(ui.Canvas canvas, StrokeElement stroke) {
    paintCanvasStroke(
      canvas: canvas,
      points: stroke.points,
      pressures: stroke.pressures,
      color: stroke.color,
      strokeWidth: stroke.strokeWidth,
      strokeOpacity: stroke.opacity,
      brushType: stroke.brushType,
      brushId: stroke.brushId,
      textureSeed: stroke.textureSeed,
    );
  }

  void _paintShape(ui.Canvas canvas, ShapeElement shape) {
    // Shared with the interactive painter so PNG/PDF match the canvas exactly
    // (free aspect, independent fill/stroke, dashes, arrowheads, label).
    paintShapeElement(canvas, shape);
  }

  void _paintText(ui.Canvas canvas, TextElement text) {
    if (text.text.isEmpty) return;
    // Same layout the canvas uses, so exported text cannot drift in size,
    // alignment or wrapping.
    final layout = CanvasTextLayout.forElement(text);
    final box = textElementRect(text);

    canvas.save();
    if (text.rotation != 0) {
      canvas.translate(box.center.dx, box.center.dy);
      canvas.rotate(text.rotation);
      canvas.translate(-box.center.dx, -box.center.dy);
    }
    final background = text.backgroundColor;
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          box.inflate(text.padding),
          const Radius.circular(3),
        ),
        ui.Paint()..color = background,
      );
    }
    layout.painter.paint(canvas, box.topLeft);
    canvas.restore();
  }

  void _paintStickyNote(ui.Canvas canvas, StickyNoteElement sticky) {
    paintStickyNoteElement(canvas, sticky);
  }

  (Offset, Offset) _resolveConnectorEndpoints(
    ConnectorElement connector,
    Map<String, CanvasElement> elementMap,
  ) => resolveConnectorEndpoints(connector, elementMap);

  void _paintConnector(
    ui.Canvas canvas,
    ConnectorElement connector,
    Map<String, CanvasElement> elementMap,
  ) {
    // Resolve attached anchors so connector connects directly to shape boundaries (Comment 14)
    final (start, end) = _resolveConnectorEndpoints(connector, elementMap);
    paintConnectorElement(
      canvas,
      start,
      end,
      lineStyle: connector.lineStyle,
      color: connector.color,
      strokeWidth: connector.strokeWidth,
      cornerRadius: connector.cornerRadius,
      dashPattern: connector.dashPattern,
      startArrowhead: connector.startArrowhead,
      endArrowhead: connector.endArrowhead,
      label: connector.label,
      labelColor: connector.labelColor,
      labelFontSize: connector.labelFontSize,
    );
  }

  void _paintImage(
    ui.Canvas canvas,
    ImageElement image,
    ui.Image? decodedImage,
  ) {
    paintImageElement(
      canvas,
      image,
      decodedImage,
      placeholder: (canvas, rect, rrect) {
        canvas.drawRRect(rrect, ui.Paint()..color = const Color(0xFFF1F5F9));
        canvas.drawRRect(
          rrect,
          ui.Paint()
            ..color = const Color(0xFF94A3B8)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final textPainter = TextPainter(
          text: const TextSpan(
            text: '🖼 Image',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
        theme: pw.ThemeData.withFont(base: ttfBase, bold: ttfBold),
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
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F1F5F9'),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6),
                      ),
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
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
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

  String renderToSvg(String boardTitle, List<CanvasElement> elements) {
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

    // Shape arrowheads use colored markers; connectors emit explicit polygons.
    final arrowColors = <String>{};
    for (final el in elements) {
      if (el is ShapeElement &&
          el.isLinear &&
          (el.startArrowhead || el.endArrowhead)) {
        arrowColors.add(_colorToHex(el.color));
      }
    }
    buffer.writeln('  <defs>');
    if (elements.any(
      (element) =>
          element is StrokeElement &&
          brushPresetFor(element.brushType).texture == BrushTexture.wash,
    )) {
      buffer.writeln(
        '    <filter id="$watercolorBlurFilterId" x="-20%" y="-20%" width="140%" height="140%">',
      );
      buffer.writeln(
        '      <feGaussianBlur stdDeviation="$watercolorBlurStdDeviation" />',
      );
      buffer.writeln('    </filter>');
    }
    if (arrowColors.isEmpty) {
      buffer.writeln(
        '    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto-start-reverse">',
      );
      buffer.writeln(
        '      <polygon points="0 0, 10 3.5, 0 7" fill="#333333" />',
      );
      buffer.writeln('    </marker>');
    } else {
      final firstColor = arrowColors.first;
      buffer.writeln(
        '    <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto-start-reverse">',
      );
      buffer.writeln(
        '      <polygon points="0 0, 10 3.5, 0 7" fill="$firstColor" />',
      );
      buffer.writeln('    </marker>');
      for (final colorHex in arrowColors) {
        final id = 'arrowhead_${colorHex.replaceAll('#', '')}';
        buffer.writeln(
          '    <marker id="$id" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto-start-reverse">',
        );
        buffer.writeln(
          '      <polygon points="0 0, 10 3.5, 0 7" fill="$colorHex" />',
        );
        buffer.writeln('    </marker>');
      }
    }
    buffer.writeln('  </defs>');

    buffer.writeln('  <!-- Background -->');
    buffer.writeln('  <rect width="100%" height="100%" fill="#ffffff" />');
    buffer.writeln('  <!-- Canvas Elements -->');
    buffer.writeln('  <g transform="translate($offsetX, $offsetY)">');

    final sorted = orderedElementsForPaint(elements);

    for (final element in sorted) {
      if (element.hidden) continue;
      // Stroke serialization already writes its own opacity attribute.
      final opacity = element.opacity.clamp(0.0, 1.0);
      final wrapLayer = opacity < 1 && element is! StrokeElement;
      if (wrapLayer) {
        buffer.writeln('  <g opacity="${opacity.toStringAsFixed(3)}">');
      }
      _serializeSvgElement(buffer, element, elementMap);
      if (wrapLayer) buffer.writeln('  </g>');
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
      case LayerElement _:
        break;
    }
  }

  void _serializeSvgStroke(StringBuffer buffer, StrokeElement stroke) {
    if (stroke.points.isEmpty) return;
    final style = resolveBrushStyle(
      brushType: stroke.brushId.isNotEmpty ? stroke.brushId : stroke.brushType,
      strokeWidth: stroke.strokeWidth,
      strokeOpacity: stroke.opacity,
    );
    final colorHex = _colorToHex(stroke.color);
    final lineCap = style.cap == ui.StrokeCap.square ? 'square' : 'round';
    // SVG has no multiply blend attribute for strokes on every viewer, so the
    // resolved opacity above carries most of the effect and this is a
    // best-effort hint.
    final blend = style.blendMode == ui.BlendMode.multiply
        ? ' style="mix-blend-mode:multiply"'
        : '';
    final filter = style.texture == BrushTexture.wash
        ? ' filter="url(#$watercolorBlurFilterId)"'
        : '';

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      buffer.writeln(
        '    <circle cx="${p.dx}" cy="${p.dy}" r="${style.width / 2}" fill="$colorHex" opacity="${style.opacity}"$blend$filter />',
      );
      return;
    }

    final hasVaryingPressure =
        stroke.pressures.isNotEmpty &&
        stroke.pressures.any(
          (pr) => (pr - stroke.pressures.first).abs() > 0.05,
        );

    if (hasVaryingPressure) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        final pr = i < stroke.pressures.length
            ? stroke.pressures[i].clamp(0.05, 1.0)
            : 1.0;
        final segWidth =
            style.width * (style.pressureAffectsSize ? (0.4 + 0.9 * pr) : 1.0);
        buffer.writeln(
          '    <line x1="${p0.dx}" y1="${p0.dy}" x2="${p1.dx}" y2="${p1.dy}" '
          'stroke="$colorHex" stroke-width="${segWidth.toStringAsFixed(2)}" '
          'stroke-linecap="$lineCap" stroke-linejoin="round" opacity="${style.opacity}"$blend$filter />',
        );
      }
      return;
    }

    final pathData = StringBuffer();
    pathData.write('M ${stroke.points.first.dx} ${stroke.points.first.dy}');
    for (int i = 1; i < stroke.points.length; i++) {
      pathData.write(' L ${stroke.points[i].dx} ${stroke.points[i].dy}');
    }

    buffer.writeln(
      '    <path d="$pathData" fill="none" stroke="$colorHex" stroke-width="${style.width}" stroke-linecap="$lineCap" stroke-linejoin="round" opacity="${style.opacity}"$blend$filter />',
    );
  }

  void _serializeSvgShape(StringBuffer buffer, ShapeElement shape) {
    final colorHex = _colorToHex(shape.color);
    final rect = shapeElementRect(shape);
    final cx = shape.center.dx;
    final cy = shape.center.dy;
    final hw = rect.width / 2;
    final hh = rect.height / 2;
    // SVG transform expects degrees; ShapeElement.rotation is radians.
    final deg = shape.rotation * 180 / math.pi;
    final rotAttr = shape.rotation != 0
        ? ' transform="rotate($deg $cx $cy)"'
        : '';
    final fill = (shape.isFilled && !shape.isLinear) ? colorHex : 'none';
    final strokeAttrs = _svgStrokeAttrs(shape, colorHex);

    if (shape.isLinear) {
      final markerId = 'arrowhead_${colorHex.replaceAll('#', '')}';
      final startMarker = shape.startArrowhead
          ? ' marker-start="url(#$markerId)"'
          : '';
      final endMarker = shape.endArrowhead
          ? ' marker-end="url(#$markerId)"'
          : '';
      buffer.writeln(
        '    <line x1="${cx - hw}" y1="$cy" x2="${cx + hw}" y2="$cy"$strokeAttrs$startMarker$endMarker$rotAttr />',
      );
      _serializeSvgShapeLabel(buffer, shape, cx, cy, rotAttr);
      return;
    }

    switch (shape.shapeType) {
      case CanvasShapeType.square:
      case CanvasShapeType.rectangle:
        final x = cx - hw;
        final y = cy - hh;
        final rx = shape.borderRadius;
        buffer.writeln(
          '    <rect x="$x" y="$y" width="${rect.width}" height="${rect.height}" rx="$rx" fill="$fill"$strokeAttrs$rotAttr />',
        );
        break;
      case CanvasShapeType.circle:
      case CanvasShapeType.ellipse:
        if ((rect.width - rect.height).abs() < 0.001) {
          buffer.writeln(
            '    <circle cx="$cx" cy="$cy" r="$hw" fill="$fill"$strokeAttrs$rotAttr />',
          );
        } else {
          buffer.writeln(
            '    <ellipse cx="$cx" cy="$cy" rx="$hw" ry="$hh" fill="$fill"$strokeAttrs$rotAttr />',
          );
        }
        break;
      case CanvasShapeType.triangle:
        final points =
            '$cx,${cy - hh} ${cx - hw},${cy + hh} ${cx + hw},${cy + hh}';
        buffer.writeln(
          '    <polygon points="$points" fill="$fill"$strokeAttrs$rotAttr />',
        );
        break;
      case CanvasShapeType.diamond:
        final points =
            '$cx,${cy - hh} ${cx + hw},$cy $cx,${cy + hh} ${cx - hw},$cy';
        buffer.writeln(
          '    <polygon points="$points" fill="$fill"$strokeAttrs$rotAttr />',
        );
        break;
      case CanvasShapeType.star:
        final points = _getStarPointsString(cx, cy, hw, hh);
        buffer.writeln(
          '    <polygon points="$points" fill="$fill"$strokeAttrs$rotAttr />',
        );
        break;
      case CanvasShapeType.pentagon:
        final points = _getPolygonPointsString(5, cx, cy, hw, hh);
        buffer.writeln(
          '    <polygon points="$points" fill="$fill"$strokeAttrs$rotAttr />',
        );
        break;
      case CanvasShapeType.hexagon:
        final points = _getPolygonPointsString(6, cx, cy, hw, hh);
        buffer.writeln(
          '    <polygon points="$points" fill="$fill"$strokeAttrs$rotAttr />',
        );
        break;
      case CanvasShapeType.semicircle:
        final d = 'M $cx $cy L ${cx - hw} $cy A $hw $hh 0 0 1 ${cx + hw} $cy Z';
        buffer.writeln('    <path d="$d" fill="$fill"$strokeAttrs$rotAttr />');
        break;
      case CanvasShapeType.line:
      case CanvasShapeType.arrow:
        break;
    }
    _serializeSvgShapeLabel(buffer, shape, cx, cy, rotAttr);
  }

  /// Stroke attributes shared by every shape primitive: independent of fill,
  /// honoring stroke opacity and dash pattern so SVG matches the painter.
  String _svgStrokeAttrs(ShapeElement shape, String colorHex) {
    if (shape.strokeWidth <= 0) return ' stroke="none"';
    final opacity = shape.strokeOpacity.clamp(0.0, 1.0);
    final opacityAttr = opacity < 1.0
        ? ' stroke-opacity="${opacity.toStringAsFixed(3)}"'
        : '';
    final dash = shape.dashPattern;
    final dashAttr = (dash != null && dash.length >= 2)
        ? ' stroke-dasharray="${dash.map((d) => d.toStringAsFixed(2)).join(' ')}"'
        : '';
    return ' stroke="$colorHex" stroke-width="${shape.strokeWidth}"$opacityAttr$dashAttr';
  }

  void _serializeSvgShapeLabel(
    StringBuffer buffer,
    ShapeElement shape,
    double cx,
    double cy,
    String rotAttr,
  ) {
    if (shape.label.isEmpty) return;
    final labelHex = _colorToHex(shape.labelColor ?? const Color(0xFF000000));
    final rect = shapeElementRect(shape);
    const padding = 6.0;
    final anchor = switch (shape.labelTextAlign) {
      'left' => 'start',
      'right' => 'end',
      _ => 'middle',
    };
    final x = switch (shape.labelTextAlign) {
      'left' => cx - rect.width / 2 + padding,
      'right' => cx + rect.width / 2 - padding,
      _ => cx,
    };
    buffer.writeln(
      '    <text x="${x.toStringAsFixed(2)}" y="$cy" fill="$labelHex" font-size="${shape.labelFontSize}" font-weight="${shape.labelFontWeight}" text-anchor="$anchor" dominant-baseline="central"$rotAttr>${_escapeXml(shape.label)}</text>',
    );
  }

  String _getStarPointsString(double cx, double cy, double hw, double hh) {
    const points = 5;
    final parts = <String>[];
    for (int i = 0; i < points; i++) {
      final outerAngle = (math.pi / 2) + i * (2 * math.pi / points);
      final innerAngle = outerAngle + (math.pi / points);
      final outerX = cx + math.cos(outerAngle) * hw;
      final outerY = cy - math.sin(outerAngle) * hh;
      final innerX = cx + math.cos(innerAngle) * hw * 0.5;
      final innerY = cy - math.sin(innerAngle) * hh * 0.5;
      parts.add('${outerX.toStringAsFixed(1)},${outerY.toStringAsFixed(1)}');
      parts.add('${innerX.toStringAsFixed(1)},${innerY.toStringAsFixed(1)}');
    }
    return parts.join(' ');
  }

  String _getPolygonPointsString(
    int sides,
    double cx,
    double cy,
    double hw,
    double hh,
  ) {
    final parts = <String>[];
    for (int i = 0; i < sides; i++) {
      final angle = (math.pi / 2) + i * (2 * math.pi / sides);
      final x = cx + math.cos(angle) * hw;
      final y = cy - math.sin(angle) * hh;
      parts.add('${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}');
    }
    return parts.join(' ');
  }

  void _serializeSvgText(StringBuffer buffer, TextElement text) {
    if (text.text.isEmpty) return;
    final colorHex = _colorToHex(text.color);
    final box = textElementRect(text);
    final anchor = switch (text.textAlign) {
      'center' => 'middle',
      'right' => 'end',
      _ => 'start',
    };
    final x = switch (text.textAlign) {
      'center' => box.center.dx,
      'right' => box.right,
      _ => box.left,
    };
    final degrees = text.rotation * 180 / math.pi;
    final rotationAttribute = text.rotation != 0
        ? ' transform="rotate($degrees ${box.center.dx} ${box.center.dy})"'
        : '';

    final background = text.backgroundColor;
    if (background != null) {
      final bgRect = box.inflate(text.padding);
      final bgHex = _colorToHex(background);
      final bgOpacity = background.a < 1.0
          ? ' fill-opacity="${background.a.toStringAsFixed(3)}"'
          : '';
      buffer.writeln(
        '    <rect x="${bgRect.left}" y="${bgRect.top}" width="${bgRect.width}" height="${bgRect.height}" rx="3" fill="$bgHex"$bgOpacity$rotationAttribute />',
      );
    }

    final family = text.fontFamily ?? 'sans-serif';
    final lines = _wrappedTextLines(text, box.width);

    buffer.writeln(
      '    <text x="$x" y="${box.top}" fill="$colorHex" font-size="${text.fontSize}" font-weight="${text.fontWeight}" font-family="$family" text-anchor="$anchor" dominant-baseline="hanging" xml:space="preserve"$rotationAttribute>',
    );
    for (var i = 0; i < lines.length; i++) {
      final dy = i == 0 ? 0.0 : text.fontSize * text.lineHeight;
      buffer.writeln(
        '      <tspan x="$x" dy="$dy">${_escapeXml(lines[i])}</tspan>',
      );
    }
    buffer.writeln('    </text>');
  }

  List<String> _wrappedTextLines(TextElement text, double maxWidth) {
    final sizedText = text.width > 0
        ? text
        : TextElement(
            id: text.id,
            z: text.z,
            hidden: text.hidden,
            locked: text.locked,
            opacity: text.opacity,
            text: text.text,
            center: text.center,
            color: text.color,
            width: maxWidth,
            height: text.height,
            fontSize: text.fontSize,
            fontWeight: text.fontWeight,
            fontFamily: text.fontFamily,
            textAlign: text.textAlign,
            lineHeight: text.lineHeight,
            rotation: text.rotation,
            maxLines: text.maxLines,
            autoSize: text.autoSize,
            backgroundColor: text.backgroundColor,
            padding: text.padding,
          );
    final layout = CanvasTextLayout.forElement(sizedText);
    final metrics = layout.painter.computeLineMetrics();
    if (metrics.isEmpty) {
      return text.text.split('\n');
    }
    final lines = <String>[];
    final farRight = math.max(maxWidth, layout.painter.width) + 10000.0;
    for (final metric in metrics) {
      final y = metric.baseline - metric.ascent * 0.3;
      final start = layout.painter
          .getPositionForOffset(Offset(-10000.0, y))
          .offset
          .clamp(0, text.text.length);
      final end = layout.painter
          .getPositionForOffset(Offset(farRight, y))
          .offset
          .clamp(start, text.text.length);
      lines.add(
        text.text.substring(start, end).replaceFirst(RegExp(r'\r?\n$'), ''),
      );
    }
    return lines;
  }

  void _serializeSvgStickyNote(StringBuffer buffer, StickyNoteElement sticky) {
    final rect = stickyNoteRect(sticky);
    final textRect = stickyNoteTextRect(sticky);
    final (top, bottom, curl) = stickyNotePaperColors(sticky);
    final tape = stickyNoteTapeHeight(sticky);
    final n = _svgNumber;
    final sid =
        'note_${base64UrlEncode(utf8.encode(sticky.id)).replaceAll('=', '')}';
    String box(Rect r) =>
        'x="${n(r.left)}" y="${n(r.top)}" width="${n(r.width)}" height="${n(r.height)}"';
    final rotation = sticky.rotation == 0
        ? ''
        : ' transform="rotate(${sticky.rotation * 180 / math.pi} ${sticky.center.dx} ${sticky.center.dy})"';
    buffer.writeln('    <g$rotation>');
    buffer.writeln(
      '<defs><linearGradient id="${sid}_paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${_colorToHex(top)}" stop-opacity="${top.a}"/><stop offset="1" stop-color="${_colorToHex(bottom)}" stop-opacity="${bottom.a}"/></linearGradient>',
    );
    for (final (name, sigma) in [('ambient', 3), ('shadow', 8), ('curl', 2)]) {
      buffer.writeln(
        '<filter id="${sid}_$name" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="$sigma"/></filter>',
      );
    }
    buffer.writeln(
      '<clipPath id="${sid}_text"><rect ${box(textRect)}/></clipPath></defs>',
    );
    buffer.writeln(
      '<rect ${box(rect.translate(0, 2))} rx="8" fill="#000000" fill-opacity="${15 / 255}" filter="url(#${sid}_ambient)"/>',
    );
    buffer.writeln(
      '<rect ${box(rect.translate(2, 6))} rx="8" fill="#000000" fill-opacity="${31 / 255}" filter="url(#${sid}_shadow)"/>',
    );
    buffer.writeln('<rect ${box(rect)} rx="8" fill="url(#${sid}_paper)"/>');
    final x = rect.left;
    final y = rect.top;
    buffer.writeln(
      '<path d="M ${n(x + 8)} ${n(y)} H ${n(rect.right - 8)} Q ${n(rect.right)} ${n(y)} ${n(rect.right)} ${n(y + 8)} V ${n(y + tape)} H ${n(x)} V ${n(y + 8)} Q ${n(x)} ${n(y)} ${n(x + 8)} ${n(y)} Z" fill="#ffffff" fill-opacity="0.2"/>',
    );
    buffer.writeln(
      '<line x1="${n(x)}" x2="${n(rect.right)}" y1="${n(y + tape)}" y2="${n(y + tape)}" stroke="#000000" stroke-opacity="${10 / 255}"/>',
    );
    final curlPath =
        'M ${n(rect.right - 14)} ${n(rect.bottom)} L ${n(rect.right)} ${n(rect.bottom - 14)} L ${n(rect.right - 14)} ${n(rect.bottom - 14)} Z';
    buffer.writeln(
      '<path d="$curlPath" transform="translate(-1 -1)" fill="#000000" fill-opacity="${20 / 255}" filter="url(#${sid}_curl)"/>',
    );
    buffer.writeln(
      '<path d="$curlPath" fill="${_colorToHex(curl)}" fill-opacity="${curl.a}"/>',
    );
    buffer.writeln(
      '<rect ${box(rect)} rx="8" fill="none" stroke="#000000" stroke-opacity="${18 / 255}"/>',
    );
    if (sticky.text.isNotEmpty) {
      final layout = stickyNoteTextLayout(sticky);
      final metrics = layout.painter.computeLineMetrics();
      buffer.writeln(
        '<text clip-path="url(#${sid}_text)" fill="${_colorToHex(sticky.textColor)}" fill-opacity="${sticky.textColor.a}" font-size="${sticky.fontSize}" font-weight="${sticky.fontWeight}" font-family="sans-serif" xml:space="preserve">',
      );
      for (final metric in metrics) {
        final y = metric.baseline - metric.ascent * 0.3;
        final start = layout.painter
            .getPositionForOffset(Offset(-10000, y))
            .offset
            .clamp(0, sticky.text.length);
        final end = layout.painter
            .getPositionForOffset(Offset(textRect.width + 10000, y))
            .offset
            .clamp(start, sticky.text.length);
        final line = sticky.text
            .substring(start, end)
            .replaceFirst(RegExp(r'\r?\n$'), '');
        buffer.writeln(
          '<tspan x="${n(textRect.left + metric.left)}" y="${n(textRect.top + metric.baseline)}">${_escapeXml(line)}</tspan>',
        );
      }
      buffer.writeln('</text>');
      layout.painter.dispose();
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
    final opacity = _svgOpacityAttr('stroke-opacity', connector.color);
    final d = connectorSvgPathData(
      start,
      end,
      connector.lineStyle,
      cornerRadius: connector.cornerRadius,
    );
    final dash = connector.dashPattern;
    final dashAttr = dash != null && dash.length >= 2
        ? ' stroke-dasharray="${dash.map(_svgNumber).join(' ')}"'
        : '';
    if (connector.strokeWidth > 0) {
      buffer.writeln(
        '    <path d="$d" fill="none" stroke="$colorHex"$opacity stroke-width="${_svgNumber(connector.strokeWidth)}" stroke-linecap="round" stroke-linejoin="round"$dashAttr />',
      );
    }

    final heads = connectorArrowheads(
      start,
      end,
      connector.lineStyle,
      strokeWidth: connector.strokeWidth,
      cornerRadius: connector.cornerRadius,
      startArrowhead: connector.startArrowhead,
      endArrowhead: connector.hasArrowhead,
    );
    final fillOpacity = _svgOpacityAttr('fill-opacity', connector.color);
    for (final head in heads) {
      final points = head
          .map((p) => '${_svgNumber(p.dx)},${_svgNumber(p.dy)}')
          .join(' ');
      buffer.writeln(
        '    <polygon points="$points" fill="$colorHex"$fillOpacity />',
      );
    }

    final labelColor = connector.labelColor ?? connector.color;
    final box = connectorLabelBox(
      start,
      end,
      connector.lineStyle,
      label: connector.label,
      color: labelColor,
      cornerRadius: connector.cornerRadius,
      fontSize: connector.labelFontSize,
    );
    if (box == null) return;
    final labelHex = _colorToHex(labelColor);
    final pill = box.pill;
    buffer.writeln(
      '    <rect x="${_svgNumber(pill.left)}" y="${_svgNumber(pill.top)}" width="${_svgNumber(pill.width)}" height="${_svgNumber(pill.height)}" rx="${_svgNumber(ConnectorLabelBox.cornerRadius)}" fill="${_colorToHex(ConnectorLabelBox.fill)}" stroke="$labelHex" stroke-opacity="${_svgNumber(ConnectorLabelBox.borderAlpha * labelColor.a)}" stroke-width="1" />',
    );
    buffer.writeln(
      '    <text x="${_svgNumber(box.center.dx)}" y="${_svgNumber(box.center.dy)}" fill="$labelHex"${_svgOpacityAttr('fill-opacity', labelColor)} font-size="${_svgNumber(connector.labelFontSize)}" font-weight="600" text-anchor="middle" dominant-baseline="central">${_escapeXml(connector.label)}</text>',
    );
  }

  String _svgOpacityAttr(String name, Color color) =>
      color.a >= 1 ? '' : ' $name="${_svgNumber(color.a)}"';

  String _svgNumber(double v) {
    final rounded = (v * 100).roundToDouble() / 100;
    return rounded == rounded.truncateToDouble()
        ? rounded.toInt().toString()
        : rounded.toString();
  }

  void _serializeSvgImage(StringBuffer buffer, ImageElement image) {
    final rect = imageElementRect(image);
    final n = _svgNumber;
    final cx = n(image.center.dx);
    final cy = n(image.center.dy);
    final radius = image.borderRadius
        .clamp(0.0, math.min(rect.width, rect.height) / 2)
        .toDouble();
    final rectAttrs =
        'x="${n(rect.left)}" y="${n(rect.top)}" width="${n(rect.width)}" height="${n(rect.height)}" rx="${n(radius)}"';
    final rotateAttr = image.rotation == 0
        ? ''
        : ' transform="translate($cx $cy) rotate(${n(image.rotation * 180 / math.pi)}) translate(-$cx -$cy)"';
    final cleanBase64 = image.imageBase64.trim().replaceAll(RegExp(r'\s+'), '');
    final isValidBase64 =
        cleanBase64.isNotEmpty &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64);

    final referenceAttr = image.isReference
        ? ' opacity="${n(ImageElement.referenceOpacity)}"'
        : '';
    buffer.writeln('    <g$rotateAttr$referenceAttr>');
    final sid = base64UrlEncode(utf8.encode(image.id)).replaceAll('=', '');
    final clipId = 'imgclip_$sid';
    buffer.writeln(
      '      <clipPath id="$clipId"><rect $rectAttrs /></clipPath>',
    );
    if (isValidBase64) {
      var filterAttr = '';
      if (image.hasFilters) {
        final filterId = 'imgfx_$sid';
        final m = imageColorMatrix(
          brightness: image.brightness,
          contrast: image.contrast,
          saturation: image.saturation,
        );
        // SVG matrix offsets are in 0–1, Flutter's in 0–255.
        final values = [
          for (var i = 0; i < m.length; i++)
            (i % 5 == 4 ? m[i] / 255 : m[i]).toStringAsFixed(6),
        ].join(' ');
        buffer.writeln(
          '      <filter id="$filterId" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="$values" /></filter>',
        );
        filterAttr = ' filter="url(#$filterId)"';
      }
      final crop = image.crop;
      final fullWidth = rect.width / crop.width;
      final fullHeight = rect.height / crop.height;
      final flipAttr = image.flipped || image.flipV
          ? ' transform="translate($cx $cy) scale(${image.flipped ? -1 : 1} ${image.flipV ? -1 : 1}) translate(-$cx -$cy)"'
          : '';
      final mime = cleanBase64.startsWith('/9j/')
          ? 'image/jpeg'
          : cleanBase64.startsWith('R0lGOD')
          ? 'image/gif'
          : cleanBase64.startsWith('UklGR')
          ? 'image/webp'
          : 'image/png';
      buffer.writeln('      <g clip-path="url(#$clipId)">');
      buffer.writeln(
        '        <image x="${n(rect.left - crop.left * fullWidth)}" y="${n(rect.top - crop.top * fullHeight)}" width="${n(fullWidth)}" height="${n(fullHeight)}" preserveAspectRatio="none"$flipAttr$filterAttr href="data:$mime;base64,$cleanBase64" />',
      );
      buffer.writeln('      </g>');
    } else {
      buffer.writeln(
        '      <rect $rectAttrs fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5" />',
      );
    }
    if (image.borderWidth > 0) {
      final inset = math.min(
        image.borderWidth / 2,
        math.min(rect.width, rect.height) / 2,
      );
      final inner = rect.deflate(inset);
      buffer.writeln(
        '      <rect x="${n(inner.left)}" y="${n(inner.top)}" width="${n(inner.width)}" height="${n(inner.height)}" rx="${n(math.max(0, radius - inset))}" fill="none" stroke="${_colorToHex(image.borderColor)}"${_svgOpacityAttr('stroke-opacity', image.borderColor)} stroke-width="${n(image.borderWidth)}" clip-path="url(#$clipId)" />',
      );
    }
    buffer.writeln('    </g>');
  }

  // ──────────────────────────────────────────────
  // Bounding Box Calculation
  // ──────────────────────────────────────────────

  Rect computeElementsBounds(List<CanvasElement> elements) {
    final visible = elements.where((e) => !e.hidden).toList(growable: false);
    if (visible.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1000, 700);
    }

    final elementMap = {for (final e in visible) e.id: e};
    Rect? union;

    for (final element in visible) {
      final Rect? rect;
      if (element is ConnectorElement) {
        final (start, end) = _resolveConnectorEndpoints(element, elementMap);
        final resolved = ConnectorElement(
          id: element.id,
          z: element.z,
          hidden: element.hidden,
          locked: element.locked,
          opacity: element.opacity,
          startElementId: element.startElementId,
          startPoint: start,
          startAnchor: element.startAnchor,
          endElementId: element.endElementId,
          endPoint: end,
          endAnchor: element.endAnchor,
          lineStyle: element.lineStyle,
          color: element.color,
          strokeWidth: element.strokeWidth,
          hasArrowhead: element.hasArrowhead,
          startArrowhead: element.startArrowhead,
          cornerRadius: element.cornerRadius,
          dashPattern: element.dashPattern,
          label: element.label,
          labelColor: element.labelColor,
          labelFontSize: element.labelFontSize,
        );
        rect = elementBounds(resolved, padding: 20.0);
      } else if (element is TextElement) {
        rect = elementBounds(element, padding: element.padding);
      } else if (element is StickyNoteElement) {
        rect = elementBounds(element, padding: 10.0);
      } else {
        rect = elementBounds(element);
      }
      if (rect == null) continue;
      union = union == null ? rect : union.expandToInclude(rect);
    }

    if (union == null) {
      return const Rect.fromLTWH(0, 0, 1000, 700);
    }

    const padding = 60.0;
    return union.inflate(padding);
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
