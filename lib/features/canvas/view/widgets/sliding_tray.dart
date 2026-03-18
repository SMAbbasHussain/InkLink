import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum TrayDirection { left, right, top, bottom }

class SlidingTray extends StatelessWidget {
  final bool isOpen;
  final TrayDirection direction;
  final Widget child;
  final double width;
  final double height;
  final String title;
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
    this.topOffset,
    this.bottomOffset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate off-screen positions
    double? top, bottom, left, right;

    switch (direction) {
      case TrayDirection.left:
        left = isOpen ? 10 : -width - 20; // Extra offset for shadow
        top = topOffset ?? (bottomOffset == null ? 100.0 : null);
        bottom = bottomOffset;
        break;
      case TrayDirection.right:
        right = isOpen ? 10 : -width - 20;
        top = topOffset ?? (bottomOffset == null ? 100.0 : null);
        bottom = bottomOffset;
        break;
      case TrayDirection.top:
        top = isOpen ? 10 : -height - 20;
        left = MediaQuery.of(context).size.width / 2 - (width / 2);
        break;
      case TrayDirection.bottom:
        bottom = isOpen ? 20 : -height - 20;
        left = 20;
        right = 20;
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
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Handle (UX cue for swiping)
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16,
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
