import 'dart:convert';

import 'dart:ui' show instantiateImageCodec;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_export_options.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// The web export path: [BoardExportServiceImpl.renderCanvasExport] renders
/// the same export as on phones, but to bytes with a file name and type, so
/// the browser can download it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = BoardExportServiceImpl();
  const elements = <CanvasElement>[
    ShapeElement(
      id: 'shape-1',
      z: 0,
      shapeType: CanvasShapeType.rectangle,
      center: Offset(200, 150),
      size: 120,
      color: Colors.blue,
    ),
    StrokeElement(
      id: 'stroke-1',
      z: 1,
      color: Colors.black,
      points: [Offset(40, 40), Offset(260, 220)],
    ),
  ];

  Future<ExportedCanvasFile> render(BoardExportFormat format) =>
      service.renderCanvasExport(
        boardTitle: 'My Board / v2',
        elements: elements,
        options: CanvasExportOptions(format: format, scale: 1),
      );

  test('PNG: a .png file name, image/png type and PNG bytes', () async {
    final file = await render(BoardExportFormat.png);
    expect(file.fileName, endsWith('.png'));
    expect(file.fileName, isNot(contains('/')));
    expect(file.mimeType, 'image/png');
    // PNG signature.
    expect(file.bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('PDF: a .pdf file name, application/pdf type and PDF bytes', () async {
    final file = await render(BoardExportFormat.pdf);
    expect(file.fileName, endsWith('.pdf'));
    expect(file.mimeType, 'application/pdf');
    expect(ascii.decode(file.bytes.sublist(0, 5)), '%PDF-');
  });

  test('SVG: a .svg file name, image/svg+xml type and SVG markup', () async {
    final file = await render(BoardExportFormat.svg);
    expect(file.fileName, endsWith('.svg'));
    expect(file.mimeType, 'image/svg+xml');
    expect(utf8.decode(file.bytes), contains('<svg'));
  });

  test('uses the same crop as the phone export', () async {
    final options = const CanvasExportOptions(scale: 1);
    final plan = service.buildExportPlan(elements: elements, options: options);
    final file = await service.renderCanvasExport(
      boardTitle: 'Board',
      elements: elements,
      options: options,
    );
    final codec = await instantiateImageCodec(file.bytes);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, plan.bounds.width.round());
      expect(frame.image.height, plan.bounds.height.round());
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });
}
