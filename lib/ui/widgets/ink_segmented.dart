import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'glass_panel.dart';

/// A glass segmented control with a spring-physics sliding selection pill.
class InkSegmented extends StatefulWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const InkSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<InkSegmented> createState() => _InkSegmentedState();
}

class _InkSegmentedState extends State<InkSegmented>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1.5,
    stiffness: 300,
    damping: 25,
  );

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant InkSegmented oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controller.animateWith(
        SpringSimulation(
          _spring,
          _controller.value,
          widget.selectedIndex.toDouble(),
          _controller.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final inverse = tokens.isDark ? Colors.black : Colors.white;
    final labels = widget.labels;
    final n = labels.length;

    return GlassPanel(
      radius: InkRadii.segmentedTab + 6,
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 42,
        child: Stack(
          children: [
            // Sliding selection pill with spring simulation
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
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.ink,
                          borderRadius: BorderRadius.circular(InkRadii.segmentedTab + 4),
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
                    child: InkWell(
                      onTap: () => widget.onChanged(i),
                      borderRadius: BorderRadius.circular(InkRadii.segmentedTab + 4),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: InkType.label(
                            i == widget.selectedIndex ? inverse : tokens.inkMuted,
                          ),
                          child: Text(
                            labels[i],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}
