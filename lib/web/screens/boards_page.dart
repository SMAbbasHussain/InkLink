import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/widgets/ink_chip.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../data/web_companion_repository.dart';
import '../widgets/web_widgets.dart';

enum _BoardFilter { all, owned, joined, archived }

/// The user's boards (live), with search and filters.
class WebBoardsPage extends StatefulWidget {
  const WebBoardsPage({super.key});

  @override
  State<WebBoardsPage> createState() => _WebBoardsPageState();
}

class _WebBoardsPageState extends State<WebBoardsPage> {
  late final Stream<List<Board>> _boards =
      context.read<WebCompanionRepository>().watchMyBoards();
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
    final uid = context.read<WebCompanionRepository>().currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        const WebPageHeader(
          title: 'Your boards',
          subtitle: 'Everything you own or joined. Open a board on your phone to draw.',
        ),
        InkTextField(
          controller: _search,
          hintText: 'Search by title or tag',
          leadingIcon: LucideIcons.search,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: InkSpacing.s12),
        Wrap(
          spacing: InkSpacing.s8,
          children: [
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
        const SizedBox(height: InkSpacing.s16),
        WebStreamList<Board>(
          stream: _boards,
          emptyIcon: LucideIcons.layoutGrid,
          emptyText: 'No boards yet',
          emptySubtitle: 'Create a board in the InkLink mobile app and it will show up here.',
          builder: (context, boards) {
            final visible = _apply(boards, uid);
            if (visible.isEmpty) {
              return const WebErrorBoxless(text: 'No boards match this filter.');
            }
            return WebBoardGrid(
              boards: visible,
              currentUid: uid,
              onOpen: (b) => showOpenInAppDialog(context, b),
            );
          },
        ),
      ],
    );
  }
}

/// Public boards anyone can browse.
class WebDiscoverPage extends StatefulWidget {
  const WebDiscoverPage({super.key});

  @override
  State<WebDiscoverPage> createState() => _WebDiscoverPageState();
}

class _WebDiscoverPageState extends State<WebDiscoverPage> {
  late Future<List<Board>> _future =
      context.read<WebCompanionRepository>().loadPublicBoards();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<WebCompanionRepository>().currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.all(InkSpacing.s24),
      children: [
        WebPageHeader(
          title: 'Discover',
          subtitle: 'Public boards from the InkLink community.',
          trailing: IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => setState(() {
              _future = context.read<WebCompanionRepository>().loadPublicBoards();
            }),
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
            if (boards.isEmpty) {
              return const WebErrorBoxless(text: 'No public boards yet.');
            }
            return WebBoardGrid(
              boards: boards,
              currentUid: uid,
              onOpen: (b) => showOpenInAppDialog(context, b),
            );
          },
        ),
      ],
    );
  }
}

/// Plain muted line for "nothing here" inside a filtered list.
class WebErrorBoxless extends StatelessWidget {
  final String text;
  const WebErrorBoxless({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: InkSpacing.s24),
        child: Center(child: Text(text)),
      );
}
