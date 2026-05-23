import 'package:flutter/material.dart';
import 'package:inklink/core/constants/app_colors.dart';

import '../widgets/sliding_tray.dart';
import 'canvas_shape_type.dart';

class ShapesTray extends StatelessWidget {
  final bool isOpen;
  final ValueChanged<CanvasShapeType> onAddShape;

  const ShapesTray({super.key, required this.isOpen, required this.onAddShape});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color backGroundColor = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    final items = <({IconData icon, String label, CanvasShapeType type})>[
      (
        icon: Icons.square_outlined,
        label: 'Square',
        type: CanvasShapeType.square,
      ),
      (
        icon: Icons.rectangle_outlined,
        label: 'Rect',
        type: CanvasShapeType.rectangle,
      ),
      (
        icon: Icons.circle_outlined,
        label: 'Circle',
        type: CanvasShapeType.circle,
      ),
      (
        icon: Icons.egg_outlined,
        label: 'Ellipse',
        type: CanvasShapeType.ellipse,
      ),
      (
        icon: Icons.change_history,
        label: 'Triangle',
        type: CanvasShapeType.triangle,
      ),
      (icon: Icons.diamond, label: 'Diamond', type: CanvasShapeType.diamond),
      (icon: Icons.star_border, label: 'Star', type: CanvasShapeType.star),
      (
        icon: Icons.pentagon_outlined,
        label: 'Pentagon',
        type: CanvasShapeType.pentagon,
      ),
      (
        icon: Icons.hexagon_outlined,
        label: 'Hexagon',
        type: CanvasShapeType.hexagon,
      ),
      (icon: Icons.horizontal_rule, label: 'Line', type: CanvasShapeType.line),
      (
        icon: Icons.align_horizontal_left_rounded,
        label: 'Semicircle',
        type: CanvasShapeType.semicircle,
      ),
    ];

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Shapes',
      height: 360,
      width: 244,
      bottomOffset: 60,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return InkWell(
            onTap: () => onAddShape(item.type),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: backGroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
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
