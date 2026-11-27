import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/ai_feature_flag.dart';
import '../../../core/utils/app_snackbar.dart';

import '../../../domain/models/board.dart';
import '../../../domain/models/canvas/canvas_board_settings.dart';
import '../../../domain/models/canvas/canvas_export_options.dart';
import '../../../domain/models/canvas/canvas_toolbar_action.dart';
import '../../../domain/models/history/board_operation.dart';
import '../../../domain/models/history/undo_request.dart';
import '../../../domain/services/history/board_history_service.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../../../core/utils/tray_tips_preferences.dart';
import '../../../ui/theme/ink_theme.dart';
import '../../../ui/theme/ink_tokens.dart';
import '../../../ui/theme/ink_type.dart';
import '../../../ui/widgets/bottom_bar_customizer_sheet.dart';
import '../../../ui/widgets/glass_panel.dart';
import '../../../ui/widgets/ink_avatar.dart';
import '../../../ui/widgets/ink_button.dart';
import '../../../ui/widgets/ink_dialog.dart';
import '../../../ui/widgets/ink_text_field.dart';
import '../../dashboard/view/board_edit_requests_screen.dart';
import '../../notifications/bloc/notifications_bloc.dart';
import '../bloc/ai_image_bloc.dart';
import '../bloc/canvas_bloc.dart';
import '../../../core/utils/canvas_color_preferences.dart';
import '../geometry/canvas_color_sampling.dart';
import '../geometry/canvas_element_drawer.dart';
import '../geometry/canvas_element_geometry.dart';
import '../geometry/canvas_selection_transform.dart';
import '../geometry/canvas_viewport_math.dart';
import '../geometry/quick_shape.dart';
import '../geometry/stroke_input.dart';
import '../models/board_template.dart';
import '../models/canvas_tool_mode.dart';
import 'ai_repaint_screen.dart';
import 'board_settings_opener.dart'
    if (dart.library.js_interop) 'board_settings_opener_web.dart';
import 'media_editor_screen.dart';
import 'trays/ai_tray.dart';
import 'trays/brush_tray.dart';
import 'trays/canvas_actions_tray.dart';
import 'trays/canvas_shape_type.dart';
import 'trays/layers_tray.dart';
import 'trays/members_tray.dart';
import 'history_screen.dart';
import 'trays/tools_tray.dart';
import 'widgets/history_preview_banner.dart';
import 'widgets/shapes_picker_popup.dart';
import 'widgets/sliding_tray.dart';
import 'widgets/revert_review_sheet.dart';
import 'widgets/undo_request_sheet.dart';
import 'chat/board_chat_drawer.dart';
import 'trays/comments_tray.dart';
import 'voice/voice_call_hud.dart';
import 'widgets/ai_image_widgets.dart';
import 'widgets/canvas_minimap.dart';
import 'widgets/canvas_selection_style_sheet.dart';
import 'widgets/canvas_toolbar.dart';
import 'widgets/color_picker_sheet.dart';
import 'widgets/comment_mention_picker.dart';
import 'widgets/sticky_note_editor_dialog.dart';
import 'widgets/template_coachmark.dart';
import 'widgets/template_gallery_sheet.dart';
import 'widgets/tray_tips_overlay.dart';
import '../../../ui/widgets/canvas_toolbar_action_meta.dart';
import 'package:inklink/features/canvas/models/canvas_editor_palette.dart';

part 'canvas_painter.dart';
part 'canvas_screen_web.dart';

enum _PinchIntent { undecided, zoom, pan }

class CanvasScreen extends StatefulWidget {
  final String boardId;
  final bool showTrayTipsOnEntry;
  final String boardPreviewQuality;
  final bool boardPreviewCompressionEnabled;
  final List<CanvasToolbarAction> initialBottomBarActions;
  final Future<void> Function(List<CanvasToolbarAction>)?
      onSaveBottomBarActions;
  final BoardHistoryService? historyService;
  final String? initialTemplateId;

