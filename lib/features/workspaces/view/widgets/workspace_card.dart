import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/workspace.dart';
import 'package:inklink/ui/theme/ink_colors.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:inklink/ui/theme/ink_tokens.dart';
import 'package:inklink/ui/theme/ink_type.dart';
import 'package:inklink/ui/widgets/ink_tilt.dart';
import 'package:inklink/ui/widgets/paper_card.dart';

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
    final tokens = context.ink;
    final boards = previewBoards.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s20),
      child: SizedBox(
        height: 190,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Two peeking sheets behind the main card.
            Positioned(
              top: 6,
              left: 10,
              right: 2,
              bottom: -2,
              child: Transform.rotate(
                angle: inkDeterministicTilt('${workspace.id}-back2', maxDegrees: 2.2),
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    borderRadius: BorderRadius.circular(InkRadii.paperCard),
                    boxShadow: tokens.paperShadow,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 3,
              left: 5,
              right: -2,
              bottom: 1,
              child: Transform.rotate(
                angle: inkDeterministicTilt('${workspace.id}-back1', maxDegrees: 1.4),
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    borderRadius: BorderRadius.circular(InkRadii.paperCard),
                    boxShadow: tokens.paperShadow,
                  ),
                ),
              ),
            ),
            PaperCard(
              padding: const EdgeInsets.all(InkSpacing.s12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(InkRadii.paperCard),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 88,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: _BoardPreviewTile(
                                board: i < boards.length ? boards[i] : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: InkSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workspace.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: InkType.cardTitle(tokens.ink),
                          ),
                        ),
                        IconButton(
                          onPressed: onOptionsPressed,
                          icon: Icon(LucideIcons.ellipsis, color: tokens.inkMuted),
                          tooltip: 'Workspace actions',
                        ),
                      ],
                    ),
                    if (workspace.description.isNotEmpty)
                      Text(
                        workspace.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: InkType.caption(tokens.inkMuted),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardPreviewTile extends StatelessWidget {
  final Board? board;

  const _BoardPreviewTile({required this.board});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final hasPreview = board != null &&
        board!.previewPath != null &&
        board!.previewPath!.isNotEmpty &&
        File(board!.previewPath!).existsSync();
    final placeholderColor =
        board != null ? InkColors.stickyForId(board!.id) : tokens.field;

    return Container(
      decoration: BoxDecoration(
        color: hasPreview ? tokens.field : placeholderColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: board == null
          ? Icon(LucideIcons.layoutGrid, color: tokens.inkMuted, size: 20)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  board!.previewPath != null &&
                      board!.previewPath!.isNotEmpty &&
                      File(board!.previewPath!).existsSync()
                  ? Image.file(
                      File(board!.previewPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, _, _) => _FallbackPreview(board: board!),
                    )
                  : _FallbackPreview(board: board!),
            ),
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  final Board board;

  const _FallbackPreview({required this.board});

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.stickyInkFor(InkColors.stickyForId(board.id));
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Text(
        board.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: InkType.caption(ink),
      ),
    );
  }
}
