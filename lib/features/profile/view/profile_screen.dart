import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/features/profile/bloc/profile_bloc.dart';
import 'package:inklink/features/profile/view/widgets/edit_profile_sheet.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../../ui/widgets/status_chip.dart';
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

    final tokens = context.ink;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(LucideIcons.chevronLeft, color: tokens.ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              if (state is ProfileLoaded && state.isSelf) {
                return PopupMenuButton<String>(
                  icon: Icon(LucideIcons.ellipsis, color: tokens.ink),
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
                  itemBuilder: (context) => [
                    _menuItem('edit', LucideIcons.pen, 'Edit profile', tokens.ink),
                    _menuItem('requests', LucideIcons.userPlus, 'View friend requests', tokens.ink),
                    _menuItem('blocked', LucideIcons.ban, 'View blocked users', tokens.ink),
                  ],
                );
              }

              if (state is ProfileLoaded && !state.isSelf) {
                return PopupMenuButton<String>(
                  icon: Icon(LucideIcons.ellipsis, color: tokens.ink),
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
                      _menuItem('unfriend', LucideIcons.userX, 'Remove friend', tokens.danger),
                    if (!state.isBlocked)
                      _menuItem('block', LucideIcons.ban, 'Block user', tokens.danger),
                    if (state.isBlocked)
                      _menuItem('unblock', LucideIcons.ban, 'Unblock user', tokens.ink),
                    _menuItem('report', LucideIcons.triangleAlert, 'Report user', tokens.danger),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<FriendsBloc, FriendsState>(
        listener: (context, friendsState) {
          if (friendsState is FriendsError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(friendsState.message)));
          }
        },
        child: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return Center(child: CircularProgressIndicator(color: tokens.accent));
            }

            if (state is ProfileError) {
              return Center(child: Text(state.message, style: InkType.body(tokens.inkMuted)));
            }

            if (state is ProfilePhotoUploading) {
              final user = state.userData;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(context, user),
                    const SizedBox(height: InkSpacing.s24),
                    _buildBioSection(context, user),
                    const SizedBox(height: InkSpacing.s32),
                  ],
                ),
              );
            }

            if (state is ProfileLoaded) {
              final user = state.userData;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(context, user),
                    const SizedBox(height: InkSpacing.s12),
                    _buildProfileStats(context, state),
                    const SizedBox(height: InkSpacing.s12),
                    _buildJoinDate(context, _asDateTime(user['createdAt']), state.isSelf),
                    if (state.isBlocked) const SizedBox(height: InkSpacing.s12),
                    if (state.isBlocked) _buildBlockedBanner(context),
                    const SizedBox(height: InkSpacing.s12),
                    _buildBioSection(context, user),
                    const SizedBox(height: InkSpacing.s32),
                    _buildActionButtons(context, state),
                    const SizedBox(height: InkSpacing.s32 + 8),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: InkSpacing.s12 - 2),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> user) {
    final tokens = context.ink;
    final name = (user['displayName'] ?? 'User').toString();
    final photoUrl = user['photoURL']?.toString();

    return SizedBox(
      height: 180 + 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: const DeskBackground(),
          ),
          Positioned(
            top: 180 - 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                InkAvatar(
                  imageUrl: photoUrl,
                  initials: inkInitialsFor(name),
                  id: userId,
                  size: 96,
                  ring: true,
                ),
                const SizedBox(height: InkSpacing.s12),
                Text(name, style: InkType.headline(tokens.ink)),
                Text(
                  user['email'] ?? '',
                  style: InkType.body(tokens.inkSecondary),
                ),
              ],
            ),
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

  Widget _buildProfileStats(BuildContext context, ProfileLoaded state) {
    if (state.isSelf) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
      child: Row(
        children: [
          Expanded(child: _buildStatItem(context, state.boardCount.toString(), 'Boards')),
          const SizedBox(width: InkSpacing.s12),
          Expanded(child: _buildStatItem(context, state.friendCount.toString(), 'Friends')),
          const SizedBox(width: InkSpacing.s12),
          Expanded(
            child: _buildStatItem(
              context,
              null,
              'Status',
              statusOnline: state.isOnline,
              statusText: state.isOnline ? 'Online' : _formatLastActive(state.lastActive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String? value,
    String label, {
    bool? statusOnline,
    String? statusText,
  }) {
    final tokens = context.ink;
    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s8, vertical: InkSpacing.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value, style: InkType.title(tokens.ink), textAlign: TextAlign.center)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusOnline == true) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: tokens.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    statusText ?? '',
                    style: InkType.label(tokens.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: InkSpacing.s4),
          Text(label, style: InkType.caption(tokens.inkMuted)),
        ],
      ),
    );
  }

  Widget _buildJoinDate(BuildContext context, DateTime? createdAt, bool isSelf) {
    if (createdAt == null) return const SizedBox.shrink();
    final tokens = context.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(LucideIcons.calendar, size: 14, color: tokens.inkMuted),
          const SizedBox(width: 6),
          Text(_formatJoinDate(createdAt), style: InkType.caption(tokens.inkMuted)),
        ],
      ),
    );
  }

  Widget _buildBioSection(BuildContext context, Map<String, dynamic> user) {
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
      child: PaperCard(
        padding: const EdgeInsets.all(InkSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bio', style: InkType.label(tokens.inkMuted)),
            const SizedBox(height: InkSpacing.s8),
            Text(
              user['bio'] ??
                  'No bio yet. This creator is busy bringing ideas to life!',
              style: InkType.body(tokens.ink).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedBanner(BuildContext context) {
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16, vertical: InkSpacing.s8 + 2),
        decoration: BoxDecoration(
          color: tokens.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.ban, size: 16, color: tokens.danger),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Text(
                'You blocked this user. Unblock from the menu to collaborate again.',
                style: InkType.caption(tokens.danger).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ProfileLoaded state) {
    if (state.isSelf) return const SizedBox.shrink();
    final tokens = context.ink;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s24),
      child: BlocBuilder<FriendsBloc, FriendsState>(
        builder: (context, friendsState) {
          final loaded = friendsState is FriendsLoaded ? friendsState : null;
          final isFriendInFriendsState =
              loaded?.friends.any(
                (friend) => (friend['uid']?.toString() ?? '').trim() == userId,
              ) ??
              false;
          final effectiveIsFriend = state.isFriend || isFriendInFriendsState;

          Map<String, dynamic>? incomingForProfile;
          Map<String, dynamic>? outgoingForProfile;
          if (loaded != null) {
            for (final req in loaded.incomingRequests) {
              if ((req['fromUid']?.toString() ?? '') == userId) {
                incomingForProfile = req;
                break;
              }
            }
            for (final req in loaded.outgoingRequests) {
              if ((req['toUid']?.toString() ?? '') == userId) {
                outgoingForProfile = req;
                break;
              }
            }
          }

          final incomingRequestId = incomingForProfile?['id']?.toString() ?? '';
          final outgoingRequestId =
              outgoingForProfile?['requestId']?.toString() ??
              outgoingForProfile?['id']?.toString() ??
              '';

          final isAccepting =
              incomingRequestId.isNotEmpty &&
              (loaded?.acceptingRequestIds.contains(incomingRequestId) ??
                  false);
          final isDeclining =
              incomingRequestId.isNotEmpty &&
              (loaded?.decliningRequestIds.contains(incomingRequestId) ??
                  false);
          final isCanceling =
              outgoingRequestId.isNotEmpty &&
              (loaded?.cancelingRequestIds.contains(outgoingRequestId) ??
                  false);
          final isSending =
              loaded?.sendingRequestTargetUids.contains(userId) ?? false;

          if (!effectiveIsFriend && incomingForProfile != null) {
            return Row(
              children: [
                Expanded(
                  child: InkButton.primary(
                    label: isAccepting ? 'Accepting...' : 'Accept request',
                    icon: isAccepting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.check),
                    onPressed: (isAccepting || isDeclining)
                        ? null
                        : () {
                            context.read<FriendsBloc>().add(
                              AcceptFriendRequestRequested(
                                incomingRequestId,
                                userId,
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: InkSpacing.s8 + 2),
                Expanded(
                  child: InkButton.secondary(
                    label: 'Decline',
                    icon: isDeclining
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.ink),
                          )
                        : const Icon(LucideIcons.x),
                    onPressed: (isAccepting || isDeclining)
                        ? null
                        : () {
                            context.read<FriendsBloc>().add(
                              DeclineFriendRequestRequested(incomingRequestId),
                            );
                          },
                  ),
                ),
              ],
            );
          }

          if (!effectiveIsFriend && outgoingForProfile != null) {
            return Row(
              children: [
                Expanded(
                  child: InkButton.secondary(
                    label: isCanceling ? 'Canceling...' : 'Request pending',
                    onPressed: isCanceling
                        ? null
                        : () {
                            context.read<FriendsBloc>().add(
                              CancelFriendRequestRequested(
                                outgoingRequestId,
                                userId,
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: InkSpacing.s8 + 2),
                const StatusChip(status: InkStatus.pending),
              ],
            );
          }

          if (state.isBlocked) {
            return InkButton.secondary(
              label: 'Blocked',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User is blocked. Use the top menu to unblock.'),
                  ),
                );
              },
            );
          }

          return InkButton.primary(
            label: isSending ? 'Sending...' : (effectiveIsFriend ? 'Message' : 'Collaborate'),
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(effectiveIsFriend ? LucideIcons.messageCircle : LucideIcons.userPlus),
            onPressed: () {
              if (effectiveIsFriend) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messaging is coming soon.')),
                );
                return;
              }

              if (isSending) {
                return;
              }

              context.read<FriendsBloc>().add(
                SendFriendRequestRequested(userId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmBlockUser(BuildContext context) async {
    final friendsBloc = context.read<FriendsBloc>();
    final profileBloc = context.read<ProfileBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final shouldBlock = await showInkConfirmDialog(
      context,
      title: 'Block user?',
      message: 'They will be removed from your friends and requests.',
      confirmLabel: 'Block',
    );

    if (!shouldBlock) return;

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

    final shouldUnfriend = await showInkConfirmDialog(
      context,
      title: 'Remove friend?',
      message: 'This will remove the connection from both accounts.',
      confirmLabel: 'Remove',
    );

    if (!shouldUnfriend) return;

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

    final shouldUnblock = await showInkConfirmDialog(
      context,
      title: 'Unblock user?',
      message: 'This will allow you to send requests and collaborate again.',
      confirmLabel: 'Unblock',
      destructive: false,
    );

    if (!shouldUnblock) return;

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
      builder: (dialogContext) => InkDialog(
        title: 'Report user',
        content: InkTextField(
          controller: reasonController,
          maxLines: 5,
          hintText: 'Optional reason',
        ),
        actions: [
          InkButton.secondary(
            label: 'Cancel',
            expand: false,
            compact: true,
            onPressed: () => Navigator.pop(dialogContext, null),
          ),
          InkButton.primary(
            label: 'Submit',
            expand: false,
            compact: true,
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
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
