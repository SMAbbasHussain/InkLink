import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../../ui/widgets/ink_initials.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../bloc/canvas_bloc.dart';
import '../widgets/sliding_tray.dart';

class MembersTray extends StatefulWidget {
  final bool isOpen;
  final VoidCallback? onClose;

  const MembersTray({super.key, required this.isOpen, this.onClose});

  @override
  State<MembersTray> createState() => _MembersTrayState();
}

class _MembersTrayState extends State<MembersTray> {
  late FocusNode _searchFocusNode;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearchMode() {
    setState(() => _isSearchMode = true);
    _searchFocusNode.requestFocus();
  }

  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _searchController.clear();
    });
    context.read<CanvasBloc>().add(const CanvasMemberSearchQueryChanged(''));
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String query) {
    context.read<CanvasBloc>().add(CanvasMemberSearchQueryChanged(query));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (prev, curr) =>
          prev.filteredBoardMembers != curr.filteredBoardMembers ||
          prev.memberSearchQuery != curr.memberSearchQuery ||
          prev.currentUserRole != curr.currentUserRole ||
          prev.isVoiceCallActive != curr.isVoiceCallActive ||
          prev.isChatDrawerOpen != curr.isChatDrawerOpen ||
          prev.isCommentsTrayOpen != curr.isCommentsTrayOpen,
      builder: (context, state) {
        final filteredMembers = state.filteredBoardMembers;

        return SlidingTray(
          isOpen: widget.isOpen,
          direction: TrayDirection.left,
          title: 'Members',
          width: 320,
          onClose: widget.onClose,
          headerActions: _isSearchMode
              ? IconButton(
                  onPressed: _exitSearchMode,
                  icon: Icon(LucideIcons.x, size: 18, color: tokens.inkMuted),
                  tooltip: 'Close search',
                  splashRadius: 18,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        final bloc = context.read<CanvasBloc>();
                        if (bloc.state.isVoiceCallActive) {
                          bloc.add(const CanvasLeaveVoiceCallRequested());
                        } else {
                          bloc.add(const CanvasJoinVoiceCallRequested());
                        }
                      },
                      icon: Icon(
                        state.isVoiceCallActive
                            ? LucideIcons.phoneOff
                            : LucideIcons.phone,
                        size: 18,
                        color: state.isVoiceCallActive
                            ? tokens.success
                            : tokens.inkMuted,
                      ),
                      tooltip: state.isVoiceCallActive
                          ? 'Leave Voice Call'
                          : 'Join Voice Call',
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: () {
                        context
                            .read<CanvasBloc>()
                            .add(const CanvasToggleChatDrawer());
                      },
                      icon: Icon(
                        LucideIcons.messageSquare,
                        size: 18,
                        color: state.isChatDrawerOpen
                            ? tokens.accent
                            : tokens.inkMuted,
                      ),
                      tooltip: 'Board Chat',
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: () {
                        context
                            .read<CanvasBloc>()
                            .add(const CanvasToggleCommentsTray());
                      },
                      icon: Icon(
                        LucideIcons.messageCircle,
                        size: 18,
                        color: state.isCommentsTrayOpen
                            ? tokens.accent
                            : tokens.inkMuted,
                      ),
                      tooltip: 'Comments',
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: _enterSearchMode,
                      icon: Icon(LucideIcons.search, size: 18, color: tokens.inkMuted),
                      tooltip: 'Search members',
                      splashRadius: 18,
                    ),
                  ],
                ),
          child: Column(
            children: [
              if (_isSearchMode)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: InkTextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    hintText: 'Search members...',
                    leadingIcon: LucideIcons.search,
                    suffixIcon: IconButton(
                      tooltip: 'Close search',
                      icon: Icon(LucideIcons.x, size: 18, color: tokens.inkMuted),
                      onPressed: _exitSearchMode,
                    ),
                  ),
                ),

              /// Members list grouped by role
              Expanded(
                child: filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.users, size: 48, color: tokens.inkMuted),
                            const SizedBox(height: InkSpacing.s12),
                            Text(
                              _isSearchMode ? 'No members found' : 'No members yet',
                              style: InkType.body(tokens.inkMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ..._buildMemberSection(
                            context,
                            tokens,
                            'Owner',
                            filteredMembers,
                            Board.roleOwner,
                            tokens.accent,
                            state,
                          ),
                          ..._buildMemberSection(
                            context,
                            tokens,
                            'Editor',
                            filteredMembers,
                            Board.roleEditor,
                            tokens.inkSecondary,
                            state,
                          ),
                          ..._buildMemberSection(
                            context,
                            tokens,
                            'Viewer',
                            filteredMembers,
                            Board.roleViewer,
                            tokens.inkMuted,
                            state,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMemberSection(
    BuildContext context,
    InkTokens tokens,
    String roleLabel,
    List<BoardMember> allMembers,
    String roleValue,
    Color roleColor,
    CanvasState state,
  ) {
    final membersInRole = allMembers.where((m) => m.role == roleValue).toList();
    if (membersInRole.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: roleColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: InkSpacing.s8),
            Text(
              roleLabel.toUpperCase(),
              style: InkType.caption(tokens.inkSecondary),
            ),
            const SizedBox(width: InkSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${membersInRole.length}',
                style: InkType.caption(tokens.inkMuted),
              ),
            ),
          ],
        ),
      ),
      ...membersInRole.map((member) => _buildMemberTile(context, tokens, member, state)),
    ];
  }

  Widget _buildMemberTile(
    BuildContext context,
    InkTokens tokens,
    BoardMember member,
    CanvasState state,
  ) {
    final displayName = member.displayName ?? member.email ?? 'Unknown';
    final subtitle = member.email ?? 'No email';
    final isOwner = state.currentUserRole == Board.roleOwner;
    final isTargetOwner = member.role == Board.roleOwner;
    final canManage = isOwner && !isTargetOwner;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          InkAvatar(
            imageUrl: member.photoUrl,
            initials: inkInitialsFor(displayName),
            id: member.uid,
            size: 36,
          ),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InkType.bodyStrong(tokens.ink),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InkType.caption(tokens.inkMuted),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: tokens.inkSecondary),
              tooltip: 'Member options',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(InkRadii.input),
              ),
              color: tokens.paper,
              onSelected: (action) {
                if (action == 'toggle_role') {
                  final newRole = member.role == Board.roleEditor
                      ? Board.roleViewer
                      : Board.roleEditor;
                  context.read<CanvasBloc>().add(
                        CanvasUpdateBoardMemberRole(
                          targetUid: member.uid,
                          newRole: newRole,
                        ),
                      );
                } else if (action == 'revoke') {
                  _confirmRevokeMember(context, tokens, member, displayName);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_role',
                  child: Row(
                    children: [
                      Icon(
                        member.role == Board.roleEditor
                            ? LucideIcons.eye
                            : LucideIcons.pencil,
                        size: 16,
                        color: tokens.ink,
                      ),
                      const SizedBox(width: InkSpacing.s8),
                      Text(
                        member.role == Board.roleEditor
                            ? 'Change to Viewer'
                            : 'Change to Editor',
                        style: InkType.body(tokens.ink),
                      ),
                    ],
                  ),
                ),
                PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'revoke',
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.userMinus,
                        size: 16,
                        color: tokens.danger,
                      ),
                      const SizedBox(width: InkSpacing.s8),
                      Text(
                        'Revoke Access',
                        style: InkType.body(tokens.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRevokeMember(
    BuildContext context,
    InkTokens tokens,
    BoardMember member,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => InkDialog(
        title: 'Revoke Member Access',
        icon: LucideIcons.userMinus,
        content: Text(
          'Are you sure you want to remove "$displayName" from this board? They will lose access immediately.',
          style: InkType.body(tokens.inkSecondary),
        ),
        actions: [
          InkButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogCtx).pop(false),
          ),
          InkButton.danger(
            label: 'Revoke',
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<CanvasBloc>().add(CanvasRemoveBoardMember(member.uid));
    }
  }
}
