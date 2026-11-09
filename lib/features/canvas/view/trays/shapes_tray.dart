import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../widgets/sliding_tray.dart';
import 'canvas_shape_type.dart';

class ShapesTray extends StatelessWidget {
  final bool isOpen;
  final ValueChanged<CanvasShapeType> onSelectShapeForDrawing;
  final CanvasShapeType? selectedType;
  final VoidCallback? onClose;

  const ShapesTray({
    super.key,
    required this.isOpen,
    required this.onSelectShapeForDrawing,
    this.selectedType,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    final items = <({IconData icon, String label, CanvasShapeType type})>[
      (icon: LucideIcons.square, label: 'Square', type: CanvasShapeType.square),
      (
        icon: LucideIcons.rectangleHorizontal,
        label: 'Rect',
        type: CanvasShapeType.rectangle,
      ),
      (icon: LucideIcons.circle, label: 'Circle', type: CanvasShapeType.circle),
      (
        // No dedicated "ellipse" glyph in Lucide; closest stand-in.
        icon: LucideIcons.circle,
        label: 'Ellipse',
        type: CanvasShapeType.ellipse,
      ),
      (icon: LucideIcons.triangle, label: 'Triangle', type: CanvasShapeType.triangle),
      (icon: LucideIcons.diamond, label: 'Diamond', type: CanvasShapeType.diamond),
      (icon: LucideIcons.star, label: 'Star', type: CanvasShapeType.star),
      (icon: LucideIcons.pentagon, label: 'Pentagon', type: CanvasShapeType.pentagon),
      (icon: LucideIcons.hexagon, label: 'Hexagon', type: CanvasShapeType.hexagon),
      (icon: LucideIcons.minus, label: 'Line', type: CanvasShapeType.line),
      (
        // No dedicated "semicircle" glyph in Lucide; closest stand-in.
        icon: LucideIcons.circle,
        label: 'Semicircle',
        type: CanvasShapeType.semicircle,
      ),
      (
        icon: LucideIcons.arrowRight,
        label: 'Arrow',
        type: CanvasShapeType.arrow,
      ),
    ];

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Shapes',
      height: 360,
      width: 244,
      bottomOffset: 60,
      onClose: onClose,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = selectedType == item.type;
          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelectShapeForDrawing(item.type);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? tokens.accentSoft : tokens.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.type == CanvasShapeType.semicircle)
                    SemicircleIcon(
                      size: 22,
                      color: selected ? tokens.accent : tokens.ink,
                    )
                  else
                    Icon(
                      item.icon,
                      size: 22,
                      color: selected ? tokens.accent : tokens.ink,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: InkType.caption(selected ? tokens.accentText : tokens.inkMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A crisp vector icon depicting an upper semicircle with a flat base,
/// matching Lucide icon geometry and stroke styling.
class SemicircleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SemicircleIcon({
    super.key,
    this.size = 22,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.88, size * 0.48),
          painter: _SemicircleIconPainter(color: color),
        ),
      ),
    );
  }
}

class _SemicircleIconPainter extends CustomPainter {
  final Color color;

  const _SemicircleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h),
      width: w,
      height: h * 2,
    );
    final path = Path()
      ..arcTo(rect, math.pi, math.pi, false)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SemicircleIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
