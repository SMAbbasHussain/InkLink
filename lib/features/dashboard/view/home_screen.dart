import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import '../../../domain/models/board.dart';
import '../../canvas/view/canvas_route.dart';
import '../../board_invitations/bloc/board_invitations_bloc.dart';
import '../../board_invitations/view/board_invites_screen.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../../notifications/view/notifications_route.dart';
import '../../profile/view/profile_route.dart';
import '../../theme/bloc/theme_bloc.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/view/create_board_route.dart';
import '../../dashboard/view/board_settings_route.dart';
import '../../dashboard/view/widgets/board_card.dart';
import '../../../ui/theme/ink_colors.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/command_bar.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_logo.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_segmented.dart';
import '../../../ui/widgets/sticky_note.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _watchedProfileUserId;
  bool _isNavigatingToCanvas = false;

  @override
  bool get wantKeepAlive => true; // Preserves tab state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Keeps the InkSegmented selector in sync when the TabBarView is swiped.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    context.read<BoardInvitationsBloc>().add(
      const BoardInvitationsLoadRequested(),
    );

    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    final authUser = authState is Authenticated ? authState : null;
    _syncProfileWatch(authUser?.uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => InkDialog(
        title: 'Join Board',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final boardId = controller.text.trim();
                context.read<DashboardBloc>().add(
                  DashboardJoinBoardRequested(boardId),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Join'),
          ),
        ],
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter the Join Code (Board ID)",
          ),
          autofocus: true,
        ),
      ),
    );
  }

  void _showCreateBoardDialog() {
    Navigator.push(context, buildCreateBoardRoute(context));
  }

  void _syncProfileWatch(String? userId) {
    if (_watchedProfileUserId == userId) return;
    _watchedProfileUserId = userId;
    context.read<DashboardBloc>().add(
      DashboardWatchCurrentUserProfileRequested(userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final tokens = context.ink;
    final isDark = tokens.isDark;
    final authState = context.watch<AuthBloc>().state;
    final authUser = authState is Authenticated ? authState : null;
    _syncProfileWatch(authUser?.uid);

    return MultiBlocListener(
      listeners: [
        BlocListener<DashboardBloc, DashboardState>(
          listenWhen: (previous, current) =>
              current is DashboardLoaded &&
              ((previous is DashboardLoaded &&
                      ((previous.joinedBoardId != current.joinedBoardId &&
                              current.joinedBoardId != null) ||
                          (previous.createdBoardId != current.createdBoardId &&
                              current.createdBoardId != null) ||
                          (previous.actionError != current.actionError &&
                              current.actionError != null) ||
                          (previous.actionInfo != current.actionInfo &&
                              current.actionInfo != null))) ||
                  (previous is! DashboardLoaded &&
                      (current.joinedBoardId != null ||
                          current.createdBoardId != null ||
                          current.actionError != null ||
                          current.actionInfo != null))),
          listener: (context, state) async {
            if (state is! DashboardLoaded) return;
            final dashboardBloc = this.context.read<DashboardBloc>();
            final scaffoldMessenger = ScaffoldMessenger.of(this.context);
            final navigator = Navigator.of(this.context);

            if (state.actionError != null) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.ban, size: 16, color: tokens.danger),
                      const SizedBox(width: InkSpacing.s8),
                      Flexible(child: Text(state.actionError!)),
                    ],
                  ),
                ),
              );
              dashboardBloc.add(DashboardConsumeEffects());
              return;
            }

            if (state.actionInfo != null) {
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(state.actionInfo!)),
              );
            }

            final boardId = state.createdBoardId ?? state.joinedBoardId;
            if (boardId == null) {
              if (state.actionInfo != null) {
                dashboardBloc.add(DashboardConsumeEffects());
              }
              return;
            }

            if (_isNavigatingToCanvas) return;
            _isNavigatingToCanvas = true;

            // Consume effect before navigation so state refreshes cannot
            // retrigger additional pushes while the canvas route is open.
            dashboardBloc.add(DashboardConsumeEffects());

            try {
              await navigator.push(
                buildCanvasRoute(
                  this.context,
                  boardId: boardId,
                  showTrayTipsOnEntry: true,
                ),
              );
            } finally {
              _isNavigatingToCanvas = false;
            }

            if (!mounted) return;
            setState(() => _selectedTabIndex = 1);
            _tabController.animateTo(1, duration: const Duration(milliseconds: 240));
          },
        ),
      ],
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          final photoURL = state is DashboardLoaded
              ? (state.currentUserProfile != null
                    ? state.currentUserProfile!['photoURL'] as String?
                    : null)
              : null;

          return Scaffold(
            body: DeskBackground(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NestedScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                InkSpacing.s16,
                                InkSpacing.s12,
                                InkSpacing.s16,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeader(context, tokens, isDark, authUser, photoURL),
                                  const SizedBox(height: InkSpacing.s24),
                                  _buildGreetingRow(context),
                                  const SizedBox(height: InkSpacing.s24),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SegmentedHeaderDelegate(
                            backgroundColor: tokens.surfaceDesk,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: InkSpacing.s16,
                                vertical: InkSpacing.s12,
                              ),
                              child: InkSegmented(
                                labels: const ['My Boards', 'Joined', 'Archived'],
                                selectedIndex: _selectedTabIndex,
                                onChanged: (i) {
                                  setState(() {
                                    _selectedTabIndex = i;
                                  });
                                  _tabController.animateTo(
                                    i,
                                    duration: const Duration(milliseconds: 240),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBoardGrid(
                            state,
                            isOwner: true,
                            isArchivedTab: false,
                            currentUserId: authUser?.uid,
                          ),
                          _buildBoardGrid(
                            state,
                            isOwner: false,
                            isArchivedTab: false,
                            currentUserId: authUser?.uid,
                          ),
                          _buildBoardGrid(
                            state,
                            isOwner: true,
                            isArchivedTab: true,
                            currentUserId: authUser?.uid,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 98,
                    child: CommandBar(
                      controller: _searchController,
                      hintText: "Search boards...",
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      trailing: [
                        CommandBarAction(
                          icon: LucideIcons.logIn,
                          tooltip: 'Join Board',
                          onPressed: _showJoinDialog,
                        ),
                        CommandBarAction(
                          icon: LucideIcons.plus,
                          tooltip: 'New Board',
                          gradient: tokens.accentGradient,
                          onPressed: _showCreateBoardDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    InkTokens tokens,
    bool isDark,
    Authenticated? authUser,
    String? photoURL,
  ) {
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const InkLogo(size: 30),
            const SizedBox(width: InkSpacing.s8),
            Text('InkLink', style: InkType.title(tokens.ink).copyWith(fontSize: 18)),
            const Spacer(),
            IconButton(
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, color: tokens.ink),
              onPressed: () => context.read<ThemeBloc>().add(ToggleTheme(isCurrentlyDark: isDark)),
            ),
            BlocBuilder<NotificationsBloc, NotificationsState>(
              builder: (context, state) {
                final hasUnread =
                    state is NotificationsLoaded &&
                    state.notifications.any((item) => item['isRead'] != true);

                return IconButton(
                  tooltip: 'Notifications',
                  icon: Badge(
                    isLabelVisible: hasUnread,
                    smallSize: 8,
                    backgroundColor: tokens.accent,
                    child: Icon(LucideIcons.bell, color: tokens.ink),
                  ),
                  onPressed: () {
                    Navigator.push(context, buildNotificationsRoute(context));
                  },
                );
              },
            ),
            const SizedBox(width: InkSpacing.s8),
            InkWell(
              onTap: () {
                if (authUser != null) {
                  Navigator.push(
                    context,
                    buildProfileRoute(context, userId: authUser.uid),
                  );
                }
              },
              customBorder: const CircleBorder(),
              child: InkAvatar(
                imageUrl: photoURL,
                initials: inkInitialsFor(authUser?.userName),
                id: authUser?.uid ?? '',
                size: 36,
                ring: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingRow(BuildContext context) {
    final tokens = context.ink;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: Text(
            "Ready to bring your ideas to life?",
            style: InkType.display(tokens.ink),
          ),
        ),
        const Spacer(),
        BlocBuilder<BoardInvitationsBloc, BoardInvitationsState>(
          builder: (context, inviteState) {
            final count = inviteState is BoardInvitationsLoaded
                ? inviteState.invites.length
                : 0;
            if (count == 0) return const SizedBox.shrink();

            return Transform.rotate(
              angle: 5 * 3.1415926535 / 180,
              child: SizedBox(
                width: 140,
                child: StickyNote(
                  color: InkColors.stickyButter,
                  showTape: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<BoardInvitationsBloc>(),
                          child: const BoardInvitesScreen(),
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count pending board invite${count > 1 ? 's' : ''} - tap to review',
                        style: InkType.body(InkColors.stickyInkFor(InkColors.stickyButter)),
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      Row(
                        children: [
                          Text(
                            'Review',
                            style: InkType.bodyStrong(InkColors.stickyInkFor(InkColors.stickyButter)),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: InkColors.stickyInkFor(InkColors.stickyButter),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBoardGrid(
    DashboardState state, {
    required bool isOwner,
    bool isArchivedTab = false,
    String? currentUserId,
  }) {
    if (state is DashboardInitial) {
      return Center(
        child: CircularProgressIndicator(color: context.ink.accent),
      );
    }

    if (state is DashboardLoaded) {
      final List<Board> boards;
      if (isArchivedTab) {
        boards = state.ownedBoards.where((b) => b.isArchived == true).toList();
      } else if (isOwner) {
        boards = state.ownedBoards.where((b) => b.isArchived != true).toList();
      } else {
        boards = state.joinedBoards.where((b) => b.isArchived != true).toList();
      }

      final query = _searchQuery.trim().toLowerCase();
      final displayedBoards = query.isEmpty
          ? boards
          : boards.where((b) {
              final titleMatches = b.title.toLowerCase().contains(query);
              final tagsMatch = b.tags.any((t) => t.toLowerCase().contains(query));
              final idMatches = b.id.toLowerCase().contains(query);
              return titleMatches || tagsMatch || idMatches;
            }).toList();

      if (displayedBoards.isEmpty) {
        if (query.isNotEmpty) {
          return EmptyState(
            icon: LucideIcons.searchX,
            text: 'No boards match "$_searchQuery"',
          );
        }
        final String emptyMsg = isArchivedTab
            ? "No archived boards."
            : (isOwner ? "No boards created yet." : "No boards joined yet.");
        return EmptyState(
          icon: isArchivedTab ? LucideIcons.archive : LucideIcons.layoutGrid,
          text: emptyMsg,
        );
      }

      return GridView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 160),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 196,
        ),
        itemCount: displayedBoards.length,
        itemBuilder: (context, index) {
          final board = displayedBoards[index];
          final isBoardOwner = board.ownerId == currentUserId;

          return BoardCard(
            board: board,
            isOwner: isBoardOwner,
            onDelete: (id) => context.read<DashboardBloc>().add(
              DashboardDeleteBoardRequested(id),
            ),
            onDuplicate: (isBoardOwner || board.allowMembersToCopy)
                ? () {
                    context.read<DashboardBloc>().add(
                      DashboardDuplicateBoardRequested(board.id),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isBoardOwner
                              ? 'Board duplicate created!'
                              : 'Board copy created!',
                        ),
                      ),
                    );
                  }
                : null,
            onArchive: () {
              context.read<DashboardBloc>().add(
                DashboardArchiveBoardRequested(board.id),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Board moved to archive.')),
              );
            },
            onUnarchive: () {
              context.read<DashboardBloc>().add(
                DashboardUnarchiveBoardRequested(board.id),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Board unarchived.')),
              );
            },
            onOpenSettings: isBoardOwner
                ? () {
                    Navigator.push(
                      context,
                      buildBoardSettingsRoute(context, board: board),
                    );
                  }
                : null,
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

class _SegmentedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SegmentedHeaderDelegate({required this.child, required this.backgroundColor});

  final Widget child;
  final Color backgroundColor;

  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: child);
  }

  @override
  bool shouldRebuild(covariant _SegmentedHeaderDelegate oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor || oldDelegate.child != child;
  }
}
