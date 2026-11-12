import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../domain/models/history/undo_request.dart';
import '../../../../domain/services/history/board_history_service.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../models/canvas_element.dart';

/// Member → owner escalation (D5). Members select elements from the LIVE
/// canvas only — they never read the log (D3).
///
/// [preselectedIds] pre-ticks the checkboxes (used by the undo-conflict flow,
/// where the conflicted elements are already known).
Future<void> showUndoRequestSheet(
  BuildContext context, {
  required BoardHistoryService service,
  required String boardId,
  required List<CanvasElement> elements,
  List<String>? preselectedIds,
  UndoRequestArea? area,
  VoidCallback? onSelectArea,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => _UndoRequestSheet(
      // Kept for post-pop snackbars: this sheet's own context is deactivated
      // once Navigator.pop runs.
      hostContext: context,
      service: service,
      boardId: boardId,
      elements: elements,
      preselectedIds: preselectedIds,
      area: area,
      onSelectArea: onSelectArea,
    ),
  );
}

class _UndoRequestSheet extends StatefulWidget {
  final BuildContext hostContext;
  final BoardHistoryService service;
  final String boardId;
  final List<CanvasElement> elements;
  final List<String>? preselectedIds;
  final UndoRequestArea? area;
  final VoidCallback? onSelectArea;

  const _UndoRequestSheet({
    required this.hostContext,
    required this.service,
    required this.boardId,
    required this.elements,
    this.preselectedIds,
    this.area,
    this.onSelectArea,
  });

  @override
  State<_UndoRequestSheet> createState() => _UndoRequestSheetState();
}

class _UndoRequestSheetState extends State<_UndoRequestSheet> {
  late final Set<String> _selected;
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  UndoRequestArea? _area;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselectedIds?.toSet() ?? <String>{};
    _area = widget.area;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (_selected.isEmpty) {
      AppSnackBar.showError(context, 'Select at least one element.');
      return;
    }
    if (reason.isEmpty) {
      AppSnackBar.showError(context, 'A reason is required.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.service.submitUndoRequest(
        boardId: widget.boardId,
        elementIds: _selected.toList(growable: false),
        reason: reason,
        area: _area,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (widget.hostContext.mounted) {
        AppSnackBar.showSuccess(
          widget.hostContext,
          'Undo request sent to the board owner.',
        );
      }
    } on HistoryServiceException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.showError(
        context,
        e.message.contains('pending')
            ? 'You already have a pending undo request on this board.'
            : 'Could not send the undo request.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.showError(context, 'Could not send the undo request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.all(InkSpacing.s20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Request an undo',
                        style: InkType.title(tokens.ink),
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  'Pick the elements you want the owner to undo, then explain why.',
                  style: InkType.caption(tokens.inkMuted),
                ),
                const SizedBox(height: InkSpacing.s12),
                if (_area != null) ...[
                  _AreaChip(
                    area: _area!,
                    onClear: _submitting
                        ? null
                        : () => setState(() => _area = null),
                  ),
                  const SizedBox(height: InkSpacing.s8),
                ],
                if (widget.onSelectArea != null) ...[
                  InkButton.secondary(
                    label: 'Select an area on the canvas',
                    icon: const Icon(LucideIcons.scan),
                    compact: true,
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onSelectArea!();
                          },
                  ),
                  const SizedBox(height: InkSpacing.s8),
                ],
                if (widget.elements.isEmpty)
                  Text(
                    'This board has no elements to select.',
                    style: InkType.caption(tokens.inkMuted),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.elements.length,
                      itemBuilder: (context, index) {
                        final element = widget.elements[index];
                        final selected = _selected.contains(element.id);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          title: Text(
                            _elementLabel(element),
                            style: InkType.body(tokens.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _kindLabel(element),
                            style: InkType.caption(tokens.inkMuted),
                          ),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selected.add(element.id);
                                    } else {
                                      _selected.remove(element.id);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: InkSpacing.s8),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    hintText: 'I accidentally moved these…',
                  ),
                ),
                const SizedBox(height: InkSpacing.s8),
                InkButton.primary(
                  label: 'Send request',
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Short noun phrase identifying a live element without exposing its id.
/// Mirrors the server's `elementNoun` so members and the owner read the same
/// words for the same thing.
String _elementLabel(CanvasElement element) {
  switch (element) {
    case ShapeElement():
      return '${_colorName(element.color)} ${element.shapeType.name}';
    case StrokeElement():
      return '${_colorName(element.color)} ${element.brushType} stroke';
    case TextElement():
      final snippet = _snippet(element.text);
      return snippet.isEmpty ? 'Text' : 'Text: “$snippet”';
    case StickyNoteElement():
      final snippet = _snippet(element.text);
      return snippet.isEmpty ? 'Sticky note' : 'Sticky note: “$snippet”';
    case ImageElement():
      return 'Image';
    case ConnectorElement():
      return '${_colorName(element.color)} connector';
  }
}

String _kindLabel(CanvasElement element) {
  switch (element) {
    case ShapeElement():
      return 'Shape';
    case StrokeElement():
      return 'Freehand stroke';
    case TextElement():
      return 'Text';
    case StickyNoteElement():
      return 'Sticky note';
    case ImageElement():
      return 'Image';
    case ConnectorElement():
      return 'Connector';
  }
}

String _snippet(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= 40) return flat;
  return '${flat.substring(0, 39)}…';
}

/// Human colour name, matching the server's HSL bucketing in describe.js.
String _colorName(Color color) {
  if (color.a < 16 / 255) return 'transparent';
  final hsl = HSLColor.fromColor(color);
  final h = hsl.hue;
  final s = hsl.saturation;
  final l = hsl.lightness;
  if (s < 0.1) {
    if (l > 0.93) return 'white';
    if (l < 0.12) return 'black';
    if (l > 0.7) return 'light grey';
    if (l < 0.35) return 'dark grey';
    return 'grey';
  }
  if (h >= 15 && h < 45 && l < 0.42) return 'brown';
  if ((h < 15 || h >= 345) && l < 0.32) return 'dark red';
  if (h < 15 || h >= 345) return l > 0.75 ? 'light red' : 'red';
  if (h < 45) return l > 0.7 ? 'peach' : 'orange';
  if (h < 70) return l > 0.7 ? 'pale yellow' : 'yellow';
  if (h < 150) {
    return l > 0.7 ? 'light green' : (l < 0.3 ? 'dark green' : 'green');
  }
  if (h < 195) return l > 0.7 ? 'light teal' : 'teal';
  if (h < 250) {
    return l > 0.7 ? 'light blue' : (l < 0.3 ? 'navy' : 'blue');
  }
  if (h < 290) return l > 0.7 ? 'lavender' : 'purple';
  return l > 0.7 ? 'pink' : 'magenta';
}

class _AreaChip extends StatelessWidget {
  final UndoRequestArea area;
  final VoidCallback? onClear;

  const _AreaChip({required this.area, this.onClear});

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s8,
        vertical: InkSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(InkRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.scan, size: 14, color: tokens.accentText),
          const SizedBox(width: InkSpacing.s4),
          Text(
            'Area: ${area.width.round()} × ${area.height.round()} px',
            style: InkType.caption(tokens.accentText),
          ),
          if (onClear != null) ...[
            const SizedBox(width: InkSpacing.s4),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(InkRadii.chip),
              child: Icon(LucideIcons.x, size: 14, color: tokens.accentText),
            ),
          ],
        ],
      ),
    );
  }
}
