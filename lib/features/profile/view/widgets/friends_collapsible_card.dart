import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_bloc.dart';
import 'package:inklink/features/auth/bloc/auth_state.dart';
import '../../../chat/view/chat_thread_route.dart';

import '../../../../domain/models/chat/chat_conversation_model.dart';
import '../../../../ui/theme/ink_colors.dart';
import '../../../chat/theme/chat_theme.dart';
import '../../../friends/bloc/friends_bloc.dart';
import '../../../friends/view/friends_screen.dart';
import '../../../friends/view/friend_requests_screen.dart';
import '../../../friends/view/widgets/friend_presence_avatar.dart';
import '../profile_route.dart';

class FriendsCollapsibleCard extends StatefulWidget {
  final bool isSelf;
  final bool isDark;

  const FriendsCollapsibleCard({
    super.key,
    required this.isSelf,
    required this.isDark,
  });

  @override
  State<FriendsCollapsibleCard> createState() => _FriendsCollapsibleCardState();
}

class _FriendsCollapsibleCardState extends State<FriendsCollapsibleCard> {
  bool _isExpanded = false;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _showSearchBar = false;
        _searchController.clear();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsBloc, FriendsState>(
      builder: (context, state) {
        List<Map<String, dynamic>> friends = [];
        int pendingRequestsCount = 0;

        if (state is FriendsLoaded) {
          final authState = context.read<AuthBloc>().state;
          final myUid = authState is Authenticated ? authState.uid : null;
          final myEmail = authState is Authenticated ? authState.email : null;
          final normalizedEmail = myEmail?.trim().toLowerCase();

          friends = state.friends.where((f) {
            final fUid = (f['uid'] ?? '').toString().trim();
            final fEmail = (f['email'] ?? '').toString().trim().toLowerCase();
            if (myUid != null && fUid.isNotEmpty && fUid == myUid.trim()) return false;
            if (normalizedEmail != null && fEmail.isNotEmpty && fEmail == normalizedEmail) return false;
            return true;
          }).toList();
          pendingRequestsCount = state.incomingRequests.length;
        }

        final query = _searchController.text.trim().toLowerCase();
        final filteredFriends = query.isEmpty
            ? friends
            : friends.where((f) {
                final name = f['displayName']?.toString().toLowerCase() ?? '';
                final email = f['email']?.toString().toLowerCase() ?? '';
                return name.contains(query) || email.contains(query);
              }).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark ? ChatTheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark ? ChatTheme.divider : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Tile (Tappable to Expand / Contract)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _toggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: InkColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: InkColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Friends',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: InkColors.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${friends.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: InkColors.accent,
                          ),
                        ),
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            _showSearchBar
                                ? Icons.search_off_rounded
                                : Icons.search_rounded,
                            size: 20,
                            color: _showSearchBar
                                ? InkColors.accent
                                : (widget.isDark
                                    ? ChatTheme.textSecondary
                                    : Colors.grey.shade600),
                          ),
                          tooltip: _showSearchBar ? 'Hide search' : 'Search friends',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          splashRadius: 18,
                          onPressed: () {
                            setState(() {
                              _showSearchBar = !_showSearchBar;
                              if (!_showSearchBar) {
                                _searchController.clear();
                              }
                            });
                          },
                        ),
                      ],
                      const Spacer(),

                      // Collapsed Preview Avatars
                      if (!_isExpanded && friends.isNotEmpty) ...[
                        SizedBox(
                          height: 28,
                          width: (friends.length > 3 ? 4 : friends.length) * 20.0 + 10,
                          child: Stack(
                            children: List.generate(
                              friends.length > 3 ? 3 : friends.length,
                              (idx) {
                                final f = friends[idx];
                                final photo = f['photoURL']?.toString();
                                return Positioned(
                                  left: idx * 18.0,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: widget.isDark ? ChatTheme.surfaceElevated : Colors.grey.shade300,
                                    backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                                    child: photo == null || photo.isEmpty
                                        ? const Icon(Icons.person, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Add friend button when expanded (accessible even with search hidden)
                      if (_isExpanded && widget.isSelf) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 20,
                            color: InkColors.accent,
                          ),
                          tooltip: 'Add Friend',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          splashRadius: 18,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FriendsScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Expand / Collapse Chevron
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: widget.isDark ? ChatTheme.textSecondary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Contractable Content
              if (_isExpanded) ...[
                Divider(
                  height: 1,
                  color: widget.isDark ? ChatTheme.divider : Colors.grey.shade200,
                ),

                // Pending Requests Banner (if any)
                if (pendingRequestsCount > 0 && widget.isSelf) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: InkColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_unread_outlined, size: 18, color: InkColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$pendingRequestsCount pending friend requests',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
                              );
                            },
                            child: const Text('View', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Search Bar (Only shown when toggled via the search icon)
                if (_showSearchBar) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search friends...',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: widget.isDark ? ChatTheme.surfaceElevated : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],

                // Friends List - Starts immediately with zero extra space
                if (filteredFriends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Text(
                      friends.isEmpty
                          ? 'No friends yet. Add friends using the button above!'
                          : 'No matching friends found.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < filteredFriends.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: widget.isDark ? ChatTheme.divider : Colors.grey.shade200,
                            ),
                          _buildFriendTile(context, filteredFriends[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friend) {
    final uid = friend['uid']?.toString() ?? '';
    final name = friend['displayName']?.toString() ?? 'User';
    final photo = friend['photoURL']?.toString();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SizedBox(
        width: 40,
        height: 40,
        child: FriendPresenceAvatar(
          userId: uid,
          displayName: name,
          photoUrl: photo,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        friend['email']?.toString() ?? '',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick "Message" Button -> Opens ChatThreadScreen
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: ChatTheme.accent,
              size: 20,
            ),
            tooltip: 'Send Message',
            onPressed: () {
              final conv = ChatConversationModel(
                id: uid,
                name: name,
                avatarUrl: photo,
                isGroup: false,
              );
              Navigator.push(
                context,
                buildChatThreadRoute(context, conversation: conv),
              );
            },
          ),
          // Profile link
          IconButton(
            icon: const Icon(Icons.person_outline, size: 20, color: Colors.grey),
            tooltip: 'View Profile',
            onPressed: () {
              Navigator.push(context, buildProfileRoute(context, userId: uid));
            },
          ),
        ],
      ),
    );
  }
}
