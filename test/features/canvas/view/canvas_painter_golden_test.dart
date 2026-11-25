import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../canvas_render_test_harness.dart';
import '../paint_golden_pixels.dart';
import '../paint_golden_scene.dart';

/// Widget-level raster check for the INTERACTIVE canvas render path.
///
/// `paint_parity_test.dart` covers the export pipeline; this covers the painter
/// the screen actually uses (`_CanvasPainter`). It pumps the real `CanvasScreen`
/// with the shared scene, takes the painter instance the screen built (so the
/// real element mapping and viewport are involved), then re-hosts that painter
/// in a chrome-free tree for a deterministic capture — the surrounding app
/// chrome pulls GoogleFonts, which attempts a network fetch and makes the
/// capture non-hermetic.
///
/// The scene (see `paint_golden_scene.dart`) covers stroke, shape, text,
/// connector, frame, sticky note, image and table. Rather than pinning raw
/// pixels (which differ by platform because text falls back to different
/// fonts), the capture is checked for the signature colour of every opaque
/// element, plus the decoded image's solid block.
///
/// The image element needs special care: the screen decodes base64 off the fake
/// clock, so this test lets real async run until the decode lands before it
/// captures. Without that, the painter only ever receives a null entry and
/// draws its placeholder, and the pixel assertion is what makes that
/// distinction visible.
///
/// Differences that the two render paths preserve on purpose — and the ones
/// that were resolved — are catalogued in `docs/canvas/paint-parity.md`.
const _captureKey = ValueKey('canvas-painter-capture');

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

  testWidgets(
    'interactive canvas painter renders every element type',
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      final scene = paintGoldenScene();
      final bloc = CanvasBloc(currentUserId: 'owner-1', boardId: 'board-1');
      bloc.add(
        const CanvasBoardTitleUpdated(
          'Painter golden',
          currentUserRole: Board.roleOwner,
        ),
      );
      await tester.pump();
      bloc.add(CanvasImportElements(scene.map((e) => e.toMap()).toList()));
      await tester.pump();

      tester.view.physicalSize = const Size(700, 620);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(canvasScreenHost(bloc: bloc, prefs: prefs));
      await tester.pump();
      if (bloc.state.isLoading) {
        await tester.runAsync(
          () => bloc.stream.firstWhere((s) => !s.isLoading),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));

      // Image elements are decoded off the fake clock: `_decodeUiImage` awaits
      // `instantiateImageCodec`, then `setState`s the decoded map into the
      // painter. Without letting real async run, the painter only ever sees a
      // null entry and draws its placeholder — the capture would pin that
      // instead of the image. Give the decode the real event loop, then pump
      // so the screen rebuilds the painter with the decoded image attached.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(
        bloc.state.elements,
        hasLength(scene.length),
        reason: 'scene seeded',
      );

      // Grab the painter the screen built: it carries the real mapped elements
      // and the screen's viewport transform.
      final painterFinder = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint && '${w.painter.runtimeType}' == '_CanvasPainter',
      );
      expect(painterFinder, findsOneWidget, reason: 'interactive painter up');
      final screenPainter = tester.widget<CustomPaint>(painterFinder).painter!;

      // Re-host it without the app chrome so the capture is hermetic.
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _captureKey,
            child: CustomPaint(
              size: paintGoldenSceneSize,
              painter: screenPainter,
            ),
          ),
        ),
      );
      await tester.pump();

      // Capture the re-hosted painter once and assert on its pixels directly.
      // A checked-in golden would pin platform-specific anti-aliasing; sampling
      // the raster is also the only way to tell a decoded image from the
      // placeholder the painter falls back to when a decode has not landed.
      final captured = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_captureKey),
        );
        final image = await boundary.toImage();
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          return (
            width: image.width,
            height: image.height,
            data: data,
            imageBlock: measureColorBlock(
              data,
              image.width,
              image.height,
              paintGoldenImageColor,
            ),
          );
        } finally {
          image.dispose();
        }
      });

      expectSceneColors(
        captured!.data,
        captured.width,
        captured.height,
        paintGoldenSignatureColors,
      );
      // tolerance 8: this capture is at the screen's auto-fit zoom (~1.13x),
      // so the 60px element spans ~68px here. The paint itself agrees with the
      // exporter at 1:1 (see cross_path_equivalence_test.dart); the tolerance
      // only absorbs the viewport scale.
      expectImageColorBlock(
        captured.imageBlock,
        side: paintGoldenImageSide,
        tolerance: 8,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      bloc.close();
      await tester.pump();
    },
  );
}
