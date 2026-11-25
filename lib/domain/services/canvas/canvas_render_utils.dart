import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Path, TextStyle;

import 'canvas_geometry.dart';

/// A resampled point along a brush stroke polyline, with interpolated
/// position, radius, opacity, and pressure.
class ResampledStrokePoint {
  final Offset position;
  final double radius;
  final double opacity;
  final double pressure;

  const ResampledStrokePoint({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.pressure,
  });
}

/// A lightweight, deterministic pseudo-random number generator for
/// texture and grain jitter. Produces the exact same sequence for a given seed.
class DeterministicBrushRandom {
  int _state;

  DeterministicBrushRandom(int seed)
      : _state = seed == 0 ? 0x12345678 : (seed & 0x7FFFFFFF);

  /// Returns a pseudo-random double in [-1.0, 1.0].
  double nextBipolar() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return (_state / 0x7FFFFFFF) * 2.0 - 1.0;
  }

  /// Returns a pseudo-random double in [0.0, 1.0].
  double nextUnit() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }

  /// Returns a pseudo-random double in [0.0, 1.0).
  double nextDouble() => nextUnit();

  /// Returns a pseudo-random double in [min, max).
  double range(double min, double max) => min + nextUnit() * (max - min);
}

/// Width multiplier for a tilted stylus. Flat strokes spread wider.
double tiltWidthScale(double tilt) {
  if (!tilt.isFinite || tilt <= 0) return 1.0;
  return 1.0 + 0.65 * math.sin(tilt.clamp(0.0, math.pi / 2));
}

/// Darkens an ink [color] for high-pressure or held/spilled ink spots so that
/// even mid-tone inks visibly pool darker when held in one spot.
Color _darkenInkColor(Color color, double factor) {
  if (factor <= 0) return color;
  final hsl = HSLColor.fromColor(color);
  final nextLightness = (hsl.lightness * (1.0 - factor * 0.55)).clamp(0.0, 1.0);
  final nextSaturation = (hsl.saturation + factor * 0.18).clamp(0.0, 1.0);
  return hsl
      .withLightness(nextLightness)
      .withSaturation(nextSaturation)
      .toColor();
}

/// Paints an organic ink-spill pool & darkened core when a pen/brush is held on
/// a spot (indicated by [sample.pressure] > 1.02).
void _paintInkSpillAtSample({
  required ui.Canvas canvas,
  required ResampledStrokePoint sample,
  required Color color,
  required ui.BlendMode blendMode,
  required DeterministicBrushRandom rng,
}) {
  final spill = (sample.pressure - 1.0).clamp(0.0, 1.4);
  if (spill <= 0.02) return;
  final darkColor = _darkenInkColor(color, (spill * 0.7).clamp(0.0, 1.0));
  final outerRadius = sample.radius * (1.08 + spill * 0.45);
  final coreRadius = sample.radius * (0.75 + spill * 0.25);

  // Feathered outer bleed halo
  final bleedPaint = ui.Paint()
    ..color = darkColor.withValues(
      alpha: (sample.opacity * (0.18 + 0.22 * (spill / 1.4))).clamp(0.02, 0.65),
    )
    ..style = ui.PaintingStyle.fill
    ..blendMode = blendMode
    ..maskFilter = ui.MaskFilter.blur(
      ui.BlurStyle.normal,
      math.max(0.8, sample.radius * 0.22 * (0.6 + spill)),
    );
  canvas.drawCircle(sample.position, outerRadius, bleedPaint);

  // Capillary micro-lobes around the ink pool
  final lobes = 3 + (spill * 3).round();
  final lobePaint = ui.Paint()
    ..color = darkColor.withValues(
      alpha: (sample.opacity * (0.28 + 0.35 * (spill / 1.4))).clamp(0.04, 0.85),
    )
    ..style = ui.PaintingStyle.fill
    ..blendMode = blendMode;
  for (var i = 0; i < lobes; i++) {
    final angle = (i / lobes) * math.pi * 2 + rng.nextBipolar() * 0.45;
    final dist = sample.radius * (0.35 + 0.38 * spill * rng.nextUnit());
    final lobeR =
        sample.radius * (0.42 + 0.28 * (spill / 1.4) * (0.6 + 0.4 * rng.nextUnit()));
    final offset = Offset(math.cos(angle) * dist, math.sin(angle) * dist);
    canvas.drawCircle(sample.position + offset, lobeR, lobePaint);
  }

  // Darkened saturated ink core
  final corePaint = ui.Paint()
    ..color = darkColor.withValues(
      alpha: (sample.opacity * (0.65 + 0.35 * (spill / 1.4))).clamp(0.1, 1.0),
    )
    ..style = ui.PaintingStyle.fill
    ..blendMode = blendMode;
  canvas.drawCircle(sample.position, coreRadius, corePaint);
}

