import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BoardExportServiceImpl exportService;

  setUp(() {
    exportService = const BoardExportServiceImpl();
  });

  group('BoardExportService Bounding Box', () {
    test('returns default bounding box when element list is empty', () {
      final bounds = exportService.computeElementsBounds([]);
      expect(bounds.width, greaterThanOrEqualTo(300.0));
      expect(bounds.height, greaterThanOrEqualTo(200.0));
    });

    test('computes encompassing bounding box for multiple shapes and strokes', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 'stroke-1',
          z: 0,
          color: Colors.black,
          points: [Offset(10, 20), Offset(100, 150)],
        ),
        const ShapeElement(
          id: 'shape-1',
          z: 1,
          shapeType: CanvasShapeType.rectangle,
          center: Offset(300, 400),
          size: 120,
          color: Colors.blue,
        ),
        const StickyNoteElement(
          id: 'sticky-1',
          z: 2,
          center: Offset(500, 600),
          width: 160,
          height: 160,
          text: 'Brainstorm idea',
          color: Color(0xFFFFF9A6),
        ),
      ];

      final bounds = exportService.computeElementsBounds(elements);
      expect(bounds.left, lessThanOrEqualTo(10.0));
      expect(bounds.top, lessThanOrEqualTo(20.0));
      expect(bounds.right, greaterThanOrEqualTo(580.0));
      expect(bounds.bottom, greaterThanOrEqualTo(680.0));
    });
  });

  group('BoardExportService SVG Serialization', () {
    test('serializes SVG with XML header, viewBox, and background rect', () {
      final elements = <CanvasElement>[
        const ShapeElement(
          id: 'rect-1',
          z: 0,
          shapeType: CanvasShapeType.rectangle,
          center: Offset(100, 100),
          size: 80,
          color: Color(0xFF2563EB),
          borderRadius: 8,
        ),
      ];

      final svg = exportService.renderToSvg('Team Roadmap', elements);

      expect(svg, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(svg, contains('<svg xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('<rect width="100%" height="100%" fill="#ffffff" />'));
      expect(svg, contains('<rect'));
      expect(svg, contains('rx="8.0"'));
      expect(svg, contains('</svg>'));
    });

    test('serializes freehand strokes to SVG <path>', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 's-1',
          z: 0,
          color: Color(0xFFEF4444),
          strokeWidth: 4.0,
          opacity: 0.9,
          points: [Offset(20, 20), Offset(50, 80), Offset(120, 140)],
        ),
      ];

      final svg = exportService.renderToSvg('Doodles', elements);

      expect(svg, contains('<path d="M 20.0 20.0 L 50.0 80.0 L 120.0 140.0"'));
      expect(svg, contains('stroke-width="4.0"'));
      expect(svg, contains('fill="none"'));
    });

    test('serializes connectors to SVG <path> with arrowhead marker', () {
      final elements = <CanvasElement>[
        const ConnectorElement(
          id: 'conn-1',
          z: 0,
          startPoint: Offset(50, 50),
          endPoint: Offset(200, 200),
          lineStyle: 'step',
          color: Color(0xFF0F766E),
          strokeWidth: 3.0,
          hasArrowhead: true,
        ),
      ];

      final svg = exportService.renderToSvg('Flowchart', elements);

      expect(svg, contains('marker-end="url(#arrowhead_0f766e)"'));
      expect(svg, contains('<polygon points="0 0, 10 3.5, 0 7" fill="#0f766e" />'));
      expect(svg, contains('stroke="#0f766e"'));
      expect(svg, contains('stroke-width="3.0"'));
    });

    test('serializes sticky notes with card rect and text', () {
      final elements = <CanvasElement>[
        const StickyNoteElement(
          id: 'sticky-note-1',
          z: 0,
          center: Offset(150, 150),
          width: 140,
          height: 140,
          text: 'Design review & planning',
          color: Color(0xFFFFF9A6),
        ),
      ];

      final svg = exportService.renderToSvg('Retro', elements);

      expect(svg, contains('Design review &amp; planning'));
      expect(svg, contains('<rect'));
      expect(svg, contains('rx="8"'));
    });
  });

  group('BoardExportService Raster & PDF Pipelines', () {
    test('renders canvas elements to valid PNG bytes', () async {
      final elements = <CanvasElement>[
        const ShapeElement(
          id: 'c-1',
          z: 0,
          shapeType: CanvasShapeType.circle,
          center: Offset(80, 80),
          size: 60,
          color: Colors.purple,
          isFilled: true,
        ),
        const TextElement(
          id: 't-1',
          z: 1,
          center: Offset(80, 140),
          text: 'Hello InkLink',
          color: Colors.black,
        ),
      ];

      final pngBytes = await exportService.renderToPng(elements);

      expect(pngBytes, isNotEmpty);
      // Verify PNG magic header: 0x89 0x50 0x4E 0x47
      expect(pngBytes[0], 0x89);
      expect(pngBytes[1], 0x50);
      expect(pngBytes[2], 0x4E);
      expect(pngBytes[3], 0x47);
    });

    test('renders canvas elements to valid PDF document bytes', () async {
      final elements = <CanvasElement>[
        const ShapeElement(
          id: 's-1',
          z: 0,
          shapeType: CanvasShapeType.rectangle,
          center: Offset(100, 100),
          size: 80,
          color: Colors.blue,
        ),
      ];

      final pdfBytes = await exportService.renderToPdf('Architecture Draft', elements);

      expect(pdfBytes, isNotEmpty);
      // Verify PDF magic header: %PDF-
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });

    test('renders canvas elements to valid PDF with Unicode and emojis without warning', () async {
      final elements = <CanvasElement>[
        const ShapeElement(
          id: 's-1',
          z: 0,
          shapeType: CanvasShapeType.circle,
          center: Offset(120, 120),
          size: 60,
          color: Colors.deepPurple,
        ),
      ];

      final pdfBytes = await exportService.renderToPdf(
        '🎨 Design Board — 2026’s “Ideas” & Plans …',
        elements,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });
  });
}
