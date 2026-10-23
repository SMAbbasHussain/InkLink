import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/services/chat/chat_service.dart';
import 'group_settings_event.dart';
import 'group_settings_state.dart';

class GroupSettingsBloc extends Bloc<GroupSettingsEvent, GroupSettingsState> {
  final ChatService _chatService;
  final String _currentUid;

  GroupSettingsBloc({
    required ChatService chatService,
    required String currentUid,
  })  : _chatService = chatService,
        _currentUid = currentUid,
        super(const GroupSettingsInitial()) {
    on<LoadGroupSettings>(_onLoadGroupSettings);
    on<UpdateGroupDetailsRequested>(_onUpdateGroupDetails);
    on<AddGroupMembersRequested>(_onAddGroupMembers);
    on<RemoveGroupMemberRequested>(_onRemoveGroupMember);
    on<PromoteGroupAdminRequested>(_onPromoteGroupAdmin);
    on<DemoteGroupAdminRequested>(_onDemoteGroupAdmin);
    on<TransferGroupOwnershipRequested>(_onTransferGroupOwnership);
    on<LeaveGroupRequested>(_onLeaveGroup);
    on<DestroyGroupRequested>(_onDestroyGroup);
  }

  Future<void> _onLoadGroupSettings(
    LoadGroupSettings event,
    Emitter<GroupSettingsState> emit,
  ) async {
    emit(const GroupSettingsLoading());
    try {
      final conversations = await _chatService.getConversations();
      final group = conversations.firstWhere(
        (c) => c.id == event.groupId,
        orElse: () => throw Exception('Group conversation not found'),
      );

      final isOwner = group.isUserOwner(_currentUid);
      final isAdmin = group.isUserAdmin(_currentUid);

      emit(GroupSettingsLoaded(
        group: group,
        isOwner: isOwner,
        isAdmin: isAdmin,
      ));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateGroupDetails(
    UpdateGroupDetailsRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.updateGroupInfo(
        groupId: event.groupId,
        name: event.name,
        description: event.description,
        iconUrl: event.iconUrl,
      );
      add(LoadGroupSettings(event.groupId));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onAddGroupMembers(
    AddGroupMembersRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.addGroupMembers(
        groupId: event.groupId,
        memberIds: event.memberIds,
      );
      add(LoadGroupSettings(event.groupId));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onRemoveGroupMember(
    RemoveGroupMemberRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.removeGroupMember(
        groupId: event.groupId,
        memberId: event.memberId,
      );
      add(LoadGroupSettings(event.groupId));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onPromoteGroupAdmin(
    PromoteGroupAdminRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.promoteAdmin(
        groupId: event.groupId,
        memberId: event.memberId,
      );
      add(LoadGroupSettings(event.groupId));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onDemoteGroupAdmin(
    DemoteGroupAdminRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.demoteAdmin(
        groupId: event.groupId,
        memberId: event.memberId,
      );
      add(LoadGroupSettings(event.groupId));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onTransferGroupOwnership(
    TransferGroupOwnershipRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.transferGroupOwner(
        groupId: event.groupId,
        newOwnerId: event.newOwnerId,
      );
      add(LoadGroupSettings(event.groupId));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onLeaveGroup(
    LeaveGroupRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.leaveGroup(event.groupId);
      emit(const GroupSettingsOperationSuccess('Left group successfully', shouldExit: true));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }

  Future<void> _onDestroyGroup(
    DestroyGroupRequested event,
    Emitter<GroupSettingsState> emit,
  ) async {
    try {
      await _chatService.destroyGroup(event.groupId);
      emit(const GroupSettingsOperationSuccess('Group destroyed successfully', shouldExit: true));
    } catch (e) {
      emit(GroupSettingsError(e.toString()));
    }
  }
}