/// Paints accumulated ink-spill pools in a second pass after the base stroke
/// segments so continuing a stroke never paints lighter ink over a held pool.
void _paintSpillOverlayPass({
  required ui.Canvas canvas,
  required List<ResampledStrokePoint> spillSamples,
  required Color color,
  required ui.BlendMode blendMode,
  required DeterministicBrushRandom rng,
}) {
  for (final sample in spillSamples) {
    _paintInkSpillAtSample(
      canvas: canvas,
      sample: sample,
      color: color,
      blendMode: blendMode,
      rng: rng,
    );
  }
}

/// Resamples a polyline of stroke points at a step proportional to brush
/// radius and spacing, interpolating pressure, tilt and applying taper.
List<ResampledStrokePoint> resampleStroke({
  required List<Offset> points,
  List<double>? pressures,
  List<double>? tilts,
  required double baseWidth,
  required double baseOpacity,
  required CanvasBrushStyle style,
  double? spacingOverride,
}) {
  if (points.isEmpty) return const [];
  if (points.length == 1) {
    final pr = (pressures != null && pressures.isNotEmpty)
        ? pressures.first.clamp(0.05, 2.4)
        : 1.0;
    final normPr = pr.clamp(0.05, 1.0);
    final spill = math.max(0.0, pr - 1.0);
    final tilt = (tilts != null && tilts.isNotEmpty) ? tilts.first : 0.0;
    final r = (baseWidth / 2) *
        (style.pressureAffectsSize
            ? (0.4 + 0.9 * normPr + 0.55 * spill)
            : (1.0 + 0.45 * spill)) *
        tiltWidthScale(tilt);
    return [
      ResampledStrokePoint(
        position: points.first,
        radius: math.max(0.5, r),
        opacity: (baseOpacity *
                (style.pressureAffectsOpacity
                    ? (0.35 + 0.65 * normPr)
                    : (0.72 + 0.28 * normPr)) *
                (1.0 + 0.35 * spill))
            .clamp(0.0, 1.0),
        pressure: pr,
      ),
    ];
  }

  // Normalize pressures and tilts parallel to input points (allowing > 1.0 for
  // ink dwell / spill).
  final rawPressures = <double>[];
  final rawTilts = <double>[];
  for (int i = 0; i < points.length; i++) {
    final p = (pressures != null && i < pressures.length)
        ? pressures[i].clamp(0.05, 2.4)
        : 1.0;
    rawPressures.add(p);
    rawTilts.add(
      (tilts != null && i < tilts.length)
          ? tilts[i].clamp(0.0, math.pi / 2)
          : 0.0,
    );
  }

  // Smoothly subdivide multi-point bends using midpoint quadratic Beziers so
  // resampled strokes follow a continuous curve instead of a jagged polygon,
  // while collapsing zero-length dwell clusters to their peak pressure.
  final curvePoints = <Offset>[];
  final pointPressures = <double>[];
  final pointTilts = <double>[];

  if (points.length >= 3 && points.length <= 1200) {
    curvePoints.add(points.first);
    pointPressures.add(rawPressures.first);
    pointTilts.add(rawTilts.first);

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      final d0 = (curr - prev).distance;
      final d1 = (next - curr).distance;

      // Preserve stationary hold/dwell peaks directly.
      if (d0 < 0.35 || d1 < 0.35) {
        if ((curr - curvePoints.last).distance < 0.35) {
          if (rawPressures[i] > pointPressures.last) {
            pointPressures[pointPressures.length - 1] = rawPressures[i];
          }
        } else {
          curvePoints.add(curr);
          pointPressures.add(rawPressures[i]);
          pointTilts.add(rawTilts[i]);
        }
        continue;
      }

      final mid0 = Offset((prev.dx + curr.dx) * 0.5, (prev.dy + curr.dy) * 0.5);
      final mid1 = Offset((curr.dx + next.dx) * 0.5, (curr.dy + next.dy) * 0.5);
      final prMid0 = (rawPressures[i - 1] + rawPressures[i]) * 0.5;
      final prMid1 = (rawPressures[i] + rawPressures[i + 1]) * 0.5;
      final tiltMid0 = (rawTilts[i - 1] + rawTilts[i]) * 0.5;
      final tiltMid1 = (rawTilts[i] + rawTilts[i + 1]) * 0.5;

      final span = d0 + d1;
      final subSteps = span > 24.0 ? 4 : (span > 8.0 ? 3 : 2);
      for (int s = 1; s <= subSteps; s++) {
        final t = s / subSteps;
        final u = 1.0 - t;
        final bx = u * u * mid0.dx + 2 * u * t * curr.dx + t * t * mid1.dx;
        final by = u * u * mid0.dy + 2 * u * t * curr.dy + t * t * mid1.dy;
        final bPr =
            u * u * prMid0 + 2 * u * t * rawPressures[i] + t * t * prMid1;
        final bTilt =
            u * u * tiltMid0 + 2 * u * t * rawTilts[i] + t * t * tiltMid1;
        curvePoints.add(Offset(bx, by));
        pointPressures.add(bPr.clamp(0.05, 2.4));
        pointTilts.add(bTilt.clamp(0.0, math.pi / 2));
      }
    }

    if ((points.last - curvePoints.last).distance < 0.35) {
      if (rawPressures.last > pointPressures.last) {
        pointPressures[pointPressures.length - 1] = rawPressures.last;
      }
    } else {
      curvePoints.add(points.last);
      pointPressures.add(rawPressures.last);
      pointTilts.add(rawTilts.last);
    }
  } else {
    curvePoints.addAll(points);
    pointPressures.addAll(rawPressures);
    pointTilts.addAll(rawTilts);
  }

  // 1. Calculate cumulative segment lengths.
  final segmentDistances = <double>[0.0];
  double totalLength = 0.0;
  for (int i = 0; i < curvePoints.length - 1; i++) {
    final dist = (curvePoints[i + 1] - curvePoints[i]).distance;
    totalLength += dist;
    segmentDistances.add(totalLength);
  }

  if (totalLength <= 0.001) {
    final pr =
        pointPressures.isNotEmpty ? pointPressures.reduce(math.max) : 1.0;
    final normPr = pr.clamp(0.05, 1.0);
    final spill = math.max(0.0, pr - 1.0);
    final r = (style.width / 2) *
        (style.pressureAffectsSize
            ? (0.4 + 0.9 * normPr + 0.55 * spill)
            : (1.0 + 0.45 * spill));
    return [
      ResampledStrokePoint(
        position: curvePoints.first,
        radius: math.max(0.5, r),
        opacity: (style.opacity *
                (style.pressureAffectsOpacity
                    ? (0.35 + 0.65 * normPr)
                    : (0.72 + 0.28 * normPr)) *
                (1.0 + 0.35 * spill))
            .clamp(0.0, 1.0),
        pressure: pr,
      ),
    ];
  }

  final spacingFraction = spacingOverride ?? style.spacing;
  final baseRadius = style.width / 2;
  // Upper bound to prevent GPU/CPU stalls on huge strokes (e.g. at 10% zoom)
  // while scaling step so the full stroke length is always covered evenly.
  const maxSamples = 1800;
  final rawStep = (baseRadius * spacingFraction).clamp(1.0, 24.0);
  final step = math.max(rawStep, totalLength / maxSamples);

  final samples = <ResampledStrokePoint>[];
  double currentDist = 0.0;
  int currentSegment = 0;

  while (currentDist <= totalLength && samples.length < maxSamples) {
    while (currentSegment < curvePoints.length - 2 &&
        segmentDistances[currentSegment + 1] < currentDist) {
      currentSegment++;
    }

    final segStartDist = segmentDistances[currentSegment];
    final segEndDist = segmentDistances[currentSegment + 1];
    final segLen = segEndDist - segStartDist;
    final t = segLen > 0.0001
        ? ((currentDist - segStartDist) / segLen).clamp(0.0, 1.0)
        : 0.0;

    final p0 = curvePoints[currentSegment];
    final p1 = curvePoints[currentSegment + 1];
    final pos = Offset.lerp(p0, p1, t) ?? p0;

    final pr0 = pointPressures[currentSegment];
    final pr1 = pointPressures[currentSegment + 1];
    final pressure = (pr0 + (pr1 - pr0) * t).clamp(0.05, 2.4);
    final normPressure = pressure.clamp(0.05, 1.0);
    final spill = math.max(0.0, pressure - 1.0);
    final tilt = pointTilts[currentSegment] +
        (pointTilts[currentSegment + 1] - pointTilts[currentSegment]) * t;

    double taper = 1.0;
    if (style.taperStart > 0 && currentDist < totalLength * style.taperStart) {
      final u = (currentDist / (totalLength * style.taperStart)).clamp(0.0, 1.0);
      taper = 0.2 + 0.8 * u;
    } else if (style.taperEnd > 0 &&
        spill <= 0.02 &&
        currentDist > totalLength * (1 - style.taperEnd)) {
      final u = ((totalLength - currentDist) /
              (totalLength * style.taperEnd))
          .clamp(0.0, 1.0);
      taper = 0.2 + 0.8 * u;
    }

    final pressureRadius = style.pressureAffectsSize
        ? (0.4 + 0.9 * normPressure + 0.55 * spill)
        : (1.0 + 0.45 * spill);
    final radius = math.max(
      0.5,
      baseRadius * taper * pressureRadius * tiltWidthScale(tilt),
    );

    final pressureOpacity = style.pressureAffectsOpacity
        ? (0.35 + 0.65 * normPressure)
        : (normPressure < 0.98 ? (0.68 + 0.32 * normPressure) : 1.0);
    final sampleOpacity =
        (style.opacity * pressureOpacity * (1.0 + 0.35 * spill)).clamp(
          0.0,
          1.0,
        );

    samples.add(
      ResampledStrokePoint(
        position: pos,
        radius: radius,
        opacity: sampleOpacity,
        pressure: pressure,
      ),
    );

    if (currentDist >= totalLength) break;
    currentDist = math.min(currentDist + step, totalLength);
  }

  if (samples.isNotEmpty) {
    final pr = pointPressures.last;
    final normPr = pr.clamp(0.05, 1.0);
    final spill = math.max(0.0, pr - 1.0);
    if ((samples.last.position - curvePoints.last).distance > 0.5 ||
        pr > samples.last.pressure + 0.08) {
      final pressureRadius = style.pressureAffectsSize
          ? (0.4 + 0.9 * normPr + 0.55 * spill)
          : (1.0 + 0.45 * spill);
      final radius = math.max(
        0.5,
        baseRadius *
            (style.taperEnd > 0 && spill <= 0.02 ? 0.2 : 1.0) *
            pressureRadius *
            tiltWidthScale(pointTilts.last),
      );
      final pressureOpacity = style.pressureAffectsOpacity
          ? (0.35 + 0.65 * normPr)
          : (normPr < 0.98 ? (0.68 + 0.32 * normPr) : 1.0);
      samples.add(
        ResampledStrokePoint(
          position: curvePoints.last,
          radius: radius,
          opacity: (style.opacity * pressureOpacity * (1.0 + 0.35 * spill))
              .clamp(0.0, 1.0),
          pressure: pr,
        ),
      );
    }
  }

  return samples;
}

