import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_avatar.dart';
import '../../../../ui/widgets/ink_initials.dart';
import '../../../../ui/widgets/ink_text_field.dart';
import '../../bloc/canvas_bloc.dart';
import '../widgets/sliding_tray.dart';

class MembersTray extends StatefulWidget {
  final bool isOpen;

  const MembersTray({super.key, required this.isOpen});

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
          prev.memberSearchQuery != curr.memberSearchQuery,
      builder: (context, state) {
        final filteredMembers = state.filteredBoardMembers;

        return SlidingTray(
          isOpen: widget.isOpen,
          direction: TrayDirection.left,
          title: 'Members',
          width: 320,
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
                      onPressed: null,
                      icon: Icon(LucideIcons.phone, size: 18, color: tokens.inkMuted.withValues(alpha: 0.5)),
                      tooltip: 'Call (Coming soon)',
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: null,
                      icon: Icon(LucideIcons.messageCircle, size: 18, color: tokens.inkMuted.withValues(alpha: 0.5)),
                      tooltip: 'Chat (Coming soon)',
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
                            tokens,
                            'Owner',
                            filteredMembers,
                            Board.roleOwner,
                            tokens.accent,
                          ),
                          ..._buildMemberSection(
                            tokens,
                            'Editor',
                            filteredMembers,
                            Board.roleEditor,
                            tokens.inkSecondary,
                          ),
                          ..._buildMemberSection(
                            tokens,
                            'Viewer',
                            filteredMembers,
                            Board.roleViewer,
                            tokens.inkMuted,
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
    InkTokens tokens,
    String roleLabel,
    List<BoardMember> allMembers,
    String roleValue,
    Color roleColor,
  ) {
    final membersInRole = allMembers.where((m) => m.role == roleValue).toList();
    if (membersInRole.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: roleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: InkSpacing.s8),
            Text(roleLabel, style: InkType.label(tokens.inkMuted)),
            const SizedBox(width: InkSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                membersInRole.length.toString(),
                style: InkType.caption(roleColor),
              ),
            ),
          ],
        ),
      ),
      ...membersInRole.map((member) => _buildMemberTile(tokens, member)),
    ];
  }

  Widget _buildMemberTile(InkTokens tokens, BoardMember member) {
    final displayName = member.displayName ?? member.email ?? 'Unknown';
    final subtitle = member.email ?? 'No email';

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
        ],
      ),
    );
  }
}
