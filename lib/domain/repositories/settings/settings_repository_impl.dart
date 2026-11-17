import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_database_service.dart';
import '../../../core/utils/board_preview_preferences.dart';
import '../../../core/utils/canvas_toolbar_preferences.dart';
import '../../../core/utils/notification_preferences.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import '../../models/canvas/canvas_toolbar_action.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final LocalDatabaseService _localDatabaseService;
  final TrayTipsPreferences _trayTipsPreferences;
  final BoardPreviewPreferences _boardPreviewPreferences;
  final CanvasToolbarPreferences _canvasToolbarPreferences;
  final NotificationPreferences _notificationPreferences;

  SettingsRepositoryImpl({
    required LocalDatabaseService localDatabaseService,
    required SharedPreferences sharedPreferences,
  }) : _localDatabaseService = localDatabaseService,
       _trayTipsPreferences = TrayTipsPreferences(prefs: sharedPreferences),
       _boardPreviewPreferences = BoardPreviewPreferences(prefs: sharedPreferences),
       _canvasToolbarPreferences = CanvasToolbarPreferences(prefs: sharedPreferences),
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
  Future<List<CanvasToolbarAction>> getBottomBarActions() {
    return _canvasToolbarPreferences.getBottomBarActions();
  }

  @override
  Future<void> setBottomBarActions(List<CanvasToolbarAction> actions) {
    return _canvasToolbarPreferences.setBottomBarActions(actions);
  }

  @override
  Future<bool> getPushNotificationsEnabled([String? userId]) async {
    final val = await _notificationPreferences.getPushNotificationsEnabled(userId);
    return val ?? true;
  }

  @override
  Future<void> setPushNotificationsEnabled(bool value, [String? userId]) {
    return _notificationPreferences.setPushNotificationsEnabled(value, userId);
  }

  @override
  Future<bool> getInviteAlertsEnabled([String? userId]) async {
    final val = await _notificationPreferences.getInviteAlertsEnabled(userId);
    return val ?? true;
  }

  @override
  Future<void> setInviteAlertsEnabled(bool value, [String? userId]) {
    return _notificationPreferences.setInviteAlertsEnabled(value, userId);
  }

  @override
  Future<bool> getFriendAlertsEnabled([String? userId]) async {
    final val = await _notificationPreferences.getFriendAlertsEnabled(userId);
    return val ?? true;
  }

  @override
  Future<void> setFriendAlertsEnabled(bool value, [String? userId]) {
    return _notificationPreferences.setFriendAlertsEnabled(value, userId);
  }

  @override
  Future<void> clearLocalCache() {
    return _localDatabaseService.clearLocalCache();
  }
}
