import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/models/board.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/board_settings_bloc.dart';
import '../bloc/dashboard_bloc.dart';

class BoardSettingsScreen extends StatelessWidget {
  final Board board;

  const BoardSettingsScreen({super.key, required this.board});

  @override
  Widget build(BuildContext context) {
    return const _BoardSettingsView();
  }
}

class _BoardSettingsView extends StatefulWidget {
  const _BoardSettingsView();

  @override
  State<_BoardSettingsView> createState() => _BoardSettingsViewState();
}

class _BoardSettingsViewState extends State<_BoardSettingsView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inviteController = TextEditingController();

  late String _visibility;
  late String _privateJoinPolicy;
  late String _whoCanInvite;
  late String _defaultLinkJoinRole;
  late String _inviteTargetRole;
  bool _formInitialized = false;
  bool _showMembersSearch = false;
  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _searchController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _initFormFields(Board board) {
    if (_formInitialized) return;
    _visibility = board.visibility;
    _privateJoinPolicy = board.privateJoinPolicy;
    _whoCanInvite = board.whoCanInvite;
    _defaultLinkJoinRole = board.defaultLinkJoinRole;
    _inviteTargetRole = Board.roleViewer;
    _formInitialized = true;
  }

  bool _canCurrentUserInvite({required Board board, required bool isOwner}) {
    if (isOwner) return true;

    switch (board.whoCanInvite) {
      case Board.inviteAllMembers:
        return true;
      case Board.inviteOwnerEditor:
        return board.currentUserRole == Board.roleEditor;
      case Board.inviteOwnerOnly:
      default:
        return false;
    }
  }

  List<String> _splitInviteEntries(String raw) {
    return raw
        .split(RegExp(r'[\n,;\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _isValidEmail(String value) {
    return _emailRegex.hasMatch(value);
  }

  void _sendInvites(BuildContext context, List<String> invitedEmails) {
    context.read<BoardSettingsBloc>().add(
      BoardSettingsInviteSubmitted(
        rawEmails: invitedEmails.join(','),
        targetRole: _inviteTargetRole,
      ),
    );
    _inviteController.clear();
    setState(() {});
  }

  void _saveSettings(BuildContext context, Board board) {
    context.read<DashboardBloc>().add(
      DashboardUpdateBoardSettingsRequested(
        boardId: board.id,
        visibility: _visibility,
        privateJoinPolicy: _privateJoinPolicy,
        whoCanInvite: _whoCanInvite,
        defaultLinkJoinRole: _defaultLinkJoinRole,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully.')),
    );
  }

  void _confirmDelete(BuildContext context, String boardId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Board'),
        content: const Text(
          'Are you sure you want to completely delete this board? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DashboardBloc>().add(
                DashboardDeleteBoardRequested(boardId),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _updateNameDialog(BuildContext context, Board board) {
    final controller = TextEditingController(text: board.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Board'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New board name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final nextName = controller.text.trim();
              if (nextName.isNotEmpty && nextName != board.title) {
                context.read<DashboardBloc>().add(
                  DashboardRenameBoardRequested(board.id, nextName),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.select<AuthBloc, String?>((bloc) {
      final state = bloc.state;
      return state is Authenticated ? state.uid : null;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Board Settings')),
      body: BlocConsumer<BoardSettingsBloc, BoardSettingsState>(
        listener: (context, state) {
          if (state.errorMessage != null && !state.isOperationLoading) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          if (state.status == BoardSettingsStatus.loading ||
              state.board == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final board = state.board!;
          final isOwner = board.ownerId == currentUserId;
          final canInvite = _canCurrentUserInvite(
            board: board,
            isOwner: isOwner,
          );
          final inviteEntries = _splitInviteEntries(_inviteController.text);
          final validInviteEmails = inviteEntries
              .where(_isValidEmail)
              .toSet()
              .toList();
          final invalidInviteEntries = inviteEntries
              .where((entry) => !_isValidEmail(entry))
              .toList();
          final canSendInvites =
              validInviteEmails.isNotEmpty &&
              invalidInviteEntries.isEmpty &&
              !state.isOperationLoading;
          _initFormFields(board);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isOperationLoading) const LinearProgressIndicator(),
              const Text(
                'General',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Board Name'),
                subtitle: Text(board.title),
                trailing: isOwner
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _updateNameDialog(context, board),
                      )
                    : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Join Code'),
                subtitle: Text(board.id),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: board.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Join code copied!')),
                    );
                  },
                ),
              ),
              const Divider(height: 32),
              if (isOwner) ...[
                const Text(
                  'Permissions & Visibility',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Visibility',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: Board.visibilityPrivate,
                      label: Text('Private'),
                    ),
                    ButtonSegment<String>(
                      value: Board.visibilityPublic,
                      label: Text('Public'),
                    ),
                  ],
                  selected: <String>{_visibility},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _visibility = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_visibility == Board.visibilityPrivate) ...[
                  const Text(
                    'Private board join policy',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _privateJoinPolicy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: Board.policyOwnerOnlyInvite,
                        child: Text('Only owner can invite'),
                      ),
                      DropdownMenuItem(
                        value: Board.policyLinkCanJoin,
                        child: Text('Anyone with join code can join'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _privateJoinPolicy = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Who can send invites',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _whoCanInvite,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: Board.inviteOwnerOnly,
                      child: Text('Owner only'),
                    ),
                    DropdownMenuItem(
                      value: Board.inviteOwnerEditor,
                      child: Text('Owner + Editors'),
                    ),
                    DropdownMenuItem(
                      value: Board.inviteAllMembers,
                      child: Text('All members'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _whoCanInvite = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Default role for link/code join',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _defaultLinkJoinRole,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: Board.roleViewer,
                      child: Text('Viewer'),
                    ),
                    DropdownMenuItem(
                      value: Board.roleEditor,
                      child: Text('Editor'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _defaultLinkJoinRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _saveSettings(context, board),
                  child: const Text('Save Form Settings'),
                ),
                const SizedBox(height: 16),
              ],
              const Divider(height: 32),
              if (canInvite) ...[
                const Text(
                  'Invite Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inviteController,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Emails (comma, space, or newline separated)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (inviteEntries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...validInviteEmails.map(
                        (email) => Chip(
                          label: Text(email),
                          avatar: const Icon(Icons.check, size: 16),
                        ),
                      ),
                      ...invalidInviteEntries.map(
                        (entry) => Chip(
                          label: Text(entry),
                          avatar: const Icon(Icons.error_outline, size: 16),
                          backgroundColor: Colors.red.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${validInviteEmails.length} valid, ${invalidInviteEntries.length} invalid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Invite as:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _inviteTargetRole,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: Board.roleViewer,
                            child: Text('Viewer'),
                          ),
                          DropdownMenuItem(
                            value: Board.roleEditor,
                            child: Text('Editor'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _inviteTargetRole = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: canSendInvites
                        ? () => _sendInvites(context, validInviteEmails)
                        : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Invites'),
                  ),
                ),
                if (state.infoMessage != null ||
                    state.unresolvedInviteEmails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: state.unresolvedInviteEmails.isEmpty
                          ? Colors.green.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.infoMessage != null)
                          Text(
                            state.infoMessage!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        if (state.unresolvedInviteEmails.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Unresolved emails',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: state.unresolvedInviteEmails
                                .map(
                                  (email) => Chip(
                                    label: Text(email),
                                    avatar: const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const Divider(height: 32),
              ],
              const Text(
                'Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    tooltip: 'Search members',
                    onPressed: () {
                      setState(() {
                        _showMembersSearch = !_showMembersSearch;
                      });
                      if (!_showMembersSearch) {
                        _searchController.clear();
                        context.read<BoardSettingsBloc>().add(
                          const BoardSettingsSearchChanged(''),
                        );
                      }
                    },
                    icon: Icon(
                      _showMembersSearch ? Icons.search_off : Icons.search,
                    ),
                  ),
                ],
              ),
              if (_showMembersSearch) ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search members',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    context.read<BoardSettingsBloc>().add(
                      BoardSettingsSearchChanged(value),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              _buildRoleSection(
                context,
                state.filteredMembers,
                'Owner',
                const ['owner'],
                isOwner,
                currentUserId,
              ),
              _buildRoleSection(
                context,
                state.filteredMembers,
                'Editors',
                const ['editor'],
                isOwner,
                currentUserId,
              ),
              _buildRoleSection(
                context,
                state.filteredMembers,
                'Viewers',
                const ['viewer'],
                isOwner,
                currentUserId,
              ),
              if (isOwner) ...[
                const Divider(height: 32),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _confirmDelete(context, board.id),
                  child: const Text(
                    'Delete Board',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleSection(
    BuildContext context,
    List<BoardMember> members,
    String title,
    List<String> activeRoles,
    bool isOwner,
    String? currentUserId,
  ) {
    final filtered = members
        .where((m) => activeRoles.contains(m.role))
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...filtered.map((member) {
          final isMe = member.uid == currentUserId;
          final canAdminMember = isOwner && !activeRoles.contains('owner');

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: member.photoUrl != null
                  ? NetworkImage(member.photoUrl!)
                  : null,
              child: member.photoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text('${member.label}${isMe ? ' (You)' : ''}'),
            subtitle: Text(member.email ?? 'No email'),
            trailing: canAdminMember
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'remove') {
                        _confirmRemoveMember(context, member);
                      } else if (value == 'make_editor') {
                        context.read<BoardSettingsBloc>().add(
                          BoardSettingsMemberRoleUpdated(member.uid, 'editor'),
                        );
                      } else if (value == 'make_viewer') {
                        context.read<BoardSettingsBloc>().add(
                          BoardSettingsMemberRoleUpdated(member.uid, 'viewer'),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (member.role != 'editor')
                        const PopupMenuItem(
                          value: 'make_editor',
                          child: Text('Make Editor'),
                        ),
                      if (member.role != 'viewer')
                        const PopupMenuItem(
                          value: 'make_viewer',
                          child: Text('Make Viewer'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text(
                          'Remove from Board',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  )
                : null,
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  void _confirmRemoveMember(BuildContext context, BoardMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.label} from this board?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BoardSettingsBloc>().add(
                BoardSettingsMemberRemoved(member.uid),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
