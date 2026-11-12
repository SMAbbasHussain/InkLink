import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_snackbar.dart';

import '../../../domain/models/board.dart';
import '../../../domain/services/history/board_history_service.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/view/board_settings_route.dart';
import '../../dashboard/view/board_edit_requests_screen.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../bloc/canvas_bloc.dart';
import '../models/canvas_tool_mode.dart';
import 'media_editor_screen.dart';
import 'trays/ai_tray.dart';
import 'trays/brush_tray.dart';
import 'trays/canvas_shape_type.dart';
import 'trays/members_tray.dart';
import 'trays/history_tray.dart';
import 'trays/shapes_tray.dart';
import 'trays/tools_tray.dart';
import 'widgets/history_preview_banner.dart';
import 'widgets/revert_review_sheet.dart';
import 'widgets/undo_request_sheet.dart';
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

class _CanvasScreenState extends State<CanvasScreen> with WidgetsBindingObserver {
  final TextEditingController _aiPromptController = TextEditingController();
  final GlobalKey _canvasPreviewKey = GlobalKey();
  bool _savingPreview = false;
  bool _isDraggingShape = false;
  bool _isDraggingStroke = false;
  bool _isDrawingShape = false;
  List<Offset>? _strokeDragOriginalPoints;
  Offset? _strokeDragDelta;
  Offset _strokeDragStartWorldPoint = Offset.zero;
  bool _isEditingShape = false;
  bool _isShapeEditTrayExpanded = false;
  bool _isStrokeEditExpanded = false;
  bool _smoothDoodlesEnabled = false;
  bool _isRotatingShape = false;
  double _rotationPrevTouchAngle = 0.0;
  double _rotationCurrentAngle = 0.0;
  bool _isResizingShape = false;
  Offset _overlayDragStartGlobalPos = Offset.zero;
  Offset _overlayDragStartCenter = Offset.zero;
  Offset _resizeStartGlobalPos = Offset.zero;
  double _resizeStartSize = 64.0;
  double _resizeStartWidth = 64.0;
  double _resizeStartHeight = 64.0;
  double _resizeStartRotation = 0.0;
  String? _rewiringConnectorId;
  bool? _rewireIsStart;
  Offset? _rewireScreenPoint;
  String? _rewireTargetId;
  Offset? _connectorDragDelta;
  bool _showEraserPreview = false;
  bool _isTransformingCanvas = false;
  bool _didAutoFrameContent = false;
  Size _lastCanvasSize = Size.zero;
  Offset _shapeDragStartCenter = Offset.zero;
  Offset _shapeDragStartWorldPoint = Offset.zero;
  Offset? _shapeDragPreviewCenter;
  _ShapeTransformDraft? _shapeTransformDraft;
  double _viewportScale = 1.0;
  Offset _viewportOffset = Offset.zero;
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;
  final List<Uint8List> _recentImages = <Uint8List>[];
  Map<String, ui.Image> _decodedUiImages = <String, ui.Image>{};
  final Map<String, String> _decodedUiImageKeys = <String, String>{};
  final Set<String> _pendingDecodeImageIds = <String>{};
  late final CanvasBloc _canvasBloc;
  Timer? _shapeEditDebounceTimer;
  final Map<String, dynamic> _pendingShapeEdits = <String, dynamic>{};
  Offset? _lastTapWorldPoint;
  String? _arrowConnectStartElementId;

  static const double _viewportComparisonEpsilon = 0.01;

