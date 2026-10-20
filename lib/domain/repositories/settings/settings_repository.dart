abstract class SettingsRepository {
  Future<bool> getShowTrayTips();
  Future<void> setShowTrayTips(bool value);
  Future<String> getBoardPreviewQuality();
  Future<void> setBoardPreviewQuality(String quality);
  Future<bool> getBoardPreviewCompressionEnabled();
  Future<void> setBoardPreviewCompressionEnabled(bool enabled);
  Future<bool> getPushNotificationsEnabled();
  Future<void> setPushNotificationsEnabled(bool value);
  Future<bool> getInviteAlertsEnabled();
  Future<void> setInviteAlertsEnabled(bool value);
  Future<bool> getFriendAlertsEnabled();
  Future<void> setFriendAlertsEnabled(bool value);
  Future<void> clearLocalCache();
}
