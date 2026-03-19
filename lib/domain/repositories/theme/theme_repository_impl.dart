import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_repository.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  static const _key = 'theme_mode';

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      mode.name,
    ); // Saves 'light', 'dark', or 'system'
  }

  @override
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeName = prefs.getString(_key);

    if (themeName == null) return ThemeMode.system;

    return ThemeMode.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => ThemeMode.system,
    );
  }
}
