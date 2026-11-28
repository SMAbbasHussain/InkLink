import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/workspace.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../../ui/widgets/paper_card.dart';
import '../../../core/web_formatters.dart';
import '../../../domain/models/web_workspace_rules.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_workspaces_cubit.dart';
import 'web_workspace_crud_dialogs.dart';

/// Live workspace membership card with optimistic role changes, member removal,
/// owner invite, and leave/delete workspace actions.
class WorkspaceMembersSection extends StatefulWidget {
  final Workspace workspace;

  /// Invoked after the user leaves or deletes the workspace.
  final VoidCallback? onExited;

  const WorkspaceMembersSection({
    super.key,
    required this.workspace,
    this.onExited,
  });

  @override
  State<WorkspaceMembersSection> createState() =>
      _WorkspaceMembersSectionState();
}

class _WorkspaceMembersSectionState extends State<WorkspaceMembersSection> {
  late final _workspaces = context.read<WebWorkspacesCubit>();
  StreamSubscription<List<WorkspaceMember>>? _sub;
  List<WorkspaceMember> _members = const [];
  bool _loading = true;

  bool get _isOwner =>
      widget.workspace.ownerId.isNotEmpty &&
      widget.workspace.ownerId == _workspaces.currentUserId;

  @override
  void initState() {
    super.initState();
    _sub = _workspaces.watchWorkspaceMembers(widget.workspace.id).listen((
      members,
    ) {
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _changeRole(WorkspaceMember member, String role) async {
    if (member.role == role) return;
    final previous = _members;
    setState(() {
      _members = [
        for (final m in _members)
          if (m.uid == member.uid) m.copyWith(role: role) else m,
      ];
    });
    try {
      await _workspaces.updateWorkspaceMemberRole(
        workspaceId: widget.workspace.id,
        memberUid: member.uid,
        role: role,
      );
      if (mounted) {
        showWebMessage(
          context,
          '${member.label} is now ${workspaceRoleLabel(role).toLowerCase()}.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _members = previous);
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _invite() async {
    if (await showWorkspaceInviteDialog(context, workspace: widget.workspace) &&
        mounted) {
      showWebMessage(context, 'Invitation sent.');
    }
  }

  Future<void> _leaveWorkspace() async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Leave this workspace?',
      message: 'You lose access to this workspace and its boards.',
      confirmLabel: 'Leave',
    );
    if (!confirmed || !mounted) return;
    try {
      await _workspaces.leaveWorkspace(widget.workspace.id);
      if (!mounted) return;
      showWebMessage(context, 'You left the workspace.');
      widget.onExited?.call();
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _deleteWorkspace() async {
    final confirmed = await showInkConfirmDialog(
      context,
      title:
          'Delete ${widget.workspace.name.isEmpty ? 'this workspace' : widget.workspace.name}?',
      message:
          'The workspace and its board links are removed for everyone. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    try {
      await _workspaces.deleteWorkspace(widget.workspace.id);
      if (!mounted) return;
      showWebMessage(context, 'Workspace deleted.');
      widget.onExited?.call();
    } catch (e) {
      if (mounted) showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  Future<void> _remove(WorkspaceMember member) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Remove ${member.label}?',
      message: 'They lose access to this workspace and its boards.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    final previous = _members;
    setState(() {
      _members = [
        for (final m in _members)
          if (m.uid != member.uid) m,
      ];
    });
    try {
      await _workspaces.removeWorkspaceMember(
        workspaceId: widget.workspace.id,
        memberUid: member.uid,
      );
      if (mounted) showWebMessage(context, '${member.label} was removed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _members = previous);
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return PaperCard(
      padding: const EdgeInsets.all(InkSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Members', style: InkType.title(tokens.ink)),
              const Spacer(),
              if (!_loading)
                Text(
                  '${_members.length}',
                  style: InkType.caption(tokens.inkMuted),
                ),
              if (_isOwner) ...[
                const SizedBox(width: InkSpacing.s8),
                TextButton.icon(
                  onPressed: _invite,
                  icon: Icon(LucideIcons.userPlus, size: 16, color: tokens.ink),
                  label: Text('Invite', style: InkType.caption(tokens.ink)),
                ),
              ],
            ],
          ),
          if (!_isOwner) ...[
            const SizedBox(height: InkSpacing.s4),
            Text(
              'Only the workspace owner can manage members.',
              style: InkType.caption(tokens.inkMuted),
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: InkSpacing.s16),
              child: WebLoading(),
            ),
          if (!_loading && _members.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: InkSpacing.s8),
              child: Text(
                'No members yet.',
                style: InkType.body(tokens.inkMuted),
              ),
            ),
          for (final member in _members)
            _MemberRow(
              key: ValueKey('member-row-${member.uid}'),
              member: member,
              canManage: _isOwner && member.role != 'owner',
              onRole: (role) => _changeRole(member, role),
              onRemove: () => _remove(member),
            ),
          const SizedBox(height: InkSpacing.s12),
          Divider(height: 1, color: tokens.glassStroke),
          const SizedBox(height: InkSpacing.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: _isOwner
                ? InkButton.danger(
                    label: 'Delete workspace',
                    compact: true,
                    expand: false,
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: tokens.danger,
                    ),
                    onPressed: _deleteWorkspace,
                  )
                : InkButton.secondary(
                    label: 'Leave workspace',
                    compact: true,
                    expand: false,
                    icon: Icon(LucideIcons.logOut, size: 16, color: tokens.ink),
                    onPressed: _leaveWorkspace,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final WorkspaceMember member;
  final bool canManage;
  final ValueChanged<String> onRole;
  final VoidCallback onRemove;

  const _MemberRow({
    super.key,
    required this.member,
    required this.canManage,
    required this.onRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final label = member.label;
    final email = member.email?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
      child: Row(
        children: [
          InkAvatar(
            imageUrl: member.photoUrl,
            initials: initialsOf(label),
            id: member.uid,
            size: 36,
          ),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InkType.bodyStrong(tokens.ink),
                ),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: InkType.caption(tokens.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: InkSpacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: member.role == 'owner' ? tokens.accentSoft : tokens.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              workspaceRoleLabel(member.role),
              key: ValueKey('member-role-${member.uid}'),
              style: InkType.caption(
                member.role == 'owner'
                    ? tokens.accentText
                    : tokens.inkSecondary,
              ),
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Manage $label',
              onSelected: (value) =>
                  value == 'remove' ? onRemove() : onRole(value),
              itemBuilder: (_) => [
                for (final role in assignableWorkspaceRoles)
                  PopupMenuItem(
                    value: role,
                    child: Text(workspaceRoleLabel(role)),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove member'),
                ),
              ],
              child: Icon(
                LucideIcons.ellipsisVertical,
                size: 18,
                color: tokens.inkSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
