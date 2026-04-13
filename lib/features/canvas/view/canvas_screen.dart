import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import '../bloc/canvas_bloc.dart';
import 'trays/ai_tray.dart';
import 'trays/brush_tray.dart';
import 'trays/canvas_shape_type.dart';
import 'trays/members_tray.dart';
import 'trays/shapes_tray.dart';
import 'trays/tools_tray.dart';
import 'widgets/tray_tips_overlay.dart';

class CanvasScreen extends StatefulWidget {
  final String boardId;
  final bool showTrayTipsOnEntry;
  final String boardPreviewQuality;
  final bool boardPreviewCompressionEnabled;

  const CanvasScreen({
    super.key,
    required this.boardId,
    this.showTrayTipsOnEntry = false,
    this.boardPreviewQuality = 'medium',
    this.boardPreviewCompressionEnabled = true,
  });

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final TextEditingController _aiPromptController = TextEditingController();
  final GlobalKey _canvasPreviewKey = GlobalKey();
  bool _savingPreview = false;
  late final CanvasBloc _canvasBloc;

  @override
  void initState() {
    super.initState();
    _canvasBloc = context.read<CanvasBloc>();
    _maybeShowTrayTipsOverlay();
  }

  Future<void> _maybeShowTrayTipsOverlay() async {
    if (!widget.showTrayTipsOnEntry) return;

    final showTips = await TrayTipsPreferences.getShowTrayTips();
    if (!mounted || !showTips) return;
    _canvasBloc.add(const CanvasShowTrayTips());
  }

