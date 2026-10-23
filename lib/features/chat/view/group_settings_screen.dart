import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../domain/services/chat/chat_service.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../bloc/group_settings_bloc.dart';
import '../bloc/group_settings_event.dart';
import '../bloc/group_settings_state.dart';
import '../theme/chat_theme.dart';

class GroupSettingsScreen extends StatelessWidget {
  final String groupId;

  const GroupSettingsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().getCurrentUserId() ?? '';
    return BlocProvider(
      create: (context) => GroupSettingsBloc(
        chatService: context.read<ChatService>(),
        currentUid: currentUid,
      )..add(LoadGroupSettings(groupId)),
      child: const _GroupSettingsView(),
    );
  }
}

class _GroupSettingsView extends StatefulWidget {
  const _GroupSettingsView();

  @override
  State<_GroupSettingsView> createState() => _GroupSettingsViewState();
}

class _GroupSettingsViewState extends State<_GroupSettingsView> {
  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    return BlocConsumer<GroupSettingsBloc, GroupSettingsState>(
      listener: (context, state) {
        if (state is GroupSettingsOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          if (state.shouldExit) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
        if (state is GroupSettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        if (state is GroupSettingsLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(child: CircularProgressIndicator(color: colors.accent)),
          );
        }

        if (state is GroupSettingsLoaded) {
          final group = state.group;
          final isOwner = state.isOwner;
          final isAdmin = state.isAdmin;

          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              elevation: 0,
              title: Text('Group Details', style: TextStyle(color: colors.textPrimary, fontSize: 16)),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(ChatTheme.space16),
              children: [
                // Group Avatar & Info
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: colors.accent,
                        backgroundImage: group.avatarUrl != null && group.avatarUrl!.isNotEmpty
                            ? NetworkImage(group.avatarUrl!)
                            : null,
                        child: group.avatarUrl == null || group.avatarUrl!.isEmpty
                            ? const Icon(Icons.groups, size: 44, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: ChatTheme.space12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isAdmin)
                            IconButton(
                              icon: Icon(Icons.edit, color: colors.accent, size: 18),
                              onPressed: () => _showEditGroupDialog(context, group),
                            ),
                        ],
                      ),
                      if (group.description != null && group.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.description!,
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${group.memberIds.length} members',
                        style: TextStyle(color: colors.accentAlt, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: ChatTheme.space24),

                // Members Section Header
                Row(
                  children: [
                    Text(
                      'Members',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isAdmin)
                      TextButton.icon(
                        icon: Icon(Icons.person_add_outlined, size: 16, color: colors.accent),
                        label: Text('Add Member', style: TextStyle(color: colors.accent, fontSize: 12)),
                        onPressed: () => _showAddMembersSheet(context, group),
                      ),
                  ],
                ),

                const SizedBox(height: ChatTheme.space8),

                // Members List
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.memberIds.length,
                    separatorBuilder: (_, _) => Divider(color: colors.divider, height: 1),
                    itemBuilder: (context, index) {
                      final memberId = group.memberIds[index];
                      final isMemberOwner = group.isUserOwner(memberId);
                      final isMemberAdmin = group.isUserAdmin(memberId);
                      final isSelf = memberId == context.read<AuthService>().getCurrentUserId();

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: colors.surfaceElevated,
                          child: Icon(Icons.person, color: colors.textSecondary, size: 20),
                        ),
                        title: Row(
                          children: [
                            Text(
                              isSelf ? 'You' : 'User ${memberId.substring(0, 5)}',
                              style: TextStyle(color: colors.textPrimary, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            if (isMemberOwner)
                              _buildRoleBadge('OWNER', Colors.amber)
                            else if (isMemberAdmin)
                              _buildRoleBadge('ADMIN', colors.accentAlt)
                            else
                              _buildRoleBadge('MEMBER', colors.textSecondary),
                          ],
                        ),
                        trailing: (isOwner && !isMemberOwner)
                            ? PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: colors.textSecondary, size: 20),
                                color: colors.surfaceElevated,
                                onSelected: (val) {
                                  if (val == 'promote') {
                                    context.read<GroupSettingsBloc>().add(
                                      PromoteGroupAdminRequested(groupId: group.id, memberId: memberId),
                                    );
                                  } else if (val == 'demote') {
                                    context.read<GroupSettingsBloc>().add(
                                      DemoteGroupAdminRequested(groupId: group.id, memberId: memberId),
                                    );
                                  } else if (val == 'transfer') {
                                    context.read<GroupSettingsBloc>().add(
                                      TransferGroupOwnershipRequested(groupId: group.id, newOwnerId: memberId),
                                    );
                                  } else if (val == 'remove') {
                                    context.read<GroupSettingsBloc>().add(
                                      RemoveGroupMemberRequested(groupId: group.id, memberId: memberId),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (!isMemberAdmin)
                                    PopupMenuItem(value: 'promote', child: Text('Promote to Admin', style: TextStyle(color: colors.textPrimary))),
                                  if (isMemberAdmin && !isMemberOwner)
                                    PopupMenuItem(value: 'demote', child: Text('Demote from Admin', style: TextStyle(color: colors.textPrimary))),
                                  PopupMenuItem(value: 'transfer', child: Text('Transfer Ownership', style: TextStyle(color: colors.textPrimary))),
                                  const PopupMenuItem(value: 'remove', child: Text('Remove from Group', style: TextStyle(color: Colors.redAccent))),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
                ),

                const SizedBox(height: ChatTheme.space32),

                // Danger Zone: Leave / Delete Group
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.exit_to_app, color: Colors.orangeAccent),
                        title: const Text('Leave Group', style: TextStyle(color: Colors.orangeAccent)),
                        onTap: () {
                          _confirmDialog(
                            context: context,
                            title: 'Leave Group',
                            message: 'Are you sure you want to leave this group chat?',
                            actionLabel: 'Leave',
                            isDestructive: true,
                            onConfirm: () {
                              context.read<GroupSettingsBloc>().add(LeaveGroupRequested(group.id));
                            },
                          );
                        },
                      ),
                      if (isOwner) ...[
                        Divider(color: colors.divider, height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          title: const Text('Delete Group', style: TextStyle(color: Colors.redAccent)),
                          onTap: () {
                            _confirmDialog(
                              context: context,
                              title: 'Delete Group',
                              message: 'This will permanently remove the group chat for all members. This cannot be undone.',
                              actionLabel: 'Delete',
                              isDestructive: true,
                              onConfirm: () {
                                context.read<GroupSettingsBloc>().add(DestroyGroupRequested(group.id));
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, ChatConversationModel group) {
    final colors = ChatTheme.colorsOf(context);
    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Edit Group Info', style: TextStyle(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(color: colors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: colors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.accent),
            onPressed: () {
              context.read<GroupSettingsBloc>().add(
                UpdateGroupDetailsRequested(
                  groupId: group.id,
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                ),
              );
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddMembersSheet(BuildContext context, ChatConversationModel group) {
    final colors = ChatTheme.colorsOf(context);
    final selectedUids = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(ChatTheme.space16),
                child: Column(
                  children: [
                    Text('Add Friends to Group', style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: ChatTheme.space12),
                    Expanded(
                      child: BlocBuilder<FriendsBloc, FriendsState>(
                        builder: (context, friendsState) {
                          List<Map<String, dynamic>> friends = [];
                          if (friendsState is FriendsLoaded) {
                            friends = friendsState.friends
                                .where((f) => !group.memberIds.contains(f['uid']))
                                .toList();
                          }

                          if (friends.isEmpty) {
                            return Center(child: Text('All friends are already members', style: TextStyle(color: colors.textSecondary)));
                          }

                          return ListView.builder(
                            itemCount: friends.length,
                            itemBuilder: (context, index) {
                              final f = friends[index];
                              final uid = f['uid'].toString();
                              final name = f['displayName']?.toString() ?? 'User';
                              final isSelected = selectedUids.contains(uid);

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: colors.accent,
                                title: Text(name, style: TextStyle(color: colors.textPrimary)),
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val == true) {
                                      selectedUids.add(uid);
                                    } else {
                                      selectedUids.remove(uid);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: colors.accent),
                        onPressed: selectedUids.isEmpty
                            ? null
                            : () {
                                context.read<GroupSettingsBloc>().add(
                                  AddGroupMembersRequested(groupId: group.id, memberIds: selectedUids.toList()),
                                );
                                Navigator.pop(sheetCtx);
                              },
                        child: const Text('Add Selected', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    final colors = ChatTheme.colorsOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(title, style: TextStyle(color: colors.textPrimary)),
        content: Text(message, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.redAccent : colors.accent,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
