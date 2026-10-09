import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../canvas/view/canvas_route.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/desk_background.dart';
import '../../../../ui/widgets/paper_card.dart';

class BoardCard extends StatelessWidget {
  final Board board;
  final bool isOwner;
  final Function(String) onDelete;
  final VoidCallback? onOpenSettings;

  const BoardCard({
    super.key,
    required this.board,
    required this.isOwner,
    required this.onDelete,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, buildCanvasRoute(context, boardId: board.id));
      },
      child: PaperCard(
        tiltId: board.id,
        showTape: true,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child:
                    board.previewPath != null && board.previewPath!.isNotEmpty
                    ? DeskBackground(
                        child: Image.file(
                          File(board.previewPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              LucideIcons.penLine,
                              size: 36,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ),
                      )
                    : DeskBackground(
                        child: Center(
                          child: Icon(
                            LucideIcons.penLine,
                            size: 36,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
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
                          "Edited ${_timeAgo(board.updatedAt)}",
                          style: InkType.caption(tokens.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(LucideIcons.ellipsis, size: 20, color: tokens.inkMuted),
                    onSelected: (value) {
                      if (value == 'copy') {
                        Clipboard.setData(ClipboardData(text: board.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Join Code (Board ID) copied to clipboard!',
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        onDelete(board.id);
                      } else if (value == 'settings') {
                        onOpenSettings?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'settings',
                        child: _menuRow(LucideIcons.slidersHorizontal, 'Settings', tokens.ink),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: _menuRow(LucideIcons.copy, 'Copy Join Code', tokens.ink),
                      ),
                      if (isOwner)
                        PopupMenuItem(
                          value: 'delete',
                          child: _menuRow(LucideIcons.trash2, 'Delete', tokens.danger),
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

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  String _timeAgo(DateTime d) {
    Duration diff = DateTime.now().difference(d);
    if (diff.inDays > 365) return "${(diff.inDays / 365).floor()}y ago";
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo ago";
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}
