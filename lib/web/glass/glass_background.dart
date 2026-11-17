import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'glass_tokens.dart';

/// The page behind the glass: near-black base, slowly drifting aurora blobs,
/// a faint dot grid faded toward the edges, and fine grain against banding.
///
/// Everything is painted (no images) and isolated in repaint boundaries, so
/// only the aurora layer repaints while it drifts. With reduced motion the
/// aurora is still.
class GlassBackground extends StatefulWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 52),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Glass.reduceMotion(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Glass.base),
        RepaintBoundary(
          child: ExcludeSemantics(
            child: CustomPaint(painter: _AuroraPainter(_drift)),
          ),
        ),
        const RepaintBoundary(child: ExcludeSemantics(child: _FadedDotGrid())),
        const RepaintBoundary(
          child: ExcludeSemantics(child: CustomPaint(painter: _GrainPainter())),
        ),
        widget.child,
      ],
    );
  }
}

class _Blob {
  final Color color;
  final double opacity;
  final double radius; // fraction of the larger side
  final Offset center; // 0..1
  final Offset travel; // 0..1 amplitude
  final double phase;
  const _Blob(this.color, this.opacity, this.radius, this.center, this.travel, this.phase);
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> t;
  _AuroraPainter(this.t) : super(repaint: t);

  static const _blobs = [
    _Blob(Glass.violet, 0.34, 0.55, Offset(0.18, 0.12), Offset(0.10, 0.08), 0),
    _Blob(Glass.indigo, 0.30, 0.60, Offset(0.85, 0.20), Offset(0.08, 0.10), 1.7),
    _Blob(Glass.magenta, 0.16, 0.45, Offset(0.70, 0.90), Offset(0.12, 0.06), 3.1),
    _Blob(Glass.cyan, 0.08, 0.40, Offset(0.10, 0.85), Offset(0.06, 0.10), 4.4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * math.pi;
    final side = math.max(size.width, size.height);
    for (final b in _blobs) {
      final c = Offset(
        (b.center.dx + b.travel.dx * math.sin(a + b.phase)) * size.width,
        (b.center.dy + b.travel.dy * math.cos(a * 0.8 + b.phase)) * size.height,
      );
      final r = b.radius * side;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withValues(alpha: b.opacity),
            b.color.withValues(alpha: b.opacity * 0.35),
            b.color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}

/// Dot grid (it's a whiteboard app), strongest in the middle of the page.
class _FadedDotGrid extends StatelessWidget {
  const _FadedDotGrid();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const RadialGradient(
        radius: 0.75,
        colors: [Colors.white, Color(0x00FFFFFF)],
      ).createShader(rect),
      child: const CustomPaint(painter: _DotsPainter(), size: Size.infinite),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1FFFFFFF);
    for (double x = 12; x < size.width; x += 24) {
      for (double y = 12; y < size.height; y += 24) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// Fine random grain at ~3% opacity, so the gradients don't band.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final count = (size.width * size.height / 90).clamp(0, 60000).toInt() ~/ 2;
    Float32List points() {
      final list = Float32List(count * 2);
      for (var i = 0; i < count; i++) {
        list[i * 2] = rnd.nextDouble() * size.width;
        list[i * 2 + 1] = rnd.nextDouble() * size.height;
      }
      return list;
    }

    // One batched draw per tone instead of tens of thousands of rects.
    canvas.drawRawPoints(
      PointMode.points,
      points(),
      Paint()
        ..color = const Color(0x08FFFFFF)
        ..strokeWidth = 1,
    );
    canvas.drawRawPoints(
      PointMode.points,
      points(),
      Paint()
        ..color = const Color(0x0A000000)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}
