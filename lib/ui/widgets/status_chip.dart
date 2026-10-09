import 'package:flutter/material.dart';

import '../theme/ink_theme.dart';
import '../theme/ink_tokens.dart';
import '../theme/ink_type.dart';

enum InkStatus { pending, accepted, declined, blocked }

/// A dot plus text in the semantic color, on that color at 12%.
class StatusChip extends StatelessWidget {
  final InkStatus status;
  final String? label;

  const StatusChip({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;

    final Color color;
    final String text;
    switch (status) {
      case InkStatus.pending:
        color = tokens.pending;
        text = label ?? 'Pending';
        break;
      case InkStatus.accepted:
        color = tokens.success;
        text = label ?? 'Accepted';
        break;
      case InkStatus.declined:
        color = tokens.danger;
        text = label ?? 'Declined';
        break;
      case InkStatus.blocked:
        color = tokens.danger;
        text = label ?? 'Blocked';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: InkType.caption(color)),
        ],
      ),
    );
  }
}
