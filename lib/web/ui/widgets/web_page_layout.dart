import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/empty_state.dart';

/// Page title with an optional subtitle and responsive trailing actions.
class WebPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: InkType.headline(tokens.ink)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: InkSpacing.s4),
          Text(subtitle!, style: InkType.body(tokens.inkSecondary)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.s20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (trailing != null && constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: InkSpacing.s12),
                Align(alignment: Alignment.centerLeft, child: trailing!),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: titleBlock),
              if (trailing != null) trailing!,
            ],
          );
        },
      ),
    );
  }
}

/// Constrains lists and forms to a comfortable reading width on wide screens.
class WebReadableWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const WebReadableWidth({super.key, this.maxWidth = 760, required this.child});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Sticky-note empty state reused across web companion sections.
class WebEmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const WebEmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: InkSpacing.s16),
    child: EmptyState(icon: icon, text: text, subtitle: subtitle),
  );
}

/// Selectable pill chip for filters, dialogs, and settings.
class WebChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const WebChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: tokens.accent,
      backgroundColor: tokens.paper,
      labelStyle: InkType.caption(
        selected ? Colors.white : tokens.inkSecondary,
      ),
      side: BorderSide(color: selected ? tokens.accent : tokens.glassStroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

/// Section subheading label above a group of items.
class WebSectionLabel extends StatelessWidget {
  final String text;
  const WebSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: InkSpacing.s8, bottom: InkSpacing.s12),
    child: Text(text, style: InkType.subhead(context.ink.inkSecondary)),
  );
}

/// Search field styled with Desk tokens for web page headers.
class WebSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const WebSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InkRadii.input),
      borderSide: BorderSide(color: tokens.glassStroke),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: InkType.body(tokens.ink),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: InkType.body(tokens.inkMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 18,
          color: tokens.inkSecondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(
                    LucideIcons.x,
                    size: 16,
                    color: tokens.inkSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: tokens.paper,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: tokens.accent, width: 1.5),
        ),
      ),
    );
  }
}
