abstract class NotificationRepository {
  Stream<List<Map<String, dynamic>>> watchNotifications();
  Future<void> deleteNotification(String notificationId);
}
