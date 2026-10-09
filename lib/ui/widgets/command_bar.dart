import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'glass_panel.dart';

/// The glass command bar with the accent glow, a sparkles icon, a text
/// field and trailing action slots (e.g. Join Board / New Board).
class CommandBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSend;
  final List<Widget> trailing;

  const CommandBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onSubmitted,
    this.onSend,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return GlassPanel(
      radius: InkRadii.glassBar,
      accentGlow: true,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(LucideIcons.sparkles, size: 18, color: tokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              style: InkType.body(tokens.ink),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: InkType.body(tokens.inkMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onSend != null)
            IconButton(
              tooltip: 'Send',
              icon: Icon(LucideIcons.send, size: 18, color: tokens.accent),
              onPressed: onSend,
            ),
          for (final action in trailing) ...[
            const SizedBox(width: 6),
            action,
          ],
        ],
      ),
    );
  }
}

/// A square glass/field icon-button used as a CommandBar trailing action
/// (e.g. Join Board, New Board).
class CommandBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? iconColor;

  const CommandBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.gradient,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final bg = backgroundColor ?? tokens.field;
    final fg = iconColor ?? tokens.ink;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: gradient == null ? bg : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed,
              child: Icon(icon, size: 20, color: gradient != null ? Colors.white : fg),
            ),
          ),
        ),
      ),
    );
  }
}
