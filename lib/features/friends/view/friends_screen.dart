import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class Friend {
  final String name;
  final String lastActive;
  final bool isOnline;
  final int gradientIndex;

  Friend({
    required this.name,
    required this.lastActive,
    required this.isOnline,
    required this.gradientIndex,
  });
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Shared Gradients for the "Glitter" effect
  final List<Gradient> _avatarGradients = [
    const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
    const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
    const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
  ];

  final List<Friend> _allFriends = [
    Friend(name: "Abbas Hussain", lastActive: "2m ago", isOnline: true, gradientIndex: 0),
    Friend(name: "Fahad Javed", lastActive: "1h ago", isOnline: false, gradientIndex: 1),
    Friend(name: "Faha Ahmed", lastActive: "Just now", isOnline: true, gradientIndex: 2),
    Friend(name: "Aamer Mehmood", lastActive: "5h ago", isOnline: false, gradientIndex: 0),
    Friend(name: "Syed Hussain", lastActive: "10m ago", isOnline: true, gradientIndex: 1),
    Friend(name: "Zainab Ali", lastActive: "3d ago", isOnline: false, gradientIndex: 2),
    Friend(name: "Omar Farooq", lastActive: "8h ago", isOnline: true, gradientIndex: 0),
  ];

  List<Friend> get _recentFriends => _allFriends.take(4).toList();
  List<Friend> _filteredFriends = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredFriends = _allFriends;
  }

  void _runFilter(String enteredKeyword) {
    setState(() {
      _filteredFriends = enteredKeyword.isEmpty
          ? _allFriends
          : _allFriends
              .where((user) => user.name.toLowerCase().contains(enteredKeyword.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Collaborators")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildSearchBar(isDark),
          ),
          if (!isSearching) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.0),
              child: Text("Recent Contacts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 115,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _recentFriends.length,
                itemBuilder: (context, index) => _buildRecentItem(_recentFriends[index], isDark),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text(
              isSearching ? "Search Results" : "All Collaborators",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredFriends.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredFriends.length,
                    itemBuilder: (context, index) => _buildFriendCard(context, _filteredFriends[index], isDark),
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE GLITTER AVATAR ---
  Widget _buildGlitterAvatar(Friend friend, double size, bool isDark) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: _avatarGradients[friend.gradientIndex],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_avatarGradients[friend.gradientIndex] as LinearGradient).colors[0].withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(
            child: Text(
              friend.name[0],
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (friend.isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.bgDark : Colors.white,
                  width: size * 0.05,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- RECENT CONTACTS UI ---
  Widget _buildRecentItem(Friend friend, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          _buildGlitterAvatar(friend, 65, isDark),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              friend.name.split(' ')[0],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }

  // --- ALL FRIENDS UI ---
  Widget _buildFriendCard(BuildContext context, Friend friend, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _buildGlitterAvatar(friend, 50, isDark), // Now uses the same glitter style
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  "Last active ${friend.lastActive}",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Invite", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // ... (Search Bar and Empty State remain the same as previous)
  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _runFilter,
        decoration: InputDecoration(
          hintText: "Search collaborators...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _runFilter(''); }) 
            : null,
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text("No collaborators found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}