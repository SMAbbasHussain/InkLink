import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../widgets/sliding_tray.dart';

/// Bottom-left sliding tray holding authoritative / non-art board controls:
/// Undo, Redo, History, Request undo, Canvas Settings, Export & Share, and
/// Clear All.
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
  final VoidCallback? onCanvasSettings;
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
    this.onCanvasSettings,
    this.onExport,
    this.onHistory,
    this.onRequestUndo,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final buttons = <Widget>[
      if (canEdit && onCanvasSettings != null)
        _ToolButton(
          icon: LucideIcons.slidersHorizontal,
          label: 'Canvas Settings',
          color: tokens.inkSecondary,
          onTap: onCanvasSettings!,
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

    final desiredHeight = _chromeHeight + buttons.length * _rowHeight;
    final media = MediaQuery.of(context);
    final maxHeight = math.max(150.0, media.size.height - media.padding.top - 124);
    final trayHeight = math.min(desiredHeight, maxHeight);

    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.left,
      title: 'Board & History',
      height: trayHeight,
      width: 230,
      bottomOffset: 60,
      onClose: onClose,
      child: SingleChildScrollView(
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
