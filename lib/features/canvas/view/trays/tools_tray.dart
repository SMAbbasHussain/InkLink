import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_type.dart';
import '../widgets/sliding_tray.dart';

class ToolsTray extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClearAll;
  final VoidCallback? onAddStickyNote;
  final VoidCallback? onAddConnector;
  final VoidCallback? onExport;
  final VoidCallback? onClose;

  const ToolsTray({
    super.key,
    required this.isOpen,
    required this.onUndo,
    required this.onRedo,
    required this.onClearAll,
    this.onAddStickyNote,
    this.onAddConnector,
    this.onExport,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SlidingTray(
      isOpen: isOpen,
      direction: TrayDirection.left,
      title: 'Editing Tools',
      height: 440,
      width: 230,
      bottomOffset: 60,
      onClose: onClose,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (onAddStickyNote != null) ...[
              _ToolButton(
                icon: Icons.note_alt_outlined,
                label: 'Sticky Note',
                color: Colors.amber.shade700,
                onTap: onAddStickyNote!,
              ),
              const SizedBox(height: 10),
            ],
            if (onAddConnector != null) ...[
              _ToolButton(
                icon: Icons.alt_route_rounded,
                label: 'Connector / Link',
                color: Colors.teal,
                onTap: onAddConnector!,
              ),
              const SizedBox(height: 10),
            ],
            _ToolButton(
              icon: LucideIcons.undo2,
              label: 'Undo',
              color: tokens.ink,
              onTap: onUndo,
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: LucideIcons.redo2,
              label: 'Redo',
              color: tokens.ink,
              onTap: onRedo,
            ),
            const SizedBox(height: 10),
            _ToolButton(
              icon: LucideIcons.trash2,
              label: 'Clear All',
              color: tokens.danger,
              onTap: onClearAll,
            ),
            if (onExport != null) ...[
              const SizedBox(height: 10),
              _ToolButton(
                icon: Icons.ios_share_rounded,
                label: 'Export & Share',
                color: Colors.deepPurple,
                onTap: onExport!,
              ),
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
      onTap: onTap,
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
            Text(label, style: InkType.bodyStrong(color)),
          ],
        ),
      ),
    );
  }
}
