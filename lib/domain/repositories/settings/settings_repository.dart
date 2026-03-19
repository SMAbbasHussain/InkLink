abstract class SettingsRepository {
  Future<bool> getShowTrayTips();
  Future<void> setShowTrayTips(bool value);
  Future<void> clearLocalCache();
}
