import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

TextElement _text({
  Offset center = const Offset(100, 100),
  double width = 120,
  double height = 20,
  double rotation = 0,
  String text = 'Hello world',
}) {
  return TextElement(
    id: 'text-1',
    z: 0,
    text: text,
    center: center,
    color: Colors.black,
    width: width,
    height: height,
    rotation: rotation,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('text geometry', () {
    test('hit box matches the drawn box instead of a circle at the corner', () {
      final element = _text();
      // Top-left anchor is inside the text.
      expect(elementContains(element, const Offset(100, 100)), isTrue);
      // Bottom-right corner is inside (Rect.contains excludes the far edge).
      expect(elementContains(element, const Offset(219, 119)), isTrue);
      // Just outside the right edge.
      expect(elementContains(element, const Offset(221, 110)), isFalse);
      // The old 64px circle would have selected this empty area above-left.
      expect(elementContains(element, const Offset(70, 70)), isFalse);
    });

    test('rotation rotates the hit box and its bounds', () {
      final element = _text(rotation: math.pi / 2);
      final bounds = elementBounds(element)!;
      expect(bounds.width, closeTo(20, 0.001));
      expect(bounds.height, closeTo(120, 0.001));

      // 20px below the box centre is inside the rotated (now vertical) box.
      expect(elementContains(element, const Offset(160, 130)), isTrue);
      // 65px below is outside even though it is inside the unrotated height.
      expect(elementContains(element, const Offset(160, 175)), isFalse);
    });

    test('unmeasured text falls back to a real layout', () {
      final element = _text(width: 0, height: 0);
      final bounds = elementBounds(element)!;
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
      expect(elementContains(element, const Offset(101, 101)), isTrue);
    });
  });

  group('connector geometry', () {
    test('curved samples leave the straight chord', () {
      const start = Offset(0, 0);
      const end = Offset(200, 100);
      final straight = connectorPolyline(start, end, 'straight');
      final curved = connectorPolyline(start, end, 'curved');
      expect(straight.length, 2);
      expect(curved.length, greaterThan(2));
      final maxDeviation = curved
          .map((point) => distanceToPolyline(straight, point))
          .reduce(math.max);
      expect(maxDeviation, greaterThan(5));
    });

    test('orthogonal samples step through the midpoint', () {
      final points = connectorPolyline(
        const Offset(0, 0),
        const Offset(100, 80),
        'orthogonal',
      );
      expect(points, hasLength(4));
      expect(points[1], const Offset(50, 0));
      expect(points[2], const Offset(50, 80));
    });
  });

  group('element bounds', () {
    test('shapes use their rendered aspect ratio and rotation', () {
      const element = ShapeElement(
        id: 'shape-1',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        color: Colors.black,
      );
      final bounds = elementBounds(element)!;
      expect(bounds.width, closeTo(100 * 1.35 + element.strokeWidth, 0.001));
      expect(bounds.height, closeTo(100 * 0.8 + element.strokeWidth, 0.001));
      expect(elementContains(element, const Offset(100, 100)), isTrue);
      expect(elementContains(element, const Offset(100, 160)), isFalse);
    });

    test('stroke bounds include half the stroke width', () {
      const element = StrokeElement(
        id: 'stroke-1',
        z: 0,
        points: [Offset(0, 0), Offset(10, 10)],
        color: Colors.black,
        strokeWidth: 4,
      );
      final bounds = elementBounds(element)!;
      expect(bounds.left, -2);
      expect(bounds.right, 12);
    });

    test('elementsBounds unions everything', () {
      final union = elementsBounds(<CanvasElement>[
        _text(center: const Offset(0, 0)),
        _text(center: const Offset(400, 400)),
      ]);
      expect(union, isNotNull);
      expect(union!.left, 0);
      expect(union.bottom, greaterThanOrEqualTo(420));
    });
  });

  group('highlighter stroke style', () {
    test('scales width 2.5x and clamps to the marker range', () {
      expect(highlighterStrokeWidth(10), 25);
      expect(highlighterStrokeWidth(1), highlighterMinWidth);
      expect(highlighterStrokeWidth(40), highlighterMaxWidth);
    });

    test('scales opacity to 35% of the brush opacity', () {
      expect(highlighterStrokeOpacity(1), closeTo(0.35, 1e-9));
      expect(highlighterStrokeOpacity(0.8), closeTo(0.28, 1e-9));
      expect(highlighterStrokeOpacity(0), 0);
    });
  });

  group('rotated images', () {
    const upright = ImageElement(
      id: 'img',
      z: 0,
      center: Offset(100, 100),
      width: 80,
      height: 20,
    );
    const turned = ImageElement(
      id: 'img',
      z: 0,
      center: Offset(100, 100),
      width: 80,
      height: 20,
      rotation: math.pi / 2,
    );

    test('bounds follow the rotation', () {
      final before = elementBounds(upright)!;
      expect(before.width, 80);
      expect(before.height, 20);

      final after = elementBounds(turned)!;
      expect(after.width, closeTo(20, 1e-6));
      expect(after.height, closeTo(80, 1e-6));
    });

    test('hit-testing rotates with the image', () {
      // The long axis now runs vertically.
      expect(elementContains(turned, const Offset(100, 130)), isTrue);
      expect(elementContains(turned, const Offset(130, 100)), isFalse);
    });
  });

  group('marker stroke style', () {
    test('widens by 1.4x', () {
      expect(markerStrokeWidth(10), closeTo(14, 1e-9));
    });

    test('keeps 90% of the brush opacity, rounded', () {
      expect(markerStrokeOpacity(1), 0.9);
      expect(markerStrokeOpacity(0.8), 0.72);
      expect(markerStrokeOpacity(0), 0);
    });
  });

  group('connector bounds and anchors', () {
    test('curved and bezier connector bounds extend beyond endpoint box', () {
      const start = Offset(100, 0);
      const end = Offset(120, 200);
      final rawBox = Rect.fromPoints(start, end);

      for (final style in const ['curved', 'bezier']) {
        const padding = 2.0;
        final connector = ConnectorElement(
          id: 'conn-$style',
          z: 0,
          startPoint: start,
          endPoint: end,
          lineStyle: style,
          strokeWidth: 4,
        );
        final bounds = elementBounds(connector)!;
        expect(bounds.left, lessThan(rawBox.left - padding));
        expect(bounds.right, greaterThan(rawBox.right + padding));
        for (final pt in connectorPolyline(start, end, style)) {
          expect(bounds.inflate(1e-6).contains(pt), isTrue);
        }
      }
    });

    test('highlighter bounds and hit-testing honor resolved 2.5x brush width',
        () {
      const stroke = StrokeElement(
        id: 'hi-1',
        z: 0,
        points: [Offset(0, 0), Offset(100, 0)],
        color: Colors.yellow,
        strokeWidth: 10,
        brushType: 'highlighter',
      );
      final bounds = elementBounds(stroke)!;
      // 10 * 2.5 = 25 width -> half-width = 12.5
      expect(bounds.top, closeTo(-12.5, 1e-6));
      expect(bounds.bottom, closeTo(12.5, 1e-6));
      expect(elementContains(stroke, const Offset(50, 11)), isTrue);
      expect(elementContains(stroke, const Offset(50, 20)), isFalse);
    });

    test('resolveConnectorAnchorPoint honors arrow proportions and rotation',
        () {
      const arrow = ShapeElement(
        id: 'arrow-1',
        z: 0,
        shapeType: CanvasShapeType.arrow,
        center: Offset(100, 100),
        size: 100,
        color: Colors.blue,
      );
      // arrow rect is 130 x 70 -> top is 100 - 35 = 65, right is 100 + 65 = 165.
      expect(
        resolveConnectorAnchorPoint(arrow, 'top', Offset.zero),
        const Offset(100, 65),
      );
      expect(
        resolveConnectorAnchorPoint(arrow, 'right', Offset.zero),
        const Offset(165, 100),
      );

      final rotated = ShapeElement(
        id: 'sq-rot',
        z: 0,
        shapeType: CanvasShapeType.square,
        center: const Offset(100, 100),
        size: 100,
        color: Colors.red,
        rotation: math.pi / 2,
      );
      // Top local (100, 50) rotated +pi/2 around (100, 100) lands at (150, 100).
      final rotatedTop = resolveConnectorAnchorPoint(
        rotated,
        'top',
        Offset.zero,
      );
      expect(rotatedTop.dx, closeTo(150, 1e-6));
      expect(rotatedTop.dy, closeTo(100, 1e-6));
    });

    test('resolveConnectorEndpoints computes auto anchors from targets', () {
      const left = ShapeElement(
        id: 's1',
        z: 0,
        shapeType: CanvasShapeType.square,
        center: Offset(100, 100),
        size: 80,
        color: Colors.green,
      );
      const right = ShapeElement(
        id: 's2',
        z: 1,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(300, 100),
        size: 100,
        color: Colors.orange,
      );
      const connector = ConnectorElement(
        id: 'c1',
        z: 2,
        startElementId: 's1',
        startPoint: Offset.zero,
        startAnchor: 'auto',
        endElementId: 's2',
        endPoint: Offset.zero,
        endAnchor: 'auto',
      );
      final (start, end) = resolveConnectorEndpoints(connector, {
        's1': left,
        's2': right,
      });
      // left.right = 140; right.left = 300 - (100 * 1.35)/2 = 232.5
      expect(start.dx, closeTo(140, 1e-6));
      expect(start.dy, closeTo(100, 1e-6));
      expect(end.dx, closeTo(232.5, 1e-6));
      expect(end.dy, closeTo(100, 1e-6));
    });
  });

  group('F-10 shape upgrades', () {
    test('explicit width/height override the legacy aspect box', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 200,
        width: 200,
        height: 80,
        color: Colors.black,
      );
      final box = shapeElementRect(rect);
      expect(box.width, closeTo(200, 1e-6));
      expect(box.height, closeTo(80, 1e-6));
      expect(box.center, const Offset(100, 100));
    });

    test('legacy rectangle still derives its aspect box', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        color: Colors.black,
      );
      final box = shapeElementRect(rect);
      expect(box.width, closeTo(135, 1e-6));
      expect(box.height, closeTo(80, 1e-6));
    });

    test('rotated rectangle hit-tests in its turned frame', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 200,
        height: 40,
        color: Colors.black,
        rotation: math.pi / 2,
      );
      // Long axis now vertical: 80px below centre is inside.
      expect(shapeContainsPoint(rect, const Offset(100, 180)), isTrue);
      // 80px to the right is outside the turned (now narrow) box.
      expect(shapeContainsPoint(rect, const Offset(180, 100)), isFalse);
    });

    test('dashPath splits a solid outline into separate contours', () {
      const rect = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset.zero,
        size: 100,
        width: 100,
        height: 100,
        color: Colors.black,
      );
      final solid = buildShapePath(rect);
      final dashed = dashPath(solid, const [10, 10]);
      expect(solid.computeMetrics().length, 1);
      expect(dashed.computeMetrics().length, greaterThan(1));
      final solidLen = solid
          .computeMetrics()
          .fold<double>(0, (sum, m) => sum + m.length);
      final dashedLen = dashed
          .computeMetrics()
          .fold<double>(0, (sum, m) => sum + m.length);
      expect(dashedLen, lessThan(solidLen));
    });

    test('dashPath returns the source for null or invalid patterns', () {
      final source = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      expect(dashPath(source, null), same(source));
      expect(dashPath(source, const [5]), same(source));
      expect(dashPath(source, const [0, -1]), same(source));
    });

    test('fill and stroke paint independently', () async {
      const filled = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 100,
        color: Color(0xFFFF0000),
        isFilled: true,
        strokeWidth: 0,
      );
      const outlined = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 100,
        color: Color(0xFFFF0000),
        isFilled: false,
        strokeWidth: 6,
      );
      final filledPx = await _renderShape(filled);
      final outlinedPx = await _renderShape(outlined);
      // Filled, no stroke: interior opaque, just outside the edge transparent.
      expect(_alpha(filledPx, 100, 100), greaterThan(200));
      expect(_alpha(filledPx, 160, 100), 0);
      // Outlined, no fill: interior transparent, on the edge opaque.
      expect(_alpha(outlinedPx, 100, 100), 0);
      expect(_alpha(outlinedPx, 150, 100), greaterThan(200));
    });

    test('stroke opacity scales the outline alpha', () async {
      const shape = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 100,
        height: 100,
        color: Color(0xFFFF0000),
        isFilled: false,
        strokeWidth: 6,
        strokeOpacity: 0.5,
      );
      final px = await _renderShape(shape);
      expect(_alpha(px, 150, 100), closeTo(128, 6));
    });

    test('a centered label renders symmetrically about the shape centre',
        () async {
      const shape = ShapeElement(
        id: 'r',
        z: 0,
        shapeType: CanvasShapeType.rectangle,
        center: Offset(100, 100),
        size: 100,
        width: 200,
        height: 80,
        color: Color(0xFFFF0000),
        isFilled: false,
        strokeWidth: 0,
        label: 'XXXX',
        labelColor: Color(0xFF000000),
        labelFontSize: 24,
      );
      final px = await _renderShape(shape);
      var minX = 200, maxX = 0, opaque = 0;
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          if (_alpha(px, x, y) > 40) {
            opaque++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
          }
        }
      }
      expect(opaque, greaterThan(0));
      expect((minX + maxX) / 2, closeTo(100, 3));
    });
  });

  group('F-11 connector rendering', () {
    test('curved connectors hit along the visible curve, not the chord', () {
      const connector = ConnectorElement(
        id: 'c',
        z: 0,
        startPoint: Offset(0, 0),
        endPoint: Offset(200, 100),
        lineStyle: 'curved',
        strokeWidth: 2,
      );
      final onCurve = connectorPolyline(
        connector.startPoint,
        connector.endPoint,
        'curved',
        samples: 8,
      )[2];
      expect(elementContains(connector, onCurve), isTrue);
      expect(
        elementContains(connector, connectorMidpoint(
          connector.startPoint,
          connector.endPoint,
          'curved',
        )),
        isTrue,
      );
      // The straight chord a quarter of the way along is off the curve.
      expect(elementContains(connector, const Offset(50, 25)), isFalse);
    });

    test('rounded orthogonal corners leave the sharp corner and keep ends',
        () {
      final sharp = connectorPolyline(
        const Offset(0, 0),
        const Offset(100, 80),
        'orthogonal',
      );
      final rounded = connectorPolyline(
        const Offset(0, 0),
        const Offset(100, 80),
        'orthogonal',
        cornerRadius: 20,
        samples: 64,
      );
      expect(sharp, contains(const Offset(50, 0)));
      expect(rounded.first, const Offset(0, 0));
      expect((rounded.last - const Offset(100, 80)).distance, lessThan(0.01));
      expect(
        distanceToPolyline(rounded, const Offset(50, 0)),
        greaterThan(3),
      );
      // The rounded corner is a quadratic peaking ~7.07px from the vertex.
      expect(distanceToPolyline(rounded, const Offset(45, 5)), lessThan(1));
    });

    test('the label midpoint sits halfway along the painted path', () {
      final mid = connectorMidpoint(
        const Offset(0, 0),
        const Offset(100, 80),
        'orthogonal',
      );
      // Total length 180: halfway is 40px down the vertical leg at x=50.
      expect(mid.dx, closeTo(50, 0.01));
      expect(mid.dy, closeTo(40, 0.01));
    });

    test('arrowheads are drawn only on the enabled ends', () async {
      final endOnly = await _renderConnector(endArrowhead: true);
      expect(_alpha(endOnly, 172, 97), greaterThan(0));
      expect(_alpha(endOnly, 28, 97), 0);

      final both = await _renderConnector(
        endArrowhead: true,
        startArrowhead: true,
      );
      expect(_alpha(both, 28, 97), greaterThan(0));
    });

    test('a dash pattern leaves gaps along the line', () async {
      final solid = await _renderConnector(endArrowhead: false);
      final dashed = await _renderConnector(
        endArrowhead: false,
        dashPattern: const [10, 10],
      );
      var solidGaps = 0, dashedGaps = 0;
      for (var x = 30; x < 170; x++) {
        if (_alpha(solid, x, 100) == 0) solidGaps++;
        if (_alpha(dashed, x, 100) == 0) dashedGaps++;
      }
      expect(solidGaps, 0);
      expect(dashedGaps, greaterThan(30));
    });

    test('a label pill is centred on the path midpoint', () async {
      final plain = await _renderConnector(endArrowhead: false);
      final labelled = await _renderConnector(
        endArrowhead: false,
        label: 'XXXX',
      );
      expect(_alpha(plain, 100, 93), 0);
      expect(_alpha(labelled, 100, 93), greaterThan(0));
      var minX = 200, maxX = 0;
      for (var x = 0; x < 200; x++) {
        if (_alpha(labelled, x, 92) > 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
      expect((minX + maxX) / 2, closeTo(100, 2));
    });
  });
}

Future<ByteData> _renderConnector({
  bool endArrowhead = true,
  bool startArrowhead = false,
  List<double>? dashPattern,
  String label = '',
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintConnectorElement(
    canvas,
    const Offset(20, 100),
    const Offset(180, 100),
    lineStyle: 'straight',
    color: const Color(0xFF2563EB),
    strokeWidth: 2,
    dashPattern: dashPattern,
    startArrowhead: startArrowhead,
    endArrowhead: endArrowhead,
    label: label,
  );
  final image = await recorder.endRecording().toImage(200, 200);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!;
}

Future<ByteData> _renderShape(ShapeElement shape, {int size = 200}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintShapeElement(canvas, shape);
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!;
}

int _alpha(ByteData px, int x, int y, {int width = 200}) {
  return px.getUint8((y * width + x) * 4 + 3);
}
