import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../../../domain/models/history/revert_plan.dart';
import '../../bloc/canvas_bloc.dart';

/// Opens the owner's per-element revert review (D4/D12).
///
/// The [bloc] is passed explicitly because a modal bottom sheet is pushed on
/// the root navigator and therefore is not under the page's BlocProvider.
Future<void> showRevertReviewSheet(
  BuildContext context, {
  required CanvasBloc bloc,
  required RevertPlan plan,
  String? requestId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) => _RevertReviewSheet(
      bloc: bloc,
      plan: plan,
      requestId: requestId ?? plan.requestId,
    ),
  );
}

class _RevertReviewSheet extends StatefulWidget {
  final CanvasBloc bloc;
  final RevertPlan plan;
  final String? requestId;

  const _RevertReviewSheet({
    required this.bloc,
    required this.plan,
    this.requestId,
  });

  @override
  State<_RevertReviewSheet> createState() => _RevertReviewSheetState();
}

class _RevertReviewSheetState extends State<_RevertReviewSheet> {
  late final Map<String, String> _decisions;

  @override
  void initState() {
    super.initState();
    // Clean items default to revert; conflicted items default to keep.
    _decisions = {
      for (final item in widget.plan.items)
        item.elementId: item.conflict ? 'keep' : 'revert',
    };
  }

  int get _revertCount =>
      _decisions.values.where((d) => d == 'revert').length;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final items = widget.plan.items;
    final isRestore = widget.plan.mode == 'restore';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.all(InkSpacing.s20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isRestore ? 'Restore version' : 'Revert changes',
                        style: InkType.title(tokens.ink),
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                      onPressed: () {
                        widget.bloc.add(const CanvasHistoryPlanDismissed());
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: InkSpacing.s4),
                Text(
                  '$_revertCount of ${items.length} element(s) will change. '
                  'Conflicted elements default to "keep".',
                  style: InkType.caption(tokens.inkMuted),
                ),
                const SizedBox(height: InkSpacing.s12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: InkSpacing.s4,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ReviewRow(
                        item: item,
                        decision: _decisions[item.elementId] ?? 'keep',
                        onChanged: (value) {
                          setState(() => _decisions[item.elementId] = value);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: InkSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: InkButton.secondary(
                        label: 'Cancel',
                        onPressed: () {
                          widget.bloc.add(const CanvasHistoryPlanDismissed());
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: InkSpacing.s12),
                    Expanded(
                      child: InkButton.primary(
                        label: _revertCount == 0 ? 'Apply' : 'Apply ($_revertCount)',
                        onPressed: _revertCount == 0
                            ? () {
                                widget.bloc.add(
                                  const CanvasHistoryPlanDismissed(),
                                );
                                Navigator.pop(context);
                              }
                            : () {
                                widget.bloc.add(
                                  CanvasHistoryApplyRevert(
                                    planId: widget.plan.planId,
                                    decisions: Map<String, String>.from(
                                      _decisions,
                                    ),
                                    requestId: widget.requestId,
                                  ),
                                );
                                Navigator.pop(context);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final RevertPlanItem item;
  final String decision;
  final ValueChanged<String> onChanged;

  const _ReviewRow({
    required this.item,
    required this.decision,
    required this.onChanged,
  });

  IconData get _icon {
    if (item.conflict) return LucideIcons.alertTriangle;
    switch (item.kind) {
      case 'add':
        return LucideIcons.plus;
      case 'delete':
        return LucideIcons.trash2;
      default:
        return LucideIcons.pencil;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final accent = item.conflict ? tokens.danger : tokens.inkSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_icon, size: 16, color: accent),
              const SizedBox(width: InkSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.elementType} • ${item.elementId}',
                      style: InkType.bodyStrong(tokens.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.conflict
                          ? 'Someone modified this after the target edit'
                          : 'Will be ${item.kind == 'delete' ? 'removed' : 'restored'}',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s8),
          // Own line so narrow screens cannot overflow the row.
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'keep', label: Text('Keep')),
                ButtonSegment(value: 'revert', label: Text('Revert')),
              ],
              selected: {decision},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}
