import 'package:flutter/material.dart';

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
      // FIX: Changed from non-existent offsetToVector to easeOutBack
      curve: Curves.easeOutBack,
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: SizedBox(
        width: width,
        height: height,
        child: GlassPanel(
          radius: InkRadii.glassBar,
          child: Column(
            children: [
              // Header Handle (UX cue for swiping)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: InkSpacing.s12,
                  horizontal: InkSpacing.s16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: InkType.bodyStrong(tokens.ink)),
                    ),
                    ?headerActions,
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.glassStroke),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
