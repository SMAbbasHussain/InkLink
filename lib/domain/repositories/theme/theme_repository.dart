import 'package:flutter/material.dart';

abstract class ThemeRepository {
  Future<void> saveThemeMode(ThemeMode mode);
  Future<ThemeMode> getThemeMode();
}
