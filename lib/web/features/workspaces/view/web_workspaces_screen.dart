import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../ui/theme/ink_colors.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_tilt.dart';
import '../../../../ui/widgets/paper_card.dart';
import '../../../domain/models/web_workspace_rules.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../../../ui/widgets/web_page_layout.dart';
import '../../navigation/view/web_shell_section.dart';
import '../bloc/web_workspaces_cubit.dart';
import 'web_workspace_crud_dialogs.dart';
import 'web_workspace_detail_view.dart';

/// Workspaces list screen displaying stacked paper cards and drilling into
/// [WebWorkspaceDetailView] when opened.
class WebWorkspacesPage extends StatefulWidget {
  const WebWorkspacesPage({super.key});

  @override
  State<WebWorkspacesPage> createState() => _WebWorkspacesPageState();
}

class _WebWorkspacesPageState extends State<WebWorkspacesPage> {
  final _search = TextEditingController();
  Workspace? _open;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: open == null
          ? KeyedSubtree(key: const ValueKey('list'), child: _buildList())
          : WebWorkspaceDetailView(
              key: ValueKey(open.id),
              workspace: open,
              onBack: () {
                setState(() => _open = null);
                context.read<WebWorkspacesCubit>().refresh();
              },
            ),
    );
  }

  Widget _buildList() {
    final state = context.watch<WebWorkspacesCubit>().state;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s24,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        WebPageHeader(
          title: 'Workspaces',
          subtitle: 'Team spaces you own or joined, with their boards.',
          trailing: Wrap(
            spacing: InkSpacing.s8,
            runSpacing: InkSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: WebSearchField(
                  controller: _search,
                  hintText: 'Search workspaces...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              InkButton.primary(
                label: 'New workspace',
                compact: true,
                expand: false,
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => showCreateWorkspaceDialog(context),
              ),
            ],
          ),
        ),
        if (state.error != null)
          WebErrorBox(message: webErrorText(state.error!))
        else if (state.loading)
          const WebLoading()
        else if (state.workspaces.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: InkSpacing.s24),
            child: WebEmptyHint(
              icon: LucideIcons.briefcase,
              text: 'No workspaces yet',
              subtitle: 'Create one to group boards for your team.',
            ),
          )
        else
          Builder(
            builder: (context) {
              final query = _search.text.trim().toLowerCase();
              final visible = query.isEmpty
                  ? state.workspaces
                  : state.workspaces
                        .where(
                          (w) =>
                              w.name.toLowerCase().contains(query) ||
                              w.description.toLowerCase().contains(query),
                        )
                        .toList();
              if (visible.isEmpty) {
                return WebEmptyHint(
                  icon: LucideIcons.searchX,
                  text: 'No workspaces match "${_search.text.trim()}"',
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  const gap = InkSpacing.s20;
                  final columns = (constraints.maxWidth / 340).floor().clamp(
                    1,
                    4,
                  );
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final w in visible)
                        SizedBox(
                          key: ValueKey(w.id),
                          width: width,
                          child: _WorkspaceCard(
                            workspace: w,
                            onOpen: () => setState(() => _open = w),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _WorkspaceCard extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback onOpen;

  const _WorkspaceCard({required this.workspace, required this.onOpen});

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  late final Stream<List<Board>> _boards = context
      .read<WebWorkspacesCubit>()
      .watchWorkspaceBoards(widget.workspace.id);

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final w = widget.workspace;

    Widget sheet(String salt, double maxDegrees) => Transform.rotate(
      angle: inkDeterministicTilt('${w.id}-$salt', maxDegrees: maxDegrees),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(InkRadii.paperCard),
          boxShadow: tokens.paperShadow,
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Workspace ${w.name}, ${formatWorkspaceCounts(w)}',
      excludeSemantics: true,
      child: SizedBox(
        height: 206,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 6,
              left: 10,
              right: 2,
              bottom: -2,
              child: sheet('back2', 2.2),
            ),
            Positioned(
              top: 3,
              left: 5,
              right: -2,
              bottom: 1,
              child: sheet('back1', 1.4),
            ),
            Positioned.fill(
              child: PaperCard(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onOpen,
                    borderRadius: BorderRadius.circular(InkRadii.paperCard),
                    child: Padding(
                      padding: const EdgeInsets.all(InkSpacing.s12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 88,
                            child: StreamBuilder<List<Board>>(
                              stream: _boards,
                              builder: (context, snapshot) {
                                final boards = (snapshot.data ?? const [])
                                    .take(3)
                                    .toList();
                                return Row(
                                  children: [
                                    for (var i = 0; i < 3; i++) ...[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: _BoardTile(
                                          board: i < boards.length
                                              ? boards[i]
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: InkSpacing.s12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.name.isEmpty ? 'Workspace' : w.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: InkType.cardTitle(tokens.ink),
                                ),
                              ),
                              _RoleChip(owner: w.currentUserRole == 'owner'),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            w.description.isNotEmpty
                                ? w.description
                                : formatWorkspaceCounts(w),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: InkType.caption(tokens.inkMuted),
                          ),
                          if (w.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              formatWorkspaceCounts(w),
                              style: InkType.caption(tokens.inkMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  final Board? board;
  const _BoardTile({required this.board});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final b = board;
    if (b == null) {
      return Container(
        decoration: BoxDecoration(
          color: tokens.field,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(LucideIcons.layoutGrid, color: tokens.inkMuted, size: 20),
      );
    }
    final color = InkColors.stickyForId(b.id);
    return Container(
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        b.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: InkType.caption(InkColors.stickyInkFor(color)),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool owner;
  const _RoleChip({required this.owner});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: owner ? tokens.accentSoft : tokens.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        owner ? 'Owner' : 'Member',
        style: InkType.caption(owner ? tokens.accentText : tokens.inkSecondary),
      ),
    );
  }
}
