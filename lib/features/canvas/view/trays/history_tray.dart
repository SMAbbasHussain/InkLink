import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../domain/models/history/board_activity_block.dart';
import '../../../../domain/models/history/undo_request.dart';
import '../../../../domain/services/history/board_history_service.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../bloc/canvas_bloc.dart';
import '../widgets/sliding_tray.dart';
import '../widgets/user_history_timeline.dart';

/// Section filter for the owner's history tray.
enum HistoryFilter { all, versions, restores, requests }

/// Owner-only board history: archived versions, the people who made them and
/// the undo requests waiting on a decision (D3/D5).
///
/// Everything here is a *view* over `CanvasState`: the tray never talks to the
/// socket itself, it dispatches bloc events so the owner-rights rules stay in
/// one place.
class HistoryTray extends StatefulWidget {
  final bool isOpen;
  final String boardId;
  final CanvasState state;
  final CanvasBloc bloc;
  final BoardHistoryService? historyService;
  final VoidCallback? onClose;

  const HistoryTray({
    super.key,
    required this.isOpen,
    required this.boardId,
    required this.state,
    required this.bloc,
    this.historyService,
    this.onClose,
  });

  @override
  State<HistoryTray> createState() => _HistoryTrayState();
}

class _HistoryTrayState extends State<HistoryTray> {
  final TextEditingController _search = TextEditingController();
  HistoryFilter _filter = HistoryFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  CanvasState get state => widget.state;

  List<UndoRequest> get _pending =>
      state.undoRequests.where((r) => r.isPending).toList(growable: false);

