import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/database/collections/local_notification.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDatabaseService _localDatabaseService;

  NotificationRepositoryImpl({
    required FirestoreService firestoreService,
    required AuthService authService,
    required LocalDatabaseService localDatabaseService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _localDatabaseService = localDatabaseService;

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
        .limit(100) // Limit to recent 100 to reduce read size
        .snapshots()
        .map((snapshot) {
          // Sync to local cache on each update
          _syncNotificationsToLocal(uid, snapshot.docs);

          return snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
  }

  Future<void> _syncNotificationsToLocal(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final isar = await _localDatabaseService.database;

    await isar.writeTxn(() async {
      for (final doc in docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;

        await isar.localNotifications.put(
          LocalNotification()
            ..uid = uid
            ..timestamp = timestamp?.toDate() ?? DateTime.now()
            ..type = data['type'] ?? 'general'
            ..title = data['title'] ?? ''
            ..body = data['body']
            ..targetId = data['targetId']
            ..senderUid = data['senderUid']
            ..senderDisplayName = data['senderDisplayName']
            ..senderPhotoUrl = data['senderPhotoUrl']
            ..read = data['read'] ?? false
            ..readAt = (data['readAt'] as Timestamp?)?.toDate()
            ..cachedAt = DateTime.now(),
        );
      }
    });
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
