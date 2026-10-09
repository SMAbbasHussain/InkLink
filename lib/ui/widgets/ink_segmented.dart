import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';
import 'glass_panel.dart';

/// A glass segmented control. The selected segment is solid `ink` with
/// inverse text.
class InkSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const InkSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final inverse = tokens.isDark ? Colors.black : Colors.white;

    return GlassPanel(
      radius: InkRadii.segmentedTab + 4,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? tokens.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(InkRadii.segmentedTab),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: InkType.label(
                      i == selectedIndex ? inverse : tokens.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
