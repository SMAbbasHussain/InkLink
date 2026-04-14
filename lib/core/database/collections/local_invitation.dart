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
  String targetRole = 'viewer';
  String? inviterRoleSnapshot;

  @Index()
  late DateTime timestamp;

  DateTime? expiresAt;
  int? inviteExpiryHours;
  DateTime? acceptedAt;
  DateTime? rejectedAt;
  DateTime? resolvedAt;

  late DateTime cachedAt;
}
