import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../domain/models/history/undo_request.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../bloc/canvas_bloc.dart';

/// Member → owner escalation (D5), in two stages:
///
/// 1. [showUndoRequestSheet] — the scope picker. The member selects an area
///    on the canvas, double-taps individual elements, or ticks checkboxes;
///    the scope lives in the bloc's [UndoRequestDraft] so canvas picks and
///    the sheet stay in sync across close/reopen.
/// 2. [showUndoRequestSendSheet] — the reason + send step. The member has
///    already settled on a stop of their own replay slider; the request
///    carries that DESIRED STATE (a target version), not a plain
///    "delete my edits".
///
/// Members select from the LIVE canvas only — they never read the log (D3).
Future<void> showUndoRequestSheet(
  BuildContext context, {
  required CanvasBloc bloc,
  required List<CanvasElement> elements,
  List<String> initialIds = const [],
  UndoRequestArea? initialArea,
  required VoidCallback onSelectArea,
  required VoidCallback onPreview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => _UndoRequestScopeSheet(
      // Kept for post-pop snackbars: this sheet's own context is deactivated
      // once Navigator.pop runs.
      hostContext: context,
      bloc: bloc,
      elements: elements,
      initialIds: initialIds,
      initialArea: initialArea,
      onSelectArea: onSelectArea,
      onPreview: onPreview,
    ),
  );
}

/// The reason + send step of the undo-request flow. Opened from the preview
/// banner's "Send request" action once the member settled on a stop; the
/// sheet is static while open (the modal barrier blocks the slider), so the
/// desired state is passed in and frozen.
Future<void> showUndoRequestSendSheet(
  BuildContext context, {
  required int targetVersion,
  required String? stopLabel,
  required int elementCount,
  required bool canSend,
  required ValueChanged<String> onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => _UndoRequestSendSheet(
      hostContext: context,
      targetVersion: targetVersion,
      stopLabel: stopLabel,
      elementCount: elementCount,
      canSend: canSend,
      onSubmit: onSubmit,
    ),
  );
}

class _UndoRequestScopeSheet extends StatefulWidget {
  final BuildContext hostContext;
  final CanvasBloc bloc;
  final List<CanvasElement> elements;
  final List<String> initialIds;
  final UndoRequestArea? initialArea;
  final VoidCallback onSelectArea;
  final VoidCallback onPreview;

  const _UndoRequestScopeSheet({
    required this.hostContext,
    required this.bloc,
    required this.elements,
    required this.initialIds,
    required this.initialArea,
    required this.onSelectArea,
    required this.onPreview,
  });

  @override
  State<_UndoRequestScopeSheet> createState() => _UndoRequestScopeSheetState();
}

