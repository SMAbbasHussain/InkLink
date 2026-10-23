import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';

/// The dot-grid "desk" surface used behind Login/Register, Home, Workspaces,
/// Friends and the Profile header. Purely decorative.
class DeskBackground extends StatelessWidget {
  final Widget? child;

  const DeskBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      color: tokens.surfaceDesk,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _DotGridPainter(dotColor: tokens.deskDot)),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color dotColor;
  static const double spacing = 20;
  static const double dotRadius = 1.3 / 2;

  _DotGridPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
