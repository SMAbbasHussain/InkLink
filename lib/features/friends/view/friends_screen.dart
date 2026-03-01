import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/friends/view/widgets/friend_request_banner.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/friends_bloc.dart';
import '../bloc/friends_event.dart';
import '../bloc/friends_state.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();

  final List<Gradient> _avatarGradients = [
    const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
    const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
    const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
  ];

  @override
  void initState() {
    super.initState();
    // Start listening to Firestore streams
    context.read<FriendsBloc>().add(LoadFriendsInfo());
  }

  @override
  void dispose() {
    // FIX: Properly cleaning up listeners
    _searchController.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<FriendsBloc, FriendsState>(
      listener: (context, state) {
        if (state is FriendsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Friends"),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => _showAddFriendDialog(context, isDark),
            ),
          ],
        ),
        body: BlocBuilder<FriendsBloc, FriendsState>(
          builder: (context, state) {
            return CustomScrollView(
              slivers: [
                // 1. Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildSearchBar(isDark),
                  ),
                ),

                // 2. Incoming Requests Banner
                if (state is FriendsLoaded && state.incomingRequests.isNotEmpty)
                  SliverToBoxAdapter(
                    child: FriendRequestBanner(
                      count: state.incomingRequests.length,
                    ),
                  ),

                // 3. Section Header (Only show if not searching or if results exist)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18.0,
                      vertical: 12,
                    ),
                    child: Text(
                      _searchController.text.isNotEmpty
                          ? "Search Results"
                          : "Collaborators",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                // 4. Main Friends List (Only call this ONCE)
                _buildFriendsSliverList(state, isDark),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- REFACTORED: HANDLES FRIENDS LIST ---
  Widget _buildFriendsSliverList(FriendsState state, bool isDark) {
    if (state is FriendsLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (state is FriendsLoaded) {
      // Logic for Local Filtering
      final filteredList = state.friends.where((f) {
        final name = f['displayName']?.toString().toLowerCase() ?? "";
        return name.contains(_searchController.text.toLowerCase());
      }).toList();

      if (filteredList.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildFriendCard(context, filteredList[index], isDark),
            childCount: filteredList.length,
          ),
        ),
      );
    }

    return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState());
  }

  Widget _buildFriendCard(
    BuildContext context,
    Map<String, dynamic> friendData,
    bool isDark,
  ) {
    final name = friendData['displayName'] ?? "User";
    final photoUrl = friendData['photoURL'];
    // Use the name's length to pick a consistent gradient index
    final int gradientIdx = name.length % _avatarGradients.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          // GLITTER AVATAR
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: photoUrl == null ? _avatarGradients[gradientIdx] : null,
              image: photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl == null
                ? Center(
                    child: Text(
                      name[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 60,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "No collaborators found",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {}), // Refresh local filter
        decoration: InputDecoration(
          hintText: "Search your friends...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchController.clear()),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Add Friend",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _globalSearchController,
              decoration: InputDecoration(
                hintText: "Enter friend's exact email...",
                prefixIcon: const Icon(Icons.mail_outline),
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                context.read<FriendsBloc>().add(
                  SearchUserByEmailRequested(val),
                );
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BlocBuilder<FriendsBloc, FriendsState>(
                builder: (context, state) {
                  if (state is FriendsLoading)
                    return const Center(child: CircularProgressIndicator());
                  if (state is SearchResultsLoaded) {
                    if (state.results.isEmpty)
                      return const Text("No user found with this email.");
                    final user = state.results.first;
                    final String name = user['displayName'] ?? "U";
                    final int gradientIdx =
                        name.length % _avatarGradients.length;

                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: user['photoURL'] == null
                              ? _avatarGradients[gradientIdx]
                              : null,
                          image: user['photoURL'] != null
                              ? DecorationImage(
                                  image: NetworkImage(user['photoURL']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user['photoURL'] == null
                            ? Center(
                                child: Text(
                                  name[0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      title: Text(name),
                      subtitle: Text(user['email'] ?? ""),
                      trailing: ElevatedButton(
                        onPressed: () {
                          context.read<FriendsBloc>().add(
                            SendFriendRequestRequested(user['uid']),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text("Add"),
                      ),
                    );
                  }
                  return const Text("Search for your teammates by email.");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
