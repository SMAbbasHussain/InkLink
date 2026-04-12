import '../../repositories/notification/notification_repository.dart';

abstract class NotificationService {
  Stream<List<Map<String, dynamic>>> watchNotifications();
  Future<void> deleteNotification(String notificationId);
}

class NotificationServiceImpl implements NotificationService {
  final NotificationRepository _notificationRepository;

  NotificationServiceImpl({
    required NotificationRepository notificationRepository,
  }) : _notificationRepository = notificationRepository;

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    return _notificationRepository.watchNotifications();
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _notificationRepository.deleteNotification(notificationId);
  }
}
