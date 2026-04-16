import 'package:isar_community/isar.dart';

part 'local_workspace.g.dart';

@collection
class LocalWorkspace {
  Id id = Isar.autoIncrement;
  late String workspaceId;
  late String ownerId;
  late String name;
  late String description;
  late int memberCount;
  late int boardCount;
  late DateTime createdAt;
  late DateTime updatedAt;

  @Index()
  late String currentUserRole; // 'owner'

  @Index()
  late bool isSynced;
}

@collection
class LocalWorkspaceInvite {
  Id id = Isar.autoIncrement;
  late String inviteId;
  late String workspaceId;
  late String fromUid;
  late String toUid;
  late String status; // 'pending', 'accepted', 'rejected'
  late DateTime timestamp;
  late DateTime? acceptedAt;
  late DateTime? rejectedAt;

  @Index()
  late bool isSynced;
}
