import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../widgets/sliding_tray.dart';

class AITray extends StatelessWidget {
  final bool isOpen;
  final TextEditingController controller;
  final VoidCallback onAddText;
  final VoidCallback onUploadImage;
  final VoidCallback onGenerateImage;
  final List<Uint8List> recentImages;
  final VoidCallback? onClose;

  const AITray({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onAddText,
    required this.onUploadImage,
    required this.onGenerateImage,
    required this.recentImages,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Media',
      width: 290,
      height: 420,
      onClose: onClose,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AI Image Generation', style: InkType.label(tokens.inkMuted)),
                  const SizedBox(height: InkSpacing.s8),
                  InkTextField(
                    controller: controller,
                    hintText: 'Describe an image idea...',
                    leadingIcon: LucideIcons.sparkles,
                  ),
                  const SizedBox(height: InkSpacing.s12),
                  InkButton.secondary(
                    label: 'Generate Image (Soon)',
                    icon: const Icon(LucideIcons.sparkles),
                    onPressed: null,
                  ),
                  const SizedBox(height: InkSpacing.s8 + 2),
                  Text(
                    'Generation integration is coming next.',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                  const SizedBox(height: InkSpacing.s12),
                  Divider(height: 1, color: tokens.glassStroke),
                  const SizedBox(height: InkSpacing.s12),
                  Text('Recent Uploads', style: InkType.label(tokens.inkMuted)),
                  const SizedBox(height: InkSpacing.s8),
                  SizedBox(
                    height: 64,
                    child: recentImages.isEmpty
                        ? Container(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No recent images yet.',
                              style: InkType.caption(tokens.inkMuted),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recentImages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(height: InkSpacing.s12),
                  InkButton.secondary(
                    label: 'Upload Image',
                    icon: const Icon(LucideIcons.upload),
                    onPressed: onUploadImage,
                  ),
                  const SizedBox(height: InkSpacing.s8),
                  InkButton.secondary(
                    label: 'Add Prompt As Text Note',
                    icon: const Icon(LucideIcons.fileText),
                    onPressed: onAddText,
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
