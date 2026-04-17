import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;

import '../bloc/workspace_bloc.dart';

class WorkspaceInvitesScreen extends StatefulWidget {
  const WorkspaceInvitesScreen({super.key});

  @override
  State<WorkspaceInvitesScreen> createState() => _WorkspaceInvitesScreenState();
}

class _WorkspaceInvitesScreenState extends State<WorkspaceInvitesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WorkspaceBloc>().add(LoadIncomingInvitesRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workspace Invitations')),
      body: SafeArea(
        child: BlocConsumer<WorkspaceBloc, WorkspaceState>(
          listener: (context, state) {
            if (state is! WorkspaceLoaded) return;

            if (state.actionError != null && state.actionError!.isNotEmpty) {
              developer.log(
                'WorkspaceInvitesScreen actionError: ${state.actionError}',
                name: 'WorkspaceInvitesScreen',
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.actionError!)));
            }

            if (state.actionInfo != null && state.actionInfo!.isNotEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.actionInfo!)));
            }
          },
          builder: (context, state) {
            if (state is! WorkspaceLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final pendingInvites = state.incomingInvites
                .where((i) => i.status == 'pending')
                .toList();

            if (pendingInvites.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No pending invitations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingInvites.length,
              itemBuilder: (context, index) {
                final invite = pendingInvites[index];
                final isProcessing = state.processingInviteDecisionIds.contains(
                  invite.id,
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage:
                              invite.senderPhotoUrl != null &&
                                  invite.senderPhotoUrl!.isNotEmpty
                              ? NetworkImage(invite.senderPhotoUrl!)
                              : null,
                          child:
                              invite.senderPhotoUrl == null ||
                                  invite.senderPhotoUrl!.isEmpty
                              ? Text(
                                  invite.senderName.isEmpty
                                      ? 'U'
                                      : invite.senderName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                )
                              : null,
                        ),
                        title: Text(
                          invite.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          'invited you to ${invite.workspaceName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () {
                                        developer.log(
                                          'Reject invite tapped | inviteId=${invite.id} | workspaceId=${invite.workspaceId} | fromUid=${invite.fromUid}',
                                          name: 'WorkspaceInvitesScreen',
                                        );
                                        context.read<WorkspaceBloc>().add(
                                          RejectWorkspaceInviteRequested(
                                            invite.id,
                                          ),
                                        );
                                      },
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: isProcessing
                                    ? null
                                    : () {
                                        developer.log(
                                          'Accept invite tapped | inviteId=${invite.id} | workspaceId=${invite.workspaceId} | fromUid=${invite.fromUid}',
                                          name: 'WorkspaceInvitesScreen',
                                        );
                                        context.read<WorkspaceBloc>().add(
                                          AcceptWorkspaceInviteRequested(
                                            invite.id,
                                          ),
                                        );
                                      },
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(
                                  isProcessing ? 'Processing...' : 'Accept',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
