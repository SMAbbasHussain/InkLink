import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const String _readNotificationIdsKey = 'read_notification_ids';

  static Future<Set<String>> getReadNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readNotificationIdsKey)?.toSet() ?? <String>{};
  }

  static Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_readNotificationIdsKey) ?? <String>[];
    if (current.contains(notificationId)) return;
    current.add(notificationId);
    await prefs.setStringList(_readNotificationIdsKey, current);
  }

  static Future<void> remove(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_readNotificationIdsKey) ?? <String>[];
    current.remove(notificationId);
    await prefs.setStringList(_readNotificationIdsKey, current);
  }
}
