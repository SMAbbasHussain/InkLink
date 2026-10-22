import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Desk redesign typography tokens.
///
/// Bricolage Grotesque (via google_fonts) is used for headlines, screen
/// titles, the wordmark and board/workspace names. Everything else uses the
/// bundled Geist family (assets/fonts) registered in pubspec.yaml.
class InkType {
  const InkType._();

  static const String geistFamily = 'Geist';

  static TextStyle _geist({
    required double fontSize,
    required double height,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: geistFamily,
      fontSize: fontSize,
      height: height,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle display(Color color) => GoogleFonts.bricolageGrotesque(
    fontSize: 36,
    height: 0.98,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    color: color,
  );

  static TextStyle headline(Color color) => GoogleFonts.bricolageGrotesque(
    fontSize: 28,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: color,
  );

  static TextStyle title(Color color) => GoogleFonts.bricolageGrotesque(
    fontSize: 20,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: color,
  );

  static TextStyle cardTitle(Color color) => GoogleFonts.bricolageGrotesque(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: color,
  );

  static TextStyle subhead(Color color) =>
      _geist(fontSize: 16, height: 1.35, weight: FontWeight.w600, color: color);

  static TextStyle body(Color color) =>
      _geist(fontSize: 15, height: 1.45, weight: FontWeight.w400, color: color);

  static TextStyle bodyStrong(Color color) =>
      _geist(fontSize: 15, height: 1.45, weight: FontWeight.w600, color: color);

  static TextStyle label(Color color) =>
      _geist(fontSize: 13, height: 1.3, weight: FontWeight.w600, color: color);

  static TextStyle caption(Color color) => _geist(
    fontSize: 11.5,
    height: 1.3,
    weight: FontWeight.w500,
    color: color,
  );
}
