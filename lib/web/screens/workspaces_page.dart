import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../domain/models/workspace.dart';
import '../../ui/theme/ink_colors.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_tilt.dart';
import '../../ui/widgets/paper_card.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
import 'boards_page.dart';
import 'web_shell_nav.dart';

/// The user's workspaces, like the phone's Workspaces tab: stacked paper
/// cards with the first boards on top. Clicking one shows its boards, which
/// open on the web canvas. Creating and managing workspaces stays in the app.
class WebWorkspacesPage extends StatefulWidget {
  const WebWorkspacesPage({super.key});

  @override
  State<WebWorkspacesPage> createState() => _WebWorkspacesPageState();
}

class _WebWorkspacesPageState extends State<WebWorkspacesPage> {
  late final _repo = context.read<WebCompanionRepository>();
  // A live query can be listened to once, and the list is rebuilt when
  // you come back from a workspace, so each visit gets a fresh one.
  late Stream<List<Workspace>> _workspaces = _repo.watchMyWorkspaces();
  final _search = TextEditingController();

  /// The open workspace (its boards are shown), or null for the list.
  Workspace? _open;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: open == null
          ? KeyedSubtree(key: const ValueKey('list'), child: _buildList())
          : _WorkspaceBoardsView(
              key: ValueKey(open.id),
              workspace: open,
              onBack: () => setState(() {
                _open = null;
                _workspaces = _repo.watchMyWorkspaces();
              }),
            ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        WebPageHeader(
          title: 'Workspaces',
          subtitle: 'Team spaces you own or joined, with their boards.',
          trailing: SizedBox(
            width: 300,
            child: WebSearchField(
              controller: _search,
              hintText: 'Search workspaces...',
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        WebStreamList<Workspace>(
          stream: _workspaces,
          compactEmpty: false,
          emptyIcon: LucideIcons.briefcase,
          emptyText: 'No workspaces yet',
          emptySubtitle: 'Create a workspace in the InkLink mobile app.',
          builder: (context, workspaces) {
            final query = _search.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? workspaces
                : workspaces
                      .where(
                        (w) =>
                            w.name.toLowerCase().contains(query) ||
                            w.description.toLowerCase().contains(query),
                      )
                      .toList();
            if (visible.isEmpty) {
              return WebEmptyHint(
                icon: LucideIcons.searchX,
                text: 'No workspaces match "${_search.text.trim()}"',
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                const gap = InkSpacing.s20;
                final columns = (constraints.maxWidth / 340).floor().clamp(
                  1,
                  4,
                );
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final w in visible)
                      SizedBox(
                        key: ValueKey(w.id),
                        width: width,
                        child: _WorkspaceCard(
                          workspace: w,
                          onOpen: () => setState(() => _open = w),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// "4 members • 3 boards".
String _workspaceCounts(Workspace w) {
  String n(int count, String word) => '$count $word${count == 1 ? '' : 's'}';
  return '${n(w.memberCount, 'member')} • ${n(w.boardCount, 'board')}';
}

/// The phone's workspace card: two tilted sheets peeking out behind a paper
/// card with the first three boards, the name and the description.
class _WorkspaceCard extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback onOpen;

  const _WorkspaceCard({required this.workspace, required this.onOpen});

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  late final Stream<List<Board>> _boards = context
      .read<WebCompanionRepository>()
      .watchWorkspaceBoards(widget.workspace.id);

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final w = widget.workspace;

    Widget sheet(String salt, double maxDegrees) => Transform.rotate(
      angle: inkDeterministicTilt('${w.id}-$salt', maxDegrees: maxDegrees),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(InkRadii.paperCard),
          boxShadow: tokens.paperShadow,
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Workspace ${w.name}, ${_workspaceCounts(w)}',
      excludeSemantics: true,
      child: SizedBox(
        height: 206,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 6,
              left: 10,
              right: 2,
              bottom: -2,
              child: sheet('back2', 2.2),
            ),
            Positioned(
              top: 3,
              left: 5,
              right: -2,
              bottom: 1,
              child: sheet('back1', 1.4),
            ),
            Positioned.fill(
              child: PaperCard(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onOpen,
                    borderRadius: BorderRadius.circular(InkRadii.paperCard),
                    child: Padding(
                      padding: const EdgeInsets.all(InkSpacing.s12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 88,
                            child: StreamBuilder<List<Board>>(
                              stream: _boards,
                              builder: (context, snapshot) {
                                final boards = (snapshot.data ?? const [])
                                    .take(3)
                                    .toList();
                                return Row(
                                  children: [
                                    for (var i = 0; i < 3; i++) ...[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: _BoardTile(
                                          board: i < boards.length
                                              ? boards[i]
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: InkSpacing.s12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.name.isEmpty ? 'Workspace' : w.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: InkType.cardTitle(tokens.ink),
                                ),
                              ),
                              _RoleChip(owner: w.currentUserRole == 'owner'),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            w.description.isNotEmpty
                                ? w.description
                                : _workspaceCounts(w),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: InkType.caption(tokens.inkMuted),
                          ),
                          if (w.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _workspaceCounts(w),
                              style: InkType.caption(tokens.inkMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A board on a workspace card: its sticky colour and title (the web has no
/// board thumbnails), or an empty slot.
class _BoardTile extends StatelessWidget {
  final Board? board;
  const _BoardTile({required this.board});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final b = board;
    if (b == null) {
      return Container(
        decoration: BoxDecoration(
          color: tokens.field,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(LucideIcons.layoutGrid, color: tokens.inkMuted, size: 20),
      );
    }
    final color = InkColors.stickyForId(b.id);
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        b.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: InkType.caption(InkColors.stickyInkFor(color)),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool owner;
  const _RoleChip({required this.owner});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: owner ? tokens.accentSoft : tokens.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        owner ? 'Owner' : 'Member',
        style: InkType.caption(owner ? tokens.accentText : tokens.inkSecondary),
      ),
    );
  }
}

/// One workspace's boards, live, as the board cards used on Home.
class _WorkspaceBoardsView extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback onBack;

  const _WorkspaceBoardsView({
    super.key,
    required this.workspace,
    required this.onBack,
  });

  @override
  State<_WorkspaceBoardsView> createState() => _WorkspaceBoardsViewState();
}

class _WorkspaceBoardsViewState extends State<_WorkspaceBoardsView> {
  late final Stream<List<Board>> _boards = context
      .read<WebCompanionRepository>()
      .watchWorkspaceBoards(widget.workspace.id);
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final w = widget.workspace;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s16,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: Icon(LucideIcons.arrowLeft, size: 18, color: tokens.ink),
            label: Text('Workspaces', style: InkType.bodyStrong(tokens.ink)),
          ),
        ),
        const SizedBox(height: InkSpacing.s8),
        WebPageHeader(
          title: w.name.isEmpty ? 'Workspace' : w.name,
          subtitle: [
            if (w.description.isNotEmpty) w.description,
            _workspaceCounts(w),
            w.currentUserRole == 'owner' ? 'You own it' : 'You are a member',
          ].join(' • '),
          trailing: SizedBox(
            width: 300,
            child: WebSearchField(
              controller: _search,
              hintText: 'Search boards...',
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        WebStreamList<Board>(
          stream: _boards,
          compactEmpty: false,
          emptyIcon: LucideIcons.layoutGrid,
          emptyText: 'No boards in this workspace yet',
          emptySubtitle: 'Add boards to it in the InkLink mobile app.',
          builder: (context, boards) {
            final query = _search.text.trim().toLowerCase();
            final visible = boards
                .where((b) => !b.isArchived)
                .where(
                  (b) =>
                      query.isEmpty ||
                      b.title.toLowerCase().contains(query) ||
                      b.tags.any((t) => t.toLowerCase().contains(query)),
                )
                .toList();
            if (visible.isEmpty) {
              return WebEmptyHint(
                icon: query.isEmpty ? LucideIcons.archive : LucideIcons.searchX,
                text: query.isEmpty
                    ? 'All boards here are archived.'
                    : 'No boards match "${_search.text.trim()}"',
              );
            }
            return WebBoardCardGrid(
              boards: visible,
              captionFor: (b) => 'Edited ${timeAgo(b.updatedAt)}',
            );
          },
        ),
      ],
    );
  }
}
