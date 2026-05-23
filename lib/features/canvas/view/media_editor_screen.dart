import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class MediaEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const MediaEditorScreen({super.key, required this.imageBytes});

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  static const int _maxPersistedImageBytes = 650000;
  static const int _minPersistedImageSide = 512;
  double _scale = 1.0;
  double _backgroundThreshold = 225;
  bool _isRemovingBackground = false;
  late Uint8List _workingImageBytes;
  bool _backgroundWasRemoved = false;

  @override
  void initState() {
    super.initState();
    _workingImageBytes = widget.imageBytes;
  }

  Future<void> _save() async {
    final decoded = img.decodeImage(_workingImageBytes);
    if (decoded == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not decode image.')));
      return;
    }

    final scaled = _scale == 1.0
        ? decoded
        : img.copyResize(
            decoded,
            width: (decoded.width * _scale).round(),
            height: (decoded.height * _scale).round(),
            interpolation: img.Interpolation.linear,
          );

    final maxSide = scaled.width > scaled.height ? scaled.width : scaled.height;
    final resized = maxSide > 1280
        ? img.copyResize(
            scaled,
            width: scaled.width >= scaled.height ? 1280 : null,
            height: scaled.height > scaled.width ? 1280 : null,
            interpolation: img.Interpolation.average,
          )
        : scaled;

    final output = _backgroundWasRemoved
        ? _encodePngWithinLimit(resized)
        : Uint8List.fromList(img.encodeJpg(resized, quality: 78));
    if (!mounted) return;
    Navigator.of(context).pop(output);
  }

  Future<void> _removeBackground() async {
    if (_isRemovingBackground) return;
    setState(() => _isRemovingBackground = true);

    try {
      final decoded = img.decodeImage(_workingImageBytes);
      if (decoded == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decode image.')),
        );
        return;
      }

      final output = img.Image.from(decoded);
      final threshold = _backgroundThreshold.toInt();

      for (var y = 0; y < output.height; y++) {
        for (var x = 0; x < output.width; x++) {
          final pixel = output.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          final isLight = r >= threshold && g >= threshold && b >= threshold;
          final channelDelta = (r - g).abs() + (g - b).abs() + (b - r).abs();
          final nearNeutral = channelDelta < 48;

          if (isLight && nearNeutral) {
            output.setPixelRgba(x, y, r, g, b, 0);
          }
        }
      }

      final bytes = Uint8List.fromList(img.encodePng(output));
      if (!mounted) return;
      setState(() {
        _workingImageBytes = bytes;
        _backgroundWasRemoved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background removal applied.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRemovingBackground = false);
      }
    }
  }

  Uint8List _encodePngWithinLimit(img.Image image) {
    var current = image;

    while (true) {
      final bytes = Uint8List.fromList(img.encodePng(current, level: 9));
      if (bytes.length <= _maxPersistedImageBytes) {
        return bytes;
      }

      if (current.width <= _minPersistedImageSide &&
          current.height <= _minPersistedImageSide) {
        return bytes;
      }

      final nextWidth = math.max(
        (current.width * 0.85).round(),
        _minPersistedImageSide,
      );
      final nextHeight = math.max(
        (current.height * 0.85).round(),
        _minPersistedImageSide,
      );

      if (nextWidth == current.width && nextHeight == current.height) {
        return bytes;
      }

      current = current.width >= current.height
          ? img.copyResize(
              current,
              width: nextWidth,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              current,
              height: nextHeight,
              interpolation: img.Interpolation.average,
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Image'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _workingImageBytes = widget.imageBytes;
              _backgroundWasRemoved = false;
            }),
            child: const Text('Reset'),
          ),
          TextButton(onPressed: _save, child: const Text('Done')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                      color: Colors.grey.shade100,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRect(
                        child: Transform.translate(
                          offset: Offset.zero,
                          child: Transform.scale(
                            scale: _scale,
                            child: Image.memory(
                              _workingImageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _SliderRow(
                        label: 'Scale',
                        valueLabel: _scale.toStringAsFixed(2),
                        value: _scale,
                        min: 0.6,
                        max: 2.4,
                        onChanged: (v) => setState(() => _scale = v),
                      ),
                      _SliderRow(
                        label: 'BG Threshold',
                        valueLabel: _backgroundThreshold.toStringAsFixed(0),
                        value: _backgroundThreshold,
                        min: 170,
                        max: 250,
                        onChanged: (v) =>
                            setState(() => _backgroundThreshold = v),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRemovingBackground
                              ? null
                              : _removeBackground,
                          icon: _isRemovingBackground
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.layers_clear, size: 16),
                          label: const Text('Remove Background'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(valueLabel),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
