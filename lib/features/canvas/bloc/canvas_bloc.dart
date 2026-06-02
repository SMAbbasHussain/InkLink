import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crdt/canvas_crdt_adapter.dart';
import '../../../core/database/collections/local_crdt_update.dart';
import '../../../domain/models/board.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../models/canvas_element.dart';
import '../view/trays/canvas_shape_type.dart';
import 'canvas_state.dart';

export '../models/canvas_element.dart';
export 'canvas_state.dart';

part 'canvas_event.dart';
part 'canvas_helpers.dart';

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final CanvasService? _canvasService;
  final BoardService? _boardService;
  final Uuid _uuid = const Uuid();
  final math.Random _random = math.Random();
  static const Duration _previewPublishThrottle = Duration(milliseconds: 60);

  StreamSubscription<List<LocalCrdtUpdate>>? _crdtUpdatesSub;
  StreamSubscription<List<LocalCrdtUpdate>>? _previewUpdatesSub;
  StreamSubscription<Board?>? _boardMetaSub;
  StreamSubscription<List<BoardMember>>? _membersSub;
  CanvasDocAdapter? _crdtAdapter;
  Future<void>? _crdtInitFuture;
  Timer? _boardUnavailableTimer;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  final Map<String, CanvasElement> _remotePreviewElements =
      <String, CanvasElement>{};
  final Set<String> _remotePreviewDeletedIds = <String>{};
  bool _remotePreviewClearsBoard = false;
  final Map<String, String> _lastShapePayloadFingerprint = <String, String>{};
  final Map<String, String> _lastShapeUpdateId =
      <String, String>{};
  final Map<String, _QueuedPreviewPublish> _pendingPreviewPublishes =
      <String, _QueuedPreviewPublish>{};
  String? _activeStrokeId;
  bool _hasSeenBoardMetadata = false;
  String _boardId;
  String _currentUserRole = Board.roleViewer;
  DateTime? _lastViewerWarningAt;

  CanvasBloc({
    CanvasService? canvasService,
    BoardService? boardService,
    String boardId = '',
  }) : _canvasService = canvasService,
       _boardService = boardService,
       _boardId = boardId,
       super(CanvasInitial()) {
    on<CanvasRenameBoardRequested>(_onCanvasRenameBoardRequested);
    on<CanvasBoardTitleUpdated>(_onCanvasBoardTitleUpdated);
    on<CanvasBoardUnavailable>(_onCanvasBoardUnavailable);
    on<CanvasInitializeCrdt>(_onInitializeCrdt);
    on<CanvasApplyRemoteUpdate>(_onApplyRemoteUpdate);
    on<CanvasApplyRemotePreview>(_onApplyRemotePreview);
    on<CanvasStartStroke>(_onStartStroke);
    on<CanvasAppendStroke>(_onAppendStroke);
    on<CanvasEndStroke>(_onEndStroke);
    on<CanvasAddShape>(_onAddShape);
    on<CanvasAddAiText>(_onAddAiText);
    on<CanvasAddImageElement>(_onAddImageElement);
    on<CanvasPreviewImageElement>(_onPreviewImageElement);
    on<CanvasUpdateImageElement>(_onUpdateImageElement);
    on<CanvasUndo>(_onUndo);
    on<CanvasRedo>(_onRedo);
    on<CanvasClearAll>(_onClearAll);
    on<CanvasDeleteElement>(_onDeleteElement);
    on<CanvasUpdateColor>(_onUpdateColor);
    on<CanvasUpdateStrokeWidth>(_onUpdateStrokeWidth);
    on<CanvasUpdateBrushOpacity>(_onUpdateBrushOpacity);
    on<CanvasUpdateBrushType>(_onUpdateBrushType);
    on<CanvasUpdateEraserScope>(_onUpdateEraserScope);
    on<CanvasSelectShape>(_onSelectShape);
    on<CanvasPreviewMoveSelectedShape>(_onPreviewMoveSelectedShape);
    on<CanvasMoveSelectedShape>(_onMoveSelectedShape);
    on<CanvasPreviewResizeSelectedShape>(_onPreviewResizeSelectedShape);
    on<CanvasResizeSelectedShape>(_onResizeSelectedShape);
    on<CanvasPreviewRotateSelectedShape>(_onPreviewRotateSelectedShape);
    on<CanvasToggleSelectedShapeFill>(_onToggleSelectedShapeFill);
    on<CanvasUpdateSelectedShapeColor>(_onUpdateSelectedShapeColor);
    on<CanvasUpdateSelectedShapeBorderRadius>(
      _onUpdateSelectedShapeBorderRadius,
    );
    on<CanvasRotateSelectedShape>(_onRotateSelectedShape);
    on<CanvasCommitPendingShapeEdits>(_onCommitPendingShapeEdits);
    on<CanvasPreviewPendingShapeEdits>(_onPreviewPendingShapeEdits);
    on<CanvasToggleTray>(_onToggleTray);
    on<CanvasShowTrayTips>(_onShowTrayTips);
    on<CanvasDismissTrayTips>(_onDismissTrayTips);
    on<CanvasMoveSelectedStroke>(_onMoveSelectedStroke);
    on<CanvasUpdateSelectedStrokeColor>(_onUpdateSelectedStrokeColor);
    on<CanvasUpdateSelectedStrokeWidth>(_onUpdateSelectedStrokeWidth);
    on<CanvasUpdateSelectedStrokeOpacity>(_onUpdateSelectedStrokeOpacity);
    on<CanvasUpdateSelectedStrokeBrushType>(_onUpdateSelectedStrokeBrushType);
    on<CanvasSaveBoardPreviewRequested>(_onSaveBoardPreviewRequested);
    on<CanvasBoardMembersUpdated>(_onBoardMembersUpdated);
    on<CanvasMemberSearchQueryChanged>(_onMemberSearchQueryChanged);
  }

  bool get _canSync => _canvasService != null && _boardId.isNotEmpty;

  String? get _currentClientId => _canvasService?.currentClientId;

  // ──────────────────────────────────────────────
  // Board & rename
  // ──────────────────────────────────────────────

  Future<void> _onCanvasRenameBoardRequested(
    CanvasRenameBoardRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    try {
      await boardService.renameBoard(_boardId, event.newName);
      emit(state.copyWith(error: null));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to rename board: $e'));
    }
  }

  void _onCanvasBoardTitleUpdated(
    CanvasBoardTitleUpdated event,
    Emitter<CanvasState> emit,
  ) {
    _currentUserRole = event.currentUserRole;
    emit(state.copyWith(
      boardTitle: event.title,
      currentUserRole: event.currentUserRole,
    ));
  }

  void _onCanvasBoardUnavailable(
    CanvasBoardUnavailable event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(error: event.message, isLoading: false));
  }

  // ──────────────────────────────────────────────
  // CRDT init & sync
  // ──────────────────────────────────────────────

  Future<void> _onInitializeCrdt(
    CanvasInitializeCrdt event,
    Emitter<CanvasState> emit,
  ) async {
    _boardId = event.boardId;
    _currentUserRole = Board.roleViewer;
    _hasSeenBoardMetadata = false;
    _boardUnavailableTimer?.cancel();
    _boardUnavailableTimer = null;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      _startBoardMetadataListener();
      await _ensureCrdtReady();
      _startCrdtUpdatesListener();
      _startPreviewUpdatesListener();
      _refreshFromCrdtAdapter(emit);
      emit(state.copyWith(isLoading: false, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _initializeCrdtSync() async {
    if (_crdtAdapter != null && _crdtUpdatesSub != null) return;
    try {
      _crdtAdapter ??= await CanvasDocAdapterFactory.create();
      _appliedCrdtUpdateIds.clear();
      _lastShapeUpdateId.clear();
      await _rebuildElementUpdateIdMapping();
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

  Future<void> _rebuildElementUpdateIdMapping() async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    try {
      final remoteUpdates =
          await canvasService.listenToCrdtUpdates(_boardId).first;
      for (final update in remoteUpdates) {
        if (update.elementId != null && !update.isDeleted) {
          _lastShapeUpdateId[update.elementId!] = update.updateId;
        }
      }
    } catch (_) {
    }
  }

  // ──────────────────────────────────────────────
  // Listeners
  // ──────────────────────────────────────────────

  void _startCrdtUpdatesListener() {
    if (_crdtUpdatesSub != null || !_canSync) return;
    final canvasService = _canvasService;
    if (canvasService == null) return;
    _crdtUpdatesSub =
        canvasService.listenToCrdtUpdates(_boardId).listen((updates) {
      add(CanvasApplyRemoteUpdate(updates));
    });
  }

  void _startPreviewUpdatesListener() {
    if (_previewUpdatesSub != null || !_canSync) return;
    final canvasService = _canvasService;
    if (canvasService == null) return;
    _previewUpdatesSub =
        canvasService.listenToCanvasPreviews(_boardId).listen((previews) {
      add(CanvasApplyRemotePreview(previews));
    });
  }

  void _startBoardMetadataListener() {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    _boardMetaSub?.cancel();
    _boardMetaSub = canvasService.watchBoardById(_boardId).listen((board) {
      if (board == null) {
        if (!_hasSeenBoardMetadata) return;
        _scheduleBoardUnavailableCheck();
        return;
      }
      _boardUnavailableTimer?.cancel();
      _boardUnavailableTimer = null;
      _hasSeenBoardMetadata = true;
      _canvasService?.setBoardSingleUserStatus(board.members.length <= 1);
      add(CanvasBoardTitleUpdated(
        board.title,
        currentUserRole: board.currentUserRole,
      ));
    });
    _startBoardMembersListener();
  }

  void _startBoardMembersListener() {
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    _membersSub?.cancel();
    _membersSub = boardService
        .getBoardMembers(_boardId)
        .listen(
          (members) => add(CanvasBoardMembersUpdated(members)),
          onError: (_) {},
        );
  }

  void _scheduleBoardUnavailableCheck() {
    _boardUnavailableTimer?.cancel();
    _boardUnavailableTimer = Timer(
      const Duration(milliseconds: 1400),
      () async {
        final canvasService = _canvasService;
        if (canvasService == null || _boardId.isEmpty || isClosed) return;
        try {
          await canvasService.ensureBoardCached(_boardId);
        } catch (_) {}
        final latestBoard =
            await canvasService.watchBoardById(_boardId).first;
        if (latestBoard != null || isClosed) return;
        add(CanvasBoardUnavailable(
          'This board is no longer available. Returning to the home screen.',
        ));
      },
    );
  }

  // ──────────────────────────────────────────────
  // Remote updates
  // ──────────────────────────────────────────────

  Future<void> _onApplyRemoteUpdate(
    CanvasApplyRemoteUpdate event,
    Emitter<CanvasState> emit,
  ) async {
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    for (final update in event.updates) {
      if (update.isDeleted) {
        _appliedCrdtUpdateIds.add(update.updateId);
        continue;
      }
      if (_appliedCrdtUpdateIds.contains(update.updateId)) continue;
      try {
        if (update.payloadBase64.isEmpty) {
          _appliedCrdtUpdateIds.add(update.updateId);
          continue;
        }
        final bytes = base64Decode(update.payloadBase64);
        if (bytes.isEmpty) {
          _appliedCrdtUpdateIds.add(update.updateId);
          continue;
        }
        adapter.applyUpdate(bytes, origin: 'remote');
        _remotePreviewClearsBoard = false;
        if (update.elementId != null) {
          _remotePreviewElements.remove(update.elementId);
        }
        _appliedCrdtUpdateIds.add(update.updateId);
      } catch (_) {
        _appliedCrdtUpdateIds.add(update.updateId);
      }
    }
    _refreshFromCrdtAdapter(emit);
  }

  Future<void> _onApplyRemotePreview(
    CanvasApplyRemotePreview event,
    Emitter<CanvasState> emit,
  ) async {
    final currentClientId = _currentClientId;
    for (final preview in event.previews) {
      if (preview.elementId == null || preview.payloadBase64.isEmpty) continue;
      if (currentClientId != null &&
          currentClientId.isNotEmpty &&
          preview.sourceClientId == currentClientId) {
        continue;
      }
      try {
        final decoded =
            jsonDecode(utf8.decode(base64Decode(preview.payloadBase64)));
        if (decoded is! Map<String, dynamic>) continue;
        final action = (decoded['action'] as String?) ?? 'upsert';
        final type = (decoded['type'] as String?) ?? 'shape';
        final elementId = preview.elementId!;
        if (action == 'delete' && type == 'board') {
          _remotePreviewClearsBoard = true;
          _remotePreviewElements.clear();
          _remotePreviewDeletedIds.clear();
          continue;
        }
        _remotePreviewClearsBoard = false;
        if (action == 'delete') {
          _remotePreviewDeletedIds.add(elementId);
          _remotePreviewElements.remove(elementId);
          continue;
        }
        _remotePreviewDeletedIds.remove(elementId);
        _remotePreviewElements[preview.elementId!] =
            CanvasElement.fromMap(elementId, decoded);
      } catch (_) {}
    }
    _refreshFromCrdtAdapter(emit);
  }

  // ──────────────────────────────────────────────
  // CRDT save / publish
  // ──────────────────────────────────────────────

  Future<void> _saveCrdtOperation({
    required String action,
    required String type,
    required String objectId,
    required Map<String, dynamic> data,
    required Emitter<CanvasState> emit,
  }) async {
    if (!_canSync) return;
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
    if (update.isEmpty) {
      _refreshFromCrdtAdapter(emit);
      return;
    }
    await _publishOperationPreview(
      action: action,
      type: type,
      objectId: objectId,
      data: data,
    );
    final elementId = objectId;
    final publishedUpdateId =
        await _publishCrdtUpdate(update, elementId: elementId);
    if (publishedUpdateId != null) {
      _lastShapeUpdateId[objectId] = publishedUpdateId;
    }
    _refreshFromCrdtAdapter(emit);
  }

  Future<String?> _publishCrdtUpdate(
    Uint8List update, {
    String? elementId,
  }) async {
    if (!_canSync || update.isEmpty) return null;
    final canvasService = _canvasService;
    if (canvasService == null) return null;
    final updateId = _uuid.v4();
    _appliedCrdtUpdateIds.add(updateId);
    await canvasService.pushCrdtUpdate(
      boardId: _boardId,
      updateId: updateId,
      payload: update,
      elementId: elementId,
    );
    return updateId;
  }

  Future<void> _publishOperationPreview({
    required String action,
    required String type,
    required String objectId,
    required Map<String, dynamic> data,
  }) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    final previewId = _uuid.v4();
    final previewPayload = <String, dynamic>{
      'action': action == 'delete' ? 'delete' : 'upsert',
      'type': type,
      'elementId': objectId,
      ...data,
    };
    await canvasService.publishCanvasPreview(
      boardId: _boardId,
      previewId: previewId,
      elementId: objectId,
      payload: Uint8List.fromList(utf8.encode(jsonEncode(previewPayload))),
    );
  }

  void _refreshFromCrdtAdapter(Emitter<CanvasState> emit) {
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    final rebuilt = _rebuildElementsFromCrdtState(
      adapter.materializeElements(),
    );
    emit(state.copyWith(elements: _composeElementsWithPreviews(rebuilt)));
  }

  List<CanvasElement> _composeElementsWithPreviews(
    List<CanvasElement> committedElements,
  ) {
    if (_remotePreviewClearsBoard) return const <CanvasElement>[];
    if (_remotePreviewElements.isEmpty && _remotePreviewDeletedIds.isEmpty) {
      return committedElements;
    }
    final byId = <String, CanvasElement>{
      for (final element in committedElements)
        if (!_remotePreviewDeletedIds.contains(element.id)) element.id: element,
    };
    for (final preview in _remotePreviewElements.values) {
      byId[preview.id] = preview;
    }
    final composed = byId.values.toList(growable: false);
    composed.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    return composed;
  }

  Future<void> _publishSelectedShapePreview(
    String elementId,
    Map<String, dynamic> data,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    final preview = _pendingPreviewPublishes.putIfAbsent(
      elementId,
      _QueuedPreviewPublish.new,
    );
    preview.previewId = _uuid.v4();
    preview.elementId = elementId;
    preview.payload = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    preview.dirty = true;
    if (preview.timer != null) return;
    _flushQueuedPreviewPublish(elementId);
  }

  void _flushQueuedPreviewPublish(String elementId) {
    final canvasService = _canvasService;
    final preview = _pendingPreviewPublishes[elementId];
    if (canvasService == null || _boardId.isEmpty || preview == null) {
      preview?.timer?.cancel();
      _pendingPreviewPublishes.remove(elementId);
      return;
    }
    preview.dirty = false;
    unawaited(
      canvasService.publishCanvasPreview(
        boardId: _boardId,
        previewId: preview.previewId,
        elementId: preview.elementId,
        payload: preview.payload,
      ),
    );
    preview.timer = Timer(_previewPublishThrottle, () {
      preview.timer = null;
      final current = _pendingPreviewPublishes[elementId];
      if (current == null) return;
      if (current.dirty) {
        _flushQueuedPreviewPublish(elementId);
      } else {
        _pendingPreviewPublishes.remove(elementId);
      }
    });
  }

  List<CanvasElement> _rebuildElementsFromCrdtState(
    Map<String, Map<String, dynamic>> elementsById,
  ) {
    final rebuilt = <CanvasElement>[];
    final currentOrder = <String, int>{
      for (var i = 0; i < state.elements.length; i++) state.elements[i].id: i,
    };
    final maxExistingOrder = currentOrder.isEmpty
        ? 0
        : currentOrder.values.reduce(math.max) + 1;
    for (final entry in elementsById.entries) {
      final id = entry.key;
      final payload = entry.value;
      final type = payload['type'] as String?;
      if (type == 'stroke') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        final pointMaps = (payload['points'] as List?) ?? const [];
        final points = pointMaps
            .whereType<Map>()
            .map((p) => Offset(
                  (p['x'] as num?)?.toDouble() ?? 0.0,
                  (p['y'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList(growable: false);
        rebuilt.add(StrokeElement(
          id: id,
          z: z,
          color: Color((payload['color'] as num?)?.toInt() ?? Colors.black.value),
          strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 5.0,
          opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
          brushType: (payload['brushType'] as String?) ?? 'solid',
          points: points,
        ));
        continue;
      }
      if (type == 'shape') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        final shapeName =
            (payload['shapeType'] as String?) ?? CanvasShapeType.square.name;
        final shapeType = CanvasShapeType.values.firstWhere(
          (s) => s.name == shapeName,
          orElse: () => CanvasShapeType.square,
        );
        rebuilt.add(ShapeElement(
          id: id,
          z: z,
          shapeType: shapeType,
          center: Offset(
            (payload['cx'] as num?)?.toDouble() ?? 0.0,
            (payload['cy'] as num?)?.toDouble() ?? 0.0,
          ),
          size: (payload['size'] as num?)?.toDouble() ?? 64.0,
          color: Color((payload['color'] as num?)?.toInt() ?? Colors.black.value),
          strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 3.0,
          isFilled: _parseBool(payload['isFilled']),
          rotation: (payload['rotation'] as num?)?.toDouble() ?? 0.0,
          borderRadius: (payload['borderRadius'] as num?)?.toDouble() ?? 0.0,
        ));
        continue;
      }
      if (type == 'text') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(TextElement(
          id: id,
          z: z,
          text: (payload['text'] as String?) ?? '',
          center: Offset(
            (payload['cx'] as num?)?.toDouble() ?? 0.0,
            (payload['cy'] as num?)?.toDouble() ?? 0.0,
          ),
          color: Color((payload['color'] as num?)?.toInt() ?? Colors.black.value),
        ));
        continue;
      }
      if (type == 'image') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(ImageElement(
          id: id,
          z: z,
          center: Offset(
            (payload['cx'] as num?)?.toDouble() ?? 0.0,
            (payload['cy'] as num?)?.toDouble() ?? 0.0,
          ),
          width: (payload['width'] as num?)?.toDouble() ?? 220.0,
          height: (payload['height'] as num?)?.toDouble() ?? 160.0,
          imageBase64: (payload['imageBase64'] as String?) ?? '',
        ));
      }
    }
    rebuilt.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    return rebuilt;
  }

  int _nextZIndex() {
    var maxZ = -1;
    for (final element in state.elements) {
      if (element.z > maxZ) maxZ = element.z;
    }
    return maxZ + 1;
  }

  String _elementType(CanvasElement element) {
    return switch (element) {
      StrokeElement() => 'stroke',
      ShapeElement() => 'shape',
      TextElement() => 'text',
      ImageElement() => 'image',
    };
  }

  // ──────────────────────────────────────────────
  // Stroke operations
  // ──────────────────────────────────────────────

  void _onStartStroke(CanvasStartStroke event, Emitter<CanvasState> emit) {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) return;
    _activeStrokeId = _uuid.v4();
    emit(state.copyWith(currentStroke: [event.point]));
  }

  Future<void> _onAppendStroke(
    CanvasAppendStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) return;
    final updated = List<Offset>.from(state.currentStroke)..add(event.point);
    emit(state.copyWith(currentStroke: updated));
    final canvasService = _canvasService;
    final strokeId = _activeStrokeId;
    if (canvasService == null || strokeId == null || _boardId.isEmpty) return;
    final previewData = {
      'type': 'stroke',
      'z': _nextZIndex(),
      'color': state.selectedColor.value,
      'strokeWidth': state.strokeWidth,
      'opacity': state.brushOpacity,
      'brushType': state.brushType,
      'points': updated
          .map((p) => {'x': p.dx, 'y': p.dy})
          .toList(growable: false),
    };
    await _publishSelectedShapePreview(strokeId, previewData);
  }

  Future<void> _onEndStroke(
    CanvasEndStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) return;
    final usePoints = event.smoothedPoints ?? state.currentStroke;
    if (usePoints.length < 2) {
      emit(state.copyWith(currentStroke: const []));
      return;
    }
    if (state.brushType == 'eraser') {
      final eraserResult = _applyEraserStroke(
        erasePath: usePoints,
        eraserRadius: state.strokeWidth / 2,
        eraseEverything: state.eraserEraseEverything,
      );
      emit(state.copyWith(
        elements: eraserResult.nextElements,
        currentStroke: const [],
      ));
      for (final elementId in eraserResult.deletedElementIds) {
        await _saveCrdtOperation(
          action: 'delete',
          type: 'element',
          objectId: elementId,
          data: const {},
          emit: emit,
        );
      }
      for (final createdStroke in eraserResult.createdStrokes) {
        await _saveCrdtOperation(
          action: 'create',
          type: 'stroke',
          objectId: createdStroke.id,
          data: createdStroke.toMap(),
          emit: emit,
        );
      }
      return;
    }
    final strokeId = _activeStrokeId ?? _uuid.v4();
    final stroke = StrokeElement(
      id: strokeId,
      z: _nextZIndex(),
      color: state.selectedColor,
      strokeWidth: state.strokeWidth,
      opacity: state.brushOpacity,
      brushType: state.brushType,
      points: usePoints,
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(stroke);
    emit(state.copyWith(elements: nextElements, currentStroke: const []));
    _activeStrokeId = null;
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(stroke),
      objectId: strokeId,
      data: stroke.toMap(),
      emit: emit,
    );
  }

  // ──────────────────────────────────────────────
  // Element creation
  // ──────────────────────────────────────────────

  Future<void> _onAddShape(
    CanvasAddShape event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final shapeId = _uuid.v4();
    final shape = ShapeElement(
      id: shapeId,
      z: _nextZIndex(),
      shapeType: event.shapeType,
      center: event.center,
      size: 64.0,
      color: state.selectedColor,
      strokeWidth: 3.0,
      isFilled: false,
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(shape);
    emit(state.copyWith(
      elements: nextElements,
      activeTray: null,
      selectedShapeId: shapeId,
      selectedShapeIsFilled: false,
      selectedShapeBorderRadius: 0.0,
    ));
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(shape),
      objectId: shapeId,
      data: shape.toMap(),
      emit: emit,
    );
  }

  Future<void> _onAddAiText(
    CanvasAddAiText event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final prompt = event.prompt.trim();
    if (prompt.isEmpty) return;
    final textId = _uuid.v4();
    final textElement = TextElement(
      id: textId,
      z: _nextZIndex(),
      text: prompt,
      center: event.position,
      color: state.selectedColor,
    );
    final nextElements =
        List<CanvasElement>.from(state.elements)..add(textElement);
    emit(state.copyWith(elements: nextElements, activeTray: null));
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(textElement),
      objectId: textId,
      data: textElement.toMap(),
      emit: emit,
    );
  }

  Future<void> _onAddImageElement(
    CanvasAddImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final imageId = _uuid.v4();
    final imageElement = ImageElement(
      id: imageId,
      z: _nextZIndex(),
      center: event.center,
      width: event.width.clamp(80.0, 720.0),
      height: event.height.clamp(80.0, 720.0),
      imageBase64: base64Encode(event.imageBytes),
    );
    final nextElements =
        List<CanvasElement>.from(state.elements)..add(imageElement);
    emit(state.copyWith(elements: nextElements, activeTray: null));
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(imageElement),
      objectId: imageId,
      data: imageElement.toMap(),
      emit: emit,
    );
  }

  Future<void> _onUpdateImageElement(
    CanvasUpdateImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    CanvasElement? target;
    for (final element in state.elements) {
      if (element.id == event.elementId && element is ImageElement) {
        target = element;
        break;
      }
    }
    if (target == null) return;
    final oldElement = target as ImageElement;
    final newCx = event.center.dx;
    final newCy = event.center.dy;
    final newW = event.width.clamp(80.0, 720.0);
    final newH = event.height.clamp(80.0, 720.0);
    final unchanged = (newCx - oldElement.center.dx).abs() < 0.1 &&
        (newCy - oldElement.center.dy).abs() < 0.1 &&
        (newW - oldElement.width).abs() < 0.1 &&
        (newH - oldElement.height).abs() < 0.1;
    if (unchanged) return;
    final next = state.elements
        .map((e) => e.id == event.elementId
            ? ImageElement(
                id: e.id,
                z: e.z,
                center: Offset(newCx, newCy),
                width: newW,
                height: newH,
                imageBase64: (e as ImageElement).imageBase64,
              )
            : e)
        .toList(growable: false);
    emit(state.copyWith(elements: next));
    final updateData = <String, dynamic>{
      'type': 'image',
      'cx': newCx,
      'cy': newCy,
      'width': newW,
      'height': newH,
      'imageBase64': oldElement.imageBase64,
    };
    await _saveCrdtOperation(
      action: 'update',
      type: 'image',
      objectId: event.elementId,
      data: updateData,
      emit: emit,
    );
  }

  Future<void> _onPreviewImageElement(
    CanvasPreviewImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final payload = {
      'type': 'image',
      'action': 'upsert',
      'elementId': event.elementId,
      'cx': event.center.dx,
      'cy': event.center.dy,
      'width': event.width.clamp(80.0, 720.0),
      'height': event.height.clamp(80.0, 720.0),
    };
    await _publishSelectedShapePreview(event.elementId, payload);
  }

  // ──────────────────────────────────────────────
  // Undo / Redo / Clear / Delete
  // ──────────────────────────────────────────────

  Future<void> _onUndo(CanvasUndo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) return;
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    final update = adapter.undoLast(origin: 'local');
    if (update == null || update.isEmpty) return;
    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
  }

  Future<void> _onRedo(CanvasRedo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) return;
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    final update = adapter.redoLast(origin: 'local');
    if (update == null || update.isEmpty) return;
    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
  }

  Future<void> _onClearAll(
    CanvasClearAll event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (state.elements.isEmpty) return;
    emit(state.copyWith(elements: const [], activeTray: null));
    await _saveCrdtOperation(
      action: 'delete',
      type: 'board',
      objectId: _boardId,
      data: {'reason': 'clear_all'},
      emit: emit,
    );
  }

  Future<void> _onDeleteElement(
    CanvasDeleteElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final nextElements = state.elements
        .where((e) => e.id != event.elementId)
        .toList(growable: false);
    emit(state.copyWith(
      elements: nextElements,
      selectedShapeId:
          state.selectedShapeId == event.elementId ? null : state.selectedShapeId,
    ));
    await _saveCrdtOperation(
      action: 'delete',
      type: 'element',
      objectId: event.elementId,
      data: const {},
      emit: emit,
    );
  }

  // ──────────────────────────────────────────────
  // Brush & tool settings
  // ──────────────────────────────────────────────

  void _onUpdateColor(CanvasUpdateColor event, Emitter<CanvasState> emit) {
    emit(state.copyWith(selectedColor: event.color));
  }

  void _onUpdateStrokeWidth(
    CanvasUpdateStrokeWidth event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(strokeWidth: event.strokeWidth));
  }

  void _onUpdateBrushOpacity(
    CanvasUpdateBrushOpacity event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(brushOpacity: event.opacity));
  }

  void _onUpdateBrushType(
    CanvasUpdateBrushType event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(brushType: event.brushType));
  }

  void _onUpdateEraserScope(
    CanvasUpdateEraserScope event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(eraserEraseEverything: event.eraseEverything));
  }

  // ──────────────────────────────────────────────
  // Selection
  // ──────────────────────────────────────────────

  void _onSelectShape(CanvasSelectShape event, Emitter<CanvasState> emit) {
    if (event.shapeId == null) {
      emit(state.copyWith(selectedShapeId: null));
      return;
    }
    CanvasElement? selected;
    for (final element in state.elements) {
      if (element.id == event.shapeId) {
        selected = element;
        break;
      }
    }
    if (selected == null) {
      emit(state.copyWith(selectedShapeId: null));
      return;
    }
    if (selected is StrokeElement) {
      emit(state.copyWith(
        selectedShapeId: event.shapeId,
        selectedStrokeColor: selected.color.value,
        selectedStrokeWidth: selected.strokeWidth,
        selectedStrokeOpacity: selected.opacity,
        selectedStrokeBrushType: selected.brushType,
      ));
    } else if (selected is ShapeElement) {
      emit(state.copyWith(
        selectedShapeId: event.shapeId,
        selectedShapeIsFilled: selected.isFilled,
        selectedShapeBorderRadius: selected.borderRadius,
        selectedShapeRotation: selected.rotation,
      ));
    } else {
      emit(state.copyWith(selectedShapeId: event.shapeId));
    }
  }

  CanvasElement? _selectedShape() {
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return null;
    for (final element in state.elements) {
      if (element.id == selectedId) return element;
    }
    return null;
  }

  // ──────────────────────────────────────────────
  // Shape editing
  // ──────────────────────────────────────────────

  Future<void> _onMoveSelectedShape(
    CanvasMoveSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy;
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onRotateSelectedShape(
    CanvasRotateSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['rotation'] = _normalizeRotation(event.rotation);
    await _updateShape(shape.id, data, emit);
    emit(state.copyWith(selectedShapeRotation: data['rotation'] as double));
  }

  Future<void> _onResizeSelectedShape(
    CanvasResizeSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['size'] = event.size.clamp(24.0, 320.0);
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onToggleSelectedShapeFill(
    CanvasToggleSelectedShapeFill event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['isFilled'] = event.isFilled;
    await _updateShape(shape.id, data, emit);
    emit(state.copyWith(selectedShapeIsFilled: event.isFilled));
  }

  Future<void> _onUpdateSelectedShapeColor(
    CanvasUpdateSelectedShapeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['color'] = event.color.value;
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onUpdateSelectedShapeBorderRadius(
    CanvasUpdateSelectedShapeBorderRadius event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final size = shape.size;
    final maxRadius = (size / 2).clamp(0.0, 180.0);
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['borderRadius'] = event.borderRadius.clamp(0.0, maxRadius);
    await _updateShape(shape.id, data, emit);
    emit(state.copyWith(
      selectedShapeBorderRadius:
          (data['borderRadius'] as num?)?.toDouble() ?? 0.0,
    ));
  }

  Future<void> _onCommitPendingShapeEdits(
    CanvasCommitPendingShapeEdits event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final shape = _selectedShape();
    if (shape == null) return;
    final data = Map<String, dynamic>.from(shape.toMap());
    for (final entry in event.pendingData.entries) {
      if (entry.key == 'rotation') {
        final rotation = _toDoubleValue(entry.value);
        if (rotation == null) continue;
        data[entry.key] = _normalizeRotation(rotation);
      } else if (entry.key == 'size') {
        final size = _toDoubleValue(entry.value);
        if (size == null) continue;
        data[entry.key] = size.clamp(24.0, 320.0);
      } else if (entry.key == 'borderRadius') {
        final borderRadius = _toDoubleValue(entry.value);
        if (borderRadius == null) continue;
        final size = _toDoubleValue(data['size']) ?? 64.0;
        final maxRadius = (size / 2).clamp(0.0, 180.0);
        data[entry.key] = borderRadius.clamp(0.0, maxRadius);
      } else {
        data[entry.key] = entry.value;
      }
    }
    if (event.pendingData.containsKey('rotation')) {
      final rotation = _toDoubleValue(data['rotation']);
      if (rotation != null) {
        emit(state.copyWith(selectedShapeRotation: rotation));
      }
    }
    if (event.pendingData.containsKey('isFilled')) {
      emit(state.copyWith(selectedShapeIsFilled: _parseBool(data['isFilled'])));
    }
    if (event.pendingData.containsKey('borderRadius')) {
      final borderRadius = _toDoubleValue(data['borderRadius']);
      if (borderRadius != null) {
        emit(state.copyWith(selectedShapeBorderRadius: borderRadius));
      }
    }
    await _updateShape(shape.id, data, emit);
  }

  // ──────────────────────────────────────────────
  // Stroke editing
  // ──────────────────────────────────────────────

  Future<void> _onMoveSelectedStroke(
    CanvasMoveSelectedStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final element = _selectedShape();
    if (element is! StrokeElement) return;
    final newPoints = element.points.map((p) => p + event.delta).toList();
    final updated = StrokeElement(
      id: element.id,
      z: element.z,
      color: element.color,
      strokeWidth: element.strokeWidth,
      opacity: element.opacity,
      brushType: element.brushType,
      points: newPoints,
    );
    final next =
        state.elements.map((e) => e.id == element.id ? updated : e).toList();
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(updated),
      objectId: element.id,
      data: updated.toMap(),
      emit: emit,
    );
  }

  Future<void> _onUpdateSelectedStrokeColor(
    CanvasUpdateSelectedStrokeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(element.toMap())
      ..['color'] = event.color;
    await _updateStroke(element.id, data, emit);
    emit(state.copyWith(selectedStrokeColor: event.color));
  }

  Future<void> _onUpdateSelectedStrokeWidth(
    CanvasUpdateSelectedStrokeWidth event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(element.toMap())
      ..['strokeWidth'] = event.strokeWidth;
    await _updateStroke(element.id, data, emit);
    emit(state.copyWith(selectedStrokeWidth: event.strokeWidth));
  }

  Future<void> _onUpdateSelectedStrokeOpacity(
    CanvasUpdateSelectedStrokeOpacity event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(element.toMap())
      ..['opacity'] = event.opacity;
    await _updateStroke(element.id, data, emit);
    emit(state.copyWith(selectedStrokeOpacity: event.opacity));
  }

  Future<void> _onUpdateSelectedStrokeBrushType(
    CanvasUpdateSelectedStrokeBrushType event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(element.toMap())
      ..['brushType'] = event.brushType;
    await _updateStroke(element.id, data, emit);
    emit(state.copyWith(selectedStrokeBrushType: event.brushType));
  }

  // ──────────────────────────────────────────────
  // Update helpers
  // ──────────────────────────────────────────────

  Future<void> _updateStroke(
    String elementId,
    Map<String, dynamic> data,
    Emitter<CanvasState> emit,
  ) async {
    CanvasElement? existing;
    for (final element in state.elements) {
      if (element.id == elementId) {
        existing = element;
        break;
      }
    }
    if (existing == null) return;
    final next = state.elements
        .map((e) =>
            e.id == elementId ? CanvasElement.fromMap(e.id, data) : e)
        .toList(growable: false);
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(existing),
      objectId: elementId,
      data: data,
      emit: emit,
    );
  }

  Future<void> _updateShape(
    String shapeId,
    Map<String, dynamic> data,
    Emitter<CanvasState> emit,
  ) async {
    CanvasElement? existing;
    for (final element in state.elements) {
      if (element.id == shapeId) {
        existing = element;
        break;
      }
    }
    if (existing == null) return;
    if (existing is! ShapeElement) return;
    final currentCx = existing.center.dx;
    final currentCy = existing.center.dy;
    final currentSize = existing.size;
    final currentRotation = existing.rotation % (math.pi * 2);
    final currentBorderRadius = existing.borderRadius;
    final currentColor = existing.color.value;
    final currentFilled = existing.isFilled;
    final nextCx = (data['cx'] as num?)?.toDouble() ?? 0.0;
    final nextCy = (data['cy'] as num?)?.toDouble() ?? 0.0;
    final nextSize = (data['size'] as num?)?.toDouble() ?? 64.0;
    final nextRotation =
        ((data['rotation'] as num?)?.toDouble() ?? 0.0) % (math.pi * 2);
    final nextBorderRadius = (data['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final nextColor = (data['color'] as num?)?.toInt() ?? 0;
    final nextFilled = (data['isFilled'] as bool?) ?? false;
    final unchanged = (nextCx - currentCx).abs() < 0.01 &&
        (nextCy - currentCy).abs() < 0.01 &&
        (nextSize - currentSize).abs() < 0.01 &&
        (nextRotation - currentRotation).abs() < 0.0001 &&
        (nextBorderRadius - currentBorderRadius).abs() < 0.01 &&
        nextColor == currentColor &&
        nextFilled == currentFilled;
    if (unchanged) return;
    final fingerprint = _shapeFingerprint(shapeId, data);
    if (_lastShapePayloadFingerprint[shapeId] == fingerprint) return;
    _lastShapePayloadFingerprint[shapeId] = fingerprint;
    final next = state.elements
        .map((e) =>
            e.id == shapeId ? CanvasElement.fromMap(e.id, data) : e)
        .toList(growable: false);
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(existing),
      objectId: shapeId,
      data: data,
      emit: emit,
    );
  }

  // ──────────────────────────────────────────────
  // Preview helpers
  // ──────────────────────────────────────────────

  Future<void> _onPreviewPendingShapeEdits(
    CanvasPreviewPendingShapeEdits event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null || canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap());
    for (final entry in event.pendingData.entries) {
      if (entry.key == 'rotation') {
        final rotation = _toDoubleValue(entry.value);
        if (rotation == null) continue;
        data[entry.key] = _normalizeRotation(rotation);
      } else if (entry.key == 'size') {
        final size = _toDoubleValue(entry.value);
        if (size == null) continue;
        data[entry.key] = size.clamp(24.0, 320.0);
      } else if (entry.key == 'borderRadius') {
        final borderRadius = _toDoubleValue(entry.value);
        if (borderRadius == null) continue;
        final size = _toDoubleValue(data['size']) ?? 64.0;
        final maxRadius = (size / 2).clamp(0.0, 180.0);
        data[entry.key] = borderRadius.clamp(0.0, maxRadius);
      } else {
        data[entry.key] = entry.value;
      }
    }
    await _publishSelectedShapePreview(shape.id, data);
  }

  Future<void> _onPreviewMoveSelectedShape(
    CanvasPreviewMoveSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null || canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy;
    await _publishSelectedShapePreview(shape.id, data);
  }

  Future<void> _onPreviewResizeSelectedShape(
    CanvasPreviewResizeSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null || canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['size'] = event.size.clamp(24.0, 320.0);
    await _publishSelectedShapePreview(shape.id, data);
  }

  Future<void> _onPreviewRotateSelectedShape(
    CanvasPreviewRotateSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null || canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['rotation'] = _normalizeRotation(event.rotation);
    await _publishSelectedShapePreview(shape.id, data);
  }

  // ──────────────────────────────────────────────
  // Eraser
  // ──────────────────────────────────────────────

  _EraserResult _applyEraserStroke({
    required List<Offset> erasePath,
    required double eraserRadius,
    required bool eraseEverything,
  }) {
    final deletedIds = <String>[];
    final createdStrokes = <CanvasElement>[];
    final nextElements = <CanvasElement>[];
    for (final element in state.elements) {
      if (element is! StrokeElement) {
        final shouldDeleteWholeElement = eraseEverything &&
            _elementTouchesErasePath(element, erasePath, eraserRadius);
        if (shouldDeleteWholeElement) {
          deletedIds.add(element.id);
        } else {
          nextElements.add(element);
        }
        continue;
      }
      final touched =
          _elementTouchesErasePath(element, erasePath, eraserRadius);
      if (!touched) {
        nextElements.add(element);
        continue;
      }
      final strokePoints = element.points;
      final strokeWidth = element.strokeWidth;
      final keepSegments = _splitStrokeByErasePath(
        strokePoints: strokePoints,
        erasePath: erasePath,
        eraseRadius: eraserRadius + (strokeWidth / 2),
      );
      deletedIds.add(element.id);
      for (final segment in keepSegments) {
        if (segment.length < 2) continue;
        final replacement = StrokeElement(
          id: _uuid.v4(),
          z: _nextZIndex(),
          color: element.color,
          strokeWidth: element.strokeWidth,
          opacity: element.opacity,
          brushType: element.brushType,
          points: segment,
        );
        nextElements.add(replacement);
        createdStrokes.add(replacement);
      }
    }
    return _EraserResult(
      nextElements: nextElements,
      deletedElementIds: deletedIds,
      createdStrokes: createdStrokes,
    );
  }

  // ──────────────────────────────────────────────
  // Tray & UI
  // ──────────────────────────────────────────────

  void _onToggleTray(CanvasToggleTray event, Emitter<CanvasState> emit) {
    final nextTray = state.activeTray == event.trayName ? null : event.trayName;
    emit(state.copyWith(activeTray: nextTray));
  }

  void _onShowTrayTips(CanvasShowTrayTips event, Emitter<CanvasState> emit) {
    emit(state.copyWith(showTrayTips: true));
  }

  void _onDismissTrayTips(
    CanvasDismissTrayTips event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(showTrayTips: false));
  }

  void _onBoardMembersUpdated(
    CanvasBoardMembersUpdated event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(boardMembers: event.members));
  }

  void _onMemberSearchQueryChanged(
    CanvasMemberSearchQueryChanged event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(memberSearchQuery: event.query));
  }

  Future<void> _onSaveBoardPreviewRequested(
    CanvasSaveBoardPreviewRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    try {
      await canvasService.saveBoardPreview(_boardId, event.pngBytes);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  // Permission checks
  // ──────────────────────────────────────────────

  bool _ensureCanEdit(Emitter<CanvasState> emit) {
    return _ensureCanEditWithOptions(emit, clearStroke: false);
  }

  bool _ensureCanEditWithOptions(
    Emitter<CanvasState> emit, {
    required bool clearStroke,
  }) {
    if (_currentUserRole != Board.roleViewer) return true;
    const warningMessage =
        'You are a viewer. Request editor role from the owner to edit this board.';
    if (clearStroke && state.currentStroke.isNotEmpty) {
      emit(state.copyWith(currentStroke: const []));
    }
    final now = DateTime.now();
    final shouldShowWarning = _lastViewerWarningAt == null ||
        now.difference(_lastViewerWarningAt!).inMilliseconds > 1200;
    if (shouldShowWarning) {
      _lastViewerWarningAt = now;
      emit(state.copyWith(error: null));
      emit(state.copyWith(error: warningMessage));
    }
    return false;
  }

  Offset randomShapeCenter() =>
      Offset(180 + _random.nextDouble() * 40, 220 + _random.nextDouble() * 80);

  Offset randomTextCenter() =>
      Offset(200 + _random.nextDouble() * 40, 240 + _random.nextDouble() * 60);

  @override
  Future<void> close() async {
    _boardUnavailableTimer?.cancel();
    _boardUnavailableTimer = null;
    for (final preview in _pendingPreviewPublishes.values) {
      preview.timer?.cancel();
    }
    _pendingPreviewPublishes.clear();
    await _boardMetaSub?.cancel();
    await _membersSub?.cancel();
    await _crdtUpdatesSub?.cancel();
    await _previewUpdatesSub?.cancel();
    await _canvasService?.stopCrdtRemoteSync(_boardId);
    return super.close();
  }
}
