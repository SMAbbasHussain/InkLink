import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_colors.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/board_card_frame.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/ink_segmented.dart';
import '../domain/web_companion_service.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
import 'board_dialogs.dart';
import 'web_shell_nav.dart';

enum _BoardTab { mine, joined, archived }

/// The user's boards (live) as a desktop page in the mobile app's style:
/// title with search, a note when invites are waiting, the My Boards /
/// Joined / Archived switch and the board cards.
class WebBoardsPage extends StatefulWidget {
  const WebBoardsPage({super.key});

  @override
  State<WebBoardsPage> createState() => _WebBoardsPageState();
}

class _WebBoardsPageState extends State<WebBoardsPage> {
  late final _repo = context.read<WebCompanionService>();
  late final Stream<List<Board>> _boards = _repo.watchMyBoards();
  late final _boardInvites = _repo.watchBoardInvites();
  final _search = TextEditingController();
  _BoardTab _tab = _BoardTab.mine;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Board> _apply(List<Board> boards, String? uid) {
    final query = _search.text.trim().toLowerCase();
    return boards.where((b) {
      final inTab = switch (_tab) {
        _BoardTab.mine => !b.isArchived && b.ownerId == uid,
        _BoardTab.joined => !b.isArchived && b.ownerId != uid,
        _BoardTab.archived => b.isArchived,
      };
      if (!inTab) return false;
      if (query.isEmpty) return true;
      return b.title.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query)) ||
          b.id.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _repo.currentUser?.uid;
    final nav = WebShellNav.maybeOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        WebPageHeader(
          title: 'Ready to bring your ideas to life?',
          subtitle: 'Your boards and the boards you joined.',
          trailing: Wrap(
            spacing: InkSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: WebSearchField(
                  controller: _search,
                  hintText: 'Search boards...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              InkButton.secondary(
                label: 'Join',
                compact: true,
                expand: false,
                icon: Icon(
                  LucideIcons.doorOpen,
                  size: 16,
                  color: context.ink.ink,
                ),
                onPressed: () => showJoinBoardDialog(context),
              ),
              InkButton.primary(
                label: 'New board',
                compact: true,
                expand: false,
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => showCreateBoardDialog(context),
              ),
            ],
          ),
        ),
        StreamBuilder(
          stream: _boardInvites,
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: InkSpacing.s20),
              child: _InviteNotice(
                count: count,
                onReview: nav == null
                    ? null
                    : () => nav.goTo(WebSection.invites),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: InkSegmented(
              labels: const ['My Boards', 'Joined', 'Archived'],
              selectedIndex: _tab.index,
              onChanged: (i) => setState(() => _tab = _BoardTab.values[i]),
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.s20),
        WebStreamList<Board>(
          stream: _boards,
          compactEmpty: false,
          emptyIcon: LucideIcons.layoutGrid,
          emptyText: 'No boards created yet.',
          emptySubtitle: 'Create your first board to get started.',
          builder: (context, boards) {
            final visible = _apply(boards, uid);
            if (visible.isEmpty) {
              final query = _search.text.trim();
              if (query.isNotEmpty) {
                return WebEmptyHint(
                  icon: LucideIcons.searchX,
                  text: 'No boards match "$query"',
                );
              }
              return WebEmptyHint(
                icon: _tab == _BoardTab.archived
                    ? LucideIcons.archive
                    : LucideIcons.layoutGrid,
                text: switch (_tab) {
                  _BoardTab.mine => 'No boards created yet.',
                  _BoardTab.joined => 'No boards joined yet.',
                  _BoardTab.archived => 'No archived boards.',
                },
                subtitle: _tab == _BoardTab.mine
                    ? 'Use New board above to start one.'
                    : null,
              );
            }
            return WebBoardCardGrid(
              boards: visible,
              captionFor: (b) => b.tags.isNotEmpty
                  ? '${b.tags.map((t) => '#$t').join(' ')} • '
                        'Edited ${timeAgo(b.updatedAt)}'
                  : 'Edited ${timeAgo(b.updatedAt)}',
            );
          },
        ),
      ],
    );
  }
}

/// A slim butter-yellow note (the mobile sticky-note colour) when board
/// invites are waiting.
class _InviteNotice extends StatelessWidget {
  final int count;
  final VoidCallback? onReview;

