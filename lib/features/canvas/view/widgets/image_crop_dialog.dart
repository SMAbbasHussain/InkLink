import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../geometry/canvas_element_geometry.dart';
import '../../models/canvas_element.dart';

/// Opens the crop editor and resolves to a normalized source-image crop, or
/// null when cancelled. The image is shown mirrored like on the board, so the
/// user crops what they see; the result is mapped back to source pixels.
Future<Rect?> showImageCropDialog(
  BuildContext context, {
  required ui.Image image,
  required Rect initialCrop,
  bool flipH = false,
  bool flipV = false,
}) {
  return showDialog<Rect>(
    context: context,
    builder: (_) => ImageCropDialog(
      image: image,
      initialCrop: initialCrop,
      flipH: flipH,
      flipV: flipV,
    ),
  );
}

enum _CropHandle { move, topLeft, topRight, bottomLeft, bottomRight }

class ImageCropDialog extends StatefulWidget {
  const ImageCropDialog({
    super.key,
    required this.image,
    required this.initialCrop,
    this.flipH = false,
    this.flipV = false,
  });

  final ui.Image image;
  final Rect initialCrop;
  final bool flipH;
  final bool flipV;

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  static const double _handleHitRadius = 24;
  static const List<(String, double?)> _aspectPresets = [
    ('Free', null),
    ('1:1', 1),
    ('4:3', 4 / 3),
    ('3:4', 3 / 4),
    ('16:9', 16 / 9),
  ];

  late Rect _crop;
  double? _aspect;
  _CropHandle? _activeHandle;

  double get _imageWidth => widget.image.width.toDouble();
  double get _imageHeight => widget.image.height.toDouble();

  @override
  void initState() {
    super.initState();
    _crop = _mirror(clampImageCrop(widget.initialCrop));
  }

  /// Mirrors a normalized rect through the board flips; it is its own inverse.
  Rect _mirror(Rect r) => Rect.fromLTRB(
    widget.flipH ? 1 - r.right : r.left,
    widget.flipV ? 1 - r.bottom : r.top,
    widget.flipH ? 1 - r.left : r.right,
    widget.flipV ? 1 - r.top : r.bottom,
  );

  /// Normalized height that gives [width] the pixel aspect [ratio].
  double _heightFor(double width, double ratio) =>
      width * _imageWidth / (_imageHeight * ratio);

  void _applyAspect(double? ratio) {
    setState(() {
      _aspect = ratio;
      if (ratio == null) return;
      final q = _heightFor(1, ratio);
      const minSize = kMinImageCropFraction;
      final minWidth = math.max(minSize, minSize / q);
      final maxWidth = math.min(1.0, 1.0 / q);
      final width = math
          .min(_crop.width, _crop.height / q)
          .clamp(minWidth, maxWidth);
      final height = width * q;
      _crop = Rect.fromCenter(
        center: Offset(
          _crop.center.dx.clamp(width / 2, 1 - width / 2),
          _crop.center.dy.clamp(height / 2, 1 - height / 2),
        ),
        width: width,
        height: height,
      );
    });
  }

  _CropHandle? _hitHandle(Offset local, Size box) {
    final rect = Rect.fromLTRB(
      _crop.left * box.width,
      _crop.top * box.height,
      _crop.right * box.width,
      _crop.bottom * box.height,
    );
    final corners = <_CropHandle, Offset>{
      _CropHandle.topLeft: rect.topLeft,
      _CropHandle.topRight: rect.topRight,
      _CropHandle.bottomLeft: rect.bottomLeft,
      _CropHandle.bottomRight: rect.bottomRight,
    };
    for (final entry in corners.entries) {
      if ((entry.value - local).distance <= _handleHitRadius) return entry.key;
    }
    return rect.contains(local) ? _CropHandle.move : null;
  }

