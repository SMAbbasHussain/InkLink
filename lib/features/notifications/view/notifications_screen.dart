import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../canvas/view/canvas_route.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/bloc/friends_event.dart';
import '../../friends/view/friend_requests_screen.dart';
import '../../profile/view/profile_route.dart';
import '../../board_invitations/bloc/board_invitations_bloc.dart';
import '../../board_invitations/view/board_invites_screen.dart';
import '../bloc/notifications_bloc.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BoardInvitationsBloc, BoardInvitationsState>(
      listener: (context, state) {
        if (state is! BoardInvitationsLoaded) return;
        if (state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: state.isError ? Colors.red : null,
            ),
          );
        }

        if (state.openedBoardId != null && !state.isError) {
          Navigator.push(
            context,
            buildCanvasRoute(
              context,
              boardId: state.openedBoardId!,
              showTrayTipsOnEntry: true,
            ),
          );
        }
      },
      child: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsInitial) {
            context.read<NotificationsBloc>().add(
              const NotificationsLoadRequested(),
            );
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is NotificationsLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is NotificationsError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Notifications')),
              body: Center(child: Text(state.message)),
            );
          }

          if (state is! NotificationsLoaded) {
            return const Scaffold(body: SizedBox.shrink());
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final unreadCount = state.notifications
              .where((item) => item['isRead'] != true)
              .length;

          return Scaffold(
            backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
            appBar: AppBar(
              title: const Text('Notifications'),
              actions: [
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () async {
                      await context
                          .read<NotificationsBloc>()
                          .markAllNotificationsRead();
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark all read'),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: state.notifications.isEmpty
                ? Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: state.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = state.notifications[index];
                      final senderName =
                          item['senderName']?.toString() ?? 'InkLink';
                      final senderPic = item['senderPic']?.toString();
                      final title = item['title']?.toString() ?? 'Notification';
                      final body = item['body']?.toString() ?? '';
                      final type = item['type']?.toString() ?? 'general';
                      final notificationId = item['id']?.toString() ?? '';
                      final status = item['status']?.toString() ?? 'info';
                      final unread = item['isRead'] != true;
                      final isActionablePending =
                          (type == 'board_invite' ||
                              type == 'friend_request') &&
                          status == 'pending';

                      final primaryLine = body;

                      final timestamp = _readTimestamp(item);
                      final timeLabel = _formatTimeLabel(timestamp);
                      final statusColor = _statusColor(context, status);
                      final iconData = _iconForType(type);
                      final cardColor = isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight;
                      final cardBorder = unread
                          ? AppColors.primary.withOpacity(isDark ? 0.35 : 0.22)
                          : (isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06));
                      final textPrimary = isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight;
                      final textSecondary = isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight;

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          if (notificationId.isNotEmpty) {
                            context
                                .read<NotificationsBloc>()
                                .markNotificationRead(notificationId);
                          }

                          if (type == 'board_invite' ||
                              type == 'board_invite_accepted') {
                            final boardId =
                                item['extraData']?['boardId']?.toString() ??
                                item['targetId']?.toString() ??
                                '';

                            final isAcceptedInvite =
                                status == 'accepted' ||
                                type == 'board_invite_accepted';

                            if (isAcceptedInvite && boardId.isNotEmpty) {
                              Navigator.push(
                                context,
                                buildCanvasRoute(
                                  context,
                                  boardId: boardId,
                                  showTrayTipsOnEntry: true,
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<BoardInvitationsBloc>(),
                                  child: const BoardInvitesScreen(),
                                ),
                              ),
                            );
                            return;
                          }

                          if (type == 'friend_request_accepted') {
                            final profileUserId =
                                item['fromUid']?.toString() ??
                                item['extraData']?['fromUid']?.toString() ??
                                item['extraData']?['targetUid']?.toString() ??
                                '';

                            if (profileUserId.isNotEmpty) {
                              Navigator.push(
                                context,
                                buildProfileRoute(
                                  context,
                                  userId: profileUserId,
                                ),
                              );
                              return;
                            }
                          }

                          if (type == 'friend_request') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FriendRequestsScreen(),
                              ),
                            );
                          }
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.primary
                                          .withOpacity(isDark ? 0.3 : 0.15),
                                      backgroundImage:
                                          senderPic != null &&
                                              senderPic.isNotEmpty
                                          ? NetworkImage(senderPic)
                                          : null,
                                      child:
                                          senderPic == null || senderPic.isEmpty
                                          ? Text(
                                              senderName.isEmpty
                                                  ? 'I'
                                                  : senderName[0].toUpperCase(),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            senderName,
                                            style: TextStyle(
                                              fontWeight: unread
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              fontSize: 15,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            timeLabel,
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color:
                                            (unread
                                                    ? Colors.orange
                                                    : AppColors.primary)
                                                .withOpacity(
                                                  isDark ? 0.25 : 0.12,
                                                ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        unread
                                            ? Icons.mark_email_unread_rounded
                                            : iconData,
                                        size: 16,
                                        color: unread
                                            ? Colors.orange
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  primaryLine,
                                  style: TextStyle(
                                    height: 1.35,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isActionablePending &&
                                        type == 'board_invite') ...[
                                      _actionButton(
                                        icon: Icons.check_circle,
                                        color: Colors.green,
                                        onTap: () {
                                          final inviteId =
                                              item['extraData']?['inviteId']
                                                  ?.toString() ??
                                              item['targetId']?.toString() ??
                                              item['id']?.toString() ??
                                              '';
                                          final boardId =
                                              item['extraData']?['boardId']
                                                  ?.toString() ??
                                              item['targetId']?.toString() ??
                                              '';
                                          if (inviteId.isEmpty ||
                                              boardId.isEmpty) {
                                            return;
                                          }
                                          context
                                              .read<NotificationsBloc>()
                                              .markNotificationRead(
                                                notificationId,
                                              );
                                          context
                                              .read<BoardInvitationsBloc>()
                                              .add(
                                                BoardInvitationAcceptRequested(
                                                  inviteId,
                                                  boardId: boardId,
                                                ),
                                              );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _actionButton(
                                        icon: Icons.cancel,
                                        color: Colors.red,
                                        onTap: () {
                                          final inviteId =
                                              item['extraData']?['inviteId']
                                                  ?.toString() ??
                                              item['targetId']?.toString() ??
                                              item['id']?.toString() ??
                                              '';
                                          if (inviteId.isEmpty) {
                                            return;
                                          }
                                          context
                                              .read<NotificationsBloc>()
                                              .markNotificationRead(
                                                notificationId,
                                              );
                                          context
                                              .read<BoardInvitationsBloc>()
                                              .add(
                                                BoardInvitationDeclineRequested(
                                                  inviteId,
                                                ),
                                              );
                                        },
                                      ),
                                    ] else if (isActionablePending &&
                                        type == 'friend_request') ...[
                                      _actionButton(
                                        icon: Icons.check_circle,
                                        color: Colors.green,
                                        onTap: () {
                                          final requestId =
                                              item['extraData']?['requestId']
                                                  ?.toString() ??
                                              item['targetId']?.toString() ??
                                              item['id']?.toString() ??
                                              '';
                                          final senderUid =
                                              item['fromUid']?.toString() ?? '';
                                          if (requestId.isEmpty) {
                                            return;
                                          }
                                          context
                                              .read<NotificationsBloc>()
                                              .markNotificationRead(
                                                notificationId,
                                              );
                                          context.read<FriendsBloc>().add(
                                            AcceptFriendRequestRequested(
                                              requestId,
                                              senderUid,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _actionButton(
                                        icon: Icons.cancel,
                                        color: Colors.red,
                                        onTap: () {
                                          final requestId =
                                              item['extraData']?['requestId']
                                                  ?.toString() ??
                                              item['targetId']?.toString() ??
                                              item['id']?.toString() ??
                                              '';
                                          if (requestId.isEmpty) {
                                            return;
                                          }
                                          context
                                              .read<NotificationsBloc>()
                                              .markNotificationRead(
                                                notificationId,
                                              );
                                          context.read<FriendsBloc>().add(
                                            DeclineFriendRequestRequested(
                                              requestId,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  DateTime? _readTimestamp(Map<String, dynamic> item) {
    final raw = item['timestamp'];
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());

    // Supports Firestore Timestamp without importing cloud_firestore in UI.
    try {
      final millis = (raw as dynamic).millisecondsSinceEpoch;
      if (millis is int) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      if (millis is num) {
        return DateTime.fromMillisecondsSinceEpoch(millis.toInt());
      }
    } catch (_) {}

    final parsed = raw?.toString();
    if (parsed == null || parsed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(parsed);
  }

  String _formatTimeLabel(DateTime? timestamp) {
    if (timestamp == null) return 'Recently';

    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.isNegative) return 'Just now';

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final month = _monthLabel(timestamp.month);
    return '$month ${timestamp.day}, ${timestamp.year}';
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[(month - 1).clamp(0, 11)];
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'friend_request':
      case 'friend_request_accepted':
        return Icons.people_alt_rounded;
      case 'board_invite':
        return Icons.draw_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'declined':
      case 'expired':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
