import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/models/workspace.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/empty_state.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
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
    final tokens = context.ink;
    final isOwner = workspace.currentUserRole == 'owner';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.s16,
            InkSpacing.s8,
            InkSpacing.s16,
            InkSpacing.s24,
          ),
          child: GlassPanel(
            radius: InkRadii.bottomSheet,
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
                    decoration: BoxDecoration(
                      color: tokens.inkMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      isOwner ? LucideIcons.trash2 : LucideIcons.logOut,
                      color: tokens.danger,
                    ),
                    title: Text(
                      isOwner ? 'Delete workspace' : 'Leave workspace',
                      style: InkType.bodyStrong(tokens.danger),
                    ),
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String workspaceId) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Delete Workspace?',
      message:
          'This workspace will be permanently deleted. This action cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      context.read<WorkspaceBloc>().add(DeleteWorkspaceRequested(workspaceId));
    }
  }

  Future<void> _confirmLeave(String workspaceId) async {
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Leave Workspace?',
      message: 'You will lose access to this workspace.',
      confirmLabel: 'Leave',
    );

    if (confirmed && mounted) {
      context.read<WorkspaceBloc>().add(LeaveWorkspaceRequested(workspaceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tokens = context.ink;

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
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.ban, size: 16, color: tokens.danger),
                    const SizedBox(width: InkSpacing.s8),
                    Flexible(child: Text(state.actionError!)),
                  ],
                ),
              ),
            );
          } else if (state.actionInfo != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.actionInfo!)),
            );
          }
        }
      },
      child: Scaffold(
        body: DeskBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.s16,
                    InkSpacing.s12,
                    InkSpacing.s16,
                    0,
                  ),
                  child: Row(
                    children: [
                      Text('Workspaces', style: InkType.headline(tokens.ink)),
                      const Spacer(),
                      BlocBuilder<WorkspaceBloc, WorkspaceState>(
                        builder: (context, state) {
                          int pendingCount = 0;
                          if (state is WorkspaceLoaded) {
                            pendingCount = state.incomingInvites
                                .where((i) => i.status == 'pending')
                                .length;
                          }
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                tooltip: 'Workspace invites',
                                icon: Icon(LucideIcons.mail, color: tokens.ink),
                                onPressed: _showInvitesScreen,
                              ),
                              if (pendingCount > 0)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: tokens.pending,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$pendingCount',
                                      style: InkType.caption(Colors.white).copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: BlocBuilder<WorkspaceBloc, WorkspaceState>(
                    builder: (context, state) {
                      if (state is WorkspaceInitial) {
                        return Center(
                          child: CircularProgressIndicator(color: tokens.accent),
                        );
                      }

                      if (state is! WorkspaceLoaded) {
                        return Center(
                          child: Text(
                            'Failed to load workspaces',
                            style: InkType.body(tokens.inkMuted),
                          ),
                        );
                      }

                      final workspaces = [
                        ...state.ownedWorkspaces,
                        ...state.memberWorkspaces,
                      ];

                      return Column(
                        children: [
                          Expanded(
                            child: workspaces.isEmpty
                                ? const EmptyState(
                                    icon: LucideIcons.layoutGrid,
                                    text: 'No workspaces yet',
                                    subtitle: 'Create your first workspace to get started',
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(InkSpacing.s16),
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
                            padding: const EdgeInsets.all(InkSpacing.s16),
                            child: InkButton.primary(
                              label: 'Create Workspace',
                              icon: const Icon(LucideIcons.plus),
                              onPressed: _showCreateWorkspaceDialog,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route<void> buildWorkspaceInvitesRoute(BuildContext context) {
  return MaterialPageRoute(builder: (_) => const WorkspaceInvitesScreen());
}
