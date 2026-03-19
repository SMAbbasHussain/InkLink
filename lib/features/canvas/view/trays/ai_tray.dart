import 'package:flutter/material.dart';

import '../widgets/sliding_tray.dart';

class AITray extends StatelessWidget {
  final bool isOpen;
  final TextEditingController controller;
  final VoidCallback onAddText;

  const AITray({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onAddText,
  });

  @override
  Widget build(BuildContext context) {
    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'AI Generation',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Describe an object...',
                hintStyle: const TextStyle(fontSize: 13),
                suffixIcon: const Icon(
                  Icons.auto_awesome,
                  color: Colors.purple,
                  size: 20,
                ),
                fillColor: Colors.black.withOpacity(0.05),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddText,
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: const Text('Add As Text Note'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI will generate a vector object for your canvas',
              style: TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
