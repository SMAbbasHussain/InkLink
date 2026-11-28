import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/board.dart';
import '../../domain/models/workspace.dart';
import '../../ui/theme/ink_colors.dart';
import '../../ui/theme/ink_theme.dart';
import '../../ui/theme/ink_tokens.dart';
import '../../ui/theme/ink_type.dart';
import '../../ui/widgets/ink_button.dart';
import '../../ui/widgets/ink_dialog.dart';
import '../../ui/widgets/ink_text_field.dart';
import '../../ui/widgets/ink_tilt.dart';
import '../../ui/widgets/paper_card.dart';
import '../domain/web_companion_service.dart';
import '../data/web_mappers.dart';
import '../widgets/web_widgets.dart';
import 'boards_page.dart';
import 'web_shell_nav.dart';
import 'workspace_members.dart';

/// The user's workspaces, like the phone's Workspaces tab: stacked paper
/// cards with the first boards on top. Clicking one shows its boards, which
/// open on the web canvas. Creating and managing workspaces stays in the app.
class WebWorkspacesPage extends StatefulWidget {
  const WebWorkspacesPage({super.key});

  @override
  State<WebWorkspacesPage> createState() => _WebWorkspacesPageState();
}

class _WebWorkspacesPageState extends State<WebWorkspacesPage> {
  late final _repo = context.read<WebCompanionService>();
  // A live query can be listened to once, and the list is rebuilt when
  // you come back from a workspace, so each visit gets a fresh one.
  late Stream<List<Workspace>> _workspaces = _repo.watchMyWorkspaces();
  final _search = TextEditingController();

  /// The open workspace (its boards are shown), or null for the list.
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
          : _WorkspaceBoardsView(
              key: ValueKey(open.id),
              workspace: open,
              onBack: () => setState(() {
                _open = null;
                _workspaces = _repo.watchMyWorkspaces();
              }),
            ),
    );
  }

  Widget _buildList() {
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
        WebStreamList<Workspace>(
          stream: _workspaces,
          compactEmpty: false,
          emptyIcon: LucideIcons.briefcase,
          emptyText: 'No workspaces yet',
          emptySubtitle: 'Create one to group boards for your team.',
          builder: (context, workspaces) {
            final query = _search.text.trim().toLowerCase();
            final visible = query.isEmpty
                ? workspaces
                : workspaces
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

/// "4 members • 3 boards".
String _workspaceCounts(Workspace w) {
  String n(int count, String word) => '$count $word${count == 1 ? '' : 's'}';
  return '${n(w.memberCount, 'member')} • ${n(w.boardCount, 'board')}';
}

/// The phone's workspace card: two tilted sheets peeking out behind a paper
/// card with the first three boards, the name and the description.
class _WorkspaceCard extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback onOpen;

  const _WorkspaceCard({required this.workspace, required this.onOpen});

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  late final Stream<List<Board>> _boards = context
      .read<WebCompanionService>()
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
      label: 'Workspace ${w.name}, ${_workspaceCounts(w)}',
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
                                : _workspaceCounts(w),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: InkType.caption(tokens.inkMuted),
                          ),
                          if (w.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _workspaceCounts(w),
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

/// A board on a workspace card: its sticky colour and title (the web has no
/// board thumbnails), or an empty slot.
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

/// One workspace's boards, live, as the board cards used on Home.
class _WorkspaceBoardsView extends StatefulWidget {
  final Workspace workspace;
  final VoidCallback onBack;

  const _WorkspaceBoardsView({
    super.key,
    required this.workspace,
    required this.onBack,
  });

  @override
  State<_WorkspaceBoardsView> createState() => _WorkspaceBoardsViewState();
}

class _WorkspaceBoardsViewState extends State<_WorkspaceBoardsView> {
  late final Stream<List<Board>> _boards = context
      .read<WebCompanionService>()
      .watchWorkspaceBoards(widget.workspace.id);
  final _search = TextEditingController();

  /// The workspace as last saved here, so an owner's name/description edit
  /// shows immediately (the list stream does not re-read the document).
  late Workspace _workspace = widget.workspace;

  /// Owner-only details editor, using the phone's `updateWorkspace` fields.
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
            _workspaceCounts(w),
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

/// Creates a workspace with the phone's `createWorkspace` function.
Future<void> showCreateWorkspaceDialog(BuildContext context) => showDialog(
  context: context,
  builder: (_) => const _CreateWorkspaceDialog(),
);

class _CreateWorkspaceDialog extends StatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  State<_CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<_CreateWorkspaceDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a workspace name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<WebCompanionService>().createWorkspace(
        name: _name.text,
        description: _description.text,
      );
      if (!mounted) return;
      showWebMessage(context, 'Workspace created.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = webErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: 'New workspace',
      icon: LucideIcons.briefcase,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkTextField(
              controller: _name,
              labelText: 'Name',
              hintText: 'e.g. Design team',
              errorText: _error,
              autofocus: true,
              enabled: !_saving,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: InkSpacing.s12),
            InkTextField(
              controller: _description,
              labelText: 'Description (optional)',
              enabled: !_saving,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        InkButton.secondary(
          label: 'Cancel',
          compact: true,
          expand: false,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        InkButton.primary(
          label: 'Create',
          compact: true,
          expand: false,
          isLoading: _saving,
          onPressed: _saving ? null : _create,
        ),
      ],
    );
  }
}

/// Adds the reader's boards to a workspace and removes them again, through
/// the same `addBoardToWorkspace` / `removeBoardFromWorkspace` functions the
/// phone's workspace screen uses.
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
    final repo = context.read<WebCompanionService>();
    try {
      final boards = await repo.watchMyBoards().first;
      final linked = await repo.watchWorkspaceBoards(widget.workspace.id).first;
      if (!mounted) return;
      setState(() {
        _boards = boards.where((b) => !b.isArchived).toList();
        _linked
          ..clear()
          ..addAll(linked.map((b) => b.id));
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
    final repo = context.read<WebCompanionService>();
    final adding = !_linked.contains(board.id);
    setState(() => _busy.add(board.id));
    try {
      if (adding) {
        await repo.addBoardToWorkspace(
          workspaceId: widget.workspace.id,
          boardId: board.id,
        );
      } else {
        await repo.removeBoardFromWorkspace(
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
