import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/app_snackbar.dart';
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
import '../../dashboard/view/board_edit_requests_screen.dart';
import '../../workspaces/bloc/workspace_bloc.dart';
import '../../workspaces/view/workspace_detail_route.dart';
import '../../workspaces/view/workspaces_screen.dart';
import '../bloc/notifications_bloc.dart';

enum _NotificationFilter {
  all('All'),
  requests('Requests'),
  boards('Boards'),
  workspace('Workspace'),
  friends('Friends');

  const _NotificationFilter(this.label);

  final String label;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;
  String? _pendingWorkspaceInviteId;

  void _decideWorkspaceInvite(
    BuildContext context, {
    required String inviteId,
    required String notificationId,
    required String status,
  }) {
    if (inviteId.isEmpty || _pendingWorkspaceInviteId != null) return;
    final notificationsBloc = context.read<NotificationsBloc>();
    final workspaceBloc = context.read<WorkspaceBloc>();
    if (notificationId.isNotEmpty) {
      notificationsBloc.markNotificationRead(notificationId);
    }
    setState(() {
      _pendingWorkspaceInviteId = inviteId;
    });

    void complete(bool success, String? error) {
      if (!mounted) return;
      setState(() {
        _pendingWorkspaceInviteId = null;
      });
      if (!success) {
        AppSnackBar.showError(
          context,
          error ?? 'Could not update the workspace invite.',
        );
        return;
      }
      // Resolve the inbox only after the workspace action has succeeded. On a
      // failure the notification stays pending and both buttons remain.
      notificationsBloc.add(
        NotificationWorkspaceInviteResolved(inviteId: inviteId, status: status),
      );
      AppSnackBar.showSuccess(
        context,
        status == 'accepted' ? 'Invite accepted.' : 'Invite declined.',
      );
    }

    workspaceBloc.add(
      status == 'accepted'
          ? AcceptWorkspaceInviteRequested(inviteId, onCompleted: complete)
          : RejectWorkspaceInviteRequested(inviteId, onCompleted: complete),
    );
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    return switch (_filter) {
      _NotificationFilter.all => true,
      _NotificationFilter.requests => type.contains('request'),
      _NotificationFilter.boards =>
        type.startsWith('board_') && !type.contains('request'),
      _NotificationFilter.workspace => type.startsWith('workspace_'),
      _NotificationFilter.friends => type.startsWith('friend_'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BoardInvitationsBloc, BoardInvitationsState>(
      listener: (context, state) {
        if (state is! BoardInvitationsLoaded) return;
        if (state.message != null) {
          if (state.isError) {
            AppSnackBar.showError(context, state.message!);
          } else {
            AppSnackBar.showSuccess(context, state.message!);
          }
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
              body: Center(
                child: CircularProgressIndicator(color: tokens.accent),
              ),
            );
          }

          if (state is NotificationsLoading) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: tokens.accent),
              ),
            );
          }

          if (state is NotificationsError) {
            return Scaffold(
              backgroundColor: tokens.paper,
              appBar: AppBar(
                backgroundColor: tokens.paper,
                title: Text('Notifications', style: InkType.title(tokens.ink)),
              ),
              body: Center(
                child: Text(
                  state.message,
                  style: InkType.body(tokens.inkMuted),
                ),
              ),
            );
          }

          if (state is! NotificationsLoaded) {
            return const Scaffold(body: SizedBox.shrink());
          }

