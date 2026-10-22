import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/sliding_tray.dart';
import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../../../ui/theme/ink_type.dart';
import '../../../../ui/widgets/ink_segmented.dart';
import '../../models/canvas_tool_mode.dart';

class BrushTray extends StatefulWidget {
  final bool isOpen;
  final double strokeWidth;
  final Color selectedColor;
  final double brushOpacity;
  final String brushType;
  final bool eraserEraseEverything;
  final bool smoothDoodlesEnabled;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<String> onBrushTypeChanged;
  final ValueChanged<CanvasToolMode>? onToolModeChanged;
  final ValueChanged<bool> onEraserEraseEverythingChanged;
  final ValueChanged<bool>? onSmoothDoodlesChanged;
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
    required this.onStrokeWidthChanged,
    required this.onColorSelected,
    required this.onOpacityChanged,
    required this.onBrushTypeChanged,
    this.onToolModeChanged,
    required this.onEraserEraseEverythingChanged,
    this.onSmoothDoodlesChanged,
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

  static const _brushTypes = ['solid', 'textured', 'watercolor', 'eraser'];
  static const _brushTypeLabels = ['Solid', 'Textured', 'Watercolor', 'Eraser'];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _redController = TextEditingController();
    _greenController = TextEditingController();
    _blueController = TextEditingController();
    _updateColorControllers(widget.selectedColor);
  }

  @override
  void didUpdateWidget(BrushTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor != widget.selectedColor) {
      _updateColorControllers(widget.selectedColor);
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

  void _onBrushTypeSelected(String type) {
    widget.onBrushTypeChanged(type);
    switch (type) {
      case 'eraser':
        widget.onToolModeChanged?.call(CanvasToolMode.eraser);
      case 'highlight':
        widget.onToolModeChanged?.call(CanvasToolMode.highlight);
      default:
        widget.onToolModeChanged?.call(CanvasToolMode.doodle);
    }
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
      height: 460,
      onClose: widget.onClose,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBrushSizeIndicator(tokens),
              const SizedBox(height: InkSpacing.s16),
              _buildStrokeWidthControl(tokens),
              const SizedBox(height: InkSpacing.s16),
              if (widget.brushType == 'eraser') ...[
                _buildEraserModeControl(tokens),
                const SizedBox(height: InkSpacing.s16),
              ],
              _buildOpacityControl(tokens),
              const SizedBox(height: InkSpacing.s16),
              _buildBrushTypeSelector(tokens),
              const SizedBox(height: InkSpacing.s16),
              if (widget.brushType != 'eraser') ...[
                _buildSmoothToggle(tokens),
                const SizedBox(height: InkSpacing.s16),
              ],
              _buildColorPalette(tokens, colors),
              const SizedBox(height: InkSpacing.s12),
              _buildColorInputs(tokens),
              const SizedBox(height: InkSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrushSizeIndicator(InkTokens tokens) {
    final isEraser = widget.brushType == 'eraser';
    return Center(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tokens.field,
          borderRadius: BorderRadius.circular(InkRadii.input),
        ),
        child: Center(
          child: Container(
            width: widget.strokeWidth,
            height: widget.strokeWidth,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEraser
                  ? tokens.inkMuted.withValues(alpha: 0.3)
                  : widget.selectedColor.withValues(alpha: widget.brushOpacity),
            ),
            child: isEraser
                ? Icon(LucideIcons.eraser, size: 16, color: tokens.inkMuted)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStrokeWidthControl(InkTokens tokens) {
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
                    widget.brushType == 'eraser' ? 'Eraser Size' : 'Stroke Width',
                    style: InkType.label(tokens.inkSecondary),
                  ),
                  Text(
                    '${widget.strokeWidth.toStringAsFixed(1)}px',
                    style: InkType.label(tokens.ink),
                  ),
                ],
              ),
              Slider(
                value: widget.strokeWidth,
                min: 2,
                max: 48,
                onChanged: widget.onStrokeWidthChanged,
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

  Widget _buildBrushTypeSelector(InkTokens tokens) {
    final selectedIndex = _brushTypes.indexOf(widget.brushType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Brush Type', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        InkSegmented(
          labels: _brushTypeLabels,
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          onChanged: (i) => _onBrushTypeSelected(_brushTypes[i]),
        ),
      ],
    );
  }

  Widget _buildEraserModeControl(InkTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eraser Target', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: widget.eraserEraseEverything,
          onChanged: widget.onEraserEraseEverythingChanged,
          title: Text('Erase everything it touches', style: InkType.body(tokens.ink)),
          subtitle: Text('Off = erase brush strokes only', style: InkType.caption(tokens.inkMuted)),
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
              Text('Smooth Doodles', style: InkType.label(tokens.inkSecondary)),
              Switch.adaptive(
                value: widget.smoothDoodlesEnabled,
                onChanged: widget.onSmoothDoodlesChanged,
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
        Text('Colors', style: InkType.label(tokens.inkSecondary)),
        const SizedBox(height: InkSpacing.s8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: colors
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => widget.onColorSelected(c),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(widget.selectedColor == c ? 2 : 0),
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