  const CanvasScreen({
    super.key,
    required this.boardId,
    this.showTrayTipsOnEntry = false,
    this.boardPreviewQuality = 'medium',
    this.boardPreviewCompressionEnabled = true,
    this.initialBottomBarActions =
        CanvasToolbarAction.defaultBottomBarActions,
    this.onSaveBottomBarActions,
    this.historyService,
    this.initialTemplateId,
  });

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen>
    with WidgetsBindingObserver {
  final TextEditingController _aiPromptController = TextEditingController();
  final GlobalKey _canvasPreviewKey = GlobalKey();
  Future<void>? _inFlightPreviewSave;
  bool _isDraggingShape = false;
  bool _isDraggingStroke = false;
  String? _enteredFrameId;
  bool _isDrawingShape = false;
  List<Offset>? _strokeDragOriginalPoints;
  Offset? _strokeDragDelta;
  Offset _strokeDragStartWorldPoint = Offset.zero;
  bool _isEditingShape = false;
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
  bool _isPreviewPanning = false;
  bool _didAutoFrameContent = false;
  bool _elementEditorDismissed = false;
  String? _activeEditControl;
  String? _editingBarSelectionId;
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
  int? _rawStrokePointerId;
  PointerDeviceKind? _rawStrokeKind;
  Offset? _rawStrokeLastWorld;
  final Map<int, Offset> _activeCanvasPointers = <int, Offset>{};
  final Map<int, PointerDeviceKind> _activePointerKinds =
      <int, PointerDeviceKind>{};
  final Set<int> _stylusPointers = <int>{};
  _PinchIntent _pinchIntent = _PinchIntent.undecided;
  static const String _fingerDrawingPreferenceKey =
      'canvas.finger_drawing_enabled';
  static const String _templateCoachmarkPreferenceKey =
      'canvas.template_coachmark_seen';
  bool _showTemplateCoachmark = false;
  bool _closedStrokeHintShown = false;
  bool _appliedInitialTemplate = false;
  final List<({String key, Uint8List bytes})> _recentAiImages =
      <({String key, Uint8List bytes})>[];
  Map<String, ui.Image> _decodedUiImages = <String, ui.Image>{};
  final Map<String, String> _decodedUiImageKeys = <String, String>{};
  final Set<String> _pendingDecodeImageIds = <String>{};
  late final CanvasBloc _canvasBloc;
  // AI images. The bloc is optional so the screen still works without it.
  AiImageBloc? _aiImageBloc;
  StreamSubscription<AiImageState>? _aiImageSub;
  bool _aiImageEnabled = false;
  String _aiAspectRatio = kAiAspectRatios.first;
  int _lastAiCompletionSequence = 0;
  int _lastAiFailureSequence = 0;
  final Set<String> _requestedAiImageUrls = <String>{};
  Timer? _shapeEditDebounceTimer;
  Timer? _edgeAutoPanTimer;
  Offset? _edgeAutoPanLocalPos;
  bool _edgeAutoPanFromOverlay = false;
  final Map<String, dynamic> _pendingShapeEdits = <String, dynamic>{};
  final Map<String, TextEditingController> _shapeLabelControllers =
      <String, TextEditingController>{};
  _TextEditorDraft? _textEditor;
  TextEditingController? _textEditingController;
  FocusNode? _textEditingFocusNode;
  Offset? _lastTapWorldPoint;
  Offset? _lastDoubleTapWorldPoint;
  bool _suppressTapDeselect = false;

  /// Set when an in-place text edit commits, so the tap that dismisses the
  /// editor does not also clear the selection. A later tap is a real
  /// "click elsewhere" and deselects as usual.
  DateTime? _textCommitAt;
  String? _arrowConnectStartElementId;
  bool _isMarqueeSelecting = false;
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;
  Offset? _groupDragDelta;
  bool _isLassoSelecting = false;
  List<Offset>? _lassoPoints;

  /// Shift state captured when a marquee/lasso gesture begins. Reading the
  /// keyboard again at drag end would miss a modifier released mid-drag.
  bool _selectionAdditive = false;

  double _latestPressure = 1.0;
  double _latestTilt = 0;
  DateTime _lastStrokeMoveAt = DateTime.now();
  DateTime _lastSpatialStrokeMoveAt = DateTime.now();
  Timer? _inkSpillTimer;
  int _inkSpillDwellTicks = 0;
  Offset? _rawStrokeLastScreen;
  List<CanvasElement>? _cachedMapElementsInput;
  List<_CanvasElement>? _cachedMappedElements;
  List<CanvasElement>? _cachedLayerEffectsInput;
  Map<String, CanvasLayerPaintEffect>? _cachedLayerEffects;
  Set<String> _lockedLayerElementIds = const {};

  // Color tools: recent swatches, saved palettes and the one-shot canvas
  // eyedropper.
  List<Color> _recentColors = const <Color>[];
  Map<String, List<Color>> _palettes = const <String, List<Color>>{};
  CanvasColorPreferences? _colorPreferences;
  bool _isEyedropperActive = false;
  bool _isPlacingSymmetryCenter = false;
  bool _isUndoRedoMode = false;

  // Multi-selection group transform gestures.
  Rect? _groupScaleSource;
  Rect? _groupScaleTarget;
  Offset _groupScaleStartGlobal = Offset.zero;
  int? _groupScaleHandle;
  Offset? _groupRotationPivot;
  double _groupRotationDelta = 0;
  double _groupRotationPrevAngle = 0;

  Offset? _areaSelectionStart;
  Offset? _areaSelectionCurrent;
  String? _historyPreviewFocusKey;
  Timer? _scrubDebounce;

  /// True while the undo-request sheet (scope or send stage) is open. Gates
  /// canvas double-tap picking so picks only register when the member can see
  /// the canvas (hint chip visible, sheet closed).
  bool _undoRequestSheetOpen = false;

  /// Manual double-tap timing while picking undo-request scope elements:
  /// [GestureDetector.onTapDown] fires for both taps of a double-tap, and the
  /// framework's [GestureDetector.onDoubleTap] opens editors we must not
  /// open during picking.
  DateTime? _lastPickTapDown;

  Rect? get _areaSelectionRect {
    final start = _areaSelectionStart;
    final current = _areaSelectionCurrent;
    if (start == null || current == null) return null;
    return Rect.fromPoints(start, current);
  }

  static const double _viewportComparisonEpsilon = 0.01;
  InkTokens get _tokens => context.ink;
  bool _preventGestureBack = true;
  bool _showEdgeTrayButtons = true;

  /// Desktop browser layout: whether the minimap is shown.
  bool _webMinimapVisible = true;

  /// Desktop browser: holds keyboard focus for the board's shortcuts
  /// (canvas_screen_web.dart). Unused on phones.
  final FocusNode _webKeyFocus = FocusNode(debugLabel: 'canvas web keys');

  /// Desktop browser: the mouse pointer panning with the middle button.
  int? _webMiddlePanPointer;

  void _closeShapesPopup() => setState(() => _isShapesPopupOpen = false);

  void _toggleWebMinimap() =>
      setState(() => _webMinimapVisible = !_webMinimapVisible);
  bool _isShapesPopupOpen = false;
  late List<CanvasToolbarAction> _bottomBarActions =
      List<CanvasToolbarAction>.of(widget.initialBottomBarActions);
  DateTime? _lastEdgeDragTime;
  DateTime? _lastBackSnackbarTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _canvasBloc = context.read<CanvasBloc>();
    _aiImageBloc = context.read<AiImageBloc?>();
    _aiImageEnabled = _aiImageBloc != null && isAiImageEnabled();
    _aiImageSub = _aiImageBloc?.stream.listen(_onAiImageState);
    _maybeShowTrayTipsOverlay();
    _loadColorPreferences();
    _loadCanvasPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeApplyInitialTemplate(_canvasBloc.state);
    });
  }

  @override
  void didUpdateWidget(covariant CanvasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.initialBottomBarActions,
      widget.initialBottomBarActions,
    )) {
      _bottomBarActions = List<CanvasToolbarAction>.of(
        widget.initialBottomBarActions,
      );
    }
  }

  void _maybeApplyInitialTemplate(CanvasState state) {
    if (!mounted ||
        state.isLoading ||
        _appliedInitialTemplate ||
        widget.initialTemplateId == null) {
      return;
    }
    _appliedInitialTemplate = true;
    if (state.canEdit && state.elements.isEmpty) {
      final template = canvasTemplates
          .where((t) => t.id == widget.initialTemplateId)
          .firstOrNull;
      if (template != null && !template.isEmpty) {
        _canvasBloc.add(
          CanvasImportElements(
            template.elements,
            offset: -template.center,
          ),
        );
      }
    }
  }

  Future<void> _loadCanvasPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final fingerDrawing = prefs.getBool(_fingerDrawingPreferenceKey) ?? true;
      _canvasBloc.add(CanvasSetFingerDrawing(fingerDrawing));
      final coachmarkSeen =
          prefs.getBool(_templateCoachmarkPreferenceKey) ?? false;
      if (!coachmarkSeen && mounted) {
        setState(() => _showTemplateCoachmark = true);
      }
    } catch (_) {
      // Preferences are optional; drawing still works with the defaults.
    }
  }

  Future<void> _dismissTemplateCoachmark() async {
    if (!mounted) return;
    setState(() => _showTemplateCoachmark = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_templateCoachmarkPreferenceKey, true);
    } catch (_) {}
  }

  Future<void> _loadColorPreferences() async {
    final preferences = await CanvasColorPreferences.instance();
    if (!mounted) return;
    _colorPreferences = preferences;
    final storedRecent = preferences.getRecentColors();
    final storedPalettes = preferences.getPalettes();
    if (storedRecent.isEmpty && storedPalettes.isEmpty) return;
    setState(() {
      _recentColors = storedRecent;
      _palettes = storedPalettes;
    });
  }

  /// Applies a brush colour without touching the current opacity. Recents only
  /// ever hold opaque colours, so picking a recent swatch or the eyedropper
  /// leaves the opacity slider where it was.
  void _setBrushColor(Color color) {
    final opaque = color.withValues(alpha: 1);
    final next = <Color>[
      opaque,
      ..._recentColors.where((existing) => existing.value != opaque.value),
    ].take(CanvasColorPreferences.maxRecentColors).toList(growable: false);
    setState(() => _recentColors = next);
    _persistRecentColors(next);
    _canvasBloc.add(CanvasUpdateColor(opaque));
  }

  /// The picker carries opacity in the alpha channel. Split it so the painter
  /// does not multiply opacity twice, and record only the opaque colour.
  void _applyPickedBrushColor(Color color) {
    _setBrushColor(color);
    _canvasBloc.add(CanvasUpdateBrushOpacity(color.a));
  }

  Future<void> _persistRecentColors(List<Color> colors) async {
    final preferences =
        _colorPreferences ?? await CanvasColorPreferences.instance();
    _colorPreferences = preferences;
    await preferences.saveRecentColors(colors);
  }

  void _updatePalettes(Map<String, List<Color>> palettes) {
    setState(() => _palettes = palettes);
    _persistPalettes(palettes);
  }

  Future<void> _persistPalettes(Map<String, List<Color>> palettes) async {
    final preferences =
        _colorPreferences ?? await CanvasColorPreferences.instance();
    _colorPreferences = preferences;
    await preferences.savePalettes(palettes);
  }

  Future<void> _openColorPicker() async {
    final picked = await showCanvasColorPicker(
      context,
      initialColor: _canvasBloc.state.selectedColor,
      recentColors: _recentColors,
      initialOpacity: _canvasBloc.state.brushOpacity,
      palettes: _palettes,
      onPalettesChanged: _updatePalettes,
    );
    if (!mounted || picked == null) return;
    _applyPickedBrushColor(picked);
  }

  void _toggleEyedropper() {
    HapticFeedback.selectionClick();
    final next = !_isEyedropperActive;
    setState(() => _isEyedropperActive = next);
    if (next && _canvasBloc.state.activeTray != null) {
      _canvasBloc.add(CanvasToggleTray(_canvasBloc.state.activeTray!));
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (next) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Eyedropper: tap the canvas to sample a color'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    if (_isShapesPopupOpen) {
      setState(() => _isShapesPopupOpen = false);
    }
    if (_canvasBloc.state.activeTray == tray) return;
    HapticFeedback.lightImpact();
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  void _toggleTray(String tray) {
    if (_isShapesPopupOpen) {
      setState(() => _isShapesPopupOpen = false);
    }
    HapticFeedback.lightImpact();
    _canvasBloc.add(CanvasToggleTray(tray));
  }

  Future<void> _openHistoryScreen() async {
    HapticFeedback.lightImpact();
    final historyService = widget.historyService;
    if (historyService == null) return;
    final activeTray = _canvasBloc.state.activeTray;
    if (activeTray != null) {
      _canvasBloc.add(CanvasToggleTray(activeTray));
    }
    _canvasBloc.add(const CanvasHistoryFeedRequested());
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _canvasBloc,
          child: BoardHistoryScreen(
            boardId: widget.boardId,
            boardTitle: _canvasBloc.state.boardTitle,
            bloc: _canvasBloc,
            historyService: historyService,
          ),
        ),
      ),
    );
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

  /// Scrub slider: debounce bursts of drag events so the CRDT replay stays
  /// smooth (one apply per ~90 ms settle instead of per tick).
  void _onScrubSliderChanged(int index) {
    _scrubDebounce?.cancel();
    _scrubDebounce = Timer(const Duration(milliseconds: 90), () {
      _canvasBloc.add(CanvasHistoryScrubMoved(index));
    });
  }

  /// "Restore to this state" inside a scrub session: confirm, then restore to
  /// the selected stop's version (or revert just the selected area when in an
  /// area-history scrub).
  Future<void> _restoreScrubState(CanvasState state) async {
    final scrub = state.historyScrub;
    if (scrub == null) return;
    final stop = scrub.stopAt(state.historyScrubIndex);
    final isAreaScrub = scrub.area != null && scrub.area!.isValid;
    final confirmed = await showInkConfirmDialog(
      context,
      title: isAreaScrub
          ? 'Revert selected area to version ${stop.version}?'
          : 'Restore version ${stop.version}?',
      message: isAreaScrub
          ? 'Only elements inside the selected area will be reverted to version '
                '${stop.version}. The rest of the board stays unchanged.'
          : 'This reverts every change made after version ${stop.version}. '
                'Nothing is deleted from history — you can restore again later.',
      confirmLabel: isAreaScrub ? 'Revert area' : 'Restore',
      destructive: false,
    );
    if (!mounted || !confirmed) return;
    _canvasBloc.add(
      CanvasHistoryRestoreRequested(
        stop.version,
        elementIds:
            (isAreaScrub || scrub.elementIds.isNotEmpty) ? scrub.elementIds : null,
        area: isAreaScrub ? scrub.area : null,
      ),
    );
  }

  /// "Undo [user] after this point": undo only that user's ops after the
  /// selected stop. The revert review sheet is the confirmation step.
  void _undoUserAfterScrub(CanvasState state) {
    final scrub = state.historyScrub;
    if (scrub == null) return;
    final versions = [
      for (var i = state.historyScrubIndex + 1; i < scrub.stops.length; i++)
        scrub.stops[i].version,
    ];
    if (versions.isEmpty) return;
    _canvasBloc.add(CanvasHistoryRevertOpsRequested(versions));
  }

  /// Owner reviewing an undo request's evidence scrub: restore the scope to
  /// the selected stop — everything the requester did to it AFTER this point
  /// (or the whole area state when `scopeMode == areaState`) is reverted.
  void _restoreScrubStateInRequest(CanvasState state) {
    final scrub = state.historyScrub;
    final requestId = state.historyPreviewRequestId;
    if (scrub == null || requestId == null) return;
    final index = state.historyScrubIndex.clamp(0, scrub.lastIndex);
    if (index >= scrub.lastIndex) {
      AppSnackBar.showMessage(
        context,
        'That is the current board — move the slider back to a state to restore.',
      );
      return;
    }
    final stop = scrub.stopAt(index);
    if (scrub.scopeMode == UndoRequestScopeMode.areaState ||
        scrub.targetUid == null) {
      _canvasBloc.add(
        CanvasHistoryRestoreRequested(
          stop.version,
          elementIds: scrub.elementIds,
          area: scrub.area,
          requestId: requestId,
        ),
      );
      return;
    }
    _canvasBloc.add(
      CanvasHistoryRevertOpsAfterRequested(
        targetUid: scrub.targetUid!,
        afterVersion: stop.version,
        elementIds: scrub.elementIds,
        area: scrub.area,
        requestId: requestId,
      ),
    );
  }

  /// Member on their request scrub: open the reason + send sheet with the
  /// selected stop frozen as the desired state (the modal barrier makes the
  /// slider unreachable while the sheet is open).
  void _openUndoRequestSendSheet(CanvasState state) {
    final scrub = state.historyScrub;
    if (scrub == null) return;
    final index = state.historyScrubIndex.clamp(0, scrub.lastIndex);
    final stop = scrub.stopAt(index);
    final diff = scrub.diffAt(index);
    final scopeMode = state.undoRequestDraft?.scopeMode ?? scrub.scopeMode;
    setState(() => _undoRequestSheetOpen = true);
    showUndoRequestSendSheet(
      context,
      targetVersion: stop.version,
      stopLabel: stop.headline,
      elementCount: scrub.elementIds.length,
      canSend: index < scrub.lastIndex,
      scopeMode: scopeMode,
      diffSummary: diff?.summaryLabel,
      onSubmit: (reason) {
        _canvasBloc.add(CanvasUndoRequestSubmitRequested(reason));
      },
    ).whenComplete(() {
      if (mounted) setState(() => _undoRequestSheetOpen = false);
    });
  }

  /// "Revert this change" on a compared log: undo the op(s) behind the view.
  /// The review sheet is the confirmation step, so no extra dialog.
  void _revertPreviewOps(CanvasState state) {
    final versions = state.historyPreviewOpVersions;
    if (versions.isEmpty) return;
    _canvasBloc.add(CanvasHistoryRevertOpsRequested(versions));
  }

  String? _memberDisplayName(CanvasState state, String uid) {
    for (final member in state.boardMembers) {
      if (member.uid == uid) return member.label;
    }
    return null;
  }

  /// Opens the undo-request scope sheet (stage 1). The draft lives in the
  /// bloc; [initialIds]/[initialArea] are FRESH values (e.g. an area just
  /// completed) because `bloc.add` is async and re-reading the state here
  /// would miss the event just dispatched.
  void _openUndoRequestSheet({
    List<String>? initialIds,
    UndoRequestArea? initialArea,
  }) {
    // Only one request can be pending per board: surface the one already with
    // the owner instead of starting a duplicate.
    if (_canvasBloc.state.myPendingUndoRequest != null) {
      AppSnackBar.showMessage(
        context,
        'You already have an undo request waiting for the owner.',
      );
      _canvasBloc.add(const CanvasUndoRequestDraftCleared());
      return;
    }
    final state = _canvasBloc.state;
    final ids = initialIds ?? state.undoRequestDraft?.elementIds ?? const [];
    final area = initialArea ?? state.undoRequestDraft?.area;
    final scopeMode =
        state.undoRequestDraft?.scopeMode ?? UndoRequestScopeMode.myChanges;
    if (initialIds != null) {
      // An explicitly resolved scope (conflict preselect or a just-completed
      // area): restart the draft so stale picks never linger behind the
      // sheet's own tick state.
      _canvasBloc.add(
        CanvasUndoRequestDraftStarted(
          preselectedIds: ids,
          area: area,
          scopeMode: scopeMode,
        ),
      );
    } else if (state.undoRequestDraft == null) {
      _canvasBloc.add(
        CanvasUndoRequestDraftStarted(
          preselectedIds: ids,
          scopeMode: scopeMode,
        ),
      );
    }
    setState(() => _undoRequestSheetOpen = true);
    showUndoRequestSheet(
      context,
      bloc: _canvasBloc,
      elements: _scopeSheetElements(state, ids, area),
      initialIds: ids,
      initialArea: area,
      initialScopeMode: scopeMode,
      onSelectArea: () {
        _canvasBloc.add(
          const CanvasToggleUndoRequestAreaSelection(enable: true),
        );
      },
      onPreview: () {
        _canvasBloc.add(const CanvasUndoRequestPreviewRequested());
      },
    ).whenComplete(() {
      if (mounted) setState(() => _undoRequestSheetOpen = false);
    });
  }

  /// The elements the scope sheet lists: with an area (or a picked scope) only
  /// those elements — the member adjusts within their scope; on a fresh draft
  /// the whole board.
  List<CanvasElement> _scopeSheetElements(
    CanvasState state,
    List<String> ids,
    UndoRequestArea? area,
  ) {
    if (area == null && ids.isEmpty) return state.elements;
    final idSet = ids.toSet();
    return state.elements
        .where((element) => idSet.contains(element.id))
        .toList(growable: false);
  }

  /// User finished drawing an area selection on the canvas (either a member
  /// selecting an undo-request area, or the owner selecting an area to view
  /// only its history).
  void _completeAreaSelection() {
    final rect = _areaSelectionRect;
    final isOwnerHistoryArea = _canvasBloc.state.isSelectingHistoryArea;
    setState(() {
      _areaSelectionStart = null;
      _areaSelectionCurrent = null;
    });
    if (isOwnerHistoryArea) {
      _canvasBloc.add(
        const CanvasToggleOwnerAreaHistorySelection(enable: false),
      );
    } else {
      _canvasBloc.add(
        const CanvasToggleUndoRequestAreaSelection(enable: false),
      );
    }
    if (rect == null || rect.width < 4 || rect.height < 4) {
      if (!isOwnerHistoryArea) {
        _openUndoRequestSheet();
      }
      return;
    }
    final area = UndoRequestArea(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
    final ids = _canvasBloc.state.elements
        .where((element) {
          final bounds = _computeContentBounds([element]);
          return bounds != null && bounds.overlaps(rect);
        })
        .map((element) => element.id)
        .toList(growable: false);
    if (isOwnerHistoryArea) {
      _canvasBloc.add(
        CanvasHistoryAreaScrubRequested(area: area, elementIds: ids),
      );
      return;
    }
    // The newest area is the whole scope: elements picked before it (a
    // double-tapped element or an earlier area's members) are dropped, so the
    // request always reflects exactly what the member just enclosed.
    _canvasBloc.add(CanvasUndoRequestDraftAreaSet(area, ids));
    _openUndoRequestSheet(initialIds: ids, initialArea: area);
  }

  void _maybeFocusHistoryPreview(
    CanvasState state,
    List<CanvasElement> displayElements,
  ) {
    if (!state.isViewingHistory) {
      _historyPreviewFocusKey = null;
      return;
    }
    final key =
        '${state.historyPreviewVersion}|${state.historyPreviewRequestId}|'
        '${state.historyPreviewFocusBounds}|'
        '${state.historyHighlightElementIds.join(',')}';
    if (key == _historyPreviewFocusKey) return;
    _historyPreviewFocusKey = key;

    final size = _lastCanvasSize;
    if (size.width <= 0 || size.height <= 0) return;

    Rect? bounds;
    final focusBounds = state.historyPreviewFocusBounds;
    if (focusBounds != null && focusBounds.width > 0 && focusBounds.height > 0) {
      bounds = focusBounds;
    } else {
      final ids = state.historyHighlightElementIds.toSet();
      final highlighted = ids.isEmpty
          ? const <CanvasElement>[]
          : displayElements
                .where((element) => ids.contains(element.id))
                .toList(growable: false);
      bounds = _computeContentBounds(
        highlighted.isNotEmpty ? highlighted : displayElements,
      );
    }
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) return;

    final padded = bounds.inflate(64);
    final scale = math
        .min(size.width / padded.width, size.height / padded.height)
        .clamp(0.35, 2.8);
    final offset = _centerOffsetForScale(size, padded.center, scale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_canvasBloc.state.isViewingHistory) return;
      _applyViewportTransform(scale: scale, offset: offset);
    });
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

  void _capturePointerPressure(PointerEvent event) {
    _latestPressure = normalizePointerPressure(
      kind: event.kind,
      pressure: event.pressure,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
    );
    _latestTilt = normalizePointerTilt(kind: event.kind, tilt: event.tilt);
  }

  bool _isBrushTool(CanvasToolMode tool) =>
      tool == CanvasToolMode.doodle ||
      tool == CanvasToolMode.highlight ||
      tool == CanvasToolMode.eraser;

  /// Brushes start on the raw pointer-down instead of waiting for the gesture
  /// arena to win. That removes the slop delay that made strokes appear late
  /// and also keeps a pen stroke from being stolen by an element underneath.
  bool _isStylusKind(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  void _handleCanvasPointerDown(PointerDownEvent event, CanvasState state) {
    // Desktop browser only: clicking the board gives it the keyboard
    // shortcuts, and the middle mouse button pans.
    if (SlidingTray.useWebLayout(context) && _webPointerDown(event)) return;
    final kind = event.kind;
    final stylus = _isStylusKind(kind);
    if (stylus) {
      _stylusPointers.add(event.pointer);
      // A palm may land before the pen. Discard that accidental touch stroke
      // and let the stylus take ownership of the canvas.
      final rawKind = _rawStrokeKind;
      if (_rawStrokePointerId != null &&
          rawKind != null &&
          !_isStylusKind(rawKind)) {
        _cancelRawStroke();
      }
    }
    // Palm rejection: once a stylus is in contact, touch pointers are ignored
    // until it lifts.
    if (kind == PointerDeviceKind.touch && _stylusPointers.isNotEmpty) {
      return;
    }
    if (kind == PointerDeviceKind.touch &&
        !state.fingerDrawingEnabled &&
        _isBrushTool(state.currentToolMode)) {
      _activeCanvasPointers[event.pointer] = event.localPosition;
      _activePointerKinds[event.pointer] = kind;
      return;
    }
    _activeCanvasPointers[event.pointer] = event.localPosition;
    _activePointerKinds[event.pointer] = kind;
    if (_textEditor != null ||
        _isEyedropperActive ||
        _isPlacingSymmetryCenter ||
        !state.canEdit ||
        state.isArchived ||
        state.isPaused ||
        state.isViewingHistory ||
        state.isSelectingUndoRequestArea ||
        state.isSelectingHistoryArea ||
        _isPickingUndoRequestScope(state)) {
      return;
    }
    if (kind == PointerDeviceKind.mouse &&
        event.buttons & kPrimaryButton == 0) {
      return;
    }

    if (_activeCanvasPointers.length > 1) {
      if (_rawStrokePointerId != null) {
        _cancelRawStroke();
        _beginPointerTransform();
      }
      return;
    }

    if (!_isBrushTool(state.currentToolMode) || _isTransformingCanvas) return;
    _rawStrokePointerId = event.pointer;
    _rawStrokeKind = kind;
    _rawStrokeLastScreen = event.localPosition;
    final world = _toWorld(event.localPosition);
    _rawStrokeLastWorld = world;
    _showEraserPreview = state.currentToolMode == CanvasToolMode.eraser;
    _startStroke(world);
    _startInkSpillDwellTimer();
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    if (event.pointer == _webMiddlePanPointer) {
      _applyViewportTransform(
        scale: _viewportScale,
        offset: _viewportOffset + event.delta,
      );
      return;
    }
    if (!_activePointerKinds.containsKey(event.pointer)) return;
    _activeCanvasPointers[event.pointer] = event.localPosition;
    if (event.pointer != _rawStrokePointerId) return;

    final rawScreen = event.localPosition;
    final prevScreen = _rawStrokeLastScreen;
    if (prevScreen != null && (rawScreen - prevScreen).distance >= 1.5) {
      _lastSpatialStrokeMoveAt = DateTime.now();
      _inkSpillDwellTicks = 0;
      _rawStrokeLastScreen = rawScreen;
    } else {
      _rawStrokeLastScreen ??= rawScreen;
    }

    final world = _toWorld(rawScreen);
    final previous = _rawStrokeLastWorld;
    if (previous != null && (world - previous).distance < 0.5) return;
    _rawStrokeLastWorld = world;
    _appendStroke(world);
  }

  void _handleCanvasPointerEnd(PointerEvent event) {
    if (event.pointer == _webMiddlePanPointer) {
      _webMiddlePanPointer = null;
      return;
    }
    _activeCanvasPointers.remove(event.pointer);
    _activePointerKinds.remove(event.pointer);
    _stylusPointers.remove(event.pointer);
    if (event.pointer == _rawStrokePointerId) _endRawStroke();
    // ScaleGestureRecognizer normally ends the transform first. Clearing here
    // as well prevents a missed onScaleEnd from leaving the canvas stuck in
    // transform mode, which would ignore the next brush stroke.
    if (_activeCanvasPointers.isEmpty && _isTransformingCanvas) {
      setState(() {
        _isTransformingCanvas = false;
        _pinchIntent = _PinchIntent.undecided;
      });
    }
  }

  void _startInkSpillDwellTimer() {
    _inkSpillTimer?.cancel();
    _inkSpillDwellTicks = 0;
    _lastSpatialStrokeMoveAt = DateTime.now();
    final state = _canvasBloc.state;
    if (!state.boardSettings.inkSpillEnabled ||
        state.currentToolMode == CanvasToolMode.eraser) {
      return;
    }
    _inkSpillTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _rawStrokePointerId == null) {
        timer.cancel();
        return;
      }
      final liveState = _canvasBloc.state;
      if (!liveState.boardSettings.inkSpillEnabled ||
          liveState.currentToolMode == CanvasToolMode.eraser ||
          liveState.currentStroke.isEmpty) {
        return;
      }
      final spot = _rawStrokeLastWorld;
      if (spot == null) return;
      final stationaryDuration = DateTime.now().difference(
        _lastSpatialStrokeMoveAt,
      );
      if (stationaryDuration < const Duration(milliseconds: 110)) {
        return;
      }
      if (_inkSpillDwellTicks >= 28) return;
      _inkSpillDwellTicks++;
      final basePressure = liveState.stylusPressureEnabled
          ? _latestPressure.clamp(0.25, 1.0)
          : 1.0;
      final dwellPressure = (basePressure + _inkSpillDwellTicks * 0.05).clamp(
        0.3,
        2.35,
      );
      final angle = _inkSpillDwellTicks * 2.399963229728653; // Golden angle
      final radius =
          (liveState.strokeWidth * 0.015 * math.sqrt(_inkSpillDwellTicks))
              .clamp(0.02, 0.32);
      final dwellPoint =
          spot + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      // Do NOT update _lastStrokeMoveAt here so QuickShape hold timing still
      // works if the user drew a shape and held at the end.
      _canvasBloc.add(
        CanvasAppendStroke(
          dwellPoint,
          pressure: dwellPressure,
          tilt: _latestTilt,
        ),
      );
    });
  }

  void _cancelRawStroke() {
    _inkSpillTimer?.cancel();
    _inkSpillTimer = null;
    _inkSpillDwellTicks = 0;
    if (_rawStrokePointerId == null) return;
    _rawStrokePointerId = null;
    _rawStrokeKind = null;
    _rawStrokeLastWorld = null;
    _rawStrokeLastScreen = null;
    _showEraserPreview = false;
    _canvasBloc.add(const CanvasCancelStroke());
  }

  void _endRawStroke() {
    _inkSpillTimer?.cancel();
    _inkSpillTimer = null;
    _inkSpillDwellTicks = 0;
    if (_rawStrokePointerId == null) return;
    _rawStrokePointerId = null;
    _rawStrokeKind = null;
    _rawStrokeLastWorld = null;
    _rawStrokeLastScreen = null;
    _showEraserPreview = false;
    _endStroke();
  }

  void _beginPointerTransform() {
    if (_activeCanvasPointers.length < 2) return;
    final points = _activeCanvasPointers.values.take(2).toList(growable: false);
    setState(() {
      _isTransformingCanvas = true;
      _gestureStartScale = _viewportScale;
      _gestureStartOffset = _viewportOffset;
      _gestureStartFocal = (points[0] + points[1]) / 2;
      _pinchIntent = _PinchIntent.undecided;
    });
  }

  void _startStroke(Offset point) {
    _lastStrokeMoveAt = DateTime.now();
    _canvasBloc.add(
      CanvasStartStroke(point, pressure: _latestPressure, tilt: _latestTilt),
    );
  }

  void _appendStroke(Offset point) {
    _lastStrokeMoveAt = DateTime.now();
    _canvasBloc.add(
      CanvasAppendStroke(point, pressure: _latestPressure, tilt: _latestTilt),
    );
  }

  void _endStroke() {
    final state = _canvasBloc.state;
    final heldLongEnough =
        DateTime.now().difference(_lastStrokeMoveAt) >=
        const Duration(milliseconds: 450);
    if (state.quickShapeEnabled &&
        state.currentToolMode == CanvasToolMode.doodle &&
        state.currentStroke.length >= 12 &&
        heldLongEnough) {
      var candidatePoints = state.currentStroke;
      if (state.boardSettings.inkSpillEnabled && candidatePoints.length > 14) {
        final anchor = candidatePoints.last;
        var trimEnd = candidatePoints.length;
        while (trimEnd > 12 &&
            (candidatePoints[trimEnd - 2] - anchor).distance < 1.0) {
          trimEnd--;
        }
        if (trimEnd < candidatePoints.length) {
          candidatePoints = candidatePoints.sublist(0, trimEnd);
        }
      }
      final match = recognizeQuickShape(candidatePoints);
      if (match != null) {
        _canvasBloc.add(
          CanvasCommitQuickShape(
            match: match,
            points: List<Offset>.of(state.currentStroke),
            pressures: List<double>.of(state.currentStrokePressures),
            tilts: List<double>.of(state.currentStrokeTilts),
          ),
        );
        return;
      }
    }
    final knownStrokeIds = state.elements
        .whereType<StrokeElement>()
        .map((stroke) => stroke.id)
        .toSet();
    _canvasBloc.add(CanvasEndStroke(smoothAfterDrawing: _smoothDoodlesEnabled));
    if (state.currentToolMode == CanvasToolMode.doodle) {
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted || _closedStrokeHintShown) return;
        final added = _canvasBloc.state.elements
            .whereType<StrokeElement>()
            .where(
              (stroke) =>
                  !knownStrokeIds.contains(stroke.id) &&
                  stroke.fillColor == null &&
                  strokeClosedFillPath(stroke) != null,
            );
        if (added.isEmpty) return;
        _closedStrokeHintShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Closed shape — select it and tap Fill to colour the inside.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      });
    }
  }

  Offset _getElementWorldCenter(CanvasElement element) {
    return switch (element) {
      StrokeElement e => _strokeCenter(e.points),
      ShapeElement e => e.center,
      TextElement e => e.center,
      ImageElement e => e.center,
      StickyNoteElement e => e.center,
      FrameElement e => e.center,
      TableElement e => e.center,
      ConnectorElement e => Offset(
        (e.startPoint.dx + e.endPoint.dx) / 2,
        (e.startPoint.dy + e.endPoint.dy) / 2,
      ),
      LayerElement _ => Offset.zero,
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

  void _selectShape(
    String? shapeId, {
    bool expandEditor = false,
    bool centerView = true,
  }) {
    // Commit any pending edits before selecting a different shape
    _commitPendingShapeEdits();

    if (shapeId != null && centerView) {
      final elements = _canvasBloc.state.elements;
      try {
        final element = elements.firstWhere((e) => e.id == shapeId);
        _centerViewportOn(_getElementWorldCenter(element));
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _elementEditorDismissed = false;
        _activeEditControl = null;
      });
    }
    _canvasBloc.add(CanvasSelectShape(shapeId));
  }

  void _moveSelectedShape(Offset center) {
    _canvasBloc.add(CanvasMoveSelectedShape(center));
  }

  void _resizeSelectedShape(
    double size, {
    double width = 0,
    double height = 0,
  }) {
    _canvasBloc.add(
      CanvasResizeSelectedShape(size, width: width, height: height),
    );
  }

  Future<void> _pickShapeFillColor({
    bool gradientEnd = false,
    bool solidFill = false,
  }) async {
    final shape = _canvasBloc.state.elements
        .whereType<ShapeElement>()
        .where((s) => s.id == _canvasBloc.state.selectedShapeId)
        .firstOrNull;
    if (shape == null) return;
    final initial = gradientEnd
        ? shape.resolvedGradientEnd
        : shape.resolvedFillColor;
    final picked = await showCanvasColorPicker(
      context,
      initialColor: initial,
      recentColors: _recentColors,
      palettes: _palettes,
      onPalettesChanged: _updatePalettes,
    );
    if (!mounted || picked == null) return;
    final opaque = picked.withValues(alpha: 1);
    _canvasBloc.add(
      CanvasUpdateShapeFill(
        fillMode: solidFill && !gradientEnd ? 'solid' : null,
        fillColor: gradientEnd ? null : opaque,
        gradientStart: gradientEnd ? null : opaque,
        gradientEnd: gradientEnd ? opaque : null,
      ),
    );
  }

  void _rotateSelectedShape(double rotation) {
    _canvasBloc.add(CanvasRotateSelectedShape(rotation));
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
    if (!editing) {
      _stopEdgeAutoPan();
    }
    if (_isEditingShape == editing) return;
    setState(() => _isEditingShape = editing);
  }

  Offset? _globalToCanvasLocal(Offset globalPosition) {
    final canvasBox =
        _canvasPreviewKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox != null && canvasBox.hasSize) {
      return canvasBox.globalToLocal(globalPosition);
    }
    final rootBox = context.findRenderObject() as RenderBox?;
    if (rootBox != null && rootBox.hasSize) {
      return rootBox.globalToLocal(globalPosition);
    }
    return null;
  }

  void _updateEdgeAutoPan(Offset localPosition, {required bool fromOverlay}) {
    _edgeAutoPanLocalPos = localPosition;
    _edgeAutoPanFromOverlay = fromOverlay;
    final step = canvasEdgeAutoPanDelta(
      localPosition: localPosition,
      canvasSize: _lastCanvasSize,
    );
    if (step == Offset.zero) {
      _edgeAutoPanTimer?.cancel();
      _edgeAutoPanTimer = null;
      return;
    }
    _edgeAutoPanTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickEdgeAutoPan(),
    );
  }

  void _stopEdgeAutoPan() {
    _edgeAutoPanTimer?.cancel();
    _edgeAutoPanTimer = null;
    _edgeAutoPanLocalPos = null;
    _edgeAutoPanFromOverlay = false;
  }

  void _tickEdgeAutoPan() {
    if (!mounted) {
      _stopEdgeAutoPan();
      return;
    }
    final localPos = _edgeAutoPanLocalPos;
    if (localPos == null) {
      _stopEdgeAutoPan();
      return;
    }
    final panDelta = canvasEdgeAutoPanDelta(
      localPosition: localPos,
      canvasSize: _lastCanvasSize,
    );
    if (panDelta == Offset.zero) {
      _edgeAutoPanTimer?.cancel();
      _edgeAutoPanTimer = null;
      return;
    }

    final worldShift = -panDelta / _viewportScale;
    final state = _canvasBloc.state;

    if (_edgeAutoPanFromOverlay) {
      final draft = _shapeTransformDraft;
      if (draft == null || _isRotatingShape || _isResizingShape) {
        _stopEdgeAutoPan();
        return;
      }
      _overlayDragStartCenter += worldShift;
      final rawCenter = draft.center + worldShift;
      final mapped = _mapElements(state.elements);
      final baseShape = mapped.where((e) => e.id == draft.shapeId).firstOrNull;
      final nextCenter = baseShape == null
          ? rawCenter
          : _snapElementCenterDrag(state, baseShape, rawCenter);
      setState(() {
        _viewportOffset += panDelta;
        _shapeTransformDraft = draft.copyWith(center: nextCenter);
      });
      if (baseShape?.kind == _ElementKind.image) {
        _canvasBloc.add(
          CanvasPreviewImageElement(
            elementId: draft.shapeId,
            center: nextCenter,
            width: draft.width ?? baseShape!.width,
            height: draft.height ?? baseShape!.height,
          ),
        );
      } else {
        _canvasBloc.add(CanvasPreviewMoveSelectedShape(nextCenter));
      }
      return;
    }

    if (_isDraggingShape && _groupDragDelta != null) {
      final nextOffset = _viewportOffset + panDelta;
      final worldPoint = (localPos - nextOffset) / _viewportScale;
      final nextDelta = _snapGroupDragDelta(
        state,
        worldPoint - _shapeDragStartWorldPoint,
      );
      setState(() {
        _viewportOffset = nextOffset;
        _groupDragDelta = nextDelta;
      });
      return;
    }

    if (_isDraggingStroke) {
      final nextOffset = _viewportOffset + panDelta;
      final worldPoint = (localPos - nextOffset) / _viewportScale;
      setState(() {
        _viewportOffset = nextOffset;
        _strokeDragDelta = worldPoint - _strokeDragStartWorldPoint;
      });
      return;
    }

    if (_isDraggingShape) {
      final nextOffset = _viewportOffset + panDelta;
      final worldPoint = (localPos - nextOffset) / _viewportScale;
      final rawCenter =
          _shapeDragStartCenter + (worldPoint - _shapeDragStartWorldPoint);
      final dragged = _mapElements(
        state.elements,
      ).where((e) => e.id == state.selectedShapeId).firstOrNull;
      final nextCenter = dragged == null
          ? rawCenter
          : _snapElementCenterDrag(state, dragged, rawCenter);
      setState(() {
        _viewportOffset = nextOffset;
        _shapeDragPreviewCenter = nextCenter;
        _connectorDragDelta = nextCenter - _shapeDragStartCenter;
      });
      _canvasBloc.add(CanvasPreviewMoveSelectedShape(nextCenter));
      return;
    }

    _stopEdgeAutoPan();
  }

  void _selectShapeForDrawing(CanvasShapeType shapeType) {
    setState(() {
      _isShapesPopupOpen = false;
    });
    _canvasBloc.add(
      CanvasSetToolMode(CanvasToolMode.shape, shapeType: shapeType),
    );
  }

  void _addAiTextElement() {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    _canvasBloc.add(CanvasAddAiText(prompt, _canvasBloc.randomTextCenter()));
    _aiPromptController.clear();
  }

  void _onGenerateImagePlaceholder() {
    AppSnackBar.showMessage(context, 'AI image generation is coming soon.');
  }

  // ──────────────────────────────────────────────
  // AI images
  // ──────────────────────────────────────────────

  bool _canUseAi(CanvasState state) =>
      state.currentUserRole != Board.roleViewer;

  void _generateAiImage() {
    final bloc = _aiImageBloc;
    final prompt = _aiPromptController.text.trim();
    if (bloc == null || !isValidAiPrompt(prompt)) return;
    if (!_canUseAi(_canvasBloc.state)) return;

    // Centre of what the user is looking at, in canvas coordinates.
    final center = _toWorld(
      Offset(_lastCanvasSize.width / 2, _lastCanvasSize.height / 2),
    );
    final size = aiCanvasSizeForAspectRatio(_aiAspectRatio);
    bloc.add(
      AiImageGenerateRequested(
        boardId: widget.boardId,
        prompt: prompt,
        aspectRatio: _aiAspectRatio,
        center: center,
        width: size.width,
        height: size.height,
      ),
    );
    _aiPromptController.clear();
    // Close the tray so the placeholder is visible.
    if (_canvasBloc.state.activeTray == 'ai') {
      _toggleTray('ai');
    }
  }

  /// Applies finished AI requests to the board and shows failures once.
  void _onAiImageState(AiImageState aiState) {
    if (!mounted) return;

    final completion = aiState.lastCompletion;
    if (completion != null && completion.sequence > _lastAiCompletionSequence) {
      _lastAiCompletionSequence = completion.sequence;
      final result = completion.result;
      _recordRecentAiImage(
        key: result.generationId.isNotEmpty
            ? result.generationId
            : result.imageUrl,
        thumbnailBase64: result.thumbnailBase64,
        fallbackBytes: aiState.imageBytes[result.imageUrl],
      );
      final placeholder = completion.placeholder;
      if (placeholder != null) {
        // Follow the real image's aspect ratio (the fallback model is square).
        final ratio = result.width / result.height;
        final longest = math.max(placeholder.width, placeholder.height);
        final width = ratio >= 1 ? longest : longest * ratio;
        final height = ratio >= 1 ? longest / ratio : longest;
        _canvasBloc.add(
          CanvasAddAiImageElement(
            imageUrl: result.imageUrl,
            thumbnailBase64: result.thumbnailBase64,
            center: placeholder.center,
            width: width,
            height: height,
            aiPrompt: completion.prompt,
            generationId: result.generationId,
          ),
        );
      } else if (completion.elementId != null) {
        _canvasBloc.add(
          CanvasReplaceImageSource(
            elementId: completion.elementId!,
            imageUrl: result.imageUrl,
            thumbnailBase64: result.thumbnailBase64,
            sourceWidth: result.width,
            sourceHeight: result.height,
            aiPrompt: completion.prompt,
            generationId: result.generationId,
          ),
        );
      }
    }

    final failure = aiState.lastFailure;
    if (failure != null && failure.sequence > _lastAiFailureSequence) {
      _lastAiFailureSequence = failure.sequence;
      AppSnackBar.showError(
        context,
        AppErrorFormatter.cleanMessage(
          failure.message,
          fallback: 'The AI image request failed. Please try again.',
        ),
      );
    }

    // Placeholders, busy overlays and downloaded images all need a repaint.
    setState(() {});
  }

  void _recordRecentAiImage({
    required String key,
    required String thumbnailBase64,
    Uint8List? fallbackBytes,
  }) {
    Uint8List? bytes;
    if (thumbnailBase64.isNotEmpty) {
      try {
        bytes = base64Decode(thumbnailBase64);
      } catch (_) {}
    }
    bytes ??= fallbackBytes;
    if (bytes == null || bytes.isEmpty) return;
    _recentAiImages.removeWhere((entry) => entry.key == key);
    _recentAiImages.insert(0, (key: key, bytes: bytes));
    if (_recentAiImages.length > 10) {
      _recentAiImages.removeLast();
    }
  }

  List<Uint8List> _collectRecentAiImages(CanvasState state) {
    final result = <Uint8List>[
      for (final entry in _recentAiImages) entry.bytes,
    ];
    if (result.length >= 10) return result;
    final seenKeys = <String>{
      for (final entry in _recentAiImages) entry.key,
    };
    final aiBytes = _aiImageBloc?.state.imageBytes;
    for (final element in state.elements.reversed) {
      if (element is! ImageElement || !element.isAiImage) continue;
      final key = (element.generationId != null &&
              element.generationId!.isNotEmpty)
          ? element.generationId!
          : (element.imageUrl ?? element.id);
      if (!seenKeys.add(key)) continue;
      final imageUrl = element.imageUrl;
      Uint8List? bytes = (imageUrl != null && aiBytes != null)
          ? aiBytes[imageUrl]
          : null;
      if (bytes == null && element.imageBase64.isNotEmpty) {
        try {
          bytes = base64Decode(element.imageBase64);
        } catch (_) {}
      }
      if (bytes != null && bytes.isNotEmpty) {
        result.add(bytes);
        if (result.length >= 10) break;
      }
    }
    return result;
  }

  ImageElement? _selectedAiImage(CanvasState state) {
    final id = state.selectedShapeId;
    if (id == null) return null;
    for (final element in state.elements) {
      if (element.id == id && element is ImageElement && element.isAiImage) {
        return element;
      }
    }
    return null;
  }

  Future<void> _editSelectedImageWithAi(ImageElement image) async {
    final bloc = _aiImageBloc;
    final url = image.imageUrl;
    if (bloc == null || url == null) return;
    final prompt = await showAiPromptDialog(
      context,
      title: 'Edit with AI',
      hintText: 'Describe the change, for example "make it night time"',
    );
    if (prompt == null || !mounted) return;
    bloc.add(
      AiImageEditRequested(
        boardId: widget.boardId,
        elementId: image.id,
        sourceImageUrl: url,
        prompt: prompt,
      ),
    );
  }

  Future<void> _repaintSelectedImageArea(ImageElement image) async {
    final bloc = _aiImageBloc;
    final url = image.imageUrl;
    if (bloc == null || url == null) return;
    final bytes = bloc.state.imageBytes[url];
    if (bytes == null) {
      AppSnackBar.showMessage(
        context,
        'The image is still loading. Try again in a moment.',
      );
      return;
    }
    final result = await Navigator.of(context).push<AiRepaintResult>(
      MaterialPageRoute(builder: (_) => AiRepaintScreen(imageBytes: bytes)),
    );
    if (result == null || !mounted) return;
    bloc.add(
      AiImageInpaintRequested(
        boardId: widget.boardId,
        elementId: image.id,
        sourceImageUrl: url,
        maskPng: result.maskPng,
        prompt: result.prompt,
      ),
    );
  }

  void _regenerateSelectedImage(ImageElement image) {
    final bloc = _aiImageBloc;
    final prompt = image.aiPrompt;
    if (bloc == null) return;
    if (prompt == null || !isValidAiPrompt(prompt)) {
      AppSnackBar.showMessage(
        context,
        'This image has no saved prompt to regenerate from.',
      );
      return;
    }
    bloc.add(
      AiImageRegenerateRequested(
        boardId: widget.boardId,
        elementId: image.id,
        prompt: prompt,
        aspectRatio: aiNearestAspectRatio(image.width, image.height),
      ),
    );
  }

  /// Local-only loading boxes for images being generated, plus a dimmed
  /// spinner over images that are being edited.
  List<Widget> _buildAiImageOverlays(CanvasState state) {
    final aiState = _aiImageBloc?.state;
    if (aiState == null) return const <Widget>[];
    final widgets = <Widget>[];

    Widget positioned(Offset center, double width, double height, Widget child) {
      final topLeft = _toScreen(
        Offset(center.dx - width / 2, center.dy - height / 2),
      );
      return Positioned(
        left: topLeft.dx,
        top: topLeft.dy,
        width: width * _viewportScale,
        height: height * _viewportScale,
        child: IgnorePointer(child: child),
      );
    }

    for (final placeholder in aiState.placeholders) {
      widgets.add(
        positioned(
          placeholder.center,
          placeholder.width,
          placeholder.height,
          AiImagePlaceholderBox(prompt: placeholder.prompt),
        ),
      );
    }
    if (aiState.busyElementIds.isNotEmpty) {
      for (final element in state.elements) {
        if (element is ImageElement &&
            aiState.busyElementIds.contains(element.id)) {
          widgets.add(
            positioned(
              element.center,
              element.width,
              element.height,
              const AiImageBusyOverlay(),
            ),
          );
        }
      }
    }
    return widgets;
  }

  /// Action bar under the selected AI image. Hidden while it is dragged.
  Widget _buildAiImageActionBar(CanvasState state) {
    final image = _selectedAiImage(state);
    if (!_aiImageEnabled || image == null || _isEditingShape) {
      return const SizedBox.shrink();
    }
    final anchor = _toScreen(
      Offset(image.center.dx, image.center.dy + image.height / 2),
    );
    return Positioned(
      left: anchor.dx,
      top: anchor.dy + 28,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: AiImageActionBar(
          canEdit: _canUseAi(state),
          isBusy: _aiImageBloc?.state.busyElementIds.contains(image.id) ?? false,
          onEditWithAi: () => _editSelectedImageWithAi(image),
          onRepaintArea: () => _repaintSelectedImageArea(image),
          onRegenerate: () => _regenerateSelectedImage(image),
        ),
      ),
    );
  }

  Future<void> _uploadImageToCanvas([
    ImageSource? directSource,
    String? replaceElementId,
  ]) async {
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
          Widget option(
            IconData icon,
            String title,
            String subtitle,
            ImageSource src,
          ) {
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
                          borderRadius: BorderRadius.circular(
                            InkRadii.chip + 2,
                          ),
                        ),
                        child: Icon(icon, size: 20, color: tokens.accentText),
                      ),
                      const SizedBox(width: InkSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: InkType.bodyStrong(tokens.ink)),
                            Text(
                              subtitle,
                              style: InkType.caption(tokens.inkMuted),
                            ),
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
        maxWidth: 2048,
        maxHeight: 2048,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isNoCamera =
          e.code == 'no_available_camera' ||
          (e.message?.toLowerCase().contains('no camera') ?? false);
      final isDenied =
          e.code == 'camera_access_denied' ||
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
      final result = await navigator.push<MediaEditorResult>(
        MaterialPageRoute(
          builder: (_) => MediaEditorScreen(imageBytes: rawBytes),
        ),
      );
      if (result == null || result.imageBytes.isEmpty || !mounted) return;
      final edited = result.imageBytes;
      if (replaceElementId != null) {
        _canvasBloc.add(
          CanvasReplaceImageElement(
            replaceElementId,
            edited,
            style: result.style,
          ),
        );
        return;
      }
      final fullSize = await _readImageSize(edited);
      final sourceSize = Size(
        fullSize.width * result.style.crop.width,
        fullSize.height * result.style.crop.height,
      );
      if (!mounted) return;

      final maxSide = math.max(sourceSize.width, sourceSize.height);
      final fitScale = maxSide > 280 ? (280 / maxSide) : 1.0;
      final width = (sourceSize.width * fitScale).clamp(1, 720).toDouble();
      final height = (sourceSize.height * fitScale).clamp(1, 720).toDouble();

      _canvasBloc.add(
        CanvasAddImageElement(
          edited,
          _canvasBloc.randomShapeCenter(),
          width: width,
          height: height,
          style: result.style,
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

    final removedIds = _decodedUiImages.keys
        .where((id) => !activeIds.contains(id))
        .toList();
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
      // URL images (AI): draw the full image once it is downloaded; until
      // then (or if the download fails) the inline thumbnail is drawn through
      // the unchanged path below.
      Uint8List? urlBytes;
      final imageUrl = element.imageUrl;
      final aiImageBloc = _aiImageBloc;
      if (imageUrl != null && aiImageBloc != null) {
        urlBytes = aiImageBloc.state.imageBytes[imageUrl];
        if (urlBytes == null && _requestedAiImageUrls.add(imageUrl)) {
          aiImageBloc.add(AiImageBytesRequested(imageUrl));
        }
      }
      if (base64Str.isEmpty && urlBytes == null) continue;
      final key = urlBytes != null
          ? 'url:$imageUrl'
          : '${base64Str.length}:${base64Str.hashCode}';
      if (_decodedUiImages.containsKey(element.id) &&
          _decodedUiImageKeys[element.id] == key) {
        continue;
      }
      if (_pendingDecodeImageIds.contains(element.id)) {
        continue;
      }
      _pendingDecodeImageIds.add(element.id);
      _decodeUiImage(element.id, base64Str, key, urlBytes: urlBytes);
    }
  }

  Future<void> _decodeUiImage(
    String id,
    String base64Str,
    String key, {
    Uint8List? urlBytes,
  }) async {
    try {
      final Uint8List bytes;
      if (urlBytes != null) {
        bytes = urlBytes;
      } else {
        final cleanBase64 = base64Str.trim().replaceAll(RegExp(r'\s+'), '');
        if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64)) return;
        bytes = base64Decode(cleanBase64);
      }
      final codec = await ui.instantiateImageCodec(bytes);
      ui.FrameInfo frame;
      try {
        frame = await codec.getNextFrame();
      } finally {
        codec.dispose();
      }
      final current = _canvasBloc.state.elements
          .whereType<ImageElement>()
          .where((element) => element.id == id)
          .firstOrNull;
      if (!mounted || current?.imageBase64 != base64Str) {
        frame.image.dispose();
        if (mounted) setState(() {});
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
      AppSnackBar.showMessage(context, 'No canvas content to fit yet.');
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
    final visible = elements.where((e) => !e.hidden).toList(growable: false);
    if (visible.isEmpty) return null;
    final elementById = {for (final element in visible) element.id: element};
    Rect? bounds;

    for (final element in visible) {
      final Rect? candidate;
      if (element is ConnectorElement) {
        final (start, end) = resolveConnectorEndpoints(element, elementById);
        candidate = elementBounds(
          ConnectorElement(
            id: element.id,
            z: element.z,
            hidden: element.hidden,
            locked: element.locked,
            opacity: element.opacity,
            startElementId: element.startElementId,
            startPoint: start,
            startAnchor: element.startAnchor,
            endElementId: element.endElementId,
            endPoint: end,
            endAnchor: element.endAnchor,
            lineStyle: element.lineStyle,
            color: element.color,
            strokeWidth: element.strokeWidth,
            hasArrowhead: element.hasArrowhead,
          ),
          padding: 8,
        );
      } else {
        candidate = elementBounds(element, padding: 8);
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

  Offset _viewportWorldCenter() {
    final size = _lastCanvasSize.isEmpty
        ? MediaQuery.sizeOf(context)
        : _lastCanvasSize;
    return _toWorld(Offset(size.width / 2, size.height / 2));
  }

  Offset _snapElementCenterDrag(
    CanvasState state,
    _CanvasElement element,
    Offset proposedCenter,
  ) {
    if (!state.boardSettings.snapEnabled ||
        HardwareKeyboard.instance.isAltPressed) {
      return proposedCenter;
    }
    final source = state.elements
        .where((e) => e.id == element.id)
        .firstOrNull;
    if (source == null) return proposedCenter;
    final baseBounds = elementBounds(source);
    if (baseBounds == null) return proposedCenter;
    final shifted = baseBounds.shift(proposedCenter - element.center);
    final adj = snapBoundsAdjustment(
      shifted,
      state.boardSettings,
      viewportScale: _viewportScale,
    );
    return proposedCenter + adj;
  }

  Offset _snapGroupDragDelta(CanvasState state, Offset delta) {
    if (!state.boardSettings.snapEnabled ||
        HardwareKeyboard.instance.isAltPressed) {
      return delta;
    }
    final bounds = _selectionWorldBounds();
    if (bounds == null) return delta;
    final adj = snapBoundsAdjustment(
      bounds.shift(delta),
      state.boardSettings,
      viewportScale: _viewportScale,
    );
    return delta + adj;
  }

  Set<String> _frameDragHighlightedIds(CanvasState state) => const {};

  Future<void> _confirmDeleteFrame(String frameId) async {
    if (!_canvasBloc.state.canEdit) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => InkDialog(
        title: 'Delete Frame',
        content: const Text(
          'Choose whether to remove only the frame border or also delete all items inside it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'frame_only'),
            child: const Text('Frame only'),
          ),
          InkButton.primary(
            label: 'Frame & contents',
            onPressed: () => Navigator.pop(ctx, 'with_contents'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    _canvasBloc.add(
      CanvasDeleteFrame(
        frameId,
        deleteContents: action == 'with_contents',
      ),
    );
  }

  Future<void> _editFrameTitleDialog(FrameElement frame) async {
    if (!_canvasBloc.state.canEdit) return;
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (_) => _FrameTitleDialog(initialTitle: frame.title),
    );
    if (!mounted || nextTitle == null) return;
    _canvasBloc.add(
      CanvasUpdateFrame(elementId: frame.id, title: nextTitle),
    );
  }

  Future<void> _addTableDialog() async {
    if (!_canvasBloc.state.canEdit) return;
    var rows = 3;
    var cols = 3;
    var headerRow = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => InkDialog(
          title: 'Insert Table',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Rows')),
                  DropdownButton<int>(
                    value: rows,
                    items: [
                      for (var r = 1; r <= 8; r++)
                        DropdownMenuItem(value: r, child: Text('$r')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => rows = v);
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('Columns')),
                  DropdownButton<int>(
                    value: cols,
                    items: [
                      for (var c = 1; c <= 8; c++)
                        DropdownMenuItem(value: c, child: Text('$c')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => cols = v);
                    },
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                activeColor: Colors.white,
                activeTrackColor: _tokens.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Header row'),
                value: headerRow,
                onChanged: (v) => setDialogState(() => headerRow = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            InkButton.primary(
              label: 'Insert Table',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    final width = (cols * 120.0).clamp(220.0, 960.0);
    final height = (rows * 56.0).clamp(112.0, 640.0);
    _canvasBloc.add(
      CanvasAddTable(
        center: _viewportWorldCenter(),
        rows: rows,
        columns: cols,
        width: width,
        height: height,
        headerRow: headerRow,
      ),
    );
  }

  Future<void> _editTableCellDialog(
    TableElement initialTable, {
    int initialRow = 0,
    int initialCol = 0,
  }) async {
    if (!_canvasBloc.state.canEdit) return;
    var activeRow = initialRow.clamp(0, initialTable.rows - 1);
    var activeCol = initialCol.clamp(0, initialTable.columns - 1);
    TableElement currentTable() {
      final found = _canvasBloc.state.elements
          .whereType<TableElement>()
          .where((t) => t.id == initialTable.id)
          .firstOrNull;
      return found ?? initialTable;
    }

    var table = currentTable();
    var cell = table.cellAt(activeRow, activeCol);
    final controller = TextEditingController(text: cell.text);
    var textAlign = cell.textAlign;
    var bold =
        (cell.fontWeight ?? 400) >= 600 || (table.headerRow && activeRow == 0);
    var cellBg = cell.backgroundColor;

    void loadCell(int r, int c) {
      table = currentTable();
      activeRow = r.clamp(0, table.rows - 1);
      activeCol = c.clamp(0, table.columns - 1);
      cell = table.cellAt(activeRow, activeCol);
      controller.text = cell.text;
      textAlign = cell.textAlign;
      bold =
          (cell.fontWeight ?? 400) >= 600 ||
          (table.headerRow && activeRow == 0);
      cellBg = cell.backgroundColor;
    }

    void commitCell() {
      _canvasBloc.add(
        CanvasUpdateTableCell(
          tableId: initialTable.id,
          row: activeRow,
          column: activeCol,
          text: controller.text,
          textAlign: textAlign,
          fontWeight: bold ? 700 : 400,
          backgroundColor: cellBg,
          clearBackgroundColor: cellBg == null,
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => _DialogDisposeScope(
        onDispose: controller.dispose,
        child: StatefulBuilder(
        builder: (ctx, setDialogState) {
          table = currentTable();
          return InkDialog(
            title: 'Edit Cell (${activeRow + 1}, ${activeCol + 1})',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap a cell to switch',
                    style: InkType.caption(_tokens.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var r = 0; r < table.rows; r++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var c = 0; c < table.columns; c++)
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    commitCell();
                                    setDialogState(() => loadCell(r, c));
                                  },
                                  child: Container(
                                    height: 26,
                                    margin: const EdgeInsets.all(1.5),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: r == activeRow && c == activeCol
                                          ? _tokens.accent.withValues(
                                              alpha: 0.16,
                                            )
                                          : table.cellAt(r, c).backgroundColor ??
                                                _tokens.field,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: r == activeRow && c == activeCol
                                            ? _tokens.accent
                                            : _tokens.ink.withValues(
                                                alpha: 0.2,
                                              ),
                                        width: r == activeRow && c == activeCol
                                            ? 1.5
                                            : 1,
                                      ),
                                    ),
                                    child: Text(
                                      table.cellAt(r, c).text.isEmpty
                                          ? '${r + 1}:${c + 1}'
                                          : table.cellAt(r, c).text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: table.cellAt(r, c).text.isEmpty
                                            ? _tokens.inkMuted
                                            : _tokens.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkTextField(
                    controller: controller,
                    labelText: 'Cell text',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final align in const ['left', 'center', 'right'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              align[0].toUpperCase() + align.substring(1),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: textAlign == align,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                setDialogState(() => textAlign = align),
                          ),
                        ),
                      FilterChip(
                        label: const Text(
                          'Bold',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: bold,
                        visualDensity: VisualDensity.compact,
                        onSelected: (v) => setDialogState(() => bold = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'Auto fill',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: cellBg == null,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            setDialogState(() => cellBg = null),
                      ),
                      for (final c in const [
                        Color(0xFFFEF3C7),
                        Color(0xFFDBEAFE),
                        Color(0xFFDCFCE7),
                        Color(0xFFFEE2E2),
                        Color(0xFFF3E8FF),
                      ])
                        _fillSwatch(
                          color: c,
                          selected: cellBg == c,
                          onTap: () => setDialogState(() => cellBg = c),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              InkButton.primary(
                label: 'Save',
                onPressed: () {
                  commitCell();
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  void _showCanvasContextMenu(
    CanvasState state,
    List<_CanvasElement> mappedElements,
    Offset localPosition,
  ) {
    if (_isTransformingCanvas ||
        _rawStrokePointerId != null ||
        _activeCanvasPointers.length > 1 ||
        _textEditor != null ||
        state.isViewingHistory ||
        state.isSelectingUndoRequestArea ||
        state.isSelectingHistoryArea ||
        _isPickingUndoRequestScope(state)) {
      return;
    }
    setState(() {
      _isMarqueeSelecting = false;
      _marqueeStart = null;
      _marqueeCurrent = null;
      _isLassoSelecting = false;
      _lassoPoints = null;
      _isDraggingShape = false;
      _isDraggingStroke = false;
    });
    final worldPoint = _toWorld(localPosition);
    final hitId = _hitTestShape(mappedElements, worldPoint);
    final hitElement = hitId == null
        ? null
        : state.elements.where((e) => e.id == hitId).firstOrNull;
    if (hitId != null && !state.selectedIds.contains(hitId)) {
      _selectShape(hitId);
    }

    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final tokens = sheetCtx.ink;
        Widget item(
          IconData icon,
          String label,
          VoidCallback onTap, {
          bool danger = false,
        }) {
          final color = danger ? tokens.danger : tokens.ink;
          return ListTile(
            dense: true,
            leading: Icon(icon, size: 18, color: color),
            title: Text(label, style: InkType.bodyStrong(color)),
            onTap: () {
              Navigator.pop(sheetCtx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(InkSpacing.s12),
            child: GlassPanel(
              radius: InkRadii.bottomSheet,
              padding: const EdgeInsets.symmetric(vertical: InkSpacing.s8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hitElement != null) ...[
                    if (state.canEdit && hitElement is TextElement)
                      item(
                        LucideIcons.pencil,
                        'Edit text',
                        () => _beginTextEditing(hitElement, hitElement.center),
                      ),
                    if (state.canEdit && hitElement is StickyNoteElement)
                      item(
                        LucideIcons.pencil,
                        'Edit note',
                        () => _editStickyNote(
                          mappedElements.firstWhere((e) => e.id == hitElement.id),
                        ),
                      ),
                    if (state.canEdit && hitElement is FrameElement) ...[
                      item(
                        LucideIcons.pencil,
                        'Rename frame',
                        () => _editFrameTitleDialog(hitElement),
                      ),
                      item(
                        LucideIcons.folderPlus,
                        'Add elements inside',
                        () => _canvasBloc.add(
                          CanvasCaptureElementsInFrame(hitElement.id),
                        ),
                      ),
                    ],
                    if (state.canEdit && hitElement is TableElement)
                      item(
                        LucideIcons.table,
                        'Edit table cell',
                        () {
                          final cell = tableHitTestCell(hitElement, worldPoint);
                          _editTableCellDialog(
                            hitElement,
                            initialRow: cell?.$1 ?? 0,
                            initialCol: cell?.$2 ?? 0,
                          );
                        },
                      ),
                    if (state.canEdit) ...[
                      item(
                        LucideIcons.copy,
                        'Copy',
                        () => _canvasBloc.add(const CanvasCopySelection()),
                      ),
                      item(
                        LucideIcons.copyPlus,
                        'Duplicate',
                        () => _canvasBloc.add(
                          CanvasDuplicateElements(
                            state.selectedIds.contains(hitElement.id)
                                ? state.selectedIds
                                : {hitElement.id},
                          ),
                        ),
                      ),
                      item(
                        LucideIcons.arrowUpToLine,
                        'Bring to front',
                        () => _canvasBloc.add(
                          CanvasReorderElement(
                            hitElement.id,
                            math.max(0, state.elements.length - 1),
                          ),
                        ),
                      ),
                      item(
                        LucideIcons.arrowDownToLine,
                        'Send to back',
                        () => _canvasBloc.add(
                          CanvasReorderElement(hitElement.id, 0),
                        ),
                      ),
                      item(
                        hitElement.locked
                            ? Icons.lock_open_outlined
                            : LucideIcons.lock,
                        hitElement.locked ? 'Unlock' : 'Lock',
                        () => _canvasBloc.add(
                          CanvasSetElementLocked(
                            hitElement.id,
                            !hitElement.locked,
                          ),
                        ),
                      ),
                      item(
                        LucideIcons.trash2,
                        'Delete',
                        () {
                          if (hitElement is FrameElement) {
                            _confirmDeleteFrame(hitElement.id);
                          } else {
                            _canvasBloc.add(
                              CanvasDeleteElement(hitElement.id),
                            );
                          }
                        },
                        danger: true,
                      ),
                    ],
                  ] else ...[
                    if (state.canEdit && state.hasClipboard)
                      item(
                        LucideIcons.clipboardPaste,
                        'Paste',
                        () => _canvasBloc.add(const CanvasPasteSelection()),
                      ),
                    if (state.canEdit) ...[
                      item(
                        LucideIcons.stickyNote,
                        'Add Sticky Note',
                        _addStickyNoteDialog,
                      ),
                      item(
                        LucideIcons.table,
                        'Insert Table',
                        _addTableDialog,
                      ),
                      item(
                        LucideIcons.frame,
                        'Add Frame',
                        _startFrameDraw,
                      ),
                    ],
                    item(
                      LucideIcons.maximize2,
                      'Fit content / Reset zoom',
                      _toggleResetView,
                    ),
                    item(
                      LucideIcons.slidersHorizontal,
                      'Canvas Settings',
                      () => _showCanvasSettingsSheet(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addStickyNoteDialog() async {
    if (!_canvasBloc.state.canEdit) return;
    final size = MediaQuery.sizeOf(context);
    final created = await showStickyNoteEditor(
      context,
      isNew: true,
      note: StickyNoteElement(
        id: 'draft',
        z: 0,
        autoSize: true,
        center: _toWorld(Offset(size.width / 2, size.height / 2)),
      ),
    );
    if (created == null || !mounted) return;
    _canvasBloc.add(
      CanvasAddStickyNote(
        center: created.center,
        text: created.text,
        color: created.color,
        width: created.width,
        height: created.height,
        fontSize: created.fontSize,
        fontWeight: created.fontWeight,
        textColor: created.textColor,
        textAlign: created.textAlign,
        autoSize: created.autoSize,
      ),
    );
  }

  Future<void> _editStickyNote(_CanvasElement element) async {
    if (!_canvasBloc.state.canEdit) return;
    final parsed =
        element.sourceElement ??
        CanvasElement.fromMap(element.id, element.data);
    final note = parsed as StickyNoteElement;
    if (note.locked) return;
    final edited = await showStickyNoteEditor(context, note: note);
    if (edited == null || !mounted) return;
    _canvasBloc.add(
      CanvasUpdateStickyNote(
        elementId: element.id,
        text: edited.text,
        color: edited.color,
        fontSize: edited.fontSize,
        fontWeight: edited.fontWeight,
        textColor: edited.textColor,
        textAlign: edited.textAlign,
        autoSize: edited.autoSize,
      ),
    );
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
                      value: 'straight',
                      child: Text('Straight Line'),
                    ),
                    DropdownMenuItem(
                      value: 'curved',
                      child: Text('Curved Bezier'),
                    ),
                    DropdownMenuItem(
                      value: 'orthogonal',
                      child: Text('Orthogonal / Step'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStyle = v);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  activeColor: Colors.white,
                  activeTrackColor: _tokens.accent,
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
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setDialogState(() => startId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.arrowRight,
                        size: 16,
                        color: _tokens.inkMuted,
                      ),
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
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
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
      _canvasBloc.add(
        CanvasAddConnector(
          startElementId: startId,
          startPoint: Offset(centerWorld.dx - 80, centerWorld.dy),
          startAnchor: startAnchor,
          endElementId: endId,
          endPoint: Offset(centerWorld.dx + 80, centerWorld.dy),
          endAnchor: endAnchor,
          lineStyle: selectedStyle,
          hasArrowhead: hasArrowhead,
          color: selectedColor,
        ),
      );
    }
  }

  Future<void> _savePreview() {
    final active = _inFlightPreviewSave;
    if (active != null) {
      return active;
    }
    final future = _performSavePreview();
    _inFlightPreviewSave = future;
    future.whenComplete(() {
      if (identical(_inFlightPreviewSave, future)) {
        _inFlightPreviewSave = null;
      }
    });
    return future;
  }

  double _previewPixelRatio() {
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
    return pixelRatio;
  }

  Future<Uint8List?> _renderBlankBoardPreviewPng(
    CanvasBoardSettings settings,
  ) async {
    ui.Picture? picture;
    ui.Image? image;
    try {
      const width = 320;
      const height = 200;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, 320, 200),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 320, 200),
        Paint()..color = settings.backgroundColor,
      );
      picture = recorder.endRecording();
      image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      developer.log('Blank preview render error: $e', name: 'CanvasScreen');
      return null;
    } finally {
      image?.dispose();
      picture?.dispose();
    }
  }

  Future<void> _performSavePreview() async {
    try {
      if (_canvasBloc.isClosed) return;
      final canvasState = _canvasBloc.state;
      final elements = canvasState.elements;
      final boardSettings = canvasState.boardSettings;
      Uint8List? bytes;

      // Prefer deterministic offscreen rendering when elements exist:
      // RepaintBoundary.toImage() with BackdropFilter glass overlays often
      // fails or captures blank/chrome frames on physical Android Impeller GPUs.
      if (elements.isNotEmpty) {
        try {
          final scale = switch (widget.boardPreviewQuality) {
            'low' => 0.3,
            'high' => 0.8,
            _ => 0.5,
          };
          bytes = await const BoardExportServiceImpl().renderToPng(
            elements,
            settings: boardSettings,
            scale: widget.boardPreviewCompressionEnabled ? scale : 0.8,
          );
        } catch (e) {
          developer.log('Offscreen renderToPng error: $e', name: 'CanvasScreen');
        }
      }

      if (bytes == null || bytes.isEmpty) {
        final boundary =
            _canvasPreviewKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;

        if (boundary != null) {
          if (boundary.debugNeedsPaint) {
            await WidgetsBinding.instance.endOfFrame;
          }

          ui.Image? image;
          try {
            image = await boundary.toImage(pixelRatio: _previewPixelRatio());
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            bytes = byteData?.buffer.asUint8List();
          } catch (e) {
            developer.log('boundary.toImage error: $e', name: 'CanvasScreen');
          } finally {
            image?.dispose();
          }
        }
      }

      if (bytes == null || bytes.isEmpty) {
        bytes = await _renderBlankBoardPreviewPng(boardSettings);
      }

      if (bytes != null && bytes.isNotEmpty && mounted && !_canvasBloc.isClosed) {
        final completer = Completer<void>();
        _canvasBloc.add(
          CanvasSaveBoardPreviewRequested(bytes, completer: completer),
        );
        await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      }
    } catch (e) {
      developer.log('Failed to save board preview: $e', name: 'CanvasScreen');
    }
  }

  Future<void> _exitCanvas() async {
    await _savePreview();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _openSettings(String currentTitle) {
    openBoardSettings(
      context,
      boardId: widget.boardId,
      currentTitle: currentTitle,
      canvasBloc: _canvasBloc,
    );
  }

  void _handleViewportPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (_lastCanvasSize.isEmpty || _textEditor != null) return;
    final keyboard = HardwareKeyboard.instance;
    final wantsZoom = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (!wantsZoom) {
      _applyViewportTransform(
        scale: _viewportScale,
        offset: canvasOffsetForPan(_viewportOffset, event.scrollDelta),
      );
      return;
    }
    final next = canvasZoomForScrollDelta(_viewportScale, event.scrollDelta.dy);
    _zoomAt(event.localPosition, next);
  }

  void _zoomAt(Offset focalPoint, double targetScale) {
    final next = clampCanvasZoom(targetScale);
    if ((next - _viewportScale).abs() < 0.001) return;
    final worldPoint = _toWorld(focalPoint);
    _applyViewportTransform(
      scale: next,
      offset: canvasOffsetForZoom(
        focalPoint: focalPoint,
        worldPoint: worldPoint,
        scale: next,
      ),
    );
  }

  void _zoomFromCenter(double factor) {
    if (_lastCanvasSize.isEmpty) return;
    _zoomAt(_lastCanvasSize.center(Offset.zero), _viewportScale * factor);
  }

  Widget _zoomButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InkRadii.pill),
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.s8),
          child: Icon(icon, size: 18, color: _tokens.inkSecondary),
        ),
      ),
    );
  }

  Widget _buildMinimap(CanvasState state) {
    return Positioned(
      left: InkSpacing.s16,
      bottom: 96,
      child: GlassPanel(
        radius: InkRadii.card,
        padding: const EdgeInsets.all(InkSpacing.s4),
        child: CanvasMinimap(
          elements: state.elements,
          viewportScale: _viewportScale,
          viewportOffset: _viewportOffset,
          viewportSize: _lastCanvasSize,
          onJump: (world) => _applyViewportTransform(
            scale: _viewportScale,
            offset: _centerOffsetForScale(
              _lastCanvasSize,
              world,
              _viewportScale,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUndoRedoControls(CanvasState state) {
    return GlassPanel(
      key: const ValueKey('undo-redo-pill'),
      radius: InkRadii.pill,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomButton(
            LucideIcons.undo2,
            'Undo',
            () {
              HapticFeedback.lightImpact();
              _undo();
            },
          ),
          Container(
            width: 1,
            height: 18,
            color: _tokens.glassStroke,
          ),
          _zoomButton(
            LucideIcons.redo2,
            'Redo',
            () {
              HapticFeedback.lightImpact();
              _redo();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls(CanvasState state) {
    return Positioned(
      right: InkSpacing.s16,
      bottom: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isUndoRedoMode && !state.isViewingHistory) ...[
            _buildUndoRedoControls(state),
            const SizedBox(height: InkSpacing.s8),
          ],
          GlassPanel(
            radius: InkRadii.pill,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _zoomButton(
                  LucideIcons.minus,
                  'Zoom out',
                  () => _zoomFromCenter(1 / 1.25),
                ),
                InkWell(
                  onTap: _toggleResetView,
                  borderRadius: BorderRadius.circular(InkRadii.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.s8,
                      vertical: InkSpacing.s12,
                    ),
                    child: Text(
                      canvasZoomPercentLabel(_viewportScale),
                      style: InkType.caption(_tokens.ink),
                    ),
                  ),
                ),
                _zoomButton(
                  LucideIcons.plus,
                  'Zoom in',
                  () => _zoomFromCenter(1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showTemplateGallerySheet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.all(InkSpacing.s20),
          child: SafeArea(
            top: false,
            child: TemplateGallerySheet(
              templates: canvasTemplates,
              onClose: () => Navigator.pop(sheetContext),
              onSelected: (template) {
                Navigator.pop(sheetContext);
                if (template.isEmpty) return;
                final worldCenter = Offset(
                  (size.width / 2 - _viewportOffset.dx) / _viewportScale,
                  (size.height / 2 - _viewportOffset.dy) / _viewportScale,
                );
                _canvasBloc.add(
                  CanvasImportElements(
                    template.elements,
                    offset: worldCenter - template.center,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCanvasSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tokens = sheetContext.ink;
        return BlocBuilder<CanvasBloc, CanvasState>(
          bloc: _canvasBloc,
          builder: (sheetContext, liveState) {
            final draft = liveState.boardSettings;
            void apply(CanvasBoardSettings next) {
              _canvasBloc.add(CanvasSetBoardSettings(next));
            }

            Widget swatch(Color color) {
              final selected = draft.backgroundColor == color;
              return InkWell(
                onTap: () => apply(draft.copyWith(backgroundColor: color)),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? tokens.accent
                          : tokens.ink.withValues(alpha: 0.12),
                      width: selected ? 3 : 1,
                    ),
                  ),
                ),
              );
            }

            Widget infoButton(String title, String description) {
              return IconButton(
                key: ValueKey('canvas-setting-info-$title'),
                tooltip: 'About $title',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  LucideIcons.info,
                  size: 15,
                  color: tokens.inkMuted,
                ),
                onPressed: () {
                  showDialog<void>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(title),
                      content: Text(description),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Got it'),
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            Widget sectionTitle(String text) {
              return Padding(
                padding: const EdgeInsets.only(bottom: InkSpacing.s8),
                child: Text(
                  text.toUpperCase(),
                  style: InkType.caption(tokens.inkMuted).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              );
            }

            Widget settingLabel(
              String label,
              String description, {
              bool strong = false,
            }) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: strong
                          ? InkType.bodyStrong(tokens.ink)
                          : InkType.label(tokens.inkSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  infoButton(label, description),
                ],
              );
            }

            final viewportCenter = _viewportWorldCenter();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(InkSpacing.s12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                  ),
                  child: GlassPanel(
                    radius: InkRadii.bottomSheet,
                    padding: const EdgeInsets.all(InkSpacing.s20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Canvas Settings',
                                  style: InkType.title(tokens.ink),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  LucideIcons.x,
                                  color: tokens.inkSecondary,
                                ),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                          const SizedBox(height: InkSpacing.s12),
                          sectionTitle('Appearance'),
                          settingLabel(
                            'Background',
                            'Sets the canvas surface color for everyone on this board.',
                          ),
                          const SizedBox(height: InkSpacing.s8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final color in const [
                                Color(0xFFFFFFFF),
                                Color(0xFFFFF8ED),
                                Color(0xFFF1F5F9),
                                Color(0xFFECFDF5),
                                Color(0xFF1E293B),
                                Color(0xFF0F172A),
                              ])
                                swatch(color),
                              () {
                                const presets = {
                                  0xFFFFFFFF,
                                  0xFFFFF8ED,
                                  0xFFF1F5F9,
                                  0xFFECFDF5,
                                  0xFF1E293B,
                                  0xFF0F172A,
                                };
                                final isCustom = !presets.contains(
                                  draft.backgroundColor.value,
                                );
                                return InkWell(
                                  key: const ValueKey(
                                    'canvas-background-color-picker',
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    final picked = await showCanvasColorPicker(
                                      sheetContext,
                                      initialColor: draft.backgroundColor,
                                      recentColors: _recentColors,
                                      palettes: _palettes,
                                      onPalettesChanged: _updatePalettes,
                                    );
                                    if (!mounted || picked == null) return;
                                    apply(
                                      draft.copyWith(
                                        backgroundColor:
                                            picked.withValues(alpha: 1),
                                      ),
                                    );
                                  },
                                  child: Tooltip(
                                    message: 'Custom background color',
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isCustom
                                            ? draft.backgroundColor
                                            : tokens.field,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isCustom
                                              ? tokens.accent
                                              : tokens.ink.withValues(
                                                  alpha: 0.16,
                                                ),
                                          width: isCustom ? 3 : 1,
                                        ),
                                      ),
                                      child: Icon(
                                        LucideIcons.palette,
                                        size: 16,
                                        color: isCustom
                                            ? (draft.backgroundColor
                                                          .computeLuminance() >
                                                      0.5
                                                  ? Colors.black
                                                  : Colors.white)
                                            : tokens.inkSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }(),
                            ],
                          ),
                          const SizedBox(height: InkSpacing.s16),
                          settingLabel(
                            'Pattern',
                            'Overlays a repeating grid, dot, or line pattern on the canvas background to help with alignment and sketching.',
                          ),
                          const SizedBox(height: InkSpacing.s8),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final pattern
                                  in CanvasBackgroundPattern.values)
                                ChoiceChip(
                                  label: Text(
                                    pattern == CanvasBackgroundPattern.none
                                        ? 'None'
                                        : pattern.name[0].toUpperCase() +
                                              pattern.name.substring(1),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: draft.backgroundPattern == pattern,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) => apply(
                                    draft.copyWith(backgroundPattern: pattern),
                                  ),
                                ),
                            ],
                          ),
                          if (draft.backgroundPattern !=
                                  CanvasBackgroundPattern.none ||
                              draft.snapEnabled) ...[
                            const SizedBox(height: InkSpacing.s8),
                            Row(
                              children: [
                                settingLabel(
                                  'Grid spacing (${draft.patternSpacing.round()}px)',
                                  'Adjusts the distance in pixels between background grid lines, dots, and snap points.',
                                ),
                                Expanded(
                                  child: Slider(
                                    value: draft.patternSpacing.clamp(
                                      12.0,
                                      96.0,
                                    ),
                                    min: 12,
                                    max: 96,
                                    divisions: 14,
                                    onChanged: (v) => apply(
                                      draft.copyWith(patternSpacing: v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          sectionTitle('Drawing & Ink'),
                          Row(
                            children: [
                              Expanded(
                                child: settingLabel(
                                  'Ink spill on hold',
                                  'When enabled, holding a pen or brush still on a spot progressively darkens the ink and creates a natural ink spill effect. Off by default.',
                                  strong: true,
                                ),
                              ),
                              Switch(
                                key: const ValueKey(
                                  'canvas-setting-ink-spill-switch',
                                ),
                                activeColor: Colors.white,
                                activeTrackColor: tokens.accent,
                                value: draft.inkSpillEnabled,
                                onChanged: (value) => apply(
                                  draft.copyWith(inkSpillEnabled: value),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          sectionTitle('Page & Layout'),
                          Row(
                            children: [
                              Expanded(
                                child: settingLabel(
                                  'Show page bounds',
                                  'Displays a printable page frame (such as A4, Letter, or 16:9) on the canvas so you can compose within a fixed boundary.',
                                  strong: true,
                                ),
                              ),
                              Switch(
                                activeColor: Colors.white,
                                activeTrackColor: tokens.accent,
                                value: draft.pageBoundsEnabled,
                                onChanged: (value) => apply(
                                  draft.copyWith(pageBoundsEnabled: value),
                                ),
                              ),
                            ],
                          ),
                          if (draft.pageBoundsEnabled) ...[
                            const SizedBox(height: InkSpacing.s8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final (name, width, height)
                                    in CanvasBoardSettings.pagePresets)
                                  ChoiceChip(
                                    label: Text(
                                      name,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected:
                                        (draft.pageWidth - width).abs() < 0.5 &&
                                        (draft.pageHeight - height).abs() < 0.5,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => apply(
                                      draft.copyWith(
                                        pageWidth: width,
                                        pageHeight: height,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: InkSpacing.s8),
                            Text(
                              'Page: ${draft.pageWidth.round()} × '
                              '${draft.pageHeight.round()}',
                              style: InkType.caption(tokens.inkMuted),
                            ),
                          ],
                          const Divider(height: 24),
                          sectionTitle('Guides & Snapping'),
                          Row(
                            children: [
                              Expanded(
                                child: settingLabel(
                                  'Show rulers & guides',
                                  'Shows horizontal and vertical pixel rulers along the edges of the canvas along with any guide lines you add.',
                                  strong: true,
                                ),
                              ),
                              Switch(
                                activeColor: Colors.white,
                                activeTrackColor: tokens.accent,
                                value: draft.rulersEnabled,
                                onChanged: (value) => apply(
                                  draft.copyWith(rulersEnabled: value),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: settingLabel(
                                  'Snap to grid & guides',
                                  'Automatically aligns shapes, text, and dragged elements to the nearest grid line or ruler guide.',
                                  strong: true,
                                ),
                              ),
                              Switch(
                                activeColor: Colors.white,
                                activeTrackColor: tokens.accent,
                                value: draft.snapEnabled,
                                onChanged: (value) => apply(
                                  draft.copyWith(snapEnabled: value),
                                ),
                              ),
                            ],
                          ),
                          if (draft.snapEnabled)
                            Row(
                              children: [
                                settingLabel(
                                  'Snap radius (${draft.snapDistance.round()}px)',
                                  'Controls how close an element must be in pixels before it snaps to a grid line or guide.',
                                ),
                                Expanded(
                                  child: Slider(
                                    value: draft.snapDistance.clamp(4.0, 24.0),
                                    min: 4,
                                    max: 24,
                                    divisions: 10,
                                    onChanged: (v) => apply(
                                      draft.copyWith(snapDistance: v),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: InkSpacing.s8),
                          Row(
                            children: [
                              Expanded(
                                child: settingLabel(
                                  'Ruler guides (${draft.guides.length})',
                                  'Adds movable horizontal (H) or vertical (V) reference lines at the center of your current view for precise alignment.',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _canvasBloc.add(
                                  CanvasAddGuide(
                                    axis: CanvasGuideAxis.horizontal,
                                    position: viewportCenter.dy,
                                  ),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('H Guide'),
                              ),
                              TextButton.icon(
                                onPressed: () => _canvasBloc.add(
                                  CanvasAddGuide(
                                    axis: CanvasGuideAxis.vertical,
                                    position: viewportCenter.dx,
                                  ),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('V Guide'),
                              ),
                            ],
                          ),
                          if (draft.guides.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final guide in draft.guides)
                                  InputChip(
                                    label: Text(
                                      '${guide.axis == CanvasGuideAxis.vertical ? 'V' : 'H'} '
                                      '${guide.position.round()}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onDeleted: () => _canvasBloc.add(
                                      CanvasRemoveGuide(guide.id),
                                    ),
                                  ),
                              ],
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Perspective guide',
                                  style: InkType.bodyStrong(tokens.ink),
                                ),
                              ),
                              Switch(
                                activeColor: Colors.white,
                                activeTrackColor: tokens.accent,
                                value: draft.perspectiveEnabled,
                                onChanged: (value) => apply(
                                  draft.copyWith(
                                    perspectiveEnabled: value,
                                    vanishingPoints:
                                        value && draft.vanishingPoints.isEmpty
                                        ? [viewportCenter]
                                        : draft.vanishingPoints,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (draft.perspectiveEnabled)
                            Row(
                              children: [
                                Text(
                                  '${draft.vanishingPoints.length} point(s)',
                                  style: InkType.caption(tokens.inkMuted),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => apply(
                                    draft.copyWith(
                                      vanishingPoints: [
                                        ...draft.vanishingPoints,
                                        viewportCenter,
                                      ],
                                    ),
                                  ),
                                  icon: const Icon(LucideIcons.plus, size: 14),
                                  label: const Text('Add point'),
                                ),
                                if (draft.vanishingPoints.isNotEmpty)
                                  TextButton(
                                    onPressed: () => apply(
                                      draft.copyWith(
                                        perspectiveEnabled: false,
                                        vanishingPoints: const [],
                                      ),
                                    ),
                                    child: const Text('Clear'),
                                  ),
                              ],
                            ),
                          const SizedBox(height: InkSpacing.s12),
                          Text(
                            'The paper colour, page bounds, and guides '
                            'help keep diagrams tidy and export cleanly.',
                            style: InkType.caption(tokens.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSymmetrySheet(BuildContext context) {
    final activeTray = _canvasBloc.state.activeTray;
    if (activeTray == 'actions') {
      _canvasBloc.add(const CanvasToggleTray('actions'));
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tokens = sheetContext.ink;
        return BlocBuilder<CanvasBloc, CanvasState>(
          bloc: _canvasBloc,
          builder: (sheetContext, liveState) {
            final draft = liveState.boardSettings;
            final viewportCenter = _viewportWorldCenter();
            void apply(CanvasBoardSettings next) {
              _canvasBloc.add(CanvasSetBoardSettings(next));
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Symmetry Drawing',
                              style: InkType.title(tokens.ink),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.x,
                              color: tokens.inkSecondary,
                            ),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      Text(
                        'Mode',
                        style: InkType.label(tokens.inkSecondary),
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final mode in CanvasSymmetryMode.values)
                            ChoiceChip(
                              key: ValueKey('symmetry-mode-${mode.name}'),
                              label: Text(
                                mode == CanvasSymmetryMode.none
                                    ? 'Off'
                                    : mode.name[0].toUpperCase() +
                                        mode.name.substring(1),
                              ),
                              selected: draft.symmetryMode == mode,
                              onSelected: (_) {
                                final turningOn =
                                    draft.symmetryMode ==
                                        CanvasSymmetryMode.none &&
                                    mode != CanvasSymmetryMode.none;
                                apply(
                                  draft.copyWith(
                                    symmetryMode: mode,
                                    symmetryCenter:
                                        (turningOn ||
                                                draft.symmetryCenter ==
                                                    Offset.zero) &&
                                            mode != CanvasSymmetryMode.none
                                        ? viewportCenter
                                        : draft.symmetryCenter,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      if (draft.symmetryMode == CanvasSymmetryMode.radial) ...[
                        const SizedBox(height: InkSpacing.s12),
                        Row(
                          children: [
                            Text(
                              'Lines (${draft.symmetryCount})',
                              style: InkType.label(tokens.inkSecondary),
                            ),
                            Expanded(
                              child: Slider(
                                value: draft.symmetryCount
                                    .toDouble()
                                    .clamp(2, 12),
                                min: 2,
                                max: 12,
                                divisions: 10,
                                onChanged: (v) => apply(
                                  draft.copyWith(symmetryCount: v.round()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (draft.symmetryMode != CanvasSymmetryMode.none) ...[
                        const SizedBox(height: InkSpacing.s12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => apply(
                                  draft.copyWith(
                                    symmetryCenter: viewportCenter,
                                  ),
                                ),
                                icon: const Icon(
                                  LucideIcons.crosshair,
                                  size: 15,
                                ),
                                label: const Text('Center on view'),
                              ),
                            ),
                            const SizedBox(width: InkSpacing.s8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  setState(
                                    () => _isPlacingSymmetryCenter = true,
                                  );
                                  AppSnackBar.showMessage(
                                    context,
                                    'Tap anywhere on the canvas to place the symmetry center',
                                  );
                                },
                                icon: const Icon(
                                  LucideIcons.move,
                                  size: 15,
                                ),
                                label: const Text('Move center'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: InkSpacing.s8),
                        Text(
                          'Tip: Long-press the center dot on the canvas to pick it up, then tap anywhere to drop it.',
                          style: InkType.caption(tokens.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExportOptionsSheet(BuildContext context) {
    final initial = _canvasBloc.state;
    var draft = CanvasExportOptions(
      scope: initial.selectedIds.isEmpty
          ? CanvasExportScope.board
          : CanvasExportScope.selection,
      suffix: initial.selectedIds.isEmpty ? null : 'selection',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        final tokens = sheetContext.ink;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final live = _canvasBloc.state;
            final hasSelection = live.selectedIds.isNotEmpty;
            final selectedFrame = live.elements
                .whereType<FrameElement>()
                .where((frame) => live.selectedIds.contains(frame.id))
                .firstOrNull;
            var scope = draft.scope;
            if (scope == CanvasExportScope.selection && !hasSelection) {
              scope = CanvasExportScope.board;
            }
            if (scope == CanvasExportScope.frame && selectedFrame == null) {
              scope = CanvasExportScope.board;
            }
            final suffix = scope == CanvasExportScope.selection
                ? 'selection'
                : scope == CanvasExportScope.frame
                ? (selectedFrame?.title ?? 'frame')
                : scope == CanvasExportScope.page
                ? 'page'
                : null;
            final effective = draft.copyWith(
              scope: scope,
              frameId: selectedFrame?.id,
              suffix: suffix,
            );
            final plan = const BoardExportServiceImpl().buildExportPlan(
              elements: live.elements,
              options: effective,
              selectedIds: live.selectedIds,
              settings: live.boardSettings,
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(InkSpacing.s12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.84,
                  ),
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
                              icon: Icon(
                                LucideIcons.x,
                                color: tokens.inkSecondary,
                              ),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: InkSpacing.s4),
                        Text(
                          'Export your canvas elements with full layout integrity:',
                          style: InkType.caption(tokens.inkMuted),
                        ),
                        const SizedBox(height: InkSpacing.s12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scope',
                                  style: InkType.caption(tokens.inkMuted),
                                ),
                      const SizedBox(height: InkSpacing.s8),
                      Wrap(
                        spacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text(
                              'Whole board',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected:
                                effective.scope == CanvasExportScope.board,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setSheetState(
                              () => draft = draft.copyWith(
                                scope: CanvasExportScope.board,
                              ),
                            ),
                          ),
                          ChoiceChip(
                            label: const Text(
                              'Selection',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected:
                                effective.scope == CanvasExportScope.selection,
                            visualDensity: VisualDensity.compact,
                            onSelected: hasSelection
                                ? (_) => setSheetState(
                                    () => draft = draft.copyWith(
                                      scope: CanvasExportScope.selection,
                                    ),
                                  )
                                : null,
                          ),
                          ChoiceChip(
                            label: const Text(
                              'Frame',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected:
                                effective.scope == CanvasExportScope.frame,
                            visualDensity: VisualDensity.compact,
                            onSelected: selectedFrame != null
                                ? (_) => setSheetState(
                                    () => draft = draft.copyWith(
                                      scope: CanvasExportScope.frame,
                                    ),
                                  )
                                : null,
                          ),
                          ChoiceChip(
                            label: const Text(
                              'Page',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected:
                                effective.scope == CanvasExportScope.page,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setSheetState(
                              () => draft = draft.copyWith(
                                scope: CanvasExportScope.page,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s16),
                      Row(
                        children: [
                          Text('Scale', style: InkType.caption(tokens.inkMuted)),
                          const Spacer(),
                          Text(
                            'Output: ${plan.widthPixels} × ${plan.heightPixels} px',
                            style: InkType.caption(tokens.inkMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final optionScale in const [1.0, 2.0, 4.0])
                            ChoiceChip(
                              label: Text(
                                '${optionScale.round()}×',
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: draft.scale == optionScale,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setSheetState(
                                () =>
                                    draft = draft.copyWith(scale: optionScale),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transparent background',
                                  style: InkType.bodyStrong(tokens.ink),
                                ),
                                Text(
                                  'PNG and SVG only',
                                  style: InkType.caption(tokens.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            activeColor: Colors.white,
                            activeTrackColor: tokens.accent,
                            value: draft.hasTransparentBackground,
                            onChanged: (value) => setSheetState(
                              () => draft = draft.copyWith(
                                transparentBackground: value,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Include background pattern',
                                  style: InkType.bodyStrong(tokens.ink),
                                ),
                                Text(
                                  'Grid, dots or ruled lines',
                                  style: InkType.caption(tokens.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            activeColor: Colors.white,
                            activeTrackColor: tokens.accent,
                            value: draft.includePattern,
                            onChanged: (value) => setSheetState(
                              () => draft = draft.copyWith(
                                includePattern: value,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: InkSpacing.s16),
                      _buildExportTile(
                        sheetContext,
                        icon: LucideIcons.image,
                        iconColor: tokens.accentText,
                        title: 'PNG Image',
                        subtitle: 'Lossless raster at ${draft.scale.round()}×',
                        format: BoardExportFormat.png,
                        options: effective,
                      ),
                      const SizedBox(height: InkSpacing.s8),
                      _buildExportTile(
                        sheetContext,
                        icon: LucideIcons.fileText,
                        iconColor: tokens.danger,
                        title: 'PDF Document',
                        subtitle:
                            'Printable formatted document with metadata header',
                        format: BoardExportFormat.pdf,
                        options: effective,
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
                        options: effective,
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
                              options: effective.copyWith(
                                format: BoardExportFormat.png,
                              ),
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
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  void _runExport(
    BuildContext sheetContext,
    BoardExportFormat format, {
    required bool share,
    CanvasExportOptions? options,
  }) {
    if (options != null && format == BoardExportFormat.pdf) {
      options = options.copyWith(
        format: format,
        transparentBackground: false,
        includeBackground: true,
      );
    }
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
        options: options?.copyWith(format: format),
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
    CanvasExportOptions? options,
  }) {
    final tokens = sheetContext.ink;
    return Material(
      color: tokens.field,
      borderRadius: BorderRadius.circular(InkRadii.input),
      child: InkWell(
        borderRadius: BorderRadius.circular(InkRadii.input),
        onTap: () =>
            _runExport(sheetContext, format, share: false, options: options),
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
                icon: Icon(
                  LucideIcons.download,
                  size: 20,
                  color: tokens.inkSecondary,
                ),
                tooltip: 'Save to Device Storage',
                onPressed: () => _runExport(
                  sheetContext,
                  format,
                  share: false,
                  options: options,
                ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.share2,
                  size: 20,
                  color: tokens.inkSecondary,
                ),
                tooltip: 'Share via...',
                onPressed: () => _runExport(
                  sheetContext,
                  format,
                  share: true,
                  options: options,
                ),
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
    // Desktop browser layout (canvas_screen_web.dart); always false on phones.
    final webLayout = SlidingTray.useWebLayout(context);

    return BlocProvider.value(
      value: _canvasBloc,
      child: BlocListener<CanvasBloc, CanvasState>(
        listenWhen: (previous, current) =>
            previous.isLoading != current.isLoading ||
            previous.error != current.error ||
            previous.infoMessage != current.infoMessage ||
            previous.infoMessageRedoable != current.infoMessageRedoable ||
            (current.exportSuccessMessage != null &&
                current.exportSuccessMessage != previous.exportSuccessMessage),
        listener: (context, state) async {
          _maybeApplyInitialTemplate(state);
          if (state.exportSuccessMessage != null) {
            final msg = state.exportSuccessMessage!;
            final path = state.lastExportedFilePath;
            final boardTitle = state.boardTitle ?? 'InkLink Board';
            AppSnackBar.showSuccess(
              context,
              msg,
              // The web has no export file to share (the download is it).
              action: path != null && !kIsWeb
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
                          developer.log(
                            'Failed to share exported file: $e',
                            name: 'CanvasScreen',
                          );
                        }
                      },
                    )
                  : null,
            );
            context.read<CanvasBloc>().add(const CanvasConsumeExportMessage());
          }

          if (state.infoMessage != null) {
            final isUndoRedoToast =
                state.infoMessageUndoable ||
                state.infoMessageRedoable ||
                state.infoMessage == 'Undone' ||
                state.infoMessage == 'Redone';
            if (!isUndoRedoToast) {
              AppSnackBar.show(
                context,
                SnackBar(
                  content: Text(state.infoMessage!),
                  backgroundColor: AppSnackBar.successColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            context.read<CanvasBloc>().add(const CanvasConsumeInfoMessage());
          }

          final rawError = state.error;
          if (rawError == null || rawError.isEmpty) return;
          final message = AppErrorFormatter.cleanMessage(rawError);

          final isViewerWarning = message.toLowerCase().contains(
            'you are a viewer',
          );
          final isArchivedWarning = message.toLowerCase().contains('archived');
          final isPausedWarning = message.toLowerCase().contains('paused');

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
          } else if (isArchivedWarning || isPausedWarning) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPausedWarning
                          ? LucideIcons.pause
                          : LucideIcons.archive,
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
            // Evidence and log-compare previews toggle between the past
            // state and the live board; everything else always previews.
            final showLive = state.isViewingHistory &&
                (state.historyPreviewRequestId != null ||
                    state.historyPreviewCompare) &&
                !state.historyPreviewShowsDesired;
            final displayElements = state.isViewingHistory
                ? (showLive ? state.elements : state.historyPreviewElements)
                : state.elements;
            _syncDecodedUiImages(displayElements);
            _maybeFocusHistoryPreview(state, displayElements);
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
                  final isRecentEdgeDrag =
                      _lastEdgeDragTime != null &&
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
                    _syncEditingBarSelection(state);
                    final editingElement = _showsElementEditingBar(state);

                    return RepaintBoundary(
                      key: _canvasPreviewKey,
                      child: Stack(
                        children: [
                          Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) {
                              _capturePointerPressure(event);
                              _handleCanvasPointerDown(event, state);
                            },
                            onPointerMove: (event) {
                              _capturePointerPressure(event);
                              _handleCanvasPointerMove(event);
                            },
                            onPointerUp: _handleCanvasPointerEnd,
                            onPointerCancel: _handleCanvasPointerEnd,
                            onPointerSignal: _handleViewportPointerSignal,
                            child: GestureDetector(
                              // Desktop browser: right-click opens the
                              // canvas menu (long-press on phones).
                              onSecondaryTapUp: webLayout
                                  ? (details) => _showCanvasContextMenu(
                                      state,
                                      mappedElements,
                                      details.localPosition,
                                    )
                                  : null,
                              onScaleStart: (details) {
                                // The in-place text editor owns the gesture while
                                // it is open; drawing/panning resumes on commit.
                                if (_textEditor != null) return;
                                // The eyedropper / symmetry center placement is a
                                // one-shot tap; a drag while armed must not paint.
                                if (_isEyedropperActive ||
                                    _isPlacingSymmetryCenter) {
                                  return;
                                }
                                if (_rawStrokePointerId != null) return;
                                // A palm landing beside the pen must not start a
                                // camera transform while the stylus is down.
                                if (_stylusPointers.isNotEmpty &&
                                    details.pointerCount > 1) {
                                  return;
                                }
                                final worldPoint = _toWorld(
                                  details.localFocalPoint,
                                );

                                if (details.pointerCount == 1 &&
                                    (state.isSelectingUndoRequestArea ||
                                        state.isSelectingHistoryArea)) {
                                  _isTransformingCanvas = false;
                                  setState(() {
                                    _areaSelectionStart = worldPoint;
                                    _areaSelectionCurrent = worldPoint;
                                  });
                                  return;
                                }

                                // While picking undo-request scope elements,
                                // taps (double-taps) toggle the scope; no
                                // strokes, drags, or pans.
                                if (details.pointerCount == 1 &&
                                    _isPickingUndoRequestScope(state)) {
                                  _isTransformingCanvas = false;
                                  return;
                                }

                                if (startsCanvasTransform(
                                  tool: state.currentToolMode,
                                  spacePressed: HardwareKeyboard
                                      .instance
                                      .logicalKeysPressed
                                      .contains(LogicalKeyboardKey.space),
                                  pointerCount: details.pointerCount,
                                  canEdit: state.canEdit,
                                  forceOneFingerPan:
                                      _isBrushTool(state.currentToolMode) &&
                                      !state.fingerDrawingEnabled,
                                )) {
                                  _isTransformingCanvas = true;
                                  _gestureStartScale = _viewportScale;
                                  _gestureStartOffset = _viewportOffset;
                                  _gestureStartFocal = details.localFocalPoint;
                                  _pinchIntent = _PinchIntent.undecided;
                                  return;
                                }

                                _isTransformingCanvas = false;

                                if (state.isViewingHistory) {
                                  _isPreviewPanning = true;
                                  _gestureStartOffset = _viewportOffset;
                                  _gestureStartFocal = details.localFocalPoint;
                                  return;
                                }

                                // Brush tools are driven by raw pointer events
                                // above; the gesture recognizer must not start a
                                // second stroke.
                                if (_isBrushTool(state.currentToolMode)) {
                                  return;
                                }

                                if (state.currentToolMode ==
                                    CanvasToolMode.fill) {
                                  _fillTopmostAt(
                                    state,
                                    mappedElements,
                                    worldPoint,
                                  );
                                  return;
                                }

                                // In arrow mode, touching an existing connectable element should connect, not draw a freehand shape
                                if (_isArrowMode(state)) {
                                  final hitShapeId = _hitTestConnectableShapeId(
                                    mappedElements,
                                    worldPoint,
                                  );
                                  if (hitShapeId != null) {
                                    return;
                                  }
                                  // Empty canvas drag in arrow mode: start drawing an arrow shape
                                  _isDrawingShape = true;
                                  _canvasBloc.add(
                                    CanvasStartShapeDraw(worldPoint),
                                  );
                                  return;
                                }

                                // Handle shape / frame drawing mode
                                if ((state.currentToolMode ==
                                            CanvasToolMode.shape &&
                                        state.pendingShapeType != null) ||
                                    state.currentToolMode ==
                                        CanvasToolMode.frame) {
                                  _isDrawingShape = true;
                                  _canvasBloc.add(
                                    CanvasStartShapeDraw(worldPoint),
                                  );
                                  return;
                                }
                                final hitShapeId = _hitTestShape(
                                  mappedElements,
                                  worldPoint,
                                );
                                final selectedIds = state.selectedIds.isNotEmpty
                                    ? state.selectedIds
                                    : (state.selectedShapeId != null
                                          ? <String>{state.selectedShapeId!}
                                          : <String>{});
                                final isSelectTool =
                                    state.currentToolMode ==
                                    CanvasToolMode.select;

                                // If a single element is selected in select
                                // mode and the user starts dragging inside its
                                // selection box (even on a hollow interior or
                                // near a thin stroke), move it instead of
                                // starting an area selection.
                                String? effectiveHitId = hitShapeId;
                                if (isSelectTool &&
                                    effectiveHitId == null &&
                                    selectedIds.length == 1) {
                                  final selectedSource = state.elements
                                      .where((e) => e.id == selectedIds.first)
                                      .firstOrNull;
                                  final selBounds = selectedSource != null
                                      ? elementBounds(selectedSource)
                                      : null;
                                  if (selBounds != null &&
                                      selBounds
                                          .inflate(6 / _viewportScale)
                                          .contains(worldPoint)) {
                                    effectiveHitId = selectedIds.first;
                                  }
                                }

                                // Select tool: dragging empty canvas draws a
                                // marquee and selects everything it touches.
                                if (isSelectTool && effectiveHitId == null) {
                                  _isDraggingShape = false;
                                  _isDraggingStroke = false;
                                  _selectionAdditive =
                                      HardwareKeyboard.instance.isShiftPressed;
                                  if (state.selectionMode ==
                                      CanvasSelectionMode.lasso) {
                                    setState(() {
                                      _isLassoSelecting = true;
                                      _lassoPoints = [worldPoint];
                                    });
                                  } else {
                                    setState(() {
                                      _isMarqueeSelecting = true;
                                      _marqueeStart = worldPoint;
                                      _marqueeCurrent = worldPoint;
                                    });
                                  }
                                  return;
                                }

                                if (effectiveHitId != null &&
                                    selectedIds.contains(effectiveHitId)) {
                                  final draggingExistingGroup =
                                      selectedIds.length > 1 &&
                                      selectedIds.contains(effectiveHitId);
                                  if (draggingExistingGroup) {
                                    _isDraggingStroke = false;
                                    _isDraggingShape = true;
                                    _setShapeEditing(true);
                                    _shapeDragStartWorldPoint = worldPoint;
                                    _groupDragDelta = Offset.zero;
                                    return;
                                  }
                                  final hit = mappedElements.firstWhere(
                                    (e) => e.id == effectiveHitId,
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

                                // Selecting elements is a deliberate double-tap.
                                // A drag on an unselected shape must not start a
                                // doodle or move it.
                                _isDraggingShape = false;
                                _isDraggingStroke = false;
                              },
                              onScaleUpdate: (details) {
                                if (_textEditor != null) return;
                                if (_rawStrokePointerId != null) return;
                                if (_stylusPointers.isNotEmpty &&
                                    details.pointerCount > 1) {
                                  return;
                                }
                                if (_isTransformingCanvas) {
                                  final nextScale = clampCanvasZoom(
                                    _gestureStartScale * details.scale,
                                  );
                                  final focalDelta =
                                      details.localFocalPoint -
                                      _gestureStartFocal;

                                  if (details.pointerCount < 2) {
                                    _pinchIntent = _PinchIntent.pan;
                                  } else if (_pinchIntent ==
                                      _PinchIntent.undecided) {
                                    final scaleChange =
                                        (nextScale / _gestureStartScale - 1)
                                            .abs();
                                    if (scaleChange > 0.015) {
                                      _pinchIntent = _PinchIntent.zoom;
                                    } else if (focalDelta.distance > 3) {
                                      _pinchIntent = _PinchIntent.pan;
                                    }
                                  }

                                  if (_pinchIntent == _PinchIntent.zoom) {
                                    // Zoom around the pinch point and ignore
                                    // focal drift so the canvas does not pan
                                    // while the user is pinching.
                                    setState(() {
                                      _viewportScale = nextScale;
                                      _viewportOffset = canvasOffsetForPinch(
                                        startFocal: _gestureStartFocal,
                                        startOffset: _gestureStartOffset,
                                        startScale: _gestureStartScale,
                                        nextScale: nextScale,
                                      );
                                    });
                                  } else if (_pinchIntent == _PinchIntent.pan) {
                                    setState(() {
                                      _viewportScale = _gestureStartScale;
                                      _viewportOffset =
                                          _gestureStartOffset + focalDelta;
                                    });
                                  }
                                  return;
                                }

                                if (_isPreviewPanning) {
                                  setState(() {
                                    _viewportOffset =
                                        _gestureStartOffset +
                                        (details.localFocalPoint -
                                            _gestureStartFocal);
                                  });
                                  return;
                                }

                                if (state.isViewingHistory) return;

                                if (_areaSelectionStart != null) {
                                  setState(() {
                                    _areaSelectionCurrent = _toWorld(
                                      details.localFocalPoint,
                                    );
                                  });
                                  return;
                                }

                                // Handle shape drawing update
                                if (_isDrawingShape || state.isDrawingShape) {
                                  final worldPoint = _toWorld(
                                    details.localFocalPoint,
                                  );
                                  _canvasBloc.add(
                                    CanvasUpdateShapeDraw(worldPoint),
                                  );
                                  return;
                                }

                                final worldPoint = _toWorld(
                                  details.localFocalPoint,
                                );
                                if (_isLassoSelecting) {
                                  final points = _lassoPoints;
                                  if (points != null &&
                                      (worldPoint - points.last).distance > 2) {
                                    setState(() => points.add(worldPoint));
                                  }
                                  return;
                                }
                                if (_isMarqueeSelecting) {
                                  setState(() => _marqueeCurrent = worldPoint);
                                  return;
                                }
                                if (_isDraggingShape &&
                                    _groupDragDelta != null) {
                                  _updateEdgeAutoPan(
                                    details.localFocalPoint,
                                    fromOverlay: false,
                                  );
                                  final nextDelta = _snapGroupDragDelta(
                                    state,
                                    worldPoint - _shapeDragStartWorldPoint,
                                  );
                                  setState(() {
                                    _groupDragDelta = nextDelta;
                                  });
                                  return;
                                }
                                if (_isDraggingStroke) {
                                  _updateEdgeAutoPan(
                                    details.localFocalPoint,
                                    fromOverlay: false,
                                  );
                                  final delta =
                                      worldPoint - _strokeDragStartWorldPoint;
                                  setState(() {
                                    _strokeDragDelta = delta;
                                  });
                                  return;
                                }

                                if (_isDraggingShape) {
                                  _updateEdgeAutoPan(
                                    details.localFocalPoint,
                                    fromOverlay: false,
                                  );
                                  final dragDelta =
                                      worldPoint - _shapeDragStartWorldPoint;
                                  final rawCenter =
                                      _shapeDragStartCenter + dragDelta;
                                  final dragged = mappedElements
                                      .where(
                                        (e) => e.id == state.selectedShapeId,
                                      )
                                      .firstOrNull;
                                  final nextCenter = dragged == null
                                      ? rawCenter
                                      : _snapElementCenterDrag(
                                          state,
                                          dragged,
                                          rawCenter,
                                        );
                                  setState(() {
                                    _shapeDragPreviewCenter = nextCenter;
                                    _connectorDragDelta =
                                        nextCenter - _shapeDragStartCenter;
                                  });
                                  _canvasBloc.add(
                                    CanvasPreviewMoveSelectedShape(nextCenter),
                                  );
                                  return;
                                }
                              },
                              onScaleEnd: (_) {
                                if (_isTransformingCanvas) {
                                  _isTransformingCanvas = false;
                                  _pinchIntent = _PinchIntent.undecided;
                                  return;
                                }
                                if (_rawStrokePointerId != null) return;

                                if (_isPreviewPanning) {
                                  _isPreviewPanning = false;
                                  return;
                                }

                                if (state.isViewingHistory) return;

                                if (_areaSelectionStart != null) {
                                  _completeAreaSelection();
                                  return;
                                }

                                // End shape drawing
                                if (_isDrawingShape || state.isDrawingShape) {
                                  _isDrawingShape = false;
                                  _canvasBloc.add(const CanvasEndShapeDraw());
                                  return;
                                }

                                if (_isLassoSelecting) {
                                  final points = _lassoPoints;
                                  final additive = _selectionAdditive;
                                  _isLassoSelecting = false;
                                  _lassoPoints = null;
                                  _selectionAdditive = false;
                                  if (points != null && points.length >= 3) {
                                    final bounds = _polygonBounds(points);
                                    if (bounds.width > 4 || bounds.height > 4) {
                                      _canvasBloc.add(
                                        CanvasSelectInLasso(
                                          points,
                                          additive: additive,
                                        ),
                                      );
                                    } else if (!additive) {
                                      _canvasBloc.add(
                                        const CanvasSelectShape(null),
                                      );
                                    }
                                  } else if (!additive) {
                                    _canvasBloc.add(
                                      const CanvasSelectShape(null),
                                    );
                                  }
                                  return;
                                }
                                if (_isMarqueeSelecting) {
                                  final start = _marqueeStart;
                                  final end = _marqueeCurrent;
                                  final additive = _selectionAdditive;
                                  _isMarqueeSelecting = false;
                                  _marqueeStart = null;
                                  _marqueeCurrent = null;
                                  _selectionAdditive = false;
                                  if (start != null && end != null) {
                                    final rect = Rect.fromPoints(start, end);
                                    if (rect.width.abs() > 4 ||
                                        rect.height.abs() > 4) {
                                      _canvasBloc.add(
                                        CanvasSelectInRect(
                                          rect,
                                          additive: additive,
                                        ),
                                      );
                                    } else if (!additive) {
                                      _canvasBloc.add(
                                        const CanvasSelectShape(null),
                                      );
                                    }
                                  }
                                  return;
                                }
                                if (_isDraggingShape &&
                                    _groupDragDelta != null) {
                                  final delta = _groupDragDelta!;
                                  _isDraggingShape = false;
                                  _groupDragDelta = null;
                                  _setShapeEditing(false);
                                  if (delta != Offset.zero) {
                                    _canvasBloc.add(
                                      CanvasTranslateSelection(delta),
                                    );
                                  }
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
                              },
                              onTapDown: (details) {
                                _suppressTapDeselect = false;
                                // Tapping the canvas commits whatever was typed.
                                if (_textEditor != null) {
                                  _suppressTapDeselect = true;
                                  _commitTextEditing();
                                  return;
                                }
                                if (_isTransformingCanvas ||
                                    _rawStrokePointerId != null) {
                                  _suppressTapDeselect = true;
                                  return;
                                }
                                if (state.isViewingHistory ||
                                    state.isSelectingUndoRequestArea ||
                                    state.isSelectingHistoryArea) {
                                  _suppressTapDeselect = true;
                                  return;
                                }

                                final worldPoint = _toWorld(
                                  details.localPosition,
                                );
                                _lastTapWorldPoint = worldPoint;

                                // Undo-request picking: double-tap toggles the
                                // element in the member's scope; every other
                                // tap behaviour is suppressed. The framework's
                                // onDoubleTap is guarded below so editors do
                                // not open on the same gesture.
                                if (_isPickingUndoRequestScope(state)) {
                                  _suppressTapDeselect = true;
                                  final now = DateTime.now();
                                  final last = _lastPickTapDown;
                                  _lastPickTapDown = now;
                                  if (last != null &&
                                      now.difference(last) <
                                          const Duration(milliseconds: 300)) {
                                    _lastPickTapDown = null;
                                    final hitShapeId = _hitTestShape(
                                      mappedElements,
                                      worldPoint,
                                    );
                                    if (hitShapeId != null) {
                                      _canvasBloc.add(
                                        CanvasUndoRequestDraftElementToggled(
                                          hitShapeId,
                                        ),
                                      );
                                    }
                                  }
                                  return;
                                }

                                if (_isEyedropperActive) {
                                  _suppressTapDeselect = true;
                                  final sampled = sampleCanvasColorAt(
                                    state.elements,
                                    worldPoint,
                                  );
                                  setState(() => _isEyedropperActive = false);
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                  if (sampled == null) {
                                    AppSnackBar.showMessage(
                                      context,
                                      'No color to pick here',
                                    );
                                  } else {
                                    _setBrushColor(sampled);
                                    AppSnackBar.showSuccess(
                                      context,
                                      'Picked #${sampled.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                                    );
                                  }
                                  return;
                                }

                                if (_isPlacingSymmetryCenter) {
                                  _suppressTapDeselect = true;
                                  setState(
                                    () => _isPlacingSymmetryCenter = false,
                                  );
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                  _canvasBloc.add(
                                    CanvasSetBoardSettings(
                                      state.boardSettings.copyWith(
                                        symmetryCenter: worldPoint,
                                      ),
                                    ),
                                  );
                                  HapticFeedback.selectionClick();
                                  return;
                                }

                                // Pin comment placement flow:
                                if (state.isPlacingComment) {
                                  _suppressTapDeselect = true;
                                  _promptNewCommentDialog(worldPoint);
                                  return;
                                }

                                // Text tool: tap an empty spot to type there.
                                if (state.currentToolMode ==
                                    CanvasToolMode.text) {
                                  _suppressTapDeselect = true;
                                  _beginTextEditing(null, worldPoint);
                                  return;
                                }

                                // Arrow 2-element connection flow:
                                if (_isArrowMode(state)) {
                                  final hitShapeId = _hitTestConnectableShapeId(
                                    mappedElements,
                                    worldPoint,
                                  );
                                  if (hitShapeId != null) {
                                    _suppressTapDeselect = true;
                                    if (_arrowConnectStartElementId == null) {
                                      setState(() {
                                        _arrowConnectStartElementId =
                                            hitShapeId;
                                      });
                                      return;
                                    } else {
                                      final startId =
                                          _arrowConnectStartElementId!;
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

                                        _canvasBloc.add(
                                          CanvasAddConnector(
                                            startElementId: startId,
                                            startAnchor: 'auto',
                                            startPoint: startPt,
                                            endElementId: endId,
                                            endAnchor: 'auto',
                                            endPoint: endPt,
                                            lineStyle: 'straight',
                                            hasArrowhead: true,
                                            color: state.selectedColor,
                                            strokeWidth: math.max(
                                              state.strokeWidth,
                                              2.5,
                                            ),
                                          ),
                                        );

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
                                      _suppressTapDeselect = true;
                                      setState(() {
                                        _arrowConnectStartElementId = null;
                                      });
                                    }
                                  }
                                }

                                // Desktop browsers: one click selects, and a
                                // click on empty canvas clears the selection,
                                // as people expect with a mouse (double-click
                                // still opens the editor). Phones unchanged.
                                if (SlidingTray.useWebLayout(context) &&
                                    state.currentToolMode ==
                                        CanvasToolMode.select) {
                                  final hitShapeId = _hitTestShape(
                                    mappedElements,
                                    worldPoint,
                                  );
                                  if (hitShapeId != null) {
                                    // Keep the view still, as desktop apps do.
                                    _selectShape(hitShapeId, centerView: false);
                                  } else if (!_insideSingleSelection(
                                    state,
                                    worldPoint,
                                  )) {
                                    _selectShape(null, centerView: false);
                                  }
                                }
                              },
                              onDoubleTapDown: (details) {
                                _lastDoubleTapWorldPoint = _toWorld(
                                  details.localPosition,
                                );
                              },
                              onDoubleTap: () {
                                if (_textEditor != null) {
                                  return;
                                }
                                if (state.isViewingHistory ||
                                    state.isSelectingUndoRequestArea ||
                                    state.isSelectingHistoryArea ||
                                    _isPickingUndoRequestScope(state)) {
                                  return;
                                }
                                if (state.currentToolMode !=
                                    CanvasToolMode.select) {
                                  return;
                                }
                                final worldPoint =
                                    _lastDoubleTapWorldPoint ??
                                    _lastTapWorldPoint;
                                _lastDoubleTapWorldPoint = null;
                                if (worldPoint == null) return;
                                final hitShapeId = _hitTestShape(
                                  mappedElements,
                                  worldPoint,
                                );
                                final selectedIds =
                                    state.selectedIds.isNotEmpty
                                    ? state.selectedIds
                                    : (state.selectedShapeId != null
                                          ? <String>{state.selectedShapeId!}
                                          : <String>{});
                                if (shouldDeselectOnCanvasDoubleTap(
                                  tool: state.currentToolMode,
                                  selectedIds: selectedIds,
                                  hitElementId: hitShapeId,
                                )) {
                                  if (_enteredFrameId != null) {
                                    setState(() => _enteredFrameId = null);
                                  }
                                  _selectShape(null);
                                  return;
                                }
                                if (!state.canEdit || hitShapeId == null) {
                                  return;
                                }
                                final hit = mappedElements.firstWhere(
                                  (e) => e.id == hitShapeId,
                                );
                                if (hit.kind == _ElementKind.frame) {
                                  setState(() => _enteredFrameId = hit.id);
                                }
                                final activeTray = state.activeTray;
                                if (activeTray != null) {
                                  _canvasBloc.add(CanvasToggleTray(activeTray));
                                }
                                _selectShape(hitShapeId, expandEditor: false);
                                  if (hit.kind == _ElementKind.stickyNote) {
                                  _editStickyNote(hit);
                                } else if (hit.kind == _ElementKind.text) {
                                  final source = _canvasBloc.state.elements
                                      .where((e) => e.id == hit.id)
                                      .firstOrNull;
                                  if (source is TextElement) {
                                    _beginTextEditing(source, source.center);
                                  }
                                } else if (hit.kind == _ElementKind.table) {
                                  final source = _canvasBloc.state.elements
                                      .whereType<TableElement>()
                                      .where((e) => e.id == hit.id)
                                      .firstOrNull;
                                  if (source != null) {
                                    final hitCell = tableHitTestCell(
                                      source,
                                      worldPoint,
                                    );
                                    _editTableCellDialog(
                                      source,
                                      initialRow: hitCell?.$1 ?? 0,
                                      initialCol: hitCell?.$2 ?? 0,
                                    );
                                  }
                                }
                              },
                              onLongPressStart: (details) {
                                final settings = state.boardSettings;
                                if (state.canEdit &&
                                    !state.isViewingHistory &&
                                    settings.symmetryMode !=
                                        CanvasSymmetryMode.none) {
                                  final worldPoint = _toWorld(
                                    details.localPosition,
                                  );
                                  final hitRadius = 28.0 / _viewportScale;
                                  if ((worldPoint - settings.symmetryCenter)
                                          .distance <=
                                      hitRadius) {
                                    HapticFeedback.mediumImpact();
                                    setState(
                                      () => _isPlacingSymmetryCenter = true,
                                    );
                                    AppSnackBar.showMessage(
                                      context,
                                      'Symmetry center picked up — tap anywhere on the canvas to drop it',
                                    );
                                    return;
                                  }
                                }
                                _showCanvasContextMenu(
                                  state,
                                  mappedElements,
                                  details.localPosition,
                                );
                              },
                              onTap: () {
                                final suppressDeselect = _suppressTapDeselect;
                                _suppressTapDeselect = false;
                                // Finishing a text edit (the tap that dismissed
                                // the keyboard) keeps the element selected so
                                // its editing bar stays open for styling. Only a
                                // later tap counts as clicking elsewhere.
                                final justCommittedText = _textCommitAt != null &&
                                    DateTime.now().difference(_textCommitAt!) <
                                        const Duration(milliseconds: 500);
                                _textCommitAt = null;
                                if (state.isViewingHistory ||
                                    state.isSelectingUndoRequestArea ||
                                    state.isSelectingHistoryArea ||
                                    _isPickingUndoRequestScope(state)) {
                                  return;
                                }
                                final worldPoint = _lastTapWorldPoint;
                                if (!suppressDeselect &&
                                    !justCommittedText &&
                                    worldPoint != null &&
                                    !_isBrushTool(state.currentToolMode)) {
                                  final hitShapeId = _hitTestShape(
                                    mappedElements,
                                    worldPoint,
                                  );
                                  final selectedIds =
                                      state.selectedIds.isNotEmpty
                                      ? state.selectedIds
                                      : (state.selectedShapeId != null
                                            ? <String>{state.selectedShapeId!}
                                            : <String>{});
                                  if (shouldDeselectOnCanvasTap(
                                    tool: state.currentToolMode,
                                    selectedIds: selectedIds,
                                    hitElementId: hitShapeId,
                                  )) {
                                    if (_enteredFrameId != null) {
                                      setState(() => _enteredFrameId = null);
                                    }
                                    _selectShape(null);
                                  } else if (hitShapeId == null &&
                                      _enteredFrameId != null) {
                                    setState(() => _enteredFrameId = null);
                                  }
                                }
                                // If in shape draw mode, tap switches back to doodle unless waiting for 2nd arrow connection
                                if (state.currentToolMode ==
                                        CanvasToolMode.shape ||
                                    _isArrowMode(state)) {
                                  if (_isArrowMode(state) &&
                                      _arrowConnectStartElementId != null) {
                                    return;
                                  }
                                  _canvasBloc.add(
                                    const CanvasCancelShapeDraw(),
                                  );
                                  return;
                                }
                                if (state.activeTray != null) {
                                  _canvasBloc.add(
                                    CanvasToggleTray(state.activeTray!),
                                  );
                                }
                              },
                              behavior: HitTestBehavior.translucent,
                              child: Semantics(
                                container: true,
                                label:
                                    'Board canvas, ${state.elements.where((element) => !element.hidden).length} objects',
                                child: SizedBox.expand(
                                  child: CustomPaint(
                                    painter: _CanvasPainter(
                                      elements: mappedElements,
                                      layerEffects: _memoizedLayerPaintEffects(
                                        displayElements,
                                      ),
                                      decodedImages: _decodedUiImages,
                                      currentPoints: state.isViewingHistory
                                          ? const []
                                          : state.currentStroke,
                                      currentStrokePressures:
                                          state.isViewingHistory
                                          ? const []
                                          : state.currentStrokePressures,
                                      currentStrokeTilts: state.isViewingHistory
                                          ? const []
                                          : state.currentStrokeTilts,
                                      currentColor: state.selectedColor,
                                      currentStrokeWidth: state.strokeWidth,
                                      currentBrushOpacity: state.brushOpacity,
                                      currentBrushType: state.brushType,
                                      showEraserPreview:
                                          !state.isViewingHistory &&
                                          _showEraserPreview &&
                                          state.currentToolMode ==
                                              CanvasToolMode.eraser,
                                      selectedShapeId: state.isViewingHistory
                                          ? null
                                          : state.selectedShapeId,
                                      viewportScale: _viewportScale,
                                      viewportOffset: _viewportOffset,
                                      isDrawingShape:
                                          !state.isViewingHistory &&
                                          state.isDrawingShape,
                                      isDrawingFrame:
                                          !state.isViewingHistory &&
                                          state.isDrawingShape &&
                                          state.currentToolMode ==
                                              CanvasToolMode.frame,
                                      shapeDrawStart: state.shapeDrawStart,
                                      shapeDrawCurrent: state.shapeDrawCurrent,
                                      pendingShapeType: state.pendingShapeType,
                                      boardSettings: state.boardSettings,
                                      accentColor: _tokens.accent,
                                      remoteEraserCursors:
                                          state.isViewingHistory
                                          ? const []
                                          : _canvasBloc.remoteEraserCursors,
                                      arrowConnectStartElementId:
                                          state.isViewingHistory
                                          ? null
                                          : (_isArrowMode(state)
                                                ? _arrowConnectStartElementId
                                                : null),
                                      highlightElementIds:
                                          state.isViewingHistory
                                          ? state.historyHighlightElementIds
                                                .toSet()
                                          : _frameDragHighlightedIds(state),
                                      areaSelectionRect: _areaSelectionRect,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          if (!state.isViewingHistory) _buildMarqueeOverlay(),
                          if (!state.isViewingHistory) _buildLassoOverlay(),
                          Positioned.fill(
                            child: Offstage(
                              offstage: _isEditingShape,
                              child: IgnorePointer(
                                ignoring: _isEditingShape,
                                child: Stack(
                                  children: [
                                    if (!state.isViewingHistory)
                                      ..._buildPinnedCommentPins(state),
                                    if (!state.isViewingHistory)
                                      ..._buildAiImageOverlays(state),
                                    // Desktop browser: corner bars and a tool rail
                                    // (canvas_screen_web.dart). Phones: unchanged.
                                    if (webLayout) ...[
                                      _buildWebKeyboardFocus(state),
                                      if (!state.isViewingHistory)
                                        _buildWebToolRail(state),
                                      if (!state.isViewingHistory)
                                        ..._buildWebBottomLeft(state),
                                      if (!editingElement) _buildWebBottomRight(state),
                                    ] else ...[
                                      if (!state.isViewingHistory)
                                        _buildEdgeTriggers(state, isDark),
                                      if (!state.isViewingHistory &&
                                          !editingElement)
                                        _buildCanvasToolbar(state),
                                      if (!state.isViewingHistory &&
                                          !editingElement)
                                        _buildSelectionModeToggle(state),
                                      _buildZoomControls(state),
                                      if (_lastCanvasSize.width >= 720)
                                        _buildMinimap(state),
                                    ],
                                    if (!state.isViewingHistory &&
                                        _showTemplateCoachmark &&
                                        !state.isLoading &&
                                        state.elements.isEmpty &&
                                        !editingElement)
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom:
                                            MediaQuery.of(
                                              context,
                                            ).padding.bottom +
                                            72,
                                        child: Center(
                                          child: TemplateCoachmark(
                                            onOpen: () {
                                              _dismissTemplateCoachmark();
                                              _showTemplateGallerySheet(
                                                context,
                                              );
                                            },
                                            onDismiss:
                                                _dismissTemplateCoachmark,
                                          ),
                                        ),
                                      ),
                                    if (!state.isViewingHistory)
                                      _buildMultiSelectBar(state),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!state.isViewingHistory &&
                              state.selectedShapeId != null)
                            _buildSelectionOutline(state, mappedElements),
                          if (!state.isViewingHistory)
                            _buildGroupTransformOverlay(state),
                          Positioned.fill(
                            child: Offstage(
                              offstage: _isEditingShape,
                              child: IgnorePointer(
                                ignoring: _isEditingShape,
                                child: Stack(
                                  children: [
                                    if (!state.isViewingHistory &&
                                        state.selectedShapeId != null)
                                      _buildAiImageActionBar(state),
                                    if (!state.isViewingHistory &&
                                        !editingElement)
                                      _buildAllTrays(state),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (!state.isViewingHistory &&
                              !editingElement &&
                              _isShapesPopupOpen)
                            ..._buildShapesPickerPopup(state),
                          if (!state.isViewingHistory)
                            _buildTextEditorOverlay(),
                          _buildHistoryPlanListener(),
                          _buildUndoConflictListener(),
                          if (state.isViewingHistory)
                            HistoryPreviewBanner(
                              version: state.historyPreviewVersion,
                              title: state.historyPreviewTitle,
                              requestId: state.historyPreviewRequestId,
                              showsDesired: state.historyPreviewShowsDesired,
                              onRestore:
                                  state.historyPreviewRequestId == null &&
                                      state.historyScrub == null &&
                                      !state.historyPreviewCompare
                                  ? () => _restoreHistoryVersion(state)
                                  : null,
                              onExit: () => _canvasBloc.add(
                                const CanvasHistoryPreviewExited(),
                              ),
                              onToggleDesired: (desired) => _canvasBloc.add(
                                CanvasHistoryEvidenceViewToggled(desired),
                              ),
                              onReview: state.historyPreviewRequestId == null
                                  ? null
                                  : () => _canvasBloc.add(
                                      CanvasHistoryUndoRequestReviewRequested(
                                        state.historyPreviewRequestId!,
                                      ),
                                    ),
                              scrub: state.historyScrub,
                              scrubIndex: state.historyScrubIndex,
                              targetName:
                                  state.historyScrub?.targetUid == null
                                  ? null
                                  : _memberDisplayName(
                                      state,
                                      state.historyScrub!.targetUid!,
                                    ),
                              onScrubChanged: state.historyScrub == null
                                  ? null
                                  : _onScrubSliderChanged,
                              // Member request scrub: send the chosen state;
                              // no restore action (the owner does that).
                              onRestoreToState: state.historyScrub == null
                                  ? null
                                  : state.undoRequestDraft != null &&
                                        state.historyPreviewRequestId == null
                                  ? null
                                  : state.historyPreviewRequestId != null
                                  ? () => _restoreScrubStateInRequest(state)
                                  : () => _restoreScrubState(state),
                              onUndoUserAfter:
                                  state.historyScrub?.targetUid != null &&
                                      state.historyPreviewRequestId == null &&
                                      state.undoRequestDraft == null
                                  ? () => _undoUserAfterScrub(state)
                                  : null,
                              onSendRequest:
                                  state.historyScrub != null &&
                                      state.undoRequestDraft != null &&
                                      state.historyPreviewRequestId == null
                                  ? () => _openUndoRequestSendSheet(state)
                                  : null,
                              hint: state.historyScrub == null
                                  ? null
                                  : state.undoRequestDraft != null &&
                                        state.historyPreviewRequestId == null
                                  ? 'Move the slider back to the state '
                                        'you want the owner to restore.'
                                  : state.historyPreviewRequestId != null
                                  ? 'Move the slider to compare the '
                                        'requested state with now.'
                                  : null,
                              onRevertThisChange: state.historyPreviewCompare
                                  ? () => _revertPreviewOps(state)
                                  : null,
                              onLoadOlder:
                                  (state.historyScrub?.targetUid != null ||
                                          state.historyScrub?.area != null ||
                                          state.historyScrub?.scopeMode ==
                                              UndoRequestScopeMode.areaState) &&
                                      state.historyScrub!.hasMore
                                  ? () => _canvasBloc.add(
                                      const CanvasHistoryScrubLoadOlderRequested(),
                                    )
                                  : null,
                              compareEnabled: state.historyPreviewCompare,
                            ),
                          const BoardChatDrawer(),
                          const CommentsTray(),
                          const VoiceCallHud(),
                          Positioned.fill(
                            child: Offstage(
                              offstage: _isEditingShape,
                              child: IgnorePointer(
                                ignoring: _isEditingShape,
                                child: Stack(
                                  children: [
                                    if (!state.isViewingHistory)
                                      _buildElementEditingBar(
                                        state,
                                        mappedElements,
                                      ),
                                    if (!state.isViewingHistory && webLayout) ...[
                                      _buildWebTopLeftBar(
                                        state,
                                        title,
                                        _pendingEditRequestsCount(state),
                                      ),
                                      _buildWebTopRightBar(
                                        state,
                                        _pendingEditRequestsCount(state),
                                      ),
                                    ] else if (!state.isViewingHistory)
                                      _buildTopPills(state, title),
                                    if (!state.isViewingHistory &&
                                        state.isArchived)
                                      _buildArchivedBanner(state),
                                    if (!state.isViewingHistory &&
                                        !state.isArchived &&
                                        state.isPaused)
                                      _buildPausedBanner(state),
                                    if (!state.isViewingHistory &&
                                        !state.isArchived &&
                                        !state.isPaused &&
                                        state.currentUserRole ==
                                            Board.roleOwner &&
                                        state.undoRequests.any(
                                          (r) => r.isPending,
                                        ))
                                      _buildPendingUndoRequestsBanner(state),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          if (state.isSelectingUndoRequestArea ||
                              state.isSelectingHistoryArea)
                            _buildAreaSelectionHint(state),

                          if (_isPickingUndoRequestScope(state))
                            _buildUndoRequestPickHint(state),

                          if (!state.isViewingHistory &&
                              !state.isSelectingUndoRequestArea &&
                              !state.isSelectingHistoryArea &&
                              !_isPickingUndoRequestScope(state) &&
                              state.myPendingUndoRequest != null)
                            _buildUndoRequestPendingNotice(state),

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

  bool get _hasActiveElementTransformOverlay =>
      _pendingShapeEdits.isNotEmpty ||
      _shapeTransformDraft != null ||
      _isDraggingShape ||
      _isDraggingStroke ||
      _groupDragDelta != null ||
      _groupScaleTarget != null ||
      _groupRotationPivot != null;

  Map<String, CanvasLayerPaintEffect> _memoizedLayerPaintEffects(
    List<CanvasElement> elements,
  ) {
    if (identical(elements, _cachedLayerEffectsInput) &&
        _cachedLayerEffects != null) {
      return _cachedLayerEffects!;
    }
    final computed = layerPaintEffects(elements);
    _cachedLayerEffectsInput = elements;
    _cachedLayerEffects = computed;
    return computed;
  }

  List<_CanvasElement> _mapElements(List<CanvasElement> elements) {
    final canUseCache = !_hasActiveElementTransformOverlay;
    if (canUseCache &&
        identical(elements, _cachedMapElementsInput) &&
        _cachedMappedElements != null) {
      return _cachedMappedElements!;
    }
    // Group transforms are previewed by rewriting payloads, so painter,
    // hit-testing and overlays all see the same transformed geometry.
    // Layers paint as bands: Default bottom-most, then each layer by z.
    final order = canvasPaintOrder(elements);
    _lockedLayerElementIds = order.lockedElementIds;
    final ordered = order.elements.toList(growable: false);
    final previewed = ordered.map(_groupPreviewElement).toList();
    final paintRank = {
      for (var i = 0; i < previewed.length; i++) previewed[i].id: i,
    };
    final metaById = {for (final e in previewed) e.id: e};
    final mapped = previewed
        .where((element) => !element.hidden)
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
              brushId: e.brushId,
              pressures: e.pressures,
              tilts: e.tilts,
              spacing: e.spacing,
              textureSeed: e.textureSeed,
              data: {
                'type': 'stroke',
                if (e.frameId != null) 'frameId': e.frameId,
                if (e.fillColor != null) 'fillColor': e.fillColor!.toARGB32(),
              },
              sourceElement: e,
            ),
            LayerElement _ => null,
            FrameElement e => _CanvasElement.frame(
              id: e.id,
              z: e.z,
              center: e.center,
              width: e.width,
              height: e.height,
              title: e.title,
              color: e.color,
              cornerRadius: e.cornerRadius,
              data: e.toMap(),
              sourceElement: e,
            ),
            TableElement e => _CanvasElement.table(
              id: e.id,
              z: e.z,
              center: e.center,
              width: e.width,
              height: e.height,
              color: e.borderColor,
              rotation: e.rotation,
              opacity: e.opacity,
              data: e.toMap(),
              sourceElement: e,
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
              data: e.toMap(),
              sourceElement: e,
            ),
            TextElement e => _CanvasElement.text(
              id: e.id,
              z: e.z,
              center: e.center,
              text: e.text,
              color: e.color,
              width: e.width,
              height: e.height,
              // The full payload: the element editing bar parses it with
              // CanvasElement.fromMap, which needs `type` and the text fields.
              data: e.toMap(),
              fontSize: e.fontSize,
              fontWeight: e.fontWeight,
              fontFamily: e.fontFamily,
              textAlign: e.textAlign,
              lineHeight: e.lineHeight,
              rotation: e.rotation,
              maxLines: e.maxLines,
              backgroundColor: e.backgroundColor,
              sourceElement: e,
            ),
            ImageElement e => _CanvasElement.image(
              id: e.id,
              z: e.z,
              center: e.center,
              width: e.width,
              height: e.height,
              imageBase64: e.imageBase64,
              data: e.toMap(),
              sourceElement: e,
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
              sourceElement: e,
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
              sourceElement: e,
            ),
          };
        })
        .whereType<_CanvasElement>()
        .toList();

    final draft = _shapeTransformDraft;
    final frameDragDeltas = <String, Offset>{};
    for (final element in mapped) {
      if (element.kind != _ElementKind.frame) continue;
      if (draft != null && element.id == draft.shapeId) {
        final d = draft.center - element.center;
        if (d != Offset.zero) frameDragDeltas[element.id] = d;
      } else if (_isDraggingShape &&
          _shapeDragPreviewCenter != null &&
          element.id == _canvasBloc.state.selectedShapeId) {
        final d = _shapeDragPreviewCenter! - element.center;
        if (d != Offset.zero) frameDragDeltas[element.id] = d;
      } else if (_groupDragDelta != null &&
          _groupDragDelta != Offset.zero &&
          _canvasBloc.state.selectedIds.contains(element.id)) {
        frameDragDeltas[element.id] = _groupDragDelta!;
      }
    }

    final processed = mapped.map((element) {
      _CanvasElement result = element;
      final source = metaById[element.id];
      if (source != null) {
        result = result.copyWith(
          opacity: source.opacity,
          layerBounds: elementBounds(source),
        );
      }

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
          rotation: draft.rotation,
          data: {...result.data, 'rotation': draft.rotation},
        );
      } else if (_isDraggingShape &&
          _shapeDragPreviewCenter != null &&
          result.id == _canvasBloc.state.selectedShapeId) {
        result = result.copyWith(center: _shapeDragPreviewCenter!);
      } else if (_groupDragDelta != null &&
          _groupDragDelta != Offset.zero &&
          _canvasBloc.state.selectedIds.contains(result.id)) {
        final delta = _groupDragDelta!;
        result = result.kind == _ElementKind.stroke
            ? result.copyWith(
                points: result.points.map((p) => p + delta).toList(),
              )
            : result.copyWith(center: result.center + delta);
      } else if (_isDraggingStroke &&
          _strokeDragDelta != null &&
          _strokeDragOriginalPoints != null &&
          result.id == _canvasBloc.state.selectedShapeId) {
        final original = _strokeDragOriginalPoints!;
        result = result.copyWith(
          points: original.map((p) => p + _strokeDragDelta!).toList(),
        );
      } else if (source != null &&
          frameDragDeltas.isNotEmpty &&
          frameDragDeltas.containsKey(
            hostFrameId(source, _canvasBloc.state.elements),
          )) {
        final delta =
            frameDragDeltas[hostFrameId(source, _canvasBloc.state.elements)]!;
        result = result.kind == _ElementKind.stroke
            ? result.copyWith(
                points: result.points.map((p) => p + delta).toList(),
              )
            : result.copyWith(center: result.center + delta);
      }

      return result;
    }).toList();

    processed.sort((a, b) {
      // Only lift an actively dragged non-frame element above opaque frames in
      // its band so the user can see it while dragging it onto a frame.
      // Dragging a frame itself keeps its band rank so higher layers stay on top
      // and the frame's own attached children remain visible on the frame.
      if (draft != null) {
        final draftEl = metaById[draft.shapeId];
        if (draftEl is! FrameElement) {
          if (a.id == draft.shapeId) return 1;
          if (b.id == draft.shapeId) return -1;
        }
      }
      if (_isDraggingShape && _canvasBloc.state.selectedShapeId != null) {
        final dragId = _canvasBloc.state.selectedShapeId!;
        final dragEl = metaById[dragId];
        if (dragEl is! FrameElement) {
          if (a.id == dragId) return 1;
          if (b.id == dragId) return -1;
        }
      }
      if (_isDraggingStroke && _canvasBloc.state.selectedShapeId != null) {
        if (a.id == _canvasBloc.state.selectedShapeId) return 1;
        if (b.id == _canvasBloc.state.selectedShapeId) return -1;
      }
      final aRank = paintRank[a.id] ?? 0;
      final bRank = paintRank[b.id] ?? 0;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.id.compareTo(b.id);
    });

    if (canUseCache) {
      _cachedMapElementsInput = elements;
      _cachedMappedElements = processed;
    }
    return processed;
  }

  String? _hitTestConnectableShapeId(
    List<_CanvasElement> elements,
    Offset position,
  ) {
    final hitId = _hitTestShape(elements, position);
    if (hitId == null) return null;
    final hit = elements.where((e) => e.id == hitId).firstOrNull;
    if (hit == null ||
        hit.kind == _ElementKind.stroke ||
        hit.kind == _ElementKind.connector) {
      return null;
    }
    return hitId;
  }

  /// Fills the topmost shape or closed freehand outline under [point].
  ///
  /// The loop walks the painted order backwards and stops at the first
  /// fillable candidate, so art above it is respected. Locked/hidden elements
  /// and their layers are skipped. A closed outline uses a screen-constant gap
  /// tolerance, keeping the fill action predictable at every zoom level.
  void _fillTopmostAt(
    CanvasState state,
    List<_CanvasElement> elements,
    Offset point,
  ) {
    final sourceById = {
      for (final element in state.elements) element.id: element,
    };
    final closureTolerance = 24 / _viewportScale;
    for (var i = elements.length - 1; i >= 0; i--) {
      final candidate = elements[i];
      final source = sourceById[candidate.id];
      if (source == null ||
          source.hidden ||
          source.locked ||
          _lockedLayerElementIds.contains(candidate.id)) {
        continue;
      }
      if (source is ShapeElement &&
          elementContains(source, point, tolerance: 12)) {
        _canvasBloc.add(
          CanvasUpdateShapeFill(
            shapeId: candidate.id,
            fillMode: 'solid',
            fillColor: state.selectedColor,
          ),
        );
        _canvasBloc.add(CanvasSelectShape(candidate.id));
        return;
      }
      if (source is StrokeElement &&
          strokeContainsClosedRegion(
            source,
            point,
            closureTolerance: closureTolerance,
          )) {
        _canvasBloc.add(
          CanvasFillStroke(strokeId: candidate.id, color: state.selectedColor),
        );
        _canvasBloc.add(CanvasSelectShape(candidate.id));
        return;
      }
    }
  }

  String? _hitTestShape(List<_CanvasElement> elements, Offset position) {
    // Resolve against the domain elements so hit geometry comes from the same
    // shared module as painting, erasing and export.
    final sourceById = <String, CanvasElement>{
      for (final element in _canvasBloc.state.elements) element.id: element,
    };
    for (var i = elements.length - 1; i >= 0; i--) {
      final element = elements[i];
      final source = sourceById[element.id];
      if (source == null ||
          source.hidden ||
          source.locked ||
          _lockedLayerElementIds.contains(element.id)) {
        continue;
      }
      if (source is FrameElement) {
        final rect = frameRect(source);
        if (_enteredFrameId == source.id) {
          // When entered, only the border acts as a frame handle so elements
          // inside can be clicked and dragged individually.
          final onBorder =
              rect.contains(position) && !rect.deflate(8).contains(position);
          if (onBorder) return element.id;
        } else if (rect.contains(position)) {
          return element.id;
        }
        continue;
      }
      // Elements attached to a frame can only be selected after double-clicking
      // to enter that frame.
      if (hostFrameId(source, _canvasBloc.state.elements) != null &&
          hostFrameId(source, _canvasBloc.state.elements) != _enteredFrameId) {
        continue;
      }
      if (source is ConnectorElement) {
        // Resolve exactly like the painter so the tappable line follows the
        // drawn curve/step instead of the straight chord.
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
        final distance = distanceToPolyline(
          connectorPolyline(start, end, element.lineStyle),
          position,
        );
        if (distance <= element.strokeWidth / 2 + 14.0) {
          return element.id;
        }
        continue;
      }
      if (elementContains(source, position, tolerance: 12.0)) {
        return element.id;
      }
    }
    return null;
  }

  void _syncEditingBarSelection(CanvasState state) {
    final id = state.selectedShapeId;
    if (_editingBarSelectionId == id) return;
    _editingBarSelectionId = id;
    _elementEditorDismissed = false;
    _activeEditControl = null;
  }

  bool _showsElementEditingBar(CanvasState state) =>
      state.canEdit &&
      state.currentToolMode == CanvasToolMode.select &&
      state.selectedIds.length == 1 &&
      state.selectedShapeId != null &&
      _textEditor == null &&
      !_elementEditorDismissed;

  /// Replaces the main toolbar with direct object controls while one element
  /// is selected. Sliders and switches open above this bar, not in a tray.
  Widget _buildElementEditingBar(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    if (!_showsElementEditingBar(state)) return const SizedBox.shrink();
    final selected = mappedElements.where((e) => e.id == state.selectedShapeId);
    if (selected.isEmpty) return const SizedBox.shrink();
    final element = selected.first;
    final parsed =
        element.sourceElement ??
        CanvasElement.fromMap(element.id, element.data);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final actions = <({String id, IconData icon, String label})>[];
    switch (element.kind) {
      case _ElementKind.shape:
        actions.addAll([
          (id: 'fill', icon: LucideIcons.paintBucket, label: 'Fill'),
          (id: 'color', icon: LucideIcons.palette, label: 'Colour'),
          (id: 'outline', icon: LucideIcons.penLine, label: 'Outline'),
          (id: 'stroke', icon: LucideIcons.brush, label: 'Stroke'),
          (id: 'flip', icon: LucideIcons.flipHorizontal, label: 'Flip'),
          (id: 'opacity', icon: LucideIcons.droplet, label: 'Opacity'),
        ]);
      case _ElementKind.stroke:
        actions.addAll([
          (id: 'fill', icon: LucideIcons.paintBucket, label: 'Fill'),
          (id: 'color', icon: LucideIcons.palette, label: 'Colour'),
          (id: 'width', icon: LucideIcons.brush, label: 'Width'),
          (id: 'opacity', icon: LucideIcons.droplet, label: 'Opacity'),
        ]);
      case _ElementKind.text:
        actions.addAll([
          (id: 'edit', icon: LucideIcons.pencil, label: 'Edit'),
          (id: 'size', icon: LucideIcons.type, label: 'Size'),
          (id: 'color', icon: LucideIcons.palette, label: 'Colour'),
          (id: 'rotation', icon: LucideIcons.rotateCw, label: 'Rotate'),
        ]);
      case _ElementKind.stickyNote:
        actions.addAll([
          (id: 'edit', icon: LucideIcons.pencil, label: 'Edit'),
          (id: 'color', icon: LucideIcons.palette, label: 'Colour'),
          (id: 'size', icon: LucideIcons.type, label: 'Text size'),
        ]);
      case _ElementKind.frame:
        actions.addAll([
          (id: 'title', icon: LucideIcons.type, label: 'Title'),
          (id: 'radius', icon: LucideIcons.slidersHorizontal, label: 'Corners'),
          (id: 'clip', icon: LucideIcons.scissors, label: 'Clip'),
          (id: 'color', icon: LucideIcons.palette, label: 'Colour'),
          (id: 'duplicate', icon: LucideIcons.copy, label: 'Duplicate'),
        ]);
      case _ElementKind.connector:
        actions.addAll([
          (id: 'color', icon: LucideIcons.palette, label: 'Colour'),
          (id: 'width', icon: LucideIcons.brush, label: 'Width'),
        ]);
      case _ElementKind.image:
        actions.addAll([
          (id: 'opacity', icon: LucideIcons.droplet, label: 'Opacity'),
          (id: 'duplicate', icon: LucideIcons.copy, label: 'Duplicate'),
        ]);
      case _ElementKind.table:
        actions.addAll([
          (id: 'edit', icon: LucideIcons.pencil, label: 'Edit cells'),
          (id: 'tableLayout', icon: LucideIcons.grid2x2, label: 'Rows/Cols'),
          (id: 'color', icon: LucideIcons.palette, label: 'Border'),
          (id: 'fill', icon: LucideIcons.paintBucket, label: 'Fill'),
          (id: 'width', icon: LucideIcons.brush, label: 'Width'),
          (id: 'opacity', icon: LucideIcons.droplet, label: 'Opacity'),
          (id: 'duplicate', icon: LucideIcons.copy, label: 'Duplicate'),
        ]);
    }

    void activate(String id) {
      if (id == 'edit') {
        if (parsed is TextElement) {
          _beginTextEditing(parsed, parsed.center);
        } else if (parsed is StickyNoteElement) {
          _editStickyNote(element);
        } else if (parsed is TableElement) {
          _editTableCellDialog(parsed);
        }
        return;
      }
      if (id == 'title' && parsed is FrameElement) {
        _editFrameTitleDialog(parsed);
        return;
      }
      if (id == 'duplicate') {
        _canvasBloc.add(CanvasDuplicateElements({element.id}));
        return;
      }
      if (id == 'delete') {
        if (parsed is FrameElement) {
          _confirmDeleteFrame(parsed.id);
        } else {
          _canvasBloc.add(CanvasDeleteElement(element.id));
        }
        return;
      }
      setState(() {
        _activeEditControl = _activeEditControl == id ? null : id;
      });
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomInset + 6,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_activeEditControl != null) _elementEditPanel(state, parsed),
              if (_activeEditControl != null) const SizedBox(height: 6),
              Material(
                color: _tokens.paper,
                elevation: 6,
                borderRadius: BorderRadius.circular(InkRadii.glassBar),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 30, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _elementEditorLabel(element.kind),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: InkType.label(_tokens.inkMuted),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final action in actions)
                                    _elementEditAction(
                                      action.icon,
                                      action.label,
                                      active: _activeEditControl == action.id,
                                      onTap: () => activate(action.id),
                                    ),
                                  _elementEditAction(
                                    LucideIcons.trash2,
                                    'Delete',
                                    danger: true,
                                    onTap: () => activate('delete'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Close editing options',
                        splashRadius: 14,
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        onPressed: () => setState(() {
                          _activeEditControl = null;
                          _elementEditorDismissed = true;
                        }),
                        icon: Icon(LucideIcons.x, color: _tokens.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _elementEditorLabel(_ElementKind kind) => switch (kind) {
    _ElementKind.shape => 'Shape',
    _ElementKind.stroke => 'Doodle',
    _ElementKind.text => 'Text',
    _ElementKind.stickyNote => 'Sticky note',
    _ElementKind.frame => 'Frame',
    _ElementKind.connector => 'Connector',
    _ElementKind.image => 'Image',
    _ElementKind.table => 'Table',
  };

  Widget _fillSwatch({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Colour ${color.toARGB32().toRadixString(16)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? _tokens.accent : Colors.black12,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _elementEditAction(
    IconData icon,
    String tooltip, {
    bool active = false,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger
        ? _tokens.danger
        : active
        ? _tokens.accent
        : _tokens.ink;
    return IconButton(
      tooltip: tooltip,
      splashRadius: 18,
      iconSize: 18,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? _tokens.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
      onPressed: onTap,
      icon: Icon(icon, color: color),
    );
  }

  Widget _elementEditPanel(CanvasState state, CanvasElement element) {
    final control = _activeEditControl;
    if (control == null) return const SizedBox.shrink();
    final panel = Container(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _tokens.paper,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: _elementEditControlBody(state, element, control),
      ),
    );
    return panel;
  }

  Widget _elementEditControlBody(
    CanvasState state,
    CanvasElement element,
    String control,
  ) {
    if (control == 'color') {
      final current = switch (element) {
        ShapeElement e => e.color,
        TextElement e => e.color,
        StickyNoteElement e => e.color,
        FrameElement e => e.color,
        TableElement e => e.borderColor,
        ConnectorElement e => e.color,
        StrokeElement e => e.color,
        ImageElement _ => _tokens.ink,
        LayerElement _ => _tokens.ink,
      };
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final color in canvasEditorPalette)
            _fillSwatch(
              color: color,
              selected: color == current,
              onTap: () => _applyElementColor(element, color),
            ),
        ],
      );
    }

    if (control == 'outline' && element is ShapeElement) {
      final current = element.resolvedStrokeColor;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outline color', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final color in canvasEditorPalette)
                _fillSwatch(
                  color: color,
                  selected: color == current,
                  onTap: () => _canvasBloc.add(
                    CanvasUpdateSelectedShapeStrokeColor(color),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    if (control == 'flip' && element is ShapeElement) {
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          FilterChip(
            avatar: const Icon(LucideIcons.flipHorizontal, size: 15),
            label: const Text('Flip horizontal'),
            selected: element.flipH,
            onSelected: (_) => _canvasBloc.add(
              const CanvasFlipSelectedShape(horizontal: true),
            ),
          ),
          FilterChip(
            avatar: const Icon(Icons.flip, size: 15),
            label: const Text('Flip vertical'),
            selected: element.flipV,
            onSelected: (_) => _canvasBloc.add(
              const CanvasFlipSelectedShape(vertical: true),
            ),
          ),
        ],
      );
    }

    if (control == 'radius' && element is FrameElement) {
      return _elementEditSlider(
        'Corner radius',
        element.cornerRadius.clamp(0, 48),
        0,
        48,
        (v) => _canvasBloc.add(
          CanvasUpdateFrame(elementId: element.id, cornerRadius: v),
        ),
      );
    }

    if (control == 'clip' && element is FrameElement) {
      return SwitchListTile.adaptive(
        activeColor: Colors.white,
        activeTrackColor: _tokens.accent,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Clip contents inside frame'),
        subtitle: const Text('Hide artwork outside frame bounds'),
        value: element.clipContents,
        onChanged: (v) => _canvasBloc.add(
          CanvasUpdateFrame(elementId: element.id, clipContents: v),
        ),
      );
    }

    if (control == 'tableLayout' && element is TableElement) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Rows: ${element.rows}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remove last row',
                icon: const Icon(LucideIcons.minus, size: 16),
                onPressed: element.rows > 1
                    ? () => _canvasBloc.add(
                        CanvasUpdateTableStyle(
                          tableId: element.id,
                          removeRowAt: element.rows - 1,
                        ),
                      )
                    : null,
              ),
              IconButton(
                tooltip: 'Add row',
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => _canvasBloc.add(
                  CanvasUpdateTableStyle(
                    tableId: element.id,
                    insertRowAt: element.rows,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Cols: ${element.columns}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remove last column',
                icon: const Icon(LucideIcons.minus, size: 16),
                onPressed: element.columns > 1
                    ? () => _canvasBloc.add(
                        CanvasUpdateTableStyle(
                          tableId: element.id,
                          removeColumnAt: element.columns - 1,
                        ),
                      )
                    : null,
              ),
              IconButton(
                tooltip: 'Add column',
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: () => _canvasBloc.add(
                  CanvasUpdateTableStyle(
                    tableId: element.id,
                    insertColumnAt: element.columns,
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            activeColor: Colors.white,
            activeTrackColor: _tokens.accent,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Header row', style: TextStyle(fontSize: 13)),
            value: element.headerRow,
            onChanged: (v) => _canvasBloc.add(
              CanvasUpdateTableStyle(tableId: element.id, headerRow: v),
            ),
          ),
          _elementEditSlider(
            'Font size',
            element.fontSize.clamp(10, 28),
            10,
            28,
            (v) => _canvasBloc.add(
              CanvasUpdateTableStyle(tableId: element.id, fontSize: v),
            ),
          ),
        ],
      );
    }

    if (control == 'fill' && element is TableElement) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Header tint', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final color in const [
                Color(0xFFF1F5F9),
                Color(0xFFDBEAFE),
                Color(0xFFDCFCE7),
                Color(0xFFFEF3C7),
                Color(0xFFF3E8FF),
                Color(0xFFFEE2E2),
              ])
                _fillSwatch(
                  color: color,
                  selected: color == element.headerBackgroundColor,
                  onTap: () => _canvasBloc.add(
                    CanvasUpdateTableStyle(
                      tableId: element.id,
                      headerBackgroundColor: color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    if (control == 'fill' && element is StrokeElement) {
      final fill = element.fillColor;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                fill == null ? 'No fill' : 'Filled outline',
                style: const TextStyle(fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: fill == null
                    ? null
                    : () => _canvasBloc.add(CanvasClearStrokeFill(element.id)),
                icon: const Icon(LucideIcons.ban, size: 16),
                label: const Text('Remove fill'),
                style: TextButton.styleFrom(
                  foregroundColor: _tokens.danger,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final color in canvasEditorPalette)
                _fillSwatch(
                  color: color,
                  selected: color == fill,
                  onTap: () => _canvasBloc.add(
                    CanvasFillStroke(strokeId: element.id, color: color),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    if (control == 'fill' && element is ShapeElement) {
      final filled = element.effectiveFillMode != 'none';
      final currentFill = element.resolvedFillColor;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Filled', style: TextStyle(fontSize: 13)),
              const Spacer(),
              Switch.adaptive(
                value: filled,
                activeColor: Colors.white,
                activeTrackColor: _tokens.accent,
                onChanged: (value) {
                  _canvasBloc.add(
                    CanvasUpdateShapeFill(fillMode: value ? 'solid' : 'none'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in canvasEditorPalette)
                _fillSwatch(
                  color: color,
                  selected:
                      filled &&
                      element.effectiveFillMode == 'solid' &&
                      color == currentFill,
                  onTap: () => _canvasBloc.add(
                    CanvasUpdateShapeFill(
                      shapeId: element.id,
                      fillMode: 'solid',
                      fillColor: color,
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _pickShapeFillColor(solidFill: true),
                icon: const Icon(LucideIcons.palette, size: 16),
                label: const Text('Custom'),
                style: TextButton.styleFrom(
                  foregroundColor: _tokens.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (control == 'opacity') {
      final source = state.elements
          .where((e) => e.id == element.id)
          .firstOrNull;
      final value = source?.opacity ?? element.opacity;
      return _elementEditSlider('Opacity', value.clamp(0, 1), 0, 1, (v) {
        if (element is StrokeElement) {
          _canvasBloc.add(CanvasUpdateSelectedStrokeOpacity(v));
        } else {
          // Shapes, images, text and other objects fade as a whole so a filled
          // shape's interior changes with its outline.
          _canvasBloc.add(CanvasSetElementOpacity(element.id, v));
        }
      }, percent: true);
    }

    if (control == 'width' || control == 'stroke') {
      if (element is TableElement) {
        return _elementEditSlider(
          'Border',
          element.borderWidth.clamp(0.5, 8.0),
          0.5,
          8.0,
          (v) => _canvasBloc.add(
            CanvasUpdateTableStyle(tableId: element.id, borderWidth: v),
          ),
          decimals: 1,
        );
      }
      final value = switch (element) {
        ShapeElement e => e.strokeWidth,
        ConnectorElement e => e.strokeWidth,
        StrokeElement _ => state.selectedStrokeWidth,
        _ => 1.0,
      };
      return _elementEditSlider(
        control == 'stroke' ? 'Stroke width' : 'Width',
        value.clamp(1, 48),
        1,
        48,
        (v) {
          if (element is ShapeElement) {
            _canvasBloc.add(CanvasUpdateSelectedShapeStrokeWidth(v));
          } else if (element is ConnectorElement) {
            _canvasBloc.add(
              CanvasUpdateConnector(elementId: element.id, strokeWidth: v),
            );
          } else if (element is StrokeElement) {
            _canvasBloc.add(CanvasUpdateSelectedStrokeWidth(v));
          }
        },
        decimals: 0,
      );
    }

    if (control == 'size') {
      if (element is TextElement) {
        return _elementEditSlider(
          'Text size',
          element.fontSize.clamp(8, 96),
          8,
          96,
          (v) => _canvasBloc.add(
            CanvasUpdateText(elementId: element.id, fontSize: v),
          ),
        );
      }
      if (element is StickyNoteElement) {
        return _elementEditSlider(
          'Text size',
          element.fontSize.clamp(8, 48),
          8,
          48,
          (v) => _canvasBloc.add(
            CanvasUpdateStickyNote(elementId: element.id, fontSize: v),
          ),
        );
      }
    }

    if (control == 'rotation' && element is TextElement) {
      return _elementEditSlider(
        'Rotation',
        element.rotation.clamp(0, math.pi * 2),
        0,
        math.pi * 2,
        (v) => _canvasBloc.add(
          CanvasUpdateText(elementId: element.id, rotation: v),
        ),
        degrees: true,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _elementEditSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int decimals = 0,
    bool percent = false,
    bool degrees = false,
  }) {
    final suffix = percent
        ? '${(value * 100).round()}%'
        : degrees
        ? '${(value * 180 / math.pi).round()}°'
        : value.toStringAsFixed(decimals);
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            suffix,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: _tokens.inkMuted),
          ),
        ),
      ],
    );
  }

  void _applyElementColor(CanvasElement element, Color color) {
    switch (element) {
      case ShapeElement e:
        _canvasBloc.add(CanvasUpdateSelectedShapeColor(color));
        if (e.effectiveFillMode != 'none') {
          _canvasBloc.add(
            CanvasUpdateShapeFill(shapeId: e.id, fillColor: color),
          );
        }
      case TextElement e:
        _canvasBloc.add(CanvasUpdateText(elementId: e.id, color: color));
      case StickyNoteElement e:
        _canvasBloc.add(CanvasUpdateStickyNote(elementId: e.id, color: color));
      case FrameElement e:
        _canvasBloc.add(CanvasUpdateFrame(elementId: e.id, color: color));
      case TableElement e:
        _canvasBloc.add(
          CanvasUpdateTableStyle(tableId: e.id, borderColor: color),
        );
      case ConnectorElement e:
        _canvasBloc.add(CanvasUpdateConnector(elementId: e.id, color: color));
      case StrokeElement _:
        _canvasBloc.add(CanvasUpdateSelectedStrokeColor(color.value));
      case ImageElement _:
      case LayerElement _:
        break;
    }
  }

  /// Outline and transform handles of the selected element. Kept below the
  /// trays so an open tray always covers the selection rather than the
  /// selection drawing over the tray.
  Widget _buildSelectionOutline(
    CanvasState state,
    List<_CanvasElement> mappedElements,
  ) {
    final rawIds = state.selectedIds.isNotEmpty
        ? state.selectedIds
        : (state.selectedShapeId != null
              ? <String>{state.selectedShapeId!}
              : <String>{});
    if (rawIds.isEmpty) return const SizedBox.shrink();
    final selectedFrameIds = {
      for (final element in state.elements)
        if (element is FrameElement && rawIds.contains(element.id)) element.id,
    };
    final ids = selectedFrameIds.isEmpty
        ? rawIds
        : {
            for (final id in rawIds)
              if (!state.elements.any(
                (e) =>
                    e.id == id &&
                    e.frameId != null &&
                    selectedFrameIds.contains(e.frameId),
              ))
                id,
          };
    if (ids.isEmpty) return const SizedBox.shrink();
    if (!state.canEdit) {
      return Stack(
        children: [
          for (final element in state.elements)
            if (ids.contains(element.id))
              _buildMultiSelectionOutline(_groupPreviewElement(element)),
        ],
      );
    }
    if (ids.length == 1) {
      final selected = mappedElements.where((e) => e.id == ids.first);
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
    // Multi-select: outline each element, reflecting active group transforms.
    return Stack(
      children: [
        for (final element in state.elements)
          if (ids.contains(element.id))
            _buildMultiSelectionOutline(_groupPreviewElement(element)),
      ],
    );
  }

  CanvasElement _groupPreviewElement(CanvasElement element) {
    if (_groupScaleSource == null && _groupRotationPivot == null) {
      return element;
    }
    final state = _canvasBloc.state;
    if (!state.selectedIds.contains(element.id) || element.locked) {
      return element;
    }
    final source = _groupScaleSource;
    final target = _groupScaleTarget;
    if (source != null && target != null) {
      return CanvasElement.fromMap(
        element.id,
        scaleElementPayload(element, source, target),
      );
    }
    final pivot = _groupRotationPivot;
    if (pivot != null && _groupRotationDelta.abs() > 1e-4) {
      return CanvasElement.fromMap(
        element.id,
        rotateElementPayload(element, pivot, _groupRotationDelta),
      );
    }
    return element;
  }

  Rect? _selectionWorldBounds([List<CanvasElement>? elements]) {
    final state = _canvasBloc.state;
    final source = elements ?? state.elements;
    return elementsBounds(
      source.where((element) => state.selectedIds.contains(element.id)),
    );
  }

  /// Union box plus 8 scale handles and a rotate handle for 2+ selected.
  Widget _buildGroupTransformOverlay(CanvasState state) {
    if (!state.canEdit || state.selectedIds.length < 2) {
      return const SizedBox.shrink();
    }
    final preview = state.elements.map(_groupPreviewElement).toList();
    var bounds = _selectionWorldBounds(preview);
    if (bounds == null) return const SizedBox.shrink();
    if (_groupDragDelta != null) {
      bounds = bounds.shift(_groupDragDelta!);
    }
    final topLeft = _toScreen(bounds.topLeft);
    final bottomRight = _toScreen(bounds.bottomRight);
    final width = math.max(1.0, bottomRight.dx - topLeft.dx);
    final height = math.max(1.0, bottomRight.dy - topLeft.dy);

    return Stack(
      children: [
        Positioned(
          left: topLeft.dx,
          top: topLeft.dy,
          width: width,
          height: height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: _tokens.accent.withValues(alpha: 0.04),
                border: Border.all(color: _tokens.accent, width: 1.5),
              ),
            ),
          ),
        ),
        ..._buildGroupScaleHandles(topLeft, width, height),
        _buildGroupRotateHandle(topLeft, width, height),
      ],
    );
  }

  List<Widget> _buildGroupScaleHandles(
    Offset topLeft,
    double width,
    double height,
  ) {
    const hitSize = 24.0;
    final positions = <Offset>[
      Offset(topLeft.dx, topLeft.dy),
      Offset(topLeft.dx + width / 2, topLeft.dy),
      Offset(topLeft.dx + width, topLeft.dy),
      Offset(topLeft.dx + width, topLeft.dy + height / 2),
      Offset(topLeft.dx + width, topLeft.dy + height),
      Offset(topLeft.dx + width / 2, topLeft.dy + height),
      Offset(topLeft.dx, topLeft.dy + height),
      Offset(topLeft.dx, topLeft.dy + height / 2),
    ];
    return [
      for (var index = 0; index < positions.length; index++)
        Positioned(
          left: positions[index].dx - hitSize / 2,
          top: positions[index].dy - hitSize / 2,
          width: hitSize,
          height: hitSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) =>
                _startGroupScale(index, details.globalPosition),
            onPanUpdate: _updateGroupScale,
            onPanEnd: (_) => _endGroupScale(),
            onPanCancel: _endGroupScale,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _tokens.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildGroupRotateHandle(Offset topLeft, double width, double height) {
    // Keep the rotate handle reachable when the box hugs the top edge.
    final aboveTop = topLeft.dy >= 46;
    return Positioned(
      left: topLeft.dx + width / 2 - 15,
      top: aboveTop ? topLeft.dy - 42 : topLeft.dy + height + 12,
      width: 30,
      height: 30,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _startGroupRotate,
        onPanUpdate: _updateGroupRotate,
        onPanEnd: (_) => _endGroupRotate(),
        onPanCancel: _endGroupRotate,
        child: _buildHandle(LucideIcons.rotateCw),
      ),
    );
  }

  void _startGroupScale(int handle, Offset globalPosition) {
    final bounds = _selectionWorldBounds();
    if (bounds == null) return;
    _setShapeEditing(true);
    setState(() {
      _groupScaleHandle = handle;
      _groupScaleSource = bounds;
      _groupScaleTarget = bounds;
      _groupScaleStartGlobal = globalPosition;
    });
  }

  void _updateGroupScale(DragUpdateDetails details) {
    final source = _groupScaleSource;
    final handle = _groupScaleHandle;
    if (source == null || handle == null) return;
    final delta =
        (details.globalPosition - _groupScaleStartGlobal) / _viewportScale;
    const minSize = 12.0;
    var left = source.left;
    var top = source.top;
    var right = source.right;
    var bottom = source.bottom;
    if (handle == 0 || handle == 6 || handle == 7) {
      left = math.min(left + delta.dx, right - minSize);
    }
    if (handle == 2 || handle == 3 || handle == 4) {
      right = math.max(right + delta.dx, left + minSize);
    }
    if (handle == 0 || handle == 1 || handle == 2) {
      top = math.min(top + delta.dy, bottom - minSize);
    }
    if (handle == 4 || handle == 5 || handle == 6) {
      bottom = math.max(bottom + delta.dy, top + minSize);
    }
    setState(() => _groupScaleTarget = Rect.fromLTRB(left, top, right, bottom));
  }

  void _endGroupScale() {
    final source = _groupScaleSource;
    final target = _groupScaleTarget;
    final changed =
        source != null &&
        target != null &&
        ((source.width - target.width).abs() > 0.5 ||
            (source.height - target.height).abs() > 0.5);
    if (changed) {
      _canvasBloc.add(
        CanvasScaleSelection(sourceBounds: source, targetBounds: target),
      );
    }
    setState(() {
      _groupScaleSource = null;
      _groupScaleTarget = null;
      _groupScaleHandle = null;
    });
    _setShapeEditing(false);
  }

  Offset _worldToGlobal(Offset world) {
    final local = _toScreen(world);
    final canvasBox =
        _canvasPreviewKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox != null && canvasBox.hasSize) {
      return canvasBox.localToGlobal(local);
    }
    final rootBox = context.findRenderObject() as RenderBox?;
    if (rootBox != null && rootBox.hasSize) {
      return rootBox.localToGlobal(local);
    }
    return local;
  }

  void _startGroupRotate(DragStartDetails details) {
    final bounds = _selectionWorldBounds();
    if (bounds == null) return;
    final pivot = bounds.center;
    final vector = details.globalPosition - _worldToGlobal(pivot);
    _setShapeEditing(true);
    setState(() {
      _groupRotationPivot = pivot;
      _groupRotationDelta = 0;
      _groupRotationPrevAngle = vector.distanceSquared > 1e-4
          ? math.atan2(vector.dy, vector.dx)
          : 0.0;
    });
  }

  void _updateGroupRotate(DragUpdateDetails details) {
    final pivot = _groupRotationPivot;
    if (pivot == null) return;
    final vector = details.globalPosition - _worldToGlobal(pivot);
    if (vector.distanceSquared < 1e-4) return;
    final angle = math.atan2(vector.dy, vector.dx);
    var diff = angle - _groupRotationPrevAngle;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    setState(() {
      _groupRotationPrevAngle = angle;
      _groupRotationDelta += diff;
    });
  }

  void _endGroupRotate() {
    final pivot = _groupRotationPivot;
    final delta = _groupRotationDelta;
    if (pivot != null && delta.abs() > 0.01) {
      _canvasBloc.add(CanvasRotateSelection(pivot: pivot, radians: delta));
    }
    setState(() {
      _groupRotationPivot = null;
      _groupRotationDelta = 0;
      _groupRotationPrevAngle = 0;
    });
    _setShapeEditing(false);
  }

  Widget _buildMultiSelectionOutline(CanvasElement element) {
    var bounds = elementBounds(element);
    if (bounds == null) return const SizedBox.shrink();
    if (_groupDragDelta != null &&
        _canvasBloc.state.selectedIds.contains(element.id)) {
      bounds = bounds.shift(_groupDragDelta!);
    }
    final topLeft = _toScreen(bounds.topLeft);
    final bottomRight = _toScreen(bounds.bottomRight);
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: math.max(1.0, bottomRight.dx - topLeft.dx),
      height: math.max(1.0, bottomRight.dy - topLeft.dy),
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _tokens.accent, width: 1.5),
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
                  lineStyle: element.lineStyle,
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
              child: const Icon(
                LucideIcons.trash2,
                size: 14,
                color: Colors.white,
              ),
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
    final target = _hitTestConnectorTarget(
      world,
      connectorId,
      isStart: isStart,
    );
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
    final ordered = orderedElementsForPaint(elements);
    for (var i = ordered.length - 1; i >= 0; i--) {
      final element = ordered[i];
      if (element.hidden ||
          element.id == connectorId ||
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

  /// World-space box a connector end snaps to, from the shared geometry.
  Rect _elementLinkBounds(CanvasElement element) {
    return elementBounds(element) ?? Rect.zero;
  }

  // ──────────────────────────────────────────────
  // Primary toolbar
  // ──────────────────────────────────────────────

  /// Inserts a frame behind the current art at the middle of the viewport.
  void _startFrameDraw() {
    setState(() {
      _enteredFrameId = null;
      _arrowConnectStartElementId = null;
      _isShapesPopupOpen = false;
    });
    _canvasBloc.add(const CanvasSetToolMode(CanvasToolMode.frame));
  }

  Widget _buildCanvasToolbar(CanvasState state) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 12,
      right: 12,
      // Ground the bar on the bottom safe area instead of leaving a gap.
      bottom: bottomInset,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: CanvasToolbar(
            activeTool: state.currentToolMode,
            canEdit: state.canEdit,
            actions: _bottomBarActions,
            isArrowPreset: _isArrowMode(state),
            isShapesPopupOpen: _isShapesPopupOpen,
            isLayersOpen: state.activeTray == 'layers',
            isToolsTrayOpen: state.activeTray == 'actions',
            onToolSelected: _onToolbarToolSelected,
            onActionSelected: _executeToolbarAction,
            onActionLongPressed: _executeToolbarActionLongPress,
            onMore: () => _toggleTray('actions'),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildShapesPickerPopup(CanvasState state) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _isShapesPopupOpen = false),
        ),
      ),
      // Desktop browser: beside the tool rail. Phones: above the toolbar.
      if (SlidingTray.useWebLayout(context))
        Positioned(
          left: 84,
          top: 120,
          child: ShapesPickerPopup(
            selectedType: state.pendingShapeType,
            onSelectShape: _selectShapeForDrawing,
            onClose: () => setState(() => _isShapesPopupOpen = false),
          ),
        )
      else
        Positioned(
          left: 12,
          right: 12,
          bottom: bottomInset + 66,
          child: Center(
            child: ShapesPickerPopup(
              selectedType: state.pendingShapeType,
              onSelectShape: _selectShapeForDrawing,
              onClose: () => setState(() => _isShapesPopupOpen = false),
            ),
          ),
        ),
    ];
  }

  Future<void> _openBottomBarCustomizer() async {
    final activeTray = _canvasBloc.state.activeTray;
    if (activeTray != null) {
      _canvasBloc.add(CanvasToggleTray(activeTray));
    }
    if (_isShapesPopupOpen) {
      setState(() => _isShapesPopupOpen = false);
    }
    final updated = await showBottomBarCustomizerSheet(
      context,
      initialActions: _bottomBarActions,
    );
    if (updated == null || !mounted) return;
    setState(() => _bottomBarActions = updated);
    await widget.onSaveBottomBarActions?.call(updated);
  }

  void _executeToolbarActionLongPress(CanvasToolbarAction action) {
    final current = _canvasBloc.state;
    if (!current.canEdit && action.requiresEdit) return;
    final mode = switch (action) {
      CanvasToolbarAction.pen => CanvasToolMode.doodle,
      CanvasToolbarAction.highlight => CanvasToolMode.highlight,
      CanvasToolbarAction.eraser => CanvasToolMode.eraser,
      _ => null,
    };
    if (mode == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _arrowConnectStartElementId = null;
      _isShapesPopupOpen = false;
    });
    if (current.currentToolMode != mode) {
      _canvasBloc.add(CanvasSetToolMode(mode, keepTray: true));
    }
    if (current.activeTray != 'brushes') {
      _canvasBloc.add(const CanvasToggleTray('brushes'));
    }
  }

  void _executeToolbarAction(CanvasToolbarAction action) {
    final current = _canvasBloc.state;
    if (!current.canEdit && action.requiresEdit) return;

    void closeTrayIfOpen() {
      final tray = _canvasBloc.state.activeTray;
      if (tray != null) {
        _canvasBloc.add(CanvasToggleTray(tray));
      }
    }

    switch (action) {
      case CanvasToolbarAction.select:
        _onToolbarToolSelected(CanvasToolMode.select);
        return;
      case CanvasToolbarAction.hand:
        _onToolbarToolSelected(CanvasToolMode.hand);
        return;
      case CanvasToolbarAction.pen:
        _onToolbarToolSelected(CanvasToolMode.doodle);
        return;
      case CanvasToolbarAction.highlight:
        _onToolbarToolSelected(CanvasToolMode.highlight);
        return;
      case CanvasToolbarAction.eraser:
        _onToolbarToolSelected(CanvasToolMode.eraser);
        return;
      case CanvasToolbarAction.fill:
        _onToolbarToolSelected(CanvasToolMode.fill);
        return;
      case CanvasToolbarAction.shape:
        _onToolbarToolSelected(CanvasToolMode.shape);
        return;
      case CanvasToolbarAction.arrow:
        _onToolbarToolSelected(CanvasToolMode.arrow);
        return;
      case CanvasToolbarAction.text:
        _onToolbarToolSelected(CanvasToolMode.text);
        return;
      case CanvasToolbarAction.stickyNote:
        setState(() => _isShapesPopupOpen = false);
        closeTrayIfOpen();
        _addStickyNoteDialog();
        return;
      case CanvasToolbarAction.frame:
        setState(() => _isShapesPopupOpen = false);
        closeTrayIfOpen();
        _startFrameDraw();
        return;
      case CanvasToolbarAction.image:
        setState(() => _isShapesPopupOpen = false);
        closeTrayIfOpen();
        _uploadImageToCanvas();
        return;
      case CanvasToolbarAction.layers:
        _toggleTray('layers');
        return;
      case CanvasToolbarAction.templates:
        setState(() => _isShapesPopupOpen = false);
        closeTrayIfOpen();
        _showTemplateGallerySheet(context);
        return;
      case CanvasToolbarAction.table:
        setState(() => _isShapesPopupOpen = false);
        closeTrayIfOpen();
        _addTableDialog();
        return;
      case CanvasToolbarAction.connector:
        setState(() => _isShapesPopupOpen = false);
        closeTrayIfOpen();
        _addConnectorDialog();
        return;
    }
  }

  /// Marquee rectangle drawn while the Select tool drags on empty canvas.
  Rect _polygonBounds(List<Offset> points) {
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Freehand loop shown while the Select tool is in lasso mode.
  Widget _buildLassoOverlay() {
    final points = _lassoPoints;
    if (!_isLassoSelecting || points == null || points.length < 2) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _LassoOverlayPainter(
            points: points.map(_toScreen).toList(growable: false),
            color: _tokens.accent,
          ),
        ),
      ),
    );
  }

  /// Marquee/lasso switch, visible only while the Select tool is active.
  Widget _buildSelectionModeToggle(CanvasState state) {
    if (state.currentToolMode != CanvasToolMode.select) {
      return const SizedBox.shrink();
    }
    final bottomInset = MediaQuery.of(context).padding.bottom;
    Widget chip(CanvasSelectionMode mode, IconData icon, String tooltip) {
      final active = state.selectionMode == mode;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _canvasBloc.add(CanvasSetSelectionMode(mode)),
          child: Container(
            width: 34,
            height: 30,
            decoration: BoxDecoration(
              color: active
                  ? _tokens.accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 17,
              color: active ? _tokens.accent : _tokens.inkMuted,
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: InkSpacing.s16,
      bottom: math.max(96.0, bottomInset + 72),
      child: Material(
        color: _tokens.paper,
        elevation: 3,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chip(
                CanvasSelectionMode.marquee,
                Icons.crop_free,
                'Marquee select',
              ),
              chip(CanvasSelectionMode.lasso, Icons.gesture, 'Lasso select'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarqueeOverlay() {
    final start = _marqueeStart;
    final end = _marqueeCurrent;
    if (!_isMarqueeSelecting || start == null || end == null) {
      return const SizedBox.shrink();
    }
    final topLeft = _toScreen(start);
    final bottomRight = _toScreen(end);
    final rect = Rect.fromPoints(topLeft, bottomRight);
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: _tokens.accent.withValues(alpha: 0.08),
            border: Border.all(color: _tokens.accent, width: 1),
          ),
        ),
      ),
    );
  }

  /// Align/distribute and multi-element actions, shown for 2+ selected.
  Widget _buildMultiSelectBar(CanvasState state) {
    if (state.selectedIds.length < 2) return const SizedBox.shrink();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final buttons = <(IconData, String, VoidCallback?)>[];
    if (state.canEdit) {
      buttons.addAll([
        (
          Icons.copy,
          'Copy',
          () => _canvasBloc.add(const CanvasCopySelection()),
        ),
        (
          Icons.content_paste,
          'Paste',
          state.hasClipboard
              ? () => _canvasBloc.add(const CanvasPasteSelection())
              : null,
        ),
        (
          Icons.format_align_left,
          'Align left',
          () => _canvasBloc.add(
            const CanvasAlignSelection(CanvasSelectionAlignment.left),
          ),
        ),
        (
          Icons.format_align_center,
          'Align centers',
          () => _canvasBloc.add(
            const CanvasAlignSelection(CanvasSelectionAlignment.centerX),
          ),
        ),
        (
          Icons.format_align_right,
          'Align right',
          () => _canvasBloc.add(
            const CanvasAlignSelection(CanvasSelectionAlignment.right),
          ),
        ),
        (
          Icons.vertical_align_top,
          'Align tops',
          () => _canvasBloc.add(
            const CanvasAlignSelection(CanvasSelectionAlignment.top),
          ),
        ),
        (
          Icons.vertical_align_center,
          'Align middles',
          () => _canvasBloc.add(
            const CanvasAlignSelection(CanvasSelectionAlignment.centerY),
          ),
        ),
        (
          Icons.vertical_align_bottom,
          'Align bottoms',
          () => _canvasBloc.add(
            const CanvasAlignSelection(CanvasSelectionAlignment.bottom),
          ),
        ),
        (
          Icons.horizontal_distribute,
          'Distribute horizontally',
          () => _canvasBloc.add(
            const CanvasAlignSelection(
              CanvasSelectionAlignment.distributeHorizontal,
            ),
          ),
        ),
        (
          Icons.vertical_distribute,
          'Distribute vertically',
          () => _canvasBloc.add(
            const CanvasAlignSelection(
              CanvasSelectionAlignment.distributeVertical,
            ),
          ),
        ),
        (
          Icons.layers_outlined,
          'Move to active layer',
          () => _canvasBloc.add(
            CanvasMoveSelectionToLayer(state.selectedIds, state.activeLayerId),
          ),
        ),
        (
          Icons.palette_outlined,
          'Style selection',
          () => _openSelectionStyleSheet(state),
        ),
        (
          Icons.copy_all,
          'Duplicate',
          () => _canvasBloc.add(CanvasDuplicateElements(state.selectedIds)),
        ),
        (
          Icons.delete_outline,
          'Delete',
          () => _canvasBloc.add(CanvasDeleteElements(state.selectedIds)),
        ),
      ]);
    }
    return Positioned(
      left: 12,
      right: 12,
      // Lift above the marquee/lasso switch when the Select tool is active.
      bottom:
          bottomInset +
          (state.currentToolMode == CanvasToolMode.select ? 100 : 58),
      child: Center(
        child: Material(
          color: _tokens.paper,
          elevation: 4,
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${state.selectedIds.length} selected',
                    style: TextStyle(fontSize: 11, color: _tokens.inkMuted),
                  ),
                ),
                for (final button in buttons)
                  IconButton(
                    tooltip: button.$2,
                    splashRadius: 18,
                    iconSize: 18,
                    onPressed: button.$3,
                    icon: Icon(button.$1, color: _tokens.ink),
                  ),
                if (state.canEdit)
                  PopupMenuButton<CanvasArrangeMode>(
                    tooltip: 'Arrange / Tidy up',
                    icon: Icon(
                      Icons.auto_awesome_mosaic_outlined,
                      size: 18,
                      color: _tokens.ink,
                    ),
                    onSelected: (mode) => _canvasBloc.add(
                      CanvasArrangeSelection(mode),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: CanvasArrangeMode.grid,
                        child: Text('Tidy into Grid'),
                      ),
                      PopupMenuItem(
                        value: CanvasArrangeMode.row,
                        child: Text('Arrange in Row'),
                      ),
                      PopupMenuItem(
                        value: CanvasArrangeMode.column,
                        child: Text('Arrange in Column'),
                      ),
                      PopupMenuItem(
                        value: CanvasArrangeMode.tree,
                        child: Text('Mind Map Tree'),
                      ),
                      PopupMenuItem(
                        value: CanvasArrangeMode.flow,
                        child: Text('Process Flow'),
                      ),
                    ],
                  ),
                if (!state.canEdit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Viewer',
                      style: TextStyle(fontSize: 11, color: _tokens.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSelectionStyleSheet(CanvasState state) {
    final selected = state.elements
        .where((element) => state.selectedIds.contains(element.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final allLocked = selected.every((element) => element.locked);
    final allVisible = selected.every((element) => !element.hidden);
    final opacity =
        selected.fold<double>(0, (sum, element) => sum + element.opacity) /
        selected.length;
    final ids = state.selectedIds;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(InkSpacing.s12),
        child: GlassPanel(
          radius: InkRadii.bottomSheet,
          padding: const EdgeInsets.all(InkSpacing.s20),
          child: SafeArea(
            top: false,
            child: CanvasSelectionStyleSheet(
              count: selected.length,
              initialOpacity: opacity.clamp(0.0, 1.0),
              allLocked: allLocked,
              allVisible: allVisible,
              onColor: (color) => _canvasBloc.add(
                CanvasUpdateSelectionStyle(ids, color: color),
              ),
              onOpacity: (value) => _canvasBloc.add(
                CanvasUpdateSelectionStyle(ids, opacity: value),
              ),
              onLockedChanged: (locked) => _canvasBloc.add(
                CanvasUpdateSelectionStyle(ids, locked: locked),
              ),
              onVisibleChanged: (visible) => _canvasBloc.add(
                CanvasUpdateSelectionStyle(ids, visible: visible),
              ),
              onClose: () => Navigator.pop(sheetContext),
            ),
          ),
        ),
      ),
    );
  }

  void _onToolbarToolSelected(CanvasToolMode mode) {
    final current = _canvasBloc.state;
    if (!current.canEdit &&
        mode != CanvasToolMode.select &&
        mode != CanvasToolMode.hand) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _arrowConnectStartElementId = null;
      if (mode != CanvasToolMode.shape) {
        _isShapesPopupOpen = false;
      }
    });
    if (mode == CanvasToolMode.shape) {
      final activeTray = current.activeTray;
      if (activeTray != null) {
        _canvasBloc.add(CanvasToggleTray(activeTray));
      }
      final nextOpen = !_isShapesPopupOpen;
      setState(() => _isShapesPopupOpen = nextOpen);
      if (nextOpen && current.currentToolMode != CanvasToolMode.shape) {
        _canvasBloc.add(
          CanvasSetToolMode(
            CanvasToolMode.shape,
            shapeType: current.pendingShapeType ?? CanvasShapeType.square,
          ),
        );
      }
      return;
    }
    if (mode == CanvasToolMode.doodle ||
        mode == CanvasToolMode.eraser ||
        mode == CanvasToolMode.highlight) {
      _canvasBloc.add(CanvasSetToolMode(mode));
      return;
    }
    _canvasBloc.add(CanvasSetToolMode(mode));
  }

  // ──────────────────────────────────────────────
  // Text tool
  // ──────────────────────────────────────────────

  /// Opens the in-place text editor. A null [element] starts a new text object
  /// at [topLeft]; otherwise the existing object is edited in place.
  void _beginTextEditing(TextElement? element, Offset topLeft) {
    if (!_canvasBloc.state.canEdit) return;
    _commitTextEditing();
    final width = element?.width ?? 0;
    final height = element?.height ?? 0;
    final draft = _TextEditorDraft(
      elementId: element?.id,
      topLeft: element?.center ?? topLeft,
      width: width > 0 ? width : 180,
      height: height > 0 ? height : 24,
      rotation: element?.rotation ?? 0,
      fontSize: element?.fontSize ?? 16,
      fontWeight: element?.fontWeight ?? 600,
      fontFamily: element?.fontFamily,
      textAlign: element?.textAlign ?? 'left',
      lineHeight: element?.lineHeight ?? 1.2,
      color: element?.color ?? _canvasBloc.state.selectedColor,
    );
    final controller = TextEditingController(text: element?.text ?? '');
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) _commitTextEditing();
    });
    setState(() {
      _textEditor = draft;
      _textEditingController = controller;
      _textEditingFocusNode = focusNode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _textEditingFocusNode == focusNode) {
        focusNode.requestFocus();
      }
    });
  }

  /// Commits the in-place editor once. Empty new text is discarded; an emptied
  /// existing text object is deleted by the bloc handler.
  void _commitTextEditing({bool cancel = false}) {
    final draft = _textEditor;
    if (draft == null) return;
    final controller = _textEditingController;
    final focusNode = _textEditingFocusNode;
    final text = controller?.text ?? '';
    if (mounted) {
      setState(() {
        _textEditor = null;
        _textEditingController = null;
        _textEditingFocusNode = null;
      });
    } else {
      _textEditor = null;
      _textEditingController = null;
      _textEditingFocusNode = null;
    }
    focusNode?.dispose();
    controller?.dispose();
    if (cancel) return;

    final elementId = draft.elementId;
    if (elementId == null) {
      if (text.trim().isEmpty) return;
      _canvasBloc.add(
        CanvasAddText(
          topLeft: draft.topLeft,
          text: text,
          color: draft.color,
          fontSize: draft.fontSize,
          fontWeight: draft.fontWeight,
          textAlign: draft.textAlign,
          rotation: draft.rotation,
        ),
      );
      // Switch to Select so the new text keeps a live editing bar, and keep
      // the selection through the tap that dismissed the editor.
      _canvasBloc.add(const CanvasSetToolMode(CanvasToolMode.select));
      _textCommitAt = DateTime.now();
    } else {
      _canvasBloc.add(CanvasUpdateText(elementId: elementId, text: text));
      _textCommitAt = DateTime.now();
    }
  }

  Widget _buildTextEditorOverlay() {
    final draft = _textEditor;
    final controller = _textEditingController;
    final focusNode = _textEditingFocusNode;
    if (draft == null || controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }
    final topLeft = _toScreen(draft.topLeft);
    final screenWidth = math.max(180.0, draft.width * _viewportScale);
    final fontSize = (draft.fontSize * _viewportScale).clamp(10.0, 72.0);
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: screenWidth,
      child: Transform.rotate(
        angle: draft.rotation,
        child: Material(
          color: _tokens.paper,
          elevation: 3,
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(24.0, draft.height * _viewportScale),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: CanvasTextLayout.fontWeightFromValue(
                  draft.fontWeight,
                ),
                fontFamily: draft.fontFamily,
                color: draft.color,
                height: draft.lineHeight,
              ),
              textAlign: CanvasTextLayout.textAlignFromName(draft.textAlign),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Type text',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 3,
                ),
              ),
              onSubmitted: (_) => _commitTextEditing(),
              onTapOutside: (_) => _commitTextEditing(),
            ),
          ),
        ),
      ),
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
    final screenRect = Rect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      bottomRight.dx,
      bottomRight.dy,
    );

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
                  border: Border.all(color: _tokens.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
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
                      color: Color(0x22000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _getShapeCenterGlobal(_CanvasElement shape, {Size? boxSize}) {
    final worldCenter = shape.kind == _ElementKind.text && boxSize != null
        ? shape.center + Offset(boxSize.width / 2, boxSize.height / 2)
        : shape.center;
    final centerLocal = _toScreen(worldCenter);
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
    if (state.selectedIds.length > 1) return const SizedBox.shrink();
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
            width:
                (_shapeTransformDraft!.width != null &&
                    _shapeTransformDraft!.width! > 0)
                ? _shapeTransformDraft!.width!
                : baseShape.width,
            height:
                (_shapeTransformDraft!.height != null &&
                    _shapeTransformDraft!.height! > 0)
                ? _shapeTransformDraft!.height!
                : baseShape.height,
            rotation: _shapeTransformDraft!.rotation,
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
    } else if (shape.kind == _ElementKind.frame) {
      rawW = shape.width > 0 ? shape.width : FrameElement.defaultWidth;
      rawH = shape.height > 0 ? shape.height : FrameElement.defaultHeight;
    } else if (shape.kind == _ElementKind.table) {
      rawW = shape.width > 0 ? shape.width : 360.0;
      rawH = shape.height > 0 ? shape.height : 180.0;
    } else if (shape.kind == _ElementKind.stickyNote ||
        shape.kind == _ElementKind.image) {
      rawW = shape.width > 0
          ? shape.width
          : (shape.size > 0 ? shape.size : 160.0);
      rawH = shape.height > 0
          ? shape.height
          : (shape.size > 0 ? shape.size : 160.0);
    } else if (shape.kind == _ElementKind.shape) {
      final domain = ShapeElement(
        id: shape.id,
        z: shape.z,
        shapeType: shape.shapeType ?? CanvasShapeType.square,
        center: shape.center,
        size: shape.size,
        width: shape.width > 0
            ? shape.width
            : ((shape.data['width'] as num?)?.toDouble() ?? 0.0),
        height: shape.height > 0
            ? shape.height
            : ((shape.data['height'] as num?)?.toDouble() ?? 0.0),
        color: shape.color,
        strokeWidth: shape.strokeWidth,
        isFilled: shape.isFilled,
      );
      final resolved = shapeElementRect(domain);
      rawW = resolved.width;
      // Linear shapes are flat; keep a grabbable overlay thickness.
      rawH = domain.isLinear
          ? math.max(resolved.height, shape.strokeWidth)
          : resolved.height;
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
                      onDoubleTapDown: shape.kind == _ElementKind.frame
                          ? (details) {
                              final screenPos = Offset(
                                center.dx - halfW + details.localPosition.dx,
                                center.dy - halfH + details.localPosition.dy,
                              );
                              _lastDoubleTapWorldPoint = _toWorld(screenPos);
                            }
                          : null,
                      onDoubleTap: shape.kind == _ElementKind.frame
                          ? () {
                              final worldPoint = _lastDoubleTapWorldPoint;
                              _lastDoubleTapWorldPoint = null;
                              if (worldPoint == null) return;
                              if (_enteredFrameId != shape.id) {
                                setState(() => _enteredFrameId = shape.id);
                              }
                              final hitChildId = _hitTestShape(
                                mappedElements,
                                worldPoint,
                              );
                              if (hitChildId != null &&
                                  hitChildId != shape.id) {
                                _selectShape(hitChildId, expandEditor: false);
                              }
                            }
                          : null,
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
                        final localPos = _globalToCanvasLocal(
                          details.globalPosition,
                        );
                        if (localPos != null) {
                          _updateEdgeAutoPan(localPos, fromOverlay: true);
                        }
                        final draft =
                            _shapeTransformDraft ??
                            _ShapeTransformDraft(
                              shapeId: shape.id,
                              center: shape.center,
                              size: shape.size,
                              width: rawW,
                              height: rawH,
                              rotation:
                                  (shape.data['rotation'] as num?)
                                      ?.toDouble() ??
                                  state.selectedShapeRotation,
                            );
                        final globalDelta =
                            details.globalPosition - _overlayDragStartGlobalPos;
                        final rawCenter = Offset(
                          _overlayDragStartCenter.dx +
                              (globalDelta.dx / _viewportScale),
                          _overlayDragStartCenter.dy +
                              (globalDelta.dy / _viewportScale),
                        );
                        final nextCenter = _snapElementCenterDrag(
                          state,
                          baseShape,
                          rawCenter,
                        );
                        setState(() {
                          _shapeTransformDraft = draft.copyWith(
                            center: nextCenter,
                          );
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
                          _canvasBloc.add(
                            CanvasPreviewMoveSelectedShape(nextCenter),
                          );
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
                  if (shape.kind != _ElementKind.image &&
                      shape.kind != _ElementKind.frame)
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
                          final centerGlobal = _getShapeCenterGlobal(
                            shape,
                            boxSize: Size(rawW, rawH),
                          );
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
                          if (draft == null || draft.shapeId != shape.id) {
                            return;
                          }
                          final centerGlobal = _getShapeCenterGlobal(
                            shape,
                            boxSize: Size(rawW, rawH),
                          );
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
                        // Text carries no `size`: its box width is what the
                        // handle resizes, so start from the drawn width instead
                        // of zero (which made any drag narrow the box).
                        _resizeStartSize = shape.kind == _ElementKind.text
                            ? rawW
                            : shape.size;
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
                        final minDim = shape.kind == _ElementKind.image
                            ? 1.0
                            : shape.kind == _ElementKind.stickyNote ||
                                  shape.kind == _ElementKind.table
                            ? 80.0
                            : shape.kind == _ElementKind.frame
                            ? 120.0
                            : 40.0;
                        final maxDim = shape.kind == _ElementKind.image
                            ? 720.0
                            : shape.kind == _ElementKind.frame ||
                                  shape.kind == _ElementKind.table
                            ? 4000.0
                            : 480.0;
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
                        } else if (shape.kind == _ElementKind.stickyNote ||
                            shape.kind == _ElementKind.shape ||
                            shape.kind == _ElementKind.frame ||
                            shape.kind == _ElementKind.table ||
                            shape.kind == _ElementKind.text) {
                          _canvasBloc.add(
                            CanvasPreviewResizeSelectedShape(
                              nextSize,
                              width: nextW,
                              height: nextH,
                            ),
                          );
                        } else {
                          _canvasBloc.add(
                            CanvasPreviewResizeSelectedShape(nextSize),
                          );
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
                          } else if (shape.kind == _ElementKind.stickyNote) {
                            _canvasBloc.add(
                              CanvasUpdateStickyNote(
                                elementId: shape.id,
                                width: draft.width,
                                height: draft.height,
                              ),
                            );
                          } else if (shape.kind == _ElementKind.text) {
                            // Width only: text height follows from wrapping.
                            _resizeSelectedShape(
                              draft.size,
                              width: draft.width ?? 0,
                            );
                          } else if (shape.kind == _ElementKind.shape ||
                              shape.kind == _ElementKind.frame ||
                              shape.kind == _ElementKind.table) {
                            _resizeSelectedShape(
                              draft.size,
                              width: draft.width ?? 0,
                              height: draft.height ?? 0,
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
                          child: Icon(
                            LucideIcons.pencil,
                            size: 14,
                            color: _tokens.accent,
                          ),
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
                child: const Icon(
                  LucideIcons.trash2,
                  size: 14,
                  color: Colors.white,
                ),
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
          // Start the draft with the conflicted elements pre-ticked; the
          // scope sheet lets the member adjust before choosing a state.
          _openUndoRequestSheet(initialIds: conflict.elementIds);
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
          onGenerateImage: _onGenerateImagePlaceholder,
          recentImages: state.activeTray == 'ai'
              ? _collectRecentAiImages(state)
              : const [],
          onClose: () => _toggleTray('ai'),
          // Null when AI_IMAGE_ENABLED is off: the tray keeps the old stub.
          generation: _aiImageEnabled
              ? AiTrayGeneration(
                  canEdit: _canUseAi(state),
                  isGenerating: _aiImageBloc?.state.isGenerating ?? false,
                  aspectRatio: _aiAspectRatio,
                  onAspectRatioChanged: (ratio) =>
                      setState(() => _aiAspectRatio = ratio),
                  onGenerate: _generateAiImage,
                )
              : null,
        ),
        ToolsTray(
          isOpen: state.activeTray == 'tools',
          canEdit: state.canEdit,
          onUndo: _undo,
          onRedo: _redo,
          onClearAll: state.currentUserRole == Board.roleOwner
              ? _clearAll
              : null,
          onCanvasSettings: () => _showCanvasSettingsSheet(context),
          onExport: () => _showExportOptionsSheet(context),
          onHistory: state.currentUserRole == Board.roleOwner
              ? _openHistoryScreen
              : null,
          onRequestUndo: state.currentUserRole == Board.roleEditor
              ? _openUndoRequestSheet
              : null,
          onClose: () => _toggleTray('tools'),
        ),
        CanvasActionsTray(
          isOpen: state.activeTray == 'actions',
          canEdit: state.canEdit,
          activeTool: state.currentToolMode,
          isArrowPreset: _isArrowMode(state),
          isLayersOpen: state.activeTray == 'layers',
          isShapesPopupOpen: _isShapesPopupOpen,
          isSymmetryActive:
              state.boardSettings.symmetryMode != CanvasSymmetryMode.none,
          bottomBarActions: _bottomBarActions,
          onActionSelected: _executeToolbarAction,
          onSymmetry: () => _showSymmetrySheet(context),
          onCustomizeBottomBar: _openBottomBarCustomizer,
          onClose: () => _toggleTray('actions'),
        ),
        LayersTray(
          isOpen: state.activeTray == 'layers',
          elements: state.elements,
          selectedIds: state.selectedIds,
          selectedShapeId: state.selectedShapeId,
          canEdit: state.canEdit,
          onSelect: (id) => _canvasBloc.add(CanvasSelectShape(id)),
          onToggleVisibility: (id, visible) =>
              _canvasBloc.add(CanvasSetElementVisibility(id, visible)),
          onToggleLock: (id, locked) =>
              _canvasBloc.add(CanvasSetElementLocked(id, locked)),
          onOpacityChanged: (id, opacity) =>
              _canvasBloc.add(CanvasSetElementOpacity(id, opacity)),
          onReorder: (id, index) =>
              _canvasBloc.add(CanvasReorderElement(id, index)),
          onMoveToLayer: (id, layerId) =>
              _canvasBloc.add(CanvasMoveElementToLayer(id, layerId)),
          onReorderLayer: (id, index) =>
              _canvasBloc.add(CanvasReorderLayer(id, index)),
          activeLayerId: state.activeLayerId,
          onSetActiveLayer: (id) => _canvasBloc.add(CanvasSetActiveLayer(id)),
          onAddLayer: (name) => _canvasBloc.add(CanvasAddLayer(name)),
          onRenameLayer: (id, name) =>
              _canvasBloc.add(CanvasRenameLayer(id, name)),
          onBlendModeChanged: (id, mode) =>
              _canvasBloc.add(CanvasUpdateLayerBlendMode(id, mode)),
          onDeleteLayer: (id) => _canvasBloc.add(CanvasDeleteLayer(id)),
          onClose: () => _toggleTray('layers'),
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
          recentColors: _recentColors,
          palettes: _palettes,
          eyedropperActive: _isEyedropperActive,
          onColorSelected: _setBrushColor,
          onOpenColorPicker: _openColorPicker,
          onEyedropperRequested: _toggleEyedropper,
          onOpacityChanged: (v) {
            _canvasBloc.add(CanvasUpdateBrushOpacity(v));
          },
          onBrushPresetSelected: (presetId) {
            _canvasBloc.add(CanvasApplyBrushPreset(presetId));
          },
          onEraserEraseEverythingChanged: _setEraserScope,
          onSmoothDoodlesChanged: (v) {
            setState(() => _smoothDoodlesEnabled = v);
          },
          stabilizerStrength: state.stabilizerStrength,
          onStabilizerChanged: (v) =>
              _canvasBloc.add(CanvasUpdateStabilizer(v)),
          stylusPressureEnabled: state.stylusPressureEnabled,
          onStylusPressureChanged: (v) {
            _canvasBloc.add(CanvasUpdateStylusPressure(v));
          },
          fingerDrawingEnabled: state.fingerDrawingEnabled,
          onFingerDrawingChanged: (v) async {
            _canvasBloc.add(CanvasSetFingerDrawing(v));
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_fingerDrawingPreferenceKey, v);
            } catch (_) {}
          },
          quickShapeEnabled: state.quickShapeEnabled,
          onQuickShapeChanged: (v) {
            _canvasBloc.add(CanvasSetQuickShapeEnabled(v));
          },
          onToolModeChanged: (mode) {
            _canvasBloc.add(CanvasSetToolMode(mode, keepTray: true));
          },
          onClose: () => _toggleTray('brushes'),
        ),
      ],
    );
  }

  Widget _buildSyncIndicator(CanvasState state) {
    final tokens = _tokens;
    switch (state.syncStatus) {
      case CanvasSyncStatus.syncing:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case CanvasSyncStatus.offline:
        return Semantics(
          button: true,
          label: 'Offline. Tap to retry syncing changes.',
          child: IconButton(
            tooltip: state.syncMessage ?? 'Retry sync',
            icon: Icon(LucideIcons.cloudOff, color: tokens.danger, size: 18),
            onPressed: () => _canvasBloc.add(const CanvasRetrySync()),
          ),
        );
      case CanvasSyncStatus.saved:
        return Semantics(
          label: 'All changes saved',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              LucideIcons.cloudCheck,
              color: tokens.success,
              size: 17,
            ),
          ),
        );
      case CanvasSyncStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildArchivedBanner(CanvasState state) {
    final isOwner = state.currentUserRole == Board.roleOwner;
    return _buildReadOnlyStatusBanner(
      icon: LucideIcons.archive,
      message: isOwner
          ? 'This board is archived. Unarchive it from Settings to edit.'
          : 'This board was archived by the owner (Read-only).',
      actionLabel: isOwner ? 'Settings' : 'Exit',
      onAction: isOwner
          ? () => _openSettings(state.boardTitle ?? 'Board')
          : _exitCanvas,
    );
  }

  Widget _buildPausedBanner(CanvasState state) {
    final isOwner = state.currentUserRole == Board.roleOwner;
    return _buildReadOnlyStatusBanner(
      icon: LucideIcons.pause,
      message: isOwner
          ? 'This board is paused. Resume it to allow editing.'
          : 'This board is paused by the owner (Read-only).',
      actionLabel: isOwner ? 'Resume' : 'Exit',
      onAction: isOwner
          ? () => _canvasBloc.add(const CanvasSetBoardPausedRequested(false))
          : _exitCanvas,
    );
  }

  Widget _buildPendingUndoRequestsBanner(CanvasState state) {
    final pendingCount = state.undoRequests.where((r) => r.isPending).length;
    return _buildReadOnlyStatusBanner(
      icon: LucideIcons.history,
      message: pendingCount == 1
          ? '1 undo request waiting for your review.'
          : '$pendingCount undo requests waiting for your review.',
      actionLabel: 'Review',
      onAction: _openHistoryScreen,
    );
  }

  Widget _buildReadOnlyStatusBanner({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final tokens = _tokens;
    final topInset = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: topInset + 56,
      left: 12,
      right: 12,
      child: GlassPanel(
        radius: InkRadii.glassBar,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tokens.pending),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: InkType.caption(tokens.ink),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            InkButton.secondary(
              label: actionLabel,
              compact: true,
              expand: false,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(InkTokens tokens, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: tokens.pending.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: tokens.pending.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: InkType.caption(tokens.pending).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTopPills(CanvasState state, String title) {
    final tokens = _tokens;
    final topInset = MediaQuery.of(context).padding.top + 8;
    final pendingRequestsCount = _pendingEditRequestsCount(state);

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
                            if (state.isArchived) ...[
                              const SizedBox(width: 6),
                              _buildStatusBadge(tokens, 'Archived'),
                            ] else if (state.isPaused) ...[
                              const SizedBox(width: 6),
                              _buildStatusBadge(tokens, 'Paused'),
                            ],
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
                  _buildSyncIndicator(state),
                  IconButton(
                    key: ValueKey(
                      _isUndoRedoMode
                          ? 'top-bar-undo-redo-close-button'
                          : 'top-bar-undo-redo-button',
                    ),
                    tooltip: _isUndoRedoMode
                        ? 'Exit undo / redo'
                        : 'Undo / Redo',
                    icon: Icon(
                      _isUndoRedoMode ? LucideIcons.x : LucideIcons.undo2,
                      color: tokens.ink,
                      size: 18,
                    ),
                    onPressed: state.canEdit
                        ? () =>
                            setState(() => _isUndoRedoMode = !_isUndoRedoMode)
                        : null,
                  ),
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
                  _buildBoardMenuButton(state, pendingRequestsCount),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Owner's pending edit requests for this board (badge on the menu).
  int _pendingEditRequestsCount(CanvasState state) {
    final notifState = context.watch<NotificationsBloc>().state;
    if (state.currentUserRole == Board.roleOwner &&
        notifState is NotificationsLoaded) {
      return notifState.notifications.where((n) {
        final type = n['type']?.toString();
        final status = n['status']?.toString();
        final extraData = n['extraData'] is Map
            ? (n['extraData'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final bId =
            extraData['boardId']?.toString() ?? n['targetId']?.toString();
        final reqType =
            extraData['requestType']?.toString() ??
            (type == 'board_edit_request' ? 'edit' : 'join');
        return (type == 'board_edit_request' ||
                (type == 'board_access_request' && reqType == 'edit')) &&
            status == 'pending' &&
            bId == widget.boardId;
      }).length;
    } else {
      return 0;
    }
  }

  /// The board's "More options" menu (settings, export, layers, share...).
  Widget _buildBoardMenuButton(
    CanvasState state,
    int pendingRequestsCount, {
    IconData icon = LucideIcons.ellipsis,
  }) {
    final tokens = _tokens;
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: pendingRequestsCount > 0
          ? Badge(
              label: Text('$pendingRequestsCount'),
              backgroundColor: tokens.accent,
              textColor: Colors.white,
              child: Icon(
                icon,
                color: tokens.ink,
                size: 18,
              ),
            )
          : Icon(
              icon,
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
        } else if (value == 'copy_selection') {
          _canvasBloc.add(const CanvasCopySelection());
        } else if (value == 'paste_selection') {
          _canvasBloc.add(const CanvasPasteSelection());
        } else if (value == 'layers') {
          _toggleTray('layers');
        } else if (value == 'share') {
          _canvasBloc.add(
            CanvasExportBoardRequested(
              format: BoardExportFormat.png,
              shareAfterExport: true,
              sharePositionOrigin: _shareAnchorRect(),
            ),
          );
        } else if (value == 'copy') {
          Clipboard.setData(ClipboardData(text: widget.boardId));
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
            child: _menuRow(
              LucideIcons.pencilLine,
              'Request Edit Access',
              tokens.accent,
            ),
          ),
        PopupMenuItem(
          value: 'export',
          child: _menuRow(
            LucideIcons.download,
            'Export Board...',
            tokens.ink,
          ),
        ),
        PopupMenuItem(
          value: 'layers',
          child: _menuRow(
            LucideIcons.layers,
            'Layers',
            tokens.ink,
          ),
        ),
        PopupMenuItem(
          value: 'copy_selection',
          enabled:
              state.selectedIds.isNotEmpty ||
              state.selectedShapeId != null,
          child: _menuRow(
            LucideIcons.copy,
            'Copy Selection',
            tokens.ink,
          ),
        ),
        PopupMenuItem(
          value: 'paste_selection',
          enabled: state.hasClipboard && state.canEdit,
          child: _menuRow(
            LucideIcons.clipboardPaste,
            'Paste',
            tokens.ink,
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: _menuRow(
            LucideIcons.share2,
            'Share Board',
            tokens.ink,
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: _menuRow(
            LucideIcons.copy,
            'Copy Join Code',
            tokens.ink,
          ),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem<String>(
          value: 'toggle_gesture_lock',
          checked: _preventGestureBack,
          child: Text(
            'Lock Back Gesture',
            style: TextStyle(color: tokens.ink),
          ),
        ),
        CheckedPopupMenuItem<String>(
          value: 'toggle_edge_buttons',
          checked: _showEdgeTrayButtons,
          child: Text(
            'Show Tray Edge Icons',
            style: TextStyle(color: tokens.ink),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'exit',
          child: _menuRow(
            LucideIcons.logOut,
            'Exit Canvas',
            tokens.danger,
          ),
        ),
      ],
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                CanvasRequestEditAccess(message: note.isNotEmpty ? note : null),
              );
            },
            child: Text(
              'Send Request',
              style: InkType.bodyStrong(Colors.white),
            ),
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
                      style: InkType.caption(
                        _tokens.ink,
                      ).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassEdgeTab(
    IconData icon, {
    required Color canvasBackground,
    bool vertical = true,
  }) {
    if (!_showEdgeTrayButtons) return const SizedBox.shrink();
    final tokens = _tokens;
    final isLightCanvas = canvasBackground.computeLuminance() > 0.5;
    final bgColor = isLightCanvas ? Colors.black : Colors.white;
    final fgColor = isLightCanvas ? Colors.white : Colors.black;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: vertical ? 36 : 56,
          height: vertical ? 56 : 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: tokens.glassShadow,
            border: Border.all(color: fgColor.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 18, color: fgColor),
        ),
      ),
    );
  }

  Widget _buildEdgeTriggers(CanvasState state, bool isDark) {
    final bg = state.boardSettings.backgroundColor;
    return Stack(
      children: [
        // Touch triggers for swiping. The bottom strip is the primary toolbar
        // now, so brushes open from its Pen tool instead of a duplicate tab.
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
              child: _buildGlassEdgeTab(
                LucideIcons.users,
                canvasBackground: bg,
              ),
            ),
          ),
        ),
        // BOTTOM LEFT: Swipe Right for Board & History Tools
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
              child: _buildGlassEdgeTab(
                LucideIcons.slidersHorizontal,
                canvasBackground: bg,
              ),
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
              child: _buildGlassEdgeTab(
                LucideIcons.sparkles,
                canvasBackground: bg,
              ),
            ),
          ),
        ),
        // BOTTOM RIGHT: Swipe Left for Canvas Tools
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTray('actions'),
            onHorizontalDragStart: (_) => _lastEdgeDragTime = DateTime.now(),
            onHorizontalDragUpdate: (d) {
              _lastEdgeDragTime = DateTime.now();
              if (d.delta.dx < -6) _openTray('actions');
            },
            child: Container(
              height: 220,
              width: 50,
              margin: const EdgeInsets.only(bottom: 60),
              color: Colors.transparent,
              child: _buildGlassEdgeTab(
                LucideIcons.layoutGrid,
                canvasBackground: bg,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Member is picking undo-request scope elements on the live canvas: a
  /// draft exists, they are not viewing history, no sheet is open, no area
  /// is being drawn, and no history load is in flight (the sheet's preview
  /// button already dispatched the scoped timeline request). Double-taps
  /// toggle the scope; other canvas gestures are suppressed.
  bool _isPickingUndoRequestScope(CanvasState state) {
    return state.undoRequestDraft != null &&
        !state.isViewingHistory &&
        !state.isHistoryLoading &&
        !state.isSelectingUndoRequestArea &&
        !state.isSelectingHistoryArea &&
        !_undoRequestSheetOpen;
  }

  /// Hint chip shown while the member is picking scope elements: count,
  /// back into the scope sheet, or abandon the request.
  Widget _buildUndoRequestPickHint(CanvasState state) {
    final tokens = _tokens;
    final draft = state.undoRequestDraft!;
    final count = draft.elementIds.length;
    return Positioned(
      left: 24,
      right: 24,
      bottom: 112,
      child: GlassPanel(
        radius: InkRadii.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s12,
          vertical: InkSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.mousePointerClick, size: 16, color: tokens.accentText),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Text(
                count == 0
                    ? 'Double-tap elements to add them to your request'
                    : '$count element(s) in your request — double-tap to adjust',
                style: InkType.caption(tokens.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: InkSpacing.s8),
            InkWell(
              onTap: () => _openUndoRequestSheet(),
              borderRadius: BorderRadius.circular(InkRadii.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.s8,
                  vertical: InkSpacing.s4,
                ),
                child: Text(
                  'Adjust',
                  style: InkType.caption(tokens.accentText),
                ),
              ),
            ),
            const SizedBox(width: InkSpacing.s4),
            InkWell(
              onTap: () {
                _canvasBloc.add(const CanvasUndoRequestDraftCleared());
              },
              borderRadius: BorderRadius.circular(InkRadii.chip),
              child: Padding(
                padding: const EdgeInsets.all(InkSpacing.s4),
                child: Icon(LucideIcons.x, size: 16, color: tokens.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Member-side status pill: their undo request is with the owner. It stays
  /// visible while the request is pending, so the member can see it is being
  /// reviewed instead of sending another one.
  Widget _buildUndoRequestPendingNotice(CanvasState state) {
    final request = state.myPendingUndoRequest!;
    final tokens = _tokens;
    final reason = request.reason.trim();
    final elementCount = request.targetElementIds.length;
    final detail = [
      if (elementCount > 0) '$elementCount element(s)',
      if (reason.isNotEmpty) '“$reason”',
    ].join(' · ');
    return Positioned(
      left: 24,
      right: 24,
      bottom: 112,
      child: GlassPanel(
        radius: InkRadii.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s12,
          vertical: InkSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.clock, size: 16, color: tokens.pending),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Undo request pending · waiting for the owner',
                    style: InkType.caption(tokens.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: InkType.caption(tokens.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSelectionHint(CanvasState state) {
    final tokens = _tokens;
    final isOwnerHistoryArea = state.isSelectingHistoryArea;
    return Positioned(
      left: 24,
      right: 24,
      bottom: 112,
      child: GlassPanel(
        radius: InkRadii.pill,
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.s12,
          vertical: InkSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.scan, size: 16, color: tokens.accentText),
            const SizedBox(width: InkSpacing.s8),
            Expanded(
              child: Text(
                isOwnerHistoryArea
                    ? 'Drag across the canvas to view history for that area'
                    : 'Drag across the canvas to select an area',
                style: InkType.caption(tokens.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: InkSpacing.s8),
            InkWell(
              onTap: () {
                setState(() {
                  _areaSelectionStart = null;
                  _areaSelectionCurrent = null;
                });
                if (isOwnerHistoryArea) {
                  _canvasBloc.add(
                    const CanvasToggleOwnerAreaHistorySelection(enable: false),
                  );
                } else {
                  _canvasBloc.add(
                    const CanvasToggleUndoRequestAreaSelection(enable: false),
                  );
                  _openUndoRequestSheet();
                }
              },
              borderRadius: BorderRadius.circular(InkRadii.chip),
              child: Padding(
                padding: const EdgeInsets.all(InkSpacing.s4),
                child: Icon(LucideIcons.x, size: 16, color: tokens.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptNewCommentDialog(Offset worldPoint) {
    final textController = TextEditingController();
    final mentionTracker = MentionSelectionTracker(textController);
    final boardMembers = _canvasBloc.state.boardMembers;
    final currentUserId = _canvasBloc.state.currentUserId;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _DialogDisposeScope(
        onDispose: () {
          mentionTracker.dispose();
          textController.dispose();
        },
        child: InkDialog(
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
            ListenableBuilder(
              listenable: mentionTracker,
              builder: (_, _) {
                final match = mentionTracker.activeMatch;
                if (match == null) return const SizedBox.shrink();
                final matches = filterMentionMembers(
                  boardMembers,
                  query: match.query,
                  excludeUid: currentUserId,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MentionMemberPicker(
                    members: matches,
                    tokens: _tokens,
                    onSelectMember: mentionTracker.selectMember,
                  ),
                );
              },
            ),
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
                    mentions: mentionTracker.selectedMentionUids,
                  ),
                );
              }
              Navigator.pop(dialogCtx);
            },
          ),
        ],
        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _tokens.accent : _tokens.pending,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 1.5),
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
    _webKeyFocus.dispose();
    _inkSpillTimer?.cancel();
    _shapeEditDebounceTimer?.cancel();
    _edgeAutoPanTimer?.cancel();
    _scrubDebounce?.cancel();
    for (final controller in _shapeLabelControllers.values) {
      controller.dispose();
    }
    _shapeLabelControllers.clear();
    _textEditingController?.dispose();
    _textEditingFocusNode?.dispose();
    for (final img in _decodedUiImages.values) {
      img.dispose();
    }
    _decodedUiImages.clear();
    _decodedUiImageKeys.clear();
    _pendingDecodeImageIds.clear();
    _aiImageSub?.cancel();
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

class _TextEditorDraft {
  final String? elementId;
  final Offset topLeft;
  final double width;
  final double height;
  final double rotation;
  final double fontSize;
  final int fontWeight;
  final String? fontFamily;
  final String textAlign;
  final double lineHeight;
  final Color color;

  const _TextEditorDraft({
    required this.elementId,
    required this.topLeft,
    required this.width,
    required this.height,
    required this.rotation,
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
    required this.textAlign,
    required this.lineHeight,
    required this.color,
  });
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

/// Draws the in-progress lasso loop in screen coordinates.
class _LassoOverlayPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  const _LassoOverlayPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.08));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _LassoOverlayPainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.points.length != points.length) return true;
    if (points.isEmpty || oldDelegate.points.isEmpty) return false;
    return oldDelegate.points.last != points.last;
  }
}

/// Owns its text controller so disposal happens after the dialog's pop
/// animation finishes rather than while the `InkTextField` is still mounted.
class _FrameTitleDialog extends StatefulWidget {
  final String initialTitle;

  const _FrameTitleDialog({required this.initialTitle});

  @override
  State<_FrameTitleDialog> createState() => _FrameTitleDialogState();
}

class _FrameTitleDialogState extends State<_FrameTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkDialog(
      title: 'Rename Frame',
      content: InkTextField(
        controller: _controller,
        labelText: 'Frame title',
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        InkButton.primary(
          label: 'Save',
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
        ),
      ],
    );
  }
}

/// Defers resource disposal until the dialog subtree has actually unmounted
/// after its exit animation.
class _DialogDisposeScope extends StatefulWidget {
  final VoidCallback onDispose;
  final Widget child;

  const _DialogDisposeScope({required this.onDispose, required this.child});

  @override
  State<_DialogDisposeScope> createState() => _DialogDisposeScopeState();
}

class _DialogDisposeScopeState extends State<_DialogDisposeScope> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
