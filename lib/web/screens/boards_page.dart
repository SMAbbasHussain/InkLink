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
import '../../ui/widgets/command_bar.dart';
import '../../ui/widgets/ink_segmented.dart';
import '../../ui/widgets/sticky_note.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
import 'web_shell_nav.dart';

/// Room under the page content for the floating search bar and nav bar.
const double _floatingBarsRoom = 180;

enum _BoardTab { mine, joined, archived }

/// The user's boards (live), laid out like the phone's home screen: the
/// greeting, a sticky note for waiting invites, the My Boards / Joined /
/// Archived switch, board cards and the floating search bar.
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
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.s16,
            InkSpacing.s24,
            InkSpacing.s16,
            _floatingBarsRoom,
          ),
          children: [
            StreamBuilder(
              stream: _boardInvites,
              builder: (context, snapshot) => _GreetingRow(
                inviteCount: snapshot.data?.length ?? 0,
                onReviewInvites: nav == null
                    ? null
                    : () => nav.goTo(WebSection.invites),
              ),
            ),
            const SizedBox(height: InkSpacing.s24),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: InkSegmented(
                  labels: const ['My Boards', 'Joined', 'Archived'],
                  selectedIndex: _tab.index,
                  onChanged: (i) => setState(() => _tab = _BoardTab.values[i]),
                ),
              ),
            ),
            const SizedBox(height: InkSpacing.s24),
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
        ),
        // The phone's floating search bar, above the nav bar.
        Positioned(
          left: InkSpacing.s12,
          right: InkSpacing.s12,
          bottom: 92,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CommandBar(
                controller: _search,
                hintText: 'Search boards...',
                onChanged: (_) => setState(() {}),
                onClear: () => setState(() {}),
                trailing: [
                  if (nav != null)
                    CommandBarAction(
                      icon: LucideIcons.compass,
                      tooltip: 'Explore Public Boards',
                      onPressed: () => nav.goTo(WebSection.discover),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Ready to bring your ideas to life?" and, when invites are waiting, the
/// tilted sticky note that opens them (as on the phone).
class _GreetingRow extends StatelessWidget {
  final int inviteCount;
  final VoidCallback? onReviewInvites;

  const _GreetingRow({required this.inviteCount, this.onReviewInvites});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final greeting = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Semantics(
        header: true,
        child: Text(
          'Ready to bring your ideas to life?',
          style: InkType.display(tokens.ink),
        ),
      ),
    );
    if (inviteCount == 0) return greeting;

    final ink = InkColors.stickyInkFor(InkColors.stickyButter);
    return Wrap(
      spacing: InkSpacing.s24,
      runSpacing: InkSpacing.s16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        greeting,
        Padding(
          padding: const EdgeInsets.all(InkSpacing.s8),
          child: Transform.rotate(
            angle: 5 * 3.1415926535 / 180,
            child: SizedBox(
              width: 160,
              child: StickyNote(
                color: InkColors.stickyButter,
                showTape: true,
                padding: const EdgeInsets.all(InkSpacing.s12),
                onTap: onReviewInvites,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      inviteCount == 1
                          ? "You've been invited to a board!"
                          : 'You have $inviteCount board invites waiting!',
                      style: InkType.label(ink),
                    ),
                    const SizedBox(height: InkSpacing.s8),
                    Row(
                      children: [
                        Text('Review', style: InkType.bodyStrong(ink)),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 14, color: ink),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.s16,
            InkSpacing.s24,
            InkSpacing.s16,
            _floatingBarsRoom - 70,
          ),
          children: [
            WebPageHeader(
              title: 'Explore Public Boards',
              subtitle: 'Boards shared with the InkLink community.',
              trailing: IconButton(
                tooltip: 'Refresh',
                icon: Icon(LucideIcons.rotateCw, color: tokens.inkSecondary),
                onPressed: loading
                    ? null
                    : () => setState(() => _future = _repo.loadPublicBoards()),
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
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: InkType.body(tokens.ink),
              decoration: InputDecoration(
                hintText: 'Search by title, topic, or keyword...',
                hintStyle: InkType.body(tokens.inkMuted),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 20,
                  color: tokens.inkSecondary,
                ),
                filled: true,
                fillColor: tokens.isDark ? tokens.paper : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(InkRadii.input),
                  borderSide: BorderSide(color: tokens.glassStroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(InkRadii.input),
                  borderSide: BorderSide(color: tokens.glassStroke),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.s12),
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
