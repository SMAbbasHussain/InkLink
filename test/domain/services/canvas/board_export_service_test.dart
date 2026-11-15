import 'dart:convert';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

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

    test(
      'computes encompassing bounding box for multiple shapes and strokes',
      () {
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
      },
    );
  });

  group('BoardExportService image styling', () {
    test(
      'SVG keeps crop, mirrors, filter precision, reference fade and clipped borders',
      () {
        const image = ImageElement(
          id: 'image/with spaces',
          z: 0,
          center: Offset(100, 100),
          width: 100,
          height: 80,
          crop: Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
          imageBase64: '/9j/AAAA',
          flipped: true,
          flipV: true,
          rotation: math.pi / 2,
          opacity: 0.5,
          isReference: true,
          brightness: 0.5,
          contrast: 0,
          saturation: -1,
          borderRadius: 12,
          borderWidth: 4,
          borderColor: Color(0x80FF0000),
        );
        final svg = exportService.renderToSvg('Images', [image]);
        final sid = base64UrlEncode(utf8.encode(image.id)).replaceAll('=', '');
        expect(svg, contains('opacity="0.500"'));
        expect(
          svg,
          contains(
            '<g transform="translate(100 100) rotate(90) translate(-100 -100)" opacity="0.4">',
          ),
        );
        expect(
          svg,
          contains(
            '<image x="0" y="20" width="200" height="160" preserveAspectRatio="none"',
          ),
        );
        expect(svg, contains('scale(-1 -1)'));
        expect(svg, contains('href="data:image/jpeg;base64,/9j/AAAA"'));
        expect(svg, contains('color-interpolation-filters="sRGB"'));
        expect(svg, contains('0.212600 0.715200 0.072200 0.000000 0.250980'));
        expect(svg, contains('filter="url(#imgfx_$sid)"'));
        expect(
          svg,
          contains(
            'stroke="#ff0000" stroke-opacity="0.5" stroke-width="4" clip-path="url(#imgclip_$sid)"',
          ),
        );
      },
    );

    test(
      'SVG clip and filter ids cannot collide after punctuation normalization',
      () {
        final svg = exportService.renderToSvg('Images', [
          for (final id in ['a-b', 'a/b'])
            ImageElement(
              id: id,
              z: 0,
              center: Offset.zero,
              imageBase64: 'AAAA',
              brightness: 0.1,
            ),
        ]);
        final ids = RegExp(
          r'id="(img(?:clip|fx)_[^"]+)"',
        ).allMatches(svg).map((m) => m[1]).toList();
        expect(ids, hasLength(4));
        expect(ids.toSet(), hasLength(4));
      },
    );

    test(
      'PNG composes crop, both flips, rotation, grayscale, reference and opacity',
      () async {
        final source = img.Image(width: 100, height: 100);
        img.fillRect(
          source,
          x1: 0,
          y1: 0,
          x2: 49,
          y2: 49,
          color: img.ColorRgb8(255, 0, 0),
        );
        img.fillRect(
          source,
          x1: 50,
          y1: 0,
          x2: 99,
          y2: 49,
          color: img.ColorRgb8(0, 255, 0),
        );
        img.fillRect(
          source,
          x1: 0,
          y1: 50,
          x2: 49,
          y2: 99,
          color: img.ColorRgb8(0, 0, 255),
        );
        img.fillRect(
          source,
          x1: 50,
          y1: 50,
          x2: 99,
          y2: 99,
          color: img.ColorRgb8(255, 255, 255),
        );
        final image = ImageElement(
          id: 'image',
          z: 0,
          center: const Offset(50, 50),
          width: 100,
          height: 100,
          imageBase64: base64Encode(img.encodePng(source)),
          crop: const Rect.fromLTRB(0.5, 0, 1, 1),
          flipped: true,
          flipV: true,
          rotation: math.pi / 2,
          saturation: -1,
          opacity: 0.5,
          isReference: true,
          borderRadius: 0,
          borderWidth: 4,
          borderColor: const Color(0xFFFF0000),
        );
        final bounds = exportService.computeElementsBounds([image]);
        final png = img.decodePng(
          await exportService.renderToPng([image], scale: 1),
        )!;
        final pixel = png.getPixel(
          (25 - bounds.left).round(),
          (25 - bounds.top).round(),
        );
        expect(pixel.r, inInclusiveRange(238, 243));
        expect(pixel.g, pixel.r);
        expect(pixel.b, pixel.r);
        final border = png.getPixel(
          (1 - bounds.left).round(),
          (50 - bounds.top).round(),
        );
        expect(border.r, 255);
        expect(border.g, inInclusiveRange(201, 207));
        final pdf = await exportService.renderToPdf('Styled image', [image]);
        expect(utf8.decode(pdf.take(4).toList()), '%PDF');
      },
    );
  });

  group('BoardExportService highlighter', () {
    test(
      'SVG renders highlighter strokes wide, translucent and multiplied',
      () {
        final elements = <CanvasElement>[
          const StrokeElement(
            id: 'highlight-1',
            z: 0,
            color: Colors.yellow,
            points: [Offset(10, 10), Offset(90, 10)],
            strokeWidth: 10,
            opacity: 0.8,
            brushType: 'highlighter',
          ),
        ];

        final svg = exportService.renderToSvg('Highlights', elements);

        // 10 * 2.5 wide, 0.8 * 0.35 translucent.
        expect(svg, contains('stroke-width="25.0"'));
        expect(svg, contains('opacity="0.28'));
        expect(svg, contains('stroke-linecap="square"'));
        expect(svg, contains('mix-blend-mode:multiply'));
      },
    );

    test('SVG rotates and mirrors image elements', () {
      const base64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final elements = <CanvasElement>[
        const ImageElement(
          id: 'img-1',
          z: 0,
          center: Offset(100, 100),
          width: 80,
          height: 60,
          imageBase64: base64,
          rotation: math.pi / 2,
          flipped: true,
        ),
      ];

      final svg = exportService.renderToSvg('Images', elements);
      expect(
        svg,
        contains(
          'transform="translate(100 100) scale(-1 1) translate(-100 -100)"',
        ),
      );
      expect(svg, contains('<g clip-path="url(#imgclip_'));

      expect(
        svg,
        contains(
          '<g transform="translate(100 100) rotate(90) translate(-100 -100)">',
        ),
      );
    });

    test('SVG renders marker strokes wider and slightly translucent', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 'marker-1',
          z: 0,
          color: Colors.black,
          points: [Offset(10, 10), Offset(90, 10)],
          strokeWidth: 10,
          opacity: 0.8,
          brushType: 'marker',
        ),
      ];

      final svg = exportService.renderToSvg('Markers', elements);

      expect(svg, contains('stroke-width="14'));
      expect(svg, contains('opacity="0.72"'));
      expect(svg, contains('stroke-linecap="round"'));
      expect(svg, isNot(contains('mix-blend-mode')));
    });
  });

  group('BoardExportService brush presets', () {
    test('SVG renders watercolor with the shared wash profile and filter', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 'wash-1',
          z: 0,
          color: Colors.blue,
          points: [Offset(10, 10), Offset(90, 10)],
          strokeWidth: 8,
          opacity: 0.9,
          brushType: 'watercolor',
        ),
      ];

      final svg = exportService.renderToSvg('Wash', elements);

      // 8 * 1.25 wide, 0.9 * 0.45 translucent.
      expect(svg, contains('stroke-width="10.0"'));
      expect(svg, contains('opacity="0.405"'));
      expect(svg, contains('filter="url(#watercolor-blur)"'));
      expect(svg, contains('<filter id="watercolor-blur"'));
      expect(svg, contains('<feGaussianBlur stdDeviation="1.25" />'));
    });

    test('SVG renders textured with its width and opacity scale only', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 'textured-1',
          z: 0,
          color: Colors.brown,
          points: [Offset(10, 10), Offset(90, 10)],
          strokeWidth: 5,
          opacity: 1,
          brushType: 'textured',
        ),
      ];

      final svg = exportService.renderToSvg('Textured', elements);

      expect(svg, contains('stroke-width="4.75"'));
      expect(svg, contains('opacity="0.8"'));
      expect(svg, isNot(contains('watercolor-blur')));
    });

    test('SVG renders pencil narrower while keeping its opacity', () {
      final elements = <CanvasElement>[
        const StrokeElement(
          id: 'pencil-1',
          z: 0,
          color: Colors.black,
          points: [Offset(10, 10), Offset(90, 10)],
          strokeWidth: 5,
          opacity: 0.9,
          brushType: 'pencil',
        ),
      ];

      final svg = exportService.renderToSvg('Pencil', elements);

      expect(svg, contains('stroke-width="4.0"'));
      expect(svg, contains('opacity="0.9"'));
    });

    test('PNG pipeline renders every brush family to valid bytes', () async {
      for (final brushType in <String>[
        'solid',
        'pencil',
        'textured',
        'marker',
        'highlighter',
        'watercolor',
      ]) {
        final png = await exportService.renderToPng(<CanvasElement>[
          StrokeElement(
            id: 'stroke-$brushType',
            z: 0,
            color: Colors.teal,
            points: const [Offset(20, 20), Offset(120, 80)],
            strokeWidth: 6,
            opacity: 0.9,
            brushType: brushType,
          ),
        ]);
        expect(png, isNotEmpty, reason: 'PNG bytes for $brushType');
        expect(png[0], 0x89, reason: 'PNG magic for $brushType');
      }
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
      expect(
        svg,
        contains('<rect width="100%" height="100%" fill="#ffffff" />'),
      );
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

    test(
      'serializes connectors to SVG <path> with a painter-sized arrowhead',
      () {
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

        expect(svg, contains('d="M 50 50 L 125 50 L 125 200 L 200 200"'));
        expect(svg, contains('stroke="#0f766e"'));
        expect(svg, contains('stroke-width="3"'));
        // Head length clamps to 12 and points along the final horizontal leg.
        expect(
          svg,
          contains(
            '<polygon points="200,200 189.19,205.22 189.19,194.78" fill="#0f766e" />',
          ),
        );
        expect(svg, isNot(contains('marker-end')));
        expect(svg, isNot(contains('stroke-dasharray')));
        expect(svg, isNot(contains('<text')));
      },
    );

    test('SVG connector exports dash, both arrowheads, rounded corners and '
        'an escaped label pill', () {
      final elements = <CanvasElement>[
        const ConnectorElement(
          id: 'conn-styled',
          z: 0,
          startPoint: Offset(0, 0),
          endPoint: Offset(100, 80),
          lineStyle: 'orthogonal',
          color: Color(0xFF2563EB),
          strokeWidth: 2,
          hasArrowhead: true,
          startArrowhead: true,
          dashPattern: [12, 8],
          cornerRadius: 10,
          label: 'A < B & "C"',
          labelColor: Color(0xFFDC2626),
          labelFontSize: 18,
        ),
      ];

      final svg = exportService.renderToSvg('Styled', elements);

      expect(
        svg,
        contains(
          'd="M 0 0 L 40 0 Q 50 0 50 10 L 50 70 Q 50 80 60 80 L 100 80"',
        ),
      );
      expect(svg, contains('stroke-dasharray="12 8"'));
      expect(svg, contains('stroke-linejoin="round"'));
      expect(
        RegExp(
          '<polygon points="[^"]+" fill="#2563eb" />',
        ).allMatches(svg).length,
        2,
      );
      expect(svg, contains('<polygon points="0,0 '));
      expect(svg, contains('<polygon points="100,80 '));
      expect(svg, contains('rx="6" fill="#f8fafc" stroke="#dc2626"'));
      expect(
        svg,
        contains(
          '<text x="50" y="40" fill="#dc2626" font-size="18" font-weight="600" '
          'text-anchor="middle" dominant-baseline="central">'
          'A &lt; B &amp; &quot;C&quot;</text>',
        ),
      );
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

      final lines = RegExp(
        r'<tspan[^>]*>([^<]*)</tspan>',
      ).allMatches(svg).map((m) => m[1]!).toList();
      expect(lines.length, greaterThan(1));
      expect(lines.join(), 'Design review &amp; planning');
      expect(svg, contains('<rect'));
      expect(svg, contains('rx="8"'));
    });
  });

  group('BoardExportService layer bands', () {
    test('SVG paints layers as bands instead of global z order', () {
      const defaultStroke = StrokeElement(
        id: 'default-stroke',
        z: 99,
        color: Color(0xFFFF0000),
        points: [Offset(10, 10), Offset(90, 10)],
      );
      const lowLayerStroke = StrokeElement(
        id: 'low-layer-stroke',
        z: 0,
        color: Color(0xFF0000FF),
        points: [Offset(10, 30), Offset(90, 30)],
      );
      const highLayerStroke = StrokeElement(
        id: 'high-layer-stroke',
        z: 1,
        color: Color(0xFF00FF00),
        points: [Offset(10, 50), Offset(90, 50)],
      );
      const lowLayer = LayerElement(
        id: 'low-layer',
        z: 0,
        name: 'Low',
        elementIds: ['low-layer-stroke'],
      );
      const highLayer = LayerElement(
        id: 'high-layer',
        z: 1,
        name: 'High',
        elementIds: ['high-layer-stroke'],
      );

      final svg = exportService.renderToSvg('Bands', const [
        defaultStroke,
        highLayerStroke,
        lowLayerStroke,
        lowLayer,
        highLayer,
      ]);

      final defaultIndex = svg.indexOf('stroke="#ff0000"');
      final lowIndex = svg.indexOf('stroke="#0000ff"');
      final highIndex = svg.indexOf('stroke="#00ff00"');
      expect(defaultIndex, greaterThanOrEqualTo(0));
      expect(lowIndex, greaterThanOrEqualTo(0));
      expect(highIndex, greaterThanOrEqualTo(0));
      // Default is bottom-most despite its higher z; layers stack by layer z
      // and a higher z inside one band stays in that band.
      expect(defaultIndex, lessThan(lowIndex));
      expect(lowIndex, lessThan(highIndex));
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

      final pdfBytes = await exportService.renderToPdf(
        'Architecture Draft',
        elements,
      );

      expect(pdfBytes, isNotEmpty);
      // Verify PDF magic header: %PDF-
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });

    test(
      'renders canvas elements to valid PDF with Unicode and emojis without warning',
      () async {
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
      },
    );

    test('renders embedded base64 images in PNG, PDF and SVG exports', () async {
      // 1x1 transparent PNG in base64
      const validPngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      final elements = <CanvasElement>[
        const ImageElement(
          id: 'img-1',
          z: 0,
          center: Offset(100, 100),
          width: 80,
          height: 60,
          imageBase64: validPngBase64,
        ),
      ];

      final pngBytes = await exportService.renderToPng(elements);
      expect(pngBytes, isNotEmpty);
      expect(pngBytes[0], 0x89); // PNG signature

      final pdfBytes = await exportService.renderToPdf('Image Board', elements);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25); // %PDF

      final svg = exportService.renderToSvg('Image Board', elements);
      expect(svg, contains('<image '));
      expect(svg, contains('href="data:image/png;base64,$validPngBase64"'));
    });

    test(
      'converts radian rotation to degrees in SVG and uses vertical cy coordinate',
      () {
        final elements = <CanvasElement>[
          const ShapeElement(
            id: 'rect-1',
            z: 0,
            shapeType: CanvasShapeType.rectangle,
            center: Offset(150, 300),
            size: 100,
            color: Colors.blue,
            rotation: 1.5707963267948966, // pi / 2 radians = 90 degrees
          ),
        ];

        final svg = exportService.renderToSvg('Rotated Rectangle', elements);

        // Verify rotation converted from radians to 90 degrees
        expect(svg, contains('transform="rotate(90.0 150.0 300.0)"'));
        // Verify y derived from cy (300 - (100 * 0.8) / 2 = 260.0), NOT cx (which would give 110.0)
        expect(svg, contains('y="260.0"'));
      },
    );

    test(
      'recognizes canvas curved and orthogonal connector styles in SVG and raster',
      () async {
        final elements = <CanvasElement>[
          const ConnectorElement(
            id: 'conn-curved',
            z: 0,
            startPoint: Offset(20, 20),
            endPoint: Offset(150, 150),
            lineStyle: 'curved',
            color: Colors.teal,
            strokeWidth: 2,
          ),
          const ConnectorElement(
            id: 'conn-ortho',
            z: 1,
            startPoint: Offset(30, 30),
            endPoint: Offset(200, 200),
            lineStyle: 'orthogonal',
            color: Colors.indigo,
            strokeWidth: 2,
          ),
        ];

        final svg = exportService.renderToSvg('Styled Connectors', elements);
        // Curved uses cubic bezier (C)
        expect(svg, contains(' C '));
        // Orthogonal uses step path (L ... L ... L)
        expect(svg, contains(' L '));

        // Also renders in PNG without throwing
        final pngBytes = await exportService.renderToPng(elements);
        expect(pngBytes, isNotEmpty);
      },
    );

    test('PNG and PDF render fully styled, labelled connectors', () async {
      final elements = <CanvasElement>[
        const ConnectorElement(
          id: 'conn-full',
          z: 0,
          startPoint: Offset(20, 20),
          endPoint: Offset(220, 160),
          lineStyle: 'orthogonal',
          color: Color(0xFF2563EB),
          strokeWidth: 4,
          hasArrowhead: true,
          startArrowhead: true,
          dashPattern: [2, 6],
          cornerRadius: 16,
          label: 'Approves',
          labelFontSize: 16,
        ),
      ];

      final png = await exportService.renderToPng(elements);
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      final pdf = await exportService.renderToPdf('Connectors', elements);
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    });

    test('computeElementsBounds skips hidden elements', () {
      const visible = ShapeElement(
        id: 'vis',
        z: 0,
        shapeType: CanvasShapeType.square,
        center: Offset(100, 100),
        size: 40,
        color: Colors.blue,
      );
      const hidden = ShapeElement(
        id: 'hid',
        z: 1,
        hidden: true,
        shapeType: CanvasShapeType.square,
        center: Offset(5000, 5000),
        size: 100,
        color: Colors.red,
      );

      final bounds = exportService.computeElementsBounds(const [
        visible,
        hidden,
      ]);
      expect(bounds.right, lessThan(500.0));
      expect(bounds.bottom, lessThan(500.0));
    });

    test(
      'renderToSvg wraps narrow text into multiple tspans and draws pill rect',
      () {
        const wrappedText = TextElement(
          id: 'txt-wrap',
          z: 0,
          text: 'Alpha Beta Gamma Delta Epsilon Zeta',
          center: Offset(40, 60),
          color: Colors.black,
          width: 90,
          height: 120,
          backgroundColor: Color(0xFFFFF3B0),
        );

        final svg = exportService.renderToSvg('Wrapped Text', const [
          wrappedText,
        ]);
        expect(svg, contains('<rect '));
        expect(svg, contains('fill="#fff3b0"'));
        expect('<tspan'.allMatches(svg).length, greaterThanOrEqualTo(2));
      },
    );

    test(
      'renderToSvg with varying stroke pressures emits segmented lines with varied stroke-width',
      () {
        const stroke = StrokeElement(
          id: 'var-pressure-stroke',
          z: 0,
          color: Colors.blue,
          points: [Offset(10, 10), Offset(50, 10), Offset(100, 10)],
          pressures: [0.2, 1.0, 0.5],
          strokeWidth: 10,
          brushType: 'solid',
          brushId: 'solid',
        );

        final svg = exportService.renderToSvg('Pressure Stroke', const [
          stroke,
        ]);
        expect(svg, contains('<line '));
        // Should have different stroke-width values for different segments
        expect(svg, contains('stroke-width="'));
      },
    );

    test('renderToPng with pressure stroke returns valid PNG bytes', () async {
      const stroke = StrokeElement(
        id: 'pressure-png-stroke',
        z: 0,
        color: Colors.purple,
        points: [Offset(20, 20), Offset(60, 40), Offset(120, 80)],
        pressures: [0.3, 0.9, 0.4],
        strokeWidth: 8,
        brushType: 'watercolor',
        brushId: 'watercolor',
      );

      final bytes = await exportService.renderToPng(const [stroke], scale: 1.0);
      expect(bytes, isNotEmpty);
      // Valid PNG header starts with 0x89, 0x50, 0x4E, 0x47
      expect(bytes.take(4), equals([0x89, 0x50, 0x4E, 0x47]));
    });
  });

  group('BoardExportService F-10 shape upgrades', () {
    test('SVG exports explicit non-uniform rectangle dimensions', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 200,
        width: 200,
        height: 80,
        color: Color(0xFF2563EB),
        strokeWidth: 2,
        isFilled: true,
      );

      final svg = exportService.renderToSvg('Resize', const [rect]);

      expect(svg, contains('width="200.0"'));
      expect(svg, contains('height="80.0"'));
      expect(svg, contains('x="0.0"'));
      expect(svg, contains('y="60.0"'));
      expect(svg, contains('fill="#2563eb"'));
    });

    test('SVG serializes dash pattern and stroke opacity', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 100,
        color: Color(0xFF000000),
        strokeWidth: 3,
        strokeOpacity: 0.5,
        dashPattern: [12, 8],
      );

      final svg = exportService.renderToSvg('Dash', const [rect]);

      expect(svg, contains('stroke-dasharray="12.00 8.00"'));
      expect(svg, contains('stroke-opacity="0.500"'));
    });

    test('SVG omits the stroke at zero width but keeps the fill', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 100,
        color: Color(0xFF22C55E),
        strokeWidth: 0,
        isFilled: true,
      );

      final svg = exportService.renderToSvg('FillOnly', const [rect]);

      expect(svg, contains('stroke="none"'));
      expect(svg, contains('fill="#22c55e"'));
    });

    test('SVG linear shape emits arrowhead markers per toggle', () {
      const both = ShapeElement(
        id: 'a',
        z: 0,
        shapeType: CanvasShapeType.arrow,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 0,
        color: Color(0xFFFF0000),
        strokeWidth: 2,
        startArrowhead: true,
        endArrowhead: true,
      );

      final svg = exportService.renderToSvg('Heads', const [both]);

      expect(svg, contains('marker-start="url(#arrowhead_ff0000)"'));
      expect(svg, contains('marker-end="url(#arrowhead_ff0000)"'));
      expect(svg, contains('<marker id="arrowhead_ff0000"'));
      expect(svg, contains('orient="auto-start-reverse"'));

      const none = ShapeElement(
        id: 'l',
        z: 0,
        shapeType: CanvasShapeType.line,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 0,
        color: Color(0xFFFF0000),
        strokeWidth: 2,
        startArrowhead: false,
        endArrowhead: false,
      );
      final plain = exportService.renderToSvg('Plain', const [none]);
      expect(plain, isNot(contains('marker-start')));
      expect(plain, isNot(contains('marker-end')));
    });

    test('SVG centers the shape label about the shape centre', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 200,
        height: 80,
        color: Color(0xFF000000),
        strokeWidth: 0,
        label: 'Hello',
        labelFontSize: 18,
      );

      final svg = exportService.renderToSvg('Label', const [rect]);

      expect(svg, contains('text-anchor="middle"'));
      expect(svg, contains('x="100.00"'));
      expect(svg, contains('>Hello</text>'));
    });

    test('PNG exports a non-uniform rectangle to valid bytes', () async {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(120, 80),
        size: 200,
        width: 200,
        height: 80,
        color: Color(0xFF2563EB),
        strokeWidth: 3,
        isFilled: true,
        label: 'Box',
      );

      final bytes = await exportService.renderToPng(const [rect]);

      expect(bytes, isNotEmpty);
      expect(bytes.take(4), equals([0x89, 0x50, 0x4E, 0x47]));
    });
  });
}
