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
        ? pressures.first.clamp(0.05, 1.0)
        : 1.0;
    final tilt = (tilts != null && tilts.isNotEmpty) ? tilts.first : 0.0;
    final r = (baseWidth / 2) *
        (style.pressureAffectsSize ? (0.4 + 0.9 * pr) : 1.0) *
        tiltWidthScale(tilt);
    return [
      ResampledStrokePoint(
        position: points.first,
        radius: math.max(0.5, r),
        opacity: (baseOpacity *
                (style.pressureAffectsOpacity ? (0.35 + 0.65 * pr) : 1.0))
            .clamp(0.0, 1.0),
        pressure: pr,
      ),
    ];
  }

  // 1. Calculate cumulative segment lengths.
  final segmentDistances = <double>[0.0];
  double totalLength = 0.0;
  for (int i = 0; i < points.length - 1; i++) {
    final dist = (points[i + 1] - points[i]).distance;
    totalLength += dist;
    segmentDistances.add(totalLength);
  }

  if (totalLength <= 0.001) {
    final pr =
        (pressures != null && pressures.isNotEmpty) ? pressures.first : 1.0;
    return [
      ResampledStrokePoint(
        position: points.first,
        radius: math.max(0.5, style.width / 2),
        opacity: style.opacity,
        pressure: pr,
      ),
    ];
  }

  // Normalize pressures parallel to points.
  final pointPressures = <double>[];
  final pointTilts = <double>[];
  for (int i = 0; i < points.length; i++) {
    final p = (pressures != null && i < pressures.length)
        ? pressures[i].clamp(0.05, 1.0)
        : 1.0;
    pointPressures.add(p);
    pointTilts.add(
      (tilts != null && i < tilts.length)
          ? tilts[i].clamp(0.0, math.pi / 2)
          : 0.0,
    );
  }

  final spacingFraction = spacingOverride ?? style.spacing;
  final baseRadius = style.width / 2;
  final step = (baseRadius * spacingFraction).clamp(1.0, 24.0);

  final samples = <ResampledStrokePoint>[];
  double currentDist = 0.0;
  int currentSegment = 0;

  // Upper bound to prevent unbounded loops on extreme coordinates.
  const maxSamples = 8000;

  while (currentDist <= totalLength && samples.length < maxSamples) {
    while (currentSegment < points.length - 2 &&
        segmentDistances[currentSegment + 1] < currentDist) {
      currentSegment++;
    }

    final segStartDist = segmentDistances[currentSegment];
    final segEndDist = segmentDistances[currentSegment + 1];
    final segLen = segEndDist - segStartDist;
    final t = segLen > 0.0001
        ? ((currentDist - segStartDist) / segLen).clamp(0.0, 1.0)
        : 0.0;

    final p0 = points[currentSegment];
    final p1 = points[currentSegment + 1];
    final pos = Offset.lerp(p0, p1, t) ?? p0;

    final pr0 = pointPressures[currentSegment];
    final pr1 = pointPressures[currentSegment + 1];
    final pressure = (pr0 + (pr1 - pr0) * t).clamp(0.05, 1.0);
    final tilt = pointTilts[currentSegment] +
        (pointTilts[currentSegment + 1] - pointTilts[currentSegment]) * t;

    double taper = 1.0;
    if (style.taperStart > 0 && currentDist < totalLength * style.taperStart) {
      final u = (currentDist / (totalLength * style.taperStart)).clamp(0.0, 1.0);
      taper = 0.2 + 0.8 * u;
    } else if (style.taperEnd > 0 &&
        currentDist > totalLength * (1 - style.taperEnd)) {
      final u = ((totalLength - currentDist) /
              (totalLength * style.taperEnd))
          .clamp(0.0, 1.0);
      taper = 0.2 + 0.8 * u;
    }

    final pressureRadius =
        style.pressureAffectsSize ? (0.4 + 0.9 * pressure) : 1.0;
    final radius = math.max(
      0.5,
      baseRadius * taper * pressureRadius * tiltWidthScale(tilt),
    );

    final pressureOpacity =
        style.pressureAffectsOpacity ? (0.35 + 0.65 * pressure) : 1.0;
    final sampleOpacity = (style.opacity * pressureOpacity).clamp(0.0, 1.0);

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

  if (samples.isNotEmpty &&
      (samples.last.position - points.last).distance > 0.5) {
    final pr = pointPressures.last;
    final pressureRadius =
        style.pressureAffectsSize ? (0.4 + 0.9 * pr) : 1.0;
    final radius = math.max(
      0.5,
      baseRadius *
          (style.taperEnd > 0 ? 0.2 : 1.0) *
          pressureRadius *
          tiltWidthScale(pointTilts.last),
    );
    final pressureOpacity =
        style.pressureAffectsOpacity ? (0.35 + 0.65 * pr) : 1.0;
    samples.add(
      ResampledStrokePoint(
        position: points.last,
        radius: radius,
        opacity: (style.opacity * pressureOpacity).clamp(0.0, 1.0),
        pressure: pr,
      ),
    );
  }

  return samples;
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
    final pr =
        (pressures != null && pressures.isNotEmpty) ? pressures.first : 1.0;
    final tilt = (tilts != null && tilts.isNotEmpty) ? tilts.first : 0.0;
    final r = math.max(
      0.5,
      (style.width / 2) *
          (style.pressureAffectsSize ? (0.4 + 0.9 * pr) : 1.0) *
          tiltWidthScale(tilt),
    );
    final p = ui.Paint()
      ..color = color.withValues(alpha: style.opacity)
      ..style = ui.PaintingStyle.fill
      ..blendMode = style.blendMode
      ..maskFilter = style.blurSigma > 0
          ? ui.MaskFilter.blur(ui.BlurStyle.normal, style.blurSigma)
          : null;
    canvas.drawCircle(points.first, r, p);
    return;
  }

  final hasVaryingPressure = pressures != null &&
      pressures.isNotEmpty &&
      pressures.any((pr) => (pr - pressures.first).abs() > 0.05);

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
  if (effectiveId == 'marker') {
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

    for (final sample in samples) {
      var pos = sample.position;
      if (style.jitter > 0) {
        pos += Offset(
          rng.nextBipolar() * sample.radius * style.jitter,
          rng.nextBipolar() * sample.radius * style.jitter,
        );
      }
      final alpha = (sample.opacity * 0.35).clamp(0.01, 1.0);
      stampPaint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(pos, sample.radius, stampPaint);

      if (effectiveId == 'watercolor') {
        edgePaint.color =
            color.withValues(alpha: (sample.opacity * 0.6).clamp(0.01, 1.0));
        canvas.drawCircle(pos, sample.radius, edgePaint);
      }
    }
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

    for (final sample in samples) {
      final pos = sample.position;
      final alpha = (sample.opacity * 0.7).clamp(0.01, 1.0);
      basePaint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(pos, sample.radius * 0.85, basePaint);

      final numSpeckles = style.jitter > 0.5 ? 3 : 2;
      for (int s = 0; s < numSpeckles; s++) {
        final jitterOffset = Offset(
          rng.nextBipolar() * sample.radius * style.jitter,
          rng.nextBipolar() * sample.radius * style.jitter,
        );
        final speckleAlpha =
            (sample.opacity * (0.3 + 0.5 * rng.nextUnit())).clamp(0.01, 1.0);
        specklePaint.color = color.withValues(alpha: speckleAlpha);
        canvas.drawCircle(
          pos + jitterOffset,
          sample.radius * (0.2 + 0.3 * rng.nextUnit()),
          specklePaint,
        );
      }
    }
    return;
  }

  // 5. Solid / Pen with varying pressure or taper
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
      color.withValues(alpha: style.opacity),
      style.blendMode,
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
  Color color,
  ui.BlendMode blendMode,
) {
  if (samples.length < 2) return;

  final fillPaint = ui.Paint()
    ..color = color
    ..style = ui.PaintingStyle.fill
    ..blendMode = blendMode;

  for (int i = 0; i < samples.length - 1; i++) {
    final s0 = samples[i];
    final s1 = samples[i + 1];
    final d = s1.position - s0.position;
    final dist = d.distance;
    if (dist < 0.001) {
      canvas.drawCircle(s0.position, s0.radius, fillPaint);
      continue;
    }
    final normal = Offset(-d.dy / dist, d.dx / dist);
    final p1 = s0.position + normal * s0.radius;
    final p2 = s1.position + normal * s1.radius;
    final p3 = s1.position - normal * s1.radius;
    final p4 = s0.position - normal * s0.radius;

    final quadPath = ui.Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    canvas.drawPath(quadPath, fillPaint);
    canvas.drawCircle(s0.position, s0.radius, fillPaint);
  }
  canvas.drawCircle(samples.last.position, samples.last.radius, fillPaint);
}
