import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../models/board_template.dart';

/// Pick a starting layout. Kept as a plain widget so the gallery can be
/// tested without opening a route.
class TemplateGallerySheet extends StatelessWidget {
  final List<BoardTemplate> templates;
  final ValueChanged<BoardTemplate> onSelected;
  final VoidCallback? onClose;

  const TemplateGallerySheet({
    super.key,
    required this.templates,
    required this.onSelected,
    this.onClose,
  });

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
            if (onClose != null)
              IconButton(
                icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                onPressed: onClose,
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s4),
        Text(
          'Templates are added in one undoable step.',
          style: InkType.caption(tokens.inkMuted),
        ),
        const SizedBox(height: InkSpacing.s16),
        SizedBox(
          height: 380,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: InkSpacing.s8),
            itemBuilder: (context, index) {
              final template = templates[index];
              final (icon, accent) = _styleFor(template.category);
              return Material(
                color: tokens.glass.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(InkRadii.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(InkRadii.card),
                  onTap: () => onSelected(template),
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
