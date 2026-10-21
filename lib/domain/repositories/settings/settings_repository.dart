abstract class SettingsRepository {
  Future<bool> getShowTrayTips();
  Future<void> setShowTrayTips(bool value);
  Future<String> getBoardPreviewQuality();
  Future<void> setBoardPreviewQuality(String quality);
  Future<bool> getBoardPreviewCompressionEnabled();
  Future<void> setBoardPreviewCompressionEnabled(bool enabled);
  Future<bool> getPushNotificationsEnabled([String? userId]);
  Future<void> setPushNotificationsEnabled(bool value, [String? userId]);
  Future<bool> getInviteAlertsEnabled([String? userId]);
  Future<void> setInviteAlertsEnabled(bool value, [String? userId]);
  Future<bool> getFriendAlertsEnabled([String? userId]);
  Future<void> setFriendAlertsEnabled(bool value, [String? userId]);
  Future<void> clearLocalCache();
}
