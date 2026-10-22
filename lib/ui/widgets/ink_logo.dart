import 'package:flutter/material.dart';

/// The real InkLink app icon (images/app_icon.png) clipped to a rounded tile.
/// Use this anywhere the brand mark is shown so it never drifts from the
/// launcher icon.
class InkLogo extends StatelessWidget {
  final double size;

  const InkLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