  InkTokens get _tokens => context.ink;
  bool _preventGestureBack = true;
  bool _showEdgeTrayButtons = true;
  DateTime? _lastEdgeDragTime;
  DateTime? _lastBackSnackbarTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _canvasBloc = context.read<CanvasBloc>();
    _maybeShowTrayTipsOverlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive) {
      _savePreview();
    }
  }

  Future<void> _maybeShowTrayTipsOverlay() async {
    if (!widget.showTrayTipsOnEntry) return;

    final showTips = await TrayTipsPreferences.checkShowTrayTips();
    if (!mounted || !showTips) return;
    _canvasBloc.add(const CanvasShowTrayTips());
  }

  void _openTray(String tray) {
    if (_canvasBloc.state.activeTray == tray) return;
    HapticFeedback.lightImpact();
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  void _toggleTray(String tray) {
    HapticFeedback.lightImpact();
    if (tray == 'history' && _canvasBloc.state.activeTray != 'history') {
      _canvasBloc.add(const CanvasHistoryFeedRequested());
    }
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  Future<void> _restoreHistoryVersion(CanvasState state) async {
    final version = state.historyPreviewVersion;
    if (version == null) return;
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Restore version $version?',
      message:
          'This reverts every change made after version $version. Nothing is '
          'deleted from history — you can restore to another version later.',
      confirmLabel: 'Restore',
      destructive: false,
    );
    if (!mounted || !confirmed) return;
    _canvasBloc.add(CanvasHistoryRestoreRequested(version));
  }

  void _openUndoRequestSheet() {
    final service = context.read<BoardHistoryService>();
    showUndoRequestSheet(
      context,
      service: service,
      boardId: widget.boardId,
      elements: _canvasBloc.state.elements,
    );
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
    setState(() {
      _pendingShapeEdits['size'] = size;
    });
    _canvasBloc.add(
      CanvasPreviewPendingShapeEdits(
        shapeId: _canvasBloc.state.selectedShapeId ?? '',
        pendingData: Map<String, dynamic>.from(_pendingShapeEdits),
      ),
    );
    _scheduleShapeEditCommit();
  }

  void _deferredSetSelectedShapeFill(bool isFilled) {
    setState(() {
      _pendingShapeEdits['isFilled'] = isFilled;
    });
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
    setState(() {
      _pendingShapeEdits['rotation'] = rotation;
    });
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
    AppSnackBar.showMessage(
      context,
      'AI image generation is coming soon.',
    );
  }

  Future<void> _uploadImageToCanvas([ImageSource? directSource]) async {
    final ImageSource? source;
    if (directSource != null) {
      source = directSource;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        elevation: 0,
        builder: (ctx) {
          final tokens = ctx.ink;
          Widget option(IconData icon, String title, String subtitle, ImageSource src) {
            return Material(
              color: tokens.field,
              borderRadius: BorderRadius.circular(InkRadii.input),
              child: InkWell(
                borderRadius: BorderRadius.circular(InkRadii.input),
                onTap: () => Navigator.pop(ctx, src),
                child: Padding(
                  padding: const EdgeInsets.all(InkSpacing.s12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tokens.accentSoft,
                          borderRadius: BorderRadius.circular(InkRadii.chip + 2),
                        ),
                        child: Icon(icon, size: 20, color: tokens.accentText),
                      ),
                      const SizedBox(width: InkSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: InkType.bodyStrong(tokens.ink)),
                            Text(subtitle, style: InkType.caption(tokens.inkMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.s12),
              child: GlassPanel(
                radius: InkRadii.bottomSheet,
                padding: const EdgeInsets.all(InkSpacing.s20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insert Image', style: InkType.title(tokens.ink)),
                    const SizedBox(height: InkSpacing.s16),
                    option(
                      LucideIcons.camera,
                      'Take Photo with Camera',
                      'Capture a picture and place onto canvas',
                      ImageSource.camera,
                    ),
                    const SizedBox(height: InkSpacing.s8),
                    option(
                      LucideIcons.image,
                      'Choose from Gallery',
                      'Pick an existing photo or graphic',
                      ImageSource.gallery,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

      AppSnackBar.showError(
        context,
        message,
        action: isNoCamera
            ? SnackBarAction(
                label: 'Choose Gallery',
                textColor: Colors.white,
                onPressed: () => _uploadImageToCanvas(ImageSource.gallery),
              )
            : null,
      );
      return;
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        AppErrorFormatter.cleanMessage(
          e,
          fallback: 'Failed to pick image. Please try again.',
        ),
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

  void _syncDecodedUiImages(List<CanvasElement> elements) {
    final activeImages = elements.whereType<ImageElement>().toList();
    final activeIds = activeImages.map((element) => element.id).toSet();

    final removedIds =
        _decodedUiImages.keys.where((id) => !activeIds.contains(id)).toList();
    if (removedIds.isNotEmpty) {
      final nextMap = Map<String, ui.Image>.from(_decodedUiImages);
      for (final id in removedIds) {
        nextMap[id]?.dispose();
        nextMap.remove(id);
        _decodedUiImageKeys.remove(id);
        _pendingDecodeImageIds.remove(id);
      }
      _decodedUiImages = nextMap;
    }

    for (final element in activeImages) {
      final base64Str = element.imageBase64;
      if (base64Str.isEmpty) continue;
      final key = '${base64Str.length}:${base64Str.hashCode}';
      if (_decodedUiImages.containsKey(element.id) &&
          _decodedUiImageKeys[element.id] == key) {
        continue;
      }
      if (_pendingDecodeImageIds.contains(element.id)) {
        continue;
      }
      _pendingDecodeImageIds.add(element.id);
      _decodeUiImage(element.id, base64Str, key);
    }
  }

  Future<void> _decodeUiImage(String id, String base64Str, String key) async {
    try {
      final cleanBase64 = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64)) return;
      final bytes = base64Decode(cleanBase64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final nextMap = Map<String, ui.Image>.from(_decodedUiImages);
      final oldImage = nextMap[id];
      nextMap[id] = frame.image;
      _decodedUiImages = nextMap;
      _decodedUiImageKeys[id] = key;
      oldImage?.dispose();
      setState(() {});
    } catch (_) {
      // Decode error fallback handled by canvas placeholder
    } finally {
      _pendingDecodeImageIds.remove(id);
    }
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
      AppSnackBar.showMessage(
        context,
        'No canvas content to fit yet.',
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

  Future<void> _clearAll() async {
    if (_canvasBloc.state.currentUserRole != Board.roleOwner) return;
    final confirmed = await showInkConfirmDialog(
      context,
      title: 'Clear entire canvas?',
      message:
          'This will permanently delete all strokes, shapes, and notes on this board for everyone.',
      confirmLabel: 'Clear All',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    _canvasBloc.add(const CanvasClearAll());
    AppSnackBar.showSuccess(context, 'Canvas cleared.');
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
        builder: (ctx, setDialogState) => InkDialog(
          title: 'Add Sticky Note',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkTextField(
                controller: textController,
                maxLines: 4,
                autofocus: true,
                hintText: 'Write note content here...',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: InkType.label(_tokens.ink)),
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
                          color: isSelected ? _tokens.accent : _tokens.inkMuted.withValues(alpha: 0.4),
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
            InkButton.secondary(
              label: 'Cancel',
              expand: false,
              compact: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            InkButton.primary(
              label: 'Add to Canvas',
              expand: false,
              compact: true,
              onPressed: () => Navigator.pop(ctx, true),
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
        builder: (ctx, setDialogState) => InkDialog(
          title: 'Edit Sticky Note',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkTextField(
                controller: textController,
                maxLines: 4,
                autofocus: true,
                hintText: 'Note content...',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: InkType.label(_tokens.ink)),
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
                          color: isSelected ? _tokens.accent : _tokens.inkMuted.withValues(alpha: 0.4),
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
            InkButton.secondary(
              label: 'Cancel',
              expand: false,
              compact: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            InkButton.primary(
              label: 'Save',
              expand: false,
              compact: true,
              onPressed: () => Navigator.pop(ctx, true),
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
        builder: (ctx, setDialogState) => InkDialog(
          title: 'Add Connector / Diagram Link',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Line Style', style: InkType.label(_tokens.ink)),
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
                SwitchListTile.adaptive(
                  activeColor: _tokens.accent,
                  title: const Text('Arrowhead End'),
                  value: hasArrowhead,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    setDialogState(() => hasArrowhead = v);
                  },
                ),
                if (linkable.length >= 2) ...[
                  const SizedBox(height: 12),
                  Text('Connect Shapes', style: InkType.label(_tokens.ink)),
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
                      Icon(LucideIcons.arrowRight, size: 16, color: _tokens.inkMuted),
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
            InkButton.secondary(
              label: 'Cancel',
              expand: false,
              compact: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            InkButton.primary(
              label: 'Add Connector',
              expand: false,
              compact: true,
              onPressed: () => Navigator.pop(ctx, true),
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
      Uint8List? bytes;

      final boundary =
          _canvasPreviewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary != null) {
        if (boundary.debugNeedsPaint) {
          await WidgetsBinding.instance.endOfFrame;
        }

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

        try {
          final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          bytes = byteData?.buffer.asUint8List();
        } catch (e) {
          developer.log('boundary.toImage error: $e', name: 'CanvasScreen');
        }
      }

      // Robust fallback: if boundary capture failed or produced empty bytes,
      // and canvas elements exist, render offscreen using BoardExportServiceImpl.
      if ((bytes == null || bytes.isEmpty) &&
          _canvasBloc.state.elements.isNotEmpty) {
        try {
          bytes = await const BoardExportServiceImpl().renderToPng(
            _canvasBloc.state.elements,
            scale: 0.5,
          );
        } catch (e) {
          developer.log('Fallback renderToPng error: $e', name: 'CanvasScreen');
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        if (mounted) {
          _canvasBloc.add(CanvasSaveBoardPreviewRequested(bytes));
        }
      }
    } catch (e) {
      developer.log('Failed to save board preview: $e', name: 'CanvasScreen');
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        final tokens = sheetContext.ink;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(InkSpacing.s12),
            child: GlassPanel(
              radius: InkRadii.bottomSheet,
              padding: const EdgeInsets.all(InkSpacing.s20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Export & Share Board',
                          style: InkType.title(tokens.ink),
                        ),
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.x, color: tokens.inkSecondary),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: InkSpacing.s4),
                  Text(
                    'Export your canvas elements with full layout integrity:',
                    style: InkType.caption(tokens.inkMuted),
                  ),
                  const SizedBox(height: InkSpacing.s16),
                  _buildExportTile(
                    sheetContext,
                    icon: LucideIcons.image,
                    iconColor: tokens.accentText,
                    title: 'PNG Image',
                    subtitle: 'High-resolution lossless raster export (2x scale)',
                    format: BoardExportFormat.png,
                  ),
                  const SizedBox(height: InkSpacing.s8),
                  _buildExportTile(
                    sheetContext,
                    icon: LucideIcons.fileText,
                    iconColor: tokens.danger,
                    title: 'PDF Document',
                    subtitle: 'Printable formatted document with metadata header',
                    format: BoardExportFormat.pdf,
                  ),
                  const SizedBox(height: InkSpacing.s8),
                  _buildExportTile(
                    sheetContext,
                    icon: LucideIcons.code,
                    iconColor: tokens.success,
                    title: 'SVG Vector File',
                    subtitle:
                        'Scalable vector graphics compatible with Figma & Illustrator',
                    format: BoardExportFormat.svg,
                  ),
                  const SizedBox(height: InkSpacing.s16),
                  InkButton.hero(
                    label: 'Share Board File (Native Sheet)',
                    icon: const Icon(LucideIcons.share2),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _canvasBloc.add(
                        CanvasExportBoardRequested(
                          format: BoardExportFormat.png,
                          shareAfterExport: true,
                          sharePositionOrigin: _shareAnchorRect(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _runExport(
    BuildContext sheetContext,
    BoardExportFormat format, {
    required bool share,
  }) {
    Navigator.pop(sheetContext);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          share
              ? 'Preparing ${format.name.toUpperCase()} for sharing...'
              : 'Saving ${format.name.toUpperCase()} to device storage...',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    _canvasBloc.add(
      CanvasExportBoardRequested(
        format: format,
        shareAfterExport: share,
        sharePositionOrigin: share ? _shareAnchorRect() : null,
      ),
    );
  }

  /// Global rect used to anchor the native share popover. iPad/Mac require it;
  /// without one the share sheet refuses to present.
  Rect? _shareAnchorRect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Widget _buildExportTile(
    BuildContext sheetContext, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required BoardExportFormat format,
  }) {
    final tokens = sheetContext.ink;
    return Material(
      color: tokens.field,
      borderRadius: BorderRadius.circular(InkRadii.input),
      child: InkWell(
        borderRadius: BorderRadius.circular(InkRadii.input),
        onTap: () => _runExport(sheetContext, format, share: false),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.s12,
            vertical: InkSpacing.s8,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(InkRadii.chip + 2),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: InkSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: InkType.bodyStrong(tokens.ink)),
                    Text(subtitle, style: InkType.caption(tokens.inkMuted)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.download, size: 20, color: tokens.inkSecondary),
                tooltip: 'Save to Device Storage',
                onPressed: () => _runExport(sheetContext, format, share: false),
              ),
              IconButton(
                icon: Icon(LucideIcons.share2, size: 20, color: tokens.inkSecondary),
                tooltip: 'Share via...',
                onPressed: () => _runExport(sheetContext, format, share: true),
              ),
            ],
          ),
        ),
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
            final boardTitle = state.boardTitle ?? 'InkLink Board';
            AppSnackBar.showSuccess(
              context,
              msg,
              action: path != null
                  ? SnackBarAction(
                      label: 'Share',
                      textColor: Colors.white,
                      onPressed: () async {
                        try {
                          final file = File(path);
                          if (await file.exists()) {
                            final mimeType = path.endsWith('.pdf')
                                ? 'application/pdf'
                                : path.endsWith('.svg')
                                    ? 'image/svg+xml'
                                    : 'image/png';
                            await SharePlus.instance.share(
                              ShareParams(
                                files: [XFile(file.path, mimeType: mimeType)],
                                subject: boardTitle,
                                title: boardTitle,
                              ),
                            );
                          }
                        } catch (e) {
                          developer.log('Failed to share exported file: $e', name: 'CanvasScreen');
                        }
                      },
                    )
                  : null,
            );
            context.read<CanvasBloc>().add(const CanvasConsumeExportMessage());
          }

          if (state.infoMessage != null) {
            AppSnackBar.showSuccess(context, state.infoMessage!);
            context.read<CanvasBloc>().add(const CanvasConsumeInfoMessage());
          }

          final rawError = state.error;
          if (rawError == null || rawError.isEmpty) return;
          final message = AppErrorFormatter.cleanMessage(rawError);

          final isViewerWarning = message.toLowerCase().contains(
            'you are a viewer',
          );

          if (isViewerWarning) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 16,
                      color: _tokens.pending,
                    ),
                    const SizedBox(width: InkSpacing.s8),
                    Flexible(
                      child: Text(
                        message,
                        style: TextStyle(color: _tokens.ink),
                      ),
                    ),
                  ],
                ),
                backgroundColor: _tokens.paper,
                action: SnackBarAction(
                  label: 'Request Edit',
                  textColor: _tokens.accent,
                  onPressed: () => _showRequestEditDialog(context),
                ),
                duration: AppSnackBar.defaultDuration,
              ),
              duration: AppSnackBar.defaultDuration,
            );
          } else {
            AppSnackBar.showError(context, message);
          }

          if (message.contains('no longer available') ||
              message.contains('access lost')) {
            await _exitCanvas();
          }
        },
        child: BlocBuilder<CanvasBloc, CanvasState>(
          builder: (context, state) {
            final displayElements = state.isViewingHistory
                ? state.historyPreviewElements
                : state.elements;
            _syncDecodedUiImages(displayElements);
            final mappedElements = _mapElements(displayElements);
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
                    ? const Color(0xFF121418)
                    : _tokens.surfaceDesk,
                resizeToAvoidBottomInset: false,

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

                              // The eraser always erases: it must not be
                              // diverted into connecting, drawing a shape, or
                              // dragging a selected element.
                              if (state.brushType == 'eraser') {
                                _isDraggingShape = false;
                                _isDraggingStroke = false;
                                _showEraserPreview = true;
                                _startStroke(worldPoint);
                                return;
                              }

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
                                _isDrawingShape = true;
                                _canvasBloc.add(CanvasStartShapeDraw(worldPoint));
                                return;
                              }

                              // Handle shape drawing mode
                              if (state.currentToolMode == CanvasToolMode.shape &&
                                  state.pendingShapeType != null) {
                                _isDrawingShape = true;
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
                                _connectorDragDelta =
                                    hit.kind == _ElementKind.connector
                                    ? Offset.zero
                                    : null;
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
                              if (_isDrawingShape || state.isDrawingShape) {
                                final worldPoint = _toWorld(
                                  details.localFocalPoint,
                                );
                                _canvasBloc.add(CanvasUpdateShapeDraw(worldPoint));
                                return;
                              }

                              final worldPoint = _toWorld(
                                details.localFocalPoint,
                              );
                              if (state.brushType == 'eraser') {
                                // Erase even while an element is selected.
                                _showEraserPreview = true;
                                _appendStroke(worldPoint);
                                return;
                              }
                              if (_isDraggingStroke) {
                                final delta =
                                    worldPoint - _strokeDragStartWorldPoint;
                                setState(() {
                                  _strokeDragDelta = delta;
                                });
                                return;
                              }

                              if (_isDraggingShape) {
                                final dragDelta =
                                    worldPoint - _shapeDragStartWorldPoint;
                                final nextCenter =
                                    _shapeDragStartCenter + dragDelta;
                                setState(() {
                                  _shapeDragPreviewCenter = nextCenter;
                                  _connectorDragDelta = dragDelta;
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
                              _showEraserPreview = false;
                              _appendStroke(worldPoint);
                            },
                            onScaleEnd: (_) {
                              if (_isTransformingCanvas) {
                                _isTransformingCanvas = false;
                                return;
                              }

                              // End shape drawing
                              if (_isDrawingShape || state.isDrawingShape) {
                                _isDrawingShape = false;
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
                                _connectorDragDelta = null;
                                _shapeDragStartCenter = Offset.zero;
                                _shapeDragStartWorldPoint = Offset.zero;
                                _setShapeEditing(false);
                                return;
                              }
                              if (_isRotatingShape || _isResizingShape) {
                                _isRotatingShape = false;
                                _rotationPrevTouchAngle = 0.0;
                                _rotationCurrentAngle = 0.0;
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
                                  decodedImages: _decodedUiImages,
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
                                  accentColor: _tokens.accent,
                                  remoteEraserCursors:
                                      _canvasBloc.remoteEraserCursors,
                                  arrowConnectStartElementId:
                                      _isArrowMode(state)
                                          ? _arrowConnectStartElementId
                                          : null,
                                ),
                              ),
                            ),
                          ),

                          ..._buildPinnedCommentPins(state),

                          _buildEdgeTriggers(state, isDark),
                          if (state.selectedShapeId != null)
                            _buildSelectionOutline(state, mappedElements),
                          _buildAllTrays(state),
                          _buildHistoryPlanListener(),
                          _buildUndoConflictListener(),
                          if (state.isViewingHistory)
                            HistoryPreviewBanner(
                              version: state.historyPreviewVersion,
                              onRestore: () => _restoreHistoryVersion(state),
                              onExit: () => _canvasBloc.add(
                                const CanvasHistoryPreviewExited(),
                              ),
                            ),
                          const BoardChatDrawer(),
                          const CommentsTray(),
                          const VoiceCallHud(),
                          if (state.selectedShapeId != null)
                            _buildSelectedElementPanel(
                              state,
                              mappedElements,
                            ),
                          _buildTopPills(state, title),

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
                width: e.width,
                height: e.height,
              ),
            ImageElement e => _CanvasElement.image(
                id: e.id,
                z: e.z,
                center: e.center,
                width: e.width,
                height: e.height,
                imageBase64: e.imageBase64,
                data: const {},
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
                data: {'rotation': e.rotation},
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
                data: const {},
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
        // Resolve exactly like the painter so the tappable line matches the
        // drawn line, including its anchor on each attached element.
        final startRaw = _resolveConnectorEnd(
          elements,
          elementId: element.startElementId,
          anchor: 'center',
          fallback: element.startPoint,
        );
        final endRaw = _resolveConnectorEnd(
          elements,
          elementId: element.endElementId,
          anchor: 'center',
          fallback: element.endPoint,
        );
        final start = _resolveConnectorEnd(
          elements,
          elementId: element.startElementId,
          anchor: element.startAnchor,
          fallback: element.startPoint,
          towards: endRaw,
        );
        final end = _resolveConnectorEnd(
          elements,
          elementId: element.endElementId,
          anchor: element.endAnchor,
          fallback: element.endPoint,
          towards: startRaw,
        );
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
      } else if (element.kind == _ElementKind.image ||
          element.kind == _ElementKind.stickyNote) {
        final halfW = (element.width > 0 ? element.width : 160.0) / 2 + 8.0;
        final halfH = (element.height > 0 ? element.height : 160.0) / 2 + 8.0;
        final dx = (position.dx - element.center.dx).abs();
        final dy = (position.dy - element.center.dy).abs();
        if (dx <= halfW && dy <= halfH) {
          return element.id;
        }
      } else {
        // Shapes, text
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

  Widget _buildSelectedElementPanel(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    final selected = mappedElements.where((e) => e.id == state.selectedShapeId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final element = selected.first;
    if (element.kind == _ElementKind.connector) {
      return const SizedBox.shrink();
    }
    if (element.kind == _ElementKind.image) {
      return const SizedBox.shrink();
    }
    if (element.kind == _ElementKind.stroke) {
      return Stack(
        children: [
          if (!_isEditingShape && _isStrokeEditExpanded)
            _buildSelectedStrokePanel(state, element),
          if (!_isEditingShape && !_isStrokeEditExpanded)
            _buildStrokeEditBanner(),
        ],
      );
    }
    if (element.kind == _ElementKind.stickyNote) {
      return Stack(
        children: [
          if (!_isEditingShape)
            _buildStickyNoteEditBanner(
              Theme.of(context).brightness == Brightness.dark,
              element,
            ),
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
      ],
    );
  }

  /// Outline and transform handles of the selected element. Kept below the
  /// trays so an open tray always covers the selection rather than the
  /// selection drawing over the tray.
  Widget _buildSelectionOutline(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    final selected = mappedElements.where((e) => e.id == state.selectedShapeId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final element = selected.first;
    if (element.kind == _ElementKind.stroke) {
      return _buildStrokeSelectionOverlay(state, element);
    }
    if (element.kind == _ElementKind.connector) {
      return _buildConnectorSelectionOverlay(element, mappedElements);
    }
    return _buildShapeTransformOverlay(state, mappedElements);
  }

  Widget _buildStickyNoteEditBanner(bool isDark, _CanvasElement element) {
    final tokens = context.ink;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24 + MediaQuery.of(context).padding.bottom,
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () => _editStickyNote(element),
          icon: Icon(
            LucideIcons.pencil,
            size: 18,
            color: tokens.ink,
          ),
          label: Text(
            'Edit Note',
            style: TextStyle(
              color: tokens.ink,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.paper,
            foregroundColor: tokens.ink,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorSelectionOverlay(
    _CanvasElement element,
    List<_CanvasElement> mappedElements,
  ) {
    final startRaw = _resolveConnectorEnd(
      mappedElements,
      elementId: element.startElementId,
      anchor: 'center',
      fallback: element.startPoint,
    );
    final endRaw = _resolveConnectorEnd(
      mappedElements,
      elementId: element.endElementId,
      anchor: 'center',
      fallback: element.endPoint,
    );
    var start = _resolveConnectorEnd(
      mappedElements,
      elementId: element.startElementId,
      anchor: element.startAnchor,
      fallback: element.startPoint,
      towards: endRaw,
    );
    var end = _resolveConnectorEnd(
      mappedElements,
      elementId: element.endElementId,
      anchor: element.endAnchor,
      fallback: element.endPoint,
      towards: startRaw,
    );

    final isRewiring = _rewiringConnectorId == element.id;
    final dragDelta = _connectorDragDelta;
    if (!isRewiring && dragDelta != null) {
      // Only the detached ends follow the drag; attached ends stay pinned.
      if (element.startElementId == null) start += dragDelta;
      if (element.endElementId == null) end += dragDelta;
    }

    final screenStart = _toScreen(start);
    final screenEnd = _toScreen(end);
    var previewStart = screenStart;
    var previewEnd = screenEnd;
    final rewirePoint = _rewireScreenPoint;
    if (isRewiring && rewirePoint != null) {
      if (_rewireIsStart ?? false) {
        previewStart = rewirePoint;
      } else {
        previewEnd = rewirePoint;
      }
    }

    Rect? highlight;
    final targetId = _rewireTargetId;
    if (isRewiring && targetId != null) {
      final target = _canvasBloc.state.elements
          .where((e) => e.id == targetId)
          .firstOrNull;
      if (target != null) {
        final worldRect = _elementLinkBounds(target);
        final topLeft = _toScreen(worldRect.topLeft);
        final bottomRight = _toScreen(worldRect.bottomRight);
        highlight = Rect.fromLTRB(
          topLeft.dx - 4,
          topLeft.dy - 4,
          bottomRight.dx + 4,
          bottomRight.dy + 4,
        );
      }
    }

    final screenMid = Offset(
      (screenStart.dx + screenEnd.dx) / 2,
      (screenStart.dy + screenEnd.dy) / 2,
    );

    Widget handle(Offset point, bool isStart) {
      final active = isRewiring && (_rewireIsStart ?? false) == isStart;
      return Positioned(
        left: point.dx - 22,
        top: point.dy - 22,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _beginConnectorRewire(element.id, isStart, point),
          onPanUpdate: (details) => _updateConnectorRewire(
            (_rewireScreenPoint ?? point) + details.delta,
          ),
          onPanCancel: _cancelConnectorRewire,
          onPanEnd: (_) => _finishConnectorRewire(element.id),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: active ? 26 : 20,
                height: active ? 26 : 20,
                decoration: BoxDecoration(
                  color: active ? _tokens.accent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? Colors.white : _tokens.accent,
                    width: 2,
                  ),
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
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isRewiring || dragDelta != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConnectorPreviewPainter(
                  start: previewStart,
                  end: previewEnd,
                  color: _tokens.accent,
                  strokeWidth: math.max(element.strokeWidth, 2),
                  highlight: highlight,
                ),
              ),
            ),
          ),
        handle(screenStart, true),
        handle(screenEnd, false),
        Positioned(
          left: screenMid.dx - 14,
          top: screenMid.dy - 36,
          child: GestureDetector(
            onTap: () => _canvasBloc.add(CanvasDeleteElement(element.id)),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _tokens.danger,
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
              child: const Icon(LucideIcons.trash2, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _beginConnectorRewire(
    String connectorId,
    bool isStart,
    Offset screenPoint,
  ) {
    setState(() {
      _rewiringConnectorId = connectorId;
      _rewireIsStart = isStart;
      _rewireScreenPoint = screenPoint;
      _rewireTargetId = null;
    });
  }

  void _updateConnectorRewire(Offset screenPoint) {
    final connectorId = _rewiringConnectorId;
    if (connectorId == null) return;
    final target = _hitTestConnectorTarget(
      _toWorld(screenPoint),
      connectorId,
      isStart: _rewireIsStart ?? true,
    );
    setState(() {
      _rewireScreenPoint = screenPoint;
      _rewireTargetId = target?.id;
    });
  }

  void _finishConnectorRewire(String connectorId) {
    final screenPoint = _rewireScreenPoint;
    final isStart = _rewireIsStart ?? true;
    if (screenPoint == null) {
      _cancelConnectorRewire();
      return;
    }
    final world = _toWorld(screenPoint);
    final target = _hitTestConnectorTarget(world, connectorId, isStart: isStart);
    _canvasBloc.add(
      CanvasRewireConnector(
        connectorId: connectorId,
        isStart: isStart,
        targetElementId: target?.id,
        anchor: target == null ? 'center' : 'auto',
        point: target == null ? world : _getElementWorldCenter(target),
      ),
    );
    _cancelConnectorRewire();
  }

  void _cancelConnectorRewire() {
    if (!mounted) return;
    setState(() {
      _rewiringConnectorId = null;
      _rewireIsStart = null;
      _rewireScreenPoint = null;
      _rewireTargetId = null;
    });
  }

  /// Element a connector end can snap to, ignoring the connector itself, its
  /// other end and everything that cannot own an anchor (doodles, connectors).
  CanvasElement? _hitTestConnectorTarget(
    Offset worldPoint,
    String connectorId, {
    required bool isStart,
  }) {
    final elements = _canvasBloc.state.elements;
    String? otherEndId;
    for (final element in elements) {
      if (element.id == connectorId && element is ConnectorElement) {
        otherEndId = isStart ? element.endElementId : element.startElementId;
        break;
      }
    }
    for (var i = elements.length - 1; i >= 0; i--) {
      final element = elements[i];
      if (element.id == connectorId ||
          element.id == otherEndId ||
          element is ConnectorElement ||
          element is StrokeElement) {
        continue;
      }
      if (_elementLinkBounds(element).inflate(18).contains(worldPoint)) {
        return element;
      }
    }
    return null;
  }

  /// World-space box a connector end snaps to, matching the bounds the painter
  /// uses to resolve anchors.
  Rect _elementLinkBounds(CanvasElement element) {
    return switch (element) {
      ShapeElement e => Rect.fromCenter(
        center: e.center,
        width: e.size *
            (e.shapeType == CanvasShapeType.rectangle ? 1.35 : 1.1),
        height: e.size *
            (e.shapeType == CanvasShapeType.rectangle ? 0.8 : 1.1),
      ),
      StickyNoteElement e => Rect.fromCenter(
        center: e.center,
        width: e.width > 0 ? e.width : 160,
        height: e.height > 0 ? e.height : 160,
      ),
      ImageElement e => Rect.fromCenter(
        center: e.center,
        width: e.width,
        height: e.height,
      ),
      TextElement e => Rect.fromCenter(
        center: e.center,
        width: e.width > 0 ? e.width : 180,
        height: e.height > 0 ? e.height : 48,
      ),
      StrokeElement e => Rect.fromCenter(
        center: _strokeCenter(e.points),
        width: 1,
        height: 1,
      ),
      ConnectorElement e => Rect.fromPoints(e.startPoint, e.endPoint),
    };
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
                      Border.all(color: _tokens.accent, width: 1.5),
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
                  color: _tokens.danger,
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
                child: const Icon(LucideIcons.trash2, size: 14,
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
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12 + bottomInset,
      child: Center(
        child: Material(
          color: const Color(0xD91F2229),
          borderRadius: BorderRadius.circular(InkRadii.glassBar),
          child: InkWell(
            borderRadius: BorderRadius.circular(InkRadii.glassBar),
            onTap: () {
              setState(() {
                _isStrokeEditExpanded = true;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.penLine, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Edit Doodle', style: TextStyle(color: Colors.white)),
                ],
              ),
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
          color: _tokens.paper,
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
                            icon: Icon(LucideIcons.trash2, size: 18,
                                color: _tokens.danger),
                            splashRadius: 16,
                            tooltip: 'Delete',
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isStrokeEditExpanded = false;
                              });
                            },
                            icon: Icon(LucideIcons.chevronDown, size: 18, color: _tokens.inkMuted),
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
                        onChanged: (v) => _canvasBloc.add(
                          CanvasUpdateSelectedStrokeWidth(v),
                        ),
                      ),
                      Text(
                        '${state.selectedStrokeWidth.toStringAsFixed(0)} px',
                        style: TextStyle(fontSize: 11, color: _tokens.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      _buildSectionLabel('Opacity'),
                      Slider(
                        value: state.selectedStrokeOpacity.clamp(0, 1),
                        min: 0,
                        max: 1,
                        onChanged: (v) => _canvasBloc.add(
                          CanvasUpdateSelectedStrokeOpacity(v),
                        ),
                      ),
                      Text(
                        '${(state.selectedStrokeOpacity * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: _tokens.inkMuted),
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
                                      ? const Icon(LucideIcons.check,
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
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: _tokens.ink,
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
          color: _tokens.paper,
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
                        icon: Icon(LucideIcons.chevronDown, size: 18, color: _tokens.inkMuted),
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
                        icon: Icon(LucideIcons.trash2, size: 18, color: _tokens.danger),
                        splashRadius: 16,
                        tooltip: 'Delete',
                      ),
                      IconButton(
                        onPressed: () {
                          _commitPendingShapeEdits();
                          _selectShape(null);
                        },
                        icon: Icon(LucideIcons.x, size: 18, color: _tokens.inkMuted),
                        splashRadius: 16,
                        tooltip: 'Deselect shape',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    activeColor: _tokens.accent,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: (_pendingShapeEdits['isFilled'] as bool?) ??
                        state.selectedShapeIsFilled,
                    title: const Text('Filled', style: TextStyle(fontSize: 13)),
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      _deferredSetSelectedShapeFill(v);
                    },
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
                  Builder(
                    builder: (context) {
                      final rawRotation =
                          (_pendingShapeEdits['rotation'] as num?)
                              ?.toDouble() ??
                          state.selectedShapeRotation;
                      final effectiveRotation =
                          (rawRotation % (math.pi * 2) + (math.pi * 2)) %
                          (math.pi * 2);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rotation ${(effectiveRotation * 180 / math.pi).toStringAsFixed(0)}°',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Slider(
                            value: effectiveRotation.clamp(0.0, math.pi * 2),
                            min: 0,
                            max: math.pi * 2,
                            onChanged: _deferredRotateSelectedShape,
                          ),
                        ],
                      );
                    },
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
      bottom: 12 + bottomInset,
      child: Center(
        child: Material(
          color: const Color(0xD91F2229),
          borderRadius: BorderRadius.circular(InkRadii.glassBar),
          child: InkWell(
            borderRadius: BorderRadius.circular(InkRadii.glassBar),
            onTap: () {
              setState(() {
                _isShapeEditTrayExpanded = true;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Edit Shape', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _getShapeCenterGlobal(_CanvasElement shape) {
    final centerLocal = _toScreen(shape.center);
    final canvasBox =
        _canvasPreviewKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox != null && canvasBox.hasSize) {
      return canvasBox.localToGlobal(centerLocal);
    }
    final rootBox = context.findRenderObject() as RenderBox?;
    if (rootBox != null && rootBox.hasSize) {
      return rootBox.localToGlobal(centerLocal);
    }
    return centerLocal;
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
    if (shape.kind == _ElementKind.text) {
      // Persisted measured text bounds; legacy elements fall back to the
      // same 180x48 estimate used by the erase hit-test.
      rawW = shape.width > 0 ? shape.width : 180.0;
      rawH = shape.height > 0 ? shape.height : 48.0;
    } else if (shape.kind == _ElementKind.stickyNote ||
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

    // Text is painted from its center point as the top-left origin, so anchor
    // the overlay box at that corner instead of centering it on the point.
    final isTextElement = shape.kind == _ElementKind.text;
    return Positioned(
      left: (isTextElement ? center.dx : center.dx - halfW) - 16,
      top: (isTextElement ? center.dy : center.dy - halfH) - 16,
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
                      onPanStart: (details) {
                        _setShapeEditing(true);
                        _overlayDragStartGlobalPos = details.globalPosition;
                        _overlayDragStartCenter = shape.center;
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
                        final globalDelta =
                            details.globalPosition - _overlayDragStartGlobalPos;
                        final nextCenter = Offset(
                          _overlayDragStartCenter.dx +
                              (globalDelta.dx / _viewportScale),
                          _overlayDragStartCenter.dy +
                              (globalDelta.dy / _viewportScale),
                        );
                        setState(() {
                          _shapeTransformDraft = draft.copyWith(center: nextCenter);
                        });
                        if (shape.kind == _ElementKind.image) {
                          _canvasBloc.add(
                            CanvasPreviewImageElement(
                              elementId: shape.id,
                              center: nextCenter,
                              width: draft.width ?? shape.width,
                              height: draft.height ?? shape.height,
                            ),
                          );
                        } else {
                          _canvasBloc.add(CanvasPreviewMoveSelectedShape(nextCenter));
                        }
                      },
                      onPanEnd: (_) {
                        final draft = _shapeTransformDraft;
                        if (draft != null && draft.shapeId == shape.id) {
                          if (shape.kind == _ElementKind.image) {
                            _canvasBloc.add(
                              CanvasUpdateImageElement(
                                elementId: shape.id,
                                center: draft.center,
                                width: draft.width ?? shape.width,
                                height: draft.height ?? shape.height,
                              ),
                            );
                          } else {
                            _moveSelectedShape(draft.center);
                          }
                        }
                        _shapeTransformDraft = null;
                        _overlayDragStartGlobalPos = Offset.zero;
                        _overlayDragStartCenter = Offset.zero;
                        _setShapeEditing(false);
                      },
                      onPanCancel: () {
                        _shapeTransformDraft = null;
                        _overlayDragStartGlobalPos = Offset.zero;
                        _overlayDragStartCenter = Offset.zero;
                        _setShapeEditing(false);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: _tokens.accent, width: 1.5),
                          borderRadius: BorderRadius.circular(
                            (shape.kind == _ElementKind.stickyNote ||
                                    shape.kind == _ElementKind.image)
                                ? 8
                                : 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Rotate handle (top center)
                  if (shape.kind != _ElementKind.image)
                    Positioned(
                      top: 2,
                      left: 16 + (screenW / 2) - 14,
                      child: GestureDetector(
                        onPanStart: (details) {
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
                          final centerGlobal = _getShapeCenterGlobal(shape);
                          final touchVector =
                              details.globalPosition - centerGlobal;
                          if (touchVector.distanceSquared > 1e-4) {
                            _rotationPrevTouchAngle = math.atan2(
                              touchVector.dy,
                              touchVector.dx,
                            );
                          } else {
                            _rotationPrevTouchAngle = 0.0;
                          }
                          _rotationCurrentAngle = baseRotation;
                        },
                        onPanUpdate: (details) {
                          final draft = _shapeTransformDraft;
                          if (draft == null || draft.shapeId != shape.id) return;
                          final centerGlobal = _getShapeCenterGlobal(shape);
                          final touchVector =
                              details.globalPosition - centerGlobal;
                          if (touchVector.distanceSquared < 1e-4) return;
                          final currentTouchAngle = math.atan2(
                            touchVector.dy,
                            touchVector.dx,
                          );
                          var angleDiff =
                              currentTouchAngle - _rotationPrevTouchAngle;
                          while (angleDiff > math.pi) {
                            angleDiff -= 2 * math.pi;
                          }
                          while (angleDiff < -math.pi) {
                            angleDiff += 2 * math.pi;
                          }
                          _rotationPrevTouchAngle = currentTouchAngle;
                          _rotationCurrentAngle += angleDiff;
                          setState(() {
                            _shapeTransformDraft = draft.copyWith(
                              rotation: _rotationCurrentAngle,
                            );
                          });
                          _canvasBloc.add(
                            CanvasPreviewRotateSelectedShape(
                              _rotationCurrentAngle,
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
                          _rotationPrevTouchAngle = 0.0;
                          _rotationCurrentAngle = 0.0;
                          _setShapeEditing(false);
                        },
                        onPanCancel: () {
                          _shapeTransformDraft = null;
                          _isRotatingShape = false;
                          _rotationPrevTouchAngle = 0.0;
                          _rotationCurrentAngle = 0.0;
                          _setShapeEditing(false);
                        },
                        child: _buildHandle(LucideIcons.rotateCw),
                      ),
                    ),
                  // Resize handle (bottom right)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onPanStart: (details) {
                        _setShapeEditing(true);
                        _isResizingShape = true;
                        final baseRotation =
                            (shape.data['rotation'] as num?)?.toDouble() ??
                            state.selectedShapeRotation;
                        _resizeStartGlobalPos = details.globalPosition;
                        _resizeStartSize = shape.size;
                        _resizeStartWidth = rawW;
                        _resizeStartHeight = rawH;
                        _resizeStartRotation = baseRotation;
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
                        final worldDelta =
                            (details.globalPosition - _resizeStartGlobalPos) /
                            _viewportScale;
                        final cosA = math.cos(-_resizeStartRotation);
                        final sinA = math.sin(-_resizeStartRotation);
                        final localDx =
                            worldDelta.dx * cosA - worldDelta.dy * sinA;
                        final localDy =
                            worldDelta.dx * sinA + worldDelta.dy * cosA;
                        final sizeDelta = (localDx + localDy) * 1.2;
                        final nextSize = (_resizeStartSize + sizeDelta)
                            .clamp(24.0, 320.0)
                            .toDouble();
                        final minDim = shape.kind == _ElementKind.image ? 80.0 : 40.0;
                        final maxDim = shape.kind == _ElementKind.image ? 720.0 : 480.0;
                        final nextW = (_resizeStartWidth + localDx * 1.8)
                            .clamp(minDim, maxDim)
                            .toDouble();
                        final nextH = (_resizeStartHeight + localDy * 1.8)
                            .clamp(minDim, maxDim)
                            .toDouble();
                        setState(() {
                          _shapeTransformDraft = draft.copyWith(
                            size: nextSize,
                            width: nextW,
                            height: nextH,
                          );
                        });
                        if (shape.kind == _ElementKind.image) {
                          _canvasBloc.add(
                            CanvasPreviewImageElement(
                              elementId: shape.id,
                              center: draft.center,
                              width: nextW,
                              height: nextH,
                            ),
                          );
                        } else {
                          _canvasBloc.add(CanvasPreviewResizeSelectedShape(nextSize));
                        }
                      },
                      onPanEnd: (_) {
                        final draft = _shapeTransformDraft;
                        if (draft != null && draft.shapeId == shape.id) {
                          if (shape.kind == _ElementKind.image) {
                            _canvasBloc.add(
                              CanvasUpdateImageElement(
                                elementId: shape.id,
                                center: draft.center,
                                width: draft.width ?? draft.size,
                                height: draft.height ?? draft.size,
                              ),
                            );
                          } else {
                            _resizeSelectedShape(draft.size);
                          }
                        }
                        _shapeTransformDraft = null;
                        _isResizingShape = false;
                        _resizeStartGlobalPos = Offset.zero;
                        _setShapeEditing(false);
                      },
                      onPanCancel: () {
                        _shapeTransformDraft = null;
                        _isResizingShape = false;
                        _resizeStartGlobalPos = Offset.zero;
                        _setShapeEditing(false);
                      },
                      child: _buildHandle(LucideIcons.maximize2),
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
                            border: Border.all(color: _tokens.accent, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(LucideIcons.pencil, size: 14, color: _tokens.accent),
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
              onTap: () {
                HapticFeedback.mediumImpact();
                _canvasBloc.add(CanvasDeleteElement(shape.id));
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _tokens.danger,
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
                child: const Icon(LucideIcons.trash2, size: 14, color: Colors.white),
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
        border: Border.all(color: _tokens.accent, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 14, color: _tokens.accent),
    );
  }

  /// Opens the per-element revert review whenever a plan arrives (D4/D12).
  Widget _buildHistoryPlanListener() {
    return BlocListener<CanvasBloc, CanvasState>(
      listenWhen: (previous, current) =>
          previous.activeRevertPlan?.planId != current.activeRevertPlan?.planId,
      listener: (context, state) {
        final plan = state.activeRevertPlan;
        if (plan == null) return;
        showRevertReviewSheet(
          context,
          bloc: _canvasBloc,
          plan: plan,
          requestId: plan.requestId,
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  /// "Your work has been changed" (§7.2): an undo/redo was blocked because a
  /// collaborator edited the element(s) the entry would revert. Members can
  /// send the owner an undo request; the owner reviews their own changes.
  Widget _buildUndoConflictListener() {
    return BlocListener<CanvasBloc, CanvasState>(
      listenWhen: (previous, current) =>
          previous.undoConflict != current.undoConflict,
      listener: (dialogContext, state) async {
        final conflict = state.undoConflict;
        if (conflict == null || conflict.elementIds.isEmpty) return;
        final isOwner = state.currentUserRole == Board.roleOwner;
        final count = conflict.elementIds.length;
        final confirmed = await showInkConfirmDialog(
          dialogContext,
          title: 'Your work has been changed',
          message: count == 1
              ? 'Someone edited the element you are about to undo. To revert '
                  'it, ${isOwner ? 'review the changes' : 'send a request to the board owner'}.'
              : 'Someone edited $count elements you are about to undo. To '
                  'revert them, ${isOwner ? 'review the changes' : 'send a request to the board owner'}.',
          confirmLabel: isOwner ? 'Review changes' : 'Send undo request',
          destructive: false,
        );
        if (!mounted) return;
        _canvasBloc.add(const CanvasUndoConflictDismissed());
        if (!confirmed) return;
        if (isOwner) {
          _canvasBloc.add(
            CanvasHistoryRevertUserRequested(
              state.currentUserId,
              elementIds: conflict.elementIds,
            ),
          );
        } else {
          final conflictedIds = conflict.elementIds.toSet();
          showUndoRequestSheet(
            context,
            service: context.read<BoardHistoryService>(),
            boardId: widget.boardId,
            elements: _canvasBloc.state.elements
                .where((e) => conflictedIds.contains(e.id))
                .toList(growable: false),
            preselectedIds: conflict.elementIds,
          );
        }
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildAllTrays(CanvasState state) {
    return Stack(
      children: [
        if (state.activeTray != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleTray(state.activeTray!),
            ),
          ),
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
          onClearAll:
              state.currentUserRole == Board.roleOwner ? _clearAll : null,
          onAddStickyNote: _addStickyNoteDialog,
          onAddConnector: _addConnectorDialog,
          onExport: () => _showExportOptionsSheet(context),
          onHistory: state.currentUserRole == Board.roleOwner
              ? () => _openTray('history')
              : null,
          onRequestUndo: state.currentUserRole == Board.roleEditor
              ? _openUndoRequestSheet
              : null,
          onClose: () => _toggleTray('tools'),
        ),
        if (state.currentUserRole == Board.roleOwner)
          HistoryTray(
            isOpen: state.activeTray == 'history',
            boardId: widget.boardId,
            state: state,
            bloc: _canvasBloc,
            historyService: context.read<BoardHistoryService>(),
            onClose: () => _toggleTray('history'),
          ),
        ShapesTray(
          isOpen: state.activeTray == 'shapes',
          onSelectShapeForDrawing: _selectShapeForDrawing,
          selectedType: state.pendingShapeType,
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
            _canvasBloc.add(CanvasSetToolMode(mode, keepTray: true));
          },
          onClose: () => _toggleTray('brushes'),
        ),
      ],
    );
  }

  Widget _buildTopPills(CanvasState state, String title) {
    final tokens = _tokens;
    final topInset = MediaQuery.of(context).padding.top + 8;
    final notifState = context.watch<NotificationsBloc>().state;
    final int pendingRequestsCount;
    if (state.currentUserRole == Board.roleOwner &&
        notifState is NotificationsLoaded) {
      pendingRequestsCount = notifState.notifications.where((n) {
        final type = n['type']?.toString();
        final status = n['status']?.toString();
        final extraData = n['extraData'] is Map
            ? (n['extraData'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final bId =
            extraData['boardId']?.toString() ?? n['targetId']?.toString();
        final reqType = extraData['requestType']?.toString() ??
            (type == 'board_edit_request' ? 'edit' : 'join');
        return (type == 'board_edit_request' ||
                (type == 'board_access_request' && reqType == 'edit')) &&
            status == 'pending' &&
            bId == widget.boardId;
      }).length;
    } else {
      pendingRequestsCount = 0;
    }

    return Positioned(
      top: topInset,
      left: 12,
      right: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GlassPanel(
              radius: InkRadii.glassBar,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Exit canvas',
                      icon: Icon(LucideIcons.chevronLeft, color: tokens.ink),
                      onPressed: _exitCanvas,
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openSettings(state.boardTitle ?? 'Board'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: InkType.title(tokens.ink),
                              ),
                            ),
                            if (pendingRequestsCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tokens.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassPanel(
            radius: InkRadii.glassBar,
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.boardMembers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildMemberAvatarStack(state.boardMembers),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip: 'Reset View',
                    icon: Icon(LucideIcons.scan, color: tokens.ink, size: 18),
                    onPressed: _toggleResetView,
                  ),
                  if (state.isExporting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: pendingRequestsCount > 0
                        ? Badge(
                            label: Text('$pendingRequestsCount'),
                            backgroundColor: tokens.accent,
                            textColor: Colors.white,
                            child: Icon(
                              LucideIcons.ellipsis,
                              color: tokens.ink,
                              size: 18,
                            ),
                          )
                        : Icon(
                            LucideIcons.ellipsis,
                            color: tokens.ink,
                            size: 18,
                          ),
                    onSelected: (value) async {
                      if (value == 'requests') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BoardEditRequestsScreen(
                              boardId: widget.boardId,
                              boardTitle: state.boardTitle ?? 'Board',
                            ),
                          ),
                        );
                      } else if (value == 'settings') {
                        _openSettings(state.boardTitle ?? 'Board');
                      } else if (value == 'request_edit') {
                        _showRequestEditDialog(context);
                      } else if (value == 'export') {
                        _showExportOptionsSheet(context);
                      } else if (value == 'share') {
                        _canvasBloc.add(
                          CanvasExportBoardRequested(
                            format: BoardExportFormat.png,
                            shareAfterExport: true,
                            sharePositionOrigin: _shareAnchorRect(),
                          ),
                        );
                      } else if (value == 'copy') {
                        Clipboard.setData(
                          ClipboardData(text: widget.boardId),
                        );
                        AppSnackBar.showSuccess(
                          context,
                          'Join Code copied to clipboard!',
                        );
                      } else if (value == 'toggle_gesture_lock') {
                        setState(() {
                          _preventGestureBack = !_preventGestureBack;
                        });
                        AppSnackBar.showMessage(
                          context,
                          _preventGestureBack
                              ? 'Gesture back locked (exit via back button).'
                              : 'Gesture back unlocked.',
                        );
                      } else if (value == 'toggle_edge_buttons') {
                        setState(() {
                          _showEdgeTrayButtons = !_showEdgeTrayButtons;
                        });
                      } else if (value == 'exit') {
                        await _exitCanvas();
                      }
                    },
                    itemBuilder: (context) => [
                      if (state.currentUserRole == Board.roleOwner &&
                          pendingRequestsCount > 0)
                        PopupMenuItem(
                          value: 'requests',
                          child: _menuRow(
                            LucideIcons.userCheck,
                            'Edit Requests ($pendingRequestsCount)',
                            tokens.accent,
                          ),
                        ),
                      PopupMenuItem(
                        value: 'settings',
                        child: _menuRow(
                          LucideIcons.slidersHorizontal,
                          (state.currentUserRole == Board.roleOwner &&
                                  pendingRequestsCount > 0)
                              ? 'Board Settings ($pendingRequestsCount)'
                              : 'Board Settings',
                          tokens.ink,
                        ),
                      ),
                      if (state.currentUserRole == Board.roleViewer)
                        PopupMenuItem(
                          value: 'request_edit',
                          child: _menuRow(LucideIcons.pencilLine, 'Request Edit Access', tokens.accent),
                        ),
                      PopupMenuItem(
                        value: 'export',
                        child: _menuRow(LucideIcons.download, 'Export Board...', tokens.ink),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: _menuRow(LucideIcons.share2, 'Share Board', tokens.ink),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: _menuRow(LucideIcons.copy, 'Copy Join Code', tokens.ink),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem<String>(
                        value: 'toggle_gesture_lock',
                        checked: _preventGestureBack,
                        child: Text('Lock Back Gesture', style: TextStyle(color: tokens.ink)),
                      ),
                      CheckedPopupMenuItem<String>(
                        value: 'toggle_edge_buttons',
                        checked: _showEdgeTrayButtons,
                        child: Text('Show Tray Edge Icons', style: TextStyle(color: tokens.ink)),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'exit',
                        child: _menuRow(LucideIcons.logOut, 'Exit Canvas', tokens.danger),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  void _showRequestEditDialog(BuildContext context) {
    final tokens = _tokens;
    final noteController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.pencilLine, size: 20, color: tokens.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Request Edit Access',
                style: InkType.title(tokens.ink),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a request to the board owner to grant you editor access?',
              style: InkType.body(tokens.inkSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLength: 140,
              decoration: InputDecoration(
                hintText: 'Optional note to owner...',
                hintStyle: InkType.caption(tokens.inkMuted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: tokens.glassStroke),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: InkType.body(tokens.inkMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final note = noteController.text.trim();
              Navigator.pop(dialogCtx);
              context.read<CanvasBloc>().add(
                    CanvasRequestEditAccess(
                      message: note.isNotEmpty ? note : null,
                    ),
                  );
            },
            child:
                Text('Send Request', style: InkType.bodyStrong(Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatarStack(List<BoardMember> members) {
    const maxVisible = 4;
    final bool hasOverflow = members.length > maxVisible;
    final shownCount = hasOverflow ? maxVisible - 1 : members.length;
    final shown = members.take(shownCount).toList();
    final overflowCount = members.length - shownCount;
    final totalBadges = shown.length + (hasOverflow ? 1 : 0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleTray('members'),
      child: Tooltip(
        message: 'Board members (${members.length})',
        child: SizedBox(
          width: totalBadges == 0 ? 0 : 28.0 + (totalBadges - 1) * 18.0,
          height: 32,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * 18.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _tokens.glassStroke,
                        width: 1.5,
                      ),
                    ),
                    child: InkAvatar(
                      imageUrl: shown[i].photoUrl,
                      initials: shown[i].label.isNotEmpty
                          ? shown[i].label.substring(0, 1).toUpperCase()
                          : '?',
                      id: shown[i].uid,
                      size: 26,
                    ),
                  ),
                ),
              if (hasOverflow)
                Positioned(
                  left: shownCount * 18.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _tokens.glass,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _tokens.glassStroke,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflowCount',
                      style: InkType.caption(_tokens.ink).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassEdgeTab(IconData icon, {bool vertical = true}) {
    if (!_showEdgeTrayButtons) return const SizedBox.shrink();
    final tokens = _tokens;
    return IgnorePointer(
      child: Center(
        child: GlassPanel(
          radius: 14,
          child: SizedBox(
            width: vertical ? 36 : 56,
            height: vertical ? 56 : 36,
            child: Icon(icon, size: 18, color: tokens.inkMuted),
          ),
        ),
      ),
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
            onTap: () => _openTray('brushes'),
            onVerticalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onVerticalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dy < -6) _openTray('brushes');
            },
            child: Container(
              height: 55,
              width: double.infinity,
              color: Colors.transparent,
              child: _buildGlassEdgeTab(LucideIcons.penLine, vertical: false),
            ),
          ),
        ),
        // TOP LEFT: Swipe Right for Members
        Align(
          alignment: Alignment.topLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTray('members'),
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
              child: _buildGlassEdgeTab(LucideIcons.users),
            ),
          ),
        ),
        // BOTTOM LEFT: Swipe Right for Tools
        Align(
          alignment: Alignment.bottomLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTray('tools'),
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
              child: _buildGlassEdgeTab(LucideIcons.slidersHorizontal),
            ),
          ),
        ),
        // TOP RIGHT: Swipe Left for AI
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTray('ai'),
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
              child: _buildGlassEdgeTab(LucideIcons.sparkles),
            ),
          ),
        ),
        // BOTTOM RIGHT: Swipe Left for Shapes
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTray('shapes'),
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
              child: _buildGlassEdgeTab(LucideIcons.shapes),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolModeIndicator(CanvasState state) {
    if (state.currentToolMode == CanvasToolMode.doodle) {
      return const SizedBox.shrink();
    }

    final (IconData icon, String label) = _isArrowMode(state)
        ? (
            LucideIcons.arrowRight,
            _arrowConnectStartElementId != null
                ? 'Arrow: Tap 2nd shape to point to'
                : 'Arrow: Tap 2 shapes to connect, or drag',
          )
        : switch (state.currentToolMode) {
            CanvasToolMode.shape => (
              LucideIcons.shapes,
              state.pendingShapeType != null
                  ? 'Shape: ${state.pendingShapeType!.name}'
                  : 'Shape',
            ),
            CanvasToolMode.eraser => (LucideIcons.eraser, 'Eraser'),
            CanvasToolMode.text => (LucideIcons.type, 'Text'),
            CanvasToolMode.arrow => (LucideIcons.arrowRight, 'Arrow'),
            CanvasToolMode.image => (LucideIcons.image, 'Image'),
            CanvasToolMode.highlight => (LucideIcons.highlighter, 'Highlight'),
            CanvasToolMode.doodle => (LucideIcons.penLine, 'Doodle'),
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
            color: const Color(0xD91F2229),
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

  void _promptNewCommentDialog(Offset worldPoint) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => InkDialog(
        title: 'Add Comment Pin',
        icon: LucideIcons.mapPin,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pin at (${worldPoint.dx.toInt()}, ${worldPoint.dy.toInt()})',
              style: InkType.caption(_tokens.inkMuted),
            ),
            const SizedBox(height: 12),
            InkTextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              hintText: 'Write a comment... (use @name to mention)',
              ),
          ],
        ),
        actions: [
          InkButton.secondary(
            label: 'Cancel',
            expand: false,
            compact: true,
            onPressed: () {
              Navigator.pop(dialogCtx);
              _canvasBloc.add(
                const CanvasToggleCommentPlacementMode(enable: false),
              );
            },
          ),
          InkButton.primary(
            label: 'Post Pin',
            expand: false,
            compact: true,
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
                      color: isSelected ? _tokens.accent : _tokens.pending,
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
                          LucideIcons.messageCircle,
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
                      color: isSelected ? _tokens.accent : _tokens.pending,
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
    WidgetsBinding.instance.removeObserver(this);
    _shapeEditDebounceTimer?.cancel();
    for (final img in _decodedUiImages.values) {
      img.dispose();
    }
    _decodedUiImages.clear();
    _decodedUiImageKeys.clear();
    _pendingDecodeImageIds.clear();
    _canvasBloc.close();
    _aiPromptController.dispose();
    super.dispose();
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