import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';

/// Shared appearance controls for two or more selected objects.
class CanvasSelectionStyleSheet extends StatefulWidget {
  final int count;
  final double initialOpacity;
  final bool allLocked;
  final bool allVisible;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onOpacity;
  final ValueChanged<bool> onLockedChanged;
  final ValueChanged<bool> onVisibleChanged;
  final VoidCallback? onClose;

  const CanvasSelectionStyleSheet({
    super.key,
    required this.count,
    required this.initialOpacity,
    required this.allLocked,
    required this.allVisible,
    required this.onColor,
    required this.onOpacity,
    required this.onLockedChanged,
    required this.onVisibleChanged,
    this.onClose,
  });

  static const List<Color> palette = <Color>[
    Color(0xFF111827),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFF64748B),
  ];

  @override
  State<CanvasSelectionStyleSheet> createState() =>
      _CanvasSelectionStyleSheetState();
}

class _CanvasSelectionStyleSheetState extends State<CanvasSelectionStyleSheet> {
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _opacity = widget.initialOpacity.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Style ${widget.count} objects',
                style: InkType.title(tokens.ink),
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                tooltip: 'Close style controls',
                icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s12),
        Text('Colour', style: InkType.bodyStrong(tokens.ink)),
        const SizedBox(height: InkSpacing.s8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final color in CanvasSelectionStyleSheet.palette)
              Semantics(
                button: true,
                label: 'Apply colour ${color.toARGB32().toRadixString(16)}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => widget.onColor(color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s16),
        Row(
          children: [
            Text('Opacity', style: InkType.bodyStrong(tokens.ink)),
            const Spacer(),
            Text(
              '${(_opacity * 100).round()}%',
              style: InkType.caption(tokens.inkMuted),
            ),
          ],
        ),
        Slider(
          value: _opacity,
          min: 0,
          max: 1,
          divisions: 20,
          label: '${(_opacity * 100).round()}%',
          onChanged: (value) => setState(() => _opacity = value),
          onChangeEnd: widget.onOpacity,
        ),
        const SizedBox(height: InkSpacing.s4),
        Row(
          children: [
            Expanded(
              child: _toggle(
                tokens,
                icon: widget.allLocked ? LucideIcons.lock : LucideIcons.unlock,
                label: widget.allLocked ? 'Unlock selection' : 'Lock selection',
                active: widget.allLocked,
                onTap: () => widget.onLockedChanged(!widget.allLocked),
              ),
            ),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: _toggle(
                tokens,
                icon: widget.allVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                label: widget.allVisible ? 'Hide selection' : 'Show selection',
                active: !widget.allVisible,
                onTap: () => widget.onVisibleChanged(!widget.allVisible),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toggle(
    InkTokens tokens, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? tokens.accent.withValues(alpha: 0.12) : tokens.field,
      borderRadius: BorderRadius.circular(InkRadii.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(InkRadii.chip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? tokens.accent : tokens.inkSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InkType.caption(
                    active ? tokens.accent : tokens.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
