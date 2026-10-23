import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';

/// Radius-8 chip. Selected chips use `accentSoft`/`accentText`.
class InkChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final Color? backgroundColor;
  final Color? textColor;

  const InkChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDeleted,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final bg = backgroundColor ?? (selected ? tokens.accentSoft : tokens.field);
    final fg = textColor ?? (selected ? tokens.accentText : tokens.ink);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InkRadii.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: InkType.label(fg)),
              if (onDeleted != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDeleted,
                  child: Icon(LucideIcons.x, size: 14, color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
