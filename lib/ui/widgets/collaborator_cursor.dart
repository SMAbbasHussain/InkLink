import 'package:flutter/material.dart';

import '../theme/ink_type.dart';

/// A decorative arrow cursor plus a name pill, used on the Login/Register
/// hero. Purely decorative — excluded from semantics by the caller.
class CollaboratorCursor extends StatelessWidget {
  final String name;
  final Color color;

  const CollaboratorCursor({super.key, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(14, 18),
          painter: _CursorArrowPainter(color: color),
        ),
        Transform.translate(
          offset: const Offset(10, -2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name,
              style: InkType.label(Colors.white).copyWith(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _CursorArrowPainter extends CustomPainter {
  final Color color;

  _CursorArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width * 0.4, size.height * 0.72)
      ..lineTo(size.width, size.height * 0.55)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CursorArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
