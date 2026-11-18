import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_board_settings.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';

void main() {
  const service = BoardExportServiceImpl();
  const bounds = Rect.fromLTWH(0, 0, 100, 50);

  test('Given a crop and 4× scale, Then PNG dimensions follow both', () async {
    final png = await service.renderToPng(
      const [],
      scale: 4,
      exportBounds: bounds,
    );
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, 400);
      expect(frame.image.height, 200);
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('Given transparent export, Then background pixels have alpha 0',
      () async {
    final png = await service.renderToPng(
      const [],
      scale: 1,
      exportBounds: bounds,
      transparentBackground: true,
    );
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(data!.buffer.asUint8List()[3], 0);
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('Given opaque export, Then background pixels use the paper colour',
      () async {
    const paper = CanvasBoardSettings(backgroundColor: Color(0xFF1E293B));
    final png = await service.renderToPng(
      const [],
      scale: 1,
      exportBounds: bounds,
      settings: paper,
    );
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final bytes = data!.buffer.asUint8List();
      expect(bytes.sublist(0, 4), [0x1E, 0x29, 0x3B, 0xFF]);
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('Given transparent SVG, Then no background rect is emitted', () {
    final svg = service.renderToSvg(
      'Crop',
      const [],
      exportBounds: bounds,
      transparentBackground: true,
    );

    expect(svg, isNot(contains('<!-- Background -->')));
    expect(svg, contains('viewBox="0 0 100 50"'));
  });

  test('Given opaque SVG, Then the background rect is emitted', () {
    final svg = service.renderToSvg(
      'Crop',
      const [],
      exportBounds: bounds,
    );

    expect(svg, contains('<!-- Background -->'));
    expect(svg, contains('fill="#ffffff"'));
  });
}
