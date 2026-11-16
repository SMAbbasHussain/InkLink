import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../widgets/sliding_tray.dart';

class ToolsTray extends StatelessWidget {
  /// Height of one tool row plus the gap that follows it.
  static const double _rowHeight = 58;

  /// Handle + title bar + divider + content padding.
  static const double _chromeHeight = 92;

  final bool isOpen;
  final bool canEdit;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback? onClearAll;
  final VoidCallback? onAddStickyNote;
  final VoidCallback? onAddConnector;
  final VoidCallback? onCanvasSettings;
  final VoidCallback? onTemplates;
  final VoidCallback? onExport;
  final VoidCallback? onHistory;
  final VoidCallback? onRequestUndo;
  final VoidCallback? onClose;

  const ToolsTray({
    super.key,
    required this.isOpen,
    this.canEdit = true,
    required this.onUndo,
    required this.onRedo,
    this.onClearAll,
    this.onAddStickyNote,
    this.onAddConnector,
    this.onCanvasSettings,
    this.onTemplates,
    this.onExport,
    this.onHistory,
    this.onRequestUndo,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final buttons = <Widget>[
      if (canEdit && onAddStickyNote != null)
        _ToolButton(
          icon: LucideIcons.stickyNote,
          label: 'Sticky Note',
          color: tokens.pending,
          onTap: onAddStickyNote!,
        ),
      if (canEdit && onAddConnector != null)
        _ToolButton(
          icon: LucideIcons.spline,
          label: 'Connector / Link',
          color: tokens.success,
          onTap: onAddConnector!,
        ),
      if (canEdit && onCanvasSettings != null)
        _ToolButton(
          icon: LucideIcons.slidersHorizontal,
          label: 'Canvas Settings',
          color: tokens.inkSecondary,
          onTap: onCanvasSettings!,
        ),
      if (canEdit && onTemplates != null)
        _ToolButton(
          icon: LucideIcons.frame,
          label: 'Templates',
          color: tokens.accent,
          onTap: onTemplates!,
        ),
      if (canEdit) ...[
        _ToolButton(
          icon: LucideIcons.undo2,
          label: 'Undo',
          color: tokens.ink,
          onTap: onUndo,
        ),
        _ToolButton(
          icon: LucideIcons.redo2,
          label: 'Redo',
          color: tokens.ink,
          onTap: onRedo,
        ),
      ],
      if (canEdit && onClearAll != null)
        _ToolButton(
          icon: LucideIcons.trash2,
          label: 'Clear All',
          color: tokens.danger,
          onTap: onClearAll!,
        ),
      if (onHistory != null)
        _ToolButton(
          icon: LucideIcons.history,
          label: 'History',
          color: tokens.accentText,
          onTap: onHistory!,
        ),
      if (canEdit && onRequestUndo != null)
        _ToolButton(
          icon: LucideIcons.undo2,
          label: 'Request undo',
          color: tokens.pending,
          onTap: onRequestUndo!,
        ),
      if (onExport != null)
        _ToolButton(
          icon: LucideIcons.share2,
          label: 'Export & Share',
          color: tokens.accentText,
          onTap: onExport!,
        ),
    ];

    // Size the tray from the rows that are actually shown and cap below the
    // top bar so adding role-specific or tool-specific actions never clips or
    // overlaps the header on smaller viewports.
    final desiredHeight = _chromeHeight + buttons.length * _rowHeight;
    final media = MediaQuery.of(context);
    final maxHeight = math.max(150.0, media.size.height - media.padding.top - 124);
    final trayHeight = math.min(desiredHeight, maxHeight);

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.left,
      title: 'Editing Tools',
      height: trayHeight,
      width: 230,
      bottomOffset: 60,
      onClose: onClose,
      child: SingleChildScrollView(
        // Safety net: the row math can be off on unusual text scales or short viewports.
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: tokens.field,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: InkType.bodyStrong(color),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
