import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_board_settings.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';

void main() {
  const service = BoardExportServiceImpl();
  const paper = CanvasBoardSettings(backgroundColor: Color(0xFF1E293B));

  test('Given custom paper, Then SVG uses it for the background fill', () {
    final svg = service.renderToSvg(
      'Paper',
      const [],
      settings: paper,
    );

    expect(svg, contains('fill="#1e293b"'));
    expect(svg, isNot(contains('fill="#ffffff"')));
  });

  test('Given custom paper, Then PNG pixels use the paper colour', () async {
    final png = await service.renderToPng(const [], settings: paper);
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final bytes = data!.buffer.asUint8List();
      expect(bytes[0], 0x1E, reason: 'red');
      expect(bytes[1], 0x29, reason: 'green');
      expect(bytes[2], 0x3B, reason: 'blue');
      expect(bytes[3], 0xFF, reason: 'opaque');
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('Given no custom paper, Then exports keep the white default', () {
    final svg = service.renderToSvg('Paper', const []);

    expect(svg, contains('fill="#ffffff"'));
  });
}