  void _drag(Offset delta, Size box) {
    final handle = _activeHandle;
    if (handle == null) return;
    final dx = delta.dx / box.width;
    final dy = delta.dy / box.height;
    if (handle == _CropHandle.move) {
      final shiftX = dx.clamp(-_crop.left, 1 - _crop.right);
      final shiftY = dy.clamp(-_crop.top, 1 - _crop.bottom);
      setState(() => _crop = _crop.shift(Offset(shiftX, shiftY)));
      return;
    }

    const minSize = kMinImageCropFraction;
    final movesLeft =
        handle == _CropHandle.topLeft || handle == _CropHandle.bottomLeft;
    final movesTop =
        handle == _CropHandle.topLeft || handle == _CropHandle.topRight;
    final anchorX = movesLeft ? _crop.right : _crop.left;
    final anchorY = movesTop ? _crop.bottom : _crop.top;
    final maxWidth = movesLeft ? anchorX : 1 - anchorX;
    final maxHeight = movesTop ? anchorY : 1 - anchorY;
    var width = (_crop.width + (movesLeft ? -dx : dx)).clamp(minSize, maxWidth);
    var height = (_crop.height + (movesTop ? -dy : dy)).clamp(
      minSize,
      maxHeight,
    );
    final ratio = _aspect;
    if (ratio != null) {
      final q = _heightFor(1, ratio);
      final fromX = movesLeft ? -dx : dx;
      final fromY = (movesTop ? -dy : dy) / q;
      final change = fromX.abs() >= fromY.abs() ? fromX : fromY;
      width = (_crop.width + change).clamp(
        math.max(minSize, minSize / q),
        math.min(maxWidth, maxHeight / q),
      );
      height = width * q;
    }
    setState(() {
      _crop = Rect.fromLTRB(
        movesLeft ? anchorX - width : anchorX,
        movesTop ? anchorY - height : anchorY,
        movesLeft ? anchorX : anchorX + width,
        movesTop ? anchorY : anchorY + height,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aspect = _imageWidth / _imageHeight;
    final availableWidth = math.max(
      1.0,
      MediaQuery.sizeOf(context).width - 112,
    );
    final width = math.min(math.min(320.0, availableWidth), 320.0 * aspect);
    final box = Size(width, width / aspect);
    return AlertDialog(
      scrollable: true,
      title: const Text('Crop image'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: GestureDetector(
                key: const Key('image-crop-area'),
                onPanStart: (d) =>
                    _activeHandle = _hitHandle(d.localPosition, box),
                onPanUpdate: (d) => _drag(d.delta, box),
                onPanEnd: (_) => _activeHandle = null,
                child: SizedBox.fromSize(
                  size: box,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scaleX: widget.flipH ? -1 : 1,
                        scaleY: widget.flipV ? -1 : 1,
                        child: RawImage(image: widget.image, fit: BoxFit.fill),
                      ),
                      CustomPaint(
                        painter: _CropOverlayPainter(
                          crop: _crop,
                          accent: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Drag a corner to resize; drag inside to move.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final (label, ratio) in _aspectPresets)
                  ChoiceChip(
                    key: Key('image-crop-aspect-$label'),
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: _aspect == ratio,
                    visualDensity: VisualDensity.compact,
                    onSelected:
                        ratio == null ||
                            (_heightFor(1, ratio) * kMinImageCropFraction <=
                                    1 &&
                                kMinImageCropFraction / _heightFor(1, ratio) <=
                                    1)
                        ? (_) => _applyAspect(ratio)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('image-crop-reset'),
          onPressed: () => setState(() {
            _crop = ImageElement.fullCrop;
            _aspect = null;
          }),
          child: const Text('Reset'),
        ),
        TextButton(
          key: const Key('image-crop-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('image-crop-apply'),
          onPressed: () =>
              Navigator.of(context).pop(clampImageCrop(_mirror(_crop))),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.crop, required this.accent});

  final Rect crop;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(shade, Paint()..color = const Color(0x99000000));

    final grid = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
    final handle = Paint()..color = accent;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 6, handle);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.crop != crop || old.accent != accent;
}
