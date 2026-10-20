import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final SharedPreferences _prefs;

  NotificationPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  static const String _readNotificationIdsKey = 'read_notification_ids';
  static const String _pushNotificationsKey = 'push_notifications_enabled';
  static const String _inviteAlertsKey = 'invite_alerts_enabled';
  static const String _friendAlertsKey = 'friend_alerts_enabled';

  Future<Set<String>> getReadNotificationIds() =>
      Future.value(_prefs.getStringList(_readNotificationIdsKey)?.toSet() ?? <String>{});

  Future<void> markAsRead(String notificationId) async {
    final current = _prefs.getStringList(_readNotificationIdsKey) ?? <String>[];
    if (current.contains(notificationId)) return;
    current.add(notificationId);
    await _prefs.setStringList(_readNotificationIdsKey, current);
  }

  Future<void> remove(String notificationId) async {
    final current = _prefs.getStringList(_readNotificationIdsKey) ?? <String>[];
    current.remove(notificationId);
    await _prefs.setStringList(_readNotificationIdsKey, current);
  }

  Future<bool> getPushNotificationsEnabled() =>
      Future.value(_prefs.getBool(_pushNotificationsKey) ?? true);

  Future<void> setPushNotificationsEnabled(bool value) =>
      _prefs.setBool(_pushNotificationsKey, value);

  Future<bool> getInviteAlertsEnabled() =>
      Future.value(_prefs.getBool(_inviteAlertsKey) ?? true);

  Future<void> setInviteAlertsEnabled(bool value) =>
      _prefs.setBool(_inviteAlertsKey, value);

  Future<bool> getFriendAlertsEnabled() =>
      Future.value(_prefs.getBool(_friendAlertsKey) ?? true);

  Future<void> setFriendAlertsEnabled(bool value) =>
      _prefs.setBool(_friendAlertsKey, value);
}
