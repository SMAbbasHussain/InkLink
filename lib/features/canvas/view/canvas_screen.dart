import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/repositories/board_repository.dart';
import 'package:inklink/domain/repositories/canvas_sync_repository.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/crdt/y_crdt_canvas_adapter.dart';
import '../../../core/database/collections/local_crdt_update.dart';
import '../../../core/utils/tray_tips_preferences.dart';
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

  const CanvasScreen({
    super.key,
    required this.boardId,
    this.showTrayTipsOnEntry = false,
  });

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  String? activeTray;
  final TextEditingController _aiPromptController = TextEditingController();
  final Uuid _uuid = const Uuid();
  final math.Random _random = math.Random();
  StreamSubscription<List<LocalCrdtUpdate>>? _crdtUpdatesSub;
  YCrdtCanvasAdapter? _crdtAdapter;
  Future<void>? _crdtInitFuture;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  bool _showTrayTipsOverlay = false;

  final List<_CanvasElement> _elements = [];
  List<Offset> _currentStrokePoints = [];

  Color _selectedColor = Colors.black;
  double _strokeWidth = 5;

  @override
  void initState() {
    super.initState();
    context.read<BoardRepository>().startBoardsSync();
    _crdtInitFuture = _initializeCrdtSync();
    unawaited(_maybeShowTrayTipsOverlay());
  }

  Future<void> _maybeShowTrayTipsOverlay() async {
    if (!widget.showTrayTipsOnEntry) return;

    final showTips = await TrayTipsPreferences.getShowTrayTips();
    if (!mounted || !showTips) return;

    setState(() {
      _showTrayTipsOverlay = true;
    });
  }

  Future<void> _initializeCrdtSync() async {
    if (_crdtAdapter != null && _crdtUpdatesSub != null) return;

    try {
      _crdtAdapter ??= await YCrdtCanvasAdapter.create();
      _appliedCrdtUpdateIds.clear();
      _startCrdtUpdatesListener();
    } finally {
      _crdtInitFuture = null;
    }
  }

  Future<void> _ensureCrdtReady() async {
    if (_crdtAdapter != null) return;
    _crdtInitFuture ??= _initializeCrdtSync();
    await _crdtInitFuture;
  }

  void _startCrdtUpdatesListener() {
    if (_crdtUpdatesSub != null) return;

    final syncRepo = context.read<CanvasSyncRepository>();
    _crdtUpdatesSub = syncRepo.listenToCrdtUpdates(widget.boardId).listen((
      updates,
    ) {
      final adapter = _crdtAdapter;
      if (adapter == null) return;

      for (final update in updates) {
        if (_appliedCrdtUpdateIds.contains(update.updateId)) {
          continue;
        }

        final bytes = base64Decode(update.payloadBase64);
        adapter.applyUpdate(bytes, origin: 'remote');
        _appliedCrdtUpdateIds.add(update.updateId);
      }

      final state = adapter.materializeElements();
      final rebuilt = _rebuildElementsFromCrdtState(state);
      if (!mounted) return;
      setState(() {
        _elements
          ..clear()
          ..addAll(rebuilt);
      });
    });
  }

  List<_CanvasElement> _rebuildElementsFromCrdtState(
    Map<String, Map<String, dynamic>> elementsById,
  ) {
    final rebuilt = <_CanvasElement>[];

    for (final entry in elementsById.entries) {
      final id = entry.key;
      final payload = entry.value;
      final type = payload['type'] as String?;

      if (type == 'stroke') {
        final pointMaps = (payload['points'] as List?) ?? [];
        final points = pointMaps
            .whereType<Map>()
            .map(
              (p) => Offset(
                (p['x'] as num?)?.toDouble() ?? 0,
                (p['y'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(growable: false);

        rebuilt.add(
          _CanvasElement.stroke(
            id: id,
            points: points,
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
            strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 5,
          ),
        );
        continue;
      }

      if (type == 'shape') {
        final shapeName = (payload['shapeType'] as String?) ?? 'square';
        final shapeType = CanvasShapeType.values.firstWhere(
          (s) => s.name == shapeName,
          orElse: () => CanvasShapeType.square,
        );

        rebuilt.add(
          _CanvasElement.shape(
            id: id,
            shapeType: shapeType,
            center: Offset(
              (payload['cx'] as num?)?.toDouble() ?? 0,
              (payload['cy'] as num?)?.toDouble() ?? 0,
            ),
            size: (payload['size'] as num?)?.toDouble() ?? 64,
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
            strokeWidth: 3,
          ),
        );
        continue;
      }

      if (type == 'text') {
        rebuilt.add(
          _CanvasElement.text(
            id: id,
            center: Offset(
              (payload['cx'] as num?)?.toDouble() ?? 0,
              (payload['cy'] as num?)?.toDouble() ?? 0,
            ),
            text: (payload['text'] as String?) ?? '',
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
          ),
        );
      }
    }

    rebuilt.sort((a, b) => a.id.compareTo(b.id));
    return rebuilt;
  }

  void _openTray(String tray) {
    setState(() {
      activeTray = (activeTray == tray) ? null : tray;
    });
  }

  Future<void> _saveOperation({
    required String action,
    required String type,
    required String objectId,
    required Map<String, dynamic> data,
  }) async {
    await _saveCrdtOperation(
      action: action,
      type: type,
      objectId: objectId,
      data: data,
    );
  }

  Future<void> _saveCrdtOperation({
    required String action,
    required String type,
    required String objectId,
    required Map<String, dynamic> data,
  }) async {
    await _ensureCrdtReady();

    final adapter = _crdtAdapter;
    if (adapter == null) return;

    Uint8List update;
    if (action == 'delete' && type == 'board') {
      update = adapter.clearElements(origin: 'local');
    } else if (action == 'delete') {
      update = adapter.deleteElement(objectId, origin: 'local');
    } else {
      final payload = <String, dynamic>{'type': type, ...data};
      update = adapter.upsertElement(objectId, payload, origin: 'local');
    }

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter();
  }

  Future<void> _publishCrdtUpdate(Uint8List update) async {
    final updateId = _uuid.v4();
    _appliedCrdtUpdateIds.add(updateId);

    await context.read<CanvasSyncRepository>().pushCrdtUpdate(
      boardId: widget.boardId,
      updateId: updateId,
      payload: update,
    );
  }

  void _refreshFromCrdtAdapter() {
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final state = adapter.materializeElements();
    final rebuilt = _rebuildElementsFromCrdtState(state);
    if (!mounted) return;
    setState(() {
      _elements
        ..clear()
        ..addAll(rebuilt);
    });
  }

  void _startStroke(Offset point) {
    setState(() {
      _currentStrokePoints = [point];
    });
  }

  void _appendStroke(Offset point) {
    setState(() {
      _currentStrokePoints.add(point);
    });
  }

  void _endStroke() {
    if (_currentStrokePoints.length < 2) {
      setState(() {
        _currentStrokePoints = [];
      });
      return;
    }

    final stroke = _CanvasElement.stroke(
      id: _uuid.v4(),
      points: List<Offset>.from(_currentStrokePoints),
      color: _selectedColor,
      strokeWidth: _strokeWidth,
    );

    setState(() {
      _elements.add(stroke);
      _currentStrokePoints = [];
    });

    _saveOperation(
      action: 'create',
      type: 'stroke',
      objectId: stroke.id,
      data: {
        'color': stroke.color.value,
        'strokeWidth': stroke.strokeWidth,
        'points': stroke.points
            .map((p) => {'x': p.dx, 'y': p.dy})
            .toList(growable: false),
      },
    );
  }

  void _addShape(CanvasShapeType shapeType) {
    final shape = _CanvasElement.shape(
      id: _uuid.v4(),
      shapeType: shapeType,
      center: Offset(
        180 + _random.nextDouble() * 40,
        220 + _random.nextDouble() * 80,
      ),
      size: 64,
      color: _selectedColor,
      strokeWidth: 3,
    );

    setState(() {
      _elements.add(shape);
      activeTray = null;
    });

    _saveOperation(
      action: 'create',
      type: 'shape',
      objectId: shape.id,
      data: {
        'shapeType': shapeType.name,
        'cx': shape.center.dx,
        'cy': shape.center.dy,
        'size': shape.size,
        'color': shape.color.value,
      },
    );
  }

  void _addAiTextElement() {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    final note = _CanvasElement.text(
      id: _uuid.v4(),
      center: Offset(
        200 + _random.nextDouble() * 40,
        240 + _random.nextDouble() * 60,
      ),
      text: prompt,
      color: _selectedColor,
    );

    setState(() {
      _elements.add(note);
      _aiPromptController.clear();
      activeTray = null;
    });

    _saveOperation(
      action: 'create',
      type: 'text',
      objectId: note.id,
      data: {
        'text': note.text,
        'cx': note.center.dx,
        'cy': note.center.dy,
        'color': note.color.value,
      },
    );
  }

  void _undo() {
    unawaited(_undoCrdt());
  }

  void _redo() {
    unawaited(_redoCrdt());
  }

  Future<void> _undoCrdt() async {
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final update = adapter.undoLast(origin: 'local');
    if (update == null) return;

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter();
    if (!mounted) return;
    setState(() {
      activeTray = null;
    });
  }

  Future<void> _redoCrdt() async {
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final update = adapter.redoLast(origin: 'local');
    if (update == null) return;

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter();
    if (!mounted) return;
    setState(() {
      activeTray = null;
    });
  }

  void _clearAll() {
    if (_elements.isEmpty) return;
    setState(() {
      _elements.clear();
      activeTray = null;
    });

    _saveOperation(
      action: 'delete',
      type: 'board',
      objectId: widget.boardId,
      data: {'reason': 'clear_all'},
    );
  }

  void _showRenameDialog(BoardRepository repo) {
    final controller = TextEditingController();
    final navigator = Navigator.of(context);
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
                await repo.renameBoard(widget.boardId, controller.text);
                if (!mounted) return;
                navigator.pop();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.read<BoardRepository>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: StreamBuilder<Board?>(
          stream: repo.getBoardById(widget.boardId),
          builder: (context, snapshot) {
            return Text(
              snapshot.data?.title ??
                  'Board ${widget.boardId.substring(0, math.min(6, widget.boardId.length))}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'rename') {
                _showRenameDialog(repo);
              } else if (value == 'copy') {
                Clipboard.setData(ClipboardData(text: widget.boardId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Join Code copied to clipboard!'),
                  ),
                );
              } else if (value == 'exit') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename Board')),
              const PopupMenuItem(value: 'copy', child: Text('Copy Join Code')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'exit',
                child: Text('Exit Canvas', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => activeTray = null),
            onPanStart: (details) => _startStroke(details.localPosition),
            onPanUpdate: (details) => _appendStroke(details.localPosition),
            onPanEnd: (_) => _endStroke(),
            behavior: HitTestBehavior.translucent,
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _CanvasPainter(
                  elements: _elements,
                  currentPoints: _currentStrokePoints,
                  currentColor: _selectedColor,
                  currentStrokeWidth: _strokeWidth,
                ),
              ),
            ),
          ),

          // 2. TRAYS
          _buildAllTrays(),

          // 3. EDGE TRIGGERS
          _buildEdgeTriggers(),

          if (_showTrayTipsOverlay)
            TrayTipsOverlay(
              onDismiss: () {
                setState(() {
                  _showTrayTipsOverlay = false;
                });
              },
            ),
        ],
      ),
    );
  }

  // --- TRAYS & GESTURES ---

  Widget _buildAllTrays() {
    return Stack(
      children: [
        MembersTray(isOpen: activeTray == 'members', boardId: widget.boardId),
        AITray(
          isOpen: activeTray == 'ai',
          controller: _aiPromptController,
          onAddText: _addAiTextElement,
        ),
        ToolsTray(
          isOpen: activeTray == 'tools',
          onUndo: _undo,
          onRedo: _redo,
          onClearAll: _clearAll,
        ),
        ShapesTray(isOpen: activeTray == 'shapes', onAddShape: _addShape),
        BrushTray(
          isOpen: activeTray == 'brushes',
          strokeWidth: _strokeWidth,
          selectedColor: _selectedColor,
          onStrokeWidthChanged: (v) => setState(() => _strokeWidth = v),
          onColorSelected: (c) => setState(() => _selectedColor = c),
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
    _crdtUpdatesSub?.cancel();
    context.read<CanvasSyncRepository>().stopCrdtRemoteSync(widget.boardId);
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
