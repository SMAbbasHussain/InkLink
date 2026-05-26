import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/sliding_tray.dart';

class AITray extends StatelessWidget {
  final bool isOpen;
  final TextEditingController controller;
  final VoidCallback onAddText;
  final VoidCallback onUploadImage;
  final VoidCallback onGenerateImage;
  final List<Uint8List> recentImages;

  const AITray({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onAddText,
    required this.onUploadImage,
    required this.onGenerateImage,
    required this.recentImages,
  });

  @override
  Widget build(BuildContext context) {
    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Media',
      width: 290,
      height: 420,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AI Image Generation',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Describe an image idea...',
                      hintStyle: const TextStyle(fontSize: 13),
                      suffixIcon: const Icon(
                        Icons.auto_awesome,
                        color: Colors.blueGrey,
                        size: 20,
                      ),
                      fillColor: Colors.black.withOpacity(0.04),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onGenerateImage,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Generate Image (Soon)'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Generation integration is coming next.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'Recent Uploads',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: recentImages.isEmpty
                        ? Container(
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'No recent images yet.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recentImages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  recentImages[i],
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onUploadImage,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Upload Image'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onAddText,
                      icon: const Icon(Icons.note_add_outlined, size: 16),
                      label: const Text('Add Prompt As Text Note'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
