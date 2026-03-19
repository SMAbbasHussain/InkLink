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
      height: 230,
      width: 200,
      bottomOffset: 60,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.undo, color: Colors.blue),
            title: const Text('Undo', style: TextStyle(fontSize: 14)),
            onTap: onUndo,
          ),
          ListTile(
            leading: const Icon(Icons.redo, color: Colors.blue),
            title: const Text('Redo', style: TextStyle(fontSize: 14)),
            onTap: onRedo,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Clear All', style: TextStyle(fontSize: 14)),
            onTap: onClearAll,
          ),
        ],
      ),
    );
  }
}
