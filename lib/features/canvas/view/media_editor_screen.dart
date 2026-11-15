import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../core/utils/app_snackbar.dart';
import '../geometry/canvas_element_geometry.dart';
import '../models/canvas_element.dart';
import 'widgets/image_crop_dialog.dart';

class MediaEditorResult {
  const MediaEditorResult(this.imageBytes, this.style);

  final Uint8List imageBytes;
  final ImageElement style;
}

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
  ui.Image? _decodedImage;
  int _decodeGeneration = 0;
  bool _isDecoding = true;
  String? _decodeError;
  ImageElement _style = const ImageElement(
    id: 'preview',
    z: 0,
    center: Offset.zero,
  );

  @override
  void initState() {
    super.initState();
    _workingImageBytes = widget.imageBytes;
    _decodePreview();
  }

  Future<void> _decodePreview() async {
    final generation = ++_decodeGeneration;
    setState(() {
      _isDecoding = true;
      _decodeError = null;
    });
    try {
      final codec = await ui.instantiateImageCodec(_workingImageBytes);
      ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted || generation != _decodeGeneration) {
        image.dispose();
        return;
      }
      _decodedImage?.dispose();
      setState(() {
        _decodedImage = image;
        _isDecoding = false;
        _style = _style.copyWith(
          width: image.width * _style.crop.width,
          height: image.height * _style.crop.height,
        );
      });
    } catch (_) {
      if (!mounted || generation != _decodeGeneration) return;
      _decodedImage?.dispose();
      setState(() {
        _decodedImage = null;
        _isDecoding = false;
        _decodeError = 'Could not decode image. Choose a different file.';
      });
    }
  }

  Future<void> _cropImage() async {
    final image = _decodedImage;
    if (image == null) return;
    final held = image.clone();
    Rect? crop;
    try {
      crop = await showImageCropDialog(
        context,
        image: held,
        initialCrop: _style.crop,
        flipH: _style.flipped,
        flipV: _style.flipV,
      );
    } finally {
      held.dispose();
    }
    if (!mounted || crop == null) return;
    setState(() => _style = applyImageCrop(_style, crop!));
  }

  void _reset() {
    setState(() {
      _workingImageBytes = widget.imageBytes;
      _backgroundWasRemoved = false;
      _scale = 1;
      _style = const ImageElement(id: 'preview', z: 0, center: Offset.zero);
    });
    _decodePreview();
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final decoded = img.decodeImage(_workingImageBytes);
    if (decoded == null) {
      if (!mounted) return;
      AppSnackBar.showMessage(context, 'Could not decode image.');
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
    Navigator.of(context).pop(MediaEditorResult(output, _style));
  }

  Future<void> _removeBackground() async {
    if (_isRemovingBackground) return;
    setState(() => _isRemovingBackground = true);

    try {
      final decoded = img.decodeImage(_workingImageBytes);
      if (decoded == null) {
        if (!mounted) return;
        AppSnackBar.showMessage(context, 'Could not decode image.');
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
      await _decodePreview();
      if (!mounted) return;
      AppSnackBar.showMessage(context, 'Background removal applied.');
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
        var quality = 78;
        var jpegBytes = Uint8List.fromList(
          img.encodeJpg(current, quality: quality),
        );

        while (jpegBytes.length > _maxPersistedImageBytes && quality > 10) {
          quality -= 10;
          jpegBytes = Uint8List.fromList(
            img.encodeJpg(current, quality: quality),
          );
        }

        return jpegBytes;
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
    final tokens = context.ink;
    return Scaffold(
      backgroundColor: tokens.surfaceDesk,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.s16),
          child: Column(
            children: [
              GlassPanel(
                radius: InkRadii.glassBar,
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s16),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Text('Edit Image', style: InkType.title(tokens.ink)),
                      const Spacer(),
                      TextButton(
                        onPressed: _isRemovingBackground ? null : _reset,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: InkSpacing.s16),
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(InkRadii.paperCard),
                      color: tokens.field,
                      boxShadow: tokens.paperShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(InkRadii.paperCard),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _decodeError != null
                            ? Center(
                                child: Text(
                                  _decodeError!,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : _isDecoding
                            ? const Center(child: CircularProgressIndicator())
                            : FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox.fromSize(
                                  size: elementBounds(_style)!.size,
                                  child: CustomPaint(
                                    painter: _MediaImagePainter(
                                      _style,
                                      _decodedImage!,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: InkSpacing.s12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Crop',
                            icon: const Icon(LucideIcons.crop),
                            onPressed:
                                _decodedImage == null ||
                                    _isDecoding ||
                                    _isRemovingBackground
                                ? null
                                : _cropImage,
                          ),
                          IconButton(
                            tooltip: 'Rotate 90°',
                            icon: const Icon(LucideIcons.rotateCw),
                            onPressed: () => setState(
                              () => _style = _style.copyWith(
                                rotation:
                                    (_style.rotation + math.pi / 2) %
                                    (2 * math.pi),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Flip horizontal',
                            icon: const Icon(LucideIcons.flipHorizontal2),
                            isSelected: _style.flipped,
                            onPressed: () => setState(
                              () => _style = _style.copyWith(
                                flipped: !_style.flipped,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Flip vertical',
                            icon: const Icon(LucideIcons.flipVertical2),
                            isSelected: _style.flipV,
                            onPressed: () => setState(
                              () => _style = _style.copyWith(
                                flipV: !_style.flipV,
                              ),
                            ),
                          ),
                          if (_style.crop != ImageElement.fullCrop)
                            TextButton(
                              onPressed: () => setState(
                                () => _style = applyImageCrop(
                                  _style,
                                  ImageElement.fullCrop,
                                ),
                              ),
                              child: const Text('Reset crop'),
                            ),
                        ],
                      ),
                      _SliderRow(
                        label: 'Opacity',
                        valueLabel: '${(_style.opacity * 100).round()}%',
                        value: _style.opacity,
                        min: 0,
                        max: 1,
                        onChanged: (v) => setState(
                          () => _style = _style.copyWith(opacity: v),
                        ),
                      ),
                      _SliderRow(
                        label: 'Corner radius',
                        valueLabel: _style.borderRadius.toStringAsFixed(0),
                        value: _style.borderRadius,
                        min: 0,
                        max: 120,
                        onChanged: (v) => setState(
                          () => _style = _style.copyWith(borderRadius: v),
                        ),
                      ),
                      _SliderRow(
                        label: 'Border',
                        valueLabel: _style.borderWidth.toStringAsFixed(0),
                        value: _style.borderWidth,
                        min: 0,
                        max: 16,
                        onChanged: (v) => setState(
                          () => _style = _style.copyWith(borderWidth: v),
                        ),
                      ),
                      if (_style.borderWidth > 0)
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final color in const [
                              Colors.black,
                              Colors.white,
                              Colors.red,
                              Colors.blue,
                              Colors.green,
                            ])
                              IconButton(
                                tooltip:
                                    'Border color ${color.toARGB32().toRadixString(16)}',
                                icon: Icon(LucideIcons.circle, color: color),
                                isSelected: _style.borderColor == color,
                                onPressed: () => setState(
                                  () => _style = _style.copyWith(
                                    borderColor: color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      for (final (label, value, update)
                          in <(String, double, ImageElement Function(double))>[
                            (
                              'Brightness',
                              _style.brightness,
                              (v) => _style.copyWith(brightness: v),
                            ),
                            (
                              'Contrast',
                              _style.contrast,
                              (v) => _style.copyWith(contrast: v),
                            ),
                            (
                              'Saturation',
                              _style.saturation,
                              (v) => _style.copyWith(saturation: v),
                            ),
                          ])
                        _SliderRow(
                          label: label,
                          valueLabel: '${(value * 100).round()}%',
                          value: value,
                          min: -1,
                          max: 1,
                          onChanged: (v) => setState(() => _style = update(v)),
                        ),
                      if (_style.hasFilters)
                        TextButton(
                          onPressed: () => setState(
                            () => _style = _style.copyWith(
                              brightness: 0,
                              contrast: 0,
                              saturation: 0,
                            ),
                          ),
                          child: const Text('Reset filters'),
                        ),
                      SwitchListTile.adaptive(
                        title: const Text('Use as reference'),
                        subtitle: const Text(
                          'Faded and locked behind artwork when added.',
                        ),
                        value: _style.isReference,
                        onChanged: (v) => setState(
                          () => _style = _style.copyWith(isReference: v),
                        ),
                      ),
                      _SliderRow(
                        label: 'Source resolution',
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
                      const SizedBox(height: InkSpacing.s8),
                      InkButton.secondary(
                        label: 'Remove Background',
                        icon: _isRemovingBackground
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: tokens.ink,
                                ),
                              )
                            : const Icon(LucideIcons.eraser),
                        onPressed:
                            _isRemovingBackground ||
                                _isDecoding ||
                                _decodeError != null
                            ? null
                            : _removeBackground,
                      ),
                      const SizedBox(height: InkSpacing.s12),
                      InkButton.primary(
                        key: const Key('image-editor-done'),
                        label: 'Done',
                        onPressed:
                            _isDecoding ||
                                _isRemovingBackground ||
                                _decodeError != null
                            ? null
                            : _save,
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

class _MediaImagePainter extends CustomPainter {
  const _MediaImagePainter(this.style, this.image);

  final ImageElement style;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = elementBounds(style)!;
    canvas.save();
    canvas.translate(-bounds.left, -bounds.top);
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: style.opacity),
    );
    paintImageElement(canvas, style, image);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MediaImagePainter old) =>
      old.style != style || old.image != image;
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
    final tokens = context.ink;
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: InkType.bodyStrong(tokens.ink)),
            const Spacer(),
            Text(valueLabel, style: InkType.label(tokens.inkMuted)),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
