import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../canvas/view/canvas_route.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/board_card_frame.dart';
import '../../../../core/utils/app_snackbar.dart';

class BoardCard extends StatelessWidget {
  final Board board;
  final bool isOwner;
  final Function(String) onDelete;
  final Function(String)? onLeave;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenRequests;
  final VoidCallback? onDuplicate;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final int pendingRequestsCount;

  const BoardCard({
    super.key,
    required this.board,
    required this.isOwner,
    required this.onDelete,
    this.onLeave,
    this.onOpenSettings,
    this.onOpenRequests,
    this.onDuplicate,
    this.onArchive,
    this.onUnarchive,
    this.pendingRequestsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    final String captionText = board.tags.isNotEmpty
        ? "${board.tags.map((t) => '#$t').join(' ')} • Edited ${_timeAgo(board.updatedAt)}"
        : "Edited ${_timeAgo(board.updatedAt)}";

    return BoardCardFrame(
      previewPath: board.previewPath,
      title: board.title,
      caption: captionText,
      pendingRequestsCount: isOwner ? pendingRequestsCount : 0,
      onPendingRequestsTap: isOwner ? onOpenRequests : null,
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(context, buildCanvasRoute(context, boardId: board.id));
      },
      menuButton: PopupMenuButton<String>(
        tooltip: 'Board options',
        icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: tokens.ink),
        onSelected: (value) {
          if (value == 'requests') {
            HapticFeedback.lightImpact();
            onOpenRequests?.call();
          } else if (value == 'copy') {
            HapticFeedback.mediumImpact();
            Clipboard.setData(ClipboardData(text: board.id));
            AppSnackBar.showMessage(
              context,
              'Join Code (Board ID) copied to clipboard!',
            );
          } else if (value == 'duplicate') {
            HapticFeedback.lightImpact();
            onDuplicate?.call();
          } else if (value == 'archive') {
            HapticFeedback.lightImpact();
            onArchive?.call();
          } else if (value == 'unarchive') {
            HapticFeedback.lightImpact();
            onUnarchive?.call();
          } else if (value == 'delete') {
            HapticFeedback.mediumImpact();
            onDelete(board.id);
          } else if (value == 'leave') {
            HapticFeedback.mediumImpact();
            onLeave?.call(board.id);
          } else if (value == 'settings') {
            HapticFeedback.lightImpact();
            onOpenSettings?.call();
          }
        },
        itemBuilder: (context) => [
          if (isOwner && pendingRequestsCount > 0)
            PopupMenuItem(
              value: 'requests',
              child: _menuRow(
                LucideIcons.userCheck,
                'Edit Requests ($pendingRequestsCount)',
                tokens.accent,
              ),
            ),
          PopupMenuItem(
            value: 'settings',
            child: _menuRow(
              LucideIcons.slidersHorizontal,
              (isOwner && pendingRequestsCount > 0)
                  ? 'Settings ($pendingRequestsCount)'
                  : 'Settings',
              tokens.ink,
            ),
          ),
          PopupMenuItem(
            value: 'copy',
            child: _menuRow(LucideIcons.copy, 'Copy Join Code', tokens.ink),
          ),
          if (onDuplicate != null)
            PopupMenuItem(
              value: 'duplicate',
              child: _menuRow(
                LucideIcons.copyPlus,
                isOwner ? 'Duplicate' : 'Make a Copy',
                tokens.ink,
              ),
            ),
          if (isOwner && onArchive != null && !board.isArchived)
            PopupMenuItem(
              value: 'archive',
              child: _menuRow(LucideIcons.archive, 'Archive', tokens.ink),
            ),
          if (isOwner && onUnarchive != null && board.isArchived)
            PopupMenuItem(
              value: 'unarchive',
              child: _menuRow(LucideIcons.archiveRestore, 'Unarchive', tokens.ink),
            ),
          if (isOwner)
            PopupMenuItem(
              value: 'delete',
              child: _menuRow(LucideIcons.trash2, 'Delete', tokens.danger),
            ),
          if (!isOwner && onLeave != null)
            PopupMenuItem(
              value: 'leave',
              child: _menuRow(LucideIcons.logOut, 'Leave Board', tokens.danger),
            ),
        ],
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: InkType.body(color)),
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
