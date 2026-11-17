import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/services/canvas/board_export_service.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

// 1x1 PNGs in base64 (different pixels, so they are distinguishable).
const _thumbnailBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
const _fullBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

const _url = 'https://cdn.example.test/ai-images/board1/gen1.png';

const _plainImage = ImageElement(
  id: 'plain',
  z: 0,
  center: Offset(100, 100),
  width: 80,
  height: 60,
  imageBase64: _thumbnailBase64,
);

const _aiImage = ImageElement(
  id: 'ai',
  z: 1,
  center: Offset(300, 100),
  width: 80,
  height: 80,
  imageBase64: _thumbnailBase64,
  imageUrl: _url,
  aiPrompt: 'a red fox',
  generationId: 'gen1',
);

const _shape = ShapeElement(
  id: 'shape',
  z: 2,
  shapeType: CanvasShapeType.rectangle,
  center: Offset(200, 300),
  size: 120,
  color: Colors.blue,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export of boards WITHOUT AI images is unchanged', () {
    test('the element list is returned untouched and nothing is downloaded', () async {
      var downloads = 0;
      final service = BoardExportServiceImpl(
        imageDownloader: (url) async {
          downloads += 1;
          return Uint8List(0);
        },
      );
      final elements = <CanvasElement>[_plainImage, _shape];

      final resolved = await service.resolveExportElements(elements);

      expect(identical(resolved, elements), isTrue);
      expect(downloads, 0);
    });

    test('SVG output is identical with and without the new code path', () async {
      final elements = <CanvasElement>[_plainImage, _shape];
      const plainService = BoardExportServiceImpl();
      final withDownloader = BoardExportServiceImpl(
        imageDownloader: (url) async => base64Decode(_fullBase64),
      );

      final before = plainService.renderToSvg('Board', elements);
      final after = withDownloader.renderToSvg(
        'Board',
        await withDownloader.resolveExportElements(elements),
      );

      expect(after, before);
      expect(after, contains('href="data:image/png;base64,$_thumbnailBase64"'));
    });
  });

  group('export of AI images', () {
    test('uses the full image from the URL; other elements are untouched', () async {
      final requested = <Uri>[];
      final service = BoardExportServiceImpl(
        imageDownloader: (url) async {
          requested.add(url);
          return base64Decode(_fullBase64);
        },
      );
      final elements = <CanvasElement>[_plainImage, _aiImage, _shape];

      final resolved = await service.resolveExportElements(elements);

      expect(requested, [Uri.parse(_url)]);
      expect(resolved, hasLength(3));
      expect(identical(resolved[0], _plainImage), isTrue);
      expect(identical(resolved[2], _shape), isTrue);

      final exported = resolved[1] as ImageElement;
      expect(exported.imageBase64, _fullBase64);
      expect(exported.id, _aiImage.id);
      expect(exported.center, _aiImage.center);
      expect(exported.width, _aiImage.width);
      expect(exported.height, _aiImage.height);
      // The board's own element is not modified.
      expect(_aiImage.imageBase64, _thumbnailBase64);
      expect(elements[1], _aiImage);

      final svg = service.renderToSvg('Board', resolved);
      expect(svg, contains('href="data:image/png;base64,$_fullBase64"'));
      expect(svg, contains('href="data:image/png;base64,$_thumbnailBase64"'));

      final png = await service.renderToPng(resolved);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final pdf = await service.renderToPdf('Board', resolved);
      expect(pdf.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('falls back to the inline thumbnail when the download fails', () async {
      final service = BoardExportServiceImpl(
        imageDownloader: (url) async => throw Exception('offline'),
      );

      final resolved = await service.resolveExportElements(<CanvasElement>[_aiImage]);

      expect(identical(resolved.single, _aiImage), isTrue);
      final svg = service.renderToSvg('Board', resolved);
      expect(svg, contains('href="data:image/png;base64,$_thumbnailBase64"'));
    });

    test('falls back to the thumbnail for an empty download or a non-http address', () async {
      var downloads = 0;
      final service = BoardExportServiceImpl(
        imageDownloader: (url) async {
          downloads += 1;
          return Uint8List(0);
        },
      );
      const odd = ImageElement(
        id: 'odd',
        z: 0,
        center: Offset.zero,
        imageBase64: _thumbnailBase64,
        imageUrl: 'file:///etc/passwd',
      );

      final resolved = await service.resolveExportElements(<CanvasElement>[_aiImage, odd]);

      expect((resolved[0] as ImageElement).imageBase64, _thumbnailBase64);
      expect((resolved[1] as ImageElement).imageBase64, _thumbnailBase64);
      expect(downloads, 1, reason: 'the file: address is never fetched');
    });

    test('the same URL used twice is downloaded once', () async {
      var downloads = 0;
      final service = BoardExportServiceImpl(
        imageDownloader: (url) async {
          downloads += 1;
          return base64Decode(_fullBase64);
        },
      );
      const copy = ImageElement(
        id: 'ai-copy',
        z: 3,
        center: Offset(500, 100),
        imageBase64: _thumbnailBase64,
        imageUrl: _url,
      );

      final resolved = await service.resolveExportElements(<CanvasElement>[_aiImage, copy]);

      expect(downloads, 1);
      expect(resolved.whereType<ImageElement>().every((e) => e.imageBase64 == _fullBase64), isTrue);
    });
  });
}
