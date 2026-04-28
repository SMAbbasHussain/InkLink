import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/board.dart';
import '../../bloc/canvas_bloc.dart';
import '../widgets/sliding_tray.dart';

class MembersTray extends StatefulWidget {
  final bool isOpen;
  final List<BoardMember> members;

  const MembersTray({super.key, required this.isOpen, required this.members});

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
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close search',
                  splashRadius: 18,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        // Call feature - placeholder for now
                      },
                      icon: const Icon(Icons.call, size: 18),
                      tooltip: 'Call (Coming soon)',
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: () {
                        // Chat feature - placeholder for now
                      },
                      icon: const Icon(Icons.chat, size: 18),
                      tooltip: 'Chat (Coming soon)',
                      splashRadius: 18,
                    ),
                    IconButton(
                      onPressed: _enterSearchMode,
                      icon: const Icon(Icons.search, size: 18),
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
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search members...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _exitSearchMode,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isSearchMode
                                  ? 'No members found'
                                  : 'No members yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ..._buildMemberSection(
                            'Owner',
                            filteredMembers,
                            Board.roleOwner,
                            Colors.orange,
                          ),
                          ..._buildMemberSection(
                            'Editor',
                            filteredMembers,
                            Board.roleEditor,
                            Colors.blue,
                          ),
                          ..._buildMemberSection(
                            'Viewer',
                            filteredMembers,
                            Board.roleViewer,
                            Colors.green,
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
            const SizedBox(width: 8),
            Text(
              roleLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                membersInRole.length.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                ),
              ),
            ),
          ],
        ),
      ),
      ...membersInRole.map((member) => _buildMemberTile(member)),
    ];
  }

  Widget _buildMemberTile(BoardMember member) {
    final displayName = member.displayName ?? member.email ?? 'Unknown';
    final subtitle = member.email ?? 'No email';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundImage:
              member.photoUrl != null && member.photoUrl!.isNotEmpty
              ? NetworkImage(member.photoUrl!)
              : null,
          child: member.photoUrl == null || member.photoUrl!.isEmpty
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 12),
                )
              : null,
        ),
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
