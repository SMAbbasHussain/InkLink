import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/canvas/view/canvas_route.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/dashboard/view/widgets/board_card.dart';
import 'package:inklink/features/dashboard/view/widgets/quick_action_button.dart';
import 'package:inklink/features/friends/bloc/friends_bloc.dart';
import 'package:inklink/features/friends/bloc/friends_event.dart';
import 'package:inklink/features/friends/bloc/friends_state.dart';
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
    final nameController = TextEditingController();
    final inviteesController = TextEditingController();
    final selectedFriendIds = <String>{};
    int inviteExpiryHours = 72;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Board'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Board name',
                      hintText: 'Enter board name',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inviteesController,
                    decoration: const InputDecoration(
                      labelText: 'Invite users (optional)',
                      hintText: 'Comma-separated emails or user IDs',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select from friends (optional)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<FriendsBloc>().add(LoadFriendsInfo());
                        },
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: BlocBuilder<FriendsBloc, FriendsState>(
                      builder: (context, friendsState) {
                        if (friendsState is FriendsLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (friendsState is! FriendsLoaded ||
                            friendsState.friends.isEmpty) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No friends loaded yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: friendsState.friends.map((friend) {
                              final uid = friend['uid']?.toString() ?? '';
                              if (uid.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final name =
                                  friend['displayName']?.toString() ?? 'Friend';
                              final selected = selectedFriendIds.contains(uid);
                              return FilterChip(
                                selected: selected,
                                label: Text(name),
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      selectedFriendIds.add(uid);
                                    } else {
                                      selectedFriendIds.remove(uid);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Invite expiration'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: inviteExpiryHours,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 24, child: Text('24 hours')),
                      DropdownMenuItem(value: 72, child: Text('3 days')),
                      DropdownMenuItem(value: 168, child: Text('7 days')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        inviteExpiryHours = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final invitees = inviteesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toSet()
                      .toList();

                  invitees.addAll(selectedFriendIds);

                  context.read<DashboardBloc>().add(
                    DashboardCreateBoardRequested(
                      title: nameController.text.trim().isEmpty
                          ? 'Untitled Board'
                          : nameController.text.trim(),
                      invitedUserIds: invitees,
                      inviteExpiryHours: inviteExpiryHours,
                    ),
                  );

                  Navigator.pop(dialogContext);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
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
              (current.joinedBoardId != null ||
                  current.createdBoardId != null ||
                  current.actionError != null),
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

            final boardId = state.createdBoardId ?? state.joinedBoardId;
            if (boardId == null) return;

            await navigator.push(
              buildCanvasRoute(
                this.context,
                boardId: boardId,
                showTrayTipsOnEntry: true,
              ),
            );
            if (!mounted) return;
            _tabController.animateTo(1);
            dashboardBloc.add(DashboardConsumeEffects());
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
