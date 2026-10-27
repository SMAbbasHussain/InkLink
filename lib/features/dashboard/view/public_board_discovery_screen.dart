import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../canvas/view/canvas_route.dart';
import '../../../domain/models/board.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/board_card_frame.dart';
import '../bloc/public_boards/public_boards_bloc.dart';
import '../bloc/public_boards/public_boards_event.dart';
import '../bloc/public_boards/public_boards_state.dart';

class PublicBoardDiscoveryScreen extends StatefulWidget {
  const PublicBoardDiscoveryScreen({super.key});

  @override
  State<PublicBoardDiscoveryScreen> createState() =>
      _PublicBoardDiscoveryScreenState();
}

class _PublicBoardDiscoveryScreenState
    extends State<PublicBoardDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      context.read<PublicBoardsBloc>().add(const PublicBoardsLoadMore());
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        context
            .read<PublicBoardsBloc>()
            .add(PublicBoardsSearchChanged(query));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    return Scaffold(
      backgroundColor: tokens.surfaceDesk,
      appBar: AppBar(
        backgroundColor: tokens.surfaceDesk,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: tokens.ink),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'Explore Public Boards',
          style: InkType.title(tokens.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.rotateCw, color: tokens.inkSecondary),
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              context
                  .read<PublicBoardsBloc>()
                  .add(const PublicBoardsRefreshRequested());
            },
          ),
        ],
      ),
      body: BlocConsumer<PublicBoardsBloc, PublicBoardsState>(
        listener: (context, state) {
          if (state.errorMessage != null &&
              state.status == PublicBoardsStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: tokens.danger,
              ),
            );
          } else if (state.actionSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(LucideIcons.checkCircle2, size: 16, color: tokens.success),
                    const SizedBox(width: InkSpacing.s8),
                    Flexible(child: Text(state.actionSuccessMessage!)),
                  ],
                ),
                backgroundColor: tokens.paper,
              ),
            );
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            color: tokens.accent,
            backgroundColor: tokens.paper,
            onRefresh: () async {
              final completer = Completer<void>();
              context
                  .read<PublicBoardsBloc>()
                  .add(const PublicBoardsRefreshRequested());
              Future.delayed(const Duration(milliseconds: 600), () {
                if (!completer.isCompleted) completer.complete();
              });
              return completer.future;
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discover collaborative workspaces, design templates, and community brainstorms.',
                          style: InkType.body(tokens.inkSecondary),
                        ),
                        const SizedBox(height: 12),
                        _buildSearchBar(context, tokens),
                      ],
                    ),
                  ),
                ),
                if (state.recommendedBoards.isNotEmpty &&
                    state.searchQuery.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildRecommendationSection(
                      context,
                      tokens,
                      state.recommendedBoards,
                    ),
                  ),
                if (state.availableTags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildTagFilterBar(
                      context,
                      tokens,
                      state.availableTags,
                      state.selectedTag,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildSortAndCountRow(
                      context,
                      tokens,
                      state.filteredBoards.length,
                      state.sort,
                    ),
                  ),
                ),
                if (state.status == PublicBoardsStatus.loading &&
                    state.boards.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.filteredBoards.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(
                      context,
                      tokens,
                      isSearching: state.searchQuery.isNotEmpty ||
                          state.selectedTag != null,
                    ),
                  )
                else
                  _buildBoardsGrid(
                    context,
                    tokens,
                    state.filteredBoards,
                  ),
                if (state.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, InkTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.glassStroke,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 20, color: tokens.inkSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: InkType.body(tokens.ink),
              decoration: InputDecoration(
                hintText: 'Search by title, topic, or keyword...',
                hintStyle: InkType.body(tokens.inkMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.x, size: 18, color: tokens.inkSecondary),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(
    BuildContext context,
    InkTokens tokens,
    List<Board> recommendedBoards,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(LucideIcons.sparkles, size: 18, color: tokens.accent),
              const SizedBox(width: 8),
              Text(
                'Recommended for You',
                style: InkType.subhead(tokens.ink),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 204,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recommendedBoards.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final board = recommendedBoards[index];
              return SizedBox(
                width: 250,
                child: _buildDiscoveryCard(context, tokens, board),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTagFilterBar(
    BuildContext context,
    InkTokens tokens,
    List<String> availableTags,
    String? selectedTag,
  ) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: availableTags.length + 1,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedTag == null;
            return ChoiceChip(
              label: const Text('All'),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                context
                    .read<PublicBoardsBloc>()
                    .add(const PublicBoardsTagSelected(null));
              },
              selectedColor: tokens.accent,
              backgroundColor: tokens.paper,
              labelStyle: InkType.caption(
                isSelected ? Colors.white : tokens.inkSecondary,
              ),
              side: BorderSide(
                color: isSelected ? tokens.accent : tokens.glassStroke,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }

          final tag = availableTags[index - 1];
          final isSelected = selectedTag == tag;

          return ChoiceChip(
            label: Text('#$tag'),
            selected: isSelected,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              context
                  .read<PublicBoardsBloc>()
                  .add(PublicBoardsTagSelected(tag));
            },
            selectedColor: tokens.accent,
            backgroundColor: tokens.paper,
            labelStyle: InkType.caption(
              isSelected ? Colors.white : tokens.inkSecondary,
            ),
            side: BorderSide(
              color: isSelected ? tokens.accent : tokens.glassStroke,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortAndCountRow(
    BuildContext context,
    InkTokens tokens,
    int count,
    PublicBoardSort currentSort,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$count ${count == 1 ? "public board" : "public boards"}',
          style: InkType.body(tokens.inkSecondary),
        ),
        Row(
          children: [
            Text('Sort: ', style: InkType.body(tokens.inkMuted)),
            DropdownButton<PublicBoardSort>(
              value: currentSort,
              underline: const SizedBox(),
              icon: Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: tokens.inkSecondary,
              ),
              style: InkType.body(tokens.ink),
              dropdownColor: tokens.paper,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(
                  value: PublicBoardSort.recent,
                  child: Text('Most Recent'),
                ),
                DropdownMenuItem(
                  value: PublicBoardSort.popular,
                  child: Text('Most Popular'),
                ),
              ],
              onChanged: (newSort) {
                if (newSort != null) {
                  HapticFeedback.selectionClick();
                  context
                      .read<PublicBoardsBloc>()
                      .add(PublicBoardsSortChanged(newSort));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBoardsGrid(
    BuildContext context,
    InkTokens tokens,
    List<Board> boards,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          mainAxisExtent: 200,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final board = boards[index];
            return _buildDiscoveryCard(context, tokens, board);
          },
          childCount: boards.length,
        ),
      ),
    );
  }

  Widget _buildDiscoveryCard(
    BuildContext context,
    InkTokens tokens,
    Board board,
  ) {
    final memberCount = board.membersCount;
    final caption = board.tags.isNotEmpty
        ? board.tags.take(3).map((t) => "#$t").join(" ")
        : (memberCount == 1 ? '1 member' : '$memberCount members');

    return BoardCardFrame(
      previewPath: board.previewPath,
      title: board.title,
      caption: caption,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          buildCanvasRoute(context, boardId: board.id),
        );
      },
      menuButton: PopupMenuButton<String>(
        tooltip: 'Board options',
        padding: EdgeInsets.zero,
        offset: const Offset(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: tokens.paper,
        elevation: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.paper.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.glassStroke, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.users, size: 11, color: tokens.inkSecondary),
              const SizedBox(width: 3),
              Text(
                '$memberCount',
                style: InkType.caption(tokens.inkSecondary),
              ),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronDown, size: 10, color: tokens.inkMuted),
            ],
          ),
        ),
        onSelected: (val) {
          if (val == 'open') {
            Navigator.push(
              context,
              buildCanvasRoute(context, boardId: board.id),
            );
          } else if (val == 'join') {
            HapticFeedback.lightImpact();
            context.read<PublicBoardsBloc>().add(
                  PublicBoardsJoinBoard(board.id, boardTitle: board.title),
                );
          } else if (val == 'copy_link') {
            final link = 'inklink://board/${board.id}';
            Clipboard.setData(ClipboardData(text: link));
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(LucideIcons.copy, size: 16, color: tokens.success),
                    const SizedBox(width: InkSpacing.s8),
                    Expanded(child: Text('Board link copied: $link')),
                  ],
                ),
                backgroundColor: tokens.paper,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (val == 'request_edit') {
            _showRequestAccessDialog(context, tokens, board, isEditRequest: true);
          } else if (val == 'request_join') {
            _showRequestAccessDialog(context, tokens, board, isEditRequest: false);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: [
                Icon(LucideIcons.externalLink, size: 14, color: tokens.ink),
                const SizedBox(width: 8),
                Text('Open Board', style: InkType.body(tokens.ink)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'join',
            child: Row(
              children: [
                Icon(LucideIcons.logIn, size: 14, color: tokens.accent),
                const SizedBox(width: 8),
                Text('Join Board', style: InkType.body(tokens.accentText)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'copy_link',
            child: Row(
              children: [
                Icon(LucideIcons.share2, size: 14, color: tokens.inkSecondary),
                const SizedBox(width: 8),
                Text('Copy Deep Link', style: InkType.body(tokens.ink)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'request_edit',
            child: Row(
              children: [
                Icon(LucideIcons.filePenLine, size: 14, color: tokens.inkSecondary),
                const SizedBox(width: 8),
                Text('Request Edit Access', style: InkType.body(tokens.inkSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestAccessDialog(
    BuildContext context,
    InkTokens tokens,
    Board board, {
    required bool isEditRequest,
  }) {
    final noteController = TextEditingController();
    final actionTitle =
        isEditRequest ? 'Request Edit Access' : 'Request to Join';
    final actionPrompt = isEditRequest
        ? 'Send a request to the board owner for editor permissions on "${board.title}"?'
        : 'Send a request to the board owner to join "${board.title}"?';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isEditRequest ? LucideIcons.filePenLine : LucideIcons.userPlus,
              size: 20,
              color: tokens.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                actionTitle,
                style: InkType.title(tokens.ink),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              actionPrompt,
              style: InkType.body(tokens.inkSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLength: 140,
              decoration: InputDecoration(
                hintText: 'Optional note to owner...',
                hintStyle: InkType.caption(tokens.inkMuted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: tokens.glassStroke),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: InkType.body(tokens.inkMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final note = noteController.text.trim();
              Navigator.pop(dialogCtx);
              if (isEditRequest) {
                context.read<PublicBoardsBloc>().add(
                      PublicBoardsRequestEditAccess(
                        board.id,
                        message: note.isNotEmpty ? note : null,
                      ),
                    );
              } else {
                context.read<PublicBoardsBloc>().add(
                      PublicBoardsRequestJoinAccess(
                        board.id,
                        message: note.isNotEmpty ? note : null,
                      ),
                    );
              }
            },
            child:
                Text('Send Request', style: InkType.bodyStrong(Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    InkTokens tokens, {
    required bool isSearching,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.paper,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.glassStroke),
              ),
              child: Icon(
                isSearching ? LucideIcons.searchX : LucideIcons.compass,
                size: 32,
                color: tokens.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No Matching Boards Found' : 'No Public Boards Yet',
              style: InkType.title(tokens.ink),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try broadening your search query or selecting a different tag filter.'
                  : 'Be the first to publish a public board from your dashboard settings!',
              textAlign: TextAlign.center,
              style: InkType.body(tokens.inkSecondary),
            ),
            if (isSearching) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(LucideIcons.filterX, size: 16),
                label: const Text('Clear Filters'),
                onPressed: () {
                  _searchController.clear();
                  context
                      .read<PublicBoardsBloc>()
                      .add(const PublicBoardsSearchChanged(''));
                  context
                      .read<PublicBoardsBloc>()
                      .add(const PublicBoardsTagSelected(null));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.ink,
                  side: BorderSide(color: tokens.glassStroke),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
