import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_element.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';

ShapeElement _shape({
  String fillMode = 'solid',
  Color? fillColor,
  Color? gradientStart,
  Color? gradientEnd,
  double gradientAngle = 0,
}) => ShapeElement(
  id: 'shape',
  z: 0,
  shapeType: CanvasShapeType.rectangle,
  center: const Offset(100, 100),
  size: 160,
  width: 160,
  height: 160,
  color: const Color(0xFF2563EB),
  strokeWidth: 4,
  fillMode: fillMode,
  fillColor: fillColor ?? const Color(0xFFEF4444),
  gradientStart: gradientStart,
  gradientEnd: gradientEnd,
  gradientAngle: gradientAngle,
);

Future<ByteData> _render(ShapeElement shape) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintShapeElement(canvas, shape);
  final image = await recorder.endRecording().toImage(200, 200);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!;
}

Color _pixel(ByteData data, int x, int y) {
  final offset = (y * 200 + x) * 4;
  return Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}

void main() {
  test('Given independent fill color, Then the payload round-trips it', () {
    final shape = _shape(
      fillMode: 'linear',
      gradientStart: const Color(0xFFEF4444),
      gradientEnd: const Color(0xFF22C55E),
      gradientAngle: 45,
    );

    final parsed = CanvasElement.fromMap('shape', shape.toMap()) as ShapeElement;

    expect(parsed, shape);
    expect(parsed.fillMode, 'linear');
    expect(parsed.fillColor, const Color(0xFFEF4444));
    expect(parsed.gradientStart, const Color(0xFFEF4444));
    expect(parsed.gradientEnd, const Color(0xFF22C55E));
    expect(parsed.gradientAngle, 45);
    expect(parsed.isFilled, isTrue);
  });

  test('Given a legacy isFilled payload, Then it reads as a solid fill', () {
    final parsed = CanvasElement.fromMap('shape', const {
      'type': 'shape',
      'shapeType': 'rectangle',
      'cx': 100.0,
      'cy': 100.0,
      'size': 80.0,
      'color': 0xFF2563EB,
      'strokeWidth': 2.0,
      'isFilled': true,
    }) as ShapeElement;

    expect(parsed.fillMode, 'solid');
    expect(parsed.resolvedFillColor, const Color(0xFF2563EB));
  });

  test('Given a solid fill, Then the interior uses fill, not stroke', () async {
    final data = await _render(_shape());
    expect(
      _pixel(data, 100, 100),
      const Color(0xFFEF4444),
      reason: 'centre is fill colour',
    );
    expect(
      _pixel(data, 20, 100),
      isNot(const Color(0xFFEF4444)),
      reason: 'outside the shape stays transparent',
    );
  });

  test('Given a linear gradient, Then pixels vary across the shape', () async {
    final data = await _render(
      _shape(
        fillMode: 'linear',
        gradientStart: const Color(0xFFEF4444),
        gradientEnd: const Color(0xFF22C55E),
      ),
    );
    final left = _pixel(data, 30, 100);
    final right = _pixel(data, 170, 100);

    expect(left, isNot(right));
    expect(left.r, greaterThan(right.r));
    expect(right.g, greaterThan(left.g));
  });

  test('Given a radial gradient, Then the centre differs from the edge',
      () async {
    final data = await _render(
      _shape(
        fillMode: 'radial',
        gradientStart: const Color(0xFFEF4444),
        gradientEnd: const Color(0xFF22C55E),
      ),
    );
    expect(_pixel(data, 100, 100), isNot(_pixel(data, 30, 100)));
  });

  test('Given a layer blend, Then SVG groups its members', () {
    const service = BoardExportServiceImpl();
    final svg = service.renderToSvg('Blend', [
      _shape(),
      const LayerElement(
        id: 'layer',
        z: 0,
        name: 'Ink',
        opacity: 0.6,
        blendMode: 'multiply',
        elementIds: ['shape'],
      ),
    ]);

    expect(svg, contains('style="mix-blend-mode:multiply"'));
    expect(svg, contains('opacity="0.600"'));
  });

  test('Given a hidden layer, Then its members are not exported', () {
    const service = BoardExportServiceImpl();
    final svg = service.renderToSvg('Hidden', [
      _shape(fillMode: 'none', fillColor: const Color(0xFFEF4444)),
      const LayerElement(
        id: 'layer',
        z: 0,
        name: 'Hidden',
        hidden: true,
        elementIds: ['shape'],
      ),
    ]);

    expect(svg, isNot(contains('fill="#ef4444"')));
  });

  test('Given gradients, Then SVG emits definitions and references them', () {
    const service = BoardExportServiceImpl();
    final linear = service.renderToSvg('Linear', [
      _shape(
        fillMode: 'linear',
        gradientStart: const Color(0xFFEF4444),
        gradientEnd: const Color(0xFF22C55E),
      ),
    ]);
    final radial = service.renderToSvg('Radial', [
      _shape(
        fillMode: 'radial',
        gradientStart: const Color(0xFFEF4444),
        gradientEnd: const Color(0xFF22C55E),
      ),
    ]);

    expect(linear, contains('<linearGradient id="shapeFill_shape"'));
    expect(linear, contains('fill="url(#shapeFill_shape)"'));
    expect(linear, contains('stop-color="#ef4444"'));
    expect(radial, contains('<radialGradient id="shapeFill_shape"'));
    expect(radial, contains('fill="url(#shapeFill_shape)"'));
  });
}
