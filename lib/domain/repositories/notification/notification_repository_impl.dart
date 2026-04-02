import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  NotificationRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
  }) : _firestoreService = firestoreService,
       _authService = authService;

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final uid = _authService.getCurrentUserId();
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestoreService
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final uid = _authService.getCurrentUserId();
    if (uid == null) return;

    await _firestoreService
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}
