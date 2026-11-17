import 'package:flutter/material.dart';

import '../../geometry/canvas_element_geometry.dart';
import '../../models/canvas_element.dart';
import 'color_picker_sheet.dart';

Future<StickyNoteElement?> showStickyNoteEditor(
  BuildContext context, {
  required StickyNoteElement note,
  bool isNew = false,
}) => showDialog<StickyNoteElement>(
  context: context,
  builder: (_) => StickyNoteEditorDialog(note: note, isNew: isNew),
);

class StickyNoteEditorDialog extends StatefulWidget {
  const StickyNoteEditorDialog({
    super.key,
    required this.note,
    this.isNew = false,
  });
  final StickyNoteElement note;
  final bool isNew;

  @override
  State<StickyNoteEditorDialog> createState() => _StickyNoteEditorDialogState();
}

class _StickyNoteEditorDialogState extends State<StickyNoteEditorDialog> {
  late StickyNoteElement _note;
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _text = TextEditingController(text: _note.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickColor(bool paper) async {
    final current = paper ? _note.color : _note.textColor;
    final color = await showCanvasColorPicker(
      context,
      initialColor: current,
      initialOpacity: current.a,
    );
    if (color == null || !mounted) return;
    setState(
      () => _note = paper
          ? _note.copyWith(color: color)
          : _note.copyWith(textColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fitted = fitStickyNoteHeight(_note);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.isNew ? 'Add Sticky Note' : 'Edit Sticky Note'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: fitted.width + 32,
                  height: fitted.height + 32,
                  child: CustomPaint(painter: _StickyPreviewPainter(fitted)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sticky-editor-text'),
              controller: _text,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Note content'),
              onChanged: (value) =>
                  setState(() => _note = _note.copyWith(text: value)),
            ),
            const SizedBox(height: 12),
            Text('Text size ${_note.fontSize.round()}'),
            Slider(
              key: const Key('sticky-font-size'),
              value: _note.fontSize.clamp(8.0, 72.0),
              min: 8,
              max: 72,
              divisions: 64,
              label: '${_note.fontSize.round()}',
              onChanged: (v) =>
                  setState(() => _note = _note.copyWith(fontSize: v)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  key: const Key('sticky-bold'),
                  label: const Text('Bold'),
                  selected: _note.fontWeight >= 700,
                  onSelected: (v) => setState(
                    () => _note = _note.copyWith(fontWeight: v ? 700 : 500),
                  ),
                ),
                for (final align in ['left', 'center', 'right'])
                  ChoiceChip(
                    key: Key('sticky-align-$align'),
                    label: Text(
                      '${align[0].toUpperCase()}${align.substring(1)}',
                    ),
                    selected: _note.textAlign == align,
                    onSelected: (_) => setState(
                      () => _note = _note.copyWith(textAlign: align),
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const Key('sticky-paper-color'),
                  onPressed: () => _pickColor(true),
                  icon: Icon(Icons.circle, color: _note.color),
                  label: const Text('Paper color'),
                ),
                TextButton.icon(
                  key: const Key('sticky-text-color'),
                  onPressed: () => _pickColor(false),
                  icon: Icon(Icons.format_color_text, color: _note.textColor),
                  label: const Text('Text color'),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              key: const Key('sticky-auto-height'),
              activeColor: Colors.white,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto height'),
              subtitle: const Text(
                'Grow to fit text, up to 480. Manual resize turns this off.',
              ),
              value: _note.autoSize,
              onChanged: (v) =>
                  setState(() => _note = _note.copyWith(autoSize: v)),
            ),
            if (_note.authorUid != null)
              Text(
                'Author: ${_note.authorUid}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('sticky-editor-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('sticky-editor-save'),
          onPressed: () => Navigator.of(context).pop(fitted),
          child: Text(widget.isNew ? 'Add to Canvas' : 'Save'),
        ),
      ],
    );
  }
}

class _StickyPreviewPainter extends CustomPainter {
  const _StickyPreviewPainter(this.note);
  final StickyNoteElement note;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: note.opacity),
    );
    paintStickyNoteElement(
      canvas,
      note.copyWith(
        center: Offset(size.width / 2, size.height / 2),
        rotation: 0,
      ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StickyPreviewPainter oldDelegate) =>
      note != oldDelegate.note;
}
