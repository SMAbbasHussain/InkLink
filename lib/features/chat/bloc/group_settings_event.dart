abstract class GroupSettingsEvent {
  const GroupSettingsEvent();
}

class LoadGroupSettings extends GroupSettingsEvent {
  final String groupId;
  const LoadGroupSettings(this.groupId);
}

class UpdateGroupDetailsRequested extends GroupSettingsEvent {
  final String groupId;
  final String? name;
  final String? description;
  final String? iconUrl;
  const UpdateGroupDetailsRequested({
    required this.groupId,
    this.name,
    this.description,
    this.iconUrl,
  });
}

class AddGroupMembersRequested extends GroupSettingsEvent {
  final String groupId;
  final List<String> memberIds;
  const AddGroupMembersRequested({
    required this.groupId,
    required this.memberIds,
  });
}

class RemoveGroupMemberRequested extends GroupSettingsEvent {
  final String groupId;
  final String memberId;
  const RemoveGroupMemberRequested({
    required this.groupId,
    required this.memberId,
  });
}

class PromoteGroupAdminRequested extends GroupSettingsEvent {
  final String groupId;
  final String memberId;
  const PromoteGroupAdminRequested({
    required this.groupId,
    required this.memberId,
  });
}

class DemoteGroupAdminRequested extends GroupSettingsEvent {
  final String groupId;
  final String memberId;
  const DemoteGroupAdminRequested({
    required this.groupId,
    required this.memberId,
  });
}

class TransferGroupOwnershipRequested extends GroupSettingsEvent {
  final String groupId;
  final String newOwnerId;
  const TransferGroupOwnershipRequested({
    required this.groupId,
    required this.newOwnerId,
  });
}

class LeaveGroupRequested extends GroupSettingsEvent {
  final String groupId;
  const LeaveGroupRequested(this.groupId);
}

class DestroyGroupRequested extends GroupSettingsEvent {
  final String groupId;
  const DestroyGroupRequested(this.groupId);
}
