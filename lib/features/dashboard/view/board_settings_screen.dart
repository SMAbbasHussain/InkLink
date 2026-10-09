import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../domain/models/board.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_chip.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_segmented.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
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

  Future<void> _confirmDelete(BuildContext context, String boardId) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Delete Board',
      message:
          'Are you sure you want to completely delete this board? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    context.read<DashboardBloc>().add(DashboardDeleteBoardRequested(boardId));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _updateNameDialog(BuildContext context, Board board) {
    final controller = TextEditingController(text: board.title);
    showDialog(
      context: context,
      builder: (ctx) => InkDialog(
        title: 'Rename Board',
        content: InkTextField(
          controller: controller,
          autofocus: true,
          hintText: 'New board name',
        ),
        actions: [
          InkButton.secondary(
            label: 'Cancel',
            expand: false,
            compact: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          InkButton.primary(
            label: 'Save',
            expand: false,
            compact: true,
            onPressed: () {
              Navigator.pop(ctx);
              final nextName = controller.text.trim();
              if (nextName.isNotEmpty && nextName != board.title) {
                context.read<DashboardBloc>().add(
                  DashboardRenameBoardRequested(board.id, nextName),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final currentUserId = context.select<AuthBloc, String?>((bloc) {
      final state = bloc.state;
      return state is Authenticated ? state.uid : null;
    });

    return Scaffold(
      backgroundColor: tokens.paper,
      appBar: AppBar(
        backgroundColor: tokens.paper,
        title: Text('Board Settings', style: InkType.title(tokens.ink)),
      ),
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
            return Center(child: CircularProgressIndicator(color: tokens.accent));
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
            padding: const EdgeInsets.all(InkSpacing.s16),
            children: [
              if (state.isOperationLoading)
                LinearProgressIndicator(color: tokens.accent),
              _sectionLabel(tokens, 'General'),
              const SizedBox(height: InkSpacing.s8),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Board Name', style: InkType.bodyStrong(tokens.ink)),
                      subtitle: Text(board.title, style: InkType.body(tokens.inkSecondary)),
                      trailing: isOwner
                          ? IconButton(
                              tooltip: 'Rename board',
                              icon: Icon(LucideIcons.pen, color: tokens.inkMuted),
                              onPressed: () => _updateNameDialog(context, board),
                            )
                          : null,
                    ),
                    Divider(height: 1, color: tokens.glassStroke),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Join Code', style: InkType.bodyStrong(tokens.ink)),
                      subtitle: Text(board.id, style: InkType.body(tokens.inkSecondary)),
                      trailing: IconButton(
                        tooltip: 'Copy join code',
                        icon: Icon(LucideIcons.copy, color: tokens.inkMuted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: board.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Join code copied!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: InkSpacing.s20),
              if (isOwner) ...[
                _sectionLabel(tokens, 'Permissions & Visibility'),
                const SizedBox(height: InkSpacing.s8),
                PaperCard(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visibility', style: InkType.title(tokens.ink)),
                      const SizedBox(height: InkSpacing.s12),
                      InkSegmented(
                        labels: const ['Private', 'Public'],
                        selectedIndex: _visibility == Board.visibilityPrivate ? 0 : 1,
                        onChanged: (i) {
                          setState(() {
                            _visibility = i == 0
                                ? Board.visibilityPrivate
                                : Board.visibilityPublic;
                          });
                        },
                      ),
                      if (_visibility == Board.visibilityPrivate) ...[
                        const SizedBox(height: InkSpacing.s16),
                        Text('Private board join policy', style: InkType.title(tokens.ink)),
                        const SizedBox(height: InkSpacing.s12),
                        _dropdown<String>(
                          value: _privateJoinPolicy,
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
                              setState(() => _privateJoinPolicy = value);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: InkSpacing.s16),
                      Text('Who can send invites', style: InkType.title(tokens.ink)),
                      const SizedBox(height: InkSpacing.s12),
                      _dropdown<String>(
                        value: _whoCanInvite,
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
                          if (value != null) setState(() => _whoCanInvite = value);
                        },
                      ),
                      const SizedBox(height: InkSpacing.s16),
                      Text('Default role for link/code join', style: InkType.title(tokens.ink)),
                      const SizedBox(height: InkSpacing.s12),
                      _dropdown<String>(
                        value: _defaultLinkJoinRole,
                        items: const [
                          DropdownMenuItem(value: Board.roleViewer, child: Text('Viewer')),
                          DropdownMenuItem(value: Board.roleEditor, child: Text('Editor')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _defaultLinkJoinRole = value);
                        },
                      ),
                      const SizedBox(height: InkSpacing.s20),
                      InkButton.secondary(
                        label: 'Save Form Settings',
                        onPressed: () => _saveSettings(context, board),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s20),
              ],
              if (canInvite) ...[
                _sectionLabel(tokens, 'Invite Members'),
                const SizedBox(height: InkSpacing.s8),
                PaperCard(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkTextField(
                        controller: _inviteController,
                        hintText: 'Emails (comma, space, or newline separated)',
                        leadingIcon: LucideIcons.mail,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (inviteEntries.isNotEmpty) ...[
                        const SizedBox(height: InkSpacing.s12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...validInviteEmails.map(
                              (email) => _inviteEmailChip(
                                tokens,
                                email,
                                valid: true,
                              ),
                            ),
                            ...invalidInviteEntries.map(
                              (entry) => _inviteEmailChip(
                                tokens,
                                entry,
                                valid: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: InkSpacing.s8),
                        Text(
                          '${validInviteEmails.length} valid, ${invalidInviteEntries.length} invalid',
                          style: InkType.caption(tokens.inkMuted),
                        ),
                      ],
                      const SizedBox(height: InkSpacing.s16),
                      Row(
                        children: [
                          Text('Invite as:', style: InkType.body(tokens.inkSecondary)),
                          const SizedBox(width: InkSpacing.s12),
                          Expanded(
                            child: _dropdown<String>(
                              value: _inviteTargetRole,
                              items: const [
                                DropdownMenuItem(value: Board.roleViewer, child: Text('Viewer')),
                                DropdownMenuItem(value: Board.roleEditor, child: Text('Editor')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _inviteTargetRole = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s16),
                      InkButton.primary(
                        label: 'Send Invites',
                        icon: const Icon(LucideIcons.send),
                        expand: false,
                        onPressed: canSendInvites
                            ? () => _sendInvites(context, validInviteEmails)
                            : null,
                      ),
                      if (state.infoMessage != null ||
                          state.unresolvedInviteEmails.isNotEmpty) ...[
                        const SizedBox(height: InkSpacing.s12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(InkSpacing.s12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: state.unresolvedInviteEmails.isEmpty
                                ? tokens.success.withValues(alpha: 0.12)
                                : tokens.pending.withValues(alpha: 0.15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (state.infoMessage != null)
                                Text(state.infoMessage!, style: InkType.bodyStrong(tokens.ink)),
                              if (state.unresolvedInviteEmails.isNotEmpty) ...[
                                const SizedBox(height: InkSpacing.s8),
                                Text('Unresolved emails', style: InkType.bodyStrong(tokens.ink)),
                                const SizedBox(height: InkSpacing.s8 - 2),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: state.unresolvedInviteEmails
                                      .map((email) => InkChip(label: email))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s20),
              ],
              Row(
                children: [
                  Expanded(child: _sectionLabel(tokens, 'Members')),
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
                      _showMembersSearch ? LucideIcons.x : LucideIcons.search,
                      color: tokens.inkMuted,
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (_showMembersSearch) ...[
                InkTextField(
                  controller: _searchController,
                  hintText: 'Search members',
                  leadingIcon: LucideIcons.search,
                  onChanged: (value) {
                    context.read<BoardSettingsBloc>().add(
                      BoardSettingsSearchChanged(value),
                    );
                  },
                ),
                const SizedBox(height: InkSpacing.s12),
              ],
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: Column(
                  children: [
                    _buildRoleSection(
                      context,
                      tokens,
                      state.filteredMembers,
                      'Owner',
                      const ['owner'],
                      isOwner,
                      currentUserId,
                    ),
                    _buildRoleSection(
                      context,
                      tokens,
                      state.filteredMembers,
                      'Editors',
                      const ['editor'],
                      isOwner,
                      currentUserId,
                    ),
                    _buildRoleSection(
                      context,
                      tokens,
                      state.filteredMembers,
                      'Viewers',
                      const ['viewer'],
                      isOwner,
                      currentUserId,
                    ),
                  ],
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: InkSpacing.s24),
                _sectionLabel(tokens, 'Danger Zone', color: tokens.danger),
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
                    label: 'Delete Board',
                    onPressed: () => _confirmDelete(context, board.id),
                  ),
                ),
              ],
              const SizedBox(height: InkSpacing.s32),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(InkTokens tokens, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s4),
      child: Text(text, style: InkType.label(color ?? tokens.inkMuted)),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      icon: const Icon(LucideIcons.chevronDown, size: 18),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _inviteEmailChip(InkTokens tokens, String text, {required bool valid}) {
    final color = valid ? tokens.accentText : tokens.danger;
    final bg = valid ? tokens.accentSoft : tokens.danger.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(InkRadii.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(valid ? LucideIcons.check : LucideIcons.triangleAlert, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: InkType.label(color)),
        ],
      ),
    );
  }

  Widget _buildRoleSection(
    BuildContext context,
    InkTokens tokens,
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
          padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
          child: Text(title, style: InkType.label(tokens.inkMuted)),
        ),
        ...filtered.map((member) {
          final isMe = member.uid == currentUserId;
          final canAdminMember = isOwner && !activeRoles.contains('owner');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s4),
            child: Row(
              children: [
                InkAvatar(
                  imageUrl: member.photoUrl,
                  initials: inkInitialsFor(member.label),
                  id: member.uid,
                  size: 36,
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${member.label}${isMe ? ' (You)' : ''}',
                        style: InkType.bodyStrong(tokens.ink),
                      ),
                      Text(
                        member.email ?? 'No email',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (canAdminMember)
                  PopupMenuButton<String>(
                    icon: Icon(LucideIcons.ellipsis, size: 18, color: tokens.inkMuted),
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
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(
                          'Remove from Board',
                          style: TextStyle(color: tokens.danger),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: InkSpacing.s12),
      ],
    );
  }

  Future<void> _confirmRemoveMember(BuildContext context, BoardMember member) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Remove Member',
      message: 'Are you sure you want to remove ${member.label} from this board?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    context.read<BoardSettingsBloc>().add(BoardSettingsMemberRemoved(member.uid));
  }
}
