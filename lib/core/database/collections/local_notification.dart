import 'package:isar_community/isar.dart';

part 'local_notification.g.dart';

@collection
class LocalNotification {
  Id? id;

  @Index()
  late String uid; // User who received notification

  @Index()
  late DateTime timestamp; // For sorting

  late String type; // 'friend_request', 'board_invite', etc.
  late String title;
  String? body;
  String? targetId;
  String? senderUid;
  String? senderDisplayName;
  String? senderPhotoUrl;

  @Index()
  late bool read;

  late DateTime? readAt;
  late DateTime cachedAt;
}
