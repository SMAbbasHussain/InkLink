import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/models/board.dart';
import '../../canvas/view/canvas_route.dart';
import '../bloc/workspace_bloc.dart';
import 'workspace_settings_screen.dart';

class WorkspaceDetailScreen extends StatefulWidget {
  final String workspaceId;
  final Stream<List<Board>> ownedBoardsStream;
  final Stream<List<Board>> joinedBoardsStream;

  const WorkspaceDetailScreen({
    required this.workspaceId,
    required this.ownedBoardsStream,
    required this.joinedBoardsStream,
    super.key,
  });

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends State<WorkspaceDetailScreen> {
  final Set<String> _selectedBoardIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<WorkspaceBloc>().add(
      LoadWorkspaceBoardsRequested(widget.workspaceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      builder: (context, state) {
        if (state is! WorkspaceLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allWorkspaces = [
          ...state.ownedWorkspaces,
          ...state.memberWorkspaces,
        ];
        final matching = allWorkspaces
            .where((w) => w.id == widget.workspaceId)
            .toList(growable: false);
        final workspace = matching.isEmpty ? null : matching.first;

        final boards = state.boardsByWorkspace[widget.workspaceId] ?? const [];
        final isOwner = workspace?.currentUserRole == 'owner';

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkspaceSettingsScreen(
                      workspaceId: widget.workspaceId,
                    ),
                  ),
                );
              },
              child: Text(workspace?.name ?? 'Workspace'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Workspace settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkspaceSettingsScreen(
                        workspaceId: widget.workspaceId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: isOwner
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddBoardsSheet(context, boards),
                  icon: const Icon(Icons.add),
                  label: const Text('Add boards'),
                )
              : null,
          body: boards.isEmpty
              ? Center(
                  child: Text(
                    'No boards in this workspace yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: boards.length,
                  itemBuilder: (context, index) {
                    final board = boards[index];
                    return _WorkspaceBoardCard(
                      board: board,
                      isOwner: isOwner,
                      onTap: () {
                        Navigator.push(
                          context,
                          buildCanvasRoute(context, boardId: board.id),
                        );
                      },
                      onRemoveFromWorkspace: isOwner
                          ? () => context.read<WorkspaceBloc>().add(
                              RemoveBoardFromWorkspaceRequested(
                                workspaceId: widget.workspaceId,
                                boardId: board.id,
                              ),
                            )
                          : null,
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _showAddBoardsSheet(BuildContext context, List<Board> existing) {
    final existingIds = existing.map((board) => board.id).toSet();
    _selectedBoardIds.removeWhere(existingIds.contains);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Add boards',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search boards',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: StreamBuilder<List<Board>>(
                      stream: widget.ownedBoardsStream,
                      builder: (context, ownedSnapshot) {
                        return StreamBuilder<List<Board>>(
                          stream: widget.joinedBoardsStream,
                          builder: (context, joinedSnapshot) {
                            final ownedBoards =
                                ownedSnapshot.data ?? const <Board>[];
                            final joinedBoards =
                                joinedSnapshot.data ?? const <Board>[];
                            final allBoards = [...ownedBoards, ...joinedBoards];
                            final filteredBoards = allBoards
                                .where(
                                  (board) =>
                                      !existingIds.contains(board.id) &&
                                      board.title.toLowerCase().contains(
                                        searchController.text.toLowerCase(),
                                      ),
                                )
                                .toList();

                            if (filteredBoards.isEmpty) {
                              return const Center(
                                child: Text('No boards available to add.'),
                              );
                            }

                            return ListView.separated(
                              itemCount: filteredBoards.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final board = filteredBoards[index];
                                final isSelected = _selectedBoardIds.contains(
                                  board.id,
                                );

                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setSheetState(() {
                                      if (value == true) {
                                        _selectedBoardIds.add(board.id);
                                      } else {
                                        _selectedBoardIds.remove(board.id);
                                      }
                                    });
                                  },
                                  title: Text(board.title),
                                  secondary:
                                      board.previewPath != null &&
                                          board.previewPath!.isNotEmpty &&
                                          File(board.previewPath!).existsSync()
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            File(board.previewPath!),
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : const Icon(Icons.dashboard_outlined),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selectedBoardIds.isEmpty
                          ? null
                          : () {
                              for (final boardId
                                  in _selectedBoardIds.toList()) {
                                context.read<WorkspaceBloc>().add(
                                  AddBoardToWorkspaceRequested(
                                    workspaceId: widget.workspaceId,
                                    boardId: boardId,
                                  ),
                                );
                              }
                              _selectedBoardIds.clear();
                              Navigator.pop(context);
                            },
                      child: const Text('Add selected boards'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WorkspaceBoardCard extends StatelessWidget {
  final Board board;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onRemoveFromWorkspace;

  const _WorkspaceBoardCard({
    required this.board,
    required this.isOwner,
    required this.onTap,
    this.onRemoveFromWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child:
                    board.previewPath != null &&
                        board.previewPath!.isNotEmpty &&
                        File(board.previewPath!).existsSync()
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: Image.file(
                          File(board.previewPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              Icons.draw_rounded,
                              size: 36,
                              color: isDark ? Colors.white54 : Colors.black26,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.draw_rounded,
                          size: 36,
                          color: isDark ? Colors.white54 : Colors.black26,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          board.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner && onRemoveFromWorkspace != null)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            if (value == 'remove') {
                              onRemoveFromWorkspace?.call();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                'Remove from workspace',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Edited ${_timeAgo(board.updatedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
