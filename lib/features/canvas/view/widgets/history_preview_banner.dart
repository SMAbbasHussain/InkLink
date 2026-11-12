import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';

/// Top banner shown while the owner is previewing a past version.
/// All editing is blocked while it is visible.
class HistoryPreviewBanner extends StatelessWidget {
  final int? version;
  final VoidCallback onRestore;
  final VoidCallback onExit;

  const HistoryPreviewBanner({
    super.key,
    required this.version,
    required this.onRestore,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: InkSpacing.s8),
          child: GlassPanel(
            radius: InkRadii.chip,
            padding: const EdgeInsets.symmetric(
              horizontal: InkSpacing.s12,
              vertical: InkSpacing.s8,
            ),
            accentGlow: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.history, size: 16, color: tokens.accentText),
                const SizedBox(width: InkSpacing.s8),
                Text(
                  'Viewing version ${version ?? '—'}',
                  style: InkType.bodyStrong(tokens.ink),
                ),
                const SizedBox(width: InkSpacing.s12),
                _BannerAction(
                  icon: LucideIcons.undo2,
                  label: 'Restore',
                  color: tokens.accentText,
                  onTap: onRestore,
                ),
                const SizedBox(width: InkSpacing.s4),
                _BannerAction(
                  icon: LucideIcons.x,
                  label: 'Exit',
                  color: tokens.inkSecondary,
                  onTap: onExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BannerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: InkType.caption(color)),
          ],
        ),
      ),
    );
  }
}
