import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/helpers.dart';
import '../../../domain/models/workspace.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_chip.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../../ui/widgets/status_chip.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../profile/view/profile_route.dart';
import '../bloc/workspace_bloc.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  final String workspaceId;

  const WorkspaceSettingsScreen({required this.workspaceId, super.key});

  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _inviteSearchController;
  bool _isSaving = false;
  bool _showInviteComposer = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _inviteSearchController = TextEditingController();

    context.read<WorkspaceBloc>().add(
      LoadWorkspaceMembersRequested(widget.workspaceId),
    );
    context.read<FriendsBloc>().add(LoadFriendsInfo());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _inviteSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkspaceDetails() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace name is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    context.read<WorkspaceBloc>().add(
      UpdateWorkspaceRequested(
        workspaceId: widget.workspaceId,
        name: name,
        description: description,
      ),
    );
  }

  Future<void> _inviteMember(String targetUid) async {
    context.read<WorkspaceBloc>().add(
      InviteToWorkspaceRequested(
        workspaceId: widget.workspaceId,
        invitedUserIds: [targetUid],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> friend, String fallbackLabel) {
    final photoUrl = (friend['photoURL'] ?? '').toString();
    final uid = (friend['uid'] ?? '').toString();
    return InkAvatar(
      imageUrl: photoUrl.isEmpty ? null : photoUrl,
      initials: inkInitialsFor(fallbackLabel),
      id: uid,
      size: 40,
    );
  }

  Color _roleColor(InkTokens tokens, String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return tokens.accent;
      case 'editor':
        return tokens.inkSecondary;
      default:
        return tokens.inkMuted;
    }
  }

  Widget _buildMemberTile(
    BuildContext context,
    WorkspaceMember member, {
    required bool canRemove,
  }) {
    final tokens = context.ink;
    final roleColor = _roleColor(tokens, member.role);
    final secondary = member.email != null && member.email!.trim().isNotEmpty
        ? member.email!.trim()
        : member.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: InkSpacing.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: tokens.paper,
        boxShadow: tokens.paperShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            buildProfileRoute(context, userId: member.uid),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              InkAvatar(
                imageUrl: member.photoUrl,
                initials: inkInitialsFor(member.label),
                id: member.uid,
                size: 44,
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InkType.bodyStrong(tokens.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InkType.caption(tokens.inkMuted),
                    ),
                    const SizedBox(height: InkSpacing.s8),
                    Row(
                      children: [
                        InkChip(
                          label: member.role.toUpperCase(),
                          backgroundColor: roleColor.withValues(alpha: 0.12),
                          textColor: roleColor,
                        ),
                        const SizedBox(width: InkSpacing.s8),
                        StatusChip(
                          status: _statusFor(member.status),
                          label: member.status,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: Icon(LucideIcons.userX, color: tokens.danger),
                  tooltip: 'Remove member',
                  onPressed: () => _removeMember(member.uid),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InkStatus _statusFor(String status) {
    switch (status.toLowerCase()) {
      case 'invited':
      case 'pending':
        return InkStatus.pending;
      case 'declined':
        return InkStatus.declined;
      default:
        return InkStatus.accepted;
    }
  }

  Future<void> _removeMember(String memberUid) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Remove Member?',
      message: 'This member will lose workspace access.',
      confirmLabel: 'Remove',
    );

    if (confirmed && mounted) {
      context.read<WorkspaceBloc>().add(
        RemoveWorkspaceMemberRequested(
          workspaceId: widget.workspaceId,
          memberUid: memberUid,
        ),
      );
    }
  }

  Future<void> _leaveWorkspace() async {
    // Show a dialog asking which imported boards to keep
    final importedBoardsToKeep = <String>{};
    final tokens = context.ink;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => InkDialog(
        title: 'Leave Workspace?',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When you leave this workspace:',
                style: InkType.bodyStrong(tokens.ink),
              ),
              const SizedBox(height: InkSpacing.s12),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Boards created in this workspace will remove you as a member',
                      style: InkType.caption(tokens.inkSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Imported boards can optionally be kept in your board list',
                      style: InkType.caption(tokens.inkSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s16),
              Text(
                'You will no longer have access to this workspace.',
                style: InkType.caption(tokens.danger),
              ),
            ],
          ),
        ),
        actions: [
          InkButton.secondary(
            label: 'Cancel',
            expand: false,
            compact: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          InkButton.dangerConfirm(
            label: 'Leave',
            expand: false,
            compact: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<WorkspaceBloc>().add(
        LeaveWorkspaceRequested(
          widget.workspaceId,
          importedBoardsToKeep: importedBoardsToKeep.toList(),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _deleteWorkspace() async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Delete Workspace?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      context.read<WorkspaceBloc>().add(
        DeleteWorkspaceRequested(widget.workspaceId),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Workspace Settings', style: InkType.title(tokens.ink)),
      ),
      body: BlocConsumer<WorkspaceBloc, WorkspaceState>(
        listener: (context, state) {
          if (state is! WorkspaceLoaded) return;

          if (state.actionError != null && state.actionError!.isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.actionError!)));
          }

          if (state.actionInfo != null && state.actionInfo!.isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.actionInfo!)));
          }

          if (_isSaving &&
              (state.actionInfo != null || state.actionError != null)) {
            setState(() => _isSaving = false);
          }
        },
        builder: (context, state) {
          if (state is! WorkspaceLoaded) {
            return Center(child: CircularProgressIndicator(color: tokens.accent));
          }

          Workspace? workspace;
          for (final candidate in [
            ...state.ownedWorkspaces,
            ...state.memberWorkspaces,
          ]) {
            if (candidate.id == widget.workspaceId) {
              workspace = candidate;
              break;
            }
          }

          if (workspace == null) {
            return Center(
              child: Text('Workspace not found', style: InkType.body(tokens.inkMuted)),
            );
          }

          if (_nameController.text.isEmpty) {
            _nameController.text = workspace.name;
          }
          if (_descriptionController.text.isEmpty) {
            _descriptionController.text = workspace.description;
          }

          final isOwner = workspace.currentUserRole == 'owner';
          final members =
              state.membersByWorkspace[widget.workspaceId] ?? const [];
          final memberUids = members.map((member) => member.uid).toSet();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(InkSpacing.s16),
              children: [
                Text('Details', style: InkType.title(tokens.ink)),
                const SizedBox(height: InkSpacing.s12),
                PaperCard(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkTextField(
                        controller: _nameController,
                        enabled: isOwner && !_isSaving,
                        labelText: 'Workspace name',
                      ),
                      const SizedBox(height: InkSpacing.s12),
                      InkTextField(
                        controller: _descriptionController,
                        enabled: isOwner && !_isSaving,
                        maxLines: 3,
                        labelText: 'Description',
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: InkSpacing.s12),
                        InkButton.primary(
                          label: _isSaving ? '' : 'Save workspace details',
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                          onPressed: _isSaving ? null : _saveWorkspaceDetails,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s24),
                Row(
                  children: [
                    Text('Members', style: InkType.title(tokens.ink)),
                    const Spacer(),
                    if (isOwner)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showInviteComposer = !_showInviteComposer;
                            if (!_showInviteComposer) {
                              _inviteSearchController.clear();
                            }
                          });
                        },
                        icon: Icon(
                          _showInviteComposer ? LucideIcons.x : LucideIcons.userPlus,
                          size: 18,
                        ),
                        label: Text(_showInviteComposer ? 'Hide invite' : 'Invite'),
                      ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s8),
                if (members.isEmpty)
                  Text('No members found.', style: InkType.body(tokens.inkMuted))
                else
                  ...members.map((member) {
                    final canRemove = isOwner && member.role != 'owner';
                    return _buildMemberTile(
                      context,
                      member,
                      canRemove: canRemove,
                    );
                  }),
                const SizedBox(height: InkSpacing.s24),
                if (isOwner && _showInviteComposer) ...[
                  InkTextField(
                    controller: _inviteSearchController,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => setState(() {}),
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'Search friends by name or email',
                    leadingIcon: LucideIcons.search,
                    suffixIcon: _inviteSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(LucideIcons.x, size: 18, color: tokens.inkMuted),
                            onPressed: () {
                              setState(() {
                                _inviteSearchController.clear();
                              });
                            },
                          ),
                  ),
                  const SizedBox(height: InkSpacing.s12),
                  BlocBuilder<FriendsBloc, FriendsState>(
                    builder: (context, friendsState) {
                      if (friendsState is FriendsInitial ||
                          friendsState is FriendsLoading) {
                        return Center(child: CircularProgressIndicator(color: tokens.accent));
                      }

                      final friends = friendsState is FriendsLoaded
                          ? friendsState.friends
                          : const <Map<String, dynamic>>[];

                      final query = _inviteSearchController.text
                          .trim()
                          .toLowerCase();
                      final filteredFriends = friends.where((friend) {
                        final uid = (friend['uid'] ?? '').toString();
                        final displayName = (friend['displayName'] ?? '')
                            .toString();
                        final email = (friend['email'] ?? '').toString();
                        final searchable = '$displayName $email $uid'
                            .toLowerCase();
                        return query.isEmpty || searchable.contains(query);
                      }).toList();

                      Widget buildFriendRow(Map<String, dynamic> friend) {
                        final uid = (friend['uid'] ?? '').toString();
                        final displayName = (friend['displayName'] ?? '')
                            .toString();
                        final email = (friend['email'] ?? '').toString();
                        final isAlreadyMember = memberUids.contains(uid);
                        final isInviting = state.invitingUserIds.contains(uid);
                        final title = displayName.isNotEmpty
                            ? displayName
                            : (email.isNotEmpty ? email : uid);

                        return Container(
                          margin: const EdgeInsets.only(bottom: InkSpacing.s8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: InkSpacing.s12,
                            vertical: InkSpacing.s8,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.paper,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: tokens.paperShadow,
                          ),
                          child: Row(
                            children: [
                              _buildAvatar(friend, title),
                              const SizedBox(width: InkSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: InkType.bodyStrong(tokens.ink)),
                                    Text(
                                      email.isNotEmpty ? email : uid,
                                      style: InkType.caption(tokens.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              isAlreadyMember
                                  ? StatusChip(status: InkStatus.accepted, label: 'Member')
                                  : InkButton.primary(
                                      label: isInviting ? '' : 'Invite',
                                      compact: true,
                                      expand: false,
                                      icon: isInviting
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                      onPressed: uid.isEmpty || isInviting
                                          ? null
                                          : () => _inviteMember(uid),
                                    ),
                            ],
                          ),
                        );
                      }

                      if (query.isEmpty) {
                        if (filteredFriends.isEmpty) {
                          return Text(
                            'No friends found for invite.',
                            style: InkType.body(tokens.inkMuted),
                          );
                        }
                        return Column(children: filteredFriends.map(buildFriendRow).toList());
                      }

                      if (filteredFriends.isNotEmpty) {
                        return Column(children: filteredFriends.map(buildFriendRow).toList());
                      }

                      if (isValidEmail(query)) {
                        final typedEmail = _inviteSearchController.text.trim();
                        final isInviting = state.invitingUserIds.contains(typedEmail);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: InkSpacing.s12,
                            vertical: InkSpacing.s8,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.paper,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: tokens.paperShadow,
                          ),
                          child: Row(
                            children: [
                              InkAvatar(initials: '?', id: typedEmail, size: 40),
                              const SizedBox(width: InkSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(typedEmail, style: InkType.bodyStrong(tokens.ink)),
                                    Text(
                                      'Invite by email address',
                                      style: InkType.caption(tokens.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              InkButton.primary(
                                label: isInviting ? '' : 'Invite',
                                compact: true,
                                expand: false,
                                icon: isInviting
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                                onPressed: isInviting ? null : () => _inviteMember(typedEmail),
                              ),
                            ],
                          ),
                        );
                      }

                      return Text(
                        'No matching friends. Enter a valid email to invite a non-friend.',
                        style: InkType.body(tokens.inkMuted),
                      );
                    },
                  ),
                  const SizedBox(height: InkSpacing.s24),
                ],
                Text('Danger zone', style: InkType.title(tokens.danger)),
                const SizedBox(height: InkSpacing.s8),
                Container(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
                    boxShadow: tokens.paperShadow,
                  ),
                  child: InkButton.danger(
                    label: isOwner ? 'Delete workspace' : 'Leave workspace',
                    onPressed: isOwner ? _deleteWorkspace : _leaveWorkspace,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
