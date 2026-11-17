import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inklink/domain/services/canvas/board_export_service.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/geometry/canvas_selection_transform.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

const _note = StickyNoteElement(
  id: 'note',
  z: 2,
  center: Offset(100, 100),
  width: 160,
  height: 160,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Given legacy payload, Then note typography defaults and height are preserved',
    () {
      final note =
          CanvasElement.fromMap('legacy', {
                'type': 'sticky_note',
                'cx': 10,
                'cy': 20,
                'width': 120,
                'height': 180,
              })
              as StickyNoteElement;
      expect(note.fontSize, 14);
      expect(note.fontWeight, 500);
      expect(note.textColor, const Color(0xFF1E293B));
      expect(note.textAlign, 'left');
      expect(note.autoSize, isFalse);
      expect(note.authorUid, isNull);
      expect(note.height, 180);
    },
  );

  test(
    'Given styled note, Then all metadata round-trips and affects equality',
    () {
      final note = _note.copyWith(
        text: 'Idea',
        fontSize: 24,
        fontWeight: 700,
        textColor: const Color(0xFF224466),
        textAlign: 'right',
        autoSize: true,
        authorUid: 'owner',
        opacity: 0.7,
        rotation: 0.3,
      );
      final restored = CanvasElement.fromMap(note.id, note.toMap());
      expect(restored, note);
      expect(restored.hashCode, note.hashCode);
      expect(note.copyWith(fontSize: 20), isNot(note));
      expect(note.copyWith(autoSize: false), isNot(note));
    },
  );

  test(
    'Given long text, Then auto-height fits shared text metrics up to the cap',
    () {
      final note = fitStickyNoteHeight(
        _note.copyWith(
          autoSize: true,
          text: List.filled(8, 'idea').join(' '),
          fontSize: 20,
        ),
      );
      final layout = stickyNoteTextLayout(note);
      expect(note.height, greaterThan(160));
      expect(
        layout.painter.height,
        lessThanOrEqualTo(stickyNoteTextRect(note).height),
      );
      layout.painter.dispose();
      final huge = fitStickyNoteHeight(
        note.copyWith(text: List.filled(1000, 'word').join(' ')),
      );
      expect(huge.height, 480);
      final manual = note.copyWith(autoSize: false, height: 90);
      expect(fitStickyNoteHeight(manual), manual);
    },
  );

  test(
    'Given group resize, Then manual dimensions disable subsequent auto-height',
    () {
      final note = _note.copyWith(autoSize: true, authorUid: 'owner');
      final payload = scaleElementPayload(
        note,
        const Rect.fromLTWH(0, 0, 200, 200),
        const Rect.fromLTWH(0, 0, 300, 400),
      );
      expect(payload['autoSize'], isFalse);
      expect(payload['height'], 320);
      expect(payload['authorUid'], 'owner');
    },
  );

  test(
    'Given wrapped centered text, Then SVG emits shared line positions and styled paper',
    () {
      final note = _note.copyWith(
        text: 'Plan & test\nShip carefully',
        fontSize: 20,
        fontWeight: 700,
        textAlign: 'center',
        textColor: const Color(0xFF113355),
        autoSize: true,
        rotation: 0.2,
      );
      const service = BoardExportServiceImpl();
      final svg = service.renderToSvg('Notes', [note]);
      final layout = stickyNoteTextLayout(note);
      expect(
        RegExp('<tspan ').allMatches(svg).length,
        layout.painter.computeLineMetrics().length,
      );
      expect(svg, contains('&amp;'));
      expect(svg, contains('font-size="20.0" font-weight="700"'));
      expect(svg, contains('fill="#113355"'));
      expect(svg, contains('clip-path="url(#note_'));
      expect(svg, contains('<linearGradient'));
      expect(svg, contains('stdDeviation="8"'));
      expect(svg, contains('transform="rotate('));
      layout.painter.dispose();
    },
  );

  test(
    'Given styled note, Then exported pixels match shared canvas painter and PDF remains valid',
    () async {
      final note = _note.copyWith(
        text: 'Line one\nLine two',
        fontSize: 24,
        fontWeight: 700,
        textAlign: 'right',
        textColor: const Color(0xFFCC0000),
        opacity: 0.7,
        rotation: 0.2,
      );
      const service = BoardExportServiceImpl();
      final bounds = service.computeElementsBounds([note]);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      canvas.translate(-bounds.left, -bounds.top);
      canvas.saveLayer(
        elementBounds(note)!.inflate(8),
        Paint()..color = Color.fromRGBO(255, 255, 255, note.opacity),
      );
      paintStickyNoteElement(canvas, note);
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        bounds.width.ceil(),
        bounds.height.ceil(),
      );
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final expected = img.decodePng(bytes.buffer.asUint8List())!;
      final exported = img.decodePng(
        await service.renderToPng([note], scale: 1),
      )!;
      expect(exported.width, expected.width);
      expect(exported.height, expected.height);
      for (final point in const [
        Offset(100, 100),
        Offset(70, 80),
        Offset(140, 60),
        Offset(60, 140),
      ]) {
        final x = (point.dx - bounds.left).round();
        final y = (point.dy - bounds.top).round();
        final a = exported.getPixel(x, y), b = expected.getPixel(x, y);
        expect(a.r, b.r);
        expect(a.g, b.g);
        expect(a.b, b.b);
      }
      image.dispose();
      picture.dispose();
      final pdf = await service.renderToPdf('Notes', [note]);
      expect(utf8.decode(pdf.take(4).toList()), '%PDF');
    },
  );
}
