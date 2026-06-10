import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/database/collections/local_notification.dart';
import 'package:isar_community/isar.dart';
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
    // Read existing local notifications for this uid to avoid re-writing unchanged items
    final existing = await isar.localNotifications
        .where()
        .uidEqualTo(uid)
        .findAll();

    final existingMap = <String, LocalNotification>{};
    for (final item in existing) {
      final key = '${item.timestamp.millisecondsSinceEpoch}|${item.title}';
      existingMap[key] = item;
    }

    await isar.writeTxn(() async {
      for (final doc in docs) {
        final data = doc.data();
        final timestamp =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final title = data['title']?.toString() ?? '';
        final key = '${timestamp.millisecondsSinceEpoch}|$title';

        final existingItem = existingMap[key];
        final read = data['read'] ?? false;
        final readAt = (data['readAt'] as Timestamp?)?.toDate();

        if (existingItem == null) {
          // Insert new notification
          await isar.localNotifications.put(
            LocalNotification()
              ..uid = uid
              ..timestamp = timestamp
              ..type = data['type'] ?? 'general'
              ..title = title
              ..body = data['body']
              ..targetId = data['targetId']
              ..senderUid = data['senderUid']
              ..senderDisplayName = data['senderDisplayName']
              ..senderPhotoUrl = data['senderPhotoUrl']
              ..read = read
              ..readAt = readAt
              ..cachedAt = DateTime.now(),
          );
        } else {
          // Update only if read state changed
          if (existingItem.read != read || existingItem.readAt != readAt) {
            existingItem.read = read;
            existingItem.readAt = readAt;
            existingItem.cachedAt = DateTime.now();
            await isar.localNotifications.put(existingItem);
          }
        }
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
