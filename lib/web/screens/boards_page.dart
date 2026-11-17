import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../domain/models/user_model.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_chip.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../widgets/board_card.dart';
import '../widgets/web_widgets.dart';
import 'web_shell_nav.dart';

enum _BoardFilter { all, owned, joined, archived }

/// The user's boards (live), with a greeting, quick stats, search and filters.
class WebBoardsPage extends StatefulWidget {
  const WebBoardsPage({super.key});

  @override
  State<WebBoardsPage> createState() => _WebBoardsPageState();
}

class _WebBoardsPageState extends State<WebBoardsPage> {
  late final _repo = context.read<WebCompanionRepository>();
  late final Stream<List<Board>> _boards = _repo.watchMyBoards();
  late final Stream<UserModel?> _profile = _repo.watchMyProfile();
  final _search = TextEditingController();
  _BoardFilter _filter = _BoardFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Board> _apply(List<Board> boards, String? uid) {
    final query = _search.text.trim().toLowerCase();
    return boards.where((b) {
      final matchesFilter = switch (_filter) {
        _BoardFilter.all => !b.isArchived,
        _BoardFilter.owned => !b.isArchived && b.ownerId == uid,
        _BoardFilter.joined => !b.isArchived && b.ownerId != uid,
        _BoardFilter.archived => b.isArchived,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return b.title.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final uid = _repo.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        StreamBuilder<UserModel?>(
          stream: _profile,
          builder: (context, snap) {
            final first = firstNameOf(snap.data?.displayName ?? _repo.currentUser?.displayName);
            return Semantics(
              header: true,
              child: Text(
                first == null ? greetingFor(DateTime.now()) : '${greetingFor(DateTime.now())}, $first',
                style: InkType.display(ink.ink),
              ),
            );
          },
        ),
        const SizedBox(height: InkSpacing.s4),
        Text(
          'Everything you own or joined. Open a board on your phone to draw.',
          style: InkType.body(ink.inkSecondary),
        ),
        const SizedBox(height: InkSpacing.s16),
        const _QuickStats(),
        const SizedBox(height: InkSpacing.s24),
        Wrap(
          spacing: InkSpacing.s12,
          runSpacing: InkSpacing.s12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: InkTextField(
                controller: _search,
                hintText: 'Search by title or tag',
                leadingIcon: LucideIcons.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            for (final f in _BoardFilter.values)
              InkChip(
                label: switch (f) {
                  _BoardFilter.all => 'All',
                  _BoardFilter.owned => 'Owned',
                  _BoardFilter.joined => 'Joined',
                  _BoardFilter.archived => 'Archived',
                },
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s20),
        WebStreamList<Board>(
          stream: _boards,
          compactEmpty: false,
          emptyIcon: LucideIcons.layoutGrid,
          emptyText: 'No boards yet',
          emptySubtitle: 'Create a board in the InkLink mobile app and it will show up here.',
          builder: (context, boards) {
            final visible = _apply(boards, uid);
            if (visible.isEmpty) {
              return const WebEmptyHint(
                icon: LucideIcons.searchX,
                text: 'No boards match this search or filter.',
              );
            }
            return WebBoardGrid(
              boards: visible,
              currentUid: uid,
              allJoined: true,
              onOpen: (b) => showOpenInAppDialog(context, b),
            );
          },
        ),
      ],
    );
  }
}

/// Small clickable summary: boards, waiting invites, friends.
class _QuickStats extends StatefulWidget {
  const _QuickStats();

  @override
  State<_QuickStats> createState() => _QuickStatsState();
}

class _QuickStatsState extends State<_QuickStats> {
  late final _repo = context.read<WebCompanionRepository>();
  late final _boards = _repo.watchMyBoards();
  late final _boardInvites = _repo.watchBoardInvites();
  late final _wsInvites = _repo.watchWorkspaceInvites();
  late final _friends = _repo.watchFriends();

  @override
  Widget build(BuildContext context) {
    final nav = WebShellNav.maybeOf(context);
    return StreamBuilder(
      stream: _boards,
      builder: (context, boards) => StreamBuilder(
        stream: _boardInvites,
        builder: (context, bi) => StreamBuilder(
          stream: _wsInvites,
          builder: (context, wi) => StreamBuilder(
            stream: _friends,
            builder: (context, fr) {
              final boardCount = boards.data?.where((b) => !b.isArchived).length;
              final invites = (bi.data?.length ?? 0) + (wi.data?.length ?? 0);
              final friends = fr.data?.length;
              return Wrap(
                spacing: InkSpacing.s12,
                runSpacing: InkSpacing.s12,
                children: [
                  _StatChip(
                    icon: LucideIcons.layoutGrid,
                    value: boardCount,
                    label: boardCount == 1 ? 'board' : 'boards',
                  ),
                  _StatChip(
                    icon: LucideIcons.mailOpen,
                    value: invites,
                    label: invites == 1 ? 'invite waiting' : 'invites waiting',
                    highlight: invites > 0,
                    onTap: nav == null ? null : () => nav.goTo(WebSection.invites),
                  ),
                  _StatChip(
                    icon: LucideIcons.users,
                    value: friends,
                    label: friends == 1 ? 'friend' : 'friends',
                    onTap: nav == null ? null : () => nav.goTo(WebSection.friends),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int? value;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final fg = highlight ? ink.accentText : ink.ink;
    return Material(
      color: highlight ? ink.accentSoft : ink.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlight ? Colors.transparent : ink.glassStroke),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: highlight ? ink.accentText : ink.inkSecondary),
              const SizedBox(width: 8),
              Text(value?.toString() ?? '–', style: InkType.bodyStrong(fg)),
              const SizedBox(width: 5),
              Text(label, style: InkType.body(highlight ? fg : ink.inkSecondary)),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight, size: 14, color: ink.inkMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Public boards with search and tag filters.
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
    final uid = _repo.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        WebPageHeader(
          title: 'Discover',
          subtitle: 'Public boards from the InkLink community.',
          trailing: IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => setState(() => _future = _repo.loadPublicBoards()),
          ),
        ),
        FutureBuilder<List<Board>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return WebErrorBox(message: webErrorText(snapshot.error!));
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(InkSpacing.s32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final boards = snapshot.data!;
            final tags = topTags(boards.map((b) => b.tags));
            final query = _search.text.trim().toLowerCase();
            final visible = boards.where((b) {
              if (_tag != null && !b.tags.contains(_tag)) return false;
              if (query.isEmpty) return true;
              return b.title.toLowerCase().contains(query) ||
                  b.tags.any((t) => t.toLowerCase().contains(query));
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: InkSpacing.s8,
                  runSpacing: InkSpacing.s12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: InkTextField(
                        controller: _search,
                        hintText: 'Search public boards',
                        leadingIcon: LucideIcons.search,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    InkChip(
                      label: 'All',
                      selected: _tag == null,
                      onTap: () => setState(() => _tag = null),
                    ),
                    for (final t in tags)
                      InkChip(
                        label: '#$t',
                        selected: _tag == t,
                        onTap: () => setState(() => _tag = _tag == t ? null : t),
                      ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s20),
                if (boards.isEmpty)
                  const WebEmptyHint(icon: LucideIcons.compass, text: 'No public boards yet.')
                else if (visible.isEmpty)
                  const WebEmptyHint(
                    icon: LucideIcons.searchX,
                    text: 'No public boards match this search or tag.',
                  )
                else
                  WebBoardGrid(
                    boards: visible,
                    currentUid: uid,
                    onOpen: (b) => showOpenInAppDialog(context, b),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
