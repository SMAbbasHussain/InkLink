import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../trays/canvas_shape_type.dart';

/// Floating popup opened when clicking the Shapes icon, allowing the user to
/// choose a geometric shape to draw on the canvas.
class ShapesPickerPopup extends StatelessWidget {
  final CanvasShapeType? selectedType;
  final ValueChanged<CanvasShapeType> onSelectShape;
  final VoidCallback onClose;

  const ShapesPickerPopup({
    super.key,
    required this.onSelectShape,
    required this.onClose,
    this.selectedType,
  });

  static const _items =
      <({IconData icon, String label, CanvasShapeType type})>[
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
        (
          icon: LucideIcons.triangle,
          label: 'Triangle',
          type: CanvasShapeType.triangle,
        ),
        (
          icon: LucideIcons.diamond,
          label: 'Diamond',
          type: CanvasShapeType.diamond,
        ),
        (icon: LucideIcons.star, label: 'Star', type: CanvasShapeType.star),
        (
          icon: LucideIcons.pentagon,
          label: 'Pentagon',
          type: CanvasShapeType.pentagon,
        ),
        (
          icon: LucideIcons.hexagon,
          label: 'Hexagon',
          type: CanvasShapeType.hexagon,
        ),
        (icon: LucideIcons.minus, label: 'Line', type: CanvasShapeType.line),
        (
          // Painted by SemicircleIcon below.
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 296),
      child: Material(
        color: tokens.paper,
        elevation: 10,
        borderRadius: BorderRadius.circular(InkRadii.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InkRadii.card),
            border: Border.all(color: tokens.glassStroke),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.shapes, size: 16, color: tokens.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Choose a Shape',
                      style: InkType.bodyStrong(tokens.ink),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(InkRadii.chip),
                    onTap: onClose,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final selected = selectedType == item.type;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelectShape(item.type);
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
                            style: InkType.caption(
                              selected ? tokens.accentText : tokens.inkMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A crisp vector icon depicting an upper semicircle with a flat base,
/// matching Lucide icon geometry and stroke styling.
class SemicircleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SemicircleIcon({super.key, this.size = 22, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SemicircleIconPainter(color: color),
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

    final margin = size.width * 0.14;
    final diameter = size.width - margin * 2;
    final radius = diameter / 2;
    final centerY = size.height / 2 + radius * 0.38;
    final arcRect = Rect.fromCircle(
      center: Offset(size.width / 2, centerY),
      radius: radius,
    );

    final path = Path()
      ..arcTo(arcRect, math.pi, math.pi, true)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SemicircleIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
