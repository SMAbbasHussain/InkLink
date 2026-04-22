import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/workspace.dart';
import '../bloc/workspace_bloc.dart';
import 'widgets/workspace_card.dart';
import 'create_workspace_route.dart';
import 'workspace_detail_route.dart';
import 'workspace_invites_screen.dart';

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<WorkspaceBloc>().add(LoadWorkspacesRequested());
    context.read<WorkspaceBloc>().add(LoadIncomingInvitesRequested());
  }

  void _showCreateWorkspaceDialog() {
    Navigator.push(context, buildCreateWorkspaceRoute(context));
  }

  void _showInvitesScreen() {
    Navigator.push(context, buildWorkspaceInvitesRoute(context));
  }

  Future<void> _showWorkspaceActions(Workspace workspace) async {
    final isOwner = workspace.currentUserRole == 'owner';
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isOwner ? Icons.delete_outline : Icons.logout),
                title: Text(isOwner ? 'Delete workspace' : 'Leave workspace'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  if (isOwner) {
                    await _confirmDelete(workspace.id);
                  } else {
                    await _confirmLeave(workspace.id);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String workspaceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workspace?'),
        content: const Text(
          'This workspace will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<WorkspaceBloc>().add(DeleteWorkspaceRequested(workspaceId));
    }
  }

  Future<void> _confirmLeave(String workspaceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Workspace?'),
        content: const Text('You will lose access to this workspace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<WorkspaceBloc>().add(LeaveWorkspaceRequested(workspaceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<WorkspaceBloc, WorkspaceState>(
      listenWhen: (previous, current) =>
          previous is WorkspaceLoaded &&
          current is WorkspaceLoaded &&
          (previous.actionError != current.actionError ||
              previous.actionInfo != current.actionInfo),
      listener: (context, state) {
        if (state is WorkspaceLoaded) {
          if (state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state.actionInfo != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionInfo!),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workspaces'),
          actions: [
            BlocBuilder<WorkspaceBloc, WorkspaceState>(
              builder: (context, state) {
                int pendingCount = 0;
                if (state is WorkspaceLoaded) {
                  pendingCount = state.incomingInvites
                      .where((i) => i.status == 'pending')
                      .length;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.mail_outline),
                        onPressed: _showInvitesScreen,
                      ),
                      if (pendingCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<WorkspaceBloc, WorkspaceState>(
          builder: (context, state) {
            if (state is WorkspaceInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is! WorkspaceLoaded) {
              return const Center(child: Text('Failed to load workspaces'));
            }

            final workspaces = [
              ...state.ownedWorkspaces,
              ...state.memberWorkspaces,
            ];

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: workspaces.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.dashboard_customize_outlined,
                                  size: 64,
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No workspaces yet',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first workspace to get started',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: workspaces.length,
                            itemBuilder: (context, index) {
                              final workspace = workspaces[index];
                              return WorkspaceCard(
                                workspace: workspace,
                                previewBoards:
                                    state.previewBoardsByWorkspace[workspace
                                        .id] ??
                                    const [],
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    buildWorkspaceDetailRoute(
                                      context,
                                      workspace.id,
                                    ),
                                  );
                                },
                                onOptionsPressed: () =>
                                    _showWorkspaceActions(workspace),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Create Workspace'),
                      onPressed: _showCreateWorkspaceDialog,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Route<void> buildWorkspaceInvitesRoute(BuildContext context) {
  return MaterialPageRoute(builder: (_) => const WorkspaceInvitesScreen());
}
