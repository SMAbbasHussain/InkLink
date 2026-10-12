import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';

/// The shared "frame with glass label" board-card chrome used on Home
/// (My Boards / Joined Boards) and in Workspace Detail. Visual-only: the
/// caller supplies the data, tap handler and owner-menu button.
class BoardCardFrame extends StatelessWidget {
  final String? previewPath;
  final String title;
  final String caption;
  final VoidCallback onTap;
  final Widget? menuButton;

  const BoardCardFrame({
    super.key,
    required this.previewPath,
    required this.title,
    required this.caption,
    required this.onTap,
    this.menuButton,
  });

  bool get _hasPreview =>
      previewPath != null &&
      previewPath!.isNotEmpty &&
      File(previewPath!).existsSync();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final isDark = tokens.isDark;

    return Container(
      height: 196,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0F000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardDotGridPainter(isDark: isDark),
                ),
              ),
              if (_hasPreview)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 132,
                  child: Image.file(
                    File(previewPath!),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                )
              else
                Positioned(
                  top: (132 - 44) / 2,
                  left: 0,
                  right: 0,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 80,
                      height: 44,
                      child: CustomPaint(
                        painter: _SquigglePainter(
                          color: isDark
                              ? const Color(0xFF4B4F59)
                              : const Color(0xFFC4C4CC),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                height: 56,
                child: _GlassLabel(
                  title: title,
                  caption: caption,
                  menuButton: menuButton,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  final String title;
  final String caption;
  final Widget? menuButton;

  const _GlassLabel({
    required this.title,
    required this.caption,
    required this.menuButton,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.glass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.glassStroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                offset: Offset(0, 4),
                blurRadius: 14,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InkType.cardTitle(tokens.ink),
                    ),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: InkType.geistFamily,
                        fontSize: 11,
                        color: tokens.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (menuButton != null)
                SizedBox(width: 34, height: 34, child: menuButton),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDotGridPainter extends CustomPainter {
  final bool isDark;

  _CardDotGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1B1E24) : const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final dotPaint = Paint()
      ..color = isDark ? const Color(0xFF2A2D35) : const Color(0xFFDCDCE2);
    const spacing = 10.0;
    const dotRadius = 0.5;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardDotGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _SquigglePainter extends CustomPainter {
  final Color color;

  _SquigglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.25,
        0,
        size.width * 0.5,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height,
        size.width,
        size.height * 0.35,
      );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _drawDashedPath(canvas, path, paint, dashLength: 4, gapLength: 5);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final segmentLength = draw ? dashLength : gapLength;
        final next = math.min(distance + segmentLength, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SquigglePainter oldDelegate) =>
      oldDelegate.color != color;
}
