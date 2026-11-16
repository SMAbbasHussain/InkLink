import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/history/board_operation.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../bloc/canvas_bloc.dart';

/// One user's full action history across blocks (D15). Newest first, paged
/// with `beforeVersion`; R2 access happens through the socket service.
///
/// Tapping a row opens the past/current compare preview for that op; the
/// trailing undo undoes that single op (the revert review sheet confirms).
/// "Select" enters multi-select whose "Undo N selected" plans the revert of
/// every chosen op at once. "Replay changes" scrubs this user's changes
/// op-by-op on the canvas, starting at their latest change.
class UserHistoryTimeline extends StatefulWidget {
  final CanvasState state;
  final CanvasBloc bloc;
  final String targetUid;
  final String displayName;

  const UserHistoryTimeline({
    super.key,
    required this.state,
    required this.bloc,
    required this.targetUid,
    required this.displayName,
  });

  @override
  State<UserHistoryTimeline> createState() => _UserHistoryTimelineState();
}

class _UserHistoryTimelineState extends State<UserHistoryTimeline> {
  bool _selectMode = false;
  final Set<int> _selectedVersions = <int>{};

  CanvasState get state => widget.state;
  CanvasBloc get bloc => widget.bloc;

  bool get _selecting => _selectMode;
  int get _selectedCount => _selectedVersions.length;

  void _enterSelection() => setState(() => _selectMode = true);

  void _exitSelection() =>
      setState(() {
        _selectMode = false;
        _selectedVersions.clear();
      });

  void _toggleSelect(BoardOperation op) {
    setState(() {
      if (!_selectedVersions.add(op.version)) {
        _selectedVersions.remove(op.version);
      }
    });
  }

  void _undoSelected() {
    final versions = _selectedVersions.toList(growable: false)..sort();
    if (versions.isEmpty) return;
    bloc.add(CanvasHistoryRevertOpsRequested(versions));
    _exitSelection();
  }

  void _undoOne(BoardOperation op) =>
      bloc.add(CanvasHistoryRevertOpsRequested([op.version]));

