import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_text_field.dart';

/// A searchable object in the board outline.
class CanvasSearchEntry {
  final String id;
  final String label;
  final String detail;
  final IconData icon;
  final Offset center;
  final bool isComment;

  const CanvasSearchEntry({
    required this.id,
    required this.label,
    required this.detail,
    required this.icon,
    required this.center,
    this.isComment = false,
  });
}

class CanvasSearchSheet extends StatefulWidget {
  final List<CanvasSearchEntry> entries;
  final ValueChanged<CanvasSearchEntry> onSelected;
  final VoidCallback? onClose;

  const CanvasSearchSheet({
    super.key,
    required this.entries,
    required this.onSelected,
    this.onClose,
  });

  @override
  State<CanvasSearchSheet> createState() => _CanvasSearchSheetState();
}

class _CanvasSearchSheetState extends State<CanvasSearchSheet> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.entries
        : widget.entries
              .where(
                (entry) =>
                    entry.label.toLowerCase().contains(query) ||
                    entry.detail.toLowerCase().contains(query),
              )
              .toList(growable: false);
    final listHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(
      160.0,
      360.0,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Find on board', style: InkType.title(tokens.ink)),
            ),
            if (widget.onClose != null)
              IconButton(
                tooltip: 'Close search',
                icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s8),
        InkTextField(
          controller: _controller,
          autofocus: true,
          leadingIcon: LucideIcons.search,
          hintText: 'Search text, notes, labels, frames and comments',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: InkSpacing.s12),
        SizedBox(
          height: listHeight,
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'There is nothing on this board yet.'
                        : 'No matches for “${_query.trim()}”.',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: InkSpacing.s4),
                  itemBuilder: (context, index) {
                    final entry = matches[index];
                    return Semantics(
                      button: true,
                      label: '${entry.label}. ${entry.detail}',
                      child: Material(
                        color: tokens.glass.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(InkRadii.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(InkRadii.card),
                          onTap: () => widget.onSelected(entry),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: InkSpacing.s12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  entry.icon,
                                  size: 18,
                                  color: tokens.accent,
                                ),
                                const SizedBox(width: InkSpacing.s12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: InkType.bodyStrong(tokens.ink),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.detail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: InkType.caption(tokens.inkMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  LucideIcons.arrowUpRight,
                                  size: 16,
                                  color: tokens.inkMuted,
                                ),
                              ],
                            ),
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
