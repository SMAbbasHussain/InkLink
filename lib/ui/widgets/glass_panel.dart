import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';

/// A frosted glass surface: blur + translucent fill + hairline stroke.
/// Used for floating bars, trays, dialogs, bottom sheets and menus.
class GlassPanel extends StatelessWidget {
  final Widget? child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool accentGlow;
  final BorderRadiusGeometry? borderRadius;

  const GlassPanel({
    super.key,
    this.child,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.accentGlow = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final radiusGeometry = borderRadius ?? BorderRadius.circular(radius);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radiusGeometry,
        boxShadow: accentGlow ? tokens.accentGlowShadow : tokens.glassShadow,
      ),
      child: ClipRRect(
        borderRadius: radiusGeometry,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.glassBlurSigma,
            sigmaY: tokens.glassBlurSigma,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tokens.glass,
              borderRadius: radiusGeometry,
              border: Border.all(
                color: accentGlow
                    ? tokens.accentGlowBorder.color
                    : tokens.glassStroke,
                width: accentGlow ? tokens.accentGlowBorder.width : 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
