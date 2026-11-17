import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../domain/models/user_model.dart';
import '../data/web_companion_repository.dart';
import '../data/web_mappers.dart';
import '../glass/glass_tokens.dart';
import '../glass/glass_widgets.dart';
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
    final uid = _repo.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      children: [
        StreamBuilder<UserModel?>(
          stream: _profile,
          builder: (context, snap) => _Greeting(
            firstName: firstNameOf(snap.data?.displayName ?? _repo.currentUser?.displayName),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Everything you own or joined. Open a board on your phone to draw.',
          style: Glass.body(color: Glass.textMuted),
        ),
        const SizedBox(height: 18),
        const _QuickStats(),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: GlassSearchField(
                controller: _search,
                hintText: 'Search by title or tag',
                shortcutHint: '⌘K',
                onChanged: (_) => setState(() {}),
              ),
            ),
            GlassSegmented<_BoardFilter>(
              values: _BoardFilter.values,
              selected: _filter,
              labelOf: (f) => switch (f) {
                _BoardFilter.all => 'All',
                _BoardFilter.owned => 'Owned',
                _BoardFilter.joined => 'Joined',
                _BoardFilter.archived => 'Archived',
              },
              onChanged: (f) => setState(() => _filter = f),
            ),
          ],
        ),
        const SizedBox(height: 22),
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

/// "Good evening, Fahad" with the name in a subtle gradient.
class _Greeting extends StatelessWidget {
  final String? firstName;
  const _Greeting({required this.firstName});

  @override
  Widget build(BuildContext context) {
    final greeting = greetingFor(DateTime.now());
    return Semantics(
      header: true,
      label: firstName == null ? greeting : '$greeting, $firstName',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: firstName == null ? greeting : '$greeting, '),
            if (firstName != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFFE9E3FF), Color(0xFFB9A6FF), Color(0xFF8B9BFF)],
                  ).createShader(rect),
                  child: Text(firstName!, style: Glass.title()),
                ),
              ),
          ],
        ),
        style: Glass.title(),
      ),
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
                spacing: 10,
                runSpacing: 10,
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
    const radius = BorderRadius.all(Radius.circular(999));
    Widget chip = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: highlight ? const Color(0x268B5CF6) : Glass.bg,
            borderRadius: radius,
            border: Border.all(color: highlight ? const Color(0x598B5CF6) : Glass.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: highlight ? Glass.accentText : Glass.textMuted),
              const SizedBox(width: 8),
              Text(
                value?.toString() ?? '–',
                style: Glass.strong(color: highlight ? Glass.accentText : Glass.text),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Glass.body(color: highlight ? Glass.accentText : Glass.textSecondary),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.chevronRight, size: 14, color: Glass.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
    if (highlight) chip = GlassShimmerOnce(borderRadius: radius, child: chip);
    return chip;
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
    return FutureBuilder<List<Board>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
          children: [
            WebPageHeader(
              title: 'Discover',
              subtitle: 'Public boards from the InkLink community.',
              trailing: GlassButton.icon(
                icon: LucideIcons.refreshCw,
                tooltip: 'Refresh',
                spinIcon: loading,
                onPressed: loading
                    ? null
                    : () => setState(() => _future = _repo.loadPublicBoards()),
              ),
            ),
            if (snapshot.hasError)
              WebErrorBox(message: webErrorText(snapshot.error!))
            else if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Glass.accentText),
                  ),
                ),
              )
            else
              _buildResults(snapshot.data!, uid),
          ],
        );
      },
    );
  }

  Widget _buildResults(List<Board> boards, String? uid) {
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
          spacing: 8,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: GlassSearchField(
                controller: _search,
                hintText: 'Search public boards',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 4),
            GlassChoicePill(label: 'All', selected: _tag == null, onTap: () => setState(() => _tag = null)),
            for (final t in tags)
              GlassChoicePill(
                label: '#$t',
                selected: _tag == t,
                onTap: () => setState(() => _tag = _tag == t ? null : t),
              ),
          ],
        ),
        const SizedBox(height: 22),
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
  }
}
