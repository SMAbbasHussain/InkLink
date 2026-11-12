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
class UserHistoryTimeline extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () =>
                  bloc.add(const CanvasHistoryUserTimelineExited()),
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
                displayName,
                style: InkType.bodyStrong(tokens.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state.isHistoryLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.accentText,
                ),
              ),
          ],
        ),
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
              separatorBuilder: (_, _) => const SizedBox(height: InkSpacing.s4),
              itemBuilder: (context, index) =>
                  _OperationRow(operation: state.userOps[index]),
            ),
          ),
        if (state.hasMoreUserOps) ...[
          const SizedBox(height: InkSpacing.s8),
          InkButton.secondary(
            label: 'Load older',
            compact: true,
            onPressed: () => bloc.add(
              CanvasHistoryUserOpsRequested(
                targetUid,
                beforeVersion: state.userOpsNextBeforeVersion,
              ),
            ),
          ),
        ],
        const SizedBox(height: InkSpacing.s8),
        InkButton.danger(
          label: "Revert this user's work",
          compact: true,
          onPressed: () =>
              bloc.add(CanvasHistoryRevertUserRequested(targetUid)),
        ),
      ],
    );
  }
}

class _OperationRow extends StatelessWidget {
  final BoardOperation operation;

  const _OperationRow({required this.operation});

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

  String get _subtitle {
    final stamp = operation.timestamp;
    final time = stamp == null
        ? ''
        : ' • ${stamp.hour.toString().padLeft(2, '0')}:'
              '${stamp.minute.toString().padLeft(2, '0')}';
    final elementId = operation.elementId;
    final target = elementId != null && elementId.isNotEmpty
        ? elementId
        : '${operation.changes.length} element(s)';
    return '${operation.action} $target$time';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s8,
        vertical: InkSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 14, color: tokens.inkSecondary),
          const SizedBox(width: InkSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _subtitle,
                  style: InkType.caption(tokens.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'v${operation.version}',
                  style: InkType.caption(tokens.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
