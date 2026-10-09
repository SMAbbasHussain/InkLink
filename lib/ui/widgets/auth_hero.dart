import 'package:flutter/material.dart';

import '../theme/ink_colors.dart';
import '../theme/ink_theme.dart';
import 'collaborator_cursor.dart';

/// The decorative "live board" hero shown above the auth sheet on Login
/// and Register: a few hand-drawn strokes/shapes plus two collaborator
/// cursors. Static, decorative and excluded from semantics by the caller.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HeroStrokesPainter(
              accent: tokens.accent,
              rose: InkColors.stickyRose,
              mint: InkColors.stickyMint,
            ),
          ),
        ),
        Positioned(
          left: 32,
          top: 70,
          child: CollaboratorCursor(name: 'Alex', color: tokens.accent),
        ),
        const Positioned(
          right: 36,
          top: 40,
          child: CollaboratorCursor(name: 'Sam', color: Color(0xFF16A34A)),
        ),
      ],
    );
  }
}

class _HeroStrokesPainter extends CustomPainter {
  final Color accent;
  final Color rose;
  final Color mint;

  _HeroStrokesPainter({
    required this.accent,
    required this.rose,
    required this.mint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final squiggle = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(w * 0.08, h * 0.62)
      ..quadraticBezierTo(w * 0.25, h * 0.4, w * 0.42, h * 0.58)
      ..quadraticBezierTo(w * 0.58, h * 0.76, w * 0.74, h * 0.5);
    canvas.drawPath(path, squiggle);

    final rosePaint = Paint()
      ..color = rose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rosePath = Path()
      ..moveTo(w * 0.55, h * 0.25)
      ..quadraticBezierTo(w * 0.68, h * 0.14, w * 0.82, h * 0.26);
    canvas.drawPath(rosePath, rosePaint);

    final mintPaint = Paint()
      ..color = mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(w * 0.82, h * 0.6), 22, mintPaint);
  }

  @override
  bool shouldRepaint(covariant _HeroStrokesPainter oldDelegate) => false;
}
