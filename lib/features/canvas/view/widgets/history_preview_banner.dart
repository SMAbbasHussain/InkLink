import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';

/// Top bar shown while the owner is previewing a past version or inspecting an
/// undo request's evidence. It owns the top of the screen in preview mode (the
/// live top pills are hidden), with the exit cross at the top-left.
class HistoryPreviewBanner extends StatelessWidget {
  final int? version;
  final String? title;
  final String? requestId;
  final bool showsDesired;
  final VoidCallback? onRestore;
  final VoidCallback onExit;
  final ValueChanged<bool>? onToggleDesired;
  final VoidCallback? onReview;

  const HistoryPreviewBanner({
    super.key,
    this.version,
    this.title,
    this.requestId,
    this.showsDesired = false,
    this.onRestore,
    required this.onExit,
    this.onToggleDesired,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final isEvidence = requestId != null;
    final heading = title ??
        (isEvidence
            ? 'Undo request evidence'
            : 'Viewing version ${version ?? '—'}');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.s12,
          InkSpacing.s8,
          InkSpacing.s12,
          0,
        ),
        child: GlassPanel(
          radius: InkRadii.chip,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s8,
            vertical: InkSpacing.s8,
          ),
          accentGlow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ExitButton(onTap: onExit),
                  const SizedBox(width: InkSpacing.s8),
                  Icon(
                    isEvidence ? LucideIcons.eye : LucideIcons.history,
                    size: 16,
                    color: tokens.accentText,
                  ),
                  const SizedBox(width: InkSpacing.s8),
                  Expanded(
                    child: Text(
                      heading,
                      style: InkType.bodyStrong(tokens.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isEvidence && onReview != null) ...[
                    const SizedBox(width: InkSpacing.s4),
                    _BannerAction(
                      icon: LucideIcons.undo2,
                      label: 'Review',
                      color: tokens.accentText,
                      onTap: onReview!,
                    ),
                  ] else if (!isEvidence &&
                      version != null &&
                      onRestore != null)
                    _BannerAction(
                      icon: LucideIcons.undo2,
                      label: 'Restore',
                      color: tokens.accentText,
                      onTap: onRestore!,
                    ),
                ],
              ),
              if (isEvidence) ...[
                const SizedBox(height: InkSpacing.s4),
                Align(
                  alignment: Alignment.centerRight,
                  child: _DesiredToggle(
                    showsDesired: showsDesired,
                    onChanged: onToggleDesired,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Container(
        padding: const EdgeInsets.all(InkSpacing.s4),
        decoration: BoxDecoration(
          color: tokens.field,
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        child: Icon(LucideIcons.x, size: 16, color: tokens.ink),
      ),
    );
  }
}

class _DesiredToggle extends StatelessWidget {
  final bool showsDesired;
  final ValueChanged<bool>? onChanged;

  const _DesiredToggle({required this.showsDesired, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'Current', !showsDesired, false),
          _segment(context, 'Requested', showsDesired, true),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    bool active,
    bool desired,
  ) {
    final tokens = context.ink;
    return InkWell(
      onTap: () => onChanged?.call(desired),
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: active ? tokens.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        child: Text(
          label,
          style: InkType.caption(
            active ? tokens.accentText : tokens.inkSecondary,
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
