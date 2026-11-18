import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark switch for the web companion (the header's sun/moon button,
/// like the phone's). The choice is remembered in the browser.
class WebThemeController {
  static const _key = 'web_theme_mode';

  final ValueNotifier<ThemeMode> mode;
  final bool _persist;

  WebThemeController(ThemeMode initial, {bool persist = true})
    : mode = ValueNotifier(initial),
      _persist = persist {
    if (_persist) _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'light') mode.value = ThemeMode.light;
      if (saved == 'dark') mode.value = ThemeMode.dark;
    } catch (_) {
      // Storage can be unavailable (private windows): keep the default.
    }
  }

  /// Switches away from whatever is showing now ([isDark]).
  Future<void> toggle({required bool isDark}) async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    mode.value = next;
    if (!_persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
