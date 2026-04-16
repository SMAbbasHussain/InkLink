import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        child: BlocBuilder<WorkspaceBloc, WorkspaceState>(
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
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('Workspace Invitation'),
                    subtitle: Text(
                      'From: ${invite.fromUid}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: SizedBox(
                      width: 160,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              context.read<WorkspaceBloc>().add(
                                RejectWorkspaceInviteRequested(invite.id),
                              );
                            },
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              context.read<WorkspaceBloc>().add(
                                AcceptWorkspaceInviteRequested(invite.id),
                              );
                            },
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ),
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
