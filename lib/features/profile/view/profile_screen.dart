import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/features/profile/bloc/profile_bloc.dart';
import 'package:inklink/features/profile/view/widgets/edit_profile_sheet.dart';

import '../../../core/constants/app_colors.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/view/blocked_users_screen.dart';
import '../../friends/view/friend_requests_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Invalid User ID')));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoaded && state.isSelf) {
                return PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: context.read<ProfileBloc>(),
                          child: EditProfileSheet(userData: state.userData),
                        ),
                      );
                      return;
                    }

                    if (value == 'requests') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FriendRequestsScreen(),
                        ),
                      );
                      return;
                    }

                    if (value == 'blocked') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BlockedUsersScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                    PopupMenuItem(
                      value: 'requests',
                      child: Text('View friend requests'),
                    ),
                    PopupMenuItem(
                      value: 'blocked',
                      child: Text('View blocked users'),
                    ),
                  ],
                );
              }

              if (state is ProfileLoaded && !state.isSelf) {
                return PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onSelected: (value) async {
                    if (value == 'unfriend') {
                      await _confirmUnfriendUser(context);
                    } else if (value == 'block') {
                      await _confirmBlockUser(context);
                    } else if (value == 'unblock') {
                      await _confirmUnblockUser(context);
                    } else if (value == 'report') {
                      await _reportUser(context);
                    }
                  },
                  itemBuilder: (context) => [
                    if (state.isFriend)
                      const PopupMenuItem(
                        value: 'unfriend',
                        child: Text('Remove friend'),
                      ),
                    if (!state.isBlocked)
                      const PopupMenuItem(
                        value: 'block',
                        child: Text('Block user'),
                      ),
                    if (state.isBlocked)
                      const PopupMenuItem(
                        value: 'unblock',
                        child: Text('Unblock user'),
                      ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Report user'),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProfileError) {
            return Center(child: Text(state.message));
          }

          if (state is ProfilePhotoUploading) {
            final user = state.userData;
            return Column(
              children: [
                _buildHeader(user, isDark),
                const SizedBox(height: 24),
                _buildBioSection(user, isDark),
                const Spacer(),
                const SizedBox(height: 40),
              ],
            );
          }

          if (state is ProfileLoaded) {
            final user = state.userData;
            return Column(
              children: [
                _buildHeader(user, isDark),
                const SizedBox(height: 12),
                _buildProfileStats(state, isDark),
                const SizedBox(height: 12),
                _buildJoinDate(_asDateTime(user['createdAt']), isDark),
                if (state.isBlocked) const SizedBox(height: 12),
                if (state.isBlocked) _buildBlockedBanner(isDark),
                const SizedBox(height: 12),
                _buildBioSection(user, isDark),
                const Spacer(),
                _buildActionButtons(context, state, isDark),
                const SizedBox(height: 40),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> user, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E), Colors.black]
              : [AppColors.primary.withOpacity(0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : Colors.grey.shade200,
              backgroundImage:
                  (user['photoURL'] != null &&
                      user['photoURL'].toString().isNotEmpty)
                  ? NetworkImage(user['photoURL'])
                  : null,
              child:
                  (user['photoURL'] == null ||
                      user['photoURL'].toString().isEmpty)
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user['displayName'] ?? 'User',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text(
            user['email'] ?? '',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatJoinDate(DateTime? createdAt) {
    if (createdAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return 'Joined ${createdAt.year}';
    } else if (difference.inDays > 30) {
      return 'Joined ${difference.inDays ~/ 30}mo ago';
    } else if (difference.inDays > 0) {
      return 'Joined ${difference.inDays}d ago';
    } else {
      return 'Joined today';
    }
  }

  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return 'Offline';

    final now = DateTime.now();
    final difference = now.difference(lastActive);
    if (difference.inSeconds < 60) {
      return 'Active just now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return 'Active ${difference.inDays}d ago';
    } else {
      return 'Last active ${difference.inDays}d ago';
    }
  }

  Widget _buildProfileStats(ProfileLoaded state, bool isDark) {
    if (state.isSelf) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(state.boardCount.toString(), 'Boards', isDark),
          _buildStatItem(state.friendCount.toString(), 'Friends', isDark),
          _buildStatItem(
            state.isOnline ? '🟢 Online' : _formatLastActive(state.lastActive),
            'Status',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    bool isDark, {
    double height = 52,
  }) {
    return Expanded(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinDate(DateTime? createdAt, bool isDark) {
    if (createdAt == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        '⏰ ${_formatJoinDate(createdAt)}',
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildBioSection(Map<String, dynamic> user, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bio',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              user['bio'] ??
                  'No bio yet. This creator is busy bringing ideas to life!',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3F2A2A) : const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFFB77979) : const Color(0xFFEFA6A6),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.block, size: 16, color: Color(0xFFD64545)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You blocked this user. Unblock from the menu to collaborate again.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ProfileLoaded state,
    bool isDark,
  ) {
    if (state.isSelf) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () async {
          if (state.isBlocked) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'User is blocked. Use the top menu to unblock.',
                  ),
                ),
              );
            }
            return;
          }

          if (state.isFriend) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messaging is coming soon.')),
              );
            }
            return;
          }

          try {
            await context.read<FriendsBloc>().sendFriendRequestToUser(userId);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Request Sent!')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: state.isBlocked
                  ? [const Color(0xFF6B7280), const Color(0xFF374151)]
                  : state.isFriend
                  ? [const Color(0xFFD64545), const Color(0xFF8E2DE2)]
                  : [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                state.isBlocked
                    ? Icons.block
                    : state.isFriend
                    ? Icons.chat_rounded
                    : Icons.person_add_alt_1,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                state.isBlocked
                    ? 'Blocked'
                    : state.isFriend
                    ? 'Message'
                    : 'Collaborate',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlockUser(BuildContext context) async {
    final friendsBloc = context.read<FriendsBloc>();
    final profileBloc = context.read<ProfileBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final shouldBlock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block user?'),
        content: const Text(
          'They will be removed from your friends and requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (shouldBlock != true) return;

    try {
      await friendsBloc.blockUser(userId);
      profileBloc.add(LoadProfile(userId));
      messenger?.showSnackBar(const SnackBar(content: Text('User blocked')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmUnfriendUser(BuildContext context) async {
    final friendsBloc = context.read<FriendsBloc>();
    final profileBloc = context.read<ProfileBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final shouldUnfriend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove friend?'),
        content: const Text(
          'This will remove the connection from both accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldUnfriend != true) return;

    try {
      await friendsBloc.unfriendUser(userId);
      profileBloc.add(LoadProfile(userId));
      messenger?.showSnackBar(const SnackBar(content: Text('Friend removed')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmUnblockUser(BuildContext context) async {
    final friendsBloc = context.read<FriendsBloc>();
    final profileBloc = context.read<ProfileBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock user?'),
        content: const Text(
          'This will allow you to send requests and collaborate again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (shouldUnblock != true) return;

    try {
      await friendsBloc.unblockUser(userId);
      profileBloc.add(LoadProfile(userId));
      messenger?.showSnackBar(const SnackBar(content: Text('User unblocked')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reportUser(BuildContext context) async {
    final friendsBloc = context.read<FriendsBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report user'),
        content: TextField(
          controller: reasonController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Optional reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (reason == null) return;

    try {
      await friendsBloc.reportUser(userId, reason: reason);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Report submitted')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
