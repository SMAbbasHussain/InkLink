import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/desk_background.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_segmented.dart';
import '../../../ui/widgets/ink_text_field.dart';
import 'widgets/ai_image_widgets.dart';

/// What the repaint screen returns: the mask and what to paint there.
class AiRepaintResult {
  /// PNG with exactly the source image's pixel size. White = repaint,
  /// black = keep.
  final Uint8List maskPng;
  final String prompt;

  const AiRepaintResult({required this.maskPng, required this.prompt});
}

/// One brush stroke of the mask, in source-image pixel coordinates.
class AiMaskStroke {
  final List<Offset> points;

  /// Brush diameter in source-image pixels.
  final double width;

  /// True for the eraser (removes mask), false for the brush (adds mask).
  final bool erase;

  const AiMaskStroke({
    required this.points,
    required this.width,
    this.erase = false,
  });
}

// Mask pixel values are part of the server contract, not UI colours.
const Color _maskRepaint = Color(0xFFFFFFFF);
const Color _maskKeep = Color(0xFF000000);

void _paintMaskStrokes(
  Canvas canvas,
  List<AiMaskStroke> strokes, {
  required Color paintColor,
  required Color? eraseColor,
}) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.width
      ..isAntiAlias = true;
    if (stroke.erase) {
      if (eraseColor == null) {
        paint.blendMode = BlendMode.clear;
      } else {
        paint.color = eraseColor;
      }
    } else {
      paint.color = paintColor;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.width / 2,
        paint..style = PaintingStyle.fill,
      );
      continue;
    }
    final path = Path()
      ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }
}

/// Renders [strokes] to a black-and-white PNG of exactly [width] x [height]
/// pixels (white = repaint).
Future<Uint8List> renderAiMaskPng({
  required int width,
  required int height,
  required List<AiMaskStroke> strokes,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = _maskKeep,
  );
  _paintMaskStrokes(
    canvas,
    strokes,
    paintColor: _maskRepaint,
    eraseColor: _maskKeep,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Could not encode the mask.');
    }
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Lets the user paint over part of an image and describe what should go
/// there. Pops with an [AiRepaintResult], or null when cancelled.
class AiRepaintScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const AiRepaintScreen({super.key, required this.imageBytes});

  @override
  State<AiRepaintScreen> createState() => _AiRepaintScreenState();
}

class _AiRepaintScreenState extends State<AiRepaintScreen> {
  final TextEditingController _promptController = TextEditingController();
  final List<AiMaskStroke> _strokes = <AiMaskStroke>[];

  ui.Image? _image;
  bool _decodeFailed = false;
  bool _exporting = false;
  bool _eraseMode = false;

