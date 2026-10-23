import '../../../../domain/models/chat/chat_conversation_model.dart';

abstract class GroupSettingsState {
  const GroupSettingsState();
}

class GroupSettingsInitial extends GroupSettingsState {
  const GroupSettingsInitial();
}

class GroupSettingsLoading extends GroupSettingsState {
  const GroupSettingsLoading();
}

class GroupSettingsLoaded extends GroupSettingsState {
  final ChatConversationModel group;
  final bool isOwner;
  final bool isAdmin;

  const GroupSettingsLoaded({
    required this.group,
    required this.isOwner,
    required this.isAdmin,
  });

  GroupSettingsLoaded copyWith({
    ChatConversationModel? group,
    bool? isOwner,
    bool? isAdmin,
  }) {
    return GroupSettingsLoaded(
      group: group ?? this.group,
      isOwner: isOwner ?? this.isOwner,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

class GroupSettingsOperationSuccess extends GroupSettingsState {
  final String message;
  final bool shouldExit;
  const GroupSettingsOperationSuccess(this.message, {this.shouldExit = false});
}

class GroupSettingsError extends GroupSettingsState {
  final String message;
  const GroupSettingsError(this.message);
}
