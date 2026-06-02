import 'package:shared_preferences/shared_preferences.dart';

class TrayTipsPreferences {
  final SharedPreferences _prefs;

  TrayTipsPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  /// Convenience static accessor for legacy callers without DI.
  /// Prefer constructor injection in new code.
  static Future<bool> checkShowTrayTips() async {
    final prefs = await SharedPreferences.getInstance();
    return TrayTipsPreferences(prefs: prefs).getShowTrayTips();
  }

  static const String _showTrayTipsKey = 'show_tray_tips';

  Future<bool> getShowTrayTips() =>
      Future.value(_prefs.getBool(_showTrayTipsKey) ?? true);

  Future<void> setShowTrayTips(bool value) async {
    await _prefs.setBool(_showTrayTipsKey, value);
  }
}
