import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/canvas/canvas_toolbar_action.dart';
import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'canvas_toolbar_action_meta.dart';
import 'ink_button.dart';

/// Opens a modal sheet letting the user choose which [CanvasToolbarAction]s
/// appear on their canvas bottom bar and in what order.
Future<List<CanvasToolbarAction>?> showBottomBarCustomizerSheet(
  BuildContext context, {
  required List<CanvasToolbarAction> initialActions,
}) {
  return showModalBottomSheet<List<CanvasToolbarAction>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => _BottomBarCustomizerSheet(initialActions: initialActions),
  );
}

class _BottomBarCustomizerSheet extends StatefulWidget {
  final List<CanvasToolbarAction> initialActions;

  const _BottomBarCustomizerSheet({required this.initialActions});

  @override
  State<_BottomBarCustomizerSheet> createState() =>
      _BottomBarCustomizerSheetState();
}

class _BottomBarCustomizerSheetState extends State<_BottomBarCustomizerSheet> {
  late List<CanvasToolbarAction> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialActions.isEmpty
        ? [CanvasToolbarAction.select]
        : List<CanvasToolbarAction>.of(widget.initialActions);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
    HapticFeedback.selectionClick();
  }

  void _moveItem(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _selected.length) return;
    setState(() {
      final item = _selected.removeAt(index);
      _selected.insert(target, item);
    });
    HapticFeedback.selectionClick();
  }

  void _removeAction(CanvasToolbarAction action) {
    if (_selected.length <= 1) return;
    setState(() => _selected.remove(action));
    HapticFeedback.selectionClick();
  }

  void _addAction(CanvasToolbarAction action) {
    if (_selected.contains(action)) return;
    setState(() => _selected.add(action));
    HapticFeedback.selectionClick();
  }

  void _resetToDefault() {
    setState(() {
      _selected = List<CanvasToolbarAction>.of(
        CanvasToolbarAction.defaultBottomBarActions,
      );
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final trayOnly = CanvasToolbarAction.actionsNotOnBar(_selected);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Material(
          color: tokens.surfaceDesk,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.inkMuted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customize Bottom Bar',
                                style: InkType.title(tokens.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose tools for your bar and drag to reorder. '
                                'Remaining tools stay in the bottom-right tray.',
                                style: InkType.caption(tokens.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _resetToDefault,
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Live preview pill showing exact shrink-wrapped alignment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.field,
                    borderRadius: BorderRadius.circular(InkRadii.card),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Preview (${_selected.length} pinned)',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 470),
                          child: Material(
                            color: tokens.paper,
                            elevation: 4,
                            borderRadius:
                                BorderRadius.circular(InkRadii.glassBar),
                            child: SizedBox(
                              height: 54,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final action in _selected)
                                      _PreviewActionPill(action: action),
                                    const _PreviewMorePill(),
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
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'ON BOTTOM BAR (${_selected.length})',
                            style: InkType.caption(tokens.inkMuted),
                          ),
                          const Spacer(),
                          Text(
                            'Drag to reorder',
                            style: InkType.caption(tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: tokens.paper,
                      borderRadius: BorderRadius.circular(InkRadii.card),
                      clipBehavior: Clip.antiAlias,
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _selected.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final action = _selected[index];
                          final canRemove = _selected.length > 1;
                          return Column(
                            key: ValueKey('bar-action-${action.id}'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                Divider(height: 1, color: tokens.glassStroke),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          LucideIcons.gripVertical,
                                          size: 18,
                                          color: tokens.inkMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: tokens.accentSoft,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        iconForCanvasToolbarAction(action),
                                        size: 17,
                                        color: tokens.accentText,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            action.label,
                                            style: InkType.bodyStrong(
                                              tokens.ink,
                                            ),
                                          ),
                                          Text(
                                            action.description,
                                            style: InkType.caption(
                                              tokens.inkMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Move up',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        LucideIcons.chevronUp,
                                        size: 16,
                                        color: index > 0
                                            ? tokens.inkMuted
                                            : tokens.inkMuted
                                                .withValues(alpha: 0.3),
                                      ),
                                      onPressed: index > 0
                                          ? () => _moveItem(index, -1)
                                          : null,
                                    ),
                                    IconButton(
                                      tooltip: 'Move down',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        LucideIcons.chevronDown,
                                        size: 16,
                                        color: index < _selected.length - 1
                                            ? tokens.inkMuted
                                            : tokens.inkMuted
                                                .withValues(alpha: 0.3),
                                      ),
                                      onPressed: index < _selected.length - 1
                                          ? () => _moveItem(index, 1)
                                          : null,
                                    ),
                                    IconButton(
                                      tooltip: canRemove
                                          ? 'Remove from bottom bar'
                                          : 'Keep at least 1 action on bar',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        LucideIcons.circleMinus,
                                        size: 18,
                                        color: canRemove
                                            ? tokens.danger
                                            : tokens.inkMuted
                                                .withValues(alpha: 0.35),
                                      ),
                                      onPressed: canRemove
                                          ? () => _removeAction(action)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'IN BOTTOM-RIGHT TRAY (${trayOnly.length})',
                        style: InkType.caption(tokens.inkMuted),
                      ),
                    ),
                    if (trayOnly.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tokens.paper,
                          borderRadius: BorderRadius.circular(InkRadii.card),
                        ),
                        child: Text(
                          'All actions are currently pinned to your bottom bar.',
                          style: InkType.caption(tokens.inkMuted),
                        ),
                      )
                    else
                      Material(
                        color: tokens.paper,
                        borderRadius: BorderRadius.circular(InkRadii.card),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < trayOnly.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: tokens.glassStroke),
                              InkWell(
                                onTap: () => _addAction(trayOnly[i]),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: tokens.field,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          iconForCanvasToolbarAction(
                                            trayOnly[i],
                                          ),
                                          size: 17,
                                          color: tokens.ink,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trayOnly[i].label,
                                              style: InkType.bodyStrong(
                                                tokens.ink,
                                              ),
                                            ),
                                            Text(
                                              trayOnly[i].description,
                                              style: InkType.caption(
                                                tokens.inkMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        LucideIcons.circlePlus,
                                        size: 20,
                                        color: tokens.accent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: tokens.surfaceDesk,
                  border: Border(top: BorderSide(color: tokens.glassStroke)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkButton.secondary(
                        label: 'Cancel',
                        compact: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkButton.primary(
                        label: 'Save bar',
                        compact: true,
                        onPressed: () => Navigator.of(context).pop(_selected),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewActionPill extends StatelessWidget {
  final CanvasToolbarAction action;

  const _PreviewActionPill({required this.action});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconForCanvasToolbarAction(action),
            size: 18,
            color: tokens.ink,
          ),
          const SizedBox(height: 2),
          Text(
            action.shortLabel,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewMorePill extends StatelessWidget {
  const _PreviewMorePill();

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.layoutGrid, size: 18, color: tokens.inkMuted),
          const SizedBox(height: 2),
          Text(
            'More',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: tokens.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