          final unreadCount = state.notifications
              .where((item) => item['isRead'] != true)
              .length;
          final filtered = state.notifications.where(_matchesFilter).toList();

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
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterBar(tokens),
                Expanded(
                  child: state.notifications.isEmpty
                      ? const EmptyState(
                          icon: LucideIcons.bell,
                          text: 'No notifications yet.',
                        )
                      : filtered.isEmpty
                      ? EmptyState(
                          icon: LucideIcons.bell,
                          text:
                              'No ${_filter.label.toLowerCase()} notifications.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: InkSpacing.s16,
                            vertical: InkSpacing.s12,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: InkSpacing.s12 - 2),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final senderName =
                                item['senderName']?.toString() ?? 'InkLink';
                            final senderPic = item['senderPic']?.toString();
                            final title =
                                item['title']?.toString() ?? 'Notification';
                            final body = item['body']?.toString() ?? '';
                            final type = item['type']?.toString() ?? 'general';
                            final notificationId = item['id']?.toString() ?? '';
                            final status = item['status']?.toString() ?? 'info';
                            final unread = item['isRead'] != true;
                            final isActionablePending =
                                (type == 'board_invite' ||
                                    type == 'friend_request' ||
                                    type == 'workspace_invite' ||
                                    type == 'board_access_request' ||
                                    type == 'board_edit_request') &&
                                status == 'pending';
                            final workspaceInviteId =
                                item['extraData']?['inviteId']?.toString() ??
                                item['targetId']?.toString() ??
                                item['id']?.toString() ??
                                '';
                            final workspaceInvitePending =
                                type == 'workspace_invite' &&
                                _pendingWorkspaceInviteId == workspaceInviteId;

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

                                if (type == 'board_edit_request' ||
                                    (type == 'board_access_request' &&
                                        item['extraData']?['requestType'] ==
                                            'edit')) {
                                  final boardId =
                                      item['extraData']?['boardId']
                                          ?.toString() ??
                                      item['targetId']?.toString() ??
                                      '';
                                  final boardTitle =
                                      item['extraData']?['boardTitle']
                                          ?.toString() ??
                                      'Board';
                                  if (boardId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BoardEditRequestsScreen(
                                          boardId: boardId,
                                          boardTitle: boardTitle,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                if (type == 'board_access_request' ||
                                    type == 'board_access_accepted' ||
                                    type == 'board_edit_accepted') {
                                  final boardId =
                                      item['extraData']?['boardId']
                                          ?.toString() ??
                                      item['targetId']?.toString() ??
                                      '';
                                  if (boardId.isNotEmpty) {
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
                                }

                                if (type == 'board_invite' ||
                                    type == 'board_invite_accepted') {
                                  final boardId =
                                      item['extraData']?['boardId']
                                          ?.toString() ??
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
                                        value: context
                                            .read<BoardInvitationsBloc>(),
                                        child: const BoardInvitesScreen(),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (type == 'friend_request_accepted') {
                                  final profileUserId =
                                      item['fromUid']?.toString() ??
                                      item['extraData']?['fromUid']
                                          ?.toString() ??
                                      item['extraData']?['targetUid']
                                          ?.toString() ??
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
                                      builder: (_) =>
                                          const FriendRequestsScreen(),
                                    ),
                                  );
                                  return;
                                }

                                if (type == 'workspace_invite' ||
                                    type == 'workspace_invite_accepted') {
                                  final workspaceId =
                                      item['extraData']?['workspaceId']
                                          ?.toString() ??
                                      item['targetId']?.toString() ??
                                      '';

                                  final isAcceptedInvite =
                                      status == 'accepted' ||
                                      type == 'workspace_invite_accepted';

                                  if (isAcceptedInvite &&
                                      workspaceId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      buildWorkspaceDetailRoute(
                                        context,
                                        workspaceId,
                                      ),
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
                                padding: const EdgeInsets.all(
                                  InkSpacing.s16 - 2,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (unread) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(
                                          top: 6,
                                          right: InkSpacing.s8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ] else
                                      const SizedBox(width: 6 + InkSpacing.s8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              InkAvatar(
                                                imageUrl: senderPic,
                                                initials: inkInitialsFor(
                                                  senderName,
                                                ),
                                                id:
                                                    item['fromUid']
                                                        ?.toString() ??
                                                    senderName,
                                                size: 40,
                                              ),
                                              const SizedBox(
                                                width: InkSpacing.s12,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      senderName,
                                                      style: InkType.bodyStrong(
                                                        tokens.ink,
                                                      ),
                                                    ),
                                                    Text(
                                                      timeLabel,
                                                      style: InkType.caption(
                                                        tokens.inkMuted,
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
                                                              ? tokens.pending
                                                              : tokens.accent)
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  unread
                                                      ? LucideIcons.mailWarning
                                                      : _iconForType(type),
                                                  size: 16,
                                                  color: unread
                                                      ? tokens.pending
                                                      : tokens.accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: InkSpacing.s12,
                                          ),
                                          Text(
                                            title,
                                            style: InkType.bodyStrong(
                                              tokens.ink,
                                            ),
                                          ),
                                          const SizedBox(height: InkSpacing.s4),
                                          Text(
                                            body,
                                            style: InkType.body(
                                              tokens.inkSecondary,
                                            ).copyWith(height: 1.35),
                                          ),
                                          const SizedBox(
                                            height: InkSpacing.s12,
                                          ),
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
                                                        item['targetId']
                                                            ?.toString() ??
                                                        item['id']
                                                            ?.toString() ??
                                                        '';
                                                    final boardId =
                                                        item['extraData']?['boardId']
                                                            ?.toString() ??
                                                        item['targetId']
                                                            ?.toString() ??
                                                        '';
                                                    if (inviteId.isEmpty ||
                                                        boardId.isEmpty) {
                                                      return;
                                                    }
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .markNotificationRead(
                                                          notificationId,
                                                        );
                                                    context
                                                        .read<
                                                          BoardInvitationsBloc
                                                        >()
                                                        .add(
                                                          BoardInvitationAcceptRequested(
                                                            inviteId,
                                                            boardId: boardId,
                                                          ),
                                                        );
                                                  },
                                                ),
                                                const SizedBox(
                                                  width: InkSpacing.s8,
                                                ),
                                                _actionButton(
                                                  icon: LucideIcons.x,
                                                  color: tokens.danger,
                                                  onTap: () {
                                                    final inviteId =
                                                        item['extraData']?['inviteId']
                                                            ?.toString() ??
                                                        item['targetId']
                                                            ?.toString() ??
                                                        item['id']
                                                            ?.toString() ??
                                                        '';
                                                    if (inviteId.isEmpty) {
                                                      return;
                                                    }
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .markNotificationRead(
                                                          notificationId,
                                                        );
                                                    context
                                                        .read<
                                                          BoardInvitationsBloc
                                                        >()
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
                                                        item['targetId']
                                                            ?.toString() ??
                                                        item['id']
                                                            ?.toString() ??
                                                        '';
                                                    final senderUid =
                                                        item['fromUid']
                                                            ?.toString() ??
                                                        '';
                                                    if (requestId.isEmpty) {
                                                      return;
                                                    }
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .markNotificationRead(
                                                          notificationId,
                                                        );
                                                    context.read<FriendsBloc>().add(
                                                      AcceptFriendRequestRequested(
                                                        requestId,
                                                        senderUid,
                                                      ),
                                                    );
                                                    AppSnackBar.showSuccess(
                                                      context,
                                                      'Friend request accepted!',
                                                    );
                                                  },
                                                ),
                                                const SizedBox(
                                                  width: InkSpacing.s8,
                                                ),
                                                _actionButton(
                                                  icon: LucideIcons.x,
                                                  color: tokens.danger,
                                                  onTap: () {
                                                    final requestId =
                                                        item['extraData']?['requestId']
                                                            ?.toString() ??
                                                        item['targetId']
                                                            ?.toString() ??
                                                        item['id']
                                                            ?.toString() ??
                                                        '';
                                                    if (requestId.isEmpty) {
                                                      return;
                                                    }
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .markNotificationRead(
                                                          notificationId,
                                                        );
                                                    context.read<FriendsBloc>().add(
                                                      DeclineFriendRequestRequested(
                                                        requestId,
                                                      ),
                                                    );
                                                    AppSnackBar.showMessage(
                                                      context,
                                                      'Friend request declined.',
                                                    );
                                                  },
                                                ),
                                              ] else if (isActionablePending &&
                                                  type ==
                                                      'workspace_invite') ...[
                                                if (workspaceInvitePending)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                tokens.accent,
                                                          ),
                                                    ),
                                                  )
                                                else ...[
                                                  _actionButton(
                                                    icon: LucideIcons.check,
                                                    color: tokens.success,
                                                    onTap: () =>
                                                        _decideWorkspaceInvite(
                                                          context,
                                                          inviteId:
                                                              workspaceInviteId,
                                                          notificationId:
                                                              notificationId,
                                                          status: 'accepted',
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    width: InkSpacing.s8,
                                                  ),
                                                  _actionButton(
                                                    icon: LucideIcons.x,
                                                    color: tokens.danger,
                                                    onTap: () =>
                                                        _decideWorkspaceInvite(
                                                          context,
                                                          inviteId:
                                                              workspaceInviteId,
                                                          notificationId:
                                                              notificationId,
                                                          status: 'declined',
                                                        ),
                                                  ),
                                                ],
                                              ] else if (isActionablePending &&
                                                  (type ==
                                                          'board_access_request' ||
                                                      type ==
                                                          'board_edit_request')) ...[
                                                _actionButton(
                                                  icon: LucideIcons.check,
                                                  color: tokens.success,
                                                  onTap: () {
                                                    final boardId =
                                                        item['extraData']?['boardId']
                                                            ?.toString() ??
                                                        item['targetId']
                                                            ?.toString() ??
                                                        '';
                                                    final requesterUid =
                                                        item['extraData']?['requesterUid']
                                                            ?.toString() ??
                                                        item['fromUid']
                                                            ?.toString() ??
                                                        '';
                                                    final requestType =
                                                        item['extraData']?['requestType']
                                                            ?.toString() ??
                                                        (type ==
                                                                'board_edit_request'
                                                            ? 'edit'
                                                            : 'join');
                                                    if (boardId.isEmpty ||
                                                        requesterUid.isEmpty) {
                                                      return;
                                                    }
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .markNotificationRead(
                                                          notificationId,
                                                        );
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .add(
                                                          NotificationRespondToAccessRequest(
                                                            notificationId:
                                                                notificationId,
                                                            boardId: boardId,
                                                            requesterUid:
                                                                requesterUid,
                                                            action: 'accept',
                                                            requestType:
                                                                requestType,
                                                          ),
                                                        );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          requestType == 'edit'
                                                              ? 'Edit access approved for $senderName.'
                                                              : 'Join request approved for $senderName.',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(
                                                  width: InkSpacing.s8,
                                                ),
                                                _actionButton(
                                                  icon: LucideIcons.x,
                                                  color: tokens.danger,
                                                  onTap: () {
                                                    final boardId =
                                                        item['extraData']?['boardId']
                                                            ?.toString() ??
                                                        item['targetId']
                                                            ?.toString() ??
                                                        '';
                                                    final requesterUid =
                                                        item['extraData']?['requesterUid']
                                                            ?.toString() ??
                                                        item['fromUid']
                                                            ?.toString() ??
                                                        '';
                                                    final requestType =
                                                        item['extraData']?['requestType']
                                                            ?.toString() ??
                                                        (type ==
                                                                'board_edit_request'
                                                            ? 'edit'
                                                            : 'join');
                                                    if (boardId.isEmpty ||
                                                        requesterUid.isEmpty) {
                                                      return;
                                                    }
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .markNotificationRead(
                                                          notificationId,
                                                        );
                                                    context
                                                        .read<
                                                          NotificationsBloc
                                                        >()
                                                        .add(
                                                          NotificationRespondToAccessRequest(
                                                            notificationId:
                                                                notificationId,
                                                            boardId: boardId,
                                                            requesterUid:
                                                                requesterUid,
                                                            action: 'decline',
                                                            requestType:
                                                                requestType,
                                                          ),
                                                        );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Request declined.',
                                                        ),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(InkTokens tokens) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
        children: [
          for (final filter in _NotificationFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
                showCheckmark: false,
                labelStyle: InkType.caption(
                  _filter == filter ? tokens.accentText : tokens.inkSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
                selectedColor: tokens.accent.withValues(alpha: 0.14),
                backgroundColor: tokens.field,
                side: BorderSide(
                  color: _filter == filter
                      ? tokens.accent.withValues(alpha: 0.35)
                      : Colors.transparent,
                ),
              ),
            ),
        ],
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
      case 'board_invite_accepted':
        return LucideIcons.penLine;
      case 'board_access_request':
      case 'board_access_accepted':
        return LucideIcons.userPlus;
      case 'board_edit_request':
      case 'board_edit_accepted':
        return LucideIcons.pencil;
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
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s8 + 2,
        vertical: 5,
      ),
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
          Text(
            status.toUpperCase(),
            style: InkType.caption(color).copyWith(fontWeight: FontWeight.w700),
          ),
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
