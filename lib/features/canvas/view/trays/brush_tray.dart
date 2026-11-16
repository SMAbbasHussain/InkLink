import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/sliding_tray.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../geometry/canvas_element_geometry.dart';
import '../../geometry/stroke_input.dart';
import '../../models/brush_preset.dart';
import '../../models/canvas_tool_mode.dart';

class BrushTray extends StatefulWidget {
  final bool isOpen;
  final double strokeWidth;
  final Color selectedColor;
  final double brushOpacity;
  final String brushType;
  final bool eraserEraseEverything;
  final bool smoothDoodlesEnabled;
  final bool stylusPressureEnabled;
  final bool fingerDrawingEnabled;
  final bool quickShapeEnabled;
  final double stabilizerStrength;
  final ValueChanged<double>? onStabilizerChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<String> onBrushPresetSelected;
  final ValueChanged<CanvasToolMode>? onToolModeChanged;
  final ValueChanged<bool> onEraserEraseEverythingChanged;
  final ValueChanged<bool>? onSmoothDoodlesChanged;
  final ValueChanged<bool>? onStylusPressureChanged;
  final ValueChanged<bool>? onFingerDrawingChanged;
  final ValueChanged<bool>? onQuickShapeChanged;
  final List<Color> recentColors;
  final bool eyedropperActive;
  final VoidCallback? onOpenColorPicker;
  final VoidCallback? onEyedropperRequested;
  final VoidCallback? onClose;

  const BrushTray({
    super.key,
    required this.isOpen,
    required this.strokeWidth,
    required this.selectedColor,
    required this.brushOpacity,
    required this.brushType,
    required this.eraserEraseEverything,
    this.smoothDoodlesEnabled = false,
    this.stylusPressureEnabled = true,
    this.fingerDrawingEnabled = true,
    this.quickShapeEnabled = true,
    this.stabilizerStrength = 0,
    this.onStabilizerChanged,
    required this.onStrokeWidthChanged,
    required this.onColorSelected,
    required this.onOpacityChanged,
    required this.onBrushPresetSelected,
    this.onToolModeChanged,
    required this.onEraserEraseEverythingChanged,
    this.onSmoothDoodlesChanged,
    this.onStylusPressureChanged,
    this.onFingerDrawingChanged,
    this.onQuickShapeChanged,
    this.recentColors = const [],
    this.eyedropperActive = false,
    this.onOpenColorPicker,
    this.onEyedropperRequested,
    this.onClose,
  });

  @override
  State<BrushTray> createState() => _BrushTrayState();
}

