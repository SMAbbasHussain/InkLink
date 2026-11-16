import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../geometry/canvas_element_geometry.dart';
import '../../models/canvas_element.dart';
import '../widgets/sliding_tray.dart';

/// Layer groups with an active drawing target.
///
/// Layers are paint bands: the Default band is always bottom-most, then each
/// layer by ascending `z`. New elements join the active layer. Membership is
/// stored on the [LayerElement] as a list of element ids, so element payloads
/// stay unchanged.
class LayersTray extends StatelessWidget {
  final bool isOpen;
  final List<CanvasElement> elements;
  final Set<String> selectedIds;
  final String? selectedShapeId;
  final String? activeLayerId;
  final bool canEdit;
  final ValueChanged<String> onSelect;
  final void Function(String id, bool visible) onToggleVisibility;
  final void Function(String id, bool locked) onToggleLock;
  final void Function(String id, double opacity) onOpacityChanged;
  final void Function(String id, int newIndex) onReorder;
  final void Function(String id, String? layerId)? onMoveToLayer;
  final void Function(String layerId, int newIndex)? onReorderLayer;
  final ValueChanged<String?> onSetActiveLayer;
  final ValueChanged<String> onAddLayer;
  final void Function(String layerId, String name) onRenameLayer;
  final void Function(String layerId, String blendMode)? onBlendModeChanged;
  final ValueChanged<String> onDeleteLayer;
  final VoidCallback? onClose;

  const LayersTray({
    super.key,
    required this.isOpen,
    required this.elements,
    required this.selectedIds,
    required this.selectedShapeId,
    required this.activeLayerId,
    required this.canEdit,
    required this.onSelect,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onOpacityChanged,
    required this.onReorder,
    this.onMoveToLayer,
    this.onReorderLayer,
    required this.onSetActiveLayer,
    required this.onAddLayer,
    required this.onRenameLayer,
    this.onBlendModeChanged,
    required this.onDeleteLayer,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final order = canvasPaintOrder(elements);
    final ascendingLayers = <LayerElement>[
      for (final band in order.bands)
        if (band.layer != null) band.layer!,
    ];
    final layerIndexById = <String, int>{
      for (var i = 0; i < ascendingLayers.length; i++) ascendingLayers[i].id: i,
    };
    // The tray lists topmost first; the paint order is bottom-first.
    final sections = <_Section>[
      for (final band in order.bands.reversed)
        if (band.layer != null)
          _Section(
            layer: band.layer!,
            children: band.elements.reversed.toList(growable: false),
          ),
    ];
    final defaultBand = order.bands.firstWhere((band) => band.layer == null);
    final orphans = defaultBand.elements.reversed.toList(growable: false);

    final resolvedActiveId =
        ascendingLayers.any((layer) => layer.id == activeLayerId)
        ? activeLayerId
        : null;
    final activeName = resolvedActiveId == null
        ? 'Default'
        : ascendingLayers
              .firstWhere((layer) => layer.id == resolvedActiveId)
              .name;

    void reorderWithin(
      List<CanvasElement> topFirst,
      int oldIndex,
      int newIndex,
    ) {
      if (!canEdit) return;
      if (newIndex > oldIndex) newIndex -= 1;
      if (newIndex == oldIndex) return;
      HapticFeedback.lightImpact();
      // The bloc takes a bottom-to-top band index; rows are top-first.
      onReorder(topFirst[oldIndex].id, topFirst.length - 1 - newIndex);
    }

    VoidCallback? moveLayer(LayerElement layer, int delta) {
      final index = layerIndexById[layer.id];
      if (!canEdit || onReorderLayer == null || index == null) return null;
      final target = index + delta;
      if (target < 0 || target >= ascendingLayers.length) return null;
      return () => onReorderLayer!(layer.id, target);
    }

    Widget rowFor(CanvasElement element, int index) {
      // The key must sit on ReorderableListView's direct child, so it goes on
      // whichever wrapper is outermost.
      final rowKey = ValueKey('layer-${element.id}');
      final row = _LayerRow(
        index: index,
        element: element,
        canEdit: canEdit,
        selected:
            selectedIds.contains(element.id) || selectedShapeId == element.id,
        onSelect: () => onSelect(element.id),
        onToggleVisibility: () =>
            onToggleVisibility(element.id, element.hidden),
        onToggleLock: () => onToggleLock(element.id, !element.locked),
        onOpacityChanged: (value) => onOpacityChanged(element.id, value),
      );
      if (!canEdit || onMoveToLayer == null) {
        return KeyedSubtree(key: rowKey, child: row);
      }
      // Long-press drag moves membership between bands; the grip handle still
      // reorders inside the band.
      return LongPressDraggable<String>(
        key: rowKey,
        data: element.id,
        delay: const Duration(milliseconds: 220),
        feedback: _LayerDragFeedback(
          label: _labelForElement(element),
          icon: _iconForElement(element),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: row),
        child: row,
      );
    }

    Widget sectionContent(_Section section) {
      if (section.children.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
          child: Text(
            'Empty layer — draw to fill it',
            style: TextStyle(fontSize: 11, color: tokens.inkMuted),
          ),
        );
      }
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        itemCount: section.children.length,
        onReorder: (oldIndex, newIndex) =>
            reorderWithin(section.children, oldIndex, newIndex),
        itemBuilder: (context, index) => rowFor(section.children[index], index),
      );
    }

