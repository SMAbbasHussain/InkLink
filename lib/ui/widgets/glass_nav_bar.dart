import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/ink_theme.dart';
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
///
/// The selection pill is driven by an under-damped spring so it overshoots
/// the target tab, then wobbles back and settles (Apple-style jiggle).
class GlassNavBar extends StatefulWidget {
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
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  // Snappy spring with low damping ratio => fast transition with crisp elastic jiggle.
  static const _spring = SpringDescription(
    mass: 0.6,
    stiffness: 700,
    damping: 22,
  );

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.currentIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant GlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.animateWith(
        SpringSimulation(
          _spring,
          _controller.value,
          widget.currentIndex.toDouble(),
          _controller.velocity,
        ),
      );
    }
  }

  void _handleTap(int index) {
    if (widget.currentIndex != index) {
      HapticFeedback.selectionClick();
      _controller.animateWith(
        SpringSimulation(
          _spring,
          _controller.value,
          index.toDouble(),
          _controller.velocity,
        ),
      );
    }
    widget.onTap(index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final items = widget.items;
    final n = items.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: SizedBox(
        height: 64,
        child: GlassPanel(
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              children: [
                // Sliding, fully rounded selection pill.
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final x = n <= 1 ? 0.0 : -1 + 2 * _controller.value / (n - 1);
                    return Align(
                      alignment: Alignment(x, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / n,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.accentSoft,
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == widget.currentIndex,
                          label: items[i].label,
                          child: Tooltip(
                            message: items[i].label,
                            child: InkWell(
                              onTap: () => _handleTap(i),
                              customBorder: const StadiumBorder(),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    i == widget.currentIndex
                                        ? items[i].activeIcon
                                        : items[i].inactiveIcon,
                                    key: ValueKey('${i}_${i == widget.currentIndex}'),
                                    color: i == widget.currentIndex
                                        ? tokens.accentText
                                        : tokens.inkMuted,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
