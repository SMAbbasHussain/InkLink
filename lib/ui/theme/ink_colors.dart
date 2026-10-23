import 'package:flutter/material.dart';

/// Desk redesign color tokens. Presentation-only — see INKLINK_REDESIGN.md.
class InkColors {
  const InkColors._();

  static const Color surfaceDeskLight = Color(0xFFEDEDF0);
  static const Color surfaceDeskDark = Color(0xFF121418);

  static const Color deskDotLight = Color(0xFFCFCFD6);
  static const Color deskDotDark = Color(0xFF2A2D35);

  static const Color paperLight = Color(0xFFFFFFFF);
  static const Color paperDark = Color(0xFF1B1E24);

  static const Color glassLight = Color(0xB8FFFFFF); // #FFFFFF @ 72%
  static const Color glassDark = Color(0xC71F2229); // #1F2229 @ 78%

  static const Color glassStrokeLight = Color(0x0F0B0B0F); // #0B0B0F @ 6%
  static const Color glassStrokeDark = Color(0x14FFFFFF); // #FFFFFF @ 8%

  static const Color inkLight = Color(0xFF0B0B0F);
  static const Color inkDark = Color(0xFFF2F2F5);

  static const Color inkSecondaryLight = Color(0xFF5A5A64);
  static const Color inkSecondaryDark = Color(0xFFA6A9B4);

  static const Color inkMutedLight = Color(0xFF75757F);
  static const Color inkMutedDark = Color(0xFF8C909B);

  static const Color fieldLight = Color(0xFFF0F0F3);
  static const Color fieldDark = Color(0xFF22252D);

  static const Color accent = Color(0xFF6A4EFF);

  static const Color accentTextLight = Color(0xFF4B32D9);
  static const Color accentTextDark = Color(0xFFA996FF);

  static const Color accentSoftLight = Color(0xFFE7E3FF);
  static const Color accentSoftDark = Color(0xFF2A2452);

  static const Color successLight = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF22C55E);

  static const Color pendingLight = Color(0xFFD97706);
  static const Color pendingDark = Color(0xFFF59E0B);

  static const Color dangerLight = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);

  // Sticky-note palette — content-like surfaces only, never buttons.
  static const Color stickyButter = Color(0xFFFDE68A);
  static const Color stickyRose = Color(0xFFFBCFE8);
  static const Color stickyMint = Color(0xFFBBF7D0);
  static const Color stickySky = Color(0xFFBFDBFE);
  static const Color stickyLilac = Color(0xFFDDD6FE);
  static const Color stickyPeach = Color(0xFFFED7AA);

  static const List<Color> stickyPalette = [
    stickyButter,
    stickyRose,
    stickyMint,
    stickySky,
    stickyLilac,
    stickyPeach,
  ];

  static const Color stickyInkOnButter = Color(0xFF422006);
  static const Color stickyInkDefault = Color(0xFF0B0B0F);

  /// Dark ink text color for a given sticky background.
  static Color stickyInkFor(Color sticky) {
    return sticky == stickyButter ? stickyInkOnButter : stickyInkDefault;
  }

  /// The single accent gradient, used only for Login/Sign-up/New-Board.
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF6A4EFF), Color(0xFF9579FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(135 * 3.1415926535 / 180),
  );

  /// Deterministically picks a sticky pastel for an avatar fallback from an id.
  static Color stickyForId(String id) {
    if (id.isEmpty) return stickyPalette.first;
    final hash = id.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return stickyPalette[hash % stickyPalette.length];
  }
}
