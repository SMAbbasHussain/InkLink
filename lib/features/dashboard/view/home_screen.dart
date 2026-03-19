import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/canvas/view/canvas_route.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/dashboard/view/widgets/board_card.dart';
import 'package:inklink/features/dashboard/view/widgets/quick_action_button.dart';
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

  @override
  bool get wantKeepAlive => true; // Preserves tab state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    context.read<DashboardBloc>().add(LoadDashboardRequested());
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final authUser = authState is Authenticated ? authState : null;

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
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Icon(Icons.notifications_none),
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
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      backgroundImage: authUser?.photoUrl != null
                          ? NetworkImage(authUser!.photoUrl!)
                          : null,
                      child: authUser?.photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 20,
                              color: AppColors.primary,
                            )
                          : null,
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
                          "Hello, ${authUser?.userName.split(' ')[0] ?? 'Creator'}! 👋",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Ready to bring your ideas to life?",
                          style: TextStyle(color: Colors.grey),
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
                              onTap: () => context.read<DashboardBloc>().add(
                                DashboardCreateBoardRequested(),
                              ),
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
