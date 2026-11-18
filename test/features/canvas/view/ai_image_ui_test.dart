import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/view/ai_repaint_screen.dart';
import 'package:inklink/features/canvas/view/trays/ai_tray.dart';
import 'package:inklink/features/canvas/view/widgets/ai_image_widgets.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/widgets/ink_button.dart';

Widget _host(Widget child, {bool dark = false}) {
  return MaterialApp(
    theme: dark ? InkTheme.dark() : InkTheme.light(),
    home: Scaffold(body: Stack(children: [child])),
  );
}

InkButton _button(WidgetTester tester, String label) {
  return tester.widget<InkButton>(
    find.byWidgetPredicate((w) => w is InkButton && w.label == label),
  );
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = (y * image.width + x) * 4;
  return [data!.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2)];
}

void main() {
  group('AITray', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Widget tray({
      AiTrayGeneration? generation,
      VoidCallback? onGenerateImage,
      List<Uint8List> recentImages = const [],
      bool dark = false,
    }) {
      return _host(
        AITray(
          isOpen: true,
          controller: controller,
          onAddText: () {},
          onGenerateImage: onGenerateImage ?? () {},
          recentImages: recentImages,
          generation: generation,
        ),
        dark: dark,
      );
    }

    AiTrayGeneration generation({
      bool canEdit = true,
      bool isGenerating = false,
      String aspectRatio = '1:1',
      ValueChanged<String>? onAspectRatioChanged,
      VoidCallback? onGenerate,
    }) {
      return AiTrayGeneration(
        canEdit: canEdit,
        isGenerating: isGenerating,
        aspectRatio: aspectRatio,
        onAspectRatioChanged: onAspectRatioChanged ?? (_) {},
        onGenerate: onGenerate ?? () {},
      );
    }

    testWidgets('flag off: shows the old "(Soon)" stub wired to the old handler', (tester) async {
      var stubTapped = 0;
      await tester.pumpWidget(tray(onGenerateImage: () => stubTapped++));
      await tester.pumpAndSettle();

      expect(find.text('Generate Image (Soon)'), findsOneWidget);
      expect(find.text('Generation integration is coming next.'), findsOneWidget);
      expect(find.text('Generate Image'), findsNothing);
      expect(find.text('16:9'), findsNothing);

      await tester.tap(find.text('Generate Image (Soon)'));
      expect(stubTapped, 1);

      // Upload Image is removed from the AI tray; Add Prompt As Text stays.
      expect(find.text('Upload Image'), findsNothing);
      expect(find.text('Recent AI Images'), findsOneWidget);
      expect(find.text('No recent AI images yet.'), findsOneWidget);
      expect(find.text('Add Prompt As Text'), findsOneWidget);
    });

    testWidgets('shows recent generated AI images below Generate Image', (tester) async {
      final png1x1 = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      await tester.pumpWidget(
        tray(generation: generation(), recentImages: [png1x1]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent AI Images'), findsOneWidget);
      expect(find.text('No recent AI images yet.'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Upload Image'), findsNothing);
    });

    testWidgets('editor: Generate is enabled once a prompt is typed', (tester) async {
      var generated = 0;
      await tester.pumpWidget(tray(generation: generation(onGenerate: () => generated++)));
      await tester.pumpAndSettle();

      expect(find.text('Generate Image (Soon)'), findsNothing);
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      expect(find.text('9:16'), findsOneWidget);
      expect(find.text('0/1000'), findsOneWidget);
      expect(_button(tester, 'Generate Image').onPressed, isNull, reason: 'empty prompt');

      controller.text = 'a red fox';
      await tester.pump();
      expect(find.text('9/1000'), findsOneWidget);
      expect(_button(tester, 'Generate Image').onPressed, isNotNull);

      await tester.tap(find.text('Generate Image'));
      expect(generated, 1);
    });

    testWidgets('editor: a prompt over 1000 characters disables Generate', (tester) async {
      await tester.pumpWidget(tray(generation: generation()));
      controller.text = 'x' * 1001;
      await tester.pump();

      expect(find.text('1001/1000'), findsOneWidget);
      expect(_button(tester, 'Generate Image').onPressed, isNull);
    });

    testWidgets('editor: picking an aspect ratio reports it', (tester) async {
      String? picked;
      await tester.pumpWidget(
        tray(generation: generation(onAspectRatioChanged: (ratio) => picked = ratio)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('16:9'));
      await tester.pumpAndSettle();
      expect(picked, '16:9');
    });

    testWidgets('viewer: controls are disabled with an explanation', (tester) async {
      var generated = 0;
      String? picked;
      await tester.pumpWidget(
        tray(
          generation: generation(
            canEdit: false,
            onGenerate: () => generated++,
            onAspectRatioChanged: (ratio) => picked = ratio,
          ),
        ),
      );
      controller.text = 'a red fox';
      await tester.pumpAndSettle();

      expect(_button(tester, 'Generate Image').onPressed, isNull);
      expect(find.text('Only editors can generate images on this board.'), findsOneWidget);

      await tester.tap(find.text('Generate Image'), warnIfMissed: false);
      await tester.tap(find.text('16:9'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(generated, 0);
      expect(picked, isNull);
    });

    testWidgets('while generating: button shows loading and is disabled', (tester) async {
      await tester.pumpWidget(tray(generation: generation(isGenerating: true)));
      controller.text = 'a red fox';
      await tester.pump();

      final button = _button(tester, 'Generating...');
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);
      expect(find.text('You can keep drawing while the image is generated.'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(tray(generation: generation(), dark: true));
      await tester.pumpAndSettle();
      expect(find.text('Generate Image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AiImageActionBar', () {
    Widget bar({
      required bool canEdit,
      bool isBusy = false,
      VoidCallback? onEdit,
      VoidCallback? onRepaint,
      VoidCallback? onRegenerate,
      bool dark = false,
    }) {
      return _host(
        Positioned(
          left: 20,
          top: 20,
          child: AiImageActionBar(
            canEdit: canEdit,
            isBusy: isBusy,
            onEditWithAi: onEdit ?? () {},
            onRepaintArea: onRepaint ?? () {},
            onRegenerate: onRegenerate ?? () {},
          ),
        ),
        dark: dark,
      );
    }

    testWidgets('editor: all three actions work', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        bar(
          canEdit: true,
          onEdit: () => tapped.add('edit'),
          onRepaint: () => tapped.add('repaint'),
          onRegenerate: () => tapped.add('regenerate'),
        ),
      );

      await tester.tap(find.text('Edit with AI'));
      await tester.tap(find.text('Repaint area'));
      await tester.tap(find.text('Regenerate'));

      expect(tapped, ['edit', 'repaint', 'regenerate']);
      expect(find.text(AiImageActionBar.viewerExplanation), findsNothing);
    });

    testWidgets('viewer: actions are disabled with an explanation', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        bar(
          canEdit: false,
          onEdit: () => tapped.add('edit'),
          onRepaint: () => tapped.add('repaint'),
          onRegenerate: () => tapped.add('regenerate'),
        ),
      );

      await tester.tap(find.text('Edit with AI'), warnIfMissed: false);
      await tester.tap(find.text('Repaint area'), warnIfMissed: false);
      await tester.tap(find.text('Regenerate'), warnIfMissed: false);

      expect(tapped, isEmpty);
      expect(find.text(AiImageActionBar.viewerExplanation), findsOneWidget);
    });

    testWidgets('busy: actions are disabled while a request runs', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(bar(canEdit: true, isBusy: true, onEdit: () => tapped++));

      await tester.tap(find.text('Edit with AI'), warnIfMissed: false);
      expect(tapped, 0);
      expect(find.text('Working on this image...'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(bar(canEdit: true, dark: true));
      expect(find.text('Regenerate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AiImagePlaceholderBox', () {
    testWidgets('shows a spinner and the prompt', (tester) async {
      await tester.pumpWidget(
        _host(
          const Positioned(
            left: 0,
            top: 0,
            width: 280,
            height: 160,
            child: AiImagePlaceholderBox(prompt: 'a red fox'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('a red fox'), findsOneWidget);
      expect(find.text('Generating image...'), findsOneWidget);
    });

    testWidgets('shrinks to just the spinner when very small', (tester) async {
      await tester.pumpWidget(
        _host(
          const Positioned(
            left: 0,
            top: 0,
            width: 60,
            height: 40,
            child: AiImagePlaceholderBox(prompt: 'a red fox'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('a red fox'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('prompt dialog', () {
    testWidgets('returns the trimmed prompt; Apply is disabled when empty', (tester) async {
      String? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAiPromptDialog(
                    context,
                    title: 'Edit with AI',
                    hintText: 'Describe the change',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(_button(tester, 'Apply').onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  make it night  ');
      await tester.pump();
      expect(_button(tester, 'Apply').onPressed, isNotNull);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, 'make it night');
    });

    testWidgets('Cancel returns null', (tester) async {
      String? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAiPromptDialog(context, title: 't', hintText: 'h');
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('repaint mask', () {
    testWidgets('mask PNG has exactly the source size; white only where painted', (tester) async {
      await tester.runAsync(() async {
        final png = await renderAiMaskPng(
          width: 320,
          height: 180,
          strokes: const [
            AiMaskStroke(points: [Offset(60, 90), Offset(140, 90)], width: 40),
            AiMaskStroke(points: [Offset(260, 40)], width: 30),
          ],
        );
        // PNG signature.
        expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);

        final image = await _decode(png);
        expect(image.width, 320);
        expect(image.height, 180);
        expect(await _pixel(image, 100, 90), [255, 255, 255], reason: 'inside the stroke');
        expect(await _pixel(image, 260, 40), [255, 255, 255], reason: 'single tap dot');
        expect(await _pixel(image, 10, 10), [0, 0, 0], reason: 'untouched area');
        expect(await _pixel(image, 100, 160), [0, 0, 0], reason: 'below the stroke');
        image.dispose();
      });
    });

    testWidgets('the eraser removes mask that was painted earlier', (tester) async {
      await tester.runAsync(() async {
        final png = await renderAiMaskPng(
          width: 200,
          height: 200,
          strokes: const [
            AiMaskStroke(points: [Offset(20, 100), Offset(180, 100)], width: 60),
            AiMaskStroke(points: [Offset(100, 60), Offset(100, 140)], width: 40, erase: true),
          ],
        );
        final image = await _decode(png);
        expect(await _pixel(image, 40, 100), [255, 255, 255]);
        expect(await _pixel(image, 100, 100), [0, 0, 0], reason: 'erased');
        image.dispose();
      });
    });

    testWidgets('an empty mask is all black', (tester) async {
      await tester.runAsync(() async {
        final png = await renderAiMaskPng(width: 64, height: 32, strokes: const []);
        final image = await _decode(png);
        expect(image.width, 64);
        expect(image.height, 32);
        expect(await _pixel(image, 32, 16), [0, 0, 0]);
        image.dispose();
      });
    });
  });

  group('AiRepaintScreen', () {
    Future<Uint8List> sourcePng() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 200, 100),
        Paint()..color = const Color(0xFF3366CC),
      );
      final image = await recorder.endRecording().toImage(200, 100);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }

    testWidgets('Repaint needs both a painted area and a prompt, then returns the mask', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(sourcePng))!;
      AiRepaintResult? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<AiRepaintResult>(
                    MaterialPageRoute(builder: (_) => AiRepaintScreen(imageBytes: bytes)),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Let the image decode on the real event loop.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      final surface = find.byKey(const ValueKey('ai-repaint-surface'));
      expect(surface, findsOneWidget);
      expect(_button(tester, 'Repaint').onPressed, isNull, reason: 'nothing painted yet');
      expect(_button(tester, 'Clear').onPressed, isNull);

      await tester.drag(surface, const Offset(60, 0));
      await tester.pump();
      expect(_button(tester, 'Repaint').onPressed, isNull, reason: 'no prompt yet');
      expect(_button(tester, 'Clear').onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), ' a tree ');
      await tester.pump();
      expect(_button(tester, 'Repaint').onPressed, isNotNull);

      await tester.tap(find.text('Repaint'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.prompt, 'a tree');
      final mask = (await tester.runAsync(() => _decode(result!.maskPng)))!;
      expect(mask.width, 200, reason: 'same pixel size as the source image');
      expect(mask.height, 100);
      // The drag started at the centre of the surface = centre of the image.
      final centre = (await tester.runAsync(() => _pixel(mask, 110, 50)))!;
      expect(centre, [255, 255, 255]);
      final corner = (await tester.runAsync(() => _pixel(mask, 2, 2)))!;
      expect(corner, [0, 0, 0]);
    });

    testWidgets('Clear removes the painted area', (tester) async {
      final bytes = (await tester.runAsync(sourcePng))!;
      await tester.pumpWidget(
        MaterialApp(theme: InkTheme.dark(), home: AiRepaintScreen(imageBytes: bytes)),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      await tester.drag(find.byKey(const ValueKey('ai-repaint-surface')), const Offset(40, 0));
      await tester.enterText(find.byType(TextField), 'a tree');
      await tester.pump();
      expect(_button(tester, 'Repaint').onPressed, isNotNull);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(_button(tester, 'Repaint').onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
