import 'package:shared_preferences/shared_preferences.dart';

class BoardPreviewPreferences {
  static const String _previewQualityKey = 'board_preview_quality';
  static const String _previewCompressionEnabledKey =
      'board_preview_compression_enabled';

  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';

  static Future<String> getQuality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_previewQualityKey) ?? medium;
  }

  static Future<void> setQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeQuality(quality);
    await prefs.setString(_previewQualityKey, normalized);
  }

  static Future<bool> getCompressionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_previewCompressionEnabledKey) ?? true;
  }

  static Future<void> setCompressionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_previewCompressionEnabledKey, enabled);
  }

  static String _normalizeQuality(String quality) {
    switch (quality) {
      case low:
      case medium:
      case high:
        return quality;
      default:
        return medium;
    }
  }
}
