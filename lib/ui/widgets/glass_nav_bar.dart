import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'glass_panel.dart';

class GlassNavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const GlassNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

/// A floating glass bottom nav. Takes the same `currentIndex`/`onTap`
/// contract the existing nav uses — only the visual layer changes.
class GlassNavBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: SizedBox(
        height: 64,
        child: GlassPanel(
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              children: [
                // Sliding selection pill (Apple-style).
                AnimatedAlign(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(
                    items.length <= 1
                        ? 0
                        : -1 + 2 * currentIndex / (items.length - 1),
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / items.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        borderRadius: BorderRadius.circular(InkRadii.glassBar - 6),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => onTap(i),
                          borderRadius: BorderRadius.circular(InkRadii.glassBar - 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  i == currentIndex
                                      ? items[i].activeIcon
                                      : items[i].inactiveIcon,
                                  key: ValueKey('_'),
                                  color: i == currentIndex
                                      ? tokens.accentText
                                      : tokens.inkMuted,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: InkType.caption(
                                  i == currentIndex
                                      ? tokens.accentText
                                      : tokens.inkMuted,
                                ),
                                child: Text(items[i].label),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),        ),
      ),
    );
  }
}
