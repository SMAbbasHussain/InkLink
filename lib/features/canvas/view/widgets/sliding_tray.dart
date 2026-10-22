import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';

enum TrayDirection { left, right, top, bottom }

class SlidingTray extends StatelessWidget {
  final bool isOpen;
  final TrayDirection direction;
  final Widget child;
  final double width;
  final double height;
  final String title;
  final Widget? headerActions;
  final double? topOffset;
  final double? bottomOffset;
  final VoidCallback? onClose;

  const SlidingTray({
    super.key,
    required this.isOpen,
    required this.direction,
    required this.child,
    this.width = 250,
    this.height = 300,
    required this.title,
    this.headerActions,
    this.topOffset,
    this.bottomOffset,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    // Calculate off-screen positions
    double? top, bottom, left, right;
    const inset = 12.0;

    switch (direction) {
      case TrayDirection.left:
        left = isOpen ? inset : -width - 20; // Extra offset for shadow
        top = topOffset ?? (bottomOffset == null ? 100.0 : null);
        bottom = bottomOffset;
        break;
      case TrayDirection.right:
        right = isOpen ? inset : -width - 20;
        top = topOffset ?? (bottomOffset == null ? 100.0 : null);
        bottom = bottomOffset;
        break;
      case TrayDirection.top:
        top = isOpen ? inset : -height - 20;
        left = MediaQuery.of(context).size.width / 2 - (width / 2);
        break;
      case TrayDirection.bottom:
        bottom = isOpen ? inset : -height - 20;
        left = inset;
        right = inset;
        break;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) {
          if (direction == TrayDirection.left && d.delta.dx < -8) {
            onClose?.call();
          } else if (direction == TrayDirection.right && d.delta.dx > 8) {
            onClose?.call();
          }
        },
        onVerticalDragUpdate: (d) {
          if (direction == TrayDirection.bottom && d.delta.dy > 8) {
            onClose?.call();
          } else if (direction == TrayDirection.top && d.delta.dy < -8) {
            onClose?.call();
          }
        },
        child: SizedBox(
          width: width,
          height: height,
          child: GlassPanel(
            radius: InkRadii.glassBar,
            child: Column(
              children: [
                // Header Handle (UX cue for swiping)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) {
                    if (direction == TrayDirection.bottom && d.delta.dy > 6) {
                      onClose?.call();
                    } else if (direction == TrayDirection.top && d.delta.dy < -6) {
                      onClose?.call();
                    }
                  },
                  onHorizontalDragUpdate: (d) {
                    if (direction == TrayDirection.left && d.delta.dx < -6) {
                      onClose?.call();
                    } else if (direction == TrayDirection.right && d.delta.dx > 6) {
                      onClose?.call();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.inkMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: InkSpacing.s8,
                    horizontal: InkSpacing.s16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: InkType.bodyStrong(tokens.ink)),
                      ),
                      ?headerActions,
                      if (onClose != null) ...[
                        const SizedBox(width: InkSpacing.s8),
                        InkWell(
                          borderRadius: BorderRadius.circular(InkRadii.chip),
                          onTap: onClose,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              LucideIcons.x,
                              size: 18,
                              color: tokens.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: tokens.glassStroke),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
