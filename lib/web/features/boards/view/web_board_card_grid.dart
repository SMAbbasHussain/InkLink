import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/board_card_frame.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/web_board_opener.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_boards_cubit.dart';
import 'web_board_crud_dialogs.dart';
import 'web_board_settings_dialogs.dart';

/// Responsive grid of Desk-styled board cards with per-card action menus.
class WebBoardCardGrid extends StatelessWidget {
  final List<Board> boards;
  final String Function(Board board) captionFor;

  /// When true (Discover), non-members see a "Join board" menu action.
  final bool showJoin;

  const WebBoardCardGrid({
    super.key,
    required this.boards,
    required this.captionFor,
    this.showJoin = false,
  });

  @override
  Widget build(BuildContext context) {
    final opener = context.read<WebBoardOpener>();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = InkSpacing.s12;
        final columns = (constraints.maxWidth / 270).floor().clamp(1, 5);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final board in boards)
              SizedBox(
                key: ValueKey(board.id),
                width: width,
                child: Semantics(
                  container: true,
                  button: true,
                  label: 'Board ${board.title}. ${captionFor(board)}',
                  child: BoardCardFrame(
                    previewPath: null,
                    title: board.title,
                    caption: captionFor(board),
                    onTap: () => opener.open(context, board),
                    menuButton: _BoardMenu(board: board, showJoin: showJoin),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BoardMenu extends StatelessWidget {
  final Board board;
  final bool showJoin;

  const _BoardMenu({required this.board, this.showJoin = false});

  bool _isOwner(BuildContext context) =>
      context.read<WebBoardsCubit>().currentUserId == board.ownerId;

  bool _canJoin(BuildContext context) =>
      showJoin &&
      !board.members.contains(context.read<WebBoardsCubit>().currentUserId);

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String doneMessage,
  ) async {
    try {
      await action();
      if (context.mounted) showWebMessage(context, doneMessage);
    } catch (e) {
      if (context.mounted) {
        showWebMessage(context, webErrorText(e), isError: true);
      }
    }
  }

  Future<void> _onSelected(BuildContext context, String value) async {
    final boards = context.read<WebBoardsCubit>();
    if (value == 'open') {
      context.read<WebBoardOpener>().open(context, board);
      return;
    }
    if (value == 'copy') {
      await Clipboard.setData(ClipboardData(text: board.id));
      if (context.mounted) {
        showWebMessage(context, 'Join Code (Board ID) copied to clipboard!');
      }
      return;
    }
    if (value == 'rename') return showRenameBoardDialog(context, board);
    if (value == 'tags') return showBoardTagsDialog(context, board);
    if (value == 'settings') return showBoardSettingsDialog(context, board);
    if (value == 'join') {
      return _run(
        context,
        () => boards.joinBoard(board.id),
        'You joined "${board.title}".',
      );
    }
    if (value == 'duplicate') {
      return _run(
        context,
        () => boards.duplicateBoard(board.id),
        'Board copied.',
      );
    }
    if (value == 'archive' || value == 'unarchive') {
      final archived = value == 'archive';
      return _run(
        context,
        () => boards.setBoardArchived(board.id, archived: archived),
        archived ? 'Board archived.' : 'Board restored.',
      );
    }
    if (value == 'pause' || value == 'resume') {
      final paused = value == 'pause';
      return _run(
        context,
        () => boards.setBoardPaused(board.id, paused: paused),
        paused
            ? 'Board paused. Editing is disabled until you resume it.'
            : 'Board resumed.',
      );
    }
    if (value == 'delete') {
      final confirmed = await showInkConfirmDialog(
        context,
        title: 'Delete "${board.title}"?',
        message:
            'The board and everything on it are removed for every member. '
            'This cannot be undone.',
      );
      if (confirmed && context.mounted) {
        await _run(
          context,
          () => boards.deleteBoard(board.id),
          'Board deleted.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final owner = _isOwner(context);
    final canJoin = _canJoin(context);
    return PopupMenuButton<String>(
      tooltip: 'Board options',
      icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: tokens.ink),
      onSelected: (value) => _onSelected(context, value),
      itemBuilder: (_) => [
        if (canJoin)
          PopupMenuItem(
            value: 'join',
            child: _row(LucideIcons.doorOpen, 'Join board', tokens),
          ),
        PopupMenuItem(
          value: 'open',
          child: _row(LucideIcons.squareArrowOutUpRight, 'Open board', tokens),
        ),
        if (owner) ...[
          PopupMenuItem(
            value: 'rename',
            child: _row(LucideIcons.pencil, 'Rename', tokens),
          ),
          PopupMenuItem(
            value: 'tags',
            child: _row(LucideIcons.tag, 'Tags', tokens),
          ),
          PopupMenuItem(
            value: 'settings',
            child: _row(LucideIcons.settings, 'Board settings', tokens),
          ),
        ],
        PopupMenuItem(
          value: 'duplicate',
          child: _row(LucideIcons.copyPlus, 'Duplicate', tokens),
        ),
        PopupMenuItem(
          value: 'copy',
          child: _row(LucideIcons.copy, 'Copy Join Code', tokens),
        ),
        if (owner && !board.isArchived) ...[
          PopupMenuItem(
            value: board.isPaused ? 'resume' : 'pause',
            child: _row(
              board.isPaused ? LucideIcons.play : LucideIcons.pause,
              board.isPaused ? 'Resume editing' : 'Pause editing',
              tokens,
            ),
          ),
          PopupMenuItem(
            value: 'archive',
            child: _row(LucideIcons.archive, 'Archive', tokens),
          ),
        ],
        if (owner && board.isArchived)
          PopupMenuItem(
            value: 'unarchive',
            child: _row(LucideIcons.archiveRestore, 'Unarchive', tokens),
          ),
        if (owner)
          PopupMenuItem(
            value: 'delete',
            child: _row(
              LucideIcons.trash2,
              'Delete board',
              tokens,
              danger: true,
            ),
          ),
      ],
    );
  }

  Widget _row(
    IconData icon,
    String label,
    InkTokens tokens, {
    bool danger = false,
  }) => Row(
    children: [
      Icon(icon, size: 18, color: danger ? tokens.danger : tokens.ink),
      const SizedBox(width: 10),
      Text(label, style: InkType.body(danger ? tokens.danger : tokens.ink)),
    ],
  );
}
