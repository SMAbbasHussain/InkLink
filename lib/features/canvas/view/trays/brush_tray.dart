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
  final Map<String, List<Color>> palettes;
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
    this.palettes = const <String, List<Color>>{},
    this.eyedropperActive = false,
    this.onOpenColorPicker,
    this.onEyedropperRequested,
    this.onClose,
  });

  @override
  State<BrushTray> createState() => _BrushTrayState();
}

class _BrushTrayState extends State<BrushTray> {
  bool _showPalettes = false;
  String? _selectedPaletteName;

  @override
  void initState() {
    super.initState();
    _selectedPaletteName = widget.palettes.keys.firstOrNull;
  }

  @override
  void didUpdateWidget(BrushTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPaletteName == null ||
        !widget.palettes.containsKey(_selectedPaletteName)) {
      _selectedPaletteName = widget.palettes.keys.firstOrNull;
    }
  }

  void _onBrushPresetSelected(BrushPreset preset) {
    HapticFeedback.selectionClick();
    widget.onBrushPresetSelected(preset.id);
    widget.onToolModeChanged?.call(
      preset.id == 'highlighter'
          ? CanvasToolMode.highlight
          : CanvasToolMode.doodle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    const defaultColors = <Color>[
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
              _buildColorsSection(tokens, defaultColors),
              const SizedBox(height: InkSpacing.s12),
              _buildBrushPresetPicker(tokens),
              const SizedBox(height: InkSpacing.s12),
              _buildLiveBrushPreview(tokens),
              const SizedBox(height: InkSpacing.s16),
              // Sliders section (brush size at the top of sliders)
              _buildStrokeWidthControl(tokens),
              const SizedBox(height: InkSpacing.s12),
              _buildOpacityControl(tokens),
              if (widget.brushType != 'eraser') ...[
                const SizedBox(height: InkSpacing.s12),
                _buildStabilizerControl(tokens),
              ],
              // Toggles section at the bottom
              if (widget.brushType == 'eraser') ...[
                const SizedBox(height: InkSpacing.s12),
                _buildEraserModeControl(tokens),
              ],
              const SizedBox(height: InkSpacing.s12),
              _buildFingerDrawingToggle(tokens),
              if (widget.brushType != 'eraser') ...[
                const SizedBox(height: InkSpacing.s12),
                _buildStylusPressureToggle(tokens),
                const SizedBox(height: InkSpacing.s12),
                _buildQuickShapeToggle(tokens),
                const SizedBox(height: InkSpacing.s12),
                _buildSmoothToggle(tokens),
              ],
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
    final pressureTag = isEraser
        ? 'Eraser preview'
        : (widget.stylusPressureEnabled &&
                  (preset.pressureAffectsSize || preset.pressureAffectsOpacity)
              ? 'Pressure & dwell active'
              : 'Uniform weight');

    return Container(
      width: double.infinity,
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  stylusPressureEnabled: widget.stylusPressureEnabled,
                  gridColor: tokens.glassStroke.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.paper.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${preset.description} · $pressureTag',
                style: InkType.caption(tokens.inkMuted),
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
                activeColor: Colors.white,
                activeTrackColor: tokens.accent,
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
                activeColor: Colors.white,
                activeTrackColor: tokens.accent,
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
                activeColor: Colors.white,
                activeTrackColor: tokens.accent,
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
        Text('Brushes', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        SizedBox(
          height: 62,
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
      ],
    );
  }

  Widget _buildPresetCard(InkTokens tokens, BrushPreset preset) {
    final selected = widget.brushType == preset.id;
    final swatchColor = selected ? tokens.accent : tokens.ink;
    return InkWell(
      key: ValueKey('brush-preset-${preset.id}'),
      onTap: () => _onBrushPresetSelected(preset),
      borderRadius: BorderRadius.circular(InkRadii.input),
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  preset.icon,
                  size: 14,
                  color: selected ? tokens.accent : tokens.inkMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: InkType.label(selected ? tokens.accent : tokens.ink),
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              height: 22,
              child: CustomPaint(
                painter: _MiniBrushArtworkPainter(
                  preset: preset,
                  color: swatchColor,
                ),
              ),
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
                activeColor: Colors.white,
                activeTrackColor: tokens.accent,
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

  Widget _buildColorsSection(InkTokens tokens, List<Color> defaultColors) {
    final activePaletteName = _selectedPaletteName != null &&
            widget.palettes.containsKey(_selectedPaletteName)
        ? _selectedPaletteName
        : widget.palettes.keys.firstOrNull;
    final paletteColors = activePaletteName != null
        ? (widget.palettes[activePaletteName] ?? const <Color>[])
        : const <Color>[];
    final displayedColors = _showPalettes
        ? paletteColors
        : (widget.recentColors.isNotEmpty ? widget.recentColors : defaultColors);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(
              key: const ValueKey('brush-colors-recent-tab'),
              label: const Text('Recent'),
              selected: !_showPalettes,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _showPalettes = false),
              labelStyle: InkType.caption(
                !_showPalettes ? tokens.accent : tokens.inkSecondary,
              ),
              backgroundColor: tokens.field,
              selectedColor: tokens.accent.withValues(alpha: 0.15),
              side: BorderSide(
                color: !_showPalettes ? tokens.accent : tokens.glassStroke,
              ),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              key: const ValueKey('brush-colors-palettes-tab'),
              label: const Text('Palettes'),
              selected: _showPalettes,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() {
                _showPalettes = true;
                _selectedPaletteName ??= widget.palettes.keys.firstOrNull;
              }),
              labelStyle: InkType.caption(
                _showPalettes ? tokens.accent : tokens.inkSecondary,
              ),
              backgroundColor: tokens.field,
              selectedColor: tokens.accent.withValues(alpha: 0.15),
              side: BorderSide(
                color: _showPalettes ? tokens.accent : tokens.glassStroke,
              ),
            ),
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
        if (_showPalettes && widget.palettes.isNotEmpty) ...[
          const SizedBox(height: InkSpacing.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final name in widget.palettes.keys) ...[
                  ChoiceChip(
                    key: ValueKey('brush-palette-tab-$name'),
                    label: Text(name),
                    selected: name == activePaletteName,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) =>
                        setState(() => _selectedPaletteName = name),
                    labelStyle: InkType.caption(
                      name == activePaletteName
                          ? tokens.accent
                          : tokens.inkSecondary,
                    ),
                    backgroundColor: tokens.field,
                    selectedColor: tokens.accent.withValues(alpha: 0.15),
                    side: BorderSide(
                      color: name == activePaletteName
                          ? tokens.accent
                          : tokens.glassStroke,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: InkSpacing.s8),
        if (_showPalettes && widget.palettes.isEmpty)
          Row(
            children: [
              Text(
                'No saved palettes yet',
                style: InkType.caption(tokens.inkMuted),
              ),
              if (widget.onOpenColorPicker != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onOpenColorPicker,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Create'),
                ),
              ],
            ],
          )
        else if (displayedColors.isEmpty)
          Text(
            'No colors in this palette yet',
            style: InkType.caption(tokens.inkMuted),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayedColors
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
                            width: 34,
                            height: 34,
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

class _MiniBrushArtworkPainter extends CustomPainter {
  final BrushPreset preset;
  final Color color;

  const _MiniBrushArtworkPainter({
    required this.preset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    final p0 = Offset(4, h * 0.68);
    final p1 = Offset(w * 0.35, h * 0.15);
    final p2 = Offset(w * 0.68, h * 0.85);
    final p3 = Offset(w - 6, h * 0.38);

    final points = <Offset>[];
    final pressures = <double>[];
    const steps = 20;
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
      pressures.add(0.22 + 0.78 * math.sin(t * math.pi));
    }

    final sampleWidth = preset.defaultWidth.clamp(3.0, 9.0);
    paintCanvasStroke(
      canvas: canvas,
      points: points,
      pressures: pressures,
      color: color,
      strokeWidth: sampleWidth,
      strokeOpacity: preset.defaultOpacity,
      brushType: preset.id,
      brushId: preset.id,
      textureSeed: 17,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniBrushArtworkPainter oldDelegate) {
    return oldDelegate.preset.id != preset.id || oldDelegate.color != color;
  }
}

class _BrushPreviewPainter extends CustomPainter {
  final String brushType;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool stylusPressureEnabled;
  final Color gridColor;

  _BrushPreviewPainter({
    required this.brushType,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    this.stylusPressureEnabled = true,
    this.gridColor = const Color(0x2294A3B8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Subtle paper grid backdrop so translucency, multiply blend, and wash bleed
    // are immediately visible against the surface.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.75;
    const gridStep = 16.0;
    for (double x = gridStep; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = gridStep; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

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

    // Secondary overlapping companion stroke to visualize layering, grain tooth,
    // and blend mode (e.g. highlighter multiply, watercolor glazing).
    final accentPoints = <Offset>[];
    final accentPressures = <double>[];
    final a0 = Offset(w * 0.56, h * 0.78);
    final a1 = Offset(w * 0.68, h * 0.22);
    final a2 = Offset(w * 0.88, h * 0.28);
    const accentSteps = 22;
    for (int i = 0; i <= accentSteps; i++) {
      final t = i / accentSteps;
      final u = 1 - t;
      final x = u * u * a0.dx + 2 * u * t * a1.dx + t * t * a2.dx;
      final y = u * u * a0.dy + 2 * u * t * a1.dy + t * t * a2.dy;
      accentPoints.add(Offset(x, y));
      accentPressures.add(
        stylusPressureEnabled ? (0.3 + 0.55 * math.sin(t * math.pi)) : 1.0,
      );
    }
    paintCanvasStroke(
      canvas: canvas,
      points: accentPoints,
      pressures: accentPressures,
      color: color,
      strokeWidth: (strokeWidth * 0.82).clamp(1.0, 64.0),
      strokeOpacity: (opacity * 0.75).clamp(0.1, 1.0),
      brushType: brushType,
      brushId: brushType,
      textureSeed: 84,
    );

    // Primary expressive artwork stroke: light entry -> heavy pressure swell ->
    // dynamic taper -> held dwell spot at the tail.
    final p0 = Offset(14, h * 0.66);
    final p1 = Offset(w * 0.28, h * 0.14);
    final p2 = Offset(w * 0.64, h * 0.88);
    final p3 = Offset(w - 22, h * 0.42);

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
      final double pressure;
      if (!stylusPressureEnabled) {
        pressure = 1.0;
      } else if (t > 0.92) {
        // Demonstrate hold-on-spot darkening/pooling at the end of the stroke.
        pressure = 0.85 + (t - 0.92) * 5.0;
      } else {
        pressure = 0.2 + 0.8 * math.sin(t * math.pi);
      }
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
        oldDelegate.opacity != opacity ||
        oldDelegate.stylusPressureEnabled != stylusPressureEnabled ||
        oldDelegate.gridColor != gridColor;
  }
}
