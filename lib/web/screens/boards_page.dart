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
import '../../ui/widgets/ink_segmented.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
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
  late final _repo = context.read<WebCompanionRepository>();
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
          trailing: SizedBox(
            width: 300,
            child: WebSearchField(
              controller: _search,
              hintText: 'Search boards...',
              onChanged: (_) => setState(() {}),
            ),
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
          emptySubtitle: 'Create a board in the InkLink mobile app.',
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

  const WebBoardCardGrid({
    super.key,
    required this.boards,
    required this.captionFor,
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
                  button: true,
                  label: board.title,
                  child: BoardCardFrame(
                    // The web has no local preview images.
                    previewPath: null,
                    title: board.title,
                    caption: captionFor(board),
                    onTap: () => opener.open(context, board),
                    menuButton: _BoardMenu(board: board),
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
  const _BoardMenu({required this.board});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return PopupMenuButton<String>(
      tooltip: 'Board options',
      icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: tokens.ink),
      onSelected: (value) {
        if (value == 'open') {
          context.read<WebBoardOpener>().open(context, board);
        } else if (value == 'copy') {
          Clipboard.setData(ClipboardData(text: board.id));
          showWebMessage(context, 'Join Code (Board ID) copied to clipboard!');
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'open',
          child: _row(LucideIcons.squareArrowOutUpRight, 'Open board', tokens),
        ),
        PopupMenuItem(
          value: 'copy',
          child: _row(LucideIcons.copy, 'Copy Join Code', tokens),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, InkTokens tokens) => Row(
    children: [
      Icon(icon, size: 18, color: tokens.ink),
      const SizedBox(width: 10),
      Text(label, style: InkType.body(tokens.ink)),
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
  late final _repo = context.read<WebCompanionRepository>();
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
    final tokens = context.ink;
    final tags = topTags(boards.map((b) => b.tags));
    final query = _search.text.trim().toLowerCase();
    final visible = boards.where((b) {
      if (_tag != null && !b.tags.contains(_tag)) return false;
      if (query.isEmpty) return true;
      return b.title.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();

    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: tokens.accent,
      backgroundColor: tokens.paper,
      labelStyle: InkType.caption(
        selected ? Colors.white : tokens.inkSecondary,
      ),
      side: BorderSide(color: selected ? tokens.accent : tokens.glassStroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );

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
