import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../canvas/view/canvas_route.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/bloc/friends_event.dart';
import '../../friends/view/friend_requests_screen.dart';
import '../../invitations/bloc/invitations_bloc.dart';
import '../../invitations/view/board_invites_screen.dart';
import '../bloc/notifications_bloc.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvitationsBloc, InvitationsState>(
      listener: (context, state) {
        if (state is! InvitationsLoaded) return;
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

          return Scaffold(
            appBar: AppBar(title: const Text('Notifications')),
            body: state.groups.isEmpty
                ? const Center(child: Text('No notifications yet.'))
                : ListView.separated(
                    itemCount: state.groups.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final group = state.groups[index];
                      final latest = group.latestNotification;
                      final senderName =
                          latest['senderName']?.toString() ?? 'InkLink';
                      final senderPic = latest['senderPic']?.toString();
                      final title =
                          latest['title']?.toString() ?? 'Notification';
                      final body = latest['body']?.toString() ?? '';
                      final type = latest['type']?.toString() ?? 'general';
                      final notificationId = latest['id']?.toString() ?? '';
                      final status = latest['status']?.toString() ?? 'info';
                      final unread = group.hasUnread;
                      final isActionablePending =
                          (type == 'board_invite' ||
                              type == 'friend_request') &&
                          status == 'pending';

                      final resolvedSuffix = switch (status) {
                        'accepted' => 'accepted',
                        'declined' => 'declined',
                        'expired' => 'expired',
                        _ => null,
                      };

                      final primaryLine = resolvedSuffix == null
                          ? body
                          : '$body\nYou $resolvedSuffix this request';

                      return ListTile(
                        tileColor: unread
                            ? Colors.amber.withOpacity(0.08)
                            : null,
                        leading: CircleAvatar(
                          backgroundImage:
                              senderPic != null && senderPic.isNotEmpty
                              ? NetworkImage(senderPic)
                              : null,
                          child: senderPic == null || senderPic.isEmpty
                              ? Text(
                                  senderName.isEmpty
                                      ? 'I'
                                      : senderName[0].toUpperCase(),
                                )
                              : null,
                        ),
                        title: Text(
                          senderName,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          group.count > 1
                              ? '$title\n$primaryLine\n${group.count} similar'
                              : '$title\n$primaryLine',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActionablePending &&
                                type == 'board_invite') ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  final inviteId =
                                      latest['extraData']?['inviteId']
                                          ?.toString() ??
                                      latest['targetId']?.toString() ??
                                      latest['id']?.toString() ??
                                      '';
                                  final boardId =
                                      latest['extraData']?['boardId']
                                          ?.toString() ??
                                      latest['targetId']?.toString() ??
                                      '';
                                  if (inviteId.isEmpty || boardId.isEmpty) {
                                    return;
                                  }
                                  context
                                      .read<NotificationsBloc>()
                                      .markNotificationRead(notificationId);
                                  context.read<InvitationsBloc>().add(
                                    InvitationAcceptRequested(
                                      inviteId,
                                      boardId: boardId,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  final inviteId =
                                      latest['extraData']?['inviteId']
                                          ?.toString() ??
                                      latest['targetId']?.toString() ??
                                      latest['id']?.toString() ??
                                      '';
                                  if (inviteId.isEmpty) {
                                    return;
                                  }
                                  context
                                      .read<NotificationsBloc>()
                                      .markNotificationRead(notificationId);
                                  context.read<InvitationsBloc>().add(
                                    InvitationDeclineRequested(inviteId),
                                  );
                                },
                              ),
                            ] else if (isActionablePending &&
                                type == 'friend_request') ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  final requestId =
                                      latest['extraData']?['requestId']
                                          ?.toString() ??
                                      latest['targetId']?.toString() ??
                                      latest['id']?.toString() ??
                                      '';
                                  final senderUid =
                                      latest['fromUid']?.toString() ?? '';
                                  if (requestId.isEmpty) {
                                    return;
                                  }
                                  context
                                      .read<NotificationsBloc>()
                                      .markNotificationRead(notificationId);
                                  context.read<FriendsBloc>().add(
                                    AcceptFriendRequestRequested(
                                      requestId,
                                      senderUid,
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  final requestId =
                                      latest['extraData']?['requestId']
                                          ?.toString() ??
                                      latest['targetId']?.toString() ??
                                      latest['id']?.toString() ??
                                      '';
                                  if (requestId.isEmpty) {
                                    return;
                                  }
                                  context
                                      .read<NotificationsBloc>()
                                      .markNotificationRead(notificationId);
                                  context.read<FriendsBloc>().add(
                                    DeclineFriendRequestRequested(requestId),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          if (type == 'board_invite') {
                            if (notificationId.isNotEmpty) {
                              context
                                  .read<NotificationsBloc>()
                                  .markNotificationRead(notificationId);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<InvitationsBloc>(),
                                  child: const BoardInvitesScreen(),
                                ),
                              ),
                            );
                            return;
                          }

                          if (type == 'friend_request' ||
                              type == 'friend_request_accepted') {
                            if (notificationId.isNotEmpty) {
                              context
                                  .read<NotificationsBloc>()
                                  .markNotificationRead(notificationId);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FriendRequestsScreen(),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
