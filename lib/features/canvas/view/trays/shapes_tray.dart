import 'package:flutter/material.dart';

import '../widgets/sliding_tray.dart';
import 'canvas_shape_type.dart';

class ShapesTray extends StatelessWidget {
  final bool isOpen;
  final ValueChanged<CanvasShapeType> onAddShape;

  const ShapesTray({super.key, required this.isOpen, required this.onAddShape});

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[
      Icons.square_outlined,
      Icons.circle_outlined,
      Icons.change_history,
      Icons.star_border,
      Icons.pentagon_outlined,
      Icons.horizontal_rule,
    ];

    final shapeTypes = <CanvasShapeType>[
      CanvasShapeType.square,
      CanvasShapeType.circle,
      CanvasShapeType.triangle,
      CanvasShapeType.star,
      CanvasShapeType.pentagon,
      CanvasShapeType.line,
    ];

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Shapes',
      height: 220,
      width: 200,
      bottomOffset: 60,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemCount: icons.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => onAddShape(shapeTypes[i]),
          borderRadius: BorderRadius.circular(12),
          child: Icon(icons[i], size: 30),
        ),
      ),
    );
  }
}
