import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/widgets/canvas_toolbar_action_meta.dart';
import '../../models/canvas_tool_mode.dart';

/// The customizable primary bottom strip for the canvas.
///
/// Renders [actions] in the user's chosen order plus a trailing "More" button
/// to open the bottom-right tools tray. Shrink-wraps to fit cleanly even when
/// only 1 or 2 actions are pinned, and scrolls horizontally when many are set.
class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.canEdit,
    required this.onToolSelected,
    this.actions = CanvasToolbarAction.defaultBottomBarActions,
    this.onActionSelected,
    this.onActionLongPressed,
    this.onShape,
    this.onStickyNote,
    this.onFrame,
    this.onImage,
    this.onLayers,
    this.onTemplates,
    this.onTable,
    this.onConnector,
    this.onMore,
    this.isArrowPreset = false,
    this.isShapesPopupOpen = false,
    this.isLayersOpen = false,
    this.isToolsTrayOpen = false,
  });

  final CanvasToolMode activeTool;
  final bool canEdit;
  final List<CanvasToolbarAction> actions;
  final ValueChanged<CanvasToolMode> onToolSelected;
  final ValueChanged<CanvasToolbarAction>? onActionSelected;
  final ValueChanged<CanvasToolbarAction>? onActionLongPressed;
  final VoidCallback? onShape;
  final VoidCallback? onStickyNote;
  final VoidCallback? onFrame;
  final VoidCallback? onImage;
  final VoidCallback? onLayers;
  final VoidCallback? onTemplates;
  final VoidCallback? onTable;
  final VoidCallback? onConnector;
  final VoidCallback? onMore;
  final bool isArrowPreset;
  final bool isShapesPopupOpen;
  final bool isLayersOpen;
  final bool isToolsTrayOpen;

  bool _isSelected(CanvasToolbarAction action) => switch (action) {
    CanvasToolbarAction.select => activeTool == CanvasToolMode.select,
    CanvasToolbarAction.hand => activeTool == CanvasToolMode.hand,
    CanvasToolbarAction.pen => activeTool == CanvasToolMode.doodle,
    CanvasToolbarAction.highlight => activeTool == CanvasToolMode.highlight,
    CanvasToolbarAction.eraser => activeTool == CanvasToolMode.eraser,
    CanvasToolbarAction.fill => activeTool == CanvasToolMode.fill,
    CanvasToolbarAction.shape =>
      isShapesPopupOpen || (activeTool == CanvasToolMode.shape && !isArrowPreset),
    CanvasToolbarAction.arrow =>
      isArrowPreset || activeTool == CanvasToolMode.arrow,
    CanvasToolbarAction.text => activeTool == CanvasToolMode.text,
    CanvasToolbarAction.image => activeTool == CanvasToolMode.image,
    CanvasToolbarAction.layers => isLayersOpen,
    _ => false,
  };

  VoidCallback? _handlerFor(CanvasToolbarAction action) {
    if (!canEdit && action.requiresEdit) return null;
    if (onActionSelected != null) {
      return () => onActionSelected!(action);
    }
    return switch (action) {
      CanvasToolbarAction.select => () => onToolSelected(CanvasToolMode.select),
      CanvasToolbarAction.hand => () => onToolSelected(CanvasToolMode.hand),
      CanvasToolbarAction.pen => () => onToolSelected(CanvasToolMode.doodle),
      CanvasToolbarAction.highlight =>
        () => onToolSelected(CanvasToolMode.highlight),
      CanvasToolbarAction.eraser => () => onToolSelected(CanvasToolMode.eraser),
      CanvasToolbarAction.fill => () => onToolSelected(CanvasToolMode.fill),
      CanvasToolbarAction.shape =>
        onShape ?? () => onToolSelected(CanvasToolMode.shape),
      CanvasToolbarAction.arrow => () => onToolSelected(CanvasToolMode.arrow),
      CanvasToolbarAction.stickyNote => onStickyNote,
      CanvasToolbarAction.frame => onFrame,
      CanvasToolbarAction.text => () => onToolSelected(CanvasToolMode.text),
      CanvasToolbarAction.image => onImage,
      CanvasToolbarAction.layers => onLayers,
      CanvasToolbarAction.templates => onTemplates,
      CanvasToolbarAction.table => onTable,
      CanvasToolbarAction.connector => onConnector,
    };
  }

  String _tooltipFor(CanvasToolbarAction action, bool enabled) {
    if (!enabled) {
      return switch (action) {
        CanvasToolbarAction.pen ||
        CanvasToolbarAction.highlight => 'Viewer: drawing disabled',
        CanvasToolbarAction.eraser => 'Viewer: erasing disabled',
        _ => 'Viewer: editing disabled',
      };
    }
    return '${action.label}: ${action.description}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final buttons = <Widget>[
      for (final action in actions)
        () {
          final handler = _handlerFor(action);
          final enabled = handler != null && (!action.requiresEdit || canEdit);
          return _ToolButton(
            icon: iconForCanvasToolbarAction(action),
            label: action.shortLabel,
            tooltip: _tooltipFor(action, enabled),
            selected: _isSelected(action),
            enabled: enabled,
            onTap: handler,
            onLongPress: onActionLongPressed == null
                ? null
                : () => onActionLongPressed!(action),
          );
        }(),
      if (onMore != null)
        _ToolButton(
          icon: LucideIcons.layoutGrid,
          label: 'More',
          tooltip: 'All tools & board options',
          selected: isToolsTrayOpen,
          enabled: true,
          onTap: onMore,
        ),
    ];

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: tokens.paper,
      elevation: 8,
      borderRadius: BorderRadius.circular(InkRadii.glassBar),
      // Fixed cross-axis height keeps the horizontally scrollable strip slim;
      // Row(mainAxisSize: min) ensures 1 or 2 buttons stay compact and centered
      // instead of stretching across empty horizontal space.
      child: SizedBox(
        height: 56,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: buttons,
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final foreground = !enabled
        ? tokens.inkMuted.withValues(alpha: 0.45)
        : selected
        ? tokens.accent
        : tokens.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
