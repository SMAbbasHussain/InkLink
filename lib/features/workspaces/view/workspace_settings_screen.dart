import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/helpers.dart';
import '../../../domain/models/workspace.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/bloc/friends_event.dart';
import '../../friends/bloc/friends_state.dart';
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
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
        child: const SizedBox.shrink(),
      );
    }

    return CircleAvatar(
      child: Text(
        fallbackLabel.isEmpty
            ? 'U'
            : fallbackLabel.substring(0, 1).toUpperCase(),
      ),
    );
  }

  Widget _buildMemberAvatar(WorkspaceMember member) {
    final url = (member.photoUrl ?? '').trim();
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    final label = member.label.trim();
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.indigo.withOpacity(0.12),
      child: Text(
        label.isEmpty ? 'U' : label.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _roleChipColor(BuildContext context, String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.deepPurple;
      case 'editor':
        return Colors.teal;
      case 'viewer':
        return Colors.blueGrey;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildMemberTile(
    BuildContext context,
    WorkspaceMember member, {
    required bool canRemove,
  }) {
    final roleColor = _roleChipColor(context, member.role);
    final secondary = member.email != null && member.email!.trim().isNotEmpty
        ? member.email!.trim()
        : member.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
              _buildMemberAvatar(member),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            member.role.toUpperCase(),
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          member.status,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => _removeMember(member.uid),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeMember(String memberUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: const Text('This member will lose workspace access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<WorkspaceBloc>().add(
        RemoveWorkspaceMemberRequested(
          workspaceId: widget.workspaceId,
          memberUid: memberUid,
        ),
      );
    }
  }

  Future<void> _leaveWorkspace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Workspace?'),
        content: const Text(
          'You will no longer have access to this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<WorkspaceBloc>().add(
        LeaveWorkspaceRequested(widget.workspaceId),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _deleteWorkspace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workspace?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<WorkspaceBloc>().add(
        DeleteWorkspaceRequested(widget.workspaceId),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workspace Settings')),
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
            return const Center(child: CircularProgressIndicator());
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
            return const Center(child: Text('Workspace not found'));
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
              padding: const EdgeInsets.all(16),
              children: [
                Text('Details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  enabled: isOwner && !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Workspace name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  enabled: isOwner && !_isSaving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (isOwner)
                  FilledButton(
                    onPressed: _isSaving ? null : _saveWorkspaceDetails,
                    child: _isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save workspace details'),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Members',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                          _showInviteComposer ? Icons.close : Icons.person_add,
                        ),
                        label: Text(
                          _showInviteComposer ? 'Hide invite' : 'Invite',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text('No members found.')
                else
                  ...members.map((member) {
                    final canRemove = isOwner && member.role != 'owner';
                    return _buildMemberTile(
                      context,
                      member,
                      canRemove: canRemove,
                    );
                  }),
                const SizedBox(height: 24),
                if (isOwner && _showInviteComposer) ...[
                  TextField(
                    controller: _inviteSearchController,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => setState(() {}),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Search friends by name or email',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _inviteSearchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _inviteSearchController.clear();
                                });
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<FriendsBloc, FriendsState>(
                    builder: (context, friendsState) {
                      if (friendsState is FriendsInitial ||
                          friendsState is FriendsLoading) {
                        return const Center(child: CircularProgressIndicator());
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

                      if (query.isEmpty) {
                        if (filteredFriends.isEmpty) {
                          return const Text('No friends found for invite.');
                        }

                        return Column(
                          children: filteredFriends.map((friend) {
                            final uid = (friend['uid'] ?? '').toString();
                            final displayName = (friend['displayName'] ?? '')
                                .toString();
                            final email = (friend['email'] ?? '').toString();
                            final isAlreadyMember = memberUids.contains(uid);
                            final isInviting = state.invitingUserIds.contains(
                              uid,
                            );
                            final title = displayName.isNotEmpty
                                ? displayName
                                : (email.isNotEmpty ? email : uid);

                            return Card(
                              child: ListTile(
                                leading: _buildAvatar(friend, title),
                                title: Text(title),
                                subtitle: Text(email.isNotEmpty ? email : uid),
                                trailing: isAlreadyMember
                                    ? const Text('Member')
                                    : FilledButton(
                                        onPressed: uid.isEmpty || isInviting
                                            ? null
                                            : () => _inviteMember(uid),
                                        child: isInviting
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text('Invite'),
                                      ),
                              ),
                            );
                          }).toList(),
                        );
                      }

                      if (filteredFriends.isNotEmpty) {
                        return Column(
                          children: filteredFriends.map((friend) {
                            final uid = (friend['uid'] ?? '').toString();
                            final displayName = (friend['displayName'] ?? '')
                                .toString();
                            final email = (friend['email'] ?? '').toString();
                            final isAlreadyMember = memberUids.contains(uid);
                            final isInviting = state.invitingUserIds.contains(
                              uid,
                            );
                            final title = displayName.isNotEmpty
                                ? displayName
                                : (email.isNotEmpty ? email : uid);

                            return Card(
                              child: ListTile(
                                leading: _buildAvatar(friend, title),
                                title: Text(title),
                                subtitle: Text(email.isNotEmpty ? email : uid),
                                trailing: isAlreadyMember
                                    ? const Text('Member')
                                    : FilledButton(
                                        onPressed: uid.isEmpty || isInviting
                                            ? null
                                            : () => _inviteMember(uid),
                                        child: isInviting
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text('Invite'),
                                      ),
                              ),
                            );
                          }).toList(),
                        );
                      }

                      if (isValidEmail(query)) {
                        final typedEmail = _inviteSearchController.text.trim();
                        final isInviting = state.invitingUserIds.contains(
                          typedEmail,
                        );
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.mail_outline),
                            ),
                            title: Text(typedEmail),
                            subtitle: const Text('Invite by email address'),
                            trailing: FilledButton(
                              onPressed: isInviting
                                  ? null
                                  : () => _inviteMember(typedEmail),
                              child: isInviting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Invite'),
                            ),
                          ),
                        );
                      }

                      return const Text(
                        'No matching friends. Enter a valid email to invite a non-friend.',
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Danger zone',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 8),
                if (isOwner)
                  OutlinedButton(
                    onPressed: _deleteWorkspace,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Delete workspace'),
                  )
                else
                  OutlinedButton(
                    onPressed: _leaveWorkspace,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Leave workspace'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
