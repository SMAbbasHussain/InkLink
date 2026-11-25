import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

import 'paint_golden_pixels.dart';
import 'paint_golden_scene.dart';

/// Pixel golden for the shared element painters.
///
/// The scene is shared with the interactive painter golden so both render paths
/// are held to the same input. The digest below was captured BEFORE the
/// stroke-fill and text-box drawing sequences were extracted into shared
/// helpers, so a matching digest proves the refactor changed nothing that
/// reaches the raster output.
///
/// The digest alone cannot tell a real repaint from a quiet one, so
/// `ablating any single element changes the exported bytes` re-renders the
/// scene with each element removed in turn. Every element must contribute
/// pixels; otherwise a dropped paint branch could be papered over by
/// regenerating the golden.
///
/// Differences that the two paths preserve on purpose — and the ones that were
/// resolved — are catalogued in `docs/canvas/paint-parity.md`.
const String _expectedDigest = 'bb16e6bffea56427';

String _digest(List<int> bytes) {
  // Two independent 32-bit accumulators give a 64-bit, non-negative digest.
  // (A single 64-bit FNV accumulator overflows Dart's signed int and prints a
  // negative hex string.) Dependency-free and stable across runs.
  var a = 0x811c9dc5;
  var b = 0x01000193;
  for (final byte in bytes) {
    a = ((a ^ (byte & 0xff)) * 0x01000193) & 0xFFFFFFFF;
    b = ((b + (byte & 0xff)) * 0x85EBCA6B) & 0xFFFFFFFF;
  }
  String hex(int v) => v.toRadixString(16).padLeft(8, '0');
  return '${hex(a)}${hex(b)}';
}

/// Records the drawing calls a painter makes, including the paint properties
/// that decide the rendered result (style, colour, placement).
class _RecordingCanvas implements Canvas {
  final List<String> ops = [];

  static String _color(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0');

  @override
  void save() => ops.add('save');

  @override
  void restore() => ops.add('restore');

  @override
  void translate(double dx, double dy) =>
      ops.add('translate(${dx.toStringAsFixed(2)},${dy.toStringAsFixed(2)})');

  @override
  void rotate(double radians) =>
      ops.add('rotate(${radians.toStringAsFixed(3)})');

  @override
  void drawPath(Path path, Paint paint) => ops.add(
    'drawPath(style=${paint.style.name},color=${_color(paint.color)},'
    'vertices=${path.computeMetrics().length})',
  );

  @override
  void drawRect(Rect rect, Paint paint) => ops.add(
    'drawRect(style=${paint.style.name},color=${_color(paint.color)})',
  );

  @override
  void drawRRect(RRect rrect, Paint paint) => ops.add(
    'drawRRect(style=${paint.style.name},color=${_color(paint.color)},'
    'rect=${rrect.outerRect.left.toStringAsFixed(1)}'
    '..${rrect.outerRect.right.toStringAsFixed(1)})',
  );

  @override
  void drawOval(Rect rect, Paint paint) => ops.add(
    'drawOval(style=${paint.style.name},color=${_color(paint.color)})',
  );

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      ops.add('drawLine(style=${paint.style.name})');

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => ops.add(
    'drawParagraph(at=${offset.dx.toStringAsFixed(1)},'
    '${offset.dy.toStringAsFixed(1)})',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    ops.add(invocation.memberName.toString());
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pixel golden (export pipeline)', () {
    test('exported element scene is pixel-stable', () async {
      final bytes = await const BoardExportServiceImpl().renderToPng(
        paintGoldenScene(),
        scale: 1.0,
        exportBounds: Rect.fromLTWH(
          0,
          0,
          paintGoldenSceneSize.width,
          paintGoldenSceneSize.height,
        ),
        includePattern: false,
      );

      expect(bytes, isNotEmpty);

      // The image element must show its decoded pixels, not the placeholder:
      // a solid #FF2D55 block roughly spanning the element.
      final block = await measureColorBlockInPng(
        bytes,
        paintGoldenImageColor,
      );
      expectImageColorBlock(block, side: paintGoldenImageSide);

      expect(_digest(bytes), _expectedDigest);
    });

    // Guards the digest above against quiet regeneration: if a paint branch
    // stopped drawing (a dropped dispatch case, an element skipped in the
    // loop), this fails before anyone reaches for `--update-goldens`.
    test('ablating any single element changes the exported bytes', () async {
      final scene = paintGoldenScene();
      final bounds = Rect.fromLTWH(
        0,
        0,
        paintGoldenSceneSize.width,
        paintGoldenSceneSize.height,
      );

      Future<String> digestOf(List<CanvasElement> elements) async {
        final bytes = await const BoardExportServiceImpl().renderToPng(
          elements,
          scale: 1.0,
          exportBounds: bounds,
          includePattern: false,
        );
        return _digest(bytes);
      }

      final fullDigest = await digestOf(scene);
      expect(fullDigest, _expectedDigest, reason: 'ablated scene baseline');

      for (final element in scene) {
        final without = scene
            .where((candidate) => candidate.id != element.id)
            .toList(growable: false);

        // A duplicated id would ablate two elements at once and hide the one
        // this iteration is meant to prove.
        expect(
          without,
          hasLength(scene.length - 1),
          reason: 'element ids must be unique; "${element.id}" is repeated',
        );

        expect(
          await digestOf(without),
          isNot(fullDigest),
          reason:
              'removing "${element.id}" left the export byte-identical, so its '
              'paint branch contributes no pixels and could disappear without '
              'failing anything',
        );
      }
    });

    test('renderToPng is deterministic across runs', () async {
      final bounds = Rect.fromLTWH(
        0,
        0,
        paintGoldenSceneSize.width,
        paintGoldenSceneSize.height,
      );
      final a = await const BoardExportServiceImpl().renderToPng(
        paintGoldenScene(),
        scale: 1.0,
        exportBounds: bounds,
        includePattern: false,
      );
      final b = await const BoardExportServiceImpl().renderToPng(
        paintGoldenScene(),
        scale: 1.0,
        exportBounds: bounds,
        includePattern: false,
      );
      expect(_digest(a), _digest(b));
    });
  });

