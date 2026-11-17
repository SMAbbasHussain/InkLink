import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../../../ui/widgets/ink_segmented.dart';
import '../../bloc/ai_image_state.dart';
import '../widgets/ai_image_widgets.dart';
import '../widgets/sliding_tray.dart';

/// Everything the tray needs for working AI image generation.
class AiTrayGeneration {
  /// False for viewers: the controls are shown disabled with an explanation.
  final bool canEdit;
  final bool isGenerating;
  final String aspectRatio;
  final ValueChanged<String> onAspectRatioChanged;
  final VoidCallback onGenerate;

  const AiTrayGeneration({
    required this.canEdit,
    required this.isGenerating,
    required this.aspectRatio,
    required this.onAspectRatioChanged,
    required this.onGenerate,
  });
}

class AITray extends StatelessWidget {
  final bool isOpen;
  final TextEditingController controller;
  final VoidCallback onAddText;
  final VoidCallback onUploadImage;
  final VoidCallback onGenerateImage;
  final List<Uint8List> recentImages;
  final VoidCallback? onClose;

  /// Working AI generation controls. When null (feature switched off) the
  /// tray shows the original "coming soon" button wired to [onGenerateImage].
  final AiTrayGeneration? generation;

  const AITray({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onAddText,
    required this.onUploadImage,
    required this.onGenerateImage,
    required this.recentImages,
    this.onClose,
    this.generation,
  });

  List<Widget> _buildGenerationControls(
    InkTokens tokens,
    AiTrayGeneration generation,
  ) {
    final selectedIndex = kAiAspectRatios.indexOf(generation.aspectRatio);
    return [
      const SizedBox(height: InkSpacing.s4),
      Align(
        alignment: Alignment.centerRight,
        child: AiPromptCounter(controller: controller),
      ),
      const SizedBox(height: InkSpacing.s8),
      Text('Shape', style: InkType.label(tokens.inkMuted)),
      const SizedBox(height: InkSpacing.s8),
      IgnorePointer(
        ignoring: !generation.canEdit || generation.isGenerating,
        child: Opacity(
          opacity: generation.canEdit ? 1 : 0.5,
          child: InkSegmented(
            labels: kAiAspectRatios,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onChanged: (index) =>
                generation.onAspectRatioChanged(kAiAspectRatios[index]),
          ),
        ),
      ),
      const SizedBox(height: InkSpacing.s12),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final ready =
              generation.canEdit &&
              !generation.isGenerating &&
              isValidAiPrompt(value.text);
          return InkButton.primary(
            label: generation.isGenerating ? 'Generating...' : 'Generate Image',
            icon: const Icon(LucideIcons.sparkles),
            isLoading: generation.isGenerating,
            onPressed: ready ? generation.onGenerate : null,
          );
        },
      ),
      const SizedBox(height: InkSpacing.s8 + 2),
      Text(
        !generation.canEdit
            ? 'Only editors can generate images on this board.'
            : generation.isGenerating
            ? 'You can keep drawing while the image is generated.'
            : 'The image appears in the middle of your view.',
        style: InkType.caption(tokens.inkMuted),
      ),
    ];
  }

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
                  if (generation != null)
                    ..._buildGenerationControls(tokens, generation!)
                  else ...[
                  const SizedBox(height: InkSpacing.s12),
                  InkButton.secondary(
                    label: 'Generate Image (Soon)',
                    icon: const Icon(LucideIcons.sparkles),
                    onPressed: onGenerateImage,
                  ),
                  const SizedBox(height: InkSpacing.s8 + 2),
                  Text(
                    'Generation integration is coming next.',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                  ],
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
