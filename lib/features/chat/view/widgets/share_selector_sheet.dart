import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/models/board.dart';
import '../../../../domain/models/chat/chat_share_payload.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../domain/services/board/board_service.dart';
import '../../../../domain/services/workspace/workspace_service.dart';
import '../../theme/chat_theme.dart';

class ShareSelectorSheet extends StatefulWidget {
  const ShareSelectorSheet({super.key});

  @override
  State<ShareSelectorSheet> createState() => _ShareSelectorSheetState();
}

class _ShareSelectorSheetState extends State<ShareSelectorSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    final responsiveHeight = (MediaQuery.of(context).size.height * 0.65).clamp(380.0, 620.0);
    return Container(
      height: responsiveHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: ChatTheme.space8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: ChatTheme.space12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ChatTheme.space16),
            child: Text(
              'Share with Conversation',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: ChatTheme.space8),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: colors.accent,
            indicatorWeight: 3,
            labelColor: colors.accent,
            unselectedLabelColor: colors.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Boards'),
              Tab(icon: Icon(Icons.workspaces_outlined), text: 'Workspaces'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBoardsList(context),
                _buildWorkspacesList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardsList(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    final boardService = context.read<BoardService>();
    return StreamBuilder<List<Board>>(
      stream: boardService.getOwnedBoards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final boards = snapshot.data ?? [];
        if (boards.isEmpty) {
          return Center(
            child: Text(
              'No boards available to share',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(ChatTheme.space16),
          itemCount: boards.length,
          separatorBuilder: (_, _) => const SizedBox(height: ChatTheme.space8),
          itemBuilder: (context, index) {
            final board = boards[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final payload = ChatSharePayload(
                  type: ChatShareType.board,
                  targetId: board.id,
                  title: board.title.isNotEmpty ? board.title : 'Untitled Board',
                  joinCode: board.id.length > 8 ? board.id.substring(0, 8).toUpperCase() : board.id,
                  thumbnailUrl: board.previewPath,
                  memberCount: board.members.length,
                  description: 'Interactive canvas board',
                );
                Navigator.pop(context, payload);
              },
              child: Container(
                padding: const EdgeInsets.all(ChatTheme.space12),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.palette_outlined, color: colors.accent),
                    ),
                    const SizedBox(width: ChatTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            board.title.isNotEmpty ? board.title : 'Untitled Board',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${board.members.length} members • ${board.visibility}',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.send_rounded, color: colors.accent, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkspacesList(BuildContext context) {
    final colors = ChatTheme.colorsOf(context);
    final workspaceService = context.read<WorkspaceService>();
    return StreamBuilder<List<Workspace>>(
      stream: workspaceService.getOwnedWorkspaces(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final workspaces = snapshot.data ?? [];
        if (workspaces.isEmpty) {
          return Center(
            child: Text(
              'No workspaces available to share',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(ChatTheme.space16),
          itemCount: workspaces.length,
          separatorBuilder: (_, _) => const SizedBox(height: ChatTheme.space8),
          itemBuilder: (context, index) {
            final ws = workspaces[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final payload = ChatSharePayload(
                  type: ChatShareType.workspace,
                  targetId: ws.id,
                  title: ws.name,
                  joinCode: ws.id.length > 8 ? ws.id.substring(0, 8).toUpperCase() : ws.id,
                  memberCount: ws.memberCount,
                  description: ws.description,
                );
                Navigator.pop(context, payload);
              },
              child: Container(
                padding: const EdgeInsets.all(ChatTheme.space12),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accentAlt.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.workspaces_outlined, color: colors.accentAlt),
                    ),
                    const SizedBox(width: ChatTheme.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ws.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ws.memberCount} members',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.send_rounded, color: colors.accentAlt, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
