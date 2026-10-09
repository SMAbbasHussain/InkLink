import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'glass_panel.dart';
import 'ink_button.dart';

/// A glass dialog, radius 28, used for every dialog in the redesign
/// (Join Board, Rename, Report user, confirmations, ...).
class InkDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget> actions;

  const InkDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        radius: InkRadii.dialog,
        padding: const EdgeInsets.all(InkSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: InkType.title(tokens.ink)),
            if (content != null) ...[
              const SizedBox(height: InkSpacing.s12),
              content!,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: InkSpacing.s20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: InkSpacing.s8),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a glass confirmation dialog. Destructive confirms use the solid
/// danger button. Returns true if the user confirmed.
Future<bool> showInkConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final tokens = context.ink;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => InkDialog(
      title: title,
      content: Text(message, style: InkType.body(tokens.inkSecondary)),
      actions: [
        InkButton.secondary(
          label: cancelLabel,
          expand: false,
          compact: true,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        destructive
            ? InkButton.dangerConfirm(
                label: confirmLabel,
                expand: false,
                compact: true,
                onPressed: () => Navigator.pop(ctx, true),
              )
            : InkButton.primary(
                label: confirmLabel,
                expand: false,
                compact: true,
                onPressed: () => Navigator.pop(ctx, true),
              ),
      ],
    ),
  );
  return result ?? false;
}
