import 'package:flutter/material.dart';
import '../widgets/sliding_tray.dart';

class BrushTray extends StatefulWidget {
  final bool isOpen;
  final double strokeWidth;
  final Color selectedColor;
  final double brushOpacity;
  final String brushType;
  final bool eraserEraseEverything;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<String> onBrushTypeChanged;
  final ValueChanged<bool> onEraserEraseEverythingChanged;

  const BrushTray({
    super.key,
    required this.isOpen,
    required this.strokeWidth,
    required this.selectedColor,
    required this.brushOpacity,
    required this.brushType,
    required this.eraserEraseEverything,
    required this.onStrokeWidthChanged,
    required this.onColorSelected,
    required this.onOpacityChanged,
    required this.onBrushTypeChanged,
    required this.onEraserEraseEverythingChanged,
  });

  @override
  State<BrushTray> createState() => _BrushTrayState();
}

class _BrushTrayState extends State<BrushTray> {
  late TextEditingController _hexController;
  late TextEditingController _redController;
  late TextEditingController _greenController;
  late TextEditingController _blueController;

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

    const brushTypes = ['solid', 'textured', 'watercolor', 'eraser'];

    return SlidingTray(
      isOpen: widget.isOpen,
      direction: TrayDirection.bottom,
      title: 'Brush & Color',
      height: 420,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Brush Size Indicator
              _buildBrushSizeIndicator(),
              const SizedBox(height: 16),

              /// Stroke Width Slider
              _buildStrokeWidthControl(),
              const SizedBox(height: 16),

              if (widget.brushType == 'eraser') ...[
                _buildEraserModeControl(),
                const SizedBox(height: 16),
              ],

              /// Opacity Slider
              _buildOpacityControl(),
              const SizedBox(height: 16),

              /// Brush Type Selector
              _buildBrushTypeSelector(brushTypes),
              const SizedBox(height: 16),

              /// Color Palette (Horizontal Scroll)
              _buildColorPalette(colors),
              const SizedBox(height: 12),

              /// RGB/HEX Input
              _buildColorInputs(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrushSizeIndicator() {
    final isEraser = widget.brushType == 'eraser';
    return Center(
      child: Container(
        width: 120,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Center(
          child: Container(
            width: widget.strokeWidth * 2,
            height: widget.strokeWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEraser
                  ? Colors.grey.withOpacity(0.2)
                  : widget.selectedColor.withOpacity(widget.brushOpacity),
            ),
            child: isEraser
                ? const Icon(
                    Icons.auto_fix_off,
                    size: 18,
                    color: Colors.black54,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStrokeWidthControl() {
    return Row(
      children: [
        const Icon(Icons.edit, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    '${widget.strokeWidth.toStringAsFixed(1)}px',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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

  Widget _buildOpacityControl() {
    return Row(
      children: [
        const Icon(Icons.opacity, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Opacity',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  Text(
                    '${(widget.brushOpacity * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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

  Widget _buildBrushTypeSelector(List<String> brushTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brush Type',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Row(
          children: brushTypes
              .map(
                (type) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(
                        type == 'eraser'
                            ? 'Eraser'
                            : type[0].toUpperCase() + type.substring(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: widget.brushType == type,
                      onSelected: (selected) {
                        if (selected) widget.onBrushTypeChanged(type);
                      },
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEraserModeControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eraser Target',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: widget.eraserEraseEverything,
          onChanged: widget.onEraserEraseEverythingChanged,
          title: const Text(
            'Erase everything it touches',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: const Text(
            'Off = erase brush strokes only',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPalette(List<Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Colors', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: colors
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => widget.onColorSelected(c),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: widget.selectedColor == c
                                ? Colors.black
                                : Colors.grey[300]!,
                            width: widget.selectedColor == c ? 3 : 1,
                          ),
                        ),
                        child: widget.selectedColor == c
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
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

  Widget _buildColorInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Color',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),

        /// HEX Input
        Row(
          children: [
            Text('#', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _hexController,
                onChanged: _updateColorFromHex,
                maxLength: 6,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  hintText: 'HEX',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),

            /// RGB Inputs
            ...[
              ('R', _redController),
              ('G', _greenController),
              ('B', _blueController),
            ].map(
              (pair) => Expanded(
                child: Column(
                  children: [
                    Text(
                      pair.$1,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: pair.$2,
                      onChanged: (_) => _updateColorFromRGB(),
                      maxLength: 3,
                      style: const TextStyle(fontSize: 11),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
