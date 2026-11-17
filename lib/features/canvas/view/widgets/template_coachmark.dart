import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';

/// One-time, dismissible pointer to the template gallery. Deliberately small
/// and non-modal so an empty board stays clean.
class TemplateCoachmark extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const TemplateCoachmark({
    super.key,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Semantics(
      container: true,
      label: 'Templates are available in the Tools tray',
      child: Material(
        color: tokens.paper,
        elevation: 5,
        borderRadius: BorderRadius.circular(InkRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(InkRadii.card),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.layoutTemplate,
                  size: 18,
                  color: tokens.accent,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need a starting point?',
                      style: InkType.caption(
                        tokens.inkMuted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Templates are in Tools',
                      style: InkType.bodyStrong(tokens.ink),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Dismiss template hint',
                  splashRadius: 16,
                  iconSize: 16,
                  onPressed: onDismiss,
                  icon: Icon(LucideIcons.x, color: tokens.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