    Widget dropTarget(String? layerId, Widget child) {
      if (!canEdit || onMoveToLayer == null) return child;
      return _LayerDropTarget(
        key: ValueKey('layer-drop-${layerId ?? 'default'}'),
        onAccept: (elementId) => onMoveToLayer!(elementId, layerId),
        child: child,
      );
    }

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.right,
      title: 'Layers',
      width: 294,
      height: 470,
      bottomOffset: 60,
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Drawing into $activeName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.inkMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: canEdit
                      ? () => _promptLayerName(
                          context,
                          title: 'New layer',
                          confirmLabel: 'Create',
                          onSubmit: onAddLayer,
                        )
                      : null,
                  icon: Icon(LucideIcons.plus, size: 16, color: tokens.accent),
                  label: Text(
                    'New layer',
                    style: TextStyle(fontSize: 12, color: tokens.accent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sections.isEmpty && orphans.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No layers yet.\nCreate one, then draw into it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: tokens.inkMuted),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final section in sections)
                        dropTarget(
                          section.layer.id,
                          _LayerHeader(
                            name: section.layer.name,
                            blendMode: section.layer.blendMode,
                            count: section.children.length,
                            active: section.layer.id == resolvedActiveId,
                            canEdit: canEdit,
                            onActivate: () =>
                                onSetActiveLayer(section.layer.id),
                            onRename: () => _promptLayerName(
                              context,
                              title: 'Rename layer',
                              confirmLabel: 'Rename',
                              initialValue: section.layer.name,
                              onSubmit: (name) =>
                                  onRenameLayer(section.layer.id, name),
                            ),
                            onDelete: () => onDeleteLayer(section.layer.id),
                            onBlendModeChanged: onBlendModeChanged == null
                                ? null
                                : (mode) => onBlendModeChanged!(
                                    section.layer.id,
                                    mode,
                                  ),
                            onMoveUp: moveLayer(section.layer, 1),
                            onMoveDown: moveLayer(section.layer, -1),
                            child: sectionContent(section),
                          ),
                        ),
                      if (orphans.isNotEmpty || sections.isEmpty)
                        dropTarget(
                          null,
                          _LayerHeader(
                            name: 'Default',
                            count: orphans.length,
                            active: resolvedActiveId == null,
                            canEdit: false,
                            onActivate: () => onSetActiveLayer(null),
                            child: orphans.isEmpty
                                ? const SizedBox.shrink()
                                : ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      0,
                                      8,
                                      6,
                                    ),
                                    itemCount: orphans.length,
                                    onReorder: (oldIndex, newIndex) =>
                                        reorderWithin(
                                          orphans,
                                          oldIndex,
                                          newIndex,
                                        ),
                                    itemBuilder: (context, index) =>
                                        rowFor(orphans[index], index),
                                  ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptLayerName(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required ValueChanged<String> onSubmit,
    String initialValue = '',
  }) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _LayerNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
      ),
    );
    if (name == null || name.isEmpty) return;
    onSubmit(name);
  }
}