  group('paintStrokeFill', () {
    const fill = Color(0xFFFFB020);

    test('fills the closed polygon with opacity-scaled alpha', () {
      final canvas = _RecordingCanvas();
      paintStrokeFill(
        canvas: canvas,
        points: const [Offset(0, 0), Offset(10, 0), Offset(5, 8)],
        fillColor: fill,
        opacity: 0.5,
      );

      expect(canvas.ops, hasLength(1));
      final expectedAlpha = (0.5 * fill.a).clamp(0.0, 1.0);
      expect(
        canvas.ops.single,
        'drawPath(style=fill,'
        'color=${(fill.withValues(alpha: expectedAlpha)).toARGB32().toRadixString(16).padLeft(8, '0')},'
        'vertices=1)',
      );
    });

    test('draws nothing for a two-point path', () {
      final canvas = _RecordingCanvas();
      paintStrokeFill(
        canvas: canvas,
        points: const [Offset(0, 0), Offset(10, 10)],
        fillColor: fill,
        opacity: 1,
      );
      expect(canvas.ops, isEmpty);
    });

    test('draws nothing when the stroke has no fill colour', () {
      final canvas = _RecordingCanvas();
      paintStrokeFill(
        canvas: canvas,
        points: const [Offset(0, 0), Offset(10, 0), Offset(5, 8)],
        fillColor: null,
        opacity: 1,
      );
      expect(canvas.ops, isEmpty);
    });
  });

  test('paintShapeElement renders an unfilled square as a stroked path', () {
    final canvas = _RecordingCanvas();
    paintShapeElement(
      canvas,
      const ShapeElement(
        id: 's',
        z: 1,
        shapeType: CanvasShapeType.square,
        center: Offset(50, 50),
        size: 40,
        color: Color(0xFFE0245E),
        strokeWidth: 4,
        isFilled: false,
      ),
    );
    expect(canvas.ops, [
      'save',
      'translate(50.00,50.00)',
      startsWith('drawPath(style=stroke,color=ffe0245e'),
      'restore',
    ]);
  });

  group('paintTextLayoutBox', () {
    CanvasTextLayout layout() => CanvasTextLayout.layout(
      text: 'Ink',
      fontSize: 22,
      maxWidth: 90,
      color: const Color(0xFF101828),
    );

    test('rotates about the box centre, paints the plate, then the glyphs', () {
      final l = layout();
      final canvas = _RecordingCanvas();
      paintTextLayoutBox(
        canvas,
        layout: l,
        box: const Rect.fromLTWH(20, 105, 90, 40),
        rotation: 0.2,
        background: const Color(0xFFE8ECF2),
        backgroundPadding: 5,
      );
      l.dispose();

      expect(canvas.ops, [
        'save',
        'translate(65.00,125.00)',
        'rotate(0.200)',
        'translate(-65.00,-125.00)',
        'drawRRect(style=fill,color=ffe8ecf2,rect=15.0..115.0)',
        startsWith('drawParagraph(at=20.0,105.0)'),
        'restore',
      ]);
    });

    test('skips rotation maths and the plate when absent', () {
      final l = layout();
      final canvas = _RecordingCanvas();
      paintTextLayoutBox(
        canvas,
        layout: l,
        box: const Rect.fromLTWH(0, 0, 90, 30),
        rotation: 0,
        backgroundPadding: 4,
      );
      l.dispose();

      expect(canvas.ops, [
        'save',
        startsWith('drawParagraph(at=0.0,0.0)'),
        'restore',
      ]);
    });
  });
}
