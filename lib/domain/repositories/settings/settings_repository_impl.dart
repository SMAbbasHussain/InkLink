import '../../../core/database/database_service.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseService _databaseService;

  SettingsRepositoryImpl({required DatabaseService databaseService})
    : _databaseService = databaseService;

  @override
  Future<bool> getShowTrayTips() {
    return TrayTipsPreferences.getShowTrayTips();
  }

  @override
  Future<void> setShowTrayTips(bool value) {
    return TrayTipsPreferences.setShowTrayTips(value);
  }

  @override
  Future<void> clearLocalCache() {
    return _databaseService.clearLocalCache();
  }
}
