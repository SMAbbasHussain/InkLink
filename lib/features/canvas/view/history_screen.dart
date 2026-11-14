import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../domain/models/history/board_activity_block.dart';
import '../../../domain/models/history/undo_request.dart';
import '../../../domain/services/history/board_history_service.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../bloc/canvas_bloc.dart';
import 'widgets/user_history_timeline.dart';

/// Section filter for the owner's board history.
enum HistoryFilter { all, versions, restores, requests }

/// Quick time windows for the history screen. [custom] uses a picked range.
enum HistoryTimeFilter { all, today, last7Days, last30Days, custom }

const String _allUsersValue = '__all_users__';

/// Owner-only board history: archived versions, the people who made them and
/// the undo requests waiting on a decision (D3/D5).
///
/// This is a dedicated route rather than a tray. It filters the activity log
/// by contributor, time window, section and free text, and keeps the
/// conflict/request workflow in the same place as the log.
class BoardHistoryScreen extends StatefulWidget {
  final String boardId;
  final String? boardTitle;
  final CanvasBloc bloc;
  final BoardHistoryService? historyService;

  const BoardHistoryScreen({
    super.key,
    required this.boardId,
    required this.bloc,
    this.boardTitle,
    this.historyService,
  });

  @override
  State<BoardHistoryScreen> createState() => _BoardHistoryScreenState();
}

