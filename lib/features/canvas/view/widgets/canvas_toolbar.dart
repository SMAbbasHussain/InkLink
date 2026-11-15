import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../models/canvas_tool_mode.dart';

/// The single primary tool strip for the canvas.
///
/// Every tool is one tap away; deep options still live in the sliding trays.
/// Viewers see the same strip with edit tools disabled so the board reads as
/// read-only instead of broken.
class CanvasToolbar extends StatelessWidget {
  const CanvasToolbar({
    super.key,
    required this.activeTool,
    required this.canEdit,
    required this.onToolSelected,
    this.onStickyNote,
    this.onImage,
    this.onMore,
    this.isArrowPreset = false,
  });

  final CanvasToolMode activeTool;
  final bool canEdit;
  final ValueChanged<CanvasToolMode> onToolSelected;
  final VoidCallback? onStickyNote;
  final VoidCallback? onImage;
  final VoidCallback? onMore;
  final bool isArrowPreset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Material(
      color: tokens.paper,
      elevation: 8,
      borderRadius: BorderRadius.circular(InkRadii.glassBar),
      // A horizontal scroll view expands to its parent's full height in the
      // cross axis; without an explicit height the toolbar would leave a large
      // empty slab below the buttons.
      child: SizedBox(
        height: 56,
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              icon: LucideIcons.mousePointer2,
              label: 'Select',
              tooltip: 'Select and move',
              selected: activeTool == CanvasToolMode.select,
              enabled: true,
              onTap: () => onToolSelected(CanvasToolMode.select),
            ),
            _ToolButton(
              icon: LucideIcons.penLine,
              label: 'Pen',
              tooltip: canEdit ? 'Pen' : 'Viewer: drawing disabled',
              selected: activeTool == CanvasToolMode.doodle,
              enabled: canEdit,
              onTap: () => onToolSelected(CanvasToolMode.doodle),
            ),
            _ToolButton(
              icon: LucideIcons.highlighter,
              label: 'Highlight',
              tooltip: canEdit
                  ? 'Highlighter: wide translucent marker'
                  : 'Viewer: drawing disabled',
              selected: activeTool == CanvasToolMode.highlight,
              enabled: canEdit,
              onTap: () => onToolSelected(CanvasToolMode.highlight),
            ),
            _ToolButton(
              icon: LucideIcons.eraser,
              label: 'Eraser',
              tooltip: canEdit ? 'Eraser' : 'Viewer: erasing disabled',
              selected: activeTool == CanvasToolMode.eraser,
              enabled: canEdit,
              onTap: () => onToolSelected(CanvasToolMode.eraser),
            ),
            _ToolButton(
              icon: LucideIcons.shapes,
              label: 'Shape',
              tooltip: canEdit ? 'Shape' : 'Viewer: editing disabled',
              selected: activeTool == CanvasToolMode.shape && !isArrowPreset,
              enabled: canEdit,
              onTap: () => onToolSelected(CanvasToolMode.shape),
            ),
            _ToolButton(
              icon: LucideIcons.arrowRight,
              label: 'Arrow',
              tooltip: canEdit
                  ? 'Arrow: drag, or tap two elements to connect'
                  : 'Viewer: editing disabled',
              selected: isArrowPreset || activeTool == CanvasToolMode.arrow,
              enabled: canEdit,
              onTap: () => onToolSelected(CanvasToolMode.arrow),
            ),
            _ToolButton(
              icon: LucideIcons.stickyNote,
              label: 'Sticky',
              tooltip: canEdit ? 'Sticky note' : 'Viewer: editing disabled',
              selected: false,
              enabled: canEdit && onStickyNote != null,
              onTap: onStickyNote,
            ),
            _ToolButton(
              icon: LucideIcons.type,
              label: 'Text',
              tooltip: canEdit ? 'Text: tap the canvas to add' : 'Viewer',
              selected: activeTool == CanvasToolMode.text,
              enabled: canEdit,
              onTap: () => onToolSelected(CanvasToolMode.text),
            ),
            _ToolButton(
              icon: LucideIcons.image,
              label: 'Image',
              tooltip: canEdit ? 'Add image' : 'Viewer: editing disabled',
              selected: activeTool == CanvasToolMode.image,
              enabled: canEdit && onImage != null,
              onTap: onImage,
            ),
            _ToolButton(
              icon: LucideIcons.slidersHorizontal,
              label: 'More',
              tooltip: 'More tools',
              selected: false,
              enabled: onMore != null,
              onTap: onMore,
            ),
          ],
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
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

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
