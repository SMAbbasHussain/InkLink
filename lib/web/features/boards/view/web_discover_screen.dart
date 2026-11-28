import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../core/web_formatters.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../../../ui/widgets/web_page_layout.dart';
import '../../navigation/view/web_shell_section.dart';
import '../bloc/web_boards_cubit.dart';
import 'web_board_card_grid.dart';

/// Public boards explorer: search, tag filter chips, and community board cards.
class WebDiscoverPage extends StatefulWidget {
  const WebDiscoverPage({super.key});

  @override
  State<WebDiscoverPage> createState() => _WebDiscoverPageState();
}

class _WebDiscoverPageState extends State<WebDiscoverPage> {
  final _search = TextEditingController();
  String? _tag;

  @override
  void initState() {
    super.initState();
    context.read<WebBoardsCubit>().loadPublicBoards();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final state = context.watch<WebBoardsCubit>().state;
    final loading = state.publicBoardsLoading;
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
                icon: Icon(LucideIcons.rotateCw, color: tokens.inkSecondary),
                onPressed: loading
                    ? null
                    : () => context.read<WebBoardsCubit>().loadPublicBoards(
                        force: true,
                      ),
              ),
            ],
          ),
        ),
        if (state.publicBoardsError != null)
          WebErrorBox(message: webErrorText(state.publicBoardsError!))
        else if (!state.publicBoardsLoaded && loading)
          const WebLoading()
        else
          _buildResults(state.publicBoards),
      ],
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
