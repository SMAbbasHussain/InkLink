import 'package:shared_preferences/shared_preferences.dart';

class TrayTipsPreferences {
  static const String _showTrayTipsKey = 'show_tray_tips';

  static Future<bool> getShowTrayTips() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTrayTipsKey) ?? true;
  }

  static Future<void> setShowTrayTips(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTrayTipsKey, value);
  }
}
