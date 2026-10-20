import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_database_service.dart';
import '../../../core/utils/board_preview_preferences.dart';
import '../../../core/utils/notification_preferences.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final LocalDatabaseService _localDatabaseService;
  final TrayTipsPreferences _trayTipsPreferences;
  final BoardPreviewPreferences _boardPreviewPreferences;
  final NotificationPreferences _notificationPreferences;

  SettingsRepositoryImpl({
    required LocalDatabaseService localDatabaseService,
    required SharedPreferences sharedPreferences,
  }) : _localDatabaseService = localDatabaseService,
       _trayTipsPreferences = TrayTipsPreferences(prefs: sharedPreferences),
       _boardPreviewPreferences = BoardPreviewPreferences(prefs: sharedPreferences),
       _notificationPreferences = NotificationPreferences(prefs: sharedPreferences);

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
  Future<bool> getPushNotificationsEnabled() {
    return _notificationPreferences.getPushNotificationsEnabled();
  }

  @override
  Future<void> setPushNotificationsEnabled(bool value) {
    return _notificationPreferences.setPushNotificationsEnabled(value);
  }

  @override
  Future<bool> getInviteAlertsEnabled() {
    return _notificationPreferences.getInviteAlertsEnabled();
  }

  @override
  Future<void> setInviteAlertsEnabled(bool value) {
    return _notificationPreferences.setInviteAlertsEnabled(value);
  }

  @override
  Future<bool> getFriendAlertsEnabled() {
    return _notificationPreferences.getFriendAlertsEnabled();
  }

  @override
  Future<void> setFriendAlertsEnabled(bool value) {
    return _notificationPreferences.setFriendAlertsEnabled(value);
  }

  @override
  Future<void> clearLocalCache() {
    return _localDatabaseService.clearLocalCache();
  }
}
