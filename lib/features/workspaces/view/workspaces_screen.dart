import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../../core/utils/app_snackbar.dart';

/// Height of a workspace card in the grid (card + its bottom padding).
const double _workspaceCardExtent = 240;

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen>
    with AutomaticKeepAliveClientMixin {
  static const String _activityPrefsKey = 'workspace_activity_timestamps';
  final Map<String, int> _workspaceActivityMs = <String, int>{};
  bool _hasSeededInitialWorkspaces = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWorkspaceActivity());
    context.read<WorkspaceBloc>().add(LoadWorkspacesRequested());
    context.read<WorkspaceBloc>().add(LoadIncomingInvitesRequested());
  }

  Future<void> _loadWorkspaceActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activityPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final loaded = <String, int>{};
      for (final entry in decoded.entries) {
        final ms = entry.value;
        if (ms is num) {
          loaded[entry.key.toString()] = ms.toInt();
        }
      }
      if (!mounted || loaded.isEmpty) return;
      setState(() {
        for (final entry in loaded.entries) {
          _workspaceActivityMs.putIfAbsent(entry.key, () => entry.value);
        }
      });
    } catch (_) {}
  }

  Future<void> _persistWorkspaceActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activityPrefsKey, jsonEncode(_workspaceActivityMs));
    } catch (_) {}
  }

  void _recordWorkspaceOpened(String workspaceId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _workspaceActivityMs[workspaceId] = nowMs;
    });
    unawaited(_persistWorkspaceActivity());
  }

  void _syncWorkspaceActivity(WorkspaceLoaded state) {
    final all = [...state.ownedWorkspaces, ...state.memberWorkspaces];
    if (all.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final ws in all) {
      if (_workspaceActivityMs.containsKey(ws.id)) continue;
      _workspaceActivityMs[ws.id] = _hasSeededInitialWorkspaces
          ? nowMs
          : ws.updatedAt.millisecondsSinceEpoch;
      changed = true;
    }
    _hasSeededInitialWorkspaces = true;
    if (changed) {
      unawaited(_persistWorkspaceActivity());
    }
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

  /// Most recently opened or newly joined workspaces first.
  List<Workspace> _orderWorkspaces(WorkspaceLoaded state) {
    final byId = <String, Workspace>{};
    for (final ws in state.ownedWorkspaces) {
      byId[ws.id] = ws;
    }
    for (final ws in state.memberWorkspaces) {
      byId.putIfAbsent(ws.id, () => ws);
    }
    final ordered = byId.values.toList(growable: false)
      ..sort((a, b) {
        final aMs =
            _workspaceActivityMs[a.id] ?? a.updatedAt.millisecondsSinceEpoch;
        final bMs =
            _workspaceActivityMs[b.id] ?? b.updatedAt.millisecondsSinceEpoch;
        final cmp = bMs.compareTo(aMs);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    return ordered;
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
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (state is WorkspaceLoaded) {
          if (state.actionError != null) {
            AppSnackBar.show(
              context,
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
            AppSnackBar.showMessage(
              context,
              state.actionInfo!,
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

                      _syncWorkspaceActivity(state);
                      final workspaces = _orderWorkspaces(state);

                      return Column(
                        children: [
                          Expanded(
                            child: workspaces.isEmpty
                                ? const EmptyState(
                                    icon: LucideIcons.layoutGrid,
                                    text: 'No workspaces yet',
                                    subtitle: 'Create your first workspace to get started',
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      // One column on phones, two once the
                                      // screen is wide enough for side-by-side
                                      // cards.
                                      final columns =
                                          constraints.maxWidth >= 720 ? 2 : 1;
                                      return GridView.builder(
                                        padding: const EdgeInsets.all(
                                          InkSpacing.s16,
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: columns,
                                              crossAxisSpacing: InkSpacing.s16,
                                              mainAxisSpacing: 0,
                                              mainAxisExtent:
                                                  _workspaceCardExtent,
                                            ),
                                        itemCount: workspaces.length,
                                        itemBuilder: (context, index) {
                                          final workspace = workspaces[index];
                                          return WorkspaceCard(
                                            workspace: workspace,
                                            previewBoards:
                                                state.previewBoardsByWorkspace[workspace
                                                    .id] ??
                                                const [],
                                            onTap: () async {
                                              _recordWorkspaceOpened(
                                                workspace.id,
                                              );
                                              await Navigator.push(
                                                context,
                                                buildWorkspaceDetailRoute(
                                                  context,
                                                  workspace.id,
                                                ),
                                              );
                                              if (!context.mounted) return;
                                              // Board previews land on the
                                              // device while a board is open,
                                              // so re-read them on the way
                                              // back.
                                              context
                                                  .read<WorkspaceBloc>()
                                                  .add(
                                                    RefreshWorkspacePreviewsRequested(),
                                                  );
                                            },
                                            onOptionsPressed: () =>
                                                _showWorkspaceActions(
                                                  workspace,
                                                ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              InkSpacing.s16,
                              InkSpacing.s16,
                              InkSpacing.s16,
                              100,
                            ),
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
