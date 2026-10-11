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
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ?headerActions,
                    if (onClose != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
