import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/canvas/view/canvas_route.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/dashboard/view/create_board_route.dart';
import 'package:inklink/features/dashboard/view/board_settings_screen.dart';
import 'package:inklink/features/dashboard/view/widgets/board_card.dart';
import 'package:inklink/features/dashboard/view/widgets/quick_action_button.dart';
import 'package:inklink/features/board_invitations/bloc/board_invitations_bloc.dart';
import 'package:inklink/features/board_invitations/view/board_invites_screen.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/features/notifications/view/notifications_route.dart';
import 'package:inklink/features/profile/view/profile_route.dart';
import '../../../core/constants/app_colors.dart';
import '../../theme/bloc/theme_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  String? _watchedProfileUserId;
  bool _isNavigatingToCanvas = false;

  @override
  bool get wantKeepAlive => true; // Preserves tab state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<BoardInvitationsBloc>().add(
      const BoardInvitationsLoadRequested(),
    );

    context.read<DashboardBloc>().add(LoadDashboardRequested());

    final authState = context.read<AuthBloc>().state;
    final authUser = authState is Authenticated ? authState : null;
    _syncProfileWatch(authUser?.uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Board'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Enter the Join Code (Board ID)",
          ),
          autofocus: true,
        ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
                  content: Text(state.actionError!),
                  backgroundColor: Colors.red,
                ),
              );
              dashboardBloc.add(DashboardConsumeEffects());
              return;
            }

            if (state.actionInfo != null) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(state.actionInfo!),
                  backgroundColor: Colors.orange,
                ),
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
            _tabController.animateTo(1);
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
            appBar: AppBar(
              title: const Text(
                "InkLink",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
              ),
              actions: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => context.read<ThemeBloc>().add(ToggleTheme()),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: BlocBuilder<NotificationsBloc, NotificationsState>(
                    builder: (context, state) {
                      final hasUnread =
                          state is NotificationsLoaded &&
                          state.notifications.any(
                            (item) => item['isRead'] != true,
                          );

                      return IconButton(
                        icon: Badge(
                          isLabelVisible: hasUnread,
                          smallSize: 8,
                          backgroundColor: Colors.redAccent,
                          child: const Icon(Icons.notifications_none),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            buildNotificationsRoute(context),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: InkWell(
                    onTap: () {
                      if (authUser != null) {
                        Navigator.push(
                          context,
                          buildProfileRoute(context, userId: authUser.uid),
                        );
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: authUser != null
                        ? CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            backgroundImage:
                                (photoURL != null && photoURL.isNotEmpty)
                                ? NetworkImage(photoURL)
                                : null,
                            child: (photoURL == null || photoURL.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: AppColors.primary,
                                  )
                                : null,
                          )
                        : CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            child: const Icon(
                              Icons.person,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Ready to bring your ideas to life?",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        BlocBuilder<
                          BoardInvitationsBloc,
                          BoardInvitationsState
                        >(
                          builder: (context, inviteState) {
                            final count = inviteState is BoardInvitationsLoaded
                                ? inviteState.invites.length
                                : 0;
                            if (count == 0) {
                              return const SizedBox.shrink();
                            }

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider.value(
                                      value: context
                                          .read<BoardInvitationsBloc>(),
                                      child: const BoardInvitesScreen(),
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.actionOrange.withOpacity(
                                    0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.actionOrange.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '$count pending board invite${count > 1 ? 's' : ''} - tap to review',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSearchBar(isDark),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            QuickActionButton(
                              title: "New Board",
                              icon: Icons.add,
                              color: AppColors.actionBlue,
                              onTap: _showCreateBoardDialog,
                            ),
                            const SizedBox(width: 16),
                            QuickActionButton(
                              title: "Join Board",
                              icon: Icons.group_add,
                              color: AppColors.actionOrange,
                              onTap: _showJoinDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: "My Boards"),
                        Tab(text: "Joined Boards"),
                      ],
                    ),
                    isDark
                        ? AppColors.bgDark
                        : Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildBoardGrid(state, isOwner: true),
                  _buildBoardGrid(state, isOwner: false),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoardGrid(DashboardState state, {required bool isOwner}) {
    if (state is DashboardInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is DashboardLoaded) {
      final boards = isOwner ? state.ownedBoards : state.joinedBoards;

      if (boards.isEmpty) {
        return Center(
          child: Text(
            isOwner ? "No boards created yet." : "No boards joined yet.",
            style: const TextStyle(color: Colors.grey),
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: boards.length,
        itemBuilder: (context, index) {
          final board = boards[index];
          return BoardCard(
            board: board,
            isOwner: isOwner,
            onRename: (id, newName) => context.read<DashboardBloc>().add(
              DashboardRenameBoardRequested(id, newName),
            ),
            onDelete: (id) => context.read<DashboardBloc>().add(
              DashboardDeleteBoardRequested(id),
            ),
            onOpenSettings: isOwner
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<DashboardBloc>(),
                          child: BoardSettingsScreen(board: board),
                        ),
                      ),
                    );
                  }
                : null,
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Ask AI to generate a template...",
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          suffixIcon: Icon(Icons.auto_awesome, color: AppColors.accent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);

  final TabBar _tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is _SliverAppBarDelegate) {
      return oldDelegate.backgroundColor != backgroundColor;
    }
    return false;
  }
}
