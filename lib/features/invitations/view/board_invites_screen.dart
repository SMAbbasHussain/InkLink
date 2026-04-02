import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/canvas/view/canvas_route.dart';
import '../bloc/invitations_bloc.dart';

class BoardInvitesScreen extends StatelessWidget {
  const BoardInvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvitationsBloc, InvitationsState>(
      listener: (context, state) {
        if (state is InvitationsLoaded && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: state.isError ? Colors.red : null,
            ),
          );

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
        }
      },
      builder: (context, state) {
        if (state is InvitationsInitial) {
          context.read<InvitationsBloc>().add(const InvitationsLoadRequested());
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is InvitationsLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is InvitationsError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Board Invites')),
            body: Center(child: Text(state.message)),
          );
        }

        final loaded = state as InvitationsLoaded;
        return Scaffold(
          appBar: AppBar(title: const Text('Board Invites')),
          body: loaded.invites.isEmpty
              ? const Center(child: Text('No pending invites.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: loaded.invites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final invite = loaded.invites[index];
                    final inviteId = invite['id']?.toString() ?? '';
                    final boardId = invite['boardId']?.toString() ?? '';
                    final boardTitle =
                        invite['boardTitle']?.toString() ?? 'Untitled Board';
                    final senderName =
                        invite['senderName']?.toString() ?? 'InkLink User';
                    final senderPic = invite['senderPic']?.toString();
                    final expiresAt = invite['expiresAt'];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text('invited you to "$boardTitle"'),
                                      if (expiresAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Invite has an expiration window',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: inviteId.isEmpty
                                        ? null
                                        : () {
                                            context.read<InvitationsBloc>().add(
                                              InvitationDeclineRequested(
                                                inviteId,
                                              ),
                                            );
                                          },
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        inviteId.isEmpty || boardId.isEmpty
                                        ? null
                                        : () {
                                            context.read<InvitationsBloc>().add(
                                              InvitationAcceptRequested(
                                                inviteId,
                                                boardId: boardId,
                                              ),
                                            );
                                          },
                                    child: const Text('Accept'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
