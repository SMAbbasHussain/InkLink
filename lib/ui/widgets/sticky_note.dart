import 'package:flutter/material.dart';

import '../theme/ink_colors.dart';
import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import 'ink_tilt.dart';

/// A sticky-palette note: radius 3 with a 22 bottom-left corner, a tape
/// strip, a soft warm shadow and a slight deterministic tilt.
class StickyNote extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? tiltId;
  final bool showTape;

  const StickyNote({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(InkSpacing.s16),
    this.tiltId,
    this.showTape = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final shape = BorderRadius.only(
      topLeft: const Radius.circular(InkRadii.stickyNote),
      topRight: const Radius.circular(InkRadii.stickyNote),
      bottomRight: const Radius.circular(InkRadii.stickyNote),
      bottomLeft: const Radius.circular(InkRadii.stickyNoteCorner),
    );

    Widget note = Material(
      color: color,
      borderRadius: shape,
      elevation: 0,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: tokens.stickyShadow,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: InkColors.stickyInkFor(color)),
            child: child,
          ),
        ),
      ),
    );

    if (showTape) {
      note = Stack(
        clipBehavior: Clip.none,
        children: [
          note,
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: inkDeterministicTilt('${tiltId ?? 'sticky'}-tape', maxDegrees: 4),
                child: Container(
                  width: 46,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
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
      return Transform.rotate(angle: inkDeterministicTilt(tiltId!), child: note);
    }

    return note;
  }
}
