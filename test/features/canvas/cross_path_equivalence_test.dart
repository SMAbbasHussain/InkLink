import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'canvas_render_test_harness.dart';
import 'paint_golden_scene.dart';

/// Cross-path equivalence: the exporter and the interactive painter must
/// rasterize each element type to the same pixels.
///
/// The two goldens (`paint_parity_test.dart` and
/// `view/canvas_painter_golden_test.dart`) only prove each path is stable on
/// its own. They share a scene, but nothing compares their output, so a shared
/// helper could drift on one side without either golden noticing. This test
/// compares them byte for byte.
///
/// Each element of the shared scene is rendered alone, by both paths, into the
/// same world rectangle at the same 1:1 scale:
///
/// * export: `BoardExportServiceImpl.renderToPng` with `exportBounds` set to
///   the padded element bounds and `scale: 1`, which translates that rectangle
///   onto the raster.
/// * interactive: the painter the real `CanvasScreen` builds for that element,
///   painted directly into a picture recorder instead of captured from the
///   widget tree. Painting it directly keeps floating app chrome (toolbars,
///   selection overlays, the eraser preview) out of the comparison.
///
/// The two rasters line up because of how the screen sizes its viewport: it
/// auto-fits content into the canvas with [_fitPadding] of padding
/// (`_calculateFittedTransform`), so a viewport exactly the size of the padded
/// element bounds makes that fit scale 1 with the padded bounds' top-left at
/// the canvas origin — the same transform the exporter applies.
///
/// Everything here is compared exactly (zero differing pixels). These paths
/// share their painters, so any difference is a real one; nothing is
/// normalized away. The catalogue of differences that are preserved on purpose
/// — and the ones this work resolved — lives in
/// `docs/canvas/paint-parity.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    HttpOverrides.global = PendingFontHttpOverrides();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  for (final element in paintGoldenScene()) {
    testWidgets(
      '${element.id} rasterizes identically through export and canvas',
      timeout: const Timeout(Duration(seconds: 60)),
      (tester) async {
        // Import round-trips the payload, exactly what the screen will map and
        // paint; the viewport has to be sized from the geometry both paths see.
        final roundTripped = CanvasElement.fromMap(element.id, element.toMap());
        final bounds = elementBounds(roundTripped, padding: 8);
        expect(bounds, isNotNull, reason: '${element.id} must have paint bounds');
        final padded = bounds!.inflate(_fitPadding);

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = padded.size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final bloc = CanvasBloc(currentUserId: 'owner-1', boardId: 'board-1');
        bloc.add(
          const CanvasBoardTitleUpdated(
            'Cross-path equivalence',
            currentUserRole: Board.roleOwner,
          ),
        );
        await tester.pump();
        bloc.add(CanvasImportElements([element.toMap()]));
        await tester.pump();
        // Import selects what it created, and a selection highlight is chrome
        // drawn around the element. Clearing it gives the same unselected
        // board the exporter is asked to render.
        bloc.add(const CanvasSelectShape(null));
        await tester.pump();

        await tester.pumpWidget(canvasScreenHost(bloc: bloc, prefs: prefs));
        await tester.pump();
        for (var i = 0; i < 40 && bloc.state.isLoading; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        if (roundTripped is ImageElement) {
          // Image elements are decoded off the fake clock; let real async run
          // until the decode lands, otherwise the painter only sees a null
          // entry and paints its placeholder.
          for (var i = 0; i < 10; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump();
          }
        }

        expect(
          _unexpectedException(tester),
          isNull,
          reason: '${element.id} threw while the screen painted it',
        );
        expect(
          bloc.state.selectedIds,
          isEmpty,
          reason: 'selection chrome must not be part of the comparison',
        );

        final paintable = bloc.state.elements;
        expect(paintable, hasLength(1), reason: '${element.id} was imported');
        final painter = _screenPainter(tester);

        final interactive = await tester.runAsync(
          () => _rasterize(painter, padded.size),
        );
        final exportedPng = await tester.runAsync(
          () => const BoardExportServiceImpl().renderToPng(
            paintable,
            scale: 1.0,
            exportBounds: padded,
            includePattern: false,
          ),
        );
        final exported = await tester.runAsync(() => _decodePng(exportedPng!));

        _expectIdenticalPixels(interactive!, exported!, id: element.id);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        bloc.close();
        await tester.pump();
      },
    );
  }
}

/// Padding the screen adds around content when it auto-fits the viewport
/// (`_calculateFittedTransform`).
const double _fitPadding = 64;

/// The first exception that is not a chrome layout overflow.
///
/// The viewport is deliberately the element's padded bounds, which is far
/// smaller than the app chrome is designed for, so the toolbars overflow. That
/// is a layout complaint about widgets this test never reads (the painter is
/// painted directly), not a painting failure.
Object? _unexpectedException(WidgetTester tester) {
  Object? unexpected;
  for (var error = tester.takeException();
      error != null;
      error = tester.takeException()) {
    final message = error is FlutterError ? error.message : '$error';
    if (message.contains('overflowed')) continue;
    unexpected ??= error;
  }
  return unexpected;
}

/// The canvas painter the real screen built for the current frame.
CustomPainter _screenPainter(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (w) => w is CustomPaint && '${w.painter.runtimeType}' == '_CanvasPainter',
  );
  expect(finder, findsOneWidget, reason: 'the screen must build its painter');
  return tester.widget<CustomPaint>(finder).painter!;
}

class _Raster {
  const _Raster({required this.width, required this.height, required this.rgba});

  final int width;
  final int height;
  final ByteData rgba;
}

/// Paints [painter] into a fresh raster at 1:1, chrome-free.
Future<_Raster> _rasterize(CustomPainter painter, Size logicalSize) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), logicalSize);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    math.max(1, logicalSize.width.ceil()),
    math.max(1, logicalSize.height.ceil()),
  );
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return _Raster(width: image.width, height: image.height, rgba: data);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<_Raster> _decodePng(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return _Raster(width: image.width, height: image.height, rgba: data);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

void _expectIdenticalPixels(
  _Raster interactive,
  _Raster exported, {
  required String id,
}) {
  expect(interactive.width, exported.width, reason: '$id: raster width');
  expect(interactive.height, exported.height, reason: '$id: raster height');

  var differing = 0;
  var maxDelta = 0;
  var firstX = -1;
  var firstY = -1;
  for (var y = 0; y < interactive.height; y++) {
    for (var x = 0; x < interactive.width; x++) {
      final offset = (y * interactive.width + x) * 4;
      var delta = 0;
      for (var channel = 0; channel < 4; channel++) {
        delta = math.max(
          delta,
          (interactive.rgba.getUint8(offset + channel) -
                  exported.rgba.getUint8(offset + channel))
              .abs(),
        );
      }
      if (delta == 0) continue;
      differing++;
      maxDelta = math.max(maxDelta, delta);
      if (firstX < 0) {
        firstX = x;
        firstY = y;
      }
    }
  }

  expect(
    differing,
    0,
    reason:
        '$id: $differing pixel(s) differ between the interactive painter and '
        'the exporter (max channel delta $maxDelta, first at $firstX,$firstY)',
  );
}
