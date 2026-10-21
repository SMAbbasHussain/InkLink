import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final SharedPreferences _prefs;

  NotificationPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  static const String _readNotificationIdsKey = 'read_notification_ids';
  static const String _pushNotificationsKey = 'push_notifications_enabled';
  static const String _inviteAlertsKey = 'invite_alerts_enabled';
  static const String _friendAlertsKey = 'friend_alerts_enabled';

  String _userKey(String baseKey, [String? userId]) =>
      (userId != null && userId.isNotEmpty) ? '${baseKey}_$userId' : baseKey;

  Future<Set<String>> getReadNotificationIds([String? userId]) =>
      Future.value(_prefs.getStringList(_userKey(_readNotificationIdsKey, userId))?.toSet() ?? <String>{});

  Future<void> markAsRead(String notificationId, [String? userId]) async {
    final key = _userKey(_readNotificationIdsKey, userId);
    final current = _prefs.getStringList(key) ?? <String>[];
    if (current.contains(notificationId)) return;
    current.add(notificationId);
    await _prefs.setStringList(key, current);
  }

  Future<void> remove(String notificationId, [String? userId]) async {
    final key = _userKey(_readNotificationIdsKey, userId);
    final current = _prefs.getStringList(key) ?? <String>[];
    current.remove(notificationId);
    await _prefs.setStringList(key, current);
  }

  Future<bool?> getPushNotificationsEnabled([String? userId]) =>
      Future.value(_prefs.getBool(_userKey(_pushNotificationsKey, userId)));

  Future<void> setPushNotificationsEnabled(bool value, [String? userId]) =>
      _prefs.setBool(_userKey(_pushNotificationsKey, userId), value);

  Future<bool?> getInviteAlertsEnabled([String? userId]) =>
      Future.value(_prefs.getBool(_userKey(_inviteAlertsKey, userId)));

  Future<void> setInviteAlertsEnabled(bool value, [String? userId]) =>
      _prefs.setBool(_userKey(_inviteAlertsKey, userId), value);

  Future<bool?> getFriendAlertsEnabled([String? userId]) =>
      Future.value(_prefs.getBool(_userKey(_friendAlertsKey, userId)));

  Future<void> setFriendAlertsEnabled(bool value, [String? userId]) =>
      _prefs.setBool(_userKey(_friendAlertsKey, userId), value);
}
