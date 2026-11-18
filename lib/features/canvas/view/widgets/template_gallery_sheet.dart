import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../models/board_template.dart';

/// Pick a starting layout. Kept as a plain widget so the gallery can be
/// tested without opening a route.
class TemplateGallerySheet extends StatefulWidget {
  final List<BoardTemplate> templates;
  final ValueChanged<BoardTemplate> onSelected;
  final VoidCallback? onClose;

  const TemplateGallerySheet({
    super.key,
    required this.templates,
    required this.onSelected,
    this.onClose,
  });

  @override
  State<TemplateGallerySheet> createState() => _TemplateGallerySheetState();
}

class _TemplateGallerySheetState extends State<TemplateGallerySheet> {
  String _selectedCategory = 'All';

  static (IconData, Color) _styleFor(String category) => switch (category) {
    'Ideas' => (LucideIcons.lightbulb, const Color(0xFFD97706)),
    'Diagram' => (LucideIcons.workflow, const Color(0xFF2563EB)),
    'Workshop' => (LucideIcons.users, const Color(0xFF7C3AED)),
    'Planning' => (LucideIcons.calendarDays, const Color(0xFF16A34A)),
    _ => (LucideIcons.frame, const Color(0xFF64748B)),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final categories = <String>[
      'All',
      ...{for (final t in widget.templates) t.category},
    ];
    final filtered = _selectedCategory == 'All'
        ? widget.templates
        : widget.templates
              .where((t) => t.category == _selectedCategory)
              .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Start from a template',
                style: InkType.title(tokens.ink),
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s4),
        Text(
          'Templates are added in one undoable step.',
          style: InkType.caption(tokens.inkMuted),
        ),
        if (categories.length > 2) ...[
          const SizedBox(height: InkSpacing.s12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        category,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _selectedCategory == category,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: InkSpacing.s12),
        SizedBox(
          height: 360,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: InkSpacing.s8),
            itemBuilder: (context, index) {
              final template = filtered[index];
              final (icon, accent) = _styleFor(template.category);
              return Material(
                color: tokens.glass.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(InkRadii.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(InkRadii.card),
                  onTap: () => widget.onSelected(template),
                  child: Padding(
                    padding: const EdgeInsets.all(InkSpacing.s12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(InkRadii.chip),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(icon, size: 21, color: accent),
                        ),
                        const SizedBox(width: InkSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                style: InkType.bodyStrong(tokens.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                template.description,
                                style: InkType.caption(tokens.inkMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                template.category.toUpperCase(),
                                style: InkType.caption(accent).copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: tokens.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
