import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../domain/services/history/board_history_service.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/glass_panel.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../models/canvas_element.dart';

/// Member → owner escalation (D5). Members select elements from the LIVE
/// canvas only — they never read the log (D3).
Future<void> showUndoRequestSheet(
  BuildContext context, {
  required BoardHistoryService service,
  required String boardId,
  required List<CanvasElement> elements,
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
    ),
  );
}

class _UndoRequestSheet extends StatefulWidget {
  final BuildContext hostContext;
  final BoardHistoryService service;
  final String boardId;
  final List<CanvasElement> elements;

  const _UndoRequestSheet({
    required this.hostContext,
    required this.service,
    required this.boardId,
    required this.elements,
  });

  @override
  State<_UndoRequestSheet> createState() => _UndoRequestSheetState();
}

class _UndoRequestSheetState extends State<_UndoRequestSheet> {
  final Set<String> _selected = <String>{};
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

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
                        final type =
                            (element.toMap()['type'] as String?) ?? 'element';
                        final selected = _selected.contains(element.id);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          title: Text(
                            '$type • ${element.id}',
                            style: InkType.body(tokens.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
