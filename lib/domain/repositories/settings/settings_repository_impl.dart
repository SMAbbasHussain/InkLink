import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_database_service.dart';
import '../../../core/utils/board_preview_preferences.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final LocalDatabaseService _localDatabaseService;
  final TrayTipsPreferences _trayTipsPreferences;
  final BoardPreviewPreferences _boardPreviewPreferences;

  SettingsRepositoryImpl({
    required LocalDatabaseService localDatabaseService,
    required SharedPreferences sharedPreferences,
  }) : _localDatabaseService = localDatabaseService,
       _trayTipsPreferences = TrayTipsPreferences(prefs: sharedPreferences),
       _boardPreviewPreferences = BoardPreviewPreferences(prefs: sharedPreferences);

  @override
  Future<bool> getShowTrayTips() {
    return _trayTipsPreferences.getShowTrayTips();
  }

  @override
  Future<void> setShowTrayTips(bool value) {
    return _trayTipsPreferences.setShowTrayTips(value);
  }

  @override
  Future<String> getBoardPreviewQuality() {
    return _boardPreviewPreferences.getQuality();
  }

  @override
  Future<void> setBoardPreviewQuality(String quality) {
    return _boardPreviewPreferences.setQuality(quality);
  }

  @override
  Future<bool> getBoardPreviewCompressionEnabled() {
    return _boardPreviewPreferences.getCompressionEnabled();
  }

  @override
  Future<void> setBoardPreviewCompressionEnabled(bool enabled) {
    return _boardPreviewPreferences.setCompressionEnabled(enabled);
  }

  @override
  Future<void> clearLocalCache() {
    return _localDatabaseService.clearLocalCache();
  }
}
