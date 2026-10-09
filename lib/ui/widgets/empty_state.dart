import 'package:flutter/material.dart';

import '../theme/ink_colors.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'sticky_note.dart';

/// A sticky note holding an icon and the screen's existing empty-state copy.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.color = InkColors.stickyButter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s32),
        child: StickyNote(
          color: color,
          tiltId: text,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: InkColors.stickyInkFor(color)),
              const SizedBox(height: InkSpacing.s12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: InkType.body(InkColors.stickyInkFor(color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
