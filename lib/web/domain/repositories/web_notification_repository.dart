import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../domain/repositories/notification/notification_repository.dart';

/// Firestore-only [NotificationRepository] for the web target (no Isar cache):
/// streams the newest 100 feed notifications excluding chat messages.
class WebNotificationRepository implements NotificationRepository {
  final FirestoreService _db;
  final AuthService _authService;

  WebNotificationRepository({
    required this._authService,
    required FirestoreService firestoreService,
  }) : _db = firestoreService;

  CollectionReference<Map<String, dynamic>> _feed(String uid) => _db
      .collection(FirestorePaths.users)
      .doc(uid)
      .collection(FirestorePaths.notificationsSubcollection);

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final uid = _authService.getCurrentUserId();
    if (uid == null) return Stream.value(const []);
    return _feed(uid)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              if (doc.data()['type'] != 'chat_message')
                {'id': doc.id, ...doc.data()},
          ],
        );
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final uid = _authService.getCurrentUserId();
    if (uid == null) return;
    await _feed(uid).doc(notificationId).delete();
  }
}