class _BoardHistoryScreenState extends State<BoardHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  HistoryFilter _filter = HistoryFilter.all;
  HistoryTimeFilter _timeFilter = HistoryTimeFilter.all;
  DateTimeRange? _customRange;
  String _selectedUser = _allUsersValue;

  @override
  void initState() {
    super.initState();
    // The activity feed is live, but subscribe explicitly so opening history
    // from any path starts the listener even if the tray previously did it.
    widget.bloc.add(const CanvasHistoryFeedRequested());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? get _userFilterUid =>
      _selectedUser == _allUsersValue ? null : _selectedUser;

  bool get _hasActiveFilters =>
      _selectedUser != _allUsersValue ||
      _timeFilter != HistoryTimeFilter.all ||
      _filter != HistoryFilter.all ||
      _search.text.trim().isNotEmpty;

  DateTimeRange? get _effectiveRange {
    final now = DateTime.now();
    switch (_timeFilter) {
      case HistoryTimeFilter.all:
        return null;
      case HistoryTimeFilter.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case HistoryTimeFilter.last7Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case HistoryTimeFilter.last30Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case HistoryTimeFilter.custom:
        return _customRange;
    }
  }

  bool _inRange(DateTime? stamp) {
    final range = _effectiveRange;
    if (range == null) return true;
    if (stamp == null) return false;
    return !stamp.isBefore(range.start) && !stamp.isAfter(range.end);
  }

  bool _blockInRange(BoardActivityBlock block) {
    final range = _effectiveRange;
    if (range == null) return true;
    final start = block.firstOpAt;
    final end = block.lastOpAt;
    if (start == null || end == null) return false;
    return !end.isBefore(range.start) && !start.isAfter(range.end);
  }

  bool _matchesQuery(BoardActivityBlock block) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final range = 'v${block.fromVersion} v${block.toVersion}'.toLowerCase();
    if (range.contains(query)) return true;
    if (block.restores.any((restore) {
      final label =
          'restored v${restore.restoredFromVersion ?? restore.atVersion}';
      return label.contains(query);
    })) {
      return true;
    }
    for (final uid in block.contributorUids) {
      final name = block.summary[uid]?.name.toLowerCase() ?? uid.toLowerCase();
      if (name.contains(query)) return true;
    }
    return false;
  }

  bool _matchesRequestQuery(UndoRequest request) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return request.requesterName.toLowerCase().contains(query) ||
        request.reason.toLowerCase().contains(query);
  }

  List<BoardActivityBlock> _visibleBlocks(CanvasState state) {
    if (_filter == HistoryFilter.requests) return const [];
    final uid = _userFilterUid;
    final blocks = state.activityBlocks
        .where((block) {
          if (_filter == HistoryFilter.restores && block.restores.isEmpty) {
            return false;
          }
          if (uid != null &&
              !block.contributorUids.contains(uid) &&
              !block.summary.containsKey(uid) &&
              !block.restores.any((restore) => restore.byUid == uid)) {
            return false;
          }
          if (!_blockInRange(block)) return false;
          return _matchesQuery(block);
        })
        .toList(growable: false);
    blocks.sort((a, b) => b.toVersion.compareTo(a.toVersion));
    return blocks;
  }

  List<UndoRequest> _visibleRequests(CanvasState state) {
    if (_filter == HistoryFilter.versions) return const [];
    final uid = _userFilterUid;
    final requests = state.undoRequests
        .where((request) {
          if (!request.isPending) return false;
          if (uid != null && request.requesterUid != uid) return false;
          if (!_inRange(request.createdAt)) return false;
          return _matchesRequestQuery(request);
        })
        .toList(growable: false);
    requests.sort((a, b) {
      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated == null || bCreated == null) return 0;
      return bCreated.compareTo(aCreated);
    });
    return requests;
  }

  bool get _showRequests =>
      _filter == HistoryFilter.all || _filter == HistoryFilter.requests;

  int get _latestVersion => widget.bloc.state.activityBlocks.isEmpty
      ? 0
      : widget.bloc.state.activityBlocks
            .map((block) => block.toVersion)
            .reduce((a, b) => a > b ? a : b);

  Map<String, String> _people(CanvasState state) {
    final people = <String, String>{};
    for (final block in state.activityBlocks) {
      for (final uid in block.contributorUids) {
        final name = block.summary[uid]?.name.trim();
        if (name != null && name.isNotEmpty) {
          people[uid] = name;
        } else {
          people.putIfAbsent(uid, () => 'Contributor');
        }
      }
      for (final restore in block.restores) {
        final uid = restore.byUid;
        if (uid != null && uid.isNotEmpty) {
          people.putIfAbsent(uid, () => 'Contributor');
        }
      }
    }
    for (final request in state.undoRequests) {
      if (request.requesterUid.isNotEmpty) {
        people[request.requesterUid] = request.requesterName;
      }
    }
    for (final member in state.boardMembers) {
      people.putIfAbsent(member.uid, () => member.label);
    }
    return people;
  }

  String _displayNameFor(CanvasState state, String uid) {
    return _people(state)[uid] ?? 'User';
  }

  /// A history preview is rendered on the canvas behind this route. Leave the
  /// history screen so the owner can actually see the preview banner/canvas.
  void _returnToCanvasForPreview() {
    final route = ModalRoute.of(context);
    if (route != null && !route.isFirst) {
      Navigator.of(context).pop();
    }
  }

  /// Opens the version's scrub preview on the canvas: it starts on the
  /// block's last state and the banner slider moves back op-by-op.
  void _openPreview(BoardActivityBlock block) {
    _returnToCanvasForPreview();
    widget.bloc.add(CanvasHistoryVersionScrubRequested(block));
  }

  void _openRequestEvidence(UndoRequest request) {
    _returnToCanvasForPreview();
    widget.bloc.add(CanvasHistoryRequestEvidenceRequested(request.requestId));
  }

  void _openUserTimeline(String uid) {
    final range = _effectiveRange;
    widget.bloc.add(
      CanvasHistoryUserOpsRequested(
        uid,
        fromTime: range?.start,
        toTime: range?.end,
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _customRange,
      helpText: 'Filter history by date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        ),
      );
      _timeFilter = HistoryTimeFilter.custom;
    });
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _selectedUser = _allUsersValue;
      _timeFilter = HistoryTimeFilter.all;
      _customRange = null;
      _filter = HistoryFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return BlocListener<CanvasBloc, CanvasState>(
      bloc: widget.bloc,
      listenWhen: (previous, current) =>
          !previous.isViewingHistory && current.isViewingHistory,
      listener: (_, _) => _returnToCanvasForPreview(),
      child: BlocBuilder<CanvasBloc, CanvasState>(
        bloc: widget.bloc,
        builder: (context, state) {
          return Scaffold(
            backgroundColor: tokens.paper,
            appBar: AppBar(
              backgroundColor: tokens.paper,
              surfaceTintColor: Colors.transparent,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Board history', style: InkType.title(tokens.ink)),
                  if (widget.boardTitle != null &&
                      widget.boardTitle!.trim().isNotEmpty)
                    Text(
                      widget.boardTitle!,
                      style: InkType.caption(tokens.inkSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh history',
                  onPressed: () =>
                      widget.bloc.add(const CanvasHistoryFeedRequested()),
                  icon: Icon(
                    LucideIcons.refreshCw,
                    size: 18,
                    color: tokens.inkSecondary,
                  ),
                ),
              ],
            ),
            body: state.selectedUserUid != null
                ? _buildUserTimeline(context, state)
                : _buildHistory(context, state),
          );
        },
      ),
    );
  }

  Widget _buildUserTimeline(BuildContext context, CanvasState state) {
    final uid = state.selectedUserUid!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: Column(
            children: [
              Expanded(
                child: UserHistoryTimeline(
                  state: state,
                  bloc: widget.bloc,
                  targetUid: uid,
                  displayName: _displayNameFor(state, uid),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(BuildContext context, CanvasState state) {
    final tokens = context.ink;
    final blocks = _visibleBlocks(state);
    final requests = _visibleRequests(state);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            InkSpacing.gutter,
            InkSpacing.s8,
            InkSpacing.gutter,
            InkSpacing.s32,
          ),
          children: [
            if (state.isHistoryLoading)
              LinearProgressIndicator(
                minHeight: 2,
                color: tokens.accentText,
                backgroundColor: tokens.field,
              ),
            Text(
              state.activityBlocks.isEmpty
                  ? 'No archived versions yet'
                  : 'Latest v$_latestVersion · '
                        '${state.activityBlocks.length} version(s)'
                        '${state.undoRequests.where((r) => r.isPending).isEmpty ? '' : ' · ${state.undoRequests.where((r) => r.isPending).length} request(s)'}',
              style: InkType.caption(tokens.inkMuted),
            ),
            const SizedBox(height: InkSpacing.s12),
            _buildFilterPanel(tokens, state),
            const SizedBox(height: InkSpacing.s16),
            if (_hasActiveFilters)
              Padding(
                padding: const EdgeInsets.only(bottom: InkSpacing.s8),
                child: Text(
                  'Showing ${blocks.length} version(s) and '
                  '${requests.length} pending request(s) after filters.',
                  style: InkType.caption(tokens.inkMuted),
                ),
              ),
            if (_showRequests && requests.isNotEmpty) ...[
              _SectionHeader(
                label: 'Undo requests',
                trailing: '${requests.length} waiting',
              ),
              ...requests.map(
                (request) => _UndoRequestRow(
                  request: request,
                  onReview: () => widget.bloc.add(
                    CanvasHistoryUndoRequestReviewRequested(request.requestId),
                  ),
                  onEvidence: () => _openRequestEvidence(request),
                  onDeny: () => _denyRequest(context, request),
                ),
              ),
              const SizedBox(height: InkSpacing.s8),
            ],
            if (_filter != HistoryFilter.requests) ...[
              const _SectionHeader(label: 'Versions'),
              if (blocks.isEmpty)
                Text(
                  _emptyVersionsMessage(state),
                  style: InkType.caption(tokens.inkMuted),
                )
              else
                ...blocks.map(
                  (block) => _BlockRow(
                    block: block,
                    onPreview: () => _openPreview(block),
                    onRestore: () => _confirmRestore(block),
                    onSelectContributor: _openUserTimeline,
                  ),
                ),
            ],
            if (_filter == HistoryFilter.requests && requests.isEmpty)
              Text(
                state.undoRequests.any((request) => request.isPending)
                    ? 'No pending requests match these filters.'
                    : 'No undo requests right now. Members can ask you to '
                          'undo their own recent edits from the tools tray.',
                style: InkType.caption(tokens.inkMuted),
              ),
            if (_filter == HistoryFilter.all &&
                requests.isEmpty &&
                blocks.isEmpty &&
                state.activityBlocks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: InkSpacing.s8),
                child: Text(
                  'Nothing matches these filters.',
                  style: InkType.caption(tokens.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(InkTokens tokens, CanvasState state) {
    final people = _people(state);
    if (_selectedUser != _allUsersValue && !people.containsKey(_selectedUser)) {
      people[_selectedUser] = _selectedUser;
    }
    final peopleEntries = people.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: InkType.body(tokens.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: tokens.field,
            hintText: 'Search versions, people, or reasons',
            hintStyle: InkType.body(tokens.inkMuted),
            prefixIcon: Icon(
              LucideIcons.search,
              size: 16,
              color: tokens.inkMuted,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: InkSpacing.s12,
              vertical: InkSpacing.s12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(InkRadii.input),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.s8),
        LayoutBuilder(
          builder: (context, constraints) {
            final user = _buildDropdown<String>(
              tokens: tokens,
              icon: LucideIcons.users,
              value: _selectedUser,
              items: [
                const DropdownMenuItem<String>(
                  value: _allUsersValue,
                  child: Text('All users'),
                ),
                ...peopleEntries.map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedUser = value);
              },
            );
            final time = _buildDropdown<HistoryTimeFilter>(
              tokens: tokens,
              icon: LucideIcons.calendar,
              value: _timeFilter,
              items: [
                const DropdownMenuItem(
                  value: HistoryTimeFilter.all,
                  child: Text('Any time'),
                ),
                const DropdownMenuItem(
                  value: HistoryTimeFilter.today,
                  child: Text('Today'),
                ),
                const DropdownMenuItem(
                  value: HistoryTimeFilter.last7Days,
                  child: Text('Last 7 days'),
                ),
                const DropdownMenuItem(
                  value: HistoryTimeFilter.last30Days,
                  child: Text('Last 30 days'),
                ),
                const DropdownMenuItem(
                  value: HistoryTimeFilter.custom,
                  child: Text('Custom range'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == HistoryTimeFilter.custom) {
                  _pickCustomRange();
                } else {
                  setState(() => _timeFilter = value);
                }
              },
            );
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  user,
                  const SizedBox(height: InkSpacing.s8),
                  time,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: user),
                const SizedBox(width: InkSpacing.s8),
                Expanded(child: time),
              ],
            );
          },
        ),
        if (_timeFilter == HistoryTimeFilter.custom &&
            _customRange != null) ...[
          const SizedBox(height: InkSpacing.s4),
          Text(
            '${_formatDate(_customRange!.start)} – '
            '${_formatDate(_customRange!.end)}',
            style: InkType.caption(tokens.inkMuted),
          ),
        ],
        const SizedBox(height: InkSpacing.s8),
        _buildFilterChips(tokens, state),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required InkTokens tokens,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s8),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.input),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tokens.inkMuted),
          const SizedBox(width: InkSpacing.s4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                icon: Icon(
                  LucideIcons.chevronDown,
                  size: 15,
                  color: tokens.inkMuted,
                ),
                style: InkType.body(tokens.ink),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(InkTokens tokens, CanvasState state) {
    final entries = <HistoryFilter, String>{
      HistoryFilter.all: 'All',
      HistoryFilter.versions: 'Versions',
      HistoryFilter.restores: 'Restores',
      HistoryFilter.requests:
          state.undoRequests.where((r) => r.isPending).isEmpty
          ? 'Requests'
          : 'Requests (${state.undoRequests.where((r) => r.isPending).length})',
    };
    return Wrap(
      spacing: InkSpacing.s4,
      runSpacing: InkSpacing.s4,
      children: [
        ...entries.entries.map((entry) {
          final selected = _filter == entry.key;
          return InkWell(
            onTap: () => setState(() => _filter = entry.key),
            borderRadius: BorderRadius.circular(InkRadii.chip),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: InkSpacing.s8,
                vertical: 4,
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
        }),
        if (_hasActiveFilters)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(LucideIcons.filterX, size: 14),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: InkSpacing.s8,
                vertical: 4,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _emptyVersionsMessage(CanvasState state) {
    if (state.activityBlocks.isEmpty) {
      return 'History appears after the first block is archived '
          '(500 ops or a 5-minute flush).';
    }
    if (_hasActiveFilters) {
      return 'No archived versions match these filters.';
    }
    return 'No version in this list contains a restore.';
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
    } catch (_) {
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
          padding: const EdgeInsets.all(InkSpacing.s12),
          decoration: BoxDecoration(
            color: tokens.field,
            borderRadius: BorderRadius.circular(InkRadii.input),
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
      icon: Icon(
        LucideIcons.ellipsisVertical,
        size: 16,
        color: tokens.inkMuted,
      ),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'preview') onPreview();
        if (value == 'restore') onRestore();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'preview', child: Text('Preview version')),
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
  final VoidCallback onEvidence;
  final VoidCallback onDeny;

  const _UndoRequestRow({
    required this.request,
    required this.onReview,
    required this.onEvidence,
    required this.onDeny,
  });

  String get _selectionSummary {
    final n = request.targetElementIds.length;
    final elements = '$n element${n == 1 ? '' : 's'}';
    final area = request.area;
    if (area != null && area.isValid) {
      return '$elements · area ${area.width.round()} × '
          '${area.height.round()} px';
    }
    return elements;
  }

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
      padding: const EdgeInsets.all(InkSpacing.s12),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.input),
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
          Text(_selectionSummary, style: InkType.caption(tokens.inkMuted)),
          const SizedBox(height: 2),
          Text(
            request.reason.isEmpty ? 'No reason given.' : request.reason,
            style: InkType.caption(tokens.inkSecondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: InkSpacing.s4),
          Wrap(
            spacing: InkSpacing.s4,
            children: [
              TextButton.icon(
                onPressed: onEvidence,
                style: _actionStyle,
                icon: const Icon(LucideIcons.scan, size: 14),
                label: const Text('Evidence'),
              ),
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
