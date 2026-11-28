import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/board.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../ui/widgets/ink_dialog.dart';
import '../../../core/web_formatters.dart';
import '../../../ui/widgets/web_feedback_widgets.dart';
import '../bloc/web_workspaces_cubit.dart';

/// Adds or removes the signed-in user's active boards from [workspace].
Future<void> showWorkspaceBoardsDialog(
  BuildContext context,
  Workspace workspace,
) => showDialog(
  context: context,
  builder: (_) => _WorkspaceBoardsDialog(workspace: workspace),
);

class _WorkspaceBoardsDialog extends StatefulWidget {
  final Workspace workspace;
  const _WorkspaceBoardsDialog({required this.workspace});

  @override
  State<_WorkspaceBoardsDialog> createState() => _WorkspaceBoardsDialogState();
}

class _WorkspaceBoardsDialogState extends State<_WorkspaceBoardsDialog> {
  List<Board> _boards = const [];
  final Set<String> _linked = <String>{};
  bool _loading = true;
  String? _error;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final workspaces = context.read<WebWorkspacesCubit>();
    try {
      final result = await workspaces.loadManageableBoards(widget.workspace.id);
      if (!mounted) return;
      setState(() {
        _boards = result.activeBoards;
        _linked
          ..clear()
          ..addAll(result.linkedIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = webErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Board board) async {
    final workspaces = context.read<WebWorkspacesCubit>();
    final adding = !_linked.contains(board.id);
    setState(() => _busy.add(board.id));
    try {
      if (adding) {
        await workspaces.addBoardToWorkspace(
          workspaceId: widget.workspace.id,
          boardId: board.id,
        );
      } else {
        await workspaces.removeBoardFromWorkspace(
          workspaceId: widget.workspace.id,
          boardId: board.id,
        );
      }
      if (!mounted) return;
      setState(() {
        if (adding) {
          _linked.add(board.id);
        } else {
          _linked.remove(board.id);
        }
        _busy.remove(board.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(board.id));
      showWebMessage(context, webErrorText(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkDialog(
      title: 'Boards in ${widget.workspace.name}',
      icon: LucideIcons.briefcase,
      content: SizedBox(
        width: 440,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: _loading
              ? const WebLoading()
              : _error != null
              ? Text(_error!, style: InkType.body(tokens.danger))
              : _boards.isEmpty
              ? Text(
                  'You have no boards to add yet.',
                  style: InkType.body(tokens.inkSecondary),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final board in _boards)
                        ListTile(
                          key: ValueKey(board.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            board.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: InkType.bodyStrong(tokens.ink),
                          ),
                          subtitle: Text(
                            board.tags.isEmpty
                                ? 'Edited ${timeAgo(board.updatedAt)}'
                                : board.tags
                                      .take(3)
                                      .map((t) => '#$t')
                                      .join(' '),
                            style: InkType.caption(tokens.inkMuted),
                          ),
                          trailing: _linked.contains(board.id)
                              ? InkButton.secondary(
                                  label: 'Remove',
                                  compact: true,
                                  expand: false,
                                  isLoading: _busy.contains(board.id),
                                  onPressed: _busy.contains(board.id)
                                      ? null
                                      : () => _toggle(board),
                                )
                              : InkButton.primary(
                                  label: 'Add',
                                  compact: true,
                                  expand: false,
                                  isLoading: _busy.contains(board.id),
                                  onPressed: _busy.contains(board.id)
                                      ? null
                                      : () => _toggle(board),
                                ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Done',
          compact: true,
          expand: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
