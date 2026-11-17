// Design tokens for the web companion's "premium dark glass" look.
//
// Web-only. The shared Ink design system (lib/ui/theme) is NOT modified: the
// web builds its own ThemeData and its own InkTokens instance from the
// public constructor, so shared widgets used on the web pick up glass colours
// while the mobile app keeps its own theme.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';

abstract final class Glass {
  // ── Colours ─────────────────────────────────────────────────────────────
  static const base = Color(0xFF07070B);
  static const violet = Color(0xFF7C5CFF);
  static const indigo = Color(0xFF4F46E5);
  static const magenta = Color(0xFFD946EF);
  static const cyan = Color(0xFF22D3EE);

  static const bg = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)
  static const bgStrong = Color(0x12FFFFFF); // 0.07
  static const bgHover = Color(0x17FFFFFF); // 0.09
  static const border = Color(0x14FFFFFF); // 0.08
  static const borderBright = Color(0x29FFFFFF); // 0.16
  static const highlight = Color(0x0FFFFFFF); // 0.06 top highlight

  static const text = Color(0xF2FFFFFF); // 0.95
  static const textSecondary = Color(0xB3FFFFFF); // 0.70
  static const textMuted = Color(0x8CFFFFFF); // 0.55

  static const accentA = Color(0xFF8B5CF6);
  static const accentB = Color(0xFF6366F1);
  static const accentText = Color(0xFFC4B5FD); // readable violet on dark
  static const danger = Color(0xFFF87171);
  static const success = Color(0xFF34D399);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentA, accentB],
  );

  /// Subtle sheen used on fake-glass cards (no backdrop blur).
  static const sheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x05FFFFFF), Color(0x00FFFFFF)],
    stops: [0, 0.45, 1],
  );

  // ── Shape ───────────────────────────────────────────────────────────────
  static const r10 = 10.0;
  static const r14 = 14.0;
  static const r20 = 20.0;
  static const r28 = 28.0;

  // ── Blur (persistent surfaces only) ─────────────────────────────────────
  static final blur = ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  // ── Shadows: soft, large, low opacity, violet-tinted ────────────────────
  static const shadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x147C5CFF), blurRadius: 40, offset: Offset(0, 8)),
  ];
  static const shadowLifted = [
    BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x267C5CFF), blurRadius: 48, offset: Offset(0, 10)),
  ];

  static List<BoxShadow> glow([double strength = 1]) => [
        BoxShadow(
          color: accentA.withValues(alpha: 0.35 * strength),
          blurRadius: 18,
          spreadRadius: -2,
        ),
      ];

  // ── Motion ──────────────────────────────────────────────────────────────
  static const fast = Duration(milliseconds: 150);
  static const ui = Duration(milliseconds: 250);

  /// True when the user asked the OS / browser for reduced motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  // ── Typography (Geist is bundled with the app) ──────────────────────────
  static const font = 'Geist';

  static TextStyle title({Color color = text}) => TextStyle(
        fontFamily: font,
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8, // -0.02em
        color: color,
      );

  static TextStyle heading({double size = 20, Color color = text}) => TextStyle(
        fontFamily: font,
        fontSize: size,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * size,
        color: color,
      );

  static TextStyle body({Color color = textSecondary, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: font, fontSize: 14.5, height: 1.45, fontWeight: weight, color: color);

  static TextStyle strong({Color color = text}) =>
      TextStyle(fontFamily: font, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600, color: color);

  static TextStyle small({Color color = textMuted, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: font, fontSize: 12.5, height: 1.35, fontWeight: weight, color: color);

  static TextStyle label({Color color = textMuted}) => TextStyle(
        fontFamily: font,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: color,
      );

  // ── Theme ───────────────────────────────────────────────────────────────

  /// Ink tokens tuned for glass, so shared Ink widgets (text fields, chips,
  /// buttons, avatars) blend in on the web. Built from the public constructor;
  /// the shared InkTokens class itself is unchanged.
  static const inkTokens = InkTokens(
    brightness: Brightness.dark,
    surfaceDesk: base,
    deskDot: Color(0x12FFFFFF),
    paper: Color(0xFF12121A),
    glass: bgStrong,
    glassStroke: border,
    ink: text,
    inkSecondary: textSecondary,
    inkMuted: textMuted,
    field: bgStrong,
    accent: accentA,
    accentText: accentText,
    accentSoft: Color(0x298B5CF6),
    success: success,
    pending: Color(0xFFFBBF24),
    danger: danger,
  );

  /// The web companion's signed-in theme: the shared dark theme with glass
  /// tokens, Geist and transparent scaffolds (the aurora shows through).
  static ThemeData theme() {
    final base_ = InkTheme.dark();
    return base_.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      extensions: const [inkTokens],
      textTheme: base_.textTheme.apply(fontFamily: font),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xE6121219),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r14),
          side: const BorderSide(color: borderBright),
        ),
        textStyle: body(color: text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF0101017),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r20),
          side: const BorderSide(color: borderBright),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xF0181822),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderBright),
        ),
        textStyle: small(color: text),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xF0181822),
        contentTextStyle: body(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r14),
          side: const BorderSide(color: borderBright),
        ),
      ),
      focusColor: accentA.withValues(alpha: 0.18),
      hoverColor: Colors.white.withValues(alpha: 0.04),
      splashColor: accentA.withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
    );
  }
}
