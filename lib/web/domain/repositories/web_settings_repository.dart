import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/board_preview_preferences.dart';
import '../../../core/utils/canvas_toolbar_preferences.dart';
import '../../../core/utils/notification_preferences.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import '../../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../../domain/repositories/settings/settings_repository.dart';

/// Browser-stored (`shared_preferences`) toolbar, preview and alert preferences
/// without mobile's Isar cache.
class WebSettingsRepository implements SettingsRepository {
  final Future<SharedPreferences> _prefsFuture;

  WebSettingsRepository(SharedPreferences prefs)
    : _prefsFuture = Future<SharedPreferences>.value(prefs);

  /// Resolves `SharedPreferences` lazily when a pre-loaded instance was not
  /// passed into `WebCompanionApp`.
  WebSettingsRepository.lazy() : _prefsFuture = SharedPreferences.getInstance();

  Future<TrayTipsPreferences> _trayTips() async =>
      TrayTipsPreferences(prefs: await _prefsFuture);
  Future<BoardPreviewPreferences> _preview() async =>
      BoardPreviewPreferences(prefs: await _prefsFuture);
  Future<CanvasToolbarPreferences> _toolbar() async =>
      CanvasToolbarPreferences(prefs: await _prefsFuture);
  Future<NotificationPreferences> _notifications() async =>
      NotificationPreferences(prefs: await _prefsFuture);

  @override
  Future<bool> getShowTrayTips() async => (await _trayTips()).getShowTrayTips();

  @override
  Future<void> setShowTrayTips(bool value) async =>
      (await _trayTips()).setShowTrayTips(value);

  @override
  Future<String> getBoardPreviewQuality() async =>
      (await _preview()).getQuality();

  @override
  Future<void> setBoardPreviewQuality(String quality) async =>
      (await _preview()).setQuality(quality);

  @override
  Future<bool> getBoardPreviewCompressionEnabled() async =>
      (await _preview()).getCompressionEnabled();

  @override
  Future<void> setBoardPreviewCompressionEnabled(bool enabled) async =>
      (await _preview()).setCompressionEnabled(enabled);

  @override
  Future<List<CanvasToolbarAction>> getBottomBarActions() async =>
      (await _toolbar()).getBottomBarActions();

  @override
  Future<void> setBottomBarActions(List<CanvasToolbarAction> actions) async =>
      (await _toolbar()).setBottomBarActions(actions);

  @override
  Future<bool> getPushNotificationsEnabled([String? userId]) async =>
      await (await _notifications()).getPushNotificationsEnabled(userId) ??
      true;

  @override
  Future<void> setPushNotificationsEnabled(
    bool value, [
    String? userId,
  ]) async =>
      (await _notifications()).setPushNotificationsEnabled(value, userId);

  @override
  Future<bool> getInviteAlertsEnabled([String? userId]) async =>
      await (await _notifications()).getInviteAlertsEnabled(userId) ?? true;

  @override
  Future<void> setInviteAlertsEnabled(bool value, [String? userId]) async =>
      (await _notifications()).setInviteAlertsEnabled(value, userId);

  @override
  Future<bool> getFriendAlertsEnabled([String? userId]) async =>
      await (await _notifications()).getFriendAlertsEnabled(userId) ?? true;

  @override
  Future<void> setFriendAlertsEnabled(bool value, [String? userId]) async =>
      (await _notifications()).setFriendAlertsEnabled(value, userId);

  @override
  Future<void> clearLocalCache() async {}
}
