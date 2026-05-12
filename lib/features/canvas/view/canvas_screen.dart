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
import 'media_editor_screen.dart';
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
  bool _isDraggingShape = false;
  bool _isEditingShape = false;
  bool _isShapeEditTrayExpanded = false;
  bool _isRotatingShape = false;
  bool _isResizingShape = false;
  bool _showEraserPreview = false;
  bool _isTransformingCanvas = false;
  bool _didAutoFrameContent = false;
  Size _lastCanvasSize = Size.zero;
  Offset _shapeDragDelta = Offset.zero;
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

  static const double _viewportComparisonEpsilon = 0.01;

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
    if (_canvasBloc.state.activeTray == tray) return;
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  Offset _toWorld(Offset localPoint) {
    return Offset(
      (localPoint.dx - _viewportOffset.dx) / _viewportScale,
      (localPoint.dy - _viewportOffset.dy) / _viewportScale,
    );
  }

  Offset _toScreen(Offset worldPoint) {
    return Offset(
      (worldPoint.dx * _viewportScale) + _viewportOffset.dx,
      (worldPoint.dy * _viewportScale) + _viewportOffset.dy,
    );
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

  void _selectShape(String? shapeId, {bool expandEditor = false}) {
    // Commit any pending edits before selecting a different shape
    _commitPendingShapeEdits();

    if (mounted) {
      setState(() {
        _isShapeEditTrayExpanded = shapeId != null && expandEditor;
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
    _scheduleShapeEditCommit();
  }

  void _deferredSetSelectedShapeFill(bool isFilled) {
    _pendingShapeEdits['isFilled'] = isFilled;
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
    _scheduleShapeEditCommit();
  }

  void _deferredSetSelectedShapeBorderRadius(double borderRadius) {
    setState(() {
      _pendingShapeEdits['borderRadius'] = borderRadius;
    });
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

  void _addShape(CanvasShapeType shapeType) {
    setState(() {
      _isShapeEditTrayExpanded = true;
    });
    _canvasBloc.add(CanvasAddShape(shapeType, _canvasBloc.randomShapeCenter()));
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

  Future<void> _uploadImageToCanvas() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
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
        .where((element) => element.type == 'image')
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
      final data = element.data as Map<String, dynamic>? ?? const {};
      Rect? candidate;

      if (element.type == 'stroke') {
        final pointMaps = (data['points'] as List?) ?? const [];
        if (pointMaps.isEmpty) continue;
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = -double.infinity;
        double maxY = -double.infinity;
        for (final p in pointMaps.whereType<Map>()) {
          final x = (p['x'] as num?)?.toDouble() ?? 0.0;
          final y = (p['y'] as num?)?.toDouble() ?? 0.0;
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
        }
        final pad = ((data['strokeWidth'] as num?)?.toDouble() ?? 5.0) + 8;
        candidate = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(pad);
      } else if (element.type == 'shape') {
        final cx = (data['cx'] as num?)?.toDouble() ?? 0.0;
        final cy = (data['cy'] as num?)?.toDouble() ?? 0.0;
        final size = (data['size'] as num?)?.toDouble() ?? 64.0;
        candidate = Rect.fromCenter(
          center: Offset(cx, cy),
          width: size * 1.6,
          height: size * 1.6,
        );
      } else if (element.type == 'text') {
        final cx = (data['cx'] as num?)?.toDouble() ?? 0.0;
        final cy = (data['cy'] as num?)?.toDouble() ?? 0.0;
        candidate = Rect.fromCenter(
          center: Offset(cx, cy),
          width: 220,
          height: 72,
        );
      } else if (element.type == 'image') {
        final cx = (data['cx'] as num?)?.toDouble() ?? 0.0;
        final cy = (data['cy'] as num?)?.toDouble() ?? 0.0;
        final width = (data['width'] as num?)?.toDouble() ?? 220.0;
        final height = (data['height'] as num?)?.toDouble() ?? 160.0;
        candidate = Rect.fromCenter(
          center: Offset(cx, cy),
          width: width,
          height: height,
        );
      }

      if (candidate == null) continue;
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
    final dashboardState = context.read<DashboardBloc>().state;
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
                await _savePreview();
                return true;
              },
              child: Scaffold(
                backgroundColor: isDark
                    ? AppColors.bgDark
                    : const Color(0xFFF5F5F5),
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
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
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'settings') {
                          _openSettings(state.boardTitle ?? 'Board');
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
                          value: 'settings',
                          child: Text('Board Settings'),
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
                              final hitShapeId = _hitTestShape(
                                mappedElements,
                                worldPoint,
                              );
                              if (state.selectedShapeId != null &&
                                  hitShapeId == state.selectedShapeId) {
                                _isDraggingShape = true;
                                _setShapeEditing(true);
                                final shape = mappedElements.firstWhere(
                                  (e) => e.id == hitShapeId,
                                );
                                _shapeDragDelta = worldPoint - shape.center;
                                return;
                              }

                              _isDraggingShape = false;
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

                              final worldPoint = _toWorld(
                                details.localFocalPoint,
                              );
                              if (_isDraggingShape) {
                                _moveSelectedShape(
                                  worldPoint - _shapeDragDelta,
                                );
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

                              if (_isDraggingShape) {
                                _isDraggingShape = false;
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
                              final hitShapeId = _hitTestShape(
                                mappedElements,
                                worldPoint,
                              );
                              _selectShape(hitShapeId, expandEditor: false);
                            },
                            onTap: () {
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
                                ),
                              ),
                            ),
                          ),

                          ..._buildImageOverlays(state),

                          _buildAllTrays(state),
                          if (state.selectedShapeId != null &&
                              !_isEditingShape &&
                              _isShapeEditTrayExpanded)
                            _buildSelectedShapePanel(state, mappedElements),
                          if (state.selectedShapeId != null &&
                              !_isEditingShape &&
                              !_isShapeEditTrayExpanded)
                            _buildShapeEditBanner(
                              Theme.of(context).brightness == Brightness.dark,
                            ),
                          if (state.selectedShapeId != null)
                            _buildShapeTransformOverlay(state, mappedElements),
                          _buildEdgeTriggers(),

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
              opacity: (data['opacity'] as num?)?.toDouble() ?? 1,
              brushType: (data['brushType'] as String?) ?? 'solid',
              data: data,
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
              isFilled: (data['isFilled'] as bool?) ?? false,
              data: data,
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
            data: data,
          );
        })
        .toList(growable: false);

    final draft = _shapeTransformDraft;

    if (draft == null && _pendingShapeEdits.isEmpty) {
      return mapped;
    }

    return mapped
        .map((element) {
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
              data: {...result.data, 'rotation': draft.rotation},
            );
          }

          return result;
        })
        .toList(growable: false);
  }

  String? _hitTestShape(List<_CanvasElement> elements, Offset position) {
    for (var i = elements.length - 1; i >= 0; i--) {
      final element = elements[i];
      // Allow selecting shapes, images, strokes, and text!
      if (element.kind == _ElementKind.stroke) {
        // Simple bounding box for strokes
        if (element.bounds != null && element.bounds!.contains(position)) {
          return element.id;
        }
      } else {
        // Shapes, images, text
        final distance = (position - element.center).distance;
        final sizeHit = element.kind == _ElementKind.shape
            ? element.size
            : 100.0;
        if (distance <= (sizeHit / 2) + 14) {
          return element.id;
        }
      }
    }
    return null;
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
    final shape =
        _shapeTransformDraft != null &&
            _shapeTransformDraft!.shapeId == baseShape.id
        ? baseShape.copyWith(
            center: _shapeTransformDraft!.center,
            size: _shapeTransformDraft!.size,
            data: {
              ...baseShape.data,
              'rotation': _shapeTransformDraft!.rotation,
            },
          )
        : baseShape;

    final center = _toScreen(shape.center);
    final size = shape.size * _viewportScale;
    final half = size / 2;
    final rotation = (shape.data['rotation'] as num?)?.toDouble() ?? 0.0;

    return Positioned(
      left: center.dx - half - 16,
      top: center.dy - half - 16,
      width: size + 32,
      height: size + 32,
      child: Transform.rotate(
        angle: rotation,
        child: IgnorePointer(
          ignoring: false,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (_) {
                    _setShapeEditing(true);
                    _shapeTransformDraft ??= _ShapeTransformDraft(
                      shapeId: shape.id,
                      center: shape.center,
                      size: shape.size,
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
                      border: Border.all(color: Colors.blueAccent, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                left: size / 2,
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
              Positioned(
                top: size / 2,
                right: -8,
                child: GestureDetector(
                  onPanStart: (_) {
                    _setShapeEditing(true);
                    _isResizingShape = true;
                    _shapeTransformDraft = _ShapeTransformDraft(
                      shapeId: shape.id,
                      center: shape.center,
                      size: shape.size,
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
                        .clamp(24.0, 420.0)
                        .toDouble();
                    setState(() {
                      _shapeTransformDraft = draft.copyWith(size: nextSize);
                    });
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
            ],
          ),
        ),
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
        MembersTray(isOpen: state.activeTray == 'members'),
        AITray(
          isOpen: state.activeTray == 'ai',
          controller: _aiPromptController,
          onAddText: _addAiTextElement,
          onUploadImage: _uploadImageToCanvas,
          onGenerateImage: _onGenerateImagePlaceholder,
          recentImages: _recentImages,
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
          brushOpacity: state.brushOpacity,
          brushType: state.brushType,
          eraserEraseEverything: state.eraserEraseEverything,
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
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < -8) _openTray('brushes');
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
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 8) _openTray('members');
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
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx > 8) _openTray('tools');
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
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx < -8) _openTray('ai');
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
            onHorizontalDragUpdate: (d) {
              if (d.delta.dx < -8) _openTray('shapes');
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

  List<Widget> _buildImageOverlays(CanvasState state) {
    final overlays = <Widget>[];
    for (final element in state.elements) {
      if (element.type != 'image') continue;
      final data = element.data as Map<String, dynamic>? ?? const {};
      final imageBase64 = (data['imageBase64'] as String?) ?? '';
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

      final cx = (data['cx'] as num?)?.toDouble() ?? 0;
      final cy = (data['cy'] as num?)?.toDouble() ?? 0;
      final width = (data['width'] as num?)?.toDouble() ?? 220;
      final height = (data['height'] as num?)?.toDouble() ?? 160;

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
  final double rotation;

  const _ShapeTransformDraft({
    required this.shapeId,
    required this.center,
    required this.size,
    required this.rotation,
  });

  _ShapeTransformDraft copyWith({
    Offset? center,
    double? size,
    double? rotation,
  }) {
    return _ShapeTransformDraft(
      shapeId: shapeId,
      center: center ?? this.center,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
    );
  }
}

enum _ElementKind { stroke, shape, text }

class _CanvasElement {
  final String id;
  final _ElementKind kind;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String brushType;
  final CanvasShapeType? shapeType;
  final Offset center;
  final double size;
  final bool isFilled;
  final String text;
  final Map<String, dynamic> data;

  Rect? get bounds {
    if (points.isEmpty) return null;
    double minX = points.first.dx;
    double minY = points.first.dy;
    double maxX = points.first.dx;
    double maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(strokeWidth + 8);
  }

  const _CanvasElement._({
    required this.id,
    required this.kind,
    this.points = const [],
    required this.color,
    this.strokeWidth = 2,
    this.opacity = 1,
    this.brushType = 'solid',
    this.shapeType,
    this.center = Offset.zero,
    this.size = 0,
    this.isFilled = false,
    this.text = '',
    this.data = const {},
  });

  factory _CanvasElement.stroke({
    required String id,
    required List<Offset> points,
    required Color color,
    required double strokeWidth,
    required double opacity,
    required String brushType,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.stroke,
      points: points,
      color: color,
      strokeWidth: strokeWidth,
      opacity: opacity,
      brushType: brushType,
      data: data,
    );
  }

  factory _CanvasElement.shape({
    required String id,
    required CanvasShapeType shapeType,
    required Offset center,
    required double size,
    required Color color,
    required double strokeWidth,
    required bool isFilled,
    required Map<String, dynamic> data,
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.shape,
      shapeType: shapeType,
      center: center,
      size: size,
      color: color,
      strokeWidth: strokeWidth,
      isFilled: isFilled,
      data: data,
    );
  }

  factory _CanvasElement.text({
    required String id,
    required Offset center,
    required String text,
    required Color color,
    Map<String, dynamic> data = const {},
  }) {
    return _CanvasElement._(
      id: id,
      kind: _ElementKind.text,
      center: center,
      text: text,
      color: color,
      data: data,
    );
  }

  _CanvasElement copyWith({
    Offset? center,
    double? size,
    Map<String, dynamic>? data,
    bool? isFilled,
  }) {
    return _CanvasElement._(
      id: id,
      kind: kind,
      points: points,
      color: color,
      strokeWidth: strokeWidth,
      opacity: opacity,
      brushType: brushType,
      shapeType: shapeType,
      center: center ?? this.center,
      size: size ?? this.size,
      isFilled: isFilled ?? this.isFilled,
      text: text,
      data: data ?? this.data,
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<_CanvasElement> elements;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final String currentBrushType;
  final String? selectedShapeId;
  final double viewportScale;
  final Offset viewportOffset;
  final bool showEraserPreview;

  const _CanvasPainter({
    required this.elements,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentBrushType,
    required this.selectedShapeId,
    required this.viewportScale,
    required this.viewportOffset,
    required this.showEraserPreview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);
    canvas.scale(viewportScale);

    for (final element in elements) {
      switch (element.kind) {
        case _ElementKind.stroke:
          _paintStroke(
            canvas,
            element.points,
            element.color,
            element.strokeWidth,
            opacity: element.opacity,
            brushType: element.brushType,
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
      if (currentBrushType != 'eraser') {
        _paintStroke(
          canvas,
          currentPoints,
          currentColor,
          currentStrokeWidth,
          opacity: 1,
          brushType: currentBrushType,
        );
      } else if (showEraserPreview) {
        _paintEraserPreview(canvas, currentPoints.last, currentStrokeWidth);
      }
    }

    canvas.restore();
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width, {
    required double opacity,
    required String brushType,
  }) {
    final effectiveWidth = brushType == 'watercolor'
        ? width * 1.25
        : brushType == 'textured'
        ? width * 0.95
        : width;
    final effectiveOpacity = brushType == 'watercolor'
        ? opacity * 0.45
        : brushType == 'textured'
        ? opacity * 0.8
        : opacity;
    final paint = Paint()
      ..color = color.withOpacity(effectiveOpacity.clamp(0, 1))
      ..strokeWidth = effectiveWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = brushType == 'watercolor'
          ? const MaskFilter.blur(BlurStyle.normal, 2.5)
          : null;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  void _paintShape(Canvas canvas, _CanvasElement element) {
    final paint = Paint()
      ..color = element.color
      ..style = element.isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = element.strokeWidth;

    final highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final c = element.center;
    final s = element.size;
    final borderRadius =
        (element.data['borderRadius'] as num?)?.toDouble() ?? 0.0;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    final rotation = (element.data['rotation'] as num?)?.toDouble() ?? 0.0;
    canvas.rotate(rotation);
    canvas.translate(-c.dx, -c.dy);

    switch (element.shapeType!) {
      case CanvasShapeType.square:
        final rect = Rect.fromCenter(center: c, width: s, height: s);
        if (borderRadius > 0) {
          final clamped = borderRadius.clamp(0.0, s / 2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(clamped)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        break;
      case CanvasShapeType.rectangle:
        final rect = Rect.fromCenter(
          center: c,
          width: s * 1.35,
          height: s * 0.8,
        );
        if (borderRadius > 0) {
          final clamped = borderRadius.clamp(
            0.0,
            math.min(rect.width, rect.height) / 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(clamped)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        break;
      case CanvasShapeType.circle:
        canvas.drawCircle(c, s / 2, paint);
        break;
      case CanvasShapeType.ellipse:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: s * 1.3, height: s * 0.85),
          paint,
        );
        break;
      case CanvasShapeType.triangle:
        final p = Path()
          ..moveTo(c.dx, c.dy - s / 2)
          ..lineTo(c.dx - s / 2, c.dy + s / 2)
          ..lineTo(c.dx + s / 2, c.dy + s / 2)
          ..close();
        canvas.drawPath(p, paint);
        break;
      case CanvasShapeType.diamond:
        final p = Path()
          ..moveTo(c.dx, c.dy - s / 2)
          ..lineTo(c.dx - s / 2, c.dy)
          ..lineTo(c.dx, c.dy + s / 2)
          ..lineTo(c.dx + s / 2, c.dy)
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
      case CanvasShapeType.hexagon:
        final p = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (math.pi / 2) + i * (2 * math.pi / 6);
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
      case CanvasShapeType.semicircle:
        final rect = Rect.fromCenter(center: c, width: s, height: s);
        canvas.drawArc(rect, math.pi, math.pi, true, paint);
        break;
    }

    if (selectedShapeId == element.id) {
      canvas.drawCircle(c, (s / 2) + 10, highlightPaint);
    }

    canvas.restore();
  }

  void _paintEraserPreview(Canvas canvas, Offset position, double radius) {
    final previewPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(position, radius, previewPaint);
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
        oldDelegate.currentStrokeWidth != currentStrokeWidth ||
        oldDelegate.currentBrushType != currentBrushType ||
        oldDelegate.selectedShapeId != selectedShapeId ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.viewportOffset != viewportOffset;
  }
}
