import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/domain/repositories/board_repository.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/features/dashboard/view/widgets/board_card.dart';
import 'package:inklink/features/dashboard/view/widgets/quick_action_button.dart';
import 'package:inklink/features/profile/view/profile_screen.dart';
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

    // Initialize data flow: Firebase -> Isar -> Bloc -> UI
    context.read<BoardRepository>().startBoardsSync();
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
                try {
                  await context.read<BoardRepository>().joinBoard(controller.text.trim());
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully joined!')),
                  );
                  _tabController.animateTo(1);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to join: $e')),
                  );
                }
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
    final user = FirebaseAuth.instance.currentUser;

    return MultiBlocListener(
      listeners: [
        // Listen for Canvas creation success to navigate
        BlocListener<CanvasBloc, CanvasState>(
          listener: (context, state) {
            if (state is CanvasReady) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CanvasScreen(boardId: state.boardId),
                ),
              );
            }
            if (state is CanvasError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            }
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
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(userId: user.uid),
                          ),
                        );
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person, size: 20, color: AppColors.primary)
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
                          "Hello, ${user?.displayName?.split(' ')[0] ?? 'Creator'}! 👋",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                              onTap: () => context.read<CanvasBloc>().add(CreateBoardRequested()),
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
                    isDark ? AppColors.bgDark : Theme.of(context).scaffoldBackgroundColor,
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
            onRename: (id, newName) => context.read<BoardRepository>().renameBoard(id, newName),
            onDelete: (id) => context.read<BoardRepository>().deleteBoard(id),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}