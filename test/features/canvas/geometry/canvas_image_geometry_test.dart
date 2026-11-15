import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

const _image = ImageElement(
  id: 'image',
  z: 3,
  center: Offset(100, 100),
  width: 200,
  height: 100,
  imageBase64: 'original',
);

Future<ui.Image> _quadrants() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (final (rect, color) in const [
    (Rect.fromLTWH(0, 0, 50, 50), Color(0xFFFF0000)),
    (Rect.fromLTWH(50, 0, 50, 50), Color(0xFF00FF00)),
    (Rect.fromLTWH(0, 50, 50, 50), Color(0xFF0000FF)),
    (Rect.fromLTWH(50, 50, 50, 50), Color(0xFFFFFFFF)),
  ]) {
    canvas.drawRect(rect, Paint()..color = color);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  picture.dispose();
  return image;
}

Future<List<int>> _pixel(ImageElement style, int x, int y) async {
  final source = await _quadrants();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintImageElement(canvas, style, source);
  final picture = recorder.endRecording();
  final output = await picture.toImage(100, 100);
  final rgba = (await output.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final offset = (y * 100 + x) * 4;
  final result = [for (var i = 0; i < 4; i++) rgba.getUint8(offset + i)];
  source.dispose();
  output.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('image metadata', () {
    test('legacy image defaults remain full, unfiltered and rounded', () {
      final restored =
          CanvasElement.fromMap(_image.id, {
                'type': 'image',
                'cx': 100,
                'cy': 100,
                'width': 200,
                'height': 100,
              })
              as ImageElement;
      expect(restored.crop, ImageElement.fullCrop);
      expect(restored.borderRadius, 8);
      expect(restored.borderWidth, 0);
      expect(restored.flipV, isFalse);
      expect(restored.isReference, isFalse);
      expect(restored.hasFilters, isFalse);
    });
    test(
      'every image style field round-trips and participates in equality',
      () {
        final styled = _image.copyWith(
          opacity: 0.6,
          rotation: math.pi / 2,
          flipped: true,
          flipV: true,
          crop: const Rect.fromLTRB(0.1, 0.2, 0.8, 0.9),
          borderRadius: 20,
          borderWidth: 4,
          borderColor: const Color(0xFFFF9800),
          brightness: 0.3,
          contrast: -0.2,
          saturation: -0.6,
          isReference: true,
          locked: true,
        );
        final restored = CanvasElement.fromMap(styled.id, styled.toMap());
        expect(restored, styled);
        expect(restored.hashCode, styled.hashCode);
        expect(styled.copyWith(flipV: false), isNot(styled));
        expect(styled.copyWith(saturation: 0), isNot(styled));
        expect(styled.copyWith(crop: ImageElement.fullCrop), isNot(styled));
        expect((restored as ImageElement).imageBase64, 'original');
      },
    );
    test('malformed and non-finite crop payloads fall back safely', () {
      for (final crop in [
        {'cropL': 0.8, 'cropR': 0.2},
        {'cropL': double.nan, 'cropT': double.infinity},
      ]) {
        final restored =
            CanvasElement.fromMap('image', {..._image.toMap(), ...crop})
                as ImageElement;
        expect(restored.crop, ImageElement.fullCrop);
      }
    });
  });
  group('non-destructive crop math', () {
    test('crop shrinks the box while retaining the same pixel positions', () {
      final cropped = applyImageCrop(
        _image,
        const Rect.fromLTRB(0.5, 0.25, 1, 0.75),
      );
      expect(cropped.width, 100);
      expect(cropped.height, 50);
      expect(cropped.center, const Offset(150, 100));
      expect(cropped.imageBase64, _image.imageBase64);
      expect(applyImageCrop(cropped, ImageElement.fullCrop), _image);
    });
    test('crop shift follows rotation and both local flips', () {
      final original = _image.copyWith(
        rotation: math.pi / 2,
        flipped: true,
        flipV: true,
      );
      final cropped = applyImageCrop(
        original,
        const Rect.fromLTRB(0.5, 0.5, 1, 1),
      );
      expect(cropped.center.dx, closeTo(125, 1e-9));
      expect(cropped.center.dy, closeTo(50, 1e-9));
      final reset = applyImageCrop(cropped, ImageElement.fullCrop);
      expect(reset.center.dx, closeTo(original.center.dx, 1e-9));
      expect(reset.center.dy, closeTo(original.center.dy, 1e-9));
      expect(reset.width, original.width);
      expect(reset.height, original.height);
    });
    test('crop is bounded and cannot be degenerate', () {
      final crop = clampImageCrop(const Rect.fromLTRB(2, -3, -1, -2));
      expect(crop.left, closeTo(0.98, 1e-9));
      expect(crop.width, closeTo(kMinImageCropFraction, 1e-9));
      expect(crop.top, 0);
      expect(crop.height, closeTo(kMinImageCropFraction, 1e-9));
    });
    test('source rect uses decoded pixel dimensions', () {
      expect(
        imageCropSourceRect(
          const Rect.fromLTRB(0.25, 0.1, 0.75, 0.9),
          const Size(400, 200),
        ),
        const Rect.fromLTRB(100, 20, 300, 180),
      );
    });
  });
  group('image filter matrix', () {
    test('neutral matrix is identity and leaves alpha unchanged', () {
      expect(imageColorMatrix(), [
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    });
    test('desaturation uses luminance in all RGB channels', () {
      final matrix = imageColorMatrix(saturation: -1);
      for (final row in [0, 5, 10]) {
        expect(matrix.sublist(row, row + 3), [0.2126, 0.7152, 0.0722]);
      }
    });
    test('brightness and contrast offsets share the midpoint convention', () {
      final matrix = imageColorMatrix(brightness: 0.5, contrast: 0.5);
      expect(matrix[0], 1.5);
      expect(matrix[4], 0);
      expect(matrix[19], 0);
    });
  });
  group('shared image painter pixels', () {
    const style = ImageElement(
      id: 'pixels',
      z: 0,
      center: Offset(50, 50),
      width: 100,
      height: 100,
      borderRadius: 0,
    );
    test(
      'horizontal and vertical mirrors select the expected quadrant',
      () async {
        expect(await _pixel(style, 25, 25), [255, 0, 0, 255]);
        expect(await _pixel(style.copyWith(flipped: true), 25, 25), [
          0,
          255,
          0,
          255,
        ]);
        expect(await _pixel(style.copyWith(flipV: true), 25, 25), [
          0,
          0,
          255,
          255,
        ]);
        expect(
          await _pixel(style.copyWith(flipped: true, flipV: true), 25, 25),
          [255, 255, 255, 255],
        );
      },
    );
    test('crop selects only source pixels in the visible rectangle', () async {
      expect(
        await _pixel(
          style.copyWith(crop: const Rect.fromLTRB(0.5, 0, 1, 1)),
          25,
          25,
        ),
        [0, 255, 0, 255],
      );
    });
    test('rotation, rounded clipping and grayscale are rendered', () async {
      expect(await _pixel(style.copyWith(rotation: math.pi / 2), 25, 25), [
        0,
        0,
        255,
        255,
      ]);
      expect((await _pixel(style.copyWith(borderRadius: 50), 1, 1))[3], 0);
      final gray = await _pixel(style.copyWith(saturation: -1), 25, 25);
      expect(gray[0], closeTo(54, 1));
      expect(gray[1], gray[0]);
      expect(gray[2], gray[0]);
    });
    test('reference fade applies to both pixels and borders', () async {
      final faded = style.copyWith(
        isReference: true,
        borderWidth: 10,
        borderColor: Colors.black,
      );
      expect((await _pixel(faded, 25, 25))[3], closeTo(102, 1));
      expect((await _pixel(faded, 3, 25))[3], closeTo(102, 1));
    });
  });
}