class _UndoRequestScopeSheetState extends State<_UndoRequestScopeSheet> {
  late final Set<String> _selected;
  UndoRequestArea? _area;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIds.toSet();
    _area = widget.initialArea;
  }

  void _cancel() {
    widget.bloc.add(const CanvasUndoRequestDraftCleared());
    Navigator.pop(context);
  }

  Future<void> _preview() async {
    if (_selected.isEmpty) {
      AppSnackBar.showError(context, 'Select at least one element.');
      return;
    }
    Navigator.pop(context);
    widget.onPreview();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.all(InkSpacing.s20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
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
                      tooltip: 'Cancel request',
                      onPressed: _cancel,
                    ),
                  ],
                ),
                Text(
                  'Pick what the owner should restore. Double-tap elements on '
                  'the canvas to add or remove them.',
                  style: InkType.caption(tokens.inkMuted),
                ),
                const SizedBox(height: InkSpacing.s12),
                if (_area != null) ...[
                  _AreaChip(
                    area: _area!,
                    onClear: () {
                      // The scope was resolved from the area: clearing it
                      // restarts the selection.
                      widget.bloc.add(const CanvasUndoRequestDraftCleared());
                      setState(() {
                        _area = null;
                        _selected.clear();
                      });
                    },
                  ),
                  const SizedBox(height: InkSpacing.s8),
                ],
                InkButton.secondary(
                  label: 'Select an area on the canvas',
                  icon: const Icon(LucideIcons.scan),
                  compact: true,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSelectArea();
                  },
                ),
                const SizedBox(height: InkSpacing.s8),
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
                        // The GlassPanel's fill is a DecoratedBox between
                        // the tile and the sheet's Material, which ListTile
                        // rejects with a debug assertion — give the tile
                        // its own transparent Material.
                        return Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
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
                            onChanged: (value) {
                              widget.bloc.add(
                                CanvasUndoRequestDraftElementToggled(
                                  element.id,
                                ),
                              );
                              setState(() {
                                if (value == true) {
                                  _selected.add(element.id);
                                } else {
                                  _selected.remove(element.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: InkSpacing.s8),
                InkButton.primary(
                  label: 'Preview my changes',
                  onPressed: _selected.isEmpty ? null : _preview,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoRequestSendSheet extends StatefulWidget {
  final BuildContext hostContext;
  final int targetVersion;
  final String? stopLabel;
  final int elementCount;
  final bool canSend;
  final ValueChanged<String> onSubmit;

  const _UndoRequestSendSheet({
    required this.hostContext,
    required this.targetVersion,
    required this.stopLabel,
    required this.elementCount,
    required this.canSend,
    required this.onSubmit,
  });

  @override
  State<_UndoRequestSendSheet> createState() => _UndoRequestSendSheetState();
}

class _UndoRequestSendSheetState extends State<_UndoRequestSendSheet> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (!widget.canSend) {
      AppSnackBar.showError(
        context,
        'Move the slider back to pick a state to restore first.',
      );
      return;
    }
    if (reason.isEmpty) {
      AppSnackBar.showError(context, 'A reason is required.');
      return;
    }
    setState(() => _submitting = true);
    // The bloc performs the request and leaves the preview; failures surface
    // as the screen's error snackbar while the member stays on the slider.
    Navigator.pop(context);
    widget.onSubmit(reason);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    // The canvas Scaffold uses `resizeToAvoidBottomInset: false` and a modal
    // sheet does not inset itself, so the sheet must clear the keyboard or
    // the reason field (and what was typed into it) hides behind it.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final view = MediaQuery.of(context);
    // Keep the panel inside the space left above the keyboard; never smaller
    // than a usable minimum.
    final maxHeight = math.min(
      view.size.height * 0.78,
      math.max(220.0, availableSheetHeight(view, keyboardInset)),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.s12),
          child: GlassPanel(
            radius: InkRadii.bottomSheet,
            padding: const EdgeInsets.all(InkSpacing.s20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send undo request',
                          style: InkType.title(tokens.ink),
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                        tooltip: 'Back to the slider',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: InkSpacing.s8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(InkSpacing.s12),
                    decoration: BoxDecoration(
                      color: tokens.field,
                      borderRadius: BorderRadius.circular(InkRadii.chip),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restore to version ${widget.targetVersion}',
                          style: InkType.bodyStrong(tokens.ink),
                        ),
                        if (widget.stopLabel != null &&
                            widget.stopLabel!.isNotEmpty) ...[
                          const SizedBox(height: InkSpacing.s4),
                          Text(
                            widget.stopLabel!,
                            style: InkType.caption(tokens.inkMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: InkSpacing.s4),
                        Text(
                          '${widget.elementCount} element(s) in this request',
                          style: InkType.caption(tokens.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.canSend) ...[
                    const SizedBox(height: InkSpacing.s8),
                    Text(
                      'You picked the newest state — there is nothing to '
                      'undo. Move the slider back and try again.',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                  ],
                  const SizedBox(height: InkSpacing.s12),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    maxLength: 1000,
                    enabled: widget.canSend,
                    // Tapping anything else in the sheet drops the keyboard
                    // so the rest of it stays usable.
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      labelText: 'Reason (required)',
                      hintText: 'I accidentally moved these…',
                      suffixIcon: IconButton(
                        tooltip: 'Hide keyboard',
                        icon: Icon(
                          LucideIcons.chevronDown,
                          size: 18,
                          color: tokens.inkSecondary,
                        ),
                        onPressed: () => FocusScope.of(context).unfocus(),
                      ),
                    ),
                  ),
                  const SizedBox(height: InkSpacing.s8),
                  InkButton.primary(
                    label: 'Send request',
                    isLoading: _submitting,
                    onPressed: widget.canSend && !_submitting ? _submit : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Height left for the sheet once the keyboard and top padding are cleared.
double availableSheetHeight(MediaQueryData view, double keyboardInset) {
  return view.size.height - keyboardInset - view.padding.top - InkSpacing.s24;
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