  const _InviteNotice({required this.count, this.onReview});

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.stickyInkFor(InkColors.stickyButter);
    return Material(
      color: InkColors.stickyButter,
      borderRadius: BorderRadius.circular(InkRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(InkRadii.card),
        onTap: onReview,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s16,
            vertical: InkSpacing.s12,
          ),
          child: Row(
            children: [
              Icon(LucideIcons.mailOpen, size: 18, color: ink),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Text(
                  count == 1
                      ? "You've been invited to a board!"
                      : 'You have $count board invites waiting!',
                  style: InkType.bodyStrong(ink),
                ),
              ),
              Text('Review', style: InkType.bodyStrong(ink)),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 16, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boards as the phone's cards (frame with a glass label), as many per row
/// as fit. Clicking a card opens the board.
class WebBoardCardGrid extends StatelessWidget {
  final List<Board> boards;
  final String Function(Board board) captionFor;

  /// Public discovery: cards offer "Join board" when the reader is not a
  /// member yet.
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
                  // A named node per card: the grid reads as a list of boards
                  // instead of unnamed groups, and the menu button keeps its
                  // own "Board options" name.
                  container: true,
                  button: true,
                  label: 'Board ${board.title}. ${captionFor(board)}',
                  child: BoardCardFrame(
                    // The web has no local preview images.
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

/// The card's options menu: open, rename, tags, settings, copy, archive,
/// pause and delete for the owner; join for public boards the reader is not
/// in. Every action goes through the same repository the phone uses.
class _BoardMenu extends StatelessWidget {
  final Board board;
  final bool showJoin;

  const _BoardMenu({required this.board, this.showJoin = false});

  bool _isOwner(BuildContext context) =>
      context.read<WebCompanionService>().currentUser?.uid == board.ownerId;

  bool _canJoin(BuildContext context) =>
      showJoin &&
      !board.members.contains(
        context.read<WebCompanionService>().currentUser?.uid,
      );

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
    final repo = context.read<WebCompanionService>();
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
        () => repo.joinBoard(board.id),
        'You joined "${board.title}".',
      );
    }
    if (value == 'duplicate') {
      return _run(
        context,
        () => repo.duplicateBoard(board.id),
        'Board copied.',
      );
    }
    if (value == 'archive' || value == 'unarchive') {
      final archived = value == 'archive';
      return _run(
        context,
        () => repo.setBoardArchived(board.id, archived: archived),
        archived ? 'Board archived.' : 'Board restored.',
      );
    }
    if (value == 'pause' || value == 'resume') {
      final paused = value == 'pause';
      return _run(
        context,
        () => repo.setBoardPaused(board.id, paused: paused),
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
        await _run(context, () => repo.deleteBoard(board.id), 'Board deleted.');
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

/// Public boards, like the phone's "Explore Public Boards": search, tag
/// chips and board cards.
class WebDiscoverPage extends StatefulWidget {
  const WebDiscoverPage({super.key});

  @override
  State<WebDiscoverPage> createState() => _WebDiscoverPageState();
}

class _WebDiscoverPageState extends State<WebDiscoverPage> {
  late final _repo = context.read<WebCompanionService>();
  late Future<List<Board>> _future = _repo.loadPublicBoards();
  final _search = TextEditingController();
  String? _tag;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return FutureBuilder<List<Board>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            InkSpacing.s24,
            InkSpacing.s24,
            InkSpacing.s24,
            webPageBottomPadding(context),
          ),
          children: [
            WebPageHeader(
              title: 'Explore Public Boards',
              subtitle: 'Boards shared with the InkLink community.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 300,
                    child: WebSearchField(
                      controller: _search,
                      hintText: 'Search by title, topic or tag...',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: InkSpacing.s8),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: Icon(
                      LucideIcons.rotateCw,
                      color: tokens.inkSecondary,
                    ),
                    onPressed: loading
                        ? null
                        : () => setState(
                            () => _future = _repo.loadPublicBoards(),
                          ),
                  ),
                ],
              ),
            ),
            if (snapshot.hasError)
              WebErrorBox(message: webErrorText(snapshot.error!))
            else if (!snapshot.hasData)
              const WebLoading()
            else
              _buildResults(snapshot.data!),
          ],
        );
      },
    );
  }

  Widget _buildResults(List<Board> boards) {
    final tags = topTags(boards.map((b) => b.tags));
    final query = _search.text.trim().toLowerCase();
    final visible = boards.where((b) {
      if (_tag != null && !b.tags.contains(_tag)) return false;
      if (query.isEmpty) return true;
      return b.title.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    Widget chip(String label, bool selected, VoidCallback onTap) =>
        WebChoiceChip(label: label, selected: selected, onSelected: onTap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: InkSpacing.s8,
          runSpacing: InkSpacing.s8,
          children: [
            chip('All', _tag == null, () => setState(() => _tag = null)),
            for (final t in tags)
              chip(
                '#$t',
                _tag == t,
                () => setState(() => _tag = _tag == t ? null : t),
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s20),
        if (boards.isEmpty)
          const WebEmptyHint(
            icon: LucideIcons.compass,
            text: 'No public boards yet.',
          )
        else if (visible.isEmpty)
          const WebEmptyHint(
            icon: LucideIcons.searchX,
            text: 'No public boards match this search or tag.',
          )
        else
          WebBoardCardGrid(
            boards: visible,
            showJoin: true,
            captionFor: (b) => b.tags.isNotEmpty
                ? b.tags.take(3).map((t) => '#$t').join(' ')
                : (b.membersCount == 1
                      ? '1 member'
                      : '${b.membersCount} members'),
          ),
      ],
    );
  }
}
