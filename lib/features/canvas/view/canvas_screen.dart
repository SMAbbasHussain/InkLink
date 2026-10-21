import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/models/board.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/view/board_settings_route.dart';
import '../bloc/canvas_bloc.dart';
import '../models/canvas_tool_mode.dart';
import 'media_editor_screen.dart';
import 'trays/ai_tray.dart';
import 'trays/brush_tray.dart';
import 'trays/canvas_shape_type.dart';
import 'trays/members_tray.dart';
import 'trays/shapes_tray.dart';
import 'trays/tools_tray.dart';
import 'chat/board_chat_drawer.dart';
import 'trays/comments_tray.dart';
import 'voice/voice_call_hud.dart';
import 'widgets/tray_tips_overlay.dart';

part 'canvas_painter.dart';

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
  bool _isDraggingShape = false;
  bool _isDraggingStroke = false;
  List<Offset>? _strokeDragOriginalPoints;
  Offset? _strokeDragDelta;
  Offset _strokeDragStartWorldPoint = Offset.zero;
  bool _isEditingShape = false;
  bool _isShapeEditTrayExpanded = false;
  bool _isStrokeEditExpanded = false;
  bool _smoothDoodlesEnabled = false;
  bool _isRotatingShape = false;
  bool _isResizingShape = false;
  bool _showEraserPreview = false;
  bool _isTransformingCanvas = false;
  bool _didAutoFrameContent = false;
  Size _lastCanvasSize = Size.zero;
  Offset _shapeDragStartCenter = Offset.zero;
  Offset _shapeDragStartWorldPoint = Offset.zero;
  Offset? _shapeDragPreviewCenter;
  double _shapeDragStartRotation = 0.0;
  _ShapeTransformDraft? _shapeTransformDraft;
  double _viewportScale = 1.0;
  Offset _viewportOffset = Offset.zero;
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;
  final List<Uint8List> _recentImages = <Uint8List>[];
  final Map<String, Uint8List> _decodedImageCache = <String, Uint8List>{};
  final Map<String, String> _decodedImageCacheKey = <String, String>{};
  final Map<String, _ImageDraftTransform> _imageDrafts =
      <String, _ImageDraftTransform>{};
  late final CanvasBloc _canvasBloc;
  Timer? _shapeEditDebounceTimer;
  final Map<String, dynamic> _pendingShapeEdits = <String, dynamic>{};
  Offset? _lastTapWorldPoint;
  String? _arrowConnectStartElementId;

  static const double _viewportComparisonEpsilon = 0.01;

  bool _preventGestureBack = true;
  bool _showEdgeTrayButtons = true;
  DateTime? _lastEdgeDragTime;
  DateTime? _lastBackSnackbarTime;

  @override
  void initState() {
    super.initState();
    _canvasBloc = context.read<CanvasBloc>();
    _maybeShowTrayTipsOverlay();
  }

  Future<void> _maybeShowTrayTipsOverlay() async {
    if (!widget.showTrayTipsOnEntry) return;

    final showTips = await TrayTipsPreferences.checkShowTrayTips();
    if (!mounted || !showTips) return;
    _canvasBloc.add(const CanvasShowTrayTips());
  }

  void _openTray(String tray) {
    if (_canvasBloc.state.activeTray == tray) return;
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  void _toggleTray(String tray) {
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  Offset _toWorld(Offset localPoint) {
    return Offset(
      (localPoint.dx - _viewportOffset.dx) / _viewportScale,
      (localPoint.dy - _viewportOffset.dy) / _viewportScale,
    );
  }

  bool _isArrowMode(CanvasState state) {
    return (state.currentToolMode == CanvasToolMode.shape &&
            state.pendingShapeType == CanvasShapeType.arrow) ||
        state.currentToolMode == CanvasToolMode.arrow;
  }

  Offset _toScreen(Offset worldPoint) {
    return Offset(
      (worldPoint.dx * _viewportScale) + _viewportOffset.dx,
      (worldPoint.dy * _viewportScale) + _viewportOffset.dy,
    );
  }

  List<Offset> _smoothStrokePoints(List<Offset> points) {
    if (points.length < 4) return points;
    final result = List<Offset>.of(points);
    for (int i = 1; i < points.length - 1; i++) {
      result[i] = Offset(
        (points[i - 1].dx + points[i].dx + points[i + 1].dx) / 3,
        (points[i - 1].dy + points[i].dy + points[i + 1].dy) / 3,
      );
    }
    return result;
  }

  void _startStroke(Offset point) {
    _canvasBloc.add(CanvasStartStroke(point));
  }

  void _appendStroke(Offset point) {
    _canvasBloc.add(CanvasAppendStroke(point));
  }

  void _endStroke() {
    final smoothed = _smoothDoodlesEnabled
        ? _smoothStrokePoints(_canvasBloc.state.currentStroke)
        : null;
    _canvasBloc.add(CanvasEndStroke(smoothedPoints: smoothed));
  }

  Offset _getElementWorldCenter(CanvasElement element) {
    return switch (element) {
      StrokeElement e => _strokeCenter(e.points),
      ShapeElement e => e.center,
      TextElement e => e.center,
      ImageElement e => e.center,
      StickyNoteElement e => e.center,
      ConnectorElement e => Offset(
          (e.startPoint.dx + e.endPoint.dx) / 2,
          (e.startPoint.dy + e.endPoint.dy) / 2,
        ),
    };
  }

  Offset _strokeCenter(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  void _centerViewportOn(Offset worldPoint) {
    if (_lastCanvasSize.width <= 0 || _lastCanvasSize.height <= 0) return;
    setState(() {
      _viewportOffset = Offset(
        (_lastCanvasSize.width / 2) - (worldPoint.dx * _viewportScale),
        (_lastCanvasSize.height / 2) - (worldPoint.dy * _viewportScale),
      );
    });
  }

  void _selectShape(String? shapeId, {bool expandEditor = false}) {
    // Commit any pending edits before selecting a different shape
    _commitPendingShapeEdits();

    if (shapeId != null) {
      final elements = _canvasBloc.state.elements;
      try {
        final element = elements.firstWhere((e) => e.id == shapeId);
        _centerViewportOn(_getElementWorldCenter(element));
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isShapeEditTrayExpanded = shapeId != null && expandEditor;
        _isStrokeEditExpanded = false;
      });
    }
    _canvasBloc.add(CanvasSelectShape(shapeId));
  }

  void _moveSelectedShape(Offset center) {
    _canvasBloc.add(CanvasMoveSelectedShape(center));
  }

  void _resizeSelectedShape(double size) {
    _canvasBloc.add(CanvasResizeSelectedShape(size));
  }

  void _deferredResizeSelectedShape(double size) {
    _pendingShapeEdits['size'] = size;
    _canvasBloc.add(
      CanvasPreviewPendingShapeEdits(
        shapeId: _canvasBloc.state.selectedShapeId ?? '',
        pendingData: Map<String, dynamic>.from(_pendingShapeEdits),
      ),
    );
    _scheduleShapeEditCommit();
  }

  void _deferredSetSelectedShapeFill(bool isFilled) {
    _pendingShapeEdits['isFilled'] = isFilled;
    _canvasBloc.add(
      CanvasPreviewPendingShapeEdits(
        shapeId: _canvasBloc.state.selectedShapeId ?? '',
        pendingData: Map<String, dynamic>.from(_pendingShapeEdits),
      ),
    );
    _scheduleShapeEditCommit();
  }

  void _setSelectedShapeColor(Color color) {
    _canvasBloc.add(CanvasUpdateSelectedShapeColor(color));
  }

  void _rotateSelectedShape(double rotation) {
    _canvasBloc.add(CanvasRotateSelectedShape(rotation));
  }

  void _deferredRotateSelectedShape(double rotation) {
    _pendingShapeEdits['rotation'] = rotation;
    _canvasBloc.add(
      CanvasPreviewPendingShapeEdits(
        shapeId: _canvasBloc.state.selectedShapeId ?? '',
        pendingData: Map<String, dynamic>.from(_pendingShapeEdits),
      ),
    );
    _scheduleShapeEditCommit();
  }

  void _deferredSetSelectedShapeBorderRadius(double borderRadius) {
    setState(() {
      _pendingShapeEdits['borderRadius'] = borderRadius;
    });
    _canvasBloc.add(
      CanvasPreviewPendingShapeEdits(
        shapeId: _canvasBloc.state.selectedShapeId ?? '',
        pendingData: Map<String, dynamic>.from(_pendingShapeEdits),
      ),
    );
    _scheduleShapeEditCommit();
  }

  void _scheduleShapeEditCommit() {
    // Cancel existing timer
    _shapeEditDebounceTimer?.cancel();

    // Schedule new commit after debounce delay
    _shapeEditDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _commitPendingShapeEdits();
    });
  }

  void _commitPendingShapeEdits() {
    if (_pendingShapeEdits.isEmpty ||
        _canvasBloc.state.selectedShapeId == null) {
      return;
    }

    final shapeId = _canvasBloc.state.selectedShapeId!;
    final pending = Map<String, dynamic>.from(_pendingShapeEdits);

    // Clear pending state
    _pendingShapeEdits.clear();
    _shapeEditDebounceTimer?.cancel();
    _shapeEditDebounceTimer = null;

    // Commit all pending changes in a single update
    _canvasBloc.add(
      CanvasCommitPendingShapeEdits(shapeId: shapeId, pendingData: pending),
    );
  }

  void _setEraserScope(bool eraseEverything) {
    _canvasBloc.add(CanvasUpdateEraserScope(eraseEverything));
  }

  void _setShapeEditing(bool editing) {
    if (_isEditingShape == editing) return;
    setState(() => _isEditingShape = editing);
  }

  void _selectShapeForDrawing(CanvasShapeType shapeType) {
    setState(() {
      _isShapeEditTrayExpanded = false;
    });
    _canvasBloc.add(CanvasSetToolMode(CanvasToolMode.shape, shapeType: shapeType));
  }

  void _addAiTextElement() {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    _canvasBloc.add(CanvasAddAiText(prompt, _canvasBloc.randomTextCenter()));
    _aiPromptController.clear();
  }

  void _onGenerateImagePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI image generation is coming soon.')),
    );
  }

  Future<void> _uploadImageToCanvas([ImageSource? directSource]) async {
    final ImageSource? source;
    if (directSource != null) {
      source = directSource;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Insert Image',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.camera_alt_rounded, color: Colors.white),
                  ),
                  title: const Text('Take Photo with Camera'),
                  subtitle: const Text('Capture a picture and place onto canvas'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.photo_library_rounded, color: Colors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Pick an existing photo or graphic'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 95,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isNoCamera = e.code == 'no_available_camera' ||
          (e.message?.toLowerCase().contains('no camera') ?? false);
      final isDenied = e.code == 'camera_access_denied' ||
          (e.message?.toLowerCase().contains('denied') ?? false);

      final message = isNoCamera
          ? 'No camera available on this device.'
          : isDenied
              ? 'Camera permission was denied.'
              : 'Failed to access camera: ${e.message ?? e.code}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: isNoCamera
              ? SnackBarAction(
                  label: 'Choose Gallery',
                  onPressed: () => _uploadImageToCanvas(ImageSource.gallery),
                )
              : null,
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
      return;
    }

    if (picked == null || !mounted) return;

    try {
      final navigator = Navigator.of(context);
      final rawBytes = await picked.readAsBytes();
      final edited = await navigator.push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => MediaEditorScreen(imageBytes: rawBytes),
        ),
      );
      if (edited == null || edited.isEmpty || !mounted) return;

      final sourceSize = await _readImageSize(edited);
      if (!mounted) return;

      setState(() {
        _recentImages.insert(0, edited);
        if (_recentImages.length > 10) {
          _recentImages.removeLast();
        }
      });

      final maxSide = math.max(sourceSize.width, sourceSize.height);
      final fitScale = maxSide > 280 ? (280 / maxSide) : 1.0;
      final width = (sourceSize.width * fitScale).clamp(90, 720).toDouble();
      final height = (sourceSize.height * fitScale).clamp(90, 720).toDouble();

      _canvasBloc.add(
        CanvasAddImageElement(
          edited,
          _canvasBloc.randomShapeCenter(),
          width: width,
          height: height,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to upload image to canvas for board ${widget.boardId}: $error\n$stackTrace',
      );
    }
  }

  Future<Size> _readImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  void _pruneImageCache(List<CanvasElement> elements) {
    final activeImageIds = elements
        .whereType<ImageElement>()
        .map((element) => element.id)
        .toSet();

    _decodedImageCache.removeWhere((key, _) => !activeImageIds.contains(key));
    _decodedImageCacheKey.removeWhere(
      (key, _) => !activeImageIds.contains(key),
    );
  }

  bool _isAtTransform({required double scale, required Offset offset}) {
    return (_viewportScale - scale).abs() <= _viewportComparisonEpsilon &&
        (_viewportOffset.dx - offset.dx).abs() <= 1.0 &&
        (_viewportOffset.dy - offset.dy).abs() <= 1.0;
  }

  void _applyViewportTransform({
    required double scale,
    required Offset offset,
  }) {
    if (!mounted) return;
    setState(() {
      _viewportScale = scale;
      _viewportOffset = offset;
    });
  }

  Offset _centerOffsetForScale(
    Size canvasSize,
    Offset worldCenter,
    double scale,
  ) {
    return Offset(
      (canvasSize.width / 2) - (worldCenter.dx * scale),
      (canvasSize.height / 2) - (worldCenter.dy * scale),
    );
  }

  void _resetViewToDefaultScale() {
    if (_lastCanvasSize.width <= 0 || _lastCanvasSize.height <= 0) {
      _applyViewportTransform(scale: 1.0, offset: Offset.zero);
      return;
    }

    final bounds = _computeContentBounds(_canvasBloc.state.elements);
    final center = bounds?.center ?? Offset.zero;
    _applyViewportTransform(
      scale: 1.0,
      offset: _centerOffsetForScale(_lastCanvasSize, center, 1.0),
    );
  }

  void _toggleResetView() {
    if (_lastCanvasSize.width <= 0 || _lastCanvasSize.height <= 0) {
      _resetViewToDefaultScale();
      return;
    }

    final fitted = _calculateFittedTransform(
      _canvasBloc.state.elements,
      _lastCanvasSize,
    );
    if (fitted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No canvas content to fit yet.')),
      );
      return;
    }

    final currentlyFitted = _isAtTransform(
      scale: fitted.scale,
      offset: fitted.offset,
    );

    if (currentlyFitted) {
      _resetViewToDefaultScale();
      return;
    }

    _applyViewportTransform(scale: fitted.scale, offset: fitted.offset);
  }

  void _maybeAutoFrameCanvas(CanvasState state, Size canvasSize) {
    if (_didAutoFrameContent) {
      return;
    }

    _fitCanvasToContent(state.elements, canvasSize, markAutoFramed: true);
  }

  bool _fitCanvasToContent(
    List<CanvasElement> elements,
    Size canvasSize, {
    required bool markAutoFramed,
  }) {
    final transform = _calculateFittedTransform(elements, canvasSize);
    if (transform == null) {
      return false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (markAutoFramed && _didAutoFrameContent) return;
      setState(() {
        _viewportScale = transform.scale;
        _viewportOffset = transform.offset;
        if (markAutoFramed) {
          _didAutoFrameContent = true;
        }
      });
    });

    return true;
  }

  _ViewportTransform? _calculateFittedTransform(
    List<CanvasElement> elements,
    Size canvasSize,
  ) {
    if (elements.isEmpty) return null;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return null;

    final bounds = _computeContentBounds(elements);
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
      return null;
    }

    final padded = bounds.inflate(64);
    final sx = canvasSize.width / padded.width;
    final sy = canvasSize.height / padded.height;
    final targetScale = math.min(sx, sy).clamp(0.35, 2.8);
    final targetOffset = _centerOffsetForScale(
      canvasSize,
      padded.center,
      targetScale,
    );
    return _ViewportTransform(scale: targetScale, offset: targetOffset);
  }

  Rect? _computeContentBounds(List<CanvasElement> elements) {
    Rect? bounds;

    for (final element in elements) {
      Rect candidate;

      switch (element) {
        case StrokeElement e:
          if (e.points.isEmpty) continue;
          double minX = double.infinity;
          double minY = double.infinity;
          double maxX = -double.infinity;
          double maxY = -double.infinity;
          for (final p in e.points) {
            minX = math.min(minX, p.dx);
            minY = math.min(minY, p.dy);
            maxX = math.max(maxX, p.dx);
            maxY = math.max(maxY, p.dy);
          }
          final pad = e.strokeWidth + 8;
          candidate = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(pad);
        case ShapeElement e:
          candidate = Rect.fromCenter(
            center: e.center,
            width: e.size * 1.6,
            height: e.size * 1.6,
          );
        case TextElement e:
          candidate = Rect.fromCenter(
            center: e.center,
            width: 220,
            height: 72,
          );
        case ImageElement e:
          candidate = Rect.fromCenter(
            center: e.center,
            width: e.width,
            height: e.height,
          );
        case StickyNoteElement e:
          candidate = Rect.fromCenter(
            center: e.center,
            width: e.width,
            height: e.height,
          );
        case ConnectorElement e:
          candidate = Rect.fromPoints(e.startPoint, e.endPoint).inflate(16);
      }

      bounds = bounds == null ? candidate : bounds.expandToInclude(candidate);
    }

    return bounds;
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

  Future<void> _addStickyNoteDialog() async {
    final textController = TextEditingController();
    Color selectedColor = const Color(0xFFFFF9A6);
    final colors = [
      const Color(0xFFFFF9A6), // Yellow
      const Color(0xFFD4F8D3), // Mint / Lime
      const Color(0xFFC7F0FF), // Sky / Cyan
      const Color(0xFFFFD1DC), // Rose / Pink
      const Color(0xFFE2D4F8), // Lavender
    ];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Sticky Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Write note content here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colors.map((c) {
                  final isSelected = c.value == selectedColor.value;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blueAccent : Colors.grey.withOpacity(0.4),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [const BoxShadow(color: Colors.black26, blurRadius: 4)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add to Canvas'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      final size = MediaQuery.of(context).size;
      final centerWorld = _toWorld(Offset(size.width / 2, size.height / 2));
      _canvasBloc.add(CanvasAddStickyNote(
        center: centerWorld,
        text: textController.text.trim(),
        color: selectedColor,
      ));
    }
  }

  Future<void> _editStickyNote(_CanvasElement element) async {
    final textController = TextEditingController(text: element.text);
    Color selectedColor = element.color;
    final colors = [
      const Color(0xFFFFF9A6),
      const Color(0xFFD4F8D3),
      const Color(0xFFC7F0FF),
      const Color(0xFFFFD1DC),
      const Color(0xFFE2D4F8),
    ];

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Sticky Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Note content...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colors.map((c) {
                  final isSelected = c.value == selectedColor.value;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blueAccent : Colors.grey.withOpacity(0.4),
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      _canvasBloc.add(CanvasUpdateStickyNote(
        elementId: element.id,
        text: textController.text.trim(),
        color: selectedColor,
      ));
    }
  }

  Future<void> _addConnectorDialog() async {
    String selectedStyle = 'straight';
    bool hasArrowhead = true;
    Color selectedColor = const Color(0xFF2D3748);

    final elements = _canvasBloc.state.elements;
    final linkable = elements
        .where((e) => e is ShapeElement || e is StickyNoteElement)
        .toList();

    String? startId = linkable.isNotEmpty ? linkable.first.id : null;
    String? endId = linkable.length > 1 ? linkable[1].id : null;
    String startAnchor = 'right';
    String endAnchor = 'left';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Connector / Diagram Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Line Style',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedStyle,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'straight', child: Text('Straight Line')),
                    DropdownMenuItem(
                        value: 'curved', child: Text('Curved Bezier')),
                    DropdownMenuItem(
                        value: 'orthogonal', child: Text('Orthogonal / Step')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStyle = v);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Arrowhead End'),
                  value: hasArrowhead,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => hasArrowhead = v),
                ),
                if (linkable.length >= 2) ...[
                  const SizedBox(height: 12),
                  const Text('Connect Shapes',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: startId,
                          isExpanded: true,
                          hint: const Text('From Element'),
                          items: linkable.map((e) {
                            final label = e is ShapeElement
                                ? '${e.shapeType.name} (${e.id.substring(0, 4)})'
                                : 'Note (${e.id.substring(0, 4)})';
                            return DropdownMenuItem(
                                value: e.id,
                                child: Text(label,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (v) => setDialogState(() => startId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: endId,
                          isExpanded: true,
                          hint: const Text('To Element'),
                          items: linkable.map((e) {
                            final label = e is ShapeElement
                                ? '${e.shapeType.name} (${e.id.substring(0, 4)})'
                                : 'Note (${e.id.substring(0, 4)})';
                            return DropdownMenuItem(
                                value: e.id,
                                child: Text(label,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (v) => setDialogState(() => endId = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add Connector'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      final size = MediaQuery.of(context).size;
      final centerWorld = _toWorld(Offset(size.width / 2, size.height / 2));
      _canvasBloc.add(CanvasAddConnector(
        startElementId: startId,
        startPoint: Offset(centerWorld.dx - 80, centerWorld.dy),
        startAnchor: startAnchor,
        endElementId: endId,
        endPoint: Offset(centerWorld.dx + 80, centerWorld.dy),
        endAnchor: endAnchor,
        lineStyle: selectedStyle,
        hasArrowhead: hasArrowhead,
        color: selectedColor,
      ));
    }
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

  void _openSettings(String currentTitle) {
    final dashboardBloc = context.read<DashboardBloc>();
    final dashboardState = dashboardBloc.state;
    Board? board;

    if (dashboardState is DashboardLoaded) {
      for (final b in dashboardState.ownedBoards) {
        if (b.id == widget.boardId) {
          board = b;
          break;
        }
      }
      if (board == null) {
        for (final b in dashboardState.joinedBoards) {
          if (b.id == widget.boardId) {
            board = b;
            break;
          }
        }
      }
    }

    final fallback = Board(
      id: widget.boardId,
      title: currentTitle,
      ownerId: '',
      members: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      buildBoardSettingsRoute(context, board: board ?? fallback),
    );
  }

  void _showExportOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Export & Share Board',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Export your canvas elements with full layout integrity:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _buildExportTile(
                  sheetContext,
                  icon: Icons.image_outlined,
                  iconColor: Colors.blue,
                  title: 'PNG Image',
                  subtitle: 'High-resolution lossless raster export (2x scale)',
                  format: BoardExportFormat.png,
                ),
                const SizedBox(height: 10),
                _buildExportTile(
                  sheetContext,
                  icon: Icons.picture_as_pdf_outlined,
                  iconColor: Colors.redAccent,
                  title: 'PDF Document',
                  subtitle: 'Printable formatted document with metadata header',
                  format: BoardExportFormat.pdf,
                ),
                const SizedBox(height: 10),
                _buildExportTile(
                  sheetContext,
                  icon: Icons.code_outlined,
                  iconColor: Colors.teal,
                  title: 'SVG Vector File',
                  subtitle: 'Scalable vector graphics compatible with Figma & Illustrator',
                  format: BoardExportFormat.svg,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    label: const Text(
                      'Share Board File (Native Sheet)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _canvasBloc.add(
                        const CanvasExportBoardRequested(
                          format: BoardExportFormat.png,
                          shareAfterExport: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportTile(
    BuildContext sheetContext, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required BoardExportFormat format,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined, size: 22),
              tooltip: 'Save to Device Storage',
              onPressed: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saving ${format.name.toUpperCase()} to device storage...'),
                    duration: const Duration(seconds: 1),
                  ),
                );
                _canvasBloc.add(
                  CanvasExportBoardRequested(
                    format: format,
                    shareAfterExport: false,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: 'Share via...',
              onPressed: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preparing ${format.name.toUpperCase()} for sharing...'),
                    duration: const Duration(seconds: 1),
                  ),
                );
                _canvasBloc.add(
                  CanvasExportBoardRequested(
                    format: format,
                    shareAfterExport: true,
                  ),
                );
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saving ${format.name.toUpperCase()} to device storage...'),
              duration: const Duration(seconds: 1),
            ),
          );
          _canvasBloc.add(
            CanvasExportBoardRequested(
              format: format,
              shareAfterExport: false,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _canvasBloc,
      child: BlocListener<CanvasBloc, CanvasState>(
        listenWhen: (previous, current) =>
            previous.error != current.error ||
            (current.exportSuccessMessage != null &&
                current.exportSuccessMessage != previous.exportSuccessMessage),
        listener: (context, state) async {
          if (state.exportSuccessMessage != null) {
            final msg = state.exportSuccessMessage!;
            final path = state.lastExportedFilePath;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: Colors.teal.shade700,
                duration: const Duration(seconds: 4),
                action: path != null
                    ? SnackBarAction(
                        label: 'Share',
                        textColor: Colors.white,
                        onPressed: () {
                          final format = path.endsWith('.pdf')
                              ? BoardExportFormat.pdf
                              : path.endsWith('.svg')
                                  ? BoardExportFormat.svg
                                  : BoardExportFormat.png;
                          context.read<CanvasBloc>().add(
                            CanvasExportBoardRequested(
                              format: format,
                              shareAfterExport: true,
                            ),
                          );
                        },
                      )
                    : null,
              ),
            );
            context.read<CanvasBloc>().add(const CanvasConsumeExportMessage());
          }

          final message = state.error;
          if (message == null || message.isEmpty) return;

          final isViewerWarning = message.toLowerCase().contains(
            'you are a viewer',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: isViewerWarning ? Colors.orange : Colors.red,
              duration: isViewerWarning
                  ? const Duration(seconds: 2)
                  : const Duration(seconds: 4),
            ),
          );

          if (message.contains('no longer available') ||
              message.contains('access lost')) {
            await _exitCanvas();
          }
        },
        child: BlocBuilder<CanvasBloc, CanvasState>(
          builder: (context, state) {
            _pruneImageCache(state.elements);
            final mappedElements = _mapElements(state.elements);
            final title =
                state.boardTitle ??
                'Board ${widget.boardId.substring(0, math.min(6, widget.boardId.length))}';

            return WillPopScope(
              onWillPop: () async {
                if (_preventGestureBack) {
                  // If back gesture is locked:
                  // 1) NEVER close the active tray here. When a user swipes inward from the edge,
                  //    Android OS fires a back gesture concurrently with the edge drag. Closing
                  //    the tray here would instantly snap it shut right after opening!
                  // 2) Suppress the exit snackbar if the user was recently interacting with edge triggers.
                  final now = DateTime.now();
                  final isRecentEdgeDrag = _lastEdgeDragTime != null &&
                      now.difference(_lastEdgeDragTime!) <
                          const Duration(milliseconds: 1500);

                  if (isRecentEdgeDrag) {
                    return false;
                  }

                  if (_lastBackSnackbarTime == null ||
                      now.difference(_lastBackSnackbarTime!) >
                          const Duration(seconds: 3)) {
                    _lastBackSnackbarTime = now;
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tap top-left back arrow to exit board'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return false;
                }
                await _savePreview();
                return true;
              },
              child: Scaffold(
                backgroundColor: isDark
                    ? AppColors.bgDark
                    : const Color(0xFFF5F5F5),
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Boards',
                    onPressed: _exitCanvas,
                  ),
                  title: GestureDetector(
                    onTap: () => _openSettings(state.boardTitle ?? 'Board'),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.center_focus_strong),
                      tooltip: 'Reset View',
                      onPressed: _toggleResetView,
                    ),
                    state.isExporting
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.file_download_outlined),
                            tooltip: 'Export & Share Board',
                            onPressed: () => _showExportOptionsSheet(context),
                          ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'settings') {
                          _openSettings(state.boardTitle ?? 'Board');
                        } else if (value == 'export') {
                          _showExportOptionsSheet(context);
                        } else if (value == 'share') {
                          _canvasBloc.add(
                            const CanvasExportBoardRequested(
                              format: BoardExportFormat.png,
                              shareAfterExport: true,
                            ),
                          );
                        } else if (value == 'copy') {
                          Clipboard.setData(
                            ClipboardData(text: widget.boardId),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Join Code copied to clipboard!'),
                            ),
                          );
                        } else if (value == 'toggle_gesture_lock') {
                          setState(() {
                            _preventGestureBack = !_preventGestureBack;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_preventGestureBack
                                  ? 'Gesture back locked (exit via back button).'
                                  : 'Gesture back unlocked.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else if (value == 'toggle_edge_buttons') {
                          setState(() {
                            _showEdgeTrayButtons = !_showEdgeTrayButtons;
                          });
                        } else if (value == 'exit') {
                          _exitCanvas();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'settings',
                          child: Text('Board Settings'),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.file_download_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Export Board...'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Share Board'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copy Join Code'),
                        ),
                        const PopupMenuDivider(),
                        CheckedPopupMenuItem<String>(
                          value: 'toggle_gesture_lock',
                          checked: _preventGestureBack,
                          child: const Text('Lock Back Gesture'),
                        ),
                        CheckedPopupMenuItem<String>(
                          value: 'toggle_edge_buttons',
                          checked: _showEdgeTrayButtons,
                          child: const Text('Show Tray Edge Icons'),
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
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    _lastCanvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _maybeAutoFrameCanvas(
                      state,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );

                    return RepaintBoundary(
                      key: _canvasPreviewKey,
                      child: Stack(
                        children: [
                          GestureDetector(
                            onScaleStart: (details) {
                              if (details.pointerCount >= 2) {
                                _isTransformingCanvas = true;
                                _gestureStartScale = _viewportScale;
                                _gestureStartOffset = _viewportOffset;
                                _gestureStartFocal = details.focalPoint;
                                return;
                              }

                              _isTransformingCanvas = false;
                              final worldPoint = _toWorld(
                                details.localFocalPoint,
                              );

                              // In arrow mode, touching an existing element should connect, not draw a freehand shape
                              if (_isArrowMode(state)) {
                                final hitShapeId = _hitTestShape(
                                  mappedElements,
                                  worldPoint,
                                );
                                if (hitShapeId != null) {
                                  return;
                                }
                                // Empty canvas drag in arrow mode: start drawing an arrow shape
                                _canvasBloc.add(CanvasStartShapeDraw(worldPoint));
                                return;
                              }

                              // Handle shape drawing mode
                              if (state.currentToolMode == CanvasToolMode.shape &&
                                  state.pendingShapeType != null) {
                                _canvasBloc.add(CanvasStartShapeDraw(worldPoint));
                                return;
                              }

                              final hitShapeId = _hitTestShape(
                                mappedElements,
                                worldPoint,
                              );
                              if (state.selectedShapeId != null &&
                                  hitShapeId == state.selectedShapeId) {
                                final hit = mappedElements.firstWhere(
                                  (e) => e.id == hitShapeId,
                                );
                                if (hit.kind == _ElementKind.stroke) {
                                  _isDraggingStroke = true;
                                  _setShapeEditing(true);
                                  _strokeDragOriginalPoints =
                                      List<Offset>.from(hit.points);
                                  _strokeDragStartWorldPoint = worldPoint;
                                  _strokeDragDelta = null;
                                  return;
                                }
                                _isDraggingShape = true;
                                _setShapeEditing(true);
                                _shapeDragStartCenter = hit.center;
                                _shapeDragStartWorldPoint = worldPoint;
                                _shapeDragStartRotation =
                                    state.selectedShapeRotation;
                                return;
                              }

                              _isDraggingShape = false;
                              _isDraggingStroke = false;
                              _startStroke(worldPoint);
                            },
                            onScaleUpdate: (details) {
                              if (details.pointerCount >= 2) {
                                if (!_isTransformingCanvas) {
                                  return;
                                }

                                final nextScale =
                                    (_gestureStartScale * details.scale).clamp(
                                      0.5,
                                      4.0,
                                    );
                                final focalDelta =
                                    details.focalPoint - _gestureStartFocal;

                                setState(() {
                                  _viewportScale = nextScale;
                                  _viewportOffset =
                                      _gestureStartOffset + focalDelta;
                                });
                                return;
                              }

                              if (_isTransformingCanvas) {
                                return;
                              }

                              // Handle shape drawing update
                              if (state.isDrawingShape) {
                                final worldPoint = _toWorld(
                                  details.localFocalPoint,
                                );
                                _canvasBloc.add(CanvasUpdateShapeDraw(worldPoint));
                                return;
                              }

                              final worldPoint = _toWorld(
                                details.localFocalPoint,
                              );
                              if (_isDraggingStroke) {
                                final delta =
                                    worldPoint - _strokeDragStartWorldPoint;
                                setState(() {
                                  _strokeDragDelta = delta;
                                });
                                return;
                              }

                              if (_isDraggingShape) {
                                var dragDelta =
                                    worldPoint - _shapeDragStartWorldPoint;
                                // Unrotate dragDelta to convert from shape's rotated frame
                                // back to screen frame
                                if (_shapeDragStartRotation != 0.0) {
                                  final cos = math.cos(
                                    -_shapeDragStartRotation,
                                  );
                                  final sin = math.sin(
                                    -_shapeDragStartRotation,
                                  );
                                  dragDelta = Offset(
                                    dragDelta.dx * cos - dragDelta.dy * sin,
                                    dragDelta.dx * sin + dragDelta.dy * cos,
                                  );
                                }
                                final nextCenter =
                                    _shapeDragStartCenter + dragDelta;
                                setState(() {
                                  _shapeDragPreviewCenter = nextCenter;
                                });
                                _canvasBloc.add(
                                  CanvasPreviewMoveSelectedShape(nextCenter),
                                );
                                return;
                              }
                              if (state.selectedShapeId != null) {
                                // Don't start a new stroke while an element
                                // is selected. Deselect first.
                                return;
                              }
                              final isEraser = state.brushType == 'eraser';
                              _showEraserPreview = isEraser;
                              _appendStroke(worldPoint);
                            },
                            onScaleEnd: (_) {
                              if (_isTransformingCanvas) {
                                _isTransformingCanvas = false;
                                return;
                              }

                              // End shape drawing
                              if (state.isDrawingShape) {
                                _canvasBloc.add(const CanvasEndShapeDraw());
                                return;
                              }

                              if (_isDraggingStroke) {
                                _isDraggingStroke = false;
                                _setShapeEditing(false);
                                if (_strokeDragDelta != null &&
                                    _strokeDragDelta != Offset.zero) {
                                  _canvasBloc.add(
                                    CanvasMoveSelectedStroke(
                                      _strokeDragDelta!,
                                    ),
                                  );
                                }
                                _strokeDragOriginalPoints = null;
                                _strokeDragDelta = null;
                                return;
                              }

                              if (_isDraggingShape) {
                                _isDraggingShape = false;
                                if (_shapeDragPreviewCenter != null) {
                                  _moveSelectedShape(
                                    _shapeDragPreviewCenter!,
                                  );
                                }
                                _shapeDragPreviewCenter = null;
                                _shapeDragStartCenter = Offset.zero;
                                _shapeDragStartWorldPoint = Offset.zero;
                                _shapeDragStartRotation = 0.0;
                                _setShapeEditing(false);
                                return;
                              }
                              if (_isRotatingShape || _isResizingShape) {
                                _isRotatingShape = false;
                                _isResizingShape = false;
                                _setShapeEditing(false);
                                return;
                              }
                              _showEraserPreview = false;
                              _endStroke();
                            },
                            onTapDown: (details) {
                              if (_isTransformingCanvas) return;
                              final worldPoint = _toWorld(
                                details.localPosition,
                              );
                              _lastTapWorldPoint = worldPoint;

                              // Pin comment placement flow:
                              if (state.isPlacingComment) {
                                _promptNewCommentDialog(worldPoint);
                                return;
                              }

                              // Arrow 2-element connection flow:
                              if (_isArrowMode(state)) {
                                final hitShapeId = _hitTestShape(
                                  mappedElements,
                                  worldPoint,
                                );
                                if (hitShapeId != null) {
                                  if (_arrowConnectStartElementId == null) {
                                    setState(() {
                                      _arrowConnectStartElementId = hitShapeId;
                                    });
                                    return;
                                  } else {
                                    final startId = _arrowConnectStartElementId!;
                                    final endId = hitShapeId;
                                    if (startId != endId) {
                                      final startElem = mappedElements
                                          .where((e) => e.id == startId)
                                          .firstOrNull;
                                      final endElem = mappedElements
                                          .where((e) => e.id == endId)
                                          .firstOrNull;
                                      final startPt =
                                          startElem?.center ?? worldPoint;
                                      final endPt =
                                          endElem?.center ?? worldPoint;

                                      _canvasBloc.add(CanvasAddConnector(
                                        startElementId: startId,
                                        startAnchor: 'auto',
                                        startPoint: startPt,
                                        endElementId: endId,
                                        endAnchor: 'auto',
                                        endPoint: endPt,
                                        lineStyle: 'straight',
                                        hasArrowhead: true,
                                        color: state.selectedColor,
                                        strokeWidth:
                                            math.max(state.strokeWidth, 2.5),
                                      ));

                                      setState(() {
                                        _arrowConnectStartElementId = null;
                                      });
                                      return;
                                    } else {
                                      // Tapped same element again: cancel
                                      setState(() {
                                        _arrowConnectStartElementId = null;
                                      });
                                      return;
                                    }
                                  }
                                } else {
                                  // Tapped empty canvas: clear start element
                                  if (_arrowConnectStartElementId != null) {
                                    setState(() {
                                      _arrowConnectStartElementId = null;
                                    });
                                  }
                                }
                              }

                              final hitShapeId = _hitTestShape(
                                mappedElements,
                                worldPoint,
                              );
                              final hit = hitShapeId != null
                                  ? mappedElements.firstWhere(
                                      (e) => e.id == hitShapeId,
                                    )
                                  : null;
                              if (hit?.kind == _ElementKind.stroke) {
                                // Stroke selection is deferred to onDoubleTap
                                return;
                              }
                              _selectShape(hitShapeId, expandEditor: false);
                            },
                            onDoubleTap: () {
                              final worldPoint = _lastTapWorldPoint;
                              if (worldPoint == null) return;
                              final hitShapeId = _hitTestShape(
                                mappedElements,
                                worldPoint,
                              );
                              if (hitShapeId == null) return;
                              final hit = mappedElements.firstWhere(
                                (e) => e.id == hitShapeId,
                              );
                              if (hit.kind == _ElementKind.stroke) {
                                _selectShape(hitShapeId, expandEditor: false);
                              } else if (hit.kind == _ElementKind.stickyNote) {
                                _editStickyNote(hit);
                              }
                            },
                            onTap: () {
                              // If in shape draw mode, tap switches back to doodle unless waiting for 2nd arrow connection
                              if (state.currentToolMode == CanvasToolMode.shape ||
                                  _isArrowMode(state)) {
                                if (state.pendingShapeType ==
                                        CanvasShapeType.arrow &&
                                    _arrowConnectStartElementId != null) {
                                  return;
                                }
                                _canvasBloc.add(const CanvasCancelShapeDraw());
                                return;
                              }
                              if (state.activeTray != null) {
                                _canvasBloc.add(
                                  CanvasToggleTray(state.activeTray!),
                                );
                              }
                            },
                            behavior: HitTestBehavior.translucent,
                            child: SizedBox.expand(
                              child: CustomPaint(
                                painter: _CanvasPainter(
                                  elements: mappedElements,
                                  currentPoints: state.currentStroke,
                                  currentColor: state.selectedColor,
                                  currentStrokeWidth: state.strokeWidth,
                                  currentBrushType: state.brushType,
                                  showEraserPreview:
                                      _showEraserPreview &&
                                      state.brushType == 'eraser',
                                  selectedShapeId: state.selectedShapeId,
                                  viewportScale: _viewportScale,
                                  viewportOffset: _viewportOffset,
                                  isDrawingShape: state.isDrawingShape,
                                  shapeDrawStart: state.shapeDrawStart,
                                  shapeDrawCurrent: state.shapeDrawCurrent,
                                  pendingShapeType: state.pendingShapeType,
                                  arrowConnectStartElementId:
                                      _isArrowMode(state)
                                          ? _arrowConnectStartElementId
                                          : null,
                                ),
                              ),
                            ),
                          ),

                          ..._buildImageOverlays(state),
                          ..._buildPinnedCommentPins(state),

                          _buildEdgeTriggers(state, isDark),
                          _buildAllTrays(state),
                          const BoardChatDrawer(),
                          const CommentsTray(),
                          const VoiceCallHud(),
                          if (state.selectedShapeId != null)
                            _buildSelectedElementPanel(
                              state,
                              mappedElements,
                            ),

                          _buildToolModeIndicator(state),

                          if (state.showTrayTips)
                            TrayTipsOverlay(
                              onDismiss: () {
                                _canvasBloc.add(const CanvasDismissTrayTips());
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<_CanvasElement> _mapElements(List<CanvasElement> elements) {
    final mapped = elements
        .map((element) {
          return switch (element) {
            StrokeElement e => _CanvasElement.stroke(
                id: e.id,
                z: e.z,
                points: e.points,
                color: e.color,
                strokeWidth: e.strokeWidth,
                opacity: e.opacity,
                brushType: e.brushType,
              ),
            ShapeElement e => _CanvasElement.shape(
                id: e.id,
                z: e.z,
                shapeType: e.shapeType,
                center: e.center,
                size: e.size,
                color: e.color,
                strokeWidth: e.strokeWidth,
                isFilled: e.isFilled,
                data: {
                  'rotation': e.rotation,
                  'borderRadius': e.borderRadius,
                },
              ),
            TextElement e => _CanvasElement.text(
                id: e.id,
                z: e.z,
                center: e.center,
                text: e.text,
                color: e.color,
              ),
            ImageElement e => _CanvasElement.image(
                id: e.id,
                z: e.z,
                center: e.center,
                width: e.width,
                height: e.height,
                imageBase64: e.imageBase64,
                data: e.toMap(),
              ),
            StickyNoteElement e => _CanvasElement.stickyNote(
                id: e.id,
                z: e.z,
                center: e.center,
                width: e.width,
                height: e.height,
                text: e.text,
                color: e.color,
                rotation: e.rotation,
                data: e.toMap(),
              ),
            ConnectorElement e => _CanvasElement.connector(
                id: e.id,
                z: e.z,
                startElementId: e.startElementId,
                startPoint: e.startPoint,
                startAnchor: e.startAnchor,
                endElementId: e.endElementId,
                endPoint: e.endPoint,
                endAnchor: e.endAnchor,
                lineStyle: e.lineStyle,
                color: e.color,
                strokeWidth: e.strokeWidth,
                hasArrowhead: e.hasArrowhead,
                data: e.toMap(),
              ),
          };
        })
        .toList();

    final draft = _shapeTransformDraft;

    final processed = mapped.map((element) {
      _CanvasElement result = element;

      // 1. Apply slider pending edits if this element is selected
      if (_pendingShapeEdits.isNotEmpty &&
          element.id == _canvasBloc.state.selectedShapeId) {
        Map<String, dynamic> updatedData = Map.from(result.data);
        _pendingShapeEdits.forEach((key, value) {
          updatedData[key] = value;
        });
        // Re-bind properties from updatedData
        if (result.kind == _ElementKind.shape) {
          result = result.copyWith(
            data: updatedData,
            size: updatedData['size'] ?? result.size,
            isFilled: updatedData['isFilled'] ?? result.isFilled,
          );
        }
      }

      // 2. Apply drag/scale draft overlay edits
      if (draft != null && result.id == draft.shapeId) {
        result = result.copyWith(
          center: draft.center,
          size: draft.size,
          width: (draft.width != null && draft.width! > 0)
              ? draft.width!
              : (result.width > 0 ? result.width : draft.size),
          height: (draft.height != null && draft.height! > 0)
              ? draft.height!
              : (result.height > 0 ? result.height : draft.size),
          data: {...result.data, 'rotation': draft.rotation},
        );
      } else if (_isDraggingShape &&
          _shapeDragPreviewCenter != null &&
          result.id == _canvasBloc.state.selectedShapeId) {
        result = result.copyWith(center: _shapeDragPreviewCenter!);
      } else if (_isDraggingStroke &&
          _strokeDragDelta != null &&
          _strokeDragOriginalPoints != null &&
          result.id == _canvasBloc.state.selectedShapeId) {
        final original = _strokeDragOriginalPoints!;
        result = result.copyWith(
          points: original.map((p) => p + _strokeDragDelta!).toList(),
        );
      }

      return result;
    }).toList();

    processed.sort((a, b) {
      if (draft != null) {
        if (a.id == draft.shapeId) return 1;
        if (b.id == draft.shapeId) return -1;
      }
      if (_isDraggingShape && _canvasBloc.state.selectedShapeId != null) {
        if (a.id == _canvasBloc.state.selectedShapeId) return 1;
        if (b.id == _canvasBloc.state.selectedShapeId) return -1;
      }
      if (_isDraggingStroke && _canvasBloc.state.selectedShapeId != null) {
        if (a.id == _canvasBloc.state.selectedShapeId) return 1;
        if (b.id == _canvasBloc.state.selectedShapeId) return -1;
      }
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });

    return processed;
  }

  double _pointToSegmentDistance(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (point - a).distance;
    final ap = point - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + clamped * ab.dx, a.dy + clamped * ab.dy);
    return (point - closest).distance;
  }

  String? _hitTestShape(List<_CanvasElement> elements, Offset position) {
    for (var i = elements.length - 1; i >= 0; i--) {
      final element = elements[i];
      if (element.kind == _ElementKind.stroke) {
        // Point-to‑segment distance check instead of bounding box,
        // so you must tap near the actual doodle line, not anywhere in its box.
        const tapPadding = 12.0;
        final points = element.points;
        if (points.length < 2) {
          if (points.length == 1 &&
              (points[0] - position).distance <= tapPadding) {
            return element.id;
          }
          continue;
        }
        for (int j = 0; j < points.length - 1; j++) {
          final dist = _pointToSegmentDistance(
            position,
            points[j],
            points[j + 1],
          );
          if (dist <= element.strokeWidth / 2 + tapPadding) {
            return element.id;
          }
        }
      } else if (element.kind == _ElementKind.connector) {
        Offset start = element.startPoint;
        Offset end = element.endPoint;
        if (element.startElementId != null) {
          final sElem = elements.where((e) => e.id == element.startElementId).firstOrNull;
          if (sElem != null) start = sElem.center;
        }
        if (element.endElementId != null) {
          final eElem = elements.where((e) => e.id == element.endElementId).firstOrNull;
          if (eElem != null) end = eElem.center;
        }
        final dist = _pointToSegmentDistance(position, start, end);
        if (dist <= element.strokeWidth / 2 + 14.0) {
          return element.id;
        }
      } else if (element.kind == _ElementKind.shape &&
          element.shapeType == CanvasShapeType.arrow) {
        final rot = (element.data['rotation'] as num?)?.toDouble() ?? 0.0;
        final halfW = element.size * 0.65;
        final cosR = math.cos(rot);
        final sinR = math.sin(rot);
        final start = Offset(
          element.center.dx - halfW * cosR,
          element.center.dy - halfW * sinR,
        );
        final end = Offset(
          element.center.dx + halfW * cosR,
          element.center.dy + halfW * sinR,
        );
        final dist = _pointToSegmentDistance(position, start, end);
        if (dist <= 18.0) {
          return element.id;
        }
      } else {
        // Shapes, images, text, sticky notes
        final distance = (position - element.center).distance;
        final sizeHit = element.kind == _ElementKind.shape
            ? element.size
            : (element.kind == _ElementKind.image ||
                    element.kind == _ElementKind.stickyNote)
                ? math.max(element.width, element.height)
                : 100.0;
        if (distance <= (sizeHit / 2) + 14) {
          return element.id;
        }
      }
    }
    return null;
  }

  Widget _buildSelectedElementPanel(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    final selected = mappedElements.where((e) => e.id == state.selectedShapeId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final element = selected.first;
    if (element.kind == _ElementKind.stroke) {
      return Stack(
        children: [
          _buildStrokeSelectionOverlay(state, element),
          if (!_isEditingShape && _isStrokeEditExpanded)
            _buildSelectedStrokePanel(state, element),
          if (!_isEditingShape && !_isStrokeEditExpanded)
            _buildStrokeEditBanner(),
        ],
      );
    }
    if (element.kind == _ElementKind.connector) {
      return _buildConnectorSelectionOverlay(state, element);
    }
    if (element.kind == _ElementKind.stickyNote) {
      return Stack(
        children: [
          if (!_isEditingShape)
            _buildStickyNoteEditBanner(
              Theme.of(context).brightness == Brightness.dark,
              element,
            ),
          _buildShapeTransformOverlay(state, mappedElements),
        ],
      );
    }
    return Stack(
      children: [
        if (!_isEditingShape && _isShapeEditTrayExpanded)
          _buildSelectedShapePanel(state, mappedElements),
        if (!_isEditingShape && !_isShapeEditTrayExpanded)
          _buildShapeEditBanner(
            Theme.of(context).brightness == Brightness.dark,
          ),
        _buildShapeTransformOverlay(state, mappedElements),
      ],
    );
  }

  Widget _buildStickyNoteEditBanner(bool isDark, _CanvasElement element) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24 + MediaQuery.of(context).padding.bottom,
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () => _editStickyNote(element),
          icon: Icon(
            Icons.edit,
            size: 18,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
          label: Text(
            'Edit Note',
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            foregroundColor: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorSelectionOverlay(
    CanvasState state,
    _CanvasElement element,
  ) {
    Offset start = element.startPoint;
    Offset end = element.endPoint;
    if (element.startElementId != null) {
      final s = state.elements
          .where((e) => e.id == element.startElementId)
          .firstOrNull;
      if (s != null) start = _getElementWorldCenter(s);
    }
    if (element.endElementId != null) {
      final e = state.elements
          .where((e) => e.id == element.endElementId)
          .firstOrNull;
      if (e != null) end = _getElementWorldCenter(e);
    }

    final screenStart = _toScreen(start);
    final screenEnd = _toScreen(end);
    final screenMid = Offset(
      (screenStart.dx + screenEnd.dx) / 2,
      (screenStart.dy + screenEnd.dy) / 2,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: screenStart.dx - 10,
          top: screenStart.dy - 10,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: screenEnd.dx - 10,
          top: screenEnd.dy - 10,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: screenMid.dx - 14,
          top: screenMid.dy - 36,
          child: GestureDetector(
            onTap: () => _canvasBloc.add(CanvasDeleteElement(element.id)),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.delete, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrokeSelectionOverlay(
    CanvasState state,
    _CanvasElement element,
  ) {
    final bounds = element.bounds;
    if (bounds == null) return const SizedBox.shrink();
    final topLeft = _toScreen(bounds.topLeft);
    final bottomRight = _toScreen(bounds.bottomRight);
    final screenRect =
        Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy);

    return Positioned(
      left: screenRect.left - 6,
      top: screenRect.top - 6,
      width: screenRect.width + 12,
      height: screenRect.height + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.blueAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () =>
                  _canvasBloc.add(CanvasDeleteElement(element.id)),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.delete, size: 14,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrokeEditBanner() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: Container(
        color: isDark ? AppColors.bgDark : AppColors.bgLight,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isStrokeEditExpanded = true;
              });
            },
            icon: Icon(
              Icons.brush,
              size: 18,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            label: Text(
              'Edit Doodle',
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              foregroundColor: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedStrokePanel(
    CanvasState state,
    _CanvasElement element,
  ) {
    final palette = <Color>[
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.white,
      Colors.brown,
      Colors.teal,
    ];
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 20,
      bottom: 8 + bottomInset,
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 6,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
              child: SizedBox(
                width: 260,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Doodle Edit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                _canvasBloc.add(CanvasDeleteElement(element.id)),
                            icon: const Icon(Icons.delete, size: 18,
                                color: Colors.red),
                            splashRadius: 16,
                            tooltip: 'Delete',
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isStrokeEditExpanded = false;
                              });
                            },
                            icon: const Icon(Icons.expand_more, size: 18),
                            splashRadius: 16,
                            tooltip: 'Minimize',
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      _buildSectionLabel('Width'),
                      Slider(
                        value: state.selectedStrokeWidth.clamp(1, 48),
                        min: 1,
                        max: 48,
                        activeColor: Colors.blueAccent,
                        onChanged: (v) => _canvasBloc.add(
                          CanvasUpdateSelectedStrokeWidth(v),
                        ),
                      ),
                      Text(
                        '${state.selectedStrokeWidth.toStringAsFixed(0)} px',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 6),
                      _buildSectionLabel('Opacity'),
                      Slider(
                        value: state.selectedStrokeOpacity.clamp(0, 1),
                        min: 0,
                        max: 1,
                        activeColor: Colors.blueAccent,
                        onChanged: (v) => _canvasBloc.add(
                          CanvasUpdateSelectedStrokeOpacity(v),
                        ),
                      ),
                      Text(
                        '${(state.selectedStrokeOpacity * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 6),
                      _buildSectionLabel('Brush'),
                      DropdownButton<String>(
                        value: state.selectedStrokeBrushType,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        onChanged: (v) {
                          if (v != null) {
                            _canvasBloc.add(
                              CanvasUpdateSelectedStrokeBrushType(v),
                            );
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'solid', child: Text('Solid')),
                          DropdownMenuItem(
                            value: 'textured',
                            child: Text('Textured'),
                          ),
                          DropdownMenuItem(
                            value: 'watercolor',
                            child: Text('Watercolor'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildSectionLabel('Color'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: palette
                            .map(
                              (color) => InkWell(
                                onTap: () => _canvasBloc.add(
                                  CanvasUpdateSelectedStrokeColor(color.value),
                                ),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: color.value ==
                                          state.selectedStrokeColor
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSelectedShapePanel(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    final selected = mappedElements.where((e) => e.id == state.selectedShapeId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final shape = selected.first;

    final palette = <Color>[
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final pendingBorderRadius = (_pendingShapeEdits['borderRadius'] as num?)
        ?.toDouble();
    final effectiveBorderRadius =
        (pendingBorderRadius ?? state.selectedShapeBorderRadius).clamp(
          0.0,
          shape.size / 2,
        );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 18 + bottomInset + 12,
      child: Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 6,
          child: SizedBox(
            width: 260,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Shape Edit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          _commitPendingShapeEdits();
                          setState(() {
                            _isShapeEditTrayExpanded = false;
                          });
                        },
                        icon: const Icon(Icons.expand_more, size: 18),
                        splashRadius: 16,
                        tooltip: 'Minimize',
                      ),
                      IconButton(
                        onPressed: () {
                          _commitPendingShapeEdits();
                          _canvasBloc.add(
                            CanvasDeleteElement(shape.id),
                          );
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        splashRadius: 16,
                        tooltip: 'Delete',
                      ),
                      IconButton(
                        onPressed: () {
                          _commitPendingShapeEdits();
                          _selectShape(null);
                        },
                        icon: const Icon(Icons.close, size: 18),
                        splashRadius: 16,
                        tooltip: 'Deselect shape',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: state.selectedShapeIsFilled,
                    title: const Text('Filled', style: TextStyle(fontSize: 13)),
                    onChanged: _deferredSetSelectedShapeFill,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size ${shape.size.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: shape.size.clamp(24, 320),
                    min: 24,
                    max: 320,
                    onChanged: _deferredResizeSelectedShape,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rotation ${(state.selectedShapeRotation * 180 / math.pi).toStringAsFixed(0)}°',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: state.selectedShapeRotation,
                    min: 0,
                    max: math.pi * 2,
                    onChanged: _deferredRotateSelectedShape,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Corner Radius ${effectiveBorderRadius.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: effectiveBorderRadius,
                    min: 0,
                    max: shape.size / 2,
                    onChanged: _deferredSetSelectedShapeBorderRadius,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: palette
                        .map(
                          (color) => InkWell(
                            onTap: () => _setSelectedShapeColor(color),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShapeEditBanner(bool isDark) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: Container(
        color: isDark ? AppColors.bgDark : AppColors.bgLight,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isShapeEditTrayExpanded = true;
              });
            },
            icon: Icon(
              Icons.tune,
              size: 18,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            label: Text(
              'Edit Shape',
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              foregroundColor: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShapeTransformOverlay(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    final selected = mappedElements.where((e) => e.id == state.selectedShapeId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final baseShape = selected.first;
    if (baseShape.kind == _ElementKind.connector) {
      return const SizedBox.shrink();
    }
    final shape =
        _shapeTransformDraft != null &&
            _shapeTransformDraft!.shapeId == baseShape.id
        ? baseShape.copyWith(
            center: _shapeTransformDraft!.center,
            size: _shapeTransformDraft!.size,
            width: (_shapeTransformDraft!.width != null &&
                    _shapeTransformDraft!.width! > 0)
                ? _shapeTransformDraft!.width!
                : baseShape.width,
            height: (_shapeTransformDraft!.height != null &&
                    _shapeTransformDraft!.height! > 0)
                ? _shapeTransformDraft!.height!
                : baseShape.height,
            data: {
              ...baseShape.data,
              'rotation': _shapeTransformDraft!.rotation,
            },
          )
        : baseShape;

    final center = _toScreen(shape.center);
    final double rawW;
    final double rawH;
    if (shape.kind == _ElementKind.stickyNote ||
        shape.kind == _ElementKind.image) {
      rawW = shape.width > 0
          ? shape.width
          : (shape.size > 0 ? shape.size : 160.0);
      rawH = shape.height > 0
          ? shape.height
          : (shape.size > 0 ? shape.size : 160.0);
    } else if (shape.shapeType == CanvasShapeType.arrow) {
      rawW = shape.size * 1.3;
      rawH = shape.size * 0.7;
    } else if (shape.shapeType == CanvasShapeType.rectangle) {
      rawW = shape.size * 1.35;
      rawH = shape.size * 0.8;
    } else {
      rawW = shape.size;
      rawH = shape.size;
    }

    final screenW = rawW * _viewportScale;
    final screenH = rawH * _viewportScale;
    final halfW = screenW / 2;
    final halfH = screenH / 2;
    final rotation = (shape.data['rotation'] as num?)?.toDouble() ?? 0.0;

    return Positioned(
      left: center.dx - halfW - 16,
      top: center.dy - halfH - 16,
      width: screenW + 32,
      height: screenH + 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: rotation,
            child: IgnorePointer(
              ignoring: false,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 16,
                    top: 16,
                    width: screenW,
                    height: screenH,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) {
                        _setShapeEditing(true);
                        _shapeTransformDraft ??= _ShapeTransformDraft(
                          shapeId: shape.id,
                          center: shape.center,
                          size: shape.size,
                          width: rawW,
                          height: rawH,
                          rotation:
                              (shape.data['rotation'] as num?)?.toDouble() ??
                              state.selectedShapeRotation,
                        );
                      },
                      onPanUpdate: (details) {
                        final draft =
                            _shapeTransformDraft ??
                            _ShapeTransformDraft(
                              shapeId: shape.id,
                              center: shape.center,
                              size: shape.size,
                              width: rawW,
                              height: rawH,
                              rotation:
                                  (shape.data['rotation'] as num?)?.toDouble() ??
                                  state.selectedShapeRotation,
                            );
                        final nextCenter = Offset(
                          draft.center.dx + (details.delta.dx / _viewportScale),
                          draft.center.dy + (details.delta.dy / _viewportScale),
                        );
                        setState(() {
                          _shapeTransformDraft = draft.copyWith(center: nextCenter);
                        });
                        _canvasBloc.add(CanvasPreviewMoveSelectedShape(nextCenter));
                      },
                      onPanEnd: (_) {
                        final draft = _shapeTransformDraft;
                        if (draft != null && draft.shapeId == shape.id) {
                          _moveSelectedShape(draft.center);
                        }
                        _shapeTransformDraft = null;
                        _setShapeEditing(false);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.blueAccent, width: 2.0),
                          borderRadius: BorderRadius.circular(
                            shape.kind == _ElementKind.stickyNote ? 8 : 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Rotate handle (top center)
                  Positioned(
                    top: 2,
                    left: 16 + (screenW / 2) - 14,
                    child: GestureDetector(
                      onPanStart: (_) {
                        _setShapeEditing(true);
                        _isRotatingShape = true;
                        final baseRotation =
                            (shape.data['rotation'] as num?)?.toDouble() ??
                            state.selectedShapeRotation;
                        _shapeTransformDraft = _ShapeTransformDraft(
                          shapeId: shape.id,
                          center: shape.center,
                          size: shape.size,
                          width: rawW,
                          height: rawH,
                          rotation: baseRotation,
                        );
                      },
                      onPanUpdate: (details) {
                        final draft = _shapeTransformDraft;
                        if (draft == null || draft.shapeId != shape.id) return;
                        final delta = details.delta.dx + details.delta.dy;
                        setState(() {
                          _shapeTransformDraft = draft.copyWith(
                            rotation: draft.rotation + (delta / 140),
                          );
                        });
                        _canvasBloc.add(
                          CanvasPreviewRotateSelectedShape(
                            draft.rotation + (delta / 140),
                          ),
                        );
                      },
                      onPanEnd: (_) {
                        final draft = _shapeTransformDraft;
                        if (draft != null && draft.shapeId == shape.id) {
                          _rotateSelectedShape(draft.rotation);
                        }
                        _shapeTransformDraft = null;
                        _isRotatingShape = false;
                        _setShapeEditing(false);
                      },
                      child: _buildHandle(Icons.rotate_right),
                    ),
                  ),
                  // Resize handle (bottom right)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onPanStart: (_) {
                        _setShapeEditing(true);
                        _isResizingShape = true;
                        _shapeTransformDraft = _ShapeTransformDraft(
                          shapeId: shape.id,
                          center: shape.center,
                          size: shape.size,
                          width: rawW,
                          height: rawH,
                          rotation:
                              (shape.data['rotation'] as num?)?.toDouble() ??
                              state.selectedShapeRotation,
                        );
                      },
                      onPanUpdate: (details) {
                        final draft = _shapeTransformDraft;
                        if (draft == null || draft.shapeId != shape.id) return;
                        final delta = details.delta.dx + details.delta.dy;
                        final nextSize = (draft.size + delta / _viewportScale * 1.8)
                            .clamp(32.0, 480.0)
                            .toDouble();
                        final nextW = ((draft.width ?? draft.size) + details.delta.dx / _viewportScale * 1.8)
                            .clamp(40.0, 480.0)
                            .toDouble();
                        final nextH = ((draft.height ?? draft.size) + details.delta.dy / _viewportScale * 1.8)
                            .clamp(40.0, 480.0)
                            .toDouble();
                        setState(() {
                          _shapeTransformDraft = draft.copyWith(
                            size: nextSize,
                            width: nextW,
                            height: nextH,
                          );
                        });
                        _canvasBloc.add(CanvasPreviewResizeSelectedShape(nextSize));
                      },
                      onPanEnd: (_) {
                        final draft = _shapeTransformDraft;
                        if (draft != null && draft.shapeId == shape.id) {
                          _resizeSelectedShape(draft.size);
                        }
                        _shapeTransformDraft = null;
                        _isResizingShape = false;
                        _setShapeEditing(false);
                      },
                      child: _buildHandle(Icons.open_in_full),
                    ),
                  ),
                  // Sticky note quick edit button (bottom left)
                  if (shape.kind == _ElementKind.stickyNote)
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: GestureDetector(
                        onTap: () => _editStickyNote(shape),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.blueAccent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Delete button (top right)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _canvasBloc.add(CanvasDeleteElement(shape.id)),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.delete, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(IconData icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: Colors.blueAccent),
    );
  }

  Widget _buildAllTrays(CanvasState state) {
    return Stack(
      children: [
        MembersTray(
          isOpen: state.activeTray == 'members',
          onClose: () => _toggleTray('members'),
        ),
        AITray(
          isOpen: state.activeTray == 'ai',
          controller: _aiPromptController,
          onAddText: _addAiTextElement,
          onUploadImage: _uploadImageToCanvas,
          onGenerateImage: _onGenerateImagePlaceholder,
          recentImages: _recentImages,
          onClose: () => _toggleTray('ai'),
        ),
        ToolsTray(
          isOpen: state.activeTray == 'tools',
          onUndo: _undo,
          onRedo: _redo,
          onClearAll: _clearAll,
          onAddStickyNote: _addStickyNoteDialog,
          onAddConnector: _addConnectorDialog,
          onExport: () => _showExportOptionsSheet(context),
          onClose: () => _toggleTray('tools'),
        ),
        ShapesTray(
          isOpen: state.activeTray == 'shapes',
          onSelectShapeForDrawing: _selectShapeForDrawing,
          onClose: () => _toggleTray('shapes'),
        ),
        BrushTray(
          isOpen: state.activeTray == 'brushes',
          strokeWidth: state.strokeWidth,
          selectedColor: state.selectedColor,
          brushOpacity: state.brushOpacity,
          brushType: state.brushType,
          eraserEraseEverything: state.eraserEraseEverything,
          smoothDoodlesEnabled: _smoothDoodlesEnabled,
          onStrokeWidthChanged: (v) {
            _canvasBloc.add(CanvasUpdateStrokeWidth(v));
          },
          onColorSelected: (c) {
            _canvasBloc.add(CanvasUpdateColor(c));
          },
          onOpacityChanged: (v) {
            _canvasBloc.add(CanvasUpdateBrushOpacity(v));
          },
          onBrushTypeChanged: (type) {
            _canvasBloc.add(CanvasUpdateBrushType(type));
          },
          onEraserEraseEverythingChanged: _setEraserScope,
          onSmoothDoodlesChanged: (v) {
            setState(() => _smoothDoodlesEnabled = v);
          },
          onToolModeChanged: (mode) {
            _canvasBloc.add(CanvasSetToolMode(mode));
          },
          onClose: () => _toggleTray('brushes'),
        ),
      ],
    );
  }

  Widget _buildEdgeTriggers(CanvasState state, bool isDark) {
    return Stack(
      children: [
        // Touch triggers for swiping
        // BOTTOM: Swipe Up for Brushes
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onVerticalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dy < -6) _openTray('brushes');
            },
            child: Container(
              height: 55,
              width: double.infinity,
              color: Colors.transparent,
            ),
          ),
        ),
        // TOP LEFT: Swipe Right for Members
        Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onHorizontalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dx > 6) _openTray('members');
            },
            child: Container(
              height: 220,
              width: 50,
              margin: const EdgeInsets.only(top: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // BOTTOM LEFT: Swipe Right for Tools
        Align(
          alignment: Alignment.bottomLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onHorizontalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dx > 6) _openTray('tools');
            },
            child: Container(
              height: 220,
              width: 50,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // TOP RIGHT: Swipe Left for AI
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onHorizontalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dx < -6) _openTray('ai');
            },
            child: Container(
              height: 220,
              width: 50,
              margin: const EdgeInsets.only(top: 60),
              color: Colors.transparent,
            ),
          ),
        ),
        // BOTTOM RIGHT: Swipe Left for Shapes
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onHorizontalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dx < -6) _openTray('shapes');
            },
            child: Container(
              height: 220,
              width: 50,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
            ),
          ),
        ),

        // Visual Edge Tray Tab Icons (User can tap these instead of swiping)
        if (_showEdgeTrayButtons) ...[
          // TOP LEFT: Members Tab
          _buildSideTab(
            tray: 'members',
            icon: Icons.people_alt_outlined,
            label: 'Members',
            alignment: Alignment.topLeft,
            margin: const EdgeInsets.only(top: 130),
            isLeft: true,
            isActive: state.activeTray == 'members',
            isDark: isDark,
          ),
          // BOTTOM LEFT: Tools Tab
          _buildSideTab(
            tray: 'tools',
            icon: Icons.handyman_outlined,
            label: 'Tools',
            alignment: Alignment.bottomLeft,
            margin: const EdgeInsets.only(bottom: 120),
            isLeft: true,
            isActive: state.activeTray == 'tools',
            isDark: isDark,
          ),
          // TOP RIGHT: AI Tab
          _buildSideTab(
            tray: 'ai',
            icon: Icons.auto_awesome,
            label: 'AI Assistant',
            alignment: Alignment.topRight,
            margin: const EdgeInsets.only(top: 130),
            isLeft: false,
            isActive: state.activeTray == 'ai',
            isDark: isDark,
          ),
          // BOTTOM RIGHT: Shapes Tab
          _buildSideTab(
            tray: 'shapes',
            icon: Icons.category_outlined,
            label: 'Shapes',
            alignment: Alignment.bottomRight,
            margin: const EdgeInsets.only(bottom: 120),
            isLeft: false,
            isActive: state.activeTray == 'shapes',
            isDark: isDark,
          ),
          // BOTTOM CENTER: Brushes Tab Pill
          _buildBottomCenterTab(
            isActive: state.activeTray == 'brushes',
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildSideTab({
    required String tray,
    required IconData icon,
    required String label,
    required Alignment alignment,
    required EdgeInsets margin,
    required bool isLeft,
    required bool isActive,
    required bool isDark,
  }) {
    final bgColor = isDark
        ? (isActive
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A).withOpacity(0.92))
        : (isActive
            ? Colors.blue.shade50
            : Colors.white.withOpacity(0.95));
    final iconColor = isActive
        ? Colors.blueAccent
        : (isDark ? Colors.white70 : Colors.black87);
    final borderColor = isActive
        ? Colors.blueAccent
        : (isDark ? Colors.white24 : Colors.black12);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: margin,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleTray(tray),
          child: Container(
            width: 38,
            height: 46,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.horizontal(
                left: isLeft ? Radius.zero : const Radius.circular(14),
                right: isLeft ? const Radius.circular(14) : Radius.zero,
              ),
              border: Border(
                top: BorderSide(color: borderColor, width: 1.2),
                bottom: BorderSide(color: borderColor, width: 1.2),
                left: isLeft
                    ? BorderSide.none
                    : BorderSide(color: borderColor, width: 1.2),
                right: isLeft
                    ? BorderSide(color: borderColor, width: 1.2)
                    : BorderSide.none,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCenterTab({
    required bool isActive,
    required bool isDark,
  }) {
    final bgColor = isDark
        ? (isActive
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A).withOpacity(0.92))
        : (isActive
            ? Colors.blue.shade50
            : Colors.white.withOpacity(0.95));
    final iconColor = isActive
        ? Colors.blueAccent
        : (isDark ? Colors.white70 : Colors.black87);
    final borderColor = isActive
        ? Colors.blueAccent
        : (isDark ? Colors.white24 : Colors.black12);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleTray('brushes'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.palette_outlined, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  'Brushes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isActive ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: 16,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolModeIndicator(CanvasState state) {
    if (state.currentToolMode == CanvasToolMode.doodle) {
      return const SizedBox.shrink();
    }

    final (IconData icon, String label) = _isArrowMode(state)
        ? (
            Icons.arrow_forward_outlined,
            _arrowConnectStartElementId != null
                ? 'Arrow: Tap 2nd shape to point to'
                : 'Arrow: Tap 2 shapes to connect, or drag',
          )
        : switch (state.currentToolMode) {
            CanvasToolMode.shape => (
              Icons.category_outlined,
              state.pendingShapeType != null
                  ? 'Shape: ${state.pendingShapeType!.name}'
                  : 'Shape',
            ),
            CanvasToolMode.eraser => (Icons.auto_fix_high_outlined, 'Eraser'),
            CanvasToolMode.text => (Icons.text_fields, 'Text'),
            CanvasToolMode.arrow => (Icons.arrow_forward_outlined, 'Arrow'),
            CanvasToolMode.image => (Icons.image_outlined, 'Image'),
            CanvasToolMode.highlight => (Icons.highlight_outlined, 'Highlight'),
            CanvasToolMode.doodle => (Icons.brush, 'Doodle'),
          };

    return Positioned(
      left: 48,
      bottom: 48,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _arrowConnectStartElementId = null;
          });
          _canvasBloc.add(
            const CanvasSetToolMode(CanvasToolMode.doodle),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Tap to exit',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildImageOverlays(CanvasState state) {
    final overlays = <Widget>[];
    for (final element in state.elements) {
      if (element is! ImageElement) continue;
      final imageBase64 = element.imageBase64;
      if (imageBase64.isEmpty) continue;

      final cacheKey = '${imageBase64.length}:${imageBase64.hashCode}';
      Uint8List? imageBytes = _decodedImageCache[element.id];
      final cachedKey = _decodedImageCacheKey[element.id];
      if (imageBytes == null || cachedKey != cacheKey) {
        try {
          imageBytes = base64Decode(imageBase64);
          _decodedImageCache[element.id] = imageBytes;
          _decodedImageCacheKey[element.id] = cacheKey;
        } catch (_) {
          continue;
        }
      }

      if (imageBytes.isEmpty) {
        continue;
      }

      final cx = element.center.dx;
      final cy = element.center.dy;
      final width = element.width;
      final height = element.height;

      final draft = _imageDrafts[element.id];
      final effectiveCx = draft?.cx ?? cx;
      final effectiveCy = draft?.cy ?? cy;
      final effectiveWidth = draft?.width ?? width;
      final effectiveHeight = draft?.height ?? height;

      final screenCenter = _toScreen(Offset(effectiveCx, effectiveCy));
      final screenWidth = effectiveWidth * _viewportScale;
      final screenHeight = effectiveHeight * _viewportScale;

      overlays.add(
        Positioned(
          left: screenCenter.dx - (screenWidth / 2),
          top: screenCenter.dy - (screenHeight / 2),
          child: GestureDetector(
            onPanStart: (_) {
              _imageDrafts[element.id] = _ImageDraftTransform(
                cx: effectiveCx,
                cy: effectiveCy,
                width: effectiveWidth,
                height: effectiveHeight,
              );
            },
            onPanUpdate: (details) {
              final draftNow =
                  _imageDrafts[element.id] ??
                  _ImageDraftTransform(
                    cx: effectiveCx,
                    cy: effectiveCy,
                    width: effectiveWidth,
                    height: effectiveHeight,
                  );
              setState(() {
                _imageDrafts[element.id] = draftNow.copyWith(
                  cx: draftNow.cx + (details.delta.dx / _viewportScale),
                  cy: draftNow.cy + (details.delta.dy / _viewportScale),
                );
              });
              final liveDraft = _imageDrafts[element.id];
              if (liveDraft != null) {
                _canvasBloc.add(
                  CanvasPreviewImageElement(
                    elementId: element.id,
                    center: Offset(liveDraft.cx, liveDraft.cy),
                    width: liveDraft.width,
                    height: liveDraft.height,
                  ),
                );
              }
            },
            onPanEnd: (_) {
              final finalDraft = _imageDrafts.remove(element.id);
              if (finalDraft == null) return;
              _canvasBloc.add(
                CanvasUpdateImageElement(
                  elementId: element.id,
                  center: Offset(finalDraft.cx, finalDraft.cy),
                  width: finalDraft.width,
                  height: finalDraft.height,
                ),
              );
            },
            child: SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytes,
                      width: screenWidth,
                      height: screenHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (state.selectedShapeId == element.id)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () =>
                            _canvasBloc.add(CanvasDeleteElement(element.id)),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.delete,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: GestureDetector(
                      onPanStart: (_) {
                        _imageDrafts[element.id] = _ImageDraftTransform(
                          cx: effectiveCx,
                          cy: effectiveCy,
                          width: effectiveWidth,
                          height: effectiveHeight,
                        );
                      },
                      onPanUpdate: (details) {
                        final draftNow =
                            _imageDrafts[element.id] ??
                            _ImageDraftTransform(
                              cx: effectiveCx,
                              cy: effectiveCy,
                              width: effectiveWidth,
                              height: effectiveHeight,
                            );
                        setState(() {
                          const minDimension = 24.0;
                          _imageDrafts[element.id] = draftNow.copyWith(
                            cx:
                                draftNow.cx +
                                (details.delta.dx / (_viewportScale * 2)),
                            cy:
                                draftNow.cy +
                                (details.delta.dy / (_viewportScale * 2)),
                            width: math.max(
                              minDimension,
                              draftNow.width +
                                  (details.delta.dx / _viewportScale),
                            ),
                            height: math.max(
                              minDimension,
                              draftNow.height +
                                  (details.delta.dy / _viewportScale),
                            ),
                          );
                        });
                        final liveDraft = _imageDrafts[element.id];
                        if (liveDraft != null) {
                          _canvasBloc.add(
                            CanvasPreviewImageElement(
                              elementId: element.id,
                              center: Offset(liveDraft.cx, liveDraft.cy),
                              width: liveDraft.width,
                              height: liveDraft.height,
                            ),
                          );
                        }
                      },
                      onPanEnd: (_) {
                        final finalDraft = _imageDrafts.remove(element.id);
                        if (finalDraft == null) return;
                        _canvasBloc.add(
                          CanvasUpdateImageElement(
                            elementId: element.id,
                            center: Offset(finalDraft.cx, finalDraft.cy),
                            width: finalDraft.width,
                            height: finalDraft.height,
                          ),
                        );
                      },
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: const Icon(Icons.open_in_full, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return overlays;
  }

  void _promptNewCommentDialog(Offset worldPoint) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pin_drop, color: Colors.amber),
            SizedBox(width: 8),
            Text('Add Comment Pin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pin at (${worldPoint.dx.toInt()}, ${worldPoint.dy.toInt()})',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Write a comment... (use @name to mention)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _canvasBloc.add(
                const CanvasToggleCommentPlacementMode(enable: false),
              );
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                _canvasBloc.add(
                  CanvasAddCommentRequested(
                    text: text,
                    canvasPosition: worldPoint,
                  ),
                );
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Post Pin'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPinnedCommentPins(CanvasState state) {
    final widgets = <Widget>[];
    for (final comment in state.comments) {
      if (comment.canvasPosition == null) continue;
      final screenPos = _toScreen(comment.canvasPosition!);
      final isSelected = comment.id == state.activeCommentId;

      widgets.add(
        Positioned(
          left: screenPos.dx - 16,
          top: screenPos.dy - 32,
          child: GestureDetector(
            onTap: () {
              _canvasBloc.add(CanvasSetActiveComment(comment.id));
              if (!state.isCommentsTrayOpen) {
                _canvasBloc.add(const CanvasToggleCommentsTray());
              }
            },
            child: Tooltip(
              message: '${comment.authorName}: ${comment.text}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber.shade700
                          : Colors.amber.shade600,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble,
                          size: 11,
                          color: Colors.white,
                        ),
                        if (comment.replies.isNotEmpty) ...[
                          const SizedBox(width: 3),
                          Text(
                            '${comment.replies.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: const Size(8, 5),
                    painter: _TrianglePainter(
                      color: isSelected
                          ? Colors.amber.shade700
                          : Colors.amber.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  void dispose() {
    _shapeEditDebounceTimer?.cancel();
    _canvasBloc.close();
    _aiPromptController.dispose();
    super.dispose();
  }
}

class _ImageDraftTransform {
  final double cx;
  final double cy;
  final double width;
  final double height;

  const _ImageDraftTransform({
    required this.cx,
    required this.cy,
    required this.width,
    required this.height,
  });

  _ImageDraftTransform copyWith({
    double? cx,
    double? cy,
    double? width,
    double? height,
  }) {
    return _ImageDraftTransform(
      cx: cx ?? this.cx,
      cy: cy ?? this.cy,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class _ViewportTransform {
  final double scale;
  final Offset offset;

  const _ViewportTransform({required this.scale, required this.offset});
}

class _ShapeTransformDraft {
  final String shapeId;
  final Offset center;
  final double size;
  final double? width;
  final double? height;
  final double rotation;

  const _ShapeTransformDraft({
    required this.shapeId,
    required this.center,
    required this.size,
    this.width,
    this.height,
    required this.rotation,
  });

  _ShapeTransformDraft copyWith({
    Offset? center,
    double? size,
    double? width,
    double? height,
    double? rotation,
  }) {
    return _ShapeTransformDraft(
      shapeId: shapeId,
      center: center ?? this.center,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}