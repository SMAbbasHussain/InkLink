import 'dart:math' as math;
import 'dart:ui';

const double minStylusPressure = 0.05;

// A strength of 1 would freeze the filtered point.
const double maxStabilizerStrength = 0.9;

double normalizePointerPressure({
  required PointerDeviceKind kind,
  required double pressure,
  required double pressureMin,
  required double pressureMax,
}) {
  if (kind != PointerDeviceKind.stylus &&
      kind != PointerDeviceKind.invertedStylus) {
    return 1.0;
  }
  final range = pressureMax - pressureMin;
  if (!pressure.isFinite || !range.isFinite || range < 1e-6) return 1.0;
  return ((pressure - pressureMin) / range).clamp(minStylusPressure, 1.0);
}

/// Normalizes stylus tilt to 0–π/2 radians. Mouse/touch report 0.
double normalizePointerTilt({
  required PointerDeviceKind kind,
  required double tilt,
}) {
  if (kind != PointerDeviceKind.stylus &&
      kind != PointerDeviceKind.invertedStylus) {
    return 0;
  }
  if (!tilt.isFinite) return 0;
  return tilt.clamp(0.0, math.pi / 2);
}

class StrokeStabilizer {
  StrokeStabilizer({
    required double strength,
    this.cornerAngle = math.pi / 3,
    this.minCornerSegment = 6.0,
    this.pause = const Duration(milliseconds: 200),
  }) : strength = strength.clamp(0.0, maxStabilizerStrength);

  final double strength;
  final double cornerAngle;
  final double minCornerSegment;
  final Duration pause;

  Offset? _smoothed;
  Offset? _lastRaw;
  Offset? _directionAnchor;
  Offset? _direction;
  Duration? _lastTime;

  List<Offset> add(Offset raw, {Duration? elapsed}) {
    final smoothed = _smoothed;
    final previousRaw = _lastRaw;
    final previousTime = _lastTime;
    _lastRaw = raw;
    if (elapsed != null) _lastTime = elapsed;
    if (smoothed == null || strength <= 0) {
      _smoothed = raw;
      _directionAnchor ??= raw;
      return [raw];
    }

    final paused =
        elapsed != null &&
        previousTime != null &&
        elapsed - previousTime >= pause;
    if (paused) {
      _smoothed = raw;
      _directionAnchor = raw;
      _direction = null;
      return [raw];
    }
    if (_detectCorner(raw, previousRaw)) {
      _smoothed = raw;
      // Include the raw corner before resetting, rather than cutting across it.
      return [previousRaw!, raw];
    }
    final next = smoothed + (raw - smoothed) * (1 - strength);
    _smoothed = next;
    return [next];
  }

  bool _detectCorner(Offset raw, Offset? previousRaw) {
    final anchor = _directionAnchor ?? raw;
    final delta = raw - anchor;
    final length = delta.distance;
    if (length < minCornerSegment) return false;
    final direction = delta / length;
    final previous = _direction;
    _direction = direction;
    _directionAnchor = raw;
    if (previous == null) return false;
    // In continuous fine-grained pointer streams where individual steps are
    // smaller than [minCornerSegment], snapping [_smoothed] directly to [raw]
    // would teleport across the stabilizer lag and inject a jagged spike on
    // curves or hand tremor. Only snap on discrete corner segments.
    if (previousRaw != null &&
        (raw - previousRaw).distance < minCornerSegment) {
      return false;
    }
    final dot = (direction.dx * previous.dx + direction.dy * previous.dy).clamp(
      -1.0,
      1.0,
    );
    return math.acos(dot) >= cornerAngle;
  }

  List<Offset> finish() {
    final raw = _lastRaw;
    if (raw == null || raw == _smoothed) return const [];
    return [raw];
  }
}

List<Offset> smoothStrokePoints(List<Offset> points) {
  if (points.length < 4) return points;
  var current = points;
  final passes = points.length > 6 ? 3 : 1;
  for (var pass = 0; pass < passes; pass++) {
    current = [
      current.first,
      for (var i = 1; i < current.length - 1; i++)
        (current[i - 1] + current[i] + current[i + 1]) / 3,
      current.last,
    ];
  }
  return current;
}
