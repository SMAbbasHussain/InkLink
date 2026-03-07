import 'package:flutter/material.dart';

/// Centralized gradient definitions - reduces duplication across the app
/// Any UI changes to gradients can be made in one place

class AppGradients {
  // Main app gradient - "Glitter" purple to blue
  static const LinearGradient glitterGradient = LinearGradient(
    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Warm gradient for interactive elements
  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
  );

  // Green gradient for positive actions
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  );

  // Header gradient for light theme
  static const LinearGradient lightHeaderGradient = LinearGradient(
    colors: [Color(0xFF6200EE), Color(0xFF6200EE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Header gradient for dark theme
  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
