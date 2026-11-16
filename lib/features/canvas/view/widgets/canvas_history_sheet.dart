import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_button.dart';
import '../../services/board_history_service.dart';

/// Local board checkpoints with manual save and non-destructive restore.
class CanvasHistorySheet extends StatefulWidget {
  final Future<List<BoardHistoryEntry>> Function() load;
  final Future<bool> Function() onSave;
  final ValueChanged<BoardHistoryEntry> onRestore;
  final Future<void> Function(BoardHistoryEntry entry) onDelete;
  final VoidCallback? onClose;

  const CanvasHistorySheet({
    super.key,
    required this.load,
    required this.onSave,
    required this.onRestore,
    required this.onDelete,
    this.onClose,
  });

  @override
  State<CanvasHistorySheet> createState() => _CanvasHistorySheetState();
}

class _CanvasHistorySheetState extends State<CanvasHistorySheet> {
  List<BoardHistoryEntry> _entries = const [];
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final entries = await widget.load();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final saved = await widget.onSave();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = saved
          ? 'Checkpoint saved on this device.'
          : 'Could not save. The board may be too large or empty.';
    });
    if (saved) await _reload();
  }

  Future<void> _delete(BoardHistoryEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onDelete(entry);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = 'Checkpoint deleted.';
    });
    await _reload();
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
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
              child: Text('Board history', style: InkType.title(tokens.ink)),
            ),
            if (widget.onClose != null)
              IconButton(
                tooltip: 'Close history',
                icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: InkSpacing.s4),
        Text(
          'Checkpoints are stored on this device. Restoring adds the version '
          'back as one undoable edit.',
          style: InkType.caption(tokens.inkMuted),
        ),
        const SizedBox(height: InkSpacing.s12),
        Row(
          children: [
            InkButton.primary(
              label: _busy ? 'Saving…' : 'Save checkpoint',
              icon: const Icon(LucideIcons.save, size: 18),
              expand: false,
              compact: true,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: InkSpacing.s8),
          Text(_message!, style: InkType.caption(tokens.accent)),
        ],
        const SizedBox(height: InkSpacing.s12),
        SizedBox(
          height: 330,
          child: _entries.isEmpty
              ? Center(
                  child: Text(
                    'No checkpoints yet.',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: InkSpacing.s8),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Material(
                      color: tokens.glass.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(InkRadii.card),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          InkSpacing.s12,
                          10,
                          4,
                          10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: tokens.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  InkRadii.chip,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.history,
                                size: 18,
                                color: tokens.accent,
                              ),
                            ),
                            const SizedBox(width: InkSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.label,
                                    style: InkType.bodyStrong(tokens.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_dateLabel(entry.savedAt)} · '
                                    '${entry.elements.length} objects',
                                    style: InkType.caption(tokens.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => widget.onRestore(entry),
                              child: const Text('Restore'),
                            ),
                            IconButton(
                              tooltip: 'Delete checkpoint',
                              icon: Icon(
                                LucideIcons.trash2,
                                size: 17,
                                color: tokens.danger,
                              ),
                              onPressed: _busy ? null : () => _delete(entry),
                            ),
                          ],
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