class _BrushTrayState extends State<BrushTray> {
  late TextEditingController _hexController;
  late TextEditingController _redController;
  late TextEditingController _greenController;
  late TextEditingController _blueController;
  final List<String> _recentBrushes = <String>[];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _redController = TextEditingController();
    _greenController = TextEditingController();
    _blueController = TextEditingController();
    if (widget.brushType.isNotEmpty && widget.brushType != 'eraser') {
      _recentBrushes.add(widget.brushType);
    }
    _updateColorControllers(widget.selectedColor);
  }

  @override
  void didUpdateWidget(BrushTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor != widget.selectedColor) {
      _updateColorControllers(widget.selectedColor);
    }
    if (widget.brushType != oldWidget.brushType &&
        widget.brushType.isNotEmpty &&
        widget.brushType != 'eraser') {
      _recentBrushes.remove(widget.brushType);
      _recentBrushes.insert(0, widget.brushType);
      if (_recentBrushes.length > 5) {
        _recentBrushes.removeLast();
      }
    }
  }

  void _updateColorControllers(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    final red = color.red;
    final green = color.green;
    final blue = color.blue;

    _hexController.text = hex.substring(2); // Remove alpha
    _redController.text = red.toString();
    _greenController.text = green.toString();
    _blueController.text = blue.toString();
  }

  void _updateColorFromHex(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) {
        final color = Color(int.parse('FF$cleanHex', radix: 16));
        widget.onColorSelected(color);
      }
    } catch (_) {
      // Invalid input
    }
  }

  void _updateColorFromRGB() {
    try {
      final r = int.parse(_redController.text).clamp(0, 255);
      final g = int.parse(_greenController.text).clamp(0, 255);
      final b = int.parse(_blueController.text).clamp(0, 255);
      final color = Color.fromARGB(255, r, g, b);
      widget.onColorSelected(color);
    } catch (_) {
      // Invalid input
    }
  }

  void _onBrushPresetSelected(BrushPreset preset) {
    HapticFeedback.selectionClick();
    if (preset.id != 'eraser') {
      setState(() {
        _recentBrushes.remove(preset.id);
        _recentBrushes.insert(0, preset.id);
        if (_recentBrushes.length > 5) {
          _recentBrushes.removeLast();
        }
      });
    }
    widget.onBrushPresetSelected(preset.id);
    widget.onToolModeChanged?.call(
      preset.id == 'highlighter'
          ? CanvasToolMode.highlight
          : CanvasToolMode.doodle,
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    _redController.dispose();
    _greenController.dispose();
    _blueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final colors = <Color>[
      Colors.black,
      Colors.white,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.yellow,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
    ];

    return SlidingTray(
      isOpen: widget.isOpen,
      direction: TrayDirection.bottom,
      title: 'Brush & Color',
      height: 520,
      onClose: widget.onClose,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveBrushPreview(tokens),
              const SizedBox(height: InkSpacing.s16),
              _buildStrokeWidthControl(tokens),
              const SizedBox(height: InkSpacing.s16),
              if (widget.brushType == 'eraser') ...[
                _buildEraserModeControl(tokens),
                const SizedBox(height: InkSpacing.s16),
              ],
              _buildOpacityControl(tokens),
              const SizedBox(height: InkSpacing.s16),
              _buildFingerDrawingToggle(tokens),
              const SizedBox(height: InkSpacing.s16),
              if (widget.brushType != 'eraser') ...[
                _buildStylusPressureToggle(tokens),
                const SizedBox(height: InkSpacing.s16),
                _buildQuickShapeToggle(tokens),
                const SizedBox(height: InkSpacing.s16),
              ],
              _buildBrushPresetPicker(tokens),
              if (_recentBrushes.length > 1) ...[
                const SizedBox(height: InkSpacing.s12),
                _buildRecentBrushesRow(tokens),
              ],
              const SizedBox(height: InkSpacing.s16),
              if (widget.brushType != 'eraser') ...[
                _buildStabilizerControl(tokens),
                const SizedBox(height: InkSpacing.s16),
                _buildSmoothToggle(tokens),
                const SizedBox(height: InkSpacing.s16),
              ],
              _buildColorPalette(tokens, colors),
              if (widget.recentColors.isNotEmpty) ...[
                const SizedBox(height: InkSpacing.s12),
                _buildRecentColors(tokens),
              ],
              const SizedBox(height: InkSpacing.s12),
              _buildColorInputs(tokens),
              const SizedBox(height: InkSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBrushPreview(InkTokens tokens) {
    final preset = brushPresetFor(widget.brushType);
    final isEraser = widget.brushType == 'eraser';

    return Container(
      width: double.infinity,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.field,
        borderRadius: BorderRadius.circular(InkRadii.input),
        border: Border.all(color: tokens.glassStroke),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(InkRadii.input - 2),
              child: CustomPaint(
                painter: _BrushPreviewPainter(
                  brushType: widget.brushType,
                  color: isEraser ? tokens.inkMuted : widget.selectedColor,
                  strokeWidth: widget.strokeWidth,
                  opacity: widget.brushOpacity,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.paper.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${preset.label} · ${widget.strokeWidth.toStringAsFixed(1)}px · ${(widget.brushOpacity * 100).round()}%',
                style: InkType.caption(tokens.inkSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrokeWidthControl(InkTokens tokens) {
    final preset = brushPresetFor(widget.brushType);
    final minW = preset.minWidth;
    final maxW = preset.maxWidth;
    final clampedWidth = widget.strokeWidth.clamp(minW, maxW);

    return Row(
      children: [
        Icon(LucideIcons.penLine, size: 18, color: tokens.inkMuted),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.brushType == 'eraser'
                        ? 'Eraser Size'
                        : 'Stroke Width',
                    style: InkType.label(tokens.inkSecondary),
                  ),
                  Text(
                    '${clampedWidth.toStringAsFixed(1)}px',
                    style: InkType.label(tokens.ink),
                  ),
                ],
              ),
              Slider(
                value: clampedWidth,
                min: minW,
                max: maxW,
                onChanged: widget.onStrokeWidthChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFingerDrawingToggle(InkTokens tokens) {
    return Row(
      children: [
        Icon(LucideIcons.hand, size: 18, color: tokens.inkMuted),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finger drawing',
                      style: InkType.label(tokens.inkSecondary),
                    ),
                    Text(
                      'Off: one finger pans, pen still draws',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                activeColor: tokens.accent,
                value: widget.fingerDrawingEnabled,
                onChanged: widget.onFingerDrawingChanged == null
                    ? null
                    : (v) {
                        HapticFeedback.lightImpact();
                        widget.onFingerDrawingChanged!(v);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStylusPressureToggle(InkTokens tokens) {
    return Row(
      children: [
        Icon(LucideIcons.penTool, size: 18, color: tokens.inkMuted),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stylus Pressure',
                    style: InkType.label(tokens.inkSecondary),
                  ),
                  Text(
                    'Modulate width by pen pressure',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                ],
              ),
              Switch.adaptive(
                key: const ValueKey('stylusPressureSwitch'),
                activeColor: tokens.accent,
                value: widget.stylusPressureEnabled,
                onChanged: widget.onStylusPressureChanged == null
                    ? null
                    : (v) {
                        HapticFeedback.lightImpact();
                        widget.onStylusPressureChanged!(v);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickShapeToggle(InkTokens tokens) {
    return Row(
      children: [
        Icon(LucideIcons.shapes, size: 18, color: tokens.inkMuted),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QuickShape',
                      style: InkType.label(tokens.inkSecondary),
                    ),
                    Text(
                      'Hold at the end to snap a rough shape',
                      style: InkType.caption(tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                activeColor: tokens.accent,
                value: widget.quickShapeEnabled,
                onChanged: widget.onQuickShapeChanged == null
                    ? null
                    : (value) {
                        HapticFeedback.lightImpact();
                        widget.onQuickShapeChanged!(value);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBrushesRow(InkTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Brushes', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _recentBrushes.map((brushId) {
            final preset = brushPresetFor(brushId);
            final isSelected = widget.brushType == brushId;
            return ChoiceChip(
              avatar: Icon(
                preset.icon,
                size: 14,
                color: isSelected ? tokens.accent : tokens.inkMuted,
              ),
              label: Text(preset.label),
              selected: isSelected,
              onSelected: (_) => _onBrushPresetSelected(preset),
              labelStyle: InkType.caption(
                isSelected ? tokens.accent : tokens.ink,
              ),
              backgroundColor: tokens.field,
              selectedColor: tokens.accent.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected ? tokens.accent : tokens.glassStroke,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOpacityControl(InkTokens tokens) {
    return Row(
      children: [
        Icon(LucideIcons.droplet, size: 18, color: tokens.inkMuted),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Opacity', style: InkType.label(tokens.inkSecondary)),
                  Text(
                    '${(widget.brushOpacity * 100).toStringAsFixed(0)}%',
                    style: InkType.label(tokens.ink),
                  ),
                ],
              ),
              Slider(
                value: widget.brushOpacity,
                min: 0,
                max: 1,
                onChanged: widget.onOpacityChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrushPresetPicker(InkTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brush Presets', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: brushPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: InkSpacing.s8),
            itemBuilder: (context, index) {
              final preset = brushPresets[index];
              return _buildPresetCard(tokens, preset);
            },
          ),
        ),
        const SizedBox(height: InkSpacing.s8),
        Text(
          brushPresetFor(widget.brushType).description,
          style: InkType.caption(tokens.inkMuted),
        ),
      ],
    );
  }

  Widget _buildPresetCard(InkTokens tokens, BrushPreset preset) {
    final selected = widget.brushType == preset.id;
    return InkWell(
      key: ValueKey('brush-preset-${preset.id}'),
      onTap: () => _onBrushPresetSelected(preset),
      borderRadius: BorderRadius.circular(InkRadii.input),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? tokens.accent.withValues(alpha: 0.12)
              : tokens.field,
          borderRadius: BorderRadius.circular(InkRadii.input),
          border: Border.all(
            color: selected ? tokens.accent : tokens.glassStroke,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  preset.icon,
                  size: 16,
                  color: selected ? tokens.accent : tokens.inkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: InkType.label(selected ? tokens.accent : tokens.ink),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${preset.defaultWidth.toStringAsFixed(0)} px · '
              '${(preset.defaultOpacity * 100).round()}%',
              style: InkType.caption(tokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEraserModeControl(InkTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eraser Target', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            // A white thumb keeps the switch readable against the blue
            // active track instead of turning into one solid blue pill.
            activeColor: Colors.white,
            activeTrackColor: tokens.accent,
            value: widget.eraserEraseEverything,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              widget.onEraserEraseEverythingChanged(v);
            },
            title: Text(
              'Erase everything it touches',
              style: InkType.body(tokens.ink),
            ),
            subtitle: Text(
              'Off = erase brush strokes only',
              style: InkType.caption(tokens.inkMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStabilizerControl(InkTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Live stabilizer', style: InkType.label(tokens.inkSecondary)),
            Text(
              widget.stabilizerStrength == 0
                  ? 'Off'
                  : '${(widget.stabilizerStrength * 100).round()}%',
              style: InkType.label(tokens.ink),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('brush-stabilizer'),
          value: widget.stabilizerStrength,
          max: maxStabilizerStrength,
          divisions: 18,
          label: '${(widget.stabilizerStrength * 100).round()}%',
          onChanged: widget.onStabilizerChanged,
        ),
        Text(
          'Smooths while drawing; preserves corners and the endpoint',
          style: InkType.caption(tokens.inkMuted),
        ),
      ],
    );
  }

  Widget _buildSmoothToggle(InkTokens tokens) {
    return Row(
      children: [
        Icon(LucideIcons.sparkles, size: 18, color: tokens.inkMuted),
        const SizedBox(width: InkSpacing.s12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Smooth after drawing',
                style: InkType.label(tokens.inkSecondary),
              ),
              Switch.adaptive(
                key: const ValueKey('brush-smooth-after'),
                activeColor: tokens.accent,
                value:
                    widget.smoothDoodlesEnabled &&
                    widget.stabilizerStrength == 0,
                onChanged:
                    widget.onSmoothDoodlesChanged == null ||
                        widget.stabilizerStrength > 0
                    ? null
                    : (v) {
                        HapticFeedback.lightImpact();
                        widget.onSmoothDoodlesChanged!(v);
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorPalette(InkTokens tokens, List<Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Colors', style: InkType.label(tokens.inkSecondary)),
            const Spacer(),
            IconButton(
              onPressed: widget.onEyedropperRequested,
              tooltip: 'Pick a color from the canvas',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.pipette,
                size: 18,
                color: widget.eyedropperActive
                    ? tokens.accent
                    : tokens.inkMuted,
              ),
            ),
            IconButton(
              onPressed: widget.onOpenColorPicker,
              tooltip: 'Open the color picker',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.palette, size: 18, color: tokens.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.s4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: colors
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onColorSelected(c);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(
                          widget.selectedColor == c ? 2 : 0,
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: Border.all(
                              color: widget.selectedColor == c
                                  ? tokens.ink
                                  : tokens.glassStroke,
                              width: widget.selectedColor == c ? 2 : 1,
                            ),
                          ),
                          child: widget.selectedColor == c
                              ? Icon(
                                  LucideIcons.check,
                                  color: c.computeLuminance() > 0.6
                                      ? Colors.black
                                      : Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentColors(InkTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in widget.recentColors)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onColorSelected(color);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.selectedColor == color
                          ? tokens.ink
                          : tokens.glassStroke,
                      width: widget.selectedColor == color ? 2 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorInputs(InkTokens tokens) {
    final smallFieldDecoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: tokens.field,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      counterText: '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom Color', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        Row(
          children: [
            Text('#', style: InkType.caption(tokens.inkMuted)),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _hexController,
                onChanged: _updateColorFromHex,
                maxLength: 6,
                style: InkType.caption(tokens.ink),
                decoration: smallFieldDecoration.copyWith(hintText: 'HEX'),
              ),
            ),
            const SizedBox(width: InkSpacing.s8),
            ...[
              ('R', _redController),
              ('G', _greenController),
              ('B', _blueController),
            ].map(
              (pair) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(pair.$1, style: InkType.caption(tokens.inkMuted)),
                      const SizedBox(height: 2),
                      TextField(
                        controller: pair.$2,
                        onChanged: (_) => _updateColorFromRGB(),
                        maxLength: 3,
                        style: InkType.caption(tokens.ink),
                        keyboardType: TextInputType.number,
                        decoration: smallFieldDecoration,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

@Preview(name: 'Brush input controls', group: 'Canvas', size: Size(400, 900))
@Preview(
  name: 'Brush input controls desktop',
  group: 'Canvas',
  size: Size(1000, 900),
)
Widget brushInputControlsPreview() {
  var strength = 0.0;
  var pressure = true;
  var smoothAfter = false;
  var preset = brushPresetFor('solid');
  var width = preset.defaultWidth;
  var opacity = preset.defaultOpacity;
  return MaterialApp(
    theme: InkTheme.light(),
    home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
        body: Stack(
          children: [
            BrushTray(
              isOpen: true,
              strokeWidth: width,
              selectedColor: Colors.black,
              brushOpacity: opacity,
              brushType: preset.id,
              eraserEraseEverything: false,
              stabilizerStrength: strength,
              stylusPressureEnabled: pressure,
              smoothDoodlesEnabled: smoothAfter,
              onStabilizerChanged: (v) => setState(() => strength = v),
              onStylusPressureChanged: (v) => setState(() => pressure = v),
              onSmoothDoodlesChanged: (v) => setState(() => smoothAfter = v),
              onStrokeWidthChanged: (v) => setState(() => width = v),
              onOpacityChanged: (v) => setState(() => opacity = v),
              onColorSelected: (_) {},
              onBrushPresetSelected: (id) => setState(() {
                preset = brushPresetFor(id);
                width = preset.defaultWidth;
                opacity = preset.defaultOpacity;
              }),
              onEraserEraseEverythingChanged: (_) {},
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrushPreviewPainter extends CustomPainter {
  final String brushType;
  final Color color;
  final double strokeWidth;
  final double opacity;

  _BrushPreviewPainter({
    required this.brushType,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final isEraser = brushType == 'eraser';
    if (isEraser) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        strokeWidth.clamp(6.0, 24.0),
        paint,
      );
      return;
    }

    final w = size.width;
    final h = size.height;
    final p0 = Offset(16, h * 0.65);
    final p1 = Offset(w * 0.3, h * 0.25);
    final p2 = Offset(w * 0.7, h * 0.8);
    final p3 = Offset(w - 16, h * 0.35);

    final points = <Offset>[];
    final pressures = <double>[];
    const steps = 48;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final u = 1 - t;
      final x =
          u * u * u * p0.dx +
          3 * u * u * t * p1.dx +
          3 * u * t * t * p2.dx +
          t * t * t * p3.dx;
      final y =
          u * u * u * p0.dy +
          3 * u * u * t * p1.dy +
          3 * u * t * t * p2.dy +
          t * t * t * p3.dy;
      points.add(Offset(x, y));
      final pressure = 0.35 + 0.65 * math.sin(t * math.pi);
      pressures.add(pressure);
    }

    paintCanvasStroke(
      canvas: canvas,
      points: points,
      pressures: pressures,
      color: color,
      strokeWidth: strokeWidth,
      strokeOpacity: opacity,
      brushType: brushType,
      brushId: brushType,
      textureSeed: 42,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushPreviewPainter oldDelegate) {
    return oldDelegate.brushType != brushType ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.opacity != opacity;
  }
}