  bool _matchesQuery(BoardActivityBlock block) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final range = 'v${block.fromVersion} v${block.toVersion}'.toLowerCase();
    if (range.contains(query)) return true;
    for (final uid in block.contributorUids) {
      final name = block.summary[uid]?.name.toLowerCase() ?? uid.toLowerCase();
      if (name.contains(query)) return true;
    }
    return false;
  }

  List<BoardActivityBlock> get _visibleBlocks {
    if (_filter == HistoryFilter.requests) return const [];
    return state.activityBlocks
        .where((block) {
          if (_filter == HistoryFilter.restores && block.restores.isEmpty) {
            return false;
          }
          return _matchesQuery(block);
        })
        .toList(growable: false);
  }

  bool get _showRequests =>
      _filter == HistoryFilter.all || _filter == HistoryFilter.requests;

  int get _latestVersion => state.activityBlocks.isEmpty
      ? 0
      : state.activityBlocks
            .map((b) => b.toVersion)
            .reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final blocks = _visibleBlocks;
    final pending = _pending;

    return SlidingTray(
      isOpen: widget.isOpen,
      direction: TrayDirection.right,
      title: 'History',
      width: 320,
      height: 520,
      bottomOffset: 60,
      onClose: widget.onClose,
      child: state.selectedUserUid != null
          ? Padding(
              padding: const EdgeInsets.all(InkSpacing.s12),
              child: UserHistoryTimeline(
                state: state,
                bloc: widget.bloc,
                targetUid: state.selectedUserUid!,
                displayName: _displayNameFor(state.selectedUserUid!),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isHistoryLoading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: tokens.accentText,
                    backgroundColor: tokens.field,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.s12,
                    InkSpacing.s8,
                    InkSpacing.s12,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.activityBlocks.isEmpty
                            ? 'No archived versions yet'
                            : 'Latest v$_latestVersion · '
                                  '${state.activityBlocks.length} version(s)'
                                  '${pending.isEmpty ? '' : ' · ${pending.length} request(s)'}',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      _buildSearchField(tokens),
                      const SizedBox(height: InkSpacing.s8),
                      _buildFilterChips(tokens, pending.length),
                    ],
                  ),
                ),
                const SizedBox(height: InkSpacing.s8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      InkSpacing.s12,
                      0,
                      InkSpacing.s12,
                      InkSpacing.s12,
                    ),
                    children: [
                      if (_showRequests && pending.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'Undo requests',
                          trailing: '${pending.length} waiting',
                        ),
                        ...pending.map(
                          (request) => _UndoRequestRow(
                            request: request,
                            onReview: () => widget.bloc.add(
                              CanvasHistoryUndoRequestReviewRequested(
                                request.requestId,
                              ),
                            ),
                            onDeny: () => _denyRequest(context, request),
                          ),
                        ),
                        const SizedBox(height: InkSpacing.s8),
                      ],
                      if (_filter != HistoryFilter.requests) ...[
                        const _SectionHeader(label: 'Versions'),
                        if (blocks.isEmpty)
                          Text(
                            _emptyVersionsMessage(),
                            style: InkType.caption(tokens.inkMuted),
                          )
                        else
                          ...blocks.map(
                            (block) => _BlockRow(
                              block: block,
                              onPreview: () => widget.bloc.add(
                                CanvasHistoryPreviewRequested(block.toVersion),
                              ),
                              onRestore: () => _confirmRestore(block),
                              onSelectContributor: (uid) => widget.bloc.add(
                                CanvasHistoryUserOpsRequested(uid),
                              ),
                            ),
                          ),
                      ],
                      if (_filter == HistoryFilter.requests &&
                          pending.isEmpty)
                        Text(
                          'No undo requests right now. Members can ask you to '
                          'undo their own recent edits from the tools tray.',
                          style: InkType.caption(tokens.inkMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _emptyVersionsMessage() {
    if (state.activityBlocks.isEmpty) {
      return 'History appears after the first block is archived '
          '(500 ops or a 5-minute flush).';
    }
    if (_search.text.trim().isNotEmpty) {
      return 'No versions match "${_search.text.trim()}".';
    }
    return 'No version in this list contains a restore.';
  }

  Widget _buildSearchField(InkTokens tokens) {
    return TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      style: InkType.caption(tokens.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: tokens.field,
        hintText: 'Search versions or people',
        hintStyle: InkType.caption(tokens.inkMuted),
        prefixIcon: Icon(LucideIcons.search, size: 14, color: tokens.inkMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 30),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InkRadii.chip),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips(InkTokens tokens, int pendingCount) {
    final entries = <HistoryFilter, String>{
      HistoryFilter.all: 'All',
      HistoryFilter.versions: 'Versions',
      HistoryFilter.restores: 'Restores',
      HistoryFilter.requests:
          pendingCount == 0 ? 'Requests' : 'Requests ($pendingCount)',
    };
    return Wrap(
      spacing: InkSpacing.s4,
      runSpacing: InkSpacing.s4,
      children: entries.entries.map((entry) {
        final selected = _filter == entry.key;
        return InkWell(
          onTap: () => setState(() => _filter = entry.key),
          borderRadius: BorderRadius.circular(InkRadii.chip),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: InkSpacing.s8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: selected ? tokens.accentText : tokens.field,
              borderRadius: BorderRadius.circular(InkRadii.chip),
            ),
            child: Text(
              entry.value,
              style: InkType.caption(
                selected ? tokens.paper : tokens.inkSecondary,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  String _displayNameFor(String uid) {
    for (final block in state.activityBlocks) {
      final summary = block.summary[uid];
      if (summary != null) return summary.name;
      if (block.contributorUids.contains(uid)) return 'Contributor';
    }
    for (final request in state.undoRequests) {
      if (request.requesterUid == uid) return request.requesterName;
    }
    return 'User';
  }

  Future<void> _confirmRestore(BoardActivityBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this version?'),
        content: Text(
          'The board will be set back to v${block.toVersion}. Everything added '
          'after it is reverted — the history itself is kept, so you can undo '
          'the restore later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.bloc.add(CanvasHistoryRestoreRequested(block.toVersion));
  }

  Future<void> _denyRequest(BuildContext context, UndoRequest request) async {
    final service = widget.historyService;
    if (service == null) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _DenyNoteDialog(),
    );
    if (note == null) return;
    try {
      await service.resolveUndoRequest(
        boardId: widget.boardId,
        requestId: request.requestId,
        status: 'denied',
        note: note,
      );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Undo request declined.');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'Could not decline the request.');
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? trailing;

  const _SectionHeader({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: InkType.bodyStrong(tokens.ink))),
          if (trailing != null)
            Text(trailing!, style: InkType.caption(tokens.inkMuted)),
        ],
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  final BoardActivityBlock block;
  final VoidCallback onPreview;
  final VoidCallback onRestore;
  final ValueChanged<String> onSelectContributor;

  const _BlockRow({
    required this.block,
    required this.onPreview,
    required this.onRestore,
    required this.onSelectContributor,
  });

  String get _range {
    final first = block.firstOpAt;
    final last = block.lastOpAt;
    String fmt(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    if (first == null || last == null) return '—';
    return '${fmt(first)}–${fmt(last)}';
  }

  ({int adds, int updates, int deletes}) get _totals {
    var adds = 0;
    var updates = 0;
    var deletes = 0;
    for (final summary in block.summary.values) {
      adds += summary.adds;
      updates += summary.updates;
      deletes += summary.deletes;
    }
    return (adds: adds, updates: updates, deletes: deletes);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final totals = _totals;
    final restore = block.restores.isEmpty ? null : block.restores.last;

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s8),
      child: InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(InkRadii.chip),
        child: Container(
          padding: const EdgeInsets.all(InkSpacing.s8),
          decoration: BoxDecoration(
            color: tokens.field,
            borderRadius: BorderRadius.circular(InkRadii.chip),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'v${block.fromVersion}–v${block.toVersion}',
                      style: InkType.bodyStrong(tokens.ink),
                    ),
                  ),
                  Text(
                    '${block.operationCount} ops',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                  _VersionMenu(onPreview: onPreview, onRestore: onRestore),
                ],
              ),
              const SizedBox(height: 2),
              Text(_range, style: InkType.caption(tokens.inkMuted)),
              const SizedBox(height: 2),
              Text(
                '${totals.adds} added · ${totals.updates} edited · '
                '${totals.deletes} removed',
                style: InkType.caption(tokens.inkMuted),
              ),
              if (restore != null) ...[
                const SizedBox(height: InkSpacing.s4),
                _Tag(
                  icon: LucideIcons.history,
                  label: restore.restoredFromVersion == null
                      ? 'restored'
                      : 'restored to v${restore.restoredFromVersion}',
                  color: tokens.pending,
                ),
              ],
              if (block.contributorUids.isNotEmpty) ...[
                const SizedBox(height: InkSpacing.s4),
                Wrap(
                  spacing: InkSpacing.s4,
                  runSpacing: InkSpacing.s4,
                  children: block.contributorUids
                      .map(
                        (uid) => InkWell(
                          onTap: () => onSelectContributor(uid),
                          borderRadius: BorderRadius.circular(InkRadii.chip),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: InkSpacing.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.glassStroke,
                              borderRadius: BorderRadius.circular(
                                InkRadii.chip,
                              ),
                            ),
                            child: Text(
                              '${block.summary[uid]?.name ?? uid}'
                              ' • ${block.summary[uid]?.ops ?? 0}',
                              style: InkType.caption(tokens.inkSecondary),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionMenu extends StatelessWidget {
  final VoidCallback onPreview;
  final VoidCallback onRestore;

  const _VersionMenu({required this.onPreview, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return PopupMenuButton<String>(
      tooltip: 'Version actions',
      icon: Icon(LucideIcons.ellipsisVertical, size: 16, color: tokens.inkMuted),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'preview') onPreview();
        if (value == 'restore') onRestore();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'preview',
          child: Text('Preview version'),
        ),
        PopupMenuItem(
          value: 'restore',
          child: Text('Restore to this version…'),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: InkType.caption(color)),
      ],
    );
  }
}

class _UndoRequestRow extends StatelessWidget {
  static final ButtonStyle _actionStyle = TextButton.styleFrom(
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s8, vertical: 4),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  final UndoRequest request;
  final VoidCallback onReview;
  final VoidCallback onDeny;

  const _UndoRequestRow({
    required this.request,
    required this.onReview,
    required this.onDeny,
  });

  String get _age {
    final createdAt = request.createdAt;
    if (createdAt == null) return '';
    final delta = DateTime.now().difference(createdAt);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: InkSpacing.s8),
      padding: const EdgeInsets.all(InkSpacing.s8),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
        border: Border.all(color: tokens.pending.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.requesterName,
                  style: InkType.bodyStrong(tokens.ink),
                ),
              ),
              if (_age.isNotEmpty)
                Text(_age, style: InkType.caption(tokens.inkMuted)),
            ],
          ),
          Text(
            '${request.targetElementIds.length} element(s)',
            style: InkType.caption(tokens.inkMuted),
          ),
          const SizedBox(height: 2),
          Text(
            request.reason.isEmpty ? 'No reason given.' : request.reason,
            style: InkType.caption(tokens.inkSecondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: InkSpacing.s4),
          // Wrap + compact buttons so a narrow tray can never overflow here.
          Wrap(
            spacing: InkSpacing.s4,
            children: [
              TextButton.icon(
                onPressed: onReview,
                style: _actionStyle,
                icon: const Icon(LucideIcons.eye, size: 14),
                label: const Text('Review'),
              ),
              TextButton.icon(
                onPressed: onDeny,
                style: _actionStyle,
                icon: const Icon(LucideIcons.x, size: 14),
                label: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Owns its own [TextEditingController] so the field is never used after being
/// disposed while the dialog route animates out.
class _DenyNoteDialog extends StatefulWidget {
  const _DenyNoteDialog();

  @override
  State<_DenyNoteDialog> createState() => _DenyNoteDialogState();
}

class _DenyNoteDialogState extends State<_DenyNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline undo request'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Optional note for the requester',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
