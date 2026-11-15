import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/canvas_color_preferences.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';

/// Opens the HSV picker and resolves with the chosen colour, or `null` when
/// the user cancels.
///
/// The returned colour's alpha channel carries the picker's opacity. Callers
/// that paint must split it into an opaque colour plus an opacity value.
Future<Color?> showCanvasColorPicker(
  BuildContext context, {
  required Color initialColor,
  List<Color> recentColors = const [],
  double initialOpacity = 1.0,
  Map<String, List<Color>> palettes = const {},
  ValueChanged<Map<String, List<Color>>>? onPalettesChanged,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ColorPickerSheet(
      initialColor: initialColor,
      recentColors: recentColors,
      initialOpacity: initialOpacity,
      palettes: palettes,
      onPalettesChanged: onPalettesChanged,
    ),
  );
}

class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({
    super.key,
    required this.initialColor,
    this.recentColors = const [],
    this.initialOpacity = 1.0,
    this.palettes = const {},
    this.onPalettesChanged,
  });

  final Color initialColor;
  final List<Color> recentColors;
  final double initialOpacity;
  final Map<String, List<Color>> palettes;

  /// Called whenever the user adds, renames, deletes or fills a palette. The
  /// owner persists the map; the sheet remains usable when it is null.
  final ValueChanged<Map<String, List<Color>>>? onPalettesChanged;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  static const Object _newPaletteChoice = Object();

  late HSVColor _hsv;
  late double _opacity;
  late final TextEditingController _hexController;
  late Map<String, List<Color>> _palettes;
  String? _activePalette;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor.withValues(alpha: 1));
    _opacity = widget.initialOpacity.clamp(0.0, 1.0);
    _hexController = TextEditingController(text: _hex(_hsv.toColor()));
    _palettes = {
      for (final entry in widget.palettes.entries)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim(): List<Color>.of(entry.value),
    };
    _activePalette = _palettes.keys.firstOrNull;
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  Color get _result => _color.withValues(alpha: _opacity);

  static String _hex(Color color) =>
      color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _setHsv(HSVColor next) {
    setState(() {
      _hsv = next;
      final hex = _hex(next.toColor());
      if (_hexController.text.toUpperCase() != hex) {
        _hexController.text = hex;
      }
    });
  }

  void _onHexChanged(String raw) {
    final clean = raw.replaceAll('#', '').trim();
    if (clean.length != 6) return;
    final parsed = int.tryParse(clean, radix: 16);
    if (parsed == null) return;
    setState(() {
      _hsv = HSVColor.fromColor(Color(0xFF000000 | parsed));
    });
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _notifyPalettes() {
    widget.onPalettesChanged?.call({
      for (final entry in _palettes.entries)
        entry.key: List<Color>.unmodifiable(entry.value),
    });
  }

  Future<String?> _promptPaletteName({
    required String title,
    required String confirmLabel,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const ValueKey('palette-name-field'),
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: 'Palette name',
            counterText: '',
          ),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _createPalette() async {
    final name = await _promptPaletteName(
      title: 'New palette',
      confirmLabel: 'Create',
    );
    if (!mounted || name == null) return;
    final trimmed = name.trim();
    if (_palettes.containsKey(trimmed)) {
      _toast('A palette named $trimmed already exists');
      return;
    }
    if (_palettes.length >= CanvasColorPreferences.maxPalettes) {
      _toast(
        'Up to ${CanvasColorPreferences.maxPalettes} palettes can be saved',
      );
      return;
    }
    setState(() {
      _palettes = {..._palettes, trimmed: <Color>[]};
      _activePalette = trimmed;
    });
    _notifyPalettes();
  }

  Future<void> _saveCurrentColor() async {
    final color = _color.withValues(alpha: 1);
    if (_palettes.isEmpty) {
      final name = await _promptPaletteName(
        title: 'New palette',
        confirmLabel: 'Create',
      );
      if (!mounted || name == null) return;
      _createPaletteWithColor(name.trim(), color);
      return;
    }

    final choice = await showDialog<Object>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Save color to'),
        children: [
          for (final entry in _palettes.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry.key),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value.length}/${CanvasColorPreferences.maxPaletteColors}',
                    style: InkType.caption(context.ink.inkMuted),
                  ),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_newPaletteChoice),
            child: const Text('New palette…'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;

    if (identical(choice, _newPaletteChoice)) {
      final name = await _promptPaletteName(
        title: 'New palette',
        confirmLabel: 'Create',
      );
      if (!mounted || name == null) return;
      _createPaletteWithColor(name.trim(), color);
      return;
    }
    if (choice is! String) return;
    _addColorToPalette(choice, color);
  }

  void _createPaletteWithColor(String name, Color color) {
    if (name.isEmpty) return;
    if (_palettes.containsKey(name)) {
      _addColorToPalette(name, color);
      return;
    }
    if (_palettes.length >= CanvasColorPreferences.maxPalettes) {
      _toast(
        'Up to ${CanvasColorPreferences.maxPalettes} palettes can be saved',
      );
      return;
    }
    setState(() {
      _palettes = {
        ..._palettes,
        name: <Color>[color.withValues(alpha: 1)],
      };
      _activePalette = name;
    });
    _notifyPalettes();
  }

  void _addColorToPalette(String name, Color color) {
    final colors = _palettes[name];
    if (colors == null) return;
    final opaque = color.withValues(alpha: 1);
    if (colors.any((existing) => existing.value == opaque.value)) {
      _toast('Color already saved in $name');
      setState(() => _activePalette = name);
      return;
    }
    if (colors.length >= CanvasColorPreferences.maxPaletteColors) {
      _toast('$name is full');
      setState(() => _activePalette = name);
      return;
    }
    setState(() {
      _palettes = {
        ..._palettes,
        name: [...colors, opaque],
      };
      _activePalette = name;
    });
    _notifyPalettes();
  }

  Future<void> _renameActivePalette() async {
    final current = _activePalette;
    if (current == null) return;
    final name = await _promptPaletteName(
      title: 'Rename palette',
      confirmLabel: 'Rename',
      initialValue: current,
    );
    if (!mounted || name == null) return;
    final trimmed = name.trim();
    if (trimmed == current) return;
    if (_palettes.containsKey(trimmed)) {
      _toast('A palette named $trimmed already exists');
      return;
    }
    setState(() {
      final renamed = <String, List<Color>>{};
      for (final entry in _palettes.entries) {
        renamed[entry.key == current ? trimmed : entry.key] = entry.value;
      }
      _palettes = renamed;
      _activePalette = trimmed;
    });
    _notifyPalettes();
  }

  Future<void> _deleteActivePalette() async {
    final current = _activePalette;
    if (current == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete palette?'),
        content: Text('“$current” and its saved colors will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      final remaining = <String, List<Color>>{};
      for (final entry in _palettes.entries) {
        if (entry.key != current) remaining[entry.key] = entry.value;
      }
      _palettes = remaining;
      _activePalette = remaining.keys.firstOrNull;
    });
    _notifyPalettes();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: tokens.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Color', style: InkType.body(tokens.ink)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, size: 20, color: tokens.inkMuted),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: InkSpacing.s8),
            SizedBox(height: 180, child: _buildSaturationValue(tokens)),
            const SizedBox(height: InkSpacing.s12),
            _buildHueBar(),
            const SizedBox(height: InkSpacing.s16),
            Row(
              children: [
                Container(
                  key: const ValueKey('color-preview'),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _result,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.glassStroke),
                  ),
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('color-hex-field'),
                    controller: _hexController,
                    onChanged: _onHexChanged,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    style: InkType.caption(tokens.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: tokens.field,
                      prefixText: '#',
                      counterText: '',
                      hintText: 'HEX',
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: InkSpacing.s12),
            _buildOpacity(tokens),
            if (widget.recentColors.isNotEmpty) ...[
              const SizedBox(height: InkSpacing.s16),
              Text('Recent', style: InkType.label(tokens.inkSecondary)),
              const SizedBox(height: InkSpacing.s8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < widget.recentColors.length; i++)
                    _recentSwatch(tokens, widget.recentColors[i], i),
                ],
              ),
            ],
            const SizedBox(height: InkSpacing.s16),
            _buildPalettes(tokens),
            const SizedBox(height: InkSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: InkSpacing.s12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.ink,
                      foregroundColor: tokens.paper,
                    ),
                    onPressed: () => Navigator.of(context).pop(_result),
                    child: const Text('Use color'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpacity(InkTokens tokens) {
    return Row(
      children: [
        Text('Opacity', style: InkType.label(tokens.inkSecondary)),
        Expanded(
          child: Slider(
            key: const ValueKey('color-opacity-slider'),
            value: _opacity,
            onChanged: (value) => setState(() => _opacity = value),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(_opacity * 100).round()}%',
            textAlign: TextAlign.end,
            style: InkType.caption(tokens.ink),
          ),
        ),
      ],
    );
  }

  Widget _buildPalettes(InkTokens tokens) {
    final active = _activePalette;
    final activeColors = active == null
        ? const <Color>[]
        : _palettes[active] ?? const <Color>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Palettes', style: InkType.label(tokens.inkSecondary)),
            const Spacer(),
            TextButton.icon(
              key: const ValueKey('palette-new'),
              onPressed: _createPalette,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('New palette'),
            ),
          ],
        ),
        if (_palettes.isEmpty)
          Text(
            'Save colors into a palette to reuse them across boards.',
            style: InkType.caption(tokens.inkMuted),
          )
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in _palettes.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('palette-chip-$name'),
                      label: Text(name),
                      selected: name == active,
                      onSelected: (_) =>
                          setState(() => _activePalette = name),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: InkSpacing.s8),
          Row(
            children: [
              Expanded(
                child: activeColors.isEmpty
                    ? Text(
                        active == null
                            ? 'No palette selected'
                            : 'No colors yet — save the current color.',
                        style: InkType.caption(tokens.inkMuted),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < activeColors.length; i++)
                            _paletteSwatch(
                              tokens,
                              active!,
                              activeColors[i],
                              i,
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: InkSpacing.s8),
              TextButton.icon(
                key: const ValueKey('palette-save-color'),
                onPressed: _saveCurrentColor,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Save color'),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('palette-menu'),
                tooltip: 'Palette actions',
                onSelected: (value) {
                  if (value == 'rename') _renameActivePalette();
                  if (value == 'delete') _deleteActivePalette();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename palette')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete palette'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSaturationValue(InkTokens tokens) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        void update(Offset local) {
          _setHsv(
            _hsv
                .withSaturation((local.dx / width).clamp(0.0, 1.0))
                .withValue(1 - (local.dy / height).clamp(0.0, 1.0)),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => update(details.localPosition),
          onPanDown: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _SaturationValuePainter(_hsv.hue)),
                ),
                Positioned(
                  left: (_hsv.saturation * width - 8).clamp(0.0, width - 16),
                  top: ((1 - _hsv.value) * height - 8).clamp(0.0, height - 16),
                  child: IgnorePointer(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x55000000), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHueBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void update(Offset local) {
          _setHsv(_hsv.withHue((local.dx / width).clamp(0.0, 1.0) * 360));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => update(details.localPosition),
          onPanDown: (details) => update(details.localPosition),
          onPanUpdate: (details) => update(details.localPosition),
          child: SizedBox(
            height: 28,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (_hsv.hue / 360 * width - 7).clamp(0.0, width - 14),
                  top: 5,
                  child: IgnorePointer(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x55000000), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recentSwatch(InkTokens tokens, Color color, int index) {
    final selected = color.value == _color.value;
    return InkWell(
      key: ValueKey('recent-$index'),
      onTap: () => _setHsv(HSVColor.fromColor(color.withValues(alpha: 1))),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? tokens.ink : tokens.glassStroke,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? Icon(
                LucideIcons.check,
                size: 16,
                color: color.computeLuminance() > 0.6
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }

  Widget _paletteSwatch(
    InkTokens tokens,
    String palette,
    Color color,
    int index,
  ) {
    final selected = color.value == _color.value;
    return InkWell(
      key: ValueKey('palette-swatch-$palette-$index'),
      onTap: () => _setHsv(HSVColor.fromColor(color.withValues(alpha: 1))),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? tokens.ink : tokens.glassStroke,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? Icon(
                LucideIcons.check,
                size: 15,
                color: color.computeLuminance() > 0.6
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    canvas.drawRect(rect, Paint()..color = base);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue;
}