  void _openCompare(BoardOperation op) =>
      bloc.add(CanvasHistoryOpCompareRequested(op));

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(tokens),
        const SizedBox(height: InkSpacing.s8),
        if (state.userOps.isEmpty && !state.isHistoryLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s16),
            child: Text(
              'No operations recorded for this user yet.',
              style: InkType.caption(tokens.inkMuted),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: state.userOps.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: InkSpacing.s4),
              itemBuilder: (context, index) => _OperationRow(
                operation: state.userOps[index],
                selecting: _selecting,
                selected: _selectedVersions.contains(
                  state.userOps[index].version,
                ),
                onOpen: _openCompare,
                onUndo: _undoOne,
                onToggleSelect: _toggleSelect,
              ),
            ),
          ),
        if (state.hasMoreUserOps) ...[
          const SizedBox(height: InkSpacing.s8),
          InkButton.secondary(
            label: 'Load older',
            compact: true,
            onPressed: () => bloc.add(
              CanvasHistoryUserOpsRequested(
                widget.targetUid,
                beforeVersion: state.userOpsNextBeforeVersion,
              ),
            ),
          ),
        ],
        if (_selecting) ...[
          const SizedBox(height: InkSpacing.s8),
          Row(
            children: [
              Expanded(
                child: InkButton.secondary(
                  label: 'Cancel',
                  compact: true,
                  onPressed: _exitSelection,
                ),
              ),
              const SizedBox(width: InkSpacing.s8),
              Expanded(
                child: InkButton.danger(
                  label: 'Undo $_selectedCount selected',
                  compact: true,
                  onPressed: _selectedCount == 0 ? null : _undoSelected,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: InkSpacing.s8),
        InkButton.danger(
          label: "Revert this user's work",
          compact: true,
          onPressed: () =>
              bloc.add(CanvasHistoryRevertUserRequested(widget.targetUid)),
        ),
      ],
    );
  }

  Widget _buildHeader(InkTokens tokens) {
    return Row(
      children: [
        InkWell(
          onTap: () => bloc.add(const CanvasHistoryUserTimelineExited()),
          borderRadius: BorderRadius.circular(InkRadii.chip),
          child: Padding(
            padding: const EdgeInsets.all(InkSpacing.s4),
            child: Icon(
              LucideIcons.chevronLeft,
              size: 18,
              color: tokens.inkSecondary,
            ),
          ),
        ),
        const SizedBox(width: InkSpacing.s4),
        Expanded(
          child: Text(
            widget.displayName,
            style: InkType.bodyStrong(tokens.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (state.isHistoryLoading)
          Padding(
            padding: const EdgeInsets.only(right: InkSpacing.s8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.accentText,
              ),
            ),
          ),
        if (_selecting)
          InkButton.secondary(
            label: 'Cancel',
            compact: true,
            expand: false,
            onPressed: _exitSelection,
          )
        else ...[
          InkButton.secondary(
            label: 'Select',
            compact: true,
            expand: false,
            onPressed: state.userOps.isEmpty ? null : _enterSelection,
          ),
          const SizedBox(width: InkSpacing.s8),
          InkButton.secondary(
            label: 'Replay changes',
            icon: const Icon(LucideIcons.play),
            compact: true,
            expand: false,
            onPressed: state.userOps.isEmpty
                ? null
                : () =>
                      bloc.add(CanvasHistoryUserScrubRequested(widget.targetUid)),
          ),
        ],
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  final BoardOperation operation;
  final bool selecting;
  final bool selected;
  final ValueChanged<BoardOperation> onOpen;
  final ValueChanged<BoardOperation> onUndo;
  final ValueChanged<BoardOperation> onToggleSelect;

  const _OperationRow({
    required this.operation,
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onUndo,
    required this.onToggleSelect,
  });

  IconData get _icon {
    switch (operation.action) {
      case 'delete':
        return LucideIcons.trash2;
      case 'clear':
        return LucideIcons.eraser;
      case 'restore':
        return LucideIcons.history;
      case 'revert':
        return LucideIcons.undo2;
      default:
        return LucideIcons.pencil;
    }
  }

  /// Plain-English headline (server summary first), with the same generic
  /// fallbacks the log previously used — never a raw element id.
  String get _headline {
    return operation.headline ?? _fallbackLabel;
  }

  String get _fallbackLabel {
    final n = operation.changes.length;
    switch (operation.action) {
      case 'clear':
        return 'Cleared the board';
      case 'restore':
        final from = operation.restoredFromVersion;
        return from == null
            ? 'Restored the board'
            : 'Restored the board to version $from';
      case 'revert':
        return n > 0 ? 'Reverted $n change(s)' : 'Reverted changes';
      case 'delete':
        return n > 0 ? 'Removed $n element(s)' : 'Removed an element';
      case 'add':
        return n > 0 ? 'Added $n element(s)' : 'Added an element';
      default:
        return n > 0 ? 'Edited $n element(s)' : 'Edited the board';
    }
  }

  String get _meta {
    final stamp = operation.timestamp;
    final time = stamp == null
        ? ''
        : ' • ${stamp.hour.toString().padLeft(2, '0')}:'
              '${stamp.minute.toString().padLeft(2, '0')}';
    return 'v${operation.version}$time';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkWell(
      onTap: () => selecting ? onToggleSelect(operation) : onOpen(operation),
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s8,
          vertical: InkSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.field,
          borderRadius: BorderRadius.circular(InkRadii.chip),
        ),
        child: Row(
          children: [
            if (selecting) ...[
              Icon(
                selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                size: 16,
                color: selected ? tokens.accentText : tokens.inkMuted,
              ),
              const SizedBox(width: InkSpacing.s8),
            ],
            Icon(_icon, size: 14, color: tokens.inkSecondary),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline,
                    style: InkType.caption(tokens.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _meta,
                    style: InkType.caption(tokens.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: InkSpacing.s4),
            selecting
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: () => onUndo(operation),
                    borderRadius: BorderRadius.circular(InkRadii.chip),
                    child: Padding(
                      padding: const EdgeInsets.all(InkSpacing.s4),
                      child: Icon(
                        LucideIcons.undo2,
                        size: 15,
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