/// Draws the optional fill beneath a freehand stroke: the stroke's closed
/// polygon in [fillColor] at the stroke's effective [opacity].
///
/// Shared by the interactive canvas painter and the raster/PDF exporter so a
/// filled stroke reads identically on screen and in an export. Fewer than three
/// points cannot form a polygon, so nothing is filled and only the ink remains.
void paintStrokeFill({
  required ui.Canvas canvas,
  required List<Offset> points,
  required Color? fillColor,
  required double opacity,
}) {
  if (fillColor == null || points.length < 3) return;
  final fillOpacity = (opacity * fillColor.a).clamp(0.0, 1.0);
  canvas.drawPath(
    ui.Path()..addPolygon(points, true),
    ui.Paint()
      ..color = fillColor.withValues(alpha: fillOpacity)
      ..style = ui.PaintingStyle.fill,
  );
}

/// Unified brush renderer used by both the interactive canvas painter and
/// raster / PDF exporters, ensuring identical stroke appearance across all
/// platforms.
void paintCanvasStroke({
  required ui.Canvas canvas,
  required List<Offset> points,
  List<double>? pressures,
  List<double>? tilts,
  required Color color,
  required double strokeWidth,
  required double strokeOpacity,
  required String brushType,
  String? brushId,
  double? spacingOverride,
  double? spacing,
  int textureSeed = 0,
}) {
  if (points.isEmpty) return;

  final effectiveSpacing = spacing ?? spacingOverride;
  final effectiveId =
      (brushId != null && brushId.isNotEmpty) ? brushId : brushType;
  final style = resolveBrushStyle(
    brushType: effectiveId,
    strokeWidth: strokeWidth,
    strokeOpacity: strokeOpacity,
  );

  if (points.length == 1) {
    final pr = (pressures != null && pressures.isNotEmpty)
        ? pressures.first.clamp(0.05, 2.4)
        : 1.0;
    final normPr = pr.clamp(0.05, 1.0);
    final spill = math.max(0.0, pr - 1.0);
    final tilt = (tilts != null && tilts.isNotEmpty) ? tilts.first : 0.0;
    final r = math.max(
      0.5,
      (style.width / 2) *
          (style.pressureAffectsSize
              ? (0.4 + 0.9 * normPr + 0.55 * spill)
              : (1.0 + 0.45 * spill)) *
          tiltWidthScale(tilt),
    );
    final drawColor = spill > 0.02
        ? _darkenInkColor(color, (spill * 0.7).clamp(0.0, 1.0))
        : color;
    final p = ui.Paint()
      ..color = drawColor.withValues(alpha: style.opacity)
      ..style = ui.PaintingStyle.fill
      ..blendMode = style.blendMode
      ..maskFilter = style.blurSigma > 0
          ? ui.MaskFilter.blur(ui.BlurStyle.normal, style.blurSigma)
          : null;
    canvas.drawCircle(points.first, r, p);
    if (spill > 0.02) {
      _paintInkSpillAtSample(
        canvas: canvas,
        sample: ResampledStrokePoint(
          position: points.first,
          radius: r,
          opacity: style.opacity,
          pressure: pr,
        ),
        color: color,
        blendMode: style.blendMode,
        rng: DeterministicBrushRandom(textureSeed),
      );
    }
    return;
  }

  final hasVaryingPressure = pressures != null &&
      pressures.isNotEmpty &&
      (pressures.any((pr) => (pr - pressures.first).abs() > 0.05) ||
          pressures.any((pr) => pr > 1.02));
  final hasSpillPressure =
      pressures != null && pressures.any((pr) => pr > 1.02);

  // 1. Highlighter
  if (effectiveId == 'highlighter') {
    final paint = ui.Paint()
      ..color = color.withValues(alpha: style.opacity)
      ..strokeWidth = style.width
      ..strokeCap = ui.StrokeCap.square
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke
      ..blendMode = ui.BlendMode.multiply;
    _drawSmoothPath(canvas, points, paint);
    return;
  }

  // 2. Marker
  if (effectiveId == 'marker' && !hasSpillPressure) {
    final paint = ui.Paint()
      ..color = color.withValues(alpha: style.opacity)
      ..strokeWidth = style.width
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke
      ..blendMode = ui.BlendMode.srcOver;
    _drawSmoothPath(canvas, points, paint);
    return;
  }

  // 3. Wash / Watercolor / Airbrush
  if (style.texture == BrushTexture.wash) {
    final samples = resampleStroke(
      points: points,
      pressures: pressures,
      baseWidth: strokeWidth,
      baseOpacity: strokeOpacity,
      style: style,
      spacingOverride: effectiveSpacing,
      tilts: tilts,
    );
    final rng = DeterministicBrushRandom(textureSeed);

    final stampPaint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..blendMode = style.blendMode
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, style.blurSigma);

    final edgePaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter =
          ui.MaskFilter.blur(ui.BlurStyle.normal, style.blurSigma * 0.5);

    final spillSamples = <ResampledStrokePoint>[];
    for (final sample in samples) {
      var pos = sample.position;
      if (style.jitter > 0) {
        pos += Offset(
          rng.nextBipolar() * sample.radius * style.jitter,
          rng.nextBipolar() * sample.radius * style.jitter,
        );
      }
      final spill = math.max(0.0, sample.pressure - 1.0);
      final sampleColor = spill > 0.02
          ? _darkenInkColor(color, (spill * 0.65).clamp(0.0, 1.0))
          : color;
      final alpha = (sample.opacity * (0.35 + 0.25 * spill)).clamp(0.01, 1.0);
      stampPaint.color = sampleColor.withValues(alpha: alpha);
      canvas.drawCircle(pos, sample.radius, stampPaint);

      if (effectiveId == 'watercolor') {
        edgePaint.color = sampleColor.withValues(
          alpha: (sample.opacity * (0.6 + 0.25 * spill)).clamp(0.01, 1.0),
        );
        canvas.drawCircle(pos, sample.radius, edgePaint);
      }
      if (spill > 0.02) {
        spillSamples.add(sample);
      }
    }
    _paintSpillOverlayPass(
      canvas: canvas,
      spillSamples: spillSamples,
      color: color,
      blendMode: style.blendMode,
      rng: rng,
    );
    return;
  }

  // 4. Grain: Pencil, Textured, Charcoal
  if (style.texture == BrushTexture.grain) {
    final samples = resampleStroke(
      points: points,
      pressures: pressures,
      baseWidth: strokeWidth,
      baseOpacity: strokeOpacity,
      style: style,
      spacingOverride: effectiveSpacing,
      tilts: tilts,
    );
    final rng = DeterministicBrushRandom(textureSeed);

    final basePaint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..blendMode = style.blendMode;

    final specklePaint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..blendMode = style.blendMode;

    final spillSamples = <ResampledStrokePoint>[];
    for (final sample in samples) {
      final pos = sample.position;
      final spill = math.max(0.0, sample.pressure - 1.0);
      final sampleColor = spill > 0.02
          ? _darkenInkColor(color, (spill * 0.65).clamp(0.0, 1.0))
          : color;
      final alpha = (sample.opacity * (0.7 + 0.25 * spill)).clamp(0.01, 1.0);
      basePaint.color = sampleColor.withValues(alpha: alpha);
      canvas.drawCircle(pos, sample.radius * 0.85, basePaint);

      final numSpeckles = style.jitter > 0.5 ? 3 : 2;
      for (int s = 0; s < numSpeckles; s++) {
        final jitterOffset = Offset(
          rng.nextBipolar() * sample.radius * style.jitter,
          rng.nextBipolar() * sample.radius * style.jitter,
        );
        final speckleAlpha =
            (sample.opacity * (0.3 + 0.5 * rng.nextUnit())).clamp(0.01, 1.0);
        specklePaint.color = sampleColor.withValues(alpha: speckleAlpha);
        canvas.drawCircle(
          pos + jitterOffset,
          sample.radius * (0.2 + 0.3 * rng.nextUnit()),
          specklePaint,
        );
      }
      if (spill > 0.02) {
        spillSamples.add(sample);
      }
    }
    _paintSpillOverlayPass(
      canvas: canvas,
      spillSamples: spillSamples,
      color: color,
      blendMode: style.blendMode,
      rng: rng,
    );
    return;
  }

  // 5. Solid / Pen (or Marker with dwell spill) with varying pressure or taper
  if (hasVaryingPressure || style.taperStart > 0 || style.taperEnd > 0) {
    final samples = resampleStroke(
      points: points,
      pressures: pressures,
      baseWidth: strokeWidth,
      baseOpacity: strokeOpacity,
      style: style,
      spacingOverride: effectiveSpacing,
      tilts: tilts,
    );
    _drawRibbonStamps(
      canvas,
      samples,
      color,
      style.opacity,
      style.blendMode,
      textureSeed: textureSeed,
    );
    return;
  }

  // Constant-pressure solid line
  final paint = ui.Paint()
    ..color = color.withValues(alpha: style.opacity)
    ..strokeWidth = style.width
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round
    ..style = ui.PaintingStyle.stroke
    ..blendMode = style.blendMode;
  _drawSmoothPath(canvas, points, paint);
}

