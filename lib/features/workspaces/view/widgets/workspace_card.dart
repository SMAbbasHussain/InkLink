import 'dart:io';

import 'package:flutter/material.dart';

import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/workspace.dart';

class WorkspaceCard extends StatelessWidget {
  final Workspace workspace;
  final List<Board> previewBoards;
  final VoidCallback onTap;
  final VoidCallback onOptionsPressed;

  const WorkspaceCard({
    required this.workspace,
    required this.previewBoards,
    required this.onTap,
    required this.onOptionsPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final boards = previewBoards.take(4).toList();
    while (boards.length < 4) {
      boards.add(
        Board(
          id: '',
          title: '',
          ownerId: '',
          members: const [],
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _BoardPreviewTile(board: boards[0])),
                          const SizedBox(width: 6),
                          Expanded(child: _BoardPreviewTile(board: boards[1])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _BoardPreviewTile(board: boards[2])),
                          const SizedBox(width: 6),
                          Expanded(child: _BoardPreviewTile(board: boards[3])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workspace.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onOptionsPressed,
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Workspace actions',
                  ),
                ],
              ),
              if (workspace.description.isNotEmpty)
                Text(
                  workspace.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardPreviewTile extends StatelessWidget {
  final Board board;

  const _BoardPreviewTile({required this.board});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final tileColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.04);

    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: board.id.isEmpty
          ? Icon(
              Icons.dashboard_outlined,
              color: isDark ? Colors.white38 : Colors.black26,
              size: 20,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  board.previewPath != null &&
                      board.previewPath!.isNotEmpty &&
                      File(board.previewPath!).existsSync()
                  ? Image.file(
                      File(board.previewPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => _FallbackPreview(board: board),
                    )
                  : _FallbackPreview(board: board),
            ),
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  final Board board;

  const _FallbackPreview({required this.board});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Text(
        board.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
