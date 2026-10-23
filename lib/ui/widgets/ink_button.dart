import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';

enum InkButtonVariant { primary, hero, secondary, danger, dangerSolid, success }

/// The button variants used across the redesign. All are 48 high
/// (unless [compact]) with radius 14, tactile haptics, and optional [isLoading].
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final InkButtonVariant variant;
  final Widget? icon;
  final bool expand;
  final bool compact;
  final bool isLoading;

  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = InkButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  });

  const InkButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  }) : variant = InkButtonVariant.primary;

  const InkButton.hero({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  }) : variant = InkButtonVariant.hero;

  const InkButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  }) : variant = InkButtonVariant.secondary;

  const InkButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  }) : variant = InkButtonVariant.danger;

  /// Solid danger fill, used for destructive confirmations (e.g. "Delete"
  /// inside a confirm dialog) rather than the transparent `.danger` variant.
  const InkButton.dangerConfirm({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  }) : variant = InkButtonVariant.dangerSolid;

  /// Success green fill (e.g. "Sent", "Request Sent", confirmed actions).
  const InkButton.success({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.isLoading = false,
  }) : variant = InkButtonVariant.success;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final height = compact ? 36.0 : 48.0;
    final disabled = onPressed == null || isLoading;

    Color bg;
    Color fg;
    Gradient? gradient;
    Border? border;

    switch (variant) {
      case InkButtonVariant.primary:
        bg = tokens.accent;
        fg = Colors.white;
        break;
      case InkButtonVariant.hero:
        bg = tokens.accent;
        gradient = tokens.accentGradient;
        fg = Colors.white;
        break;
      case InkButtonVariant.secondary:
        bg = tokens.field;
        fg = tokens.ink;
        break;
      case InkButtonVariant.danger:
        bg = Colors.transparent;
        fg = tokens.danger;
        border = Border.all(color: tokens.danger.withValues(alpha: 0.4));
        break;
      case InkButtonVariant.dangerSolid:
        bg = tokens.danger;
        fg = Colors.white;
        break;
      case InkButtonVariant.success:
        bg = const Color(0xFF16A34A);
        fg = Colors.white;
        break;
    }

    if (disabled && !isLoading) {
      if (variant == InkButtonVariant.success) {
        bg = const Color(0xFF16A34A);
        fg = Colors.white;
        gradient = null;
        border = null;
      } else {
        bg = tokens.field;
        fg = tokens.inkMuted;
        gradient = null;
        border = null;
      }
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        else ...[
          if (icon != null) ...[
            IconTheme(data: IconThemeData(color: fg, size: 18), child: icon!),
            const SizedBox(width: InkSpacing.s8),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: InkType.bodyStrong(fg),
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: gradient == null ? bg : null,
        borderRadius: BorderRadius.circular(InkRadii.button),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(InkRadii.button),
            border: border,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(InkRadii.button),
            onTap: disabled
                ? null
                : () {
                    if (variant == InkButtonVariant.danger ||
                        variant == InkButtonVariant.dangerSolid) {
                      HapticFeedback.mediumImpact();
                    } else {
                      HapticFeedback.lightImpact();
                    }
                    onPressed!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
