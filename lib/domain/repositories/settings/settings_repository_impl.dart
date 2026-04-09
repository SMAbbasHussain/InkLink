import '../../../core/database/local_database_service.dart';
import '../../../core/utils/board_preview_preferences.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final LocalDatabaseService _localDatabaseService;

  SettingsRepositoryImpl({required LocalDatabaseService localDatabaseService})
    : _localDatabaseService = localDatabaseService;

  @override
  Future<bool> getShowTrayTips() {
    return TrayTipsPreferences.getShowTrayTips();
  }

  @override
  Future<void> setShowTrayTips(bool value) {
    return TrayTipsPreferences.setShowTrayTips(value);
  }

  @override
  Future<String> getBoardPreviewQuality() {
    return BoardPreviewPreferences.getQuality();
  }

  @override
  Future<void> setBoardPreviewQuality(String quality) {
    return BoardPreviewPreferences.setQuality(quality);
  }

  @override
  Future<bool> getBoardPreviewCompressionEnabled() {
    return BoardPreviewPreferences.getCompressionEnabled();
  }

  @override
  Future<void> setBoardPreviewCompressionEnabled(bool enabled) {
    return BoardPreviewPreferences.setCompressionEnabled(enabled);
  }

  @override
  Future<void> clearLocalCache() {
    return _localDatabaseService.clearLocalCache();
  }
}
