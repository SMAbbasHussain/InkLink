import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
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
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == currentIndex
                              ? items[i].activeIcon
                              : items[i].inactiveIcon,
                          color: i == currentIndex ? tokens.ink : tokens.inkMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].label,
                          style: InkType.caption(
                            i == currentIndex ? tokens.ink : tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
