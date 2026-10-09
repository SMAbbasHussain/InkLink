import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/models/board.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
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
    final tokens = context.ink;

    return BlocBuilder<WorkspaceBloc, WorkspaceState>(
      builder: (context, state) {
        if (state is! WorkspaceLoaded) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: tokens.accent)),
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
              child: Text(workspace?.name ?? 'Workspace', style: InkType.title(tokens.ink)),
            ),
            actions: [
              IconButton(
                icon: Icon(LucideIcons.slidersHorizontal, color: tokens.ink),
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
              ? _WorkspaceFab(onPressed: () => _showAddBoardsSheet(context, boards))
              : null,
          body: boards.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.layoutGrid,
                  text: 'No boards in this workspace yet.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(InkSpacing.s16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
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
    final tokens = context.ink;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                InkSpacing.s16,
                InkSpacing.s8,
                InkSpacing.s16,
                MediaQuery.of(context).viewInsets.bottom + InkSpacing.s24,
              ),
              child: GlassPanel(
                radius: InkRadii.bottomSheet,
                padding: const EdgeInsets.all(InkSpacing.s20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: InkSpacing.s16),
                        decoration: BoxDecoration(
                          color: tokens.inkMuted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text('Add boards', style: InkType.title(tokens.ink)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(LucideIcons.x, color: tokens.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    InkButton.secondary(
                      label: 'Create new board in workspace',
                      icon: const Icon(LucideIcons.plus),
                      onPressed: () {
                        _showCreateBoardDialog(context);
                      },
                    ),
                    const SizedBox(height: InkSpacing.s16),
                    Divider(color: tokens.glassStroke, height: 1),
                    const SizedBox(height: InkSpacing.s16),
                    Text('Or add existing boards:', style: InkType.body(tokens.inkSecondary)),
                    const SizedBox(height: InkSpacing.s12),
                    InkTextField(
                      controller: searchController,
                      hintText: 'Search boards',
                      leadingIcon: LucideIcons.search,
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
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
                                return Center(
                                  child: Text(
                                    'No boards available to add.',
                                    style: InkType.body(tokens.inkMuted),
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: filteredBoards.length,
                                separatorBuilder: (_, _) =>
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
                                    title: Text(board.title, style: InkType.body(tokens.ink)),
                                    secondary:
                                        board.previewPath != null &&
                                            board.previewPath!.isNotEmpty &&
                                            File(board.previewPath!).existsSync()
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(
                                              File(board.previewPath!),
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(LucideIcons.layoutGrid, color: tokens.inkMuted),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    InkButton.primary(
                      label: 'Add selected boards',
                      onPressed: _selectedBoardIds.isEmpty
                          ? null
                          : () {
                              for (final boardId in _selectedBoardIds.toList()) {
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => InkDialog(
        title: 'Create New Board',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkTextField(controller: titleController, labelText: 'Board title'),
            const SizedBox(height: InkSpacing.s12),
            InkTextField(
              controller: descriptionController,
              labelText: 'Description (optional)',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          InkButton.secondary(
            label: 'Cancel',
            expand: false,
            compact: true,
            onPressed: () => Navigator.pop(context),
          ),
          InkButton.primary(
            label: 'Create',
            expand: false,
            compact: true,
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Board title is required')),
                );
                return;
              }

              context.read<WorkspaceBloc>().add(
                CreateBoardInWorkspaceRequested(
                  workspaceId: widget.workspaceId,
                  title: title,
                  description: descriptionController.text.trim(),
                ),
              );
              Navigator.pop(context);
              Navigator.pop(context); // Close the bottom sheet
            },
          ),
        ],
      ),
    );
  }
}

class _WorkspaceFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _WorkspaceFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Tooltip(
      message: 'Add boards',
      child: Material(
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: tokens.accentGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: tokens.glassShadow,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: const Icon(LucideIcons.plus, color: Colors.white),
          ),
        ),
      ),
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
    final tokens = context.ink;

    return GestureDetector(
      onTap: onTap,
      child: PaperCard(
        tiltId: board.id,
        showTape: true,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: tokens.field,
                child: board.previewPath != null &&
                        board.previewPath!.isNotEmpty &&
                        File(board.previewPath!).existsSync()
                    ? Image.file(
                        File(board.previewPath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(LucideIcons.penLine, size: 36, color: tokens.inkMuted),
                        ),
                      )
                    : Center(
                        child: Icon(LucideIcons.penLine, size: 36, color: tokens.inkMuted),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          board.title,
                          style: InkType.cardTitle(tokens.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Edited ${_timeAgo(board.updatedAt)}',
                          style: InkType.caption(tokens.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner && onRemoveFromWorkspace != null)
                    PopupMenuButton<String>(
                      icon: Icon(LucideIcons.ellipsis, size: 20, color: tokens.inkMuted),
                      onSelected: (value) {
                        if (value == 'remove') {
                          onRemoveFromWorkspace?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(LucideIcons.folderMinus, size: 18, color: tokens.danger),
                              const SizedBox(width: 10),
                              Text('Remove from workspace', style: TextStyle(color: tokens.danger)),
                            ],
                          ),
                        ),
                      ],
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
