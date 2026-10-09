import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import 'ink_tilt.dart';

/// A white/"paper" sheet: radius 6, the three-layer paper shadow, an
/// optional tape strip and an optional deterministic tilt.
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// When set, a 46x16 tape strip is centered on the top edge.
  final bool showTape;

  /// When set, derives a tilt between -2.5deg and +2.5deg from this id.
  final String? tiltId;

  final Clip clipBehavior;

  const PaperCard({
    super.key,
    required this.child,
    this.padding,
    this.showTape = false,
    this.tiltId,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final radius = BorderRadius.circular(6);

    Widget card = Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: radius,
        boxShadow: tokens.paperShadow,
      ),
      child: child,
    );

    if (showTape) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: inkDeterministicTilt(tiltId ?? 'tape', maxDegrees: 4),
                child: Container(
                  width: 46,
                  height: 16,
                  decoration: BoxDecoration(
                    color: tokens.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (tiltId != null) {
      return Transform.rotate(
        angle: inkDeterministicTilt(tiltId!),
        child: card,
      );
    }

    return card;
  }
}
