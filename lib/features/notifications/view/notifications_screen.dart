import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_initials.dart';
import '../../../ui/widgets/paper_card.dart';
import '../../canvas/view/canvas_route.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/view/friend_requests_screen.dart';
import '../../profile/view/profile_route.dart';
import '../../board_invitations/bloc/board_invitations_bloc.dart';
import '../../board_invitations/view/board_invites_screen.dart';
import '../../workspaces/bloc/workspace_bloc.dart';
import '../../workspaces/view/workspace_detail_route.dart';
import '../../workspaces/view/workspaces_screen.dart';
import '../bloc/notifications_bloc.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BoardInvitationsBloc, BoardInvitationsState>(
      listener: (context, state) {
        if (state is! BoardInvitationsLoaded) return;
        if (state.message != null) {
          final tokens = context.ink;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: state.isError
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.ban, size: 16, color: tokens.danger),
                        const SizedBox(width: InkSpacing.s8),
                        Flexible(child: Text(state.message!)),
                      ],
                    )
                  : Text(state.message!),
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
          final tokens = context.ink;

          if (state is NotificationsInitial) {
            context.read<NotificationsBloc>().add(
              const NotificationsLoadRequested(),
            );
            return Scaffold(
              body: Center(child: CircularProgressIndicator(color: tokens.accent)),
            );
          }

          if (state is NotificationsLoading) {
            return Scaffold(
              body: Center(child: CircularProgressIndicator(color: tokens.accent)),
            );
          }

          if (state is NotificationsError) {
            return Scaffold(
              backgroundColor: tokens.paper,
              appBar: AppBar(
                backgroundColor: tokens.paper,
                title: Text('Notifications', style: InkType.title(tokens.ink)),
              ),
              body: Center(child: Text(state.message, style: InkType.body(tokens.inkMuted))),
            );
          }

          if (state is! NotificationsLoaded) {
            return const Scaffold(body: SizedBox.shrink());
          }

          final unreadCount = state.notifications
              .where((item) => item['isRead'] != true)
              .length;

          return Scaffold(
            backgroundColor: tokens.paper,
            appBar: AppBar(
              backgroundColor: tokens.paper,
              title: Text('Notifications', style: InkType.title(tokens.ink)),
              actions: [
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () async {
                      await context
                          .read<NotificationsBloc>()
                          .markAllNotificationsRead();
                    },
                    child: Text(
                      'Mark all read',
                      style: InkType.bodyStrong(tokens.accentText),
                    ),
                  ),
                const SizedBox(width: InkSpacing.s8),
              ],
            ),
            body: state.notifications.isEmpty
                ? const EmptyState(
                    icon: LucideIcons.bell,
                    text: 'No notifications yet.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.s16,
                      vertical: InkSpacing.s12,
                    ),
                    itemCount: state.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: InkSpacing.s12 - 2),
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

                      final timestamp = _readTimestamp(item);
                      final timeLabel = _formatTimeLabel(timestamp);

                      return InkWell(
                        borderRadius: BorderRadius.circular(6),
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
                            return;
                          }

                          if (type == 'workspace_invite' ||
                              type == 'workspace_invite_accepted') {
                            final workspaceId =
                                item['extraData']?['workspaceId']?.toString() ??
                                item['targetId']?.toString() ??
                                '';

                            final isAcceptedInvite =
                                status == 'accepted' ||
                                type == 'workspace_invite_accepted';

                            if (isAcceptedInvite && workspaceId.isNotEmpty) {
                              Navigator.push(
                                context,
                                buildWorkspaceDetailRoute(context, workspaceId),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              buildWorkspaceInvitesRoute(context),
                            );
                            return;
                          }
                        },
                        child: PaperCard(
                          padding: const EdgeInsets.all(InkSpacing.s16 - 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (unread) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(top: 6, right: InkSpacing.s8),
                                  decoration: BoxDecoration(
                                    color: tokens.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ] else
                                const SizedBox(width: 6 + InkSpacing.s8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        InkAvatar(
                                          imageUrl: senderPic,
                                          initials: inkInitialsFor(senderName),
                                          id: item['fromUid']?.toString() ?? senderName,
                                          size: 40,
                                        ),
                                        const SizedBox(width: InkSpacing.s12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(senderName, style: InkType.bodyStrong(tokens.ink)),
                                              Text(timeLabel, style: InkType.caption(tokens.inkMuted)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: (unread ? tokens.pending : tokens.accent)
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            unread ? LucideIcons.mailWarning : _iconForType(type),
                                            size: 16,
                                            color: unread ? tokens.pending : tokens.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: InkSpacing.s12),
                                    Text(title, style: InkType.bodyStrong(tokens.ink)),
                                    const SizedBox(height: InkSpacing.s4),
                                    Text(
                                      body,
                                      style: InkType.body(tokens.inkSecondary).copyWith(height: 1.35),
                                    ),
                                    const SizedBox(height: InkSpacing.s12),
                                    Row(
                                      children: [
                                        _statusPill(tokens, status),
                                        const Spacer(),
                                        if (isActionablePending &&
                                            type == 'board_invite') ...[
                                          _actionButton(
                                            icon: LucideIcons.check,
                                            color: tokens.success,
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
                                          const SizedBox(width: InkSpacing.s8),
                                          _actionButton(
                                            icon: LucideIcons.x,
                                            color: tokens.danger,
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
                                            icon: LucideIcons.check,
                                            color: tokens.success,
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
                                          const SizedBox(width: InkSpacing.s8),
                                          _actionButton(
                                            icon: LucideIcons.x,
                                            color: tokens.danger,
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
                                        ] else if (isActionablePending &&
                                            type == 'workspace_invite') ...[
                                          _actionButton(
                                            icon: LucideIcons.check,
                                            color: tokens.success,
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
                                                  .read<WorkspaceBloc>()
                                                  .add(
                                                    AcceptWorkspaceInviteRequested(
                                                      inviteId,
                                                    ),
                                                  );
                                            },
                                          ),
                                          const SizedBox(width: InkSpacing.s8),
                                          _actionButton(
                                            icon: LucideIcons.x,
                                            color: tokens.danger,
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
                                                  .read<WorkspaceBloc>()
                                                  .add(
                                                    RejectWorkspaceInviteRequested(
                                                      inviteId,
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
                            ],
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
        return LucideIcons.users;
      case 'board_invite':
        return LucideIcons.penLine;
      default:
        return LucideIcons.bell;
    }
  }

  Widget _statusPill(InkTokens tokens, String status) {
    final Color color;
    switch (status) {
      case 'accepted':
        color = tokens.success;
        break;
      case 'declined':
      case 'expired':
        color = tokens.danger;
        break;
      case 'pending':
        color = tokens.pending;
        break;
      default:
        color = tokens.accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s8 + 2, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status.toUpperCase(), style: InkType.caption(color).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
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
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
