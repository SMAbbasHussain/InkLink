import 'package:flutter/material.dart';

import '../widgets/sliding_tray.dart';

class BrushTray extends StatelessWidget {
  final bool isOpen;
  final double strokeWidth;
  final Color selectedColor;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<Color> onColorSelected;

  const BrushTray({
    super.key,
    required this.isOpen,
    required this.strokeWidth,
    required this.selectedColor,
    required this.onStrokeWidthChanged,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
    ];

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.bottom,
      title: 'Brush & Color',
      height: 180,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.line_weight, size: 18, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: strokeWidth,
                    min: 1,
                    max: 20,
                    onChanged: onStrokeWidthChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: colors
                  .map(
                    (c) => InkWell(
                      onTap: () => onColorSelected(c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: selectedColor == c ? 16 : 14,
                        child: selectedColor == c
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