void _drawSmoothPath(ui.Canvas canvas, List<Offset> points, ui.Paint paint) {
  if (points.length < 2) return;
  final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
  for (int i = 1; i < points.length; i++) {
    final p0 = points[i - 1];
    final p1 = points[i];
    final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  canvas.drawPath(path, paint);
}

void _drawRibbonStamps(
  ui.Canvas canvas,
  List<ResampledStrokePoint> samples,
  Color baseColor,
  double baseOpacity,
  ui.BlendMode blendMode, {
  int textureSeed = 0,
}) {
  if (samples.isEmpty) return;
  final rng = DeterministicBrushRandom(textureSeed);
  if (samples.length == 1) {
    final s = samples.first;
    final spill = math.max(0.0, s.pressure - 1.0);
    final c = spill > 0.02
        ? _darkenInkColor(baseColor, (spill * 0.7).clamp(0.0, 1.0))
        : baseColor;
    canvas.drawCircle(
      s.position,
      s.radius,
      ui.Paint()
        ..color = c.withValues(alpha: s.opacity.clamp(0.05, 1.0))
        ..style = ui.PaintingStyle.fill
        ..blendMode = blendMode,
    );
    if (spill > 0.02) {
      _paintInkSpillAtSample(
        canvas: canvas,
        sample: s,
        color: baseColor,
        blendMode: blendMode,
        rng: rng,
      );
    }
    return;
  }

  // Compute smooth averaged normals at each sample so adjacent ribbon quads
  // join seamlessly without outer-corner notches.
  final normals = List<Offset>.filled(samples.length, Offset.zero);
  Offset lastValidNormal = const Offset(0, 1);
  for (int i = 0; i < samples.length; i++) {
    Offset nPrev = Offset.zero;
    Offset nNext = Offset.zero;
    if (i > 0) {
      final d = samples[i].position - samples[i - 1].position;
      final dist = d.distance;
      if (dist > 0.0005) {
        nPrev = Offset(-d.dy / dist, d.dx / dist);
      }
    }
    if (i < samples.length - 1) {
      final d = samples[i + 1].position - samples[i].position;
      final dist = d.distance;
      if (dist > 0.0005) {
        nNext = Offset(-d.dy / dist, d.dx / dist);
      }
    }
    final combined = nPrev + nNext;
    final len = combined.distance;
    if (len > 0.0005) {
      lastValidNormal = combined / len;
    }
    normals[i] = lastValidNormal;
  }

  final fillPaint = ui.Paint()
    ..style = ui.PaintingStyle.fill
    ..blendMode = blendMode;

  final spillSamples = <ResampledStrokePoint>[];
  for (int i = 0; i < samples.length - 1; i++) {
    final s0 = samples[i];
    final s1 = samples[i + 1];
    final segPressure = math.max(s0.pressure, s1.pressure);
    final spill = math.max(0.0, segPressure - 1.0);
    final segOpacity = ((s0.opacity + s1.opacity) * 0.5).clamp(
      baseOpacity * 0.45,
      1.0,
    );
    final segColor = spill > 0.02
        ? _darkenInkColor(baseColor, (spill * 0.7).clamp(0.0, 1.0))
        : (segPressure < 0.92
              ? baseColor
              : _darkenInkColor(
                  baseColor,
                  ((segPressure - 0.85) * 0.35).clamp(0.0, 0.2),
                ));
    fillPaint.color = segColor.withValues(alpha: segOpacity);

    final d = s1.position - s0.position;
    final dist = d.distance;
    if (dist < 0.001) {
      canvas.drawCircle(s0.position, s0.radius, fillPaint);
      if (s0.pressure > 1.02) {
        spillSamples.add(s0);
      }
      continue;
    }
    final n0 = normals[i];
    final n1 = normals[i + 1];
    final p1 = s0.position + n0 * s0.radius;
    final p2 = s1.position + n1 * s1.radius;
    final p3 = s1.position - n1 * s1.radius;
    final p4 = s0.position - n0 * s0.radius;

    final quadPath = ui.Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    canvas.drawPath(quadPath, fillPaint);
    canvas.drawCircle(s0.position, s0.radius, fillPaint);
    if (s0.pressure > 1.02) {
      spillSamples.add(s0);
    }
  }
  final last = samples.last;
  final lastSpill = math.max(0.0, last.pressure - 1.0);
  final lastColor = lastSpill > 0.02
      ? _darkenInkColor(baseColor, (lastSpill * 0.7).clamp(0.0, 1.0))
      : baseColor;
  fillPaint.color = lastColor.withValues(
    alpha: last.opacity.clamp(baseOpacity * 0.45, 1.0),
  );
  canvas.drawCircle(last.position, last.radius, fillPaint);
  if (last.pressure > 1.02) {
    spillSamples.add(last);
  }
  _paintSpillOverlayPass(
    canvas: canvas,
    spillSamples: spillSamples,
    color: baseColor,
    blendMode: blendMode,
    rng: rng,
  );
}
