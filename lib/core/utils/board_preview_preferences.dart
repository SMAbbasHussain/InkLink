import 'package:shared_preferences/shared_preferences.dart';

class BoardPreviewPreferences {
  final SharedPreferences _prefs;

  BoardPreviewPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  static const String _previewQualityKey = 'board_preview_quality';
  static const String _previewCompressionEnabledKey =
      'board_preview_compression_enabled';

  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';

  Future<String> getQuality() =>
      Future.value(_prefs.getString(_previewQualityKey) ?? medium);

  Future<void> setQuality(String quality) async {
    final normalized = _normalizeQuality(quality);
    await _prefs.setString(_previewQualityKey, normalized);
  }

  Future<bool> getCompressionEnabled() =>
      Future.value(_prefs.getBool(_previewCompressionEnabledKey) ?? true);

  Future<void> setCompressionEnabled(bool enabled) async {
    await _prefs.setBool(_previewCompressionEnabledKey, enabled);
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
