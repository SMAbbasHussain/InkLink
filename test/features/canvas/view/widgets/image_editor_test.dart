import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/media_editor_screen.dart';
import 'package:inklink/features/canvas/view/widgets/image_crop_dialog.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/ink_button.dart';

Uint8List _bytes() => Uint8List.fromList(
  img.encodePng(
    img.Image(width: 200, height: 100)..clear(img.ColorRgb8(255, 0, 0)),
  ),
);

void _size(WidgetTester tester, [Size size = const Size(800, 900)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ui.Image> _decoded(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(_bytes());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }))!;
}

Future<void> _crop(
  WidgetTester tester,
  ui.Image image,
  ValueChanged<Rect?> result, {
  Rect initial = ImageElement.fullCrop,
  bool flipH = false,
  bool flipV = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: InkTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open'),
            onPressed: () async => result(
              await showImageCropDialog(
                context,
                image: image,
                initialCrop: initial,
                flipH: flipH,
                flipV: flipV,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Given crop presets, When square is applied, Then source pixel aspect is square',
    (tester) async {
      _size(tester);
      final image = await _decoded(tester);
      addTearDown(image.dispose);
      Rect? result;
      await _crop(tester, image, (r) => result = r);
      await tester.tap(find.byKey(const Key('image-crop-aspect-1:1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image-crop-apply')));
      await tester.pumpAndSettle();
      expect(result, const Rect.fromLTRB(0.25, 0, 0.75, 1));
    },
  );

  testWidgets(
    'Given both mirrors, When crop moves, Then result maps back to source pixels',
    (tester) async {
      _size(tester);
      final image = await _decoded(tester);
      addTearDown(image.dispose);
      Rect? result;
      await _crop(
        tester,
        image,
        (r) => result = r,
        initial: const Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
        flipH: true,
        flipV: true,
      );
      final area = find.byKey(const Key('image-crop-area'));
      final size = tester.getSize(area);
      final gesture = await tester.startGesture(tester.getCenter(area));
      await gesture.moveBy(const Offset(22, 0));
      await gesture.moveBy(Offset(size.width * 0.1, size.height * 0.1));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const Key('image-crop-apply')));
      await tester.pumpAndSettle();
      expect(result!.left, lessThan(0.25));
      expect(result!.top, lessThan(0.25));
      expect(result!.width, closeTo(0.5, 1e-6));
      expect(result!.height, closeTo(0.5, 1e-6));
    },
  );

  testWidgets(
    'Given a corner drag, When resized past source edge, Then crop remains bounded',
    (tester) async {
      _size(tester);
      final image = await _decoded(tester);
      addTearDown(image.dispose);
      Rect? result;
      await _crop(tester, image, (r) => result = r);
      final box = tester.getRect(find.byKey(const Key('image-crop-area')));
      final gesture = await tester.startGesture(
        box.topLeft + const Offset(2, 2),
      );
      await gesture.moveBy(const Offset(22, 22));
      await gesture.moveBy(Offset(box.width * 0.35, box.height * 0.25));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const Key('image-crop-apply')));
      await tester.pumpAndSettle();
      expect(result!.left, greaterThan(0.3));
      expect(result!.top, greaterThan(0.2));
      expect(result!.right, 1);
      expect(result!.bottom, 1);
    },
  );

  testWidgets(
    'Given a short mobile viewport, When reset or cancel is used, Then no crop leaks or overflow occurs',
    (tester) async {
      _size(tester, const Size(390, 360));
      final image = await _decoded(tester);
      addTearDown(image.dispose);
      Rect? result;
      await _crop(
        tester,
        image,
        (r) => result = r,
        initial: const Rect.fromLTRB(0.25, 0, 0.75, 1),
      );
      await tester.tap(find.byKey(const Key('image-crop-reset')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('image-crop-apply')));
      await tester.pumpAndSettle();
      expect(result, ImageElement.fullCrop);
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image-crop-cancel')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Given the media editor, When crop and flips are saved, Then source bytes and metadata are returned separately',
    (tester) async {
      _size(tester, const Size(390, 844));
      final bytes = _bytes();
      MediaEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () async {
                  result = await Navigator.of(context).push<MediaEditorResult>(
                    MaterialPageRoute(
                      builder: (_) => MediaEditorScreen(imageBytes: bytes),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.runAsync(() async {
        final timer = Stopwatch()..start();
        do {
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>(() {});
        } while ((find
                    .byKey(const Key('image-editor-done'))
                    .evaluate()
                    .isEmpty ||
                tester
                        .widget<InkButton>(
                          find.byKey(const Key('image-editor-done')),
                        )
                        .onPressed ==
                    null) &&
            timer.elapsed < const Duration(seconds: 3));
      });
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Flip vertical'));
      await tester.tap(find.byTooltip('Flip horizontal'));
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.tap(find.byTooltip('Crop'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image-crop-aspect-1:1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('image-crop-apply')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('image-editor-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('image-editor-done')));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.style.flipped, isTrue);
      expect(result!.style.flipV, isTrue);
      expect(result!.style.rotation, closeTo(1.57079632679, 1e-9));
      expect(result!.style.crop, const Rect.fromLTRB(0.25, 0, 0.75, 1));
      final decoded = img.decodeImage(result!.imageBytes)!;
      expect(decoded.width, 200);
      expect(decoded.height, 100);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Given invalid external bytes, Then decode error replaces loading and save stays disabled',
    (tester) async {
      _size(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: MediaEditorScreen(imageBytes: Uint8List.fromList([1, 2, 3])),
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpAndSettle();
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Could not decode image. Choose a different file.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<InkButton>(find.byKey(const Key('image-editor-done')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
