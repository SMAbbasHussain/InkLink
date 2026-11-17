import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../bloc/ai_image_state.dart';

/// Loading box shown on the canvas while an AI image is being generated.
class AiImagePlaceholderBox extends StatelessWidget {
  final String prompt;

  const AiImagePlaceholderBox({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.card),
        border: Border.all(color: tokens.accent, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InkRadii.card),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // When zoomed far out there is only room for the spinner.
            final showText =
                constraints.maxHeight >= 96 && constraints.maxWidth >= 96;
            return Padding(
              padding: EdgeInsets.all(showText ? InkSpacing.s12 : InkSpacing.s4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: tokens.accent,
                    ),
                  ),
                  if (showText) ...[
                    const SizedBox(height: InkSpacing.s8),
                    Text(
                      'Generating image...',
                      style: InkType.label(tokens.ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: InkSpacing.s4),
                    Flexible(
                      child: Text(
                        prompt,
                        style: InkType.caption(tokens.inkMuted),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dimmed spinner drawn over an image while it is being edited by AI.
class AiImageBusyOverlay extends StatelessWidget {
  const AiImageBusyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceDesk.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: tokens.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small action bar shown for a selected AI image.
class AiImageActionBar extends StatelessWidget {
  /// False for viewers: the actions are shown disabled with an explanation.
  final bool canEdit;

  /// True while a request for this image is running.
  final bool isBusy;
  final VoidCallback onEditWithAi;
  final VoidCallback onRepaintArea;
  final VoidCallback onRegenerate;

  const AiImageActionBar({
    super.key,
    required this.canEdit,
    required this.isBusy,
    required this.onEditWithAi,
    required this.onRepaintArea,
    required this.onRegenerate,
  });

  static const String viewerExplanation = 'Only editors can use AI on images';

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final enabled = canEdit && !isBusy;

    Widget action(IconData icon, String label, VoidCallback onTap) {
      final color = enabled ? tokens.ink : tokens.inkMuted;
      return Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(InkRadii.chip),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: InkSpacing.s8,
              vertical: InkSpacing.s8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: InkSpacing.s4),
                Text(label, style: InkType.label(color)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: GlassPanel(
        radius: InkRadii.menu,
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                action(LucideIcons.sparkles, 'Edit with AI', onEditWithAi),
                action(LucideIcons.brush, 'Repaint area', onRepaintArea),
                action(LucideIcons.refreshCw, 'Regenerate', onRegenerate),
              ],
            ),
            if (!canEdit)
              Padding(
                padding: const EdgeInsets.only(bottom: InkSpacing.s4),
                child: Text(
                  viewerExplanation,
                  style: InkType.caption(tokens.inkMuted),
                ),
              )
            else if (isBusy)
              Padding(
                padding: const EdgeInsets.only(bottom: InkSpacing.s4),
                child: Text(
                  'Working on this image...',
                  style: InkType.caption(tokens.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "12/1000" counter that turns red past the limit.
class AiPromptCounter extends StatelessWidget {
  final TextEditingController controller;

  const AiPromptCounter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = value.text.trim().length;
        final tooLong = length > kAiMaxPromptLength;
        return Text(
          '$length/$kAiMaxPromptLength',
          style: InkType.caption(tooLong ? tokens.danger : tokens.inkMuted),
        );
      },
    );
  }
}

/// True when [text] is a prompt the server will accept.
bool isValidAiPrompt(String text) {
  final length = text.trim().length;
  return length > 0 && length <= kAiMaxPromptLength;
}

/// Asks for an AI instruction. Returns the trimmed prompt, or null when the
/// dialog was cancelled.
Future<String?> showAiPromptDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  String confirmLabel = 'Apply',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _AiPromptDialog(
      title: title,
      hintText: hintText,
      confirmLabel: confirmLabel,
    ),
  );
}

class _AiPromptDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String confirmLabel;

  const _AiPromptDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
  });

  @override
  State<_AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends State<_AiPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isValidAiPrompt(_controller.text)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: widget.title,
      icon: LucideIcons.sparkles,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkTextField(
            controller: _controller,
            hintText: widget.hintText,
            autofocus: true,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: InkSpacing.s4),
          AiPromptCounter(controller: _controller),
        ],
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          compact: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => InkButton.primary(
            label: widget.confirmLabel,
            compact: true,
            onPressed: isValidAiPrompt(value.text) ? _submit : null,
          ),
        ),
      ],
    );
  }
}
