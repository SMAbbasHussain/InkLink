import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  final SharedPreferences _prefs;

  NotificationPreferences({required SharedPreferences prefs}) : _prefs = prefs;

  static const String _readNotificationIdsKey = 'read_notification_ids';

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
}
