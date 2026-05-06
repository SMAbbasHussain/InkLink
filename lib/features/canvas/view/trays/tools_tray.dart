import 'package:flutter/material.dart';

import '../widgets/sliding_tray.dart';

class ToolsTray extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClearAll;

  const ToolsTray({
    super.key,
    required this.isOpen,
    required this.onUndo,
    required this.onRedo,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.left,
      title: 'Editing Tools',
      height: 260,
      width: 230,
      bottomOffset: 60,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _ToolButton(
              icon: Icons.undo,
              label: 'Undo',
              color: Colors.blue,
              onTap: onUndo,
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.redo,
              label: 'Redo',
              color: Colors.blue,
              onTap: onRedo,
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: Icons.delete_outline,
              label: 'Clear All',
              color: Colors.red,
              onTap: onClearAll,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
          color: color.withOpacity(0.06),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