  void _openTray(String tray) {
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  void _startStroke(Offset point) {
    _canvasBloc.add(CanvasStartStroke(point));
  }

  void _appendStroke(Offset point) {
    _canvasBloc.add(CanvasAppendStroke(point));
  }

  void _endStroke() {
    _canvasBloc.add(const CanvasEndStroke());
  }

  void _addShape(CanvasShapeType shapeType) {
    _canvasBloc.add(CanvasAddShape(shapeType, _canvasBloc.randomShapeCenter()));
  }

  void _addAiTextElement() {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    _canvasBloc.add(CanvasAddAiText(prompt, _canvasBloc.randomTextCenter()));
    _aiPromptController.clear();
  }

  void _undo() {
    _canvasBloc.add(const CanvasUndo());
  }

  void _redo() {
    _canvasBloc.add(const CanvasRedo());
  }

  void _clearAll() {
    _canvasBloc.add(const CanvasClearAll());
  }

  void _showRenameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Board'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                _canvasBloc.add(
                  CanvasRenameBoardRequested(controller.text.trim()),
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePreview() async {
    if (_savingPreview) return;
    _savingPreview = true;

    try {
      final boundary =
          _canvasPreviewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      double pixelRatio;
      switch (widget.boardPreviewQuality) {
        case 'low':
          pixelRatio = 0.2;
          break;
        case 'high':
          pixelRatio = 0.5;
          break;
        case 'medium':
        default:
          pixelRatio = 0.35;
          break;
      }

      if (!widget.boardPreviewCompressionEnabled) {
        pixelRatio = (pixelRatio + 0.2).clamp(0.2, 0.8);
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) return;
      _canvasBloc.add(CanvasSaveBoardPreviewRequested(bytes));
    } catch (_) {
      // Ignore preview errors and allow navigation to continue.
    } finally {
      _savingPreview = false;
    }
  }

  Future<void> _exitCanvas() async {
    await _savePreview();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _canvasBloc,
      child: BlocListener<CanvasBloc, CanvasState>(
        listenWhen: (previous, current) => previous.error != current.error,
        listener: (context, state) async {
          final message = state.error;
          if (message == null || message.isEmpty) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );

          if (message.contains('no longer available') ||
              message.contains('access lost')) {
            await _exitCanvas();
          }
        },
        child: BlocBuilder<CanvasBloc, CanvasState>(
          builder: (context, state) {
            final mappedElements = _mapElements(state.elements);
            final title =
                state.boardTitle ??
                'Board ${widget.boardId.substring(0, math.min(6, widget.boardId.length))}';

            return WillPopScope(
              onWillPop: () async {
                await _savePreview();
                return true;
              },
              child: Scaffold(
                backgroundColor: isDark
                    ? AppColors.bgDark
                    : const Color(0xFFF5F5F5),
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'rename') {
                          _showRenameDialog();
                        } else if (value == 'copy') {
                          Clipboard.setData(
                            ClipboardData(text: widget.boardId),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Join Code copied to clipboard!'),
                            ),
                          );
                        } else if (value == 'exit') {
                          _exitCanvas();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename Board'),
                        ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copy Join Code'),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'exit',
                          child: Text(
                            'Exit Canvas',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                body: RepaintBoundary(
                  key: _canvasPreviewKey,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (state.activeTray != null) {
                            _canvasBloc.add(
                              CanvasToggleTray(state.activeTray!),
                            );
                          }
                        },
                        onPanStart: (details) =>
                            _startStroke(details.localPosition),
                        onPanUpdate: (details) =>
                            _appendStroke(details.localPosition),
                        onPanEnd: (_) => _endStroke(),
                        behavior: HitTestBehavior.translucent,
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: _CanvasPainter(
                              elements: mappedElements,
                              currentPoints: state.currentStroke,
                              currentColor: state.selectedColor,
                              currentStrokeWidth: state.strokeWidth,
                            ),
                          ),
                        ),
                      ),

                      _buildAllTrays(state),
                      _buildEdgeTriggers(),

                      if (state.showTrayTips)
                        TrayTipsOverlay(
                          onDismiss: () {
                            _canvasBloc.add(const CanvasDismissTrayTips());
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<_CanvasElement> _mapElements(List<CanvasElement> elements) {
    return elements
        .map((element) {
          final data = element.data as Map<String, dynamic>? ?? const {};

          if (element.type == 'stroke') {
            final pointMaps = (data['points'] as List?) ?? const [];
            final points = pointMaps
                .whereType<Map>()
                .map(
                  (p) => Offset(
                    (p['x'] as num?)?.toDouble() ?? 0,
                    (p['y'] as num?)?.toDouble() ?? 0,
                  ),
                )
                .toList(growable: false);

            return _CanvasElement.stroke(
              id: element.id,
              points: points,
              color: Color(
                (data['color'] as num?)?.toInt() ?? Colors.black.value,
              ),
              strokeWidth: (data['strokeWidth'] as num?)?.toDouble() ?? 5,
            );
          }

          if (element.type == 'shape') {
            final shapeName = (data['shapeType'] as String?) ?? 'square';
            final shapeType = CanvasShapeType.values.firstWhere(
              (s) => s.name == shapeName,
              orElse: () => CanvasShapeType.square,
            );

            return _CanvasElement.shape(
              id: element.id,
              shapeType: shapeType,
              center: Offset(
                (data['cx'] as num?)?.toDouble() ?? 0,
                (data['cy'] as num?)?.toDouble() ?? 0,
              ),
              size: (data['size'] as num?)?.toDouble() ?? 64,
              color: Color(
                (data['color'] as num?)?.toInt() ?? Colors.black.value,
              ),
              strokeWidth: (data['strokeWidth'] as num?)?.toDouble() ?? 3,
            );
          }

          return _CanvasElement.text(
            id: element.id,
            center: Offset(
              (data['cx'] as num?)?.toDouble() ?? 0,
              (data['cy'] as num?)?.toDouble() ?? 0,
            ),
            text: (data['text'] as String?) ?? '',
            color: Color(
              (data['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
          );
        })
        .toList(growable: false);
  }

  Widget _buildAllTrays(CanvasState state) {
    return Stack(
      children: [
        MembersTray(
          isOpen: state.activeTray == 'members',
          boardId: widget.boardId,
        ),
        AITray(
          isOpen: state.activeTray == 'ai',
          controller: _aiPromptController,
          onAddText: _addAiTextElement,
        ),
        ToolsTray(
          isOpen: state.activeTray == 'tools',
          onUndo: _undo,
          onRedo: _redo,
          onClearAll: _clearAll,
        ),
        ShapesTray(isOpen: state.activeTray == 'shapes', onAddShape: _addShape),
        BrushTray(
          isOpen: state.activeTray == 'brushes',
          strokeWidth: state.strokeWidth,
          selectedColor: state.selectedColor,
          onStrokeWidthChanged: (v) {
            _canvasBloc.add(CanvasUpdateStrokeWidth(v));
          },
          onColorSelected: (c) {
            _canvasBloc.add(CanvasUpdateColor(c));
          },
        ),
      ],
    );
  }

  Widget _buildEdgeTriggers() {
    return Stack(
      children: [
        // BOTTOM: Swipe Up for Brushes
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity! < -100) _openTray('brushes');
            },
            child: Container(
              height: 50,
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),
        // TOP LEFT: Swipe Right for Members
        Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! > 100) _openTray('members');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(top: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // BOTTOM LEFT: Swipe Right for Tools
        Align(
          alignment: Alignment.bottomLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! > 100) _openTray('tools');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // TOP RIGHT: Swipe Left for AI
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! < -100) _openTray('ai');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(top: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // BOTTOM RIGHT: Swipe Left for Shapes
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity! < -100) _openTray('shapes');
            },
            child: Container(
              height: 200,
              width: 40,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _canvasBloc.close();
    _aiPromptController.dispose();
    super.dispose();
  }
}

enum _ElementKind { stroke, shape, text }

class _CanvasElement {
  final String id;
  final _ElementKind kind;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final CanvasShapeType? shapeType;
  final Offset center;
  final double size;
  final String text;

  const _CanvasElement._({
    required this.id,
    required this.kind,
    this.points = const [],
    required this.color,
    this.strokeWidth = 2,
    this.shapeType,
    this.center = Offset.zero,
    this.size = 0,
    this.text = '',
  });

  factory _CanvasElement.stroke({
    required String id,
    required List<Offset> points,
    required Color color,
    required double strokeWidth,
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.stroke,
      points: points,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  factory _CanvasElement.shape({
    required String id,
    required CanvasShapeType shapeType,
    required Offset center,
    required double size,
    required Color color,
    required double strokeWidth,
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.shape,
      shapeType: shapeType,
      center: center,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  factory _CanvasElement.text({
    required String id,
    required Offset center,
    required String text,
    required Color color,
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.text,
      center: center,
      text: text,
      color: color,
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<_CanvasElement> elements;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;

  const _CanvasPainter({
    required this.elements,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in elements) {
      switch (element.kind) {
        case _ElementKind.stroke:
          _paintStroke(
            canvas,
            element.points,
            element.color,
            element.strokeWidth,
          );
          break;
        case _ElementKind.shape:
          _paintShape(canvas, element);
          break;
        case _ElementKind.text:
          _paintText(canvas, element);
          break;
      }
    }

    if (currentPoints.length > 1) {
      _paintStroke(canvas, currentPoints, currentColor, currentStrokeWidth);
    }
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _paintShape(Canvas canvas, _CanvasElement element) {
    final paint = Paint()
      ..color = element.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth;

    final c = element.center;
    final s = element.size;

    switch (element.shapeType!) {
      case CanvasShapeType.square:
        canvas.drawRect(Rect.fromCenter(center: c, width: s, height: s), paint);
        break;
      case CanvasShapeType.circle:
        canvas.drawCircle(c, s / 2, paint);
        break;
      case CanvasShapeType.triangle:
        final p = Path()
          ..moveTo(c.dx, c.dy - s / 2)
          ..lineTo(c.dx - s / 2, c.dy + s / 2)
          ..lineTo(c.dx + s / 2, c.dy + s / 2)
          ..close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.star:
        final p = Path();
        for (int i = 0; i < 5; i++) {
          final outerAngle = (math.pi / 2) + i * (2 * math.pi / 5);
          final innerAngle = outerAngle + (math.pi / 5);
          final outer = Offset(
            c.dx + math.cos(outerAngle) * (s / 2),
            c.dy - math.sin(outerAngle) * (s / 2),
          );
          final inner = Offset(
            c.dx + math.cos(innerAngle) * (s / 4),
            c.dy - math.sin(innerAngle) * (s / 4),
          );
          if (i == 0) {
            p.moveTo(outer.dx, outer.dy);
          } else {
            p.lineTo(outer.dx, outer.dy);
          }
          p.lineTo(inner.dx, inner.dy);
        }
        p.close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.pentagon:
        final p = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 5);
          final point = Offset(
            c.dx + math.cos(angle) * (s / 2),
            c.dy - math.sin(angle) * (s / 2),
          );
          if (i == 0) {
            p.moveTo(point.dx, point.dy);
          } else {
            p.lineTo(point.dx, point.dy);
          }
        }
        p.close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.line:
        canvas.drawLine(
          Offset(c.dx - s / 2, c.dy),
          Offset(c.dx + s / 2, c.dy),
          paint,
        );
        break;
    }
  }

  void _paintText(Canvas canvas, _CanvasElement element) {
    final textSpan = TextSpan(
      text: element.text,
      style: TextStyle(
        color: element.color,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: 220);

    textPainter.paint(canvas, Offset(element.center.dx, element.center.dy));
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return oldDelegate.elements != elements ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentStrokeWidth != currentStrokeWidth;
  }
}
