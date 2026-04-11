import 'package:isar_community/isar.dart';

part 'local_invitation.g.dart';

@collection
class LocalInvitation {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String inviteId;

  @Index()
  late String boardId;

  late String boardTitle;

  @Index()
  late String fromUid;

  @Index()
  late String toUid;

  late String senderName;
  String? senderPic;

  @Index()
  late String status;

  @Index()
  late DateTime timestamp;

  DateTime? expiresAt;
  int? inviteExpiryHours;

  late DateTime cachedAt;
}
