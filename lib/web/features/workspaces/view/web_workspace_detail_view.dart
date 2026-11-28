import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../core/web_formatters.dart';
import '../../../domain/models/web_workspace_rules.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../../../ui/widgets/web_page_layout.dart';
import '../../boards/view/web_board_card_grid.dart';
import '../../navigation/view/web_shell_section.dart';
import '../bloc/web_workspaces_cubit.dart';
import 'web_workspace_boards_dialog.dart';
import 'web_workspace_crud_dialogs.dart';
import 'web_workspace_members_section.dart';

/// Detail view for a single workspace: header, settings, members section, and
/// live linked boards grid.
class WebWorkspaceDetailView extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback onBack;

  const WebWorkspaceDetailView({
    super.key,
    required this.workspace,
    required this.onBack,
  });

  @override
  State<WebWorkspaceDetailView> createState() => _WebWorkspaceDetailViewState();
}

class _WebWorkspaceDetailViewState extends State<WebWorkspaceDetailView> {
  late final Stream<List<Board>> _boards = context
      .read<WebWorkspacesCubit>()
      .watchWorkspaceBoards(widget.workspace.id);
  final _search = TextEditingController();

  late Workspace _workspace = widget.workspace;

  Future<void> _editSettings() async {
    final saved = await showWorkspaceSettingsDialog(
      context,
      workspace: _workspace,
    );
    if (saved == null || !mounted) return;
    setState(() {
      _workspace = _workspace.copyWith(
        name: saved.name,
        description: saved.description,
      );
    });
    showWebMessage(context, 'Workspace settings saved.');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final w = _workspace;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.s24,
        InkSpacing.s16,
        InkSpacing.s24,
        webPageBottomPadding(context),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: Icon(LucideIcons.arrowLeft, size: 18, color: tokens.ink),
            label: Text('Workspaces', style: InkType.bodyStrong(tokens.ink)),
          ),
        ),
        const SizedBox(height: InkSpacing.s8),
        WebPageHeader(
          title: w.name.isEmpty ? 'Workspace' : w.name,
          subtitle: [
            if (w.description.isNotEmpty) w.description,
            formatWorkspaceCounts(w),
            w.currentUserRole == 'owner' ? 'You own it' : 'You are a member',
          ].join(' • '),
          trailing: Wrap(
            spacing: InkSpacing.s8,
            runSpacing: InkSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: WebSearchField(
                  controller: _search,
                  hintText: 'Search boards...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (w.currentUserRole == 'owner')
                InkButton.secondary(
                  label: 'Workspace settings',
                  compact: true,
                  expand: false,
                  icon: Icon(
                    LucideIcons.settings2,
                    size: 16,
                    color: context.ink.ink,
                  ),
                  onPressed: _editSettings,
                ),
              InkButton.secondary(
                label: 'Manage boards',
                compact: true,
                expand: false,
                icon: Icon(
                  LucideIcons.folderCog,
                  size: 16,
                  color: context.ink.ink,
                ),
                onPressed: () => showWorkspaceBoardsDialog(context, w),
              ),
            ],
          ),
        ),
        const SizedBox(height: InkSpacing.s16),
        WorkspaceMembersSection(workspace: w, onExited: widget.onBack),
        const SizedBox(height: InkSpacing.s16),
        WebStreamList<Board>(
          stream: _boards,
          compactEmpty: false,
          emptyIcon: LucideIcons.layoutGrid,
          emptyText: 'No boards in this workspace yet',
          emptySubtitle: 'Use Manage boards to add some.',
          builder: (context, boards) {
            final query = _search.text.trim().toLowerCase();
            final visible = boards
                .where((b) => !b.isArchived)
                .where(
                  (b) =>
                      query.isEmpty ||
                      b.title.toLowerCase().contains(query) ||
                      b.tags.any((t) => t.toLowerCase().contains(query)),
                )
                .toList();
            if (visible.isEmpty) {
              return WebEmptyHint(
                icon: query.isEmpty ? LucideIcons.archive : LucideIcons.searchX,
                text: query.isEmpty
                    ? 'All boards here are archived.'
                    : 'No boards match "${_search.text.trim()}"',
              );
            }
            return WebBoardCardGrid(
              boards: visible,
              captionFor: (b) => 'Edited ${timeAgo(b.updatedAt)}',
            );
          },
        ),
      ],
    );
  }
}
