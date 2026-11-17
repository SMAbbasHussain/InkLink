import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_element.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';

void main() {
  const service = BoardExportServiceImpl();
  const frame = FrameElement(
    id: 'frame',
    z: 0,
    center: Offset(300, 200),
    width: 400,
    height: 300,
    title: 'Section A',
    color: Color(0xFF2563EB),
  );

  test('Given a frame, Then SVG includes its background and border but no '
      'heading', () {
    final svg = service.renderToSvg('Frames', [frame]);

    expect(svg, contains('fill-opacity="0.04"'));
    expect(svg, contains('stroke-opacity="0.55"'));
    expect(svg, contains('width="400"'));
    expect(svg, contains('height="300"'));
    expect(svg, isNot(contains('fill-opacity="0.09"')));
    expect(svg, isNot(contains('Section A')));
  });

  test('Given a frame, Then export bounds cover the whole frame', () {
    final bounds = service.computeElementsBounds([frame]);

    expect(bounds.contains(const Offset(100, 50)), isTrue);
    expect(bounds.contains(const Offset(500, 350)), isTrue);
    expect(bounds.width, greaterThanOrEqualTo(400));
    expect(bounds.height, greaterThanOrEqualTo(300));
  });

  test('Given a frame, Then PNG rendering produces valid output', () async {
    final png = await service.renderToPng([frame]);

    expect(png, isNotEmpty);
  });
}
