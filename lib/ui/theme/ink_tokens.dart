import 'package:flutter/material.dart';

import 'ink_colors.dart';

/// Spacing, radii, shadow and blur constants for the Desk redesign.
/// These do not vary between light and dark.
class InkSpacing {
  const InkSpacing._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// The screen gutter.
  static const double gutter = 20;
}

class InkRadii {
  const InkRadii._();

  static const double chip = 8;
  static const double segmentedTab = 10;
  static const double input = 14;
  static const double button = 14;
  static const double glassBar = 22;
  static const double bottomSheet = 28;
  static const double dialog = 28;
  static const double menu = 18;

  /// Deliberately small, it's paper.
  static const double paperCard = 6;
  static const double card = 16;
  static const double pill = 30;

  static const double stickyNote = 3;
  static const double stickyNoteCorner = 22;
}

class InkBlur {
  const InkBlur._();

  static const double glassSigma = 20;
}

/// Theme-aware design tokens, read anywhere with `context.ink`.
@immutable
class InkTokens extends ThemeExtension<InkTokens> {
  final Brightness brightness;

  final Color surfaceDesk;
  final Color deskDot;
  final Color paper;
  final Color glass;
  final Color glassStroke;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color field;
  final Color accent;
  final Color accentText;
  final Color accentSoft;
  final Color success;
  final Color pending;
  final Color danger;

  const InkTokens({
    required this.brightness,
    required this.surfaceDesk,
    required this.deskDot,
    required this.paper,
    required this.glass,
    required this.glassStroke,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.field,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.success,
    required this.pending,
    required this.danger,
  });

  factory InkTokens.light() => const InkTokens(
    brightness: Brightness.light,
    surfaceDesk: InkColors.surfaceDeskLight,
    deskDot: InkColors.deskDotLight,
    paper: InkColors.paperLight,
    glass: InkColors.glassLight,
    glassStroke: InkColors.glassStrokeLight,
    ink: InkColors.inkLight,
    inkSecondary: InkColors.inkSecondaryLight,
    inkMuted: InkColors.inkMutedLight,
    field: InkColors.fieldLight,
    accent: InkColors.accent,
    accentText: InkColors.accentTextLight,
    accentSoft: InkColors.accentSoftLight,
    success: InkColors.successLight,
    pending: InkColors.pendingLight,
    danger: InkColors.dangerLight,
  );

  factory InkTokens.dark() => const InkTokens(
    brightness: Brightness.dark,
    surfaceDesk: InkColors.surfaceDeskDark,
    deskDot: InkColors.deskDotDark,
    paper: InkColors.paperDark,
    glass: InkColors.glassDark,
    glassStroke: InkColors.glassStrokeDark,
    ink: InkColors.inkDark,
    inkSecondary: InkColors.inkSecondaryDark,
    inkMuted: InkColors.inkMutedDark,
    field: InkColors.fieldDark,
    accent: InkColors.accent,
    accentText: InkColors.accentTextDark,
    accentSoft: InkColors.accentSoftDark,
    success: InkColors.successDark,
    pending: InkColors.pendingDark,
    danger: InkColors.dangerDark,
  );

  bool get isDark => brightness == Brightness.dark;

  /// Sticky-note palette, content-like surfaces only. Shared across themes.
  List<Color> get stickyPalette => InkColors.stickyPalette;

  Color stickyInkFor(Color sticky) => InkColors.stickyInkFor(sticky);

  Color stickyForId(String id) => InkColors.stickyForId(id);

  /// The single accent gradient (Login / Sign Up / New Board only).
  LinearGradient get accentGradient => InkColors.accentGradient;

  /// Three-layer paper shadow, 6% black each.
  List<BoxShadow> get paperShadow => const [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 1),
      blurRadius: 1,
    ),
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 6),
      blurRadius: 12,
    ),
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 18),
      blurRadius: 28,
    ),
  ];

  /// Glass shadow: 8% black (light) or 35% (dark).
  List<BoxShadow> get glassShadow => [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, isDark ? 0.35 : 0.08),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  /// Warm, soft shadow used under sticky notes.
  List<BoxShadow> get stickyShadow => [
    BoxShadow(
      color: Color.fromRGBO(120, 90, 30, isDark ? 0.28 : 0.16),
      offset: const Offset(0, 6),
      blurRadius: 14,
    ),
  ];

  /// Accent glow used only on the command bar.
  List<BoxShadow> get accentGlowShadow => [
    BoxShadow(
      color: accent.withValues(alpha: 0.22),
      blurRadius: 32,
    ),
  ];

  BorderSide get accentGlowBorder =>
      BorderSide(color: accent.withValues(alpha: 0.35), width: 1.5);

  BorderSide get glassBorder => BorderSide(color: glassStroke, width: 1);

  double get glassBlurSigma => InkBlur.glassSigma;

  @override
  InkTokens copyWith({
    Brightness? brightness,
    Color? surfaceDesk,
    Color? deskDot,
    Color? paper,
    Color? glass,
    Color? glassStroke,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? field,
    Color? accent,
    Color? accentText,
    Color? accentSoft,
    Color? success,
    Color? pending,
    Color? danger,
  }) {
    return InkTokens(
      brightness: brightness ?? this.brightness,
      surfaceDesk: surfaceDesk ?? this.surfaceDesk,
      deskDot: deskDot ?? this.deskDot,
      paper: paper ?? this.paper,
      glass: glass ?? this.glass,
      glassStroke: glassStroke ?? this.glassStroke,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      field: field ?? this.field,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      pending: pending ?? this.pending,
      danger: danger ?? this.danger,
    );
  }

  @override
  InkTokens lerp(ThemeExtension<InkTokens>? other, double t) {
    if (other is! InkTokens) return this;
    // Tokens switch per theme-mode rather than animate; snap at the midpoint
    // to avoid producing muddy intermediate colors during theme transitions.
    return t < 0.5 ? this : other;
  }
}
