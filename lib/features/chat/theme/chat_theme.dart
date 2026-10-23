import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ChatColors {
  final bool isDark;

  const ChatColors({required this.isDark});

  Color get background => isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  Color get surface => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get surfaceElevated => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F3F5);
  Color get cardBorder => isDark ? const Color(0xFF333333) : const Color(0xFFE2E4E8);
  Color get divider => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1A1A);
  Color get textSecondary => isDark ? const Color(0xFFA0A0A5) : const Color(0xFF757575);

  // iMessage bubbles
  Color get outgoingBubble => AppColors.primary;
  Color get outgoingText => Colors.white;
  Color get incomingBubble => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB);
  Color get incomingText => isDark ? Colors.white : const Color(0xFF1C1C1E);

  // Input bar
  Color get inputFill => isDark ? const Color(0xFF252528) : const Color(0xFFEDEDF0);
  Color get inputBorder => isDark ? const Color(0xFF38383A) : const Color(0xFFE0E0E0);
  Color get inputHint => const Color(0xFF8E8E93);
  Color get inputText => isDark ? Colors.white : const Color(0xFF1A1A1A);

  Color get accent => isDark ? const Color(0xFF8257E6) : AppColors.primary;
  Color get accentAlt => isDark ? const Color(0xFF9B84EE) : const Color(0xFF7C4DFF);

  Color get statusOnline => const Color(0xFF34C759);
  Color get statusIdle => const Color(0xFFFF9500);
  Color get statusDnd => const Color(0xFFFF3B30);
  Color get statusOffline => isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93);
}

class ChatTheme {
  static ChatColors colorsOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChatColors(isDark: isDark);
  }

  // Spacing constants
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Fallback static colors for backwards compatibility
  static const Color accent = Color(0xFF6200EE);
  static const Color accentAlt = Color(0xFF7C4DFF);
  static const Color statusOnline = Color(0xFF34C759);
  static const Color statusIdle = Color(0xFFFF9500);
  static const Color statusDnd = Color(0xFFFF3B30);
  static const Color statusOffline = Color(0xFF8E8E93);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceElevated = Color(0xFF2C2C2E);
  static const Color background = Color(0xFF121212);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A5);
  static const Color divider = Color(0xFF2C2C2E);
  static const Color outgoingBubble = Color(0xFF6200EE);
  static const Color incomingBubble = Color(0xFF2C2C2E);

  static const TextStyle usernameStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle timestampStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );
}