/// Owns its text controller so disposal happens after the dialog animation.
class _LayerNameDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialValue;

  const _LayerNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue = '',
  });

  @override
  State<_LayerNameDialog> createState() => _LayerNameDialogState();
}

class _LayerNameDialogState extends State<_LayerNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Layer name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _Section {
  final LayerElement layer;
  final List<CanvasElement> children;

  const _Section({required this.layer, required this.children});
}

class _LayerHeader extends StatelessWidget {
  final String name;
  final String blendMode;
  final int count;
  final bool active;
  final bool canEdit;
  final VoidCallback onActivate;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<String>? onBlendModeChanged;
  final Widget child;

  const _LayerHeader({
    required this.name,
    this.blendMode = 'normal',
    required this.count,
    required this.active,
    required this.canEdit,
    required this.onActivate,
    required this.child,
    this.onRename,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.onBlendModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(
        color: active ? tokens.accent.withValues(alpha: 0.08) : tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.chip),
        border: Border.all(color: active ? tokens.accent : tokens.glassStroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(InkRadii.chip),
            onTap: onActivate,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    active ? LucideIcons.folderOpen : LucideIcons.folder,
                    size: 16,
                    color: active ? tokens.accent : tokens.inkMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 10, color: tokens.inkMuted),
                  ),
                  if (active)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        LucideIcons.check,
                        size: 14,
                        color: tokens.accent,
                      ),
                    ),
                  if (onRename != null && canEdit)
                    PopupMenuButton<String>(
                      tooltip: 'Layer actions',
                      icon: Icon(
                        LucideIcons.ellipsis,
                        size: 16,
                        color: tokens.inkMuted,
                      ),
                      onSelected: (value) {
                        if (value == 'rename') onRename?.call();
                        if (value == 'delete') onDelete?.call();
                        if (value == 'up') onMoveUp?.call();
                        if (value == 'down') onMoveDown?.call();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'up',
                          enabled: onMoveUp != null,
                          child: const Text('Move up'),
                        ),
                        PopupMenuItem(
                          value: 'down',
                          enabled: onMoveDown != null,
                          child: const Text('Move down'),
                        ),
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete layer'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (canEdit && onBlendModeChanged != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 6, 4),
              child: Row(
                children: [
                  Text(
                    'Blend',
                    style: TextStyle(fontSize: 10, color: tokens.inkMuted),
                  ),
                  const Spacer(),
                  DropdownButton<String>(
                    value:
                        const {
                          'normal',
                          'multiply',
                          'screen',
                          'overlay',
                          'darken',
                          'lighten',
                        }.contains(blendMode)
                        ? blendMode
                        : 'normal',
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 11, color: tokens.inkSecondary),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(
                        value: 'multiply',
                        child: Text('Multiply'),
                      ),
                      DropdownMenuItem(value: 'screen', child: Text('Screen')),
                      DropdownMenuItem(
                        value: 'overlay',
                        child: Text('Overlay'),
                      ),
                      DropdownMenuItem(value: 'darken', child: Text('Darken')),
                      DropdownMenuItem(
                        value: 'lighten',
                        child: Text('Lighten'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) onBlendModeChanged?.call(mode);
                    },
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _LayerRow extends StatefulWidget {
  final int index;
  final CanvasElement element;
  final bool canEdit;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisibility;
  final VoidCallback onToggleLock;
  final ValueChanged<double> onOpacityChanged;

  const _LayerRow({
    required this.index,
    required this.element,
    required this.canEdit,
    required this.selected,
    required this.onSelect,
    required this.onToggleVisibility,
    required this.onToggleLock,
    required this.onOpacityChanged,
  });

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  /// Live value while the thumb is dragged; committed on release so a single
  /// drag writes one CRDT operation instead of dozens.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final element = widget.element;
    final opacity = (_dragValue ?? element.opacity).clamp(0.0, 1.0);
    final dimmed = element.hidden;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: widget.selected
            ? tokens.accent.withValues(alpha: 0.10)
            : tokens.paper,
        borderRadius: BorderRadius.circular(InkRadii.chip),
        border: Border.all(
          color: widget.selected ? tokens.accent : tokens.glassStroke,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(InkRadii.chip),
        onTap: widget.canEdit ? widget.onSelect : null,
        child: Opacity(
          opacity: dimmed ? 0.55 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 4, 0),
                child: Row(
                  children: [
                    Icon(
                      _iconForElement(element),
                      size: 15,
                      color: element.locked
                          ? tokens.inkMuted
                          : (widget.selected ? tokens.accent : tokens.ink),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _labelForElement(element),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: tokens.ink,
                          decoration: element.hidden
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: tokens.inkMuted,
                        ),
                      ),
                    ),
                    _iconButton(
                      tooltip: element.hidden ? 'Show layer' : 'Hide layer',
                      icon: element.hidden
                          ? LucideIcons.eyeOff
                          : LucideIcons.eye,
                      color: element.hidden ? tokens.inkMuted : tokens.ink,
                      onPressed: widget.canEdit
                          ? widget.onToggleVisibility
                          : null,
                    ),
                    _iconButton(
                      tooltip: element.locked ? 'Unlock layer' : 'Lock layer',
                      icon: element.locked
                          ? LucideIcons.lock
                          : LucideIcons.unlock,
                      color: element.locked ? tokens.accent : tokens.inkMuted,
                      onPressed: widget.canEdit ? widget.onToggleLock : null,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (widget.canEdit)
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          LucideIcons.gripVertical,
                          size: 14,
                          color: tokens.inkMuted,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 26),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                      ),
                      child: Slider(
                        value: opacity,
                        onChanged: widget.canEdit
                            ? (value) => setState(() => _dragValue = value)
                            : null,
                        onChangeEnd: widget.canEdit
                            ? (value) {
                                setState(() => _dragValue = null);
                                widget.onOpacityChanged(value);
                              }
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${(opacity * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, color: tokens.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 16,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed();
            },
      icon: Icon(
        icon,
        size: 16,
        color: onPressed == null ? color.withValues(alpha: 0.4) : color,
      ),
    );
  }
}

IconData _iconForElement(CanvasElement element) {
  return switch (element) {
    StrokeElement _ => LucideIcons.penLine,
    ShapeElement _ => LucideIcons.square,
    TextElement _ => LucideIcons.type,
    ImageElement _ => LucideIcons.image,
    StickyNoteElement _ => LucideIcons.stickyNote,
    FrameElement _ => LucideIcons.frame,
    ConnectorElement _ => LucideIcons.spline,
    LayerElement _ => LucideIcons.folder,
  };
}

String _labelForElement(CanvasElement element) {
  final raw = switch (element) {
    StrokeElement _ => 'Stroke',
    ShapeElement e => e.shapeType.name,
    TextElement e =>
      e.text.trim().isEmpty ? 'Text' : e.text.trim().replaceAll('\n', ' '),
    ImageElement _ => 'Image',
    StickyNoteElement e =>
      e.text.trim().isEmpty
          ? 'Sticky note'
          : e.text.trim().replaceAll('\n', ' '),
    FrameElement e => e.title.trim().isEmpty ? 'Frame' : e.title.trim(),
    ConnectorElement _ => 'Connector',
    LayerElement e => e.name,
  };
  if (raw.isEmpty) return 'Layer';
  return raw[0].toUpperCase() + raw.substring(1);
}

/// Highlights a layer header while an element row is dragged over it.
class _LayerDropTarget extends StatelessWidget {
  final ValueChanged<String> onAccept;
  final Widget child;

  const _LayerDropTarget({
    super.key,
    required this.onAccept,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InkRadii.chip + 2),
            border: hovering
                ? Border.all(color: tokens.accent, width: 2)
                : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// Small drag preview shown while moving an element between layers.
class _LayerDragFeedback extends StatelessWidget {
  final String label;
  final IconData icon;

  const _LayerDragFeedback({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(InkRadii.chip),
          border: Border.all(color: tokens.accent),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tokens.accent),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
