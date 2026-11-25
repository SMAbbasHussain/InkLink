import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a set of pixels matching an expected colour landed in a buffer.
class SolidBlock {
  const SolidBlock({required this.pixels, required this.bounds});

  /// Number of pixels matching the expected colour.
  final int pixels;

  /// Bounding box of those pixels, in buffer coordinates.
  final Rect bounds;

  @override
  String toString() =>
      'SolidBlock(pixels=$pixels, '
      'bounds=${bounds.left.toStringAsFixed(1)},'
      '${bounds.top.toStringAsFixed(1)} '
      '${bounds.width.toStringAsFixed(1)}x${bounds.height.toStringAsFixed(1)})';
}

/// [er]/[eg]/[eb] are the expected channel values, resolved once per scan.
bool _matches(ByteData rgba, int index, int er, int eg, int eb, int tol) {
  if (rgba.getUint8(index + 3) < 250) return false;
  return (rgba.getUint8(index) - er).abs() <= tol &&
      (rgba.getUint8(index + 1) - eg).abs() <= tol &&
      (rgba.getUint8(index + 2) - eb).abs() <= tol;
}

/// Counts pixels matching [expected] and returns their bounding box.
///
/// Used to prove that a decoded image actually reached the raster: a
/// placeholder box or a blank region yields far fewer matches than the real
/// pixels do, so the assertion fails instead of the golden silently pinning a
/// fallback.
SolidBlock measureColorBlock(
  ByteData rgba,
  int width,
  int height,
  Color expected, {
  int tolerance = 8,
}) {
  final er = (expected.r * 255).round();
  final eg = (expected.g * 255).round();
  final eb = (expected.b * 255).round();
  var count = 0;
  var minX = width, minY = height, maxX = -1, maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!_matches(rgba, (y * width + x) * 4, er, eg, eb, tolerance)) {
        continue;
      }
      count++;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  return SolidBlock(
    pixels: count,
    bounds: count == 0
        ? Rect.zero
        : Rect.fromLTRB(
            minX.toDouble(),
            minY.toDouble(),
            (maxX + 1).toDouble(),
            (maxY + 1).toDouble(),
          ),
  );
}

/// Decodes [png] and measures [expected] within it.
Future<SolidBlock> measureColorBlockInPng(Uint8List png, Color expected) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final block = measureColorBlock(
    data!,
    image.width,
    image.height,
    expected,
  );
  image.dispose();
  codec.dispose();
  return block;
}

/// Asserts that a decoded image really painted: enough pixels match the
/// expected colour, and they cover roughly the element's area.
///
/// [tolerance] exists for rasters captured under the screen's viewport zoom
/// rather than at 1:1: the interactive golden is captured at the canvas fit
/// scale (~1.13x), where a 60px element spans ~68px. At 1:1 the two paths are
/// pixel-identical — `cross_path_equivalence_test.dart` proves that — so a
/// widened tolerance here only absorbs the zoom.
void expectImageColorBlock(
  SolidBlock block, {
  required double side,
  double tolerance = 2,
}) {
  expect(
    block.pixels,
    greaterThan((side * side * 0.9).round()),
    reason:
        'expected ~${(side * side).round()} px of the image colour, got $block',
  );
  expect(
    block.bounds.width,
    closeTo(side, tolerance),
    reason: 'image width should span the element, got $block',
  );
  expect(
    block.bounds.height,
    closeTo(side, tolerance),
    reason: 'image height should span the element, got $block',
  );
}
