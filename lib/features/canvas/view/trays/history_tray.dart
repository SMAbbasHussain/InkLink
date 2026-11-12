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

/// Owner-only board history: archived blocks, per-contributor timelines and
/// pending undo requests. Members never see this tray (D3).
class HistoryTray extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final pendingRequests =
        state.undoRequests.where((request) => request.isPending).toList();

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'History',
      width: 300,
      height: 480,
      bottomOffset: 60,
      onClose: onClose,
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: state.selectedUserUid != null
            ? UserHistoryTimeline(
                state: state,
                bloc: bloc,
                targetUid: state.selectedUserUid!,
                displayName: _displayNameFor(state.selectedUserUid!),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.isHistoryLoading) ...[
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: tokens.accentText,
                      backgroundColor: tokens.field,
                    ),
                    const SizedBox(height: InkSpacing.s8),
                  ],
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          'Versions',
                          style: InkType.bodyStrong(tokens.ink),
                        ),
                        const SizedBox(height: InkSpacing.s8),
                        if (state.activityBlocks.isEmpty)
                          Text(
                            'No archived versions yet. History appears after the first block is archived (500 ops or a 5-minute flush).',
                            style: InkType.caption(tokens.inkMuted),
                          )
                        else
                          ...state.activityBlocks.map(
                            (block) => _BlockRow(
                              block: block,
                              onPreview: () => bloc.add(
                                CanvasHistoryPreviewRequested(block.toVersion),
                              ),
                              onSelectContributor: (uid) => bloc.add(
                                CanvasHistoryUserOpsRequested(uid),
                              ),
                            ),
                          ),
                        if (pendingRequests.isNotEmpty) ...[
                          const SizedBox(height: InkSpacing.s16),
                          Text(
                            'Undo requests',
                            style: InkType.bodyStrong(tokens.ink),
                          ),
                          const SizedBox(height: InkSpacing.s8),
                          ...pendingRequests.map(
                            (request) => _UndoRequestRow(
                              request: request,
                              onReview: () => bloc.add(
                                CanvasHistoryUndoRequestReviewRequested(
                                  request.requestId,
                                ),
                              ),
                              onDeny: () => _denyRequest(context, request),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
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

  Future<void> _denyRequest(
    BuildContext context,
    UndoRequest request,
  ) async {
    final service = historyService;
    if (service == null) return;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline undo request'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional note for the requester',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    try {
      await service.resolveUndoRequest(
        boardId: boardId,
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

class _BlockRow extends StatelessWidget {
  final BoardActivityBlock block;
  final VoidCallback onPreview;
  final ValueChanged<String> onSelectContributor;

  const _BlockRow({
    required this.block,
    required this.onPreview,
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
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
                ],
              ),
              const SizedBox(height: 2),
              Text(_range, style: InkType.caption(tokens.inkMuted)),
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
                            borderRadius: BorderRadius.circular(InkRadii.chip),
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
          ),
        ),
      ),
    );
  }
}

class _UndoRequestRow extends StatelessWidget {
  final UndoRequest request;
  final VoidCallback onReview;
  final VoidCallback onDeny;

  const _UndoRequestRow({
    required this.request,
    required this.onReview,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: InkSpacing.s8),
      padding: const EdgeInsets.all(InkSpacing.s8),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.requesterName,
            style: InkType.bodyStrong(tokens.ink),
          ),
          Text(
            '${request.targetElementIds.length} element(s) • ${request.reason}',
            style: InkType.caption(tokens.inkMuted),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: InkSpacing.s4),
          Row(
            children: [
              TextButton.icon(
                onPressed: onReview,
                icon: const Icon(LucideIcons.eye, size: 14),
                label: const Text('Review'),
              ),
              TextButton.icon(
                onPressed: onDeny,
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