  /// Brush diameter in screen pixels.
  double _brushSize = 36;
  List<Offset>? _activePoints;
  double _activeWidth = 0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _decodeFailed = true);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _image?.dispose();
    super.dispose();
  }

  bool get _hasMask => _strokes.any((s) => !s.erase);

  /// Where the image is drawn inside [box] (contain fit).
  Rect _imageRect(Size box, ui.Image image) {
    final scale = _scaleFor(box, image);
    final w = image.width * scale;
    final h = image.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  double _scaleFor(Size box, ui.Image image) {
    final sx = box.width / image.width;
    final sy = box.height / image.height;
    return sx < sy ? sx : sy;
  }

  Offset _toImagePoint(Offset local, Size box, ui.Image image) {
    final rect = _imageRect(box, image);
    final scale = _scaleFor(box, image);
    return Offset(
      ((local.dx - rect.left) / scale).clamp(0.0, image.width.toDouble()),
      ((local.dy - rect.top) / scale).clamp(0.0, image.height.toDouble()),
    );
  }

  void _startStroke(Offset local, Size box, ui.Image image) {
    final scale = _scaleFor(box, image);
    setState(() {
      _activeWidth = _brushSize / scale;
      _activePoints = [_toImagePoint(local, box, image)];
    });
  }

  void _extendStroke(Offset local, Size box, ui.Image image) {
    final points = _activePoints;
    if (points == null) return;
    setState(() => points.add(_toImagePoint(local, box, image)));
  }

  void _endStroke() {
    final points = _activePoints;
    if (points == null) return;
    setState(() {
      _strokes.add(
        AiMaskStroke(
          points: List<Offset>.unmodifiable(points),
          width: _activeWidth,
          erase: _eraseMode,
        ),
      );
      _activePoints = null;
    });
  }

  Future<void> _apply() async {
    final image = _image;
    if (image == null || _exporting) return;
    if (!_hasMask || !isValidAiPrompt(_promptController.text)) return;

    setState(() => _exporting = true);
    try {
      final maskPng = await renderAiMaskPng(
        width: image.width,
        height: image.height,
        strokes: _strokes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        AiRepaintResult(
          maskPng: maskPng,
          prompt: _promptController.text.trim(),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final image = _image;

    return Scaffold(
      body: DeskBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(InkSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Cancel',
                      icon: Icon(LucideIcons.x, color: tokens.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: InkSpacing.s4),
                    Expanded(
                      child: Text(
                        'Repaint area',
                        style: InkType.title(tokens.ink),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Paint over the part you want to change, then describe what should be there.',
                  style: InkType.caption(tokens.inkMuted),
                ),
                const SizedBox(height: InkSpacing.s12),
                Expanded(
                  child: _decodeFailed
                      ? Center(
                          child: Text(
                            'This image could not be opened.',
                            style: InkType.body(tokens.inkMuted),
                          ),
                        )
                      : image == null
                      ? Center(
                          child: CircularProgressIndicator(color: tokens.accent),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final box = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return GestureDetector(
                              key: const ValueKey('ai-repaint-surface'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) =>
                                  _startStroke(d.localPosition, box, image),
                              onPanUpdate: (d) =>
                                  _extendStroke(d.localPosition, box, image),
                              onPanEnd: (_) => _endStroke(),
                              onPanCancel: _endStroke,
                              child: CustomPaint(
                                size: box,
                                painter: _RepaintPainter(
                                  image: image,
                                  imageRect: _imageRect(box, image),
                                  scale: _scaleFor(box, image),
                                  strokes: [
                                    ..._strokes,
                                    if (_activePoints != null)
                                      AiMaskStroke(
                                        points: _activePoints!,
                                        width: _activeWidth,
                                        erase: _eraseMode,
                                      ),
                                  ],
                                  maskColor: tokens.accent.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: InkSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: InkSegmented(
                        labels: const ['Paint', 'Erase'],
                        selectedIndex: _eraseMode ? 1 : 0,
                        onChanged: (index) =>
                            setState(() => _eraseMode = index == 1),
                      ),
                    ),
                    const SizedBox(width: InkSpacing.s8),
                    InkButton.secondary(
                      label: 'Clear',
                      compact: true,
                      expand: false,
                      onPressed: _strokes.isEmpty
                          ? null
                          : () => setState(_strokes.clear),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Brush', style: InkType.label(tokens.inkMuted)),
                    Expanded(
                      child: Slider(
                        value: _brushSize,
                        min: 8,
                        max: 96,
                        activeColor: tokens.accent,
                        onChanged: (value) => setState(() => _brushSize = value),
                      ),
                    ),
                  ],
                ),
                InkTextField(
                  controller: _promptController,
                  hintText: 'What should be here?',
                  leadingIcon: LucideIcons.sparkles,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: InkSpacing.s4),
                Align(
                  alignment: Alignment.centerRight,
                  child: AiPromptCounter(controller: _promptController),
                ),
                const SizedBox(height: InkSpacing.s8),
                InkButton.primary(
                  label: 'Repaint',
                  icon: const Icon(LucideIcons.brush),
                  isLoading: _exporting,
                  onPressed:
                      image != null &&
                          _hasMask &&
                          isValidAiPrompt(_promptController.text)
                      ? _apply
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepaintPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final double scale;
  final List<AiMaskStroke> strokes;
  final Color maskColor;

  _RepaintPainter({
    required this.image,
    required this.imageRect,
    required this.scale,
    required this.strokes,
    required this.maskColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );

    // The mask is drawn in its own layer so the eraser can clear it without
    // touching the picture underneath.
    canvas.save();
    canvas.clipRect(imageRect);
    canvas.saveLayer(imageRect, Paint());
    canvas.translate(imageRect.left, imageRect.top);
    canvas.scale(scale);
    _paintMaskStrokes(canvas, strokes, paintColor: maskColor, eraseColor: null);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RepaintPainter oldDelegate) => true;
}
