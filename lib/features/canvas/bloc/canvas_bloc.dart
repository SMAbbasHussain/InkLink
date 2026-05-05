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
import '../view/trays/canvas_shape_type.dart';

part 'canvas_event.dart';
part 'canvas_state.dart';

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final CanvasService? _canvasService;
  final BoardService? _boardService;
  final Uuid _uuid = const Uuid();
  final math.Random _random = math.Random();

  StreamSubscription<List<LocalCrdtUpdate>>? _crdtUpdatesSub;
  StreamSubscription<Board?>? _boardMetaSub;
  StreamSubscription<List<BoardMember>>? _membersSub;
  CanvasDocAdapter? _crdtAdapter;
  Future<void>? _crdtInitFuture;
  Timer? _boardUnavailableTimer;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  final Map<String, String> _lastShapePayloadFingerprint = <String, String>{};
  final Map<String, String> _lastShapeUpdateId =
      <String, String>{}; // Track last update ID per shape
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
    on<CanvasStartStroke>(_onStartStroke);
    on<CanvasAppendStroke>(_onAppendStroke);
    on<CanvasEndStroke>(_onEndStroke);
    on<CanvasAddShape>(_onAddShape);
    on<CanvasAddAiText>(_onAddAiText);
    on<CanvasAddImageElement>(_onAddImageElement);
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
    on<CanvasMoveSelectedShape>(_onMoveSelectedShape);
    on<CanvasResizeSelectedShape>(_onResizeSelectedShape);
    on<CanvasToggleSelectedShapeFill>(_onToggleSelectedShapeFill);
    on<CanvasUpdateSelectedShapeColor>(_onUpdateSelectedShapeColor);
    on<CanvasUpdateSelectedShapeBorderRadius>(
      _onUpdateSelectedShapeBorderRadius,
    );
    on<CanvasRotateSelectedShape>(_onRotateSelectedShape);
    on<CanvasCommitPendingShapeEdits>(_onCommitPendingShapeEdits);
    on<CanvasToggleTray>(_onToggleTray);
    on<CanvasShowTrayTips>(_onShowTrayTips);
    on<CanvasDismissTrayTips>(_onDismissTrayTips);
    on<CanvasSaveBoardPreviewRequested>(_onSaveBoardPreviewRequested);
    on<CanvasBoardMembersUpdated>(_onBoardMembersUpdated);
    on<CanvasMemberSearchQueryChanged>(_onMemberSearchQueryChanged);
  }

  bool get _canSync => _canvasService != null && _boardId.isNotEmpty;

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
      _refreshFromCrdtAdapter(emit);
      emit(state.copyWith(isLoading: false, error: null));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onCanvasBoardTitleUpdated(
    CanvasBoardTitleUpdated event,
    Emitter<CanvasState> emit,
  ) {
    _currentUserRole = event.currentUserRole;
    emit(
      state.copyWith(
        boardTitle: event.title,
        currentUserRole: event.currentUserRole,
      ),
    );
  }

  void _onCanvasBoardUnavailable(
    CanvasBoardUnavailable event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(error: event.message, isLoading: false));
  }

  Future<void> _onApplyRemoteUpdate(
    CanvasApplyRemoteUpdate event,
    Emitter<CanvasState> emit,
  ) async {
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    for (final update in event.updates) {
      // Skip updates that have been marked as deleted (undone)
      if (update.isDeleted) {
        _appliedCrdtUpdateIds.add(update.updateId);
        continue;
      }

      if (_appliedCrdtUpdateIds.contains(update.updateId)) {
        continue;
      }

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
        _appliedCrdtUpdateIds.add(update.updateId);
      } catch (_) {
        // Skip malformed updates instead of crashing canvas state restoration.
        _appliedCrdtUpdateIds.add(update.updateId);
      }
    }

    _refreshFromCrdtAdapter(emit);
  }

  void _onStartStroke(CanvasStartStroke event, Emitter<CanvasState> emit) {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) {
      return;
    }
    emit(state.copyWith(currentStroke: [event.point]));
  }

  void _onAppendStroke(CanvasAppendStroke event, Emitter<CanvasState> emit) {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) {
      return;
    }

    final updated = List<Offset>.from(state.currentStroke)..add(event.point);
    emit(state.copyWith(currentStroke: updated));
  }

  Future<void> _onEndStroke(
    CanvasEndStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) {
      return;
    }

    if (state.currentStroke.length < 2) {
      emit(state.copyWith(currentStroke: const []));
      return;
    }

    if (state.brushType == 'eraser') {
      final eraserResult = _applyEraserStroke(
        erasePath: state.currentStroke,
        eraserRadius: state.strokeWidth / 2,
        eraseEverything: state.eraserEraseEverything,
      );

      emit(
        state.copyWith(
          elements: eraserResult.nextElements,
          currentStroke: const [],
        ),
      );

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
          data: createdStroke.data as Map<String, dynamic>,
          emit: emit,
        );
      }
      return;
    }

    final strokeId = _uuid.v4();
    final strokeData = {
      'z': _nextZIndex(),
      'color': state.selectedColor.value,
      'strokeWidth': state.strokeWidth,
      'opacity': state.brushOpacity,
      'brushType': state.brushType,
      'points': state.currentStroke
          .map((p) => {'x': p.dx, 'y': p.dy})
          .toList(growable: false),
    };

    final stroke = CanvasElement(
      id: strokeId,
      type: 'stroke',
      data: strokeData,
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(stroke);
    emit(state.copyWith(elements: nextElements, currentStroke: const []));

    await _saveCrdtOperation(
      action: 'create',
      type: 'stroke',
      objectId: strokeId,
      data: strokeData,
      emit: emit,
    );
  }

  Future<void> _onAddShape(
    CanvasAddShape event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) {
      return;
    }

    final shapeId = _uuid.v4();
    final shapeData = {
      'z': _nextZIndex(),
      'shapeType': event.shapeType.name,
      'cx': event.center.dx,
      'cy': event.center.dy,
      'size': 64.0,
      'color': state.selectedColor.value,
      'strokeWidth': 3.0,
      'isFilled': false,
      'borderRadius': 0.0,
      'rotation': 0.0,
    };

    final shape = CanvasElement(id: shapeId, type: 'shape', data: shapeData);
    final nextElements = List<CanvasElement>.from(state.elements)..add(shape);

    emit(
      state.copyWith(
        elements: nextElements,
        activeTray: null,
        selectedShapeId: shapeId,
        selectedShapeIsFilled: false,
        selectedShapeBorderRadius: 0.0,
      ),
    );

    await _saveCrdtOperation(
      action: 'create',
      type: 'shape',
      objectId: shapeId,
      data: shapeData,
      emit: emit,
    );
  }

  Future<void> _onAddAiText(
    CanvasAddAiText event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) {
      return;
    }

    final prompt = event.prompt.trim();
    if (prompt.isEmpty) return;

    final textId = _uuid.v4();
    final textData = {
      'z': _nextZIndex(),
      'text': prompt,
      'cx': event.position.dx,
      'cy': event.position.dy,
      'color': state.selectedColor.value,
    };

    final textElement = CanvasElement(id: textId, type: 'text', data: textData);
    final nextElements = List<CanvasElement>.from(state.elements)
      ..add(textElement);

    emit(state.copyWith(elements: nextElements, activeTray: null));

    await _saveCrdtOperation(
      action: 'create',
      type: 'text',
      objectId: textId,
      data: textData,
      emit: emit,
    );
  }

  Future<void> _onAddImageElement(
    CanvasAddImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) {
      return;
    }

    final imageId = _uuid.v4();
    final imageData = {
      'z': _nextZIndex(),
      'cx': event.center.dx,
      'cy': event.center.dy,
      'width': event.width.clamp(80.0, 720.0),
      'height': event.height.clamp(80.0, 720.0),
      'imageBase64': base64Encode(event.imageBytes),
    };

    final imageElement = CanvasElement(
      id: imageId,
      type: 'image',
      data: imageData,
    );
    final nextElements = List<CanvasElement>.from(state.elements)
      ..add(imageElement);

    emit(state.copyWith(elements: nextElements, activeTray: null));

    await _saveCrdtOperation(
      action: 'create',
      type: 'image',
      objectId: imageId,
      data: imageData,
      emit: emit,
    );
  }

  Future<void> _onUpdateImageElement(
    CanvasUpdateImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) {
      return;
    }

    CanvasElement? target;
    for (final element in state.elements) {
      if (element.id == event.elementId && element.type == 'image') {
        target = element;
        break;
      }
    }
    if (target == null) return;

    final data = Map<String, dynamic>.from(target.data as Map<String, dynamic>)
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy
      ..['width'] = event.width.clamp(80.0, 720.0)
      ..['height'] = event.height.clamp(80.0, 720.0);

    final oldData = target.data as Map<String, dynamic>;
    final oldCx = (oldData['cx'] as num?)?.toDouble() ?? 0.0;
    final oldCy = (oldData['cy'] as num?)?.toDouble() ?? 0.0;
    final oldW = (oldData['width'] as num?)?.toDouble() ?? 220.0;
    final oldH = (oldData['height'] as num?)?.toDouble() ?? 160.0;
    final newCx = (data['cx'] as num).toDouble();
    final newCy = (data['cy'] as num).toDouble();
    final newW = (data['width'] as num).toDouble();
    final newH = (data['height'] as num).toDouble();

    final unchanged =
        (newCx - oldCx).abs() < 0.1 &&
        (newCy - oldCy).abs() < 0.1 &&
        (newW - oldW).abs() < 0.1 &&
        (newH - oldH).abs() < 0.1;
    if (unchanged) {
      return;
    }

    final next = state.elements
        .map(
          (e) => e.id == event.elementId
              ? CanvasElement(id: e.id, type: e.type, data: data)
              : e,
        )
        .toList(growable: false);

    emit(state.copyWith(elements: next));

    await _saveCrdtOperation(
      action: 'update',
      type: 'image',
      objectId: event.elementId,
      data: data,
      emit: emit,
    );
  }

  Future<void> _onUndo(CanvasUndo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) {
      return;
    }

    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final update = adapter.undoLast(origin: 'local');
    if (update == null || update.isEmpty) return;

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
  }

  Future<void> _onRedo(CanvasRedo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) {
      return;
    }

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
    if (!_ensureCanEdit(emit)) {
      return;
    }

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
    if (!_ensureCanEdit(emit)) {
      return;
    }

    final nextElements = state.elements
        .where((e) => e.id != event.elementId)
        .toList(growable: false);

    emit(
      state.copyWith(
        elements: nextElements,
        selectedShapeId: state.selectedShapeId == event.elementId
            ? null
            : state.selectedShapeId,
      ),
    );
    await _saveCrdtOperation(
      action: 'delete',
      type: 'element',
      objectId: event.elementId,
      data: const {},
      emit: emit,
    );
  }

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
    final data = selected?.data as Map<String, dynamic>?;
    emit(
      state.copyWith(
        selectedShapeId: event.shapeId,
        selectedShapeIsFilled: (data?['isFilled'] as bool?) ?? false,
        selectedShapeBorderRadius:
            (data?['borderRadius'] as num?)?.toDouble() ?? 0.0,
        selectedShapeRotation: (data?['rotation'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  Future<void> _onMoveSelectedShape(
    CanvasMoveSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.data as Map<String, dynamic>)
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
    final data = Map<String, dynamic>.from(shape.data as Map<String, dynamic>)
      ..['rotation'] = _normalizeRotation(event.rotation);
    await _updateShape(shape.id, data, emit);
    emit(state.copyWith(selectedShapeRotation: data['rotation'] as double));
  }

  Future<void> _onCommitPendingShapeEdits(
    CanvasCommitPendingShapeEdits event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final shape = _selectedShape();
    if (shape == null) return;

    // Merge current shape data with pending changes
    final data = Map<String, dynamic>.from(
      shape.data as Map<String, dynamic>? ?? const {},
    );

    // Apply pending changes, with normalization for specific fields
    for (final entry in event.pendingData.entries) {
      if (entry.key == 'rotation') {
        data[entry.key] = _normalizeRotation(entry.value as double);
      } else if (entry.key == 'size') {
        data[entry.key] = (entry.value as double).clamp(24.0, 320.0);
      } else if (entry.key == 'borderRadius') {
        final size = (data['size'] as num?)?.toDouble() ?? 64.0;
        final maxRadius = (size / 2).clamp(0.0, 180.0);
        data[entry.key] = (entry.value as double).clamp(0.0, maxRadius);
      } else {
        data[entry.key] = entry.value;
      }
    }

    // Update UI state for tracked fields
    if (event.pendingData.containsKey('rotation')) {
      emit(state.copyWith(selectedShapeRotation: data['rotation'] as double));
    }
    if (event.pendingData.containsKey('isFilled')) {
      emit(state.copyWith(selectedShapeIsFilled: data['isFilled'] as bool));
    }
    if (event.pendingData.containsKey('borderRadius')) {
      emit(
        state.copyWith(
          selectedShapeBorderRadius: data['borderRadius'] as double,
        ),
      );
    }

    // Publish single batched update
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onResizeSelectedShape(
    CanvasResizeSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.data as Map<String, dynamic>)
      ..['size'] = event.size.clamp(24.0, 320.0);
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onToggleSelectedShapeFill(
    CanvasToggleSelectedShapeFill event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.data as Map<String, dynamic>)
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
    final data = Map<String, dynamic>.from(shape.data as Map<String, dynamic>)
      ..['color'] = event.color.value;
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onUpdateSelectedShapeBorderRadius(
    CanvasUpdateSelectedShapeBorderRadius event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final size =
        ((shape.data as Map<String, dynamic>)['size'] as num?)?.toDouble() ??
        64.0;
    final maxRadius = (size / 2).clamp(0.0, 180.0);
    final data = Map<String, dynamic>.from(shape.data as Map<String, dynamic>)
      ..['borderRadius'] = event.borderRadius.clamp(0.0, maxRadius);
    await _updateShape(shape.id, data, emit);
    emit(
      state.copyWith(
        selectedShapeBorderRadius:
            (data['borderRadius'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  CanvasElement? _selectedShape() {
    final selectedId = state.selectedShapeId;
    if (selectedId == null) return null;
    for (final element in state.elements) {
      if (element.id == selectedId) {
        return element;
      }
    }
    return null;
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

    final currentData = existing.data as Map<String, dynamic>? ?? const {};
    final currentCx = (currentData['cx'] as num?)?.toDouble() ?? 0.0;
    final currentCy = (currentData['cy'] as num?)?.toDouble() ?? 0.0;
    final currentSize = (currentData['size'] as num?)?.toDouble() ?? 64.0;
    final currentRotation =
        ((currentData['rotation'] as num?)?.toDouble() ?? 0.0) % (math.pi * 2);
    final currentBorderRadius =
        (currentData['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final currentColor = (currentData['color'] as num?)?.toInt() ?? 0;
    final currentFilled = (currentData['isFilled'] as bool?) ?? false;

    final nextCx = (data['cx'] as num?)?.toDouble() ?? 0.0;
    final nextCy = (data['cy'] as num?)?.toDouble() ?? 0.0;
    final nextSize = (data['size'] as num?)?.toDouble() ?? 64.0;
    final nextRotation =
        ((data['rotation'] as num?)?.toDouble() ?? 0.0) % (math.pi * 2);
    final nextBorderRadius = (data['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final nextColor = (data['color'] as num?)?.toInt() ?? 0;
    final nextFilled = (data['isFilled'] as bool?) ?? false;

    final unchanged =
        (nextCx - currentCx).abs() < 0.01 &&
        (nextCy - currentCy).abs() < 0.01 &&
        (nextSize - currentSize).abs() < 0.01 &&
        (nextRotation - currentRotation).abs() < 0.0001 &&
        (nextBorderRadius - currentBorderRadius).abs() < 0.01 &&
        nextColor == currentColor &&
        nextFilled == currentFilled;
    if (unchanged) return;

    final fingerprint = _shapeFingerprint(shapeId, data);
    if (_lastShapePayloadFingerprint[shapeId] == fingerprint) {
      return;
    }
    _lastShapePayloadFingerprint[shapeId] = fingerprint;

    final next = state.elements
        .map(
          (e) => e.id == shapeId
              ? CanvasElement(id: e.id, type: e.type, data: data)
              : e,
        )
        .toList(growable: false);
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: existing
          .type, // <-- Pass the correct type instead of hardcoded 'shape'
      objectId: shapeId,
      data: data,
      emit: emit,
    );
  }

  double _normalizeRotation(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    final twoPi = math.pi * 2;
    var normalized = value % twoPi;
    if (normalized < 0) {
      normalized += twoPi;
    }
    return normalized;
  }

  String _shapeFingerprint(String shapeId, Map<String, dynamic> data) {
    final cx = ((data['cx'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(3);
    final cy = ((data['cy'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(3);
    final size = ((data['size'] as num?)?.toDouble() ?? 64.0).toStringAsFixed(
      3,
    );
    final rotation = _normalizeRotation(
      (data['rotation'] as num?)?.toDouble() ?? 0.0,
    ).toStringAsFixed(5);
    final borderRadius = ((data['borderRadius'] as num?)?.toDouble() ?? 0.0)
        .toStringAsFixed(3);
    final color = ((data['color'] as num?)?.toInt() ?? 0).toString();
    final filled = ((data['isFilled'] as bool?) ?? false).toString();
    return '$shapeId|$cx|$cy|$size|$rotation|$borderRadius|$color|$filled';
  }

  _EraserResult _applyEraserStroke({
    required List<Offset> erasePath,
    required double eraserRadius,
    required bool eraseEverything,
  }) {
    final deletedIds = <String>[];
    final createdStrokes = <CanvasElement>[];
    final nextElements = <CanvasElement>[];

    for (final element in state.elements) {
      if (element.type != 'stroke') {
        final shouldDeleteWholeElement =
            eraseEverything &&
            _elementTouchesErasePath(element, erasePath, eraserRadius);
        if (shouldDeleteWholeElement) {
          deletedIds.add(element.id);
        } else {
          nextElements.add(element);
        }
        continue;
      }

      final touched = _elementTouchesErasePath(
        element,
        erasePath,
        eraserRadius,
      );
      if (!touched) {
        nextElements.add(element);
        continue;
      }

      final data = element.data as Map<String, dynamic>? ?? const {};
      final strokePoints = _pointsFromData(data);
      final strokeWidth = (data['strokeWidth'] as num?)?.toDouble() ?? 5.0;
      final keepSegments = _splitStrokeByErasePath(
        strokePoints: strokePoints,
        erasePath: erasePath,
        eraseRadius: eraserRadius + (strokeWidth / 2),
      );

      deletedIds.add(element.id);

      for (final segment in keepSegments) {
        if (segment.length < 2) continue;
        final segmentData = Map<String, dynamic>.from(data)
          ..['points'] = segment
              .map((p) => {'x': p.dx, 'y': p.dy})
              .toList(growable: false)
          ..['z'] = _nextZIndex();

        final replacement = CanvasElement(
          id: _uuid.v4(),
          type: 'stroke',
          data: segmentData,
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

  List<List<Offset>> _splitStrokeByErasePath({
    required List<Offset> strokePoints,
    required List<Offset> erasePath,
    required double eraseRadius,
  }) {
    if (strokePoints.length < 2 || erasePath.length < 2) {
      return <List<Offset>>[strokePoints];
    }

    final keepMask = List<bool>.filled(strokePoints.length, true);
    for (var i = 0; i < strokePoints.length; i++) {
      final point = strokePoints[i];
      for (var j = 0; j < erasePath.length - 1; j++) {
        final distance = _distanceToSegment(
          point,
          erasePath[j],
          erasePath[j + 1],
        );
        if (distance <= eraseRadius) {
          keepMask[i] = false;
          break;
        }
      }
    }

    final segments = <List<Offset>>[];
    var currentSegment = <Offset>[];

    for (var i = 0; i < strokePoints.length; i++) {
      if (keepMask[i]) {
        currentSegment.add(strokePoints[i]);
      } else {
        if (currentSegment.length >= 2) {
          segments.add(List<Offset>.from(currentSegment));
        }
        currentSegment = <Offset>[];
      }
    }

    if (currentSegment.length >= 2) {
      segments.add(currentSegment);
    }

    return segments;
  }

  bool _elementTouchesErasePath(
    CanvasElement element,
    List<Offset> points,
    double brushRadius,
  ) {
    final data = element.data as Map<String, dynamic>? ?? const {};

    if (element.type == 'stroke') {
      final strokePoints = _pointsFromData(data);
      if (strokePoints.length < 2 || points.isEmpty) return false;

      final strokeRadius = (data['strokeWidth'] as num?)?.toDouble() ?? 5.0;
      for (final erasePoint in points) {
        for (var i = 0; i < strokePoints.length - 1; i++) {
          final distance = _distanceToSegment(
            erasePoint,
            strokePoints[i],
            strokePoints[i + 1],
          );
          if (distance <= brushRadius + (strokeRadius / 2)) {
            return true;
          }
        }
      }
      return false;
    }

    final bounds = _elementBounds(element, data);
    if (bounds == null) return false;
    for (final erasePoint in points) {
      if (bounds.inflate(brushRadius).contains(erasePoint)) {
        return true;
      }
    }
    return false;
  }

  List<Offset> _pointsFromData(Map<String, dynamic> data) {
    final pointMaps = (data['points'] as List?) ?? const [];
    return pointMaps
        .whereType<Map>()
        .map(
          (point) => Offset(
            (point['x'] as num?)?.toDouble() ?? 0.0,
            (point['y'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList(growable: false);
  }

  Rect? _elementBounds(CanvasElement element, Map<String, dynamic> data) {
    if (element.type == 'shape') {
      final cx = (data['cx'] as num?)?.toDouble() ?? 0.0;
      final cy = (data['cy'] as num?)?.toDouble() ?? 0.0;
      final size = (data['size'] as num?)?.toDouble() ?? 64.0;
      return Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);
    }

    if (element.type == 'text') {
      final cx = (data['cx'] as num?)?.toDouble() ?? 0.0;
      final cy = (data['cy'] as num?)?.toDouble() ?? 0.0;
      return Rect.fromCenter(center: Offset(cx, cy), width: 180, height: 48);
    }

    if (element.type == 'image') {
      final cx = (data['cx'] as num?)?.toDouble() ?? 0.0;
      final cy = (data['cy'] as num?)?.toDouble() ?? 0.0;
      final width = (data['width'] as num?)?.toDouble() ?? 220.0;
      final height = (data['height'] as num?)?.toDouble() ?? 160.0;
      return Rect.fromCenter(
        center: Offset(cx, cy),
        width: width,
        height: height,
      );
    }

    return null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx == 0 && dy == 0) {
      return (point - start).distance;
    }

    final lengthSquared = (dx * dx) + (dy * dy);
    final t =
        (((point.dx - start.dx) * dx) + ((point.dy - start.dy) * dy)) /
        lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + (clampedT * dx),
      start.dy + (clampedT * dy),
    );
    return (point - projection).distance;
  }

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

  Future<void> _onSaveBoardPreviewRequested(
    CanvasSaveBoardPreviewRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;

    try {
      await canvasService.saveBoardPreview(_boardId, event.pngBytes);
    } catch (_) {
      // Preview persistence failure should not interrupt canvas usage.
    }
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

  Future<void> _initializeCrdtSync() async {
    if (_crdtAdapter != null && _crdtUpdatesSub != null) return;

    try {
      _crdtAdapter ??= await CanvasDocAdapterFactory.create();
      _appliedCrdtUpdateIds.clear();
      _lastShapeUpdateId.clear();

      // Rebuild element -> updateId mapping from remote updates
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
      final remoteUpdates = await canvasService
          .listenToCrdtUpdates(_boardId)
          .first;
      for (final update in remoteUpdates) {
        if (update.elementId != null && !update.isDeleted) {
          _lastShapeUpdateId[update.elementId!] = update.updateId;
        }
      }
    } catch (_) {
      // Silently handle errors - if rebuild fails, elements will get new updates on edit
    }
  }

  void _startCrdtUpdatesListener() {
    if (_crdtUpdatesSub != null || !_canSync) return;

    final canvasService = _canvasService;
    if (canvasService == null) return;

    _crdtUpdatesSub = canvasService.listenToCrdtUpdates(_boardId).listen((
      updates,
    ) {
      add(CanvasApplyRemoteUpdate(updates));
    });
  }

  void _startBoardMetadataListener() {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;

    _boardMetaSub?.cancel();
    _boardMetaSub = canvasService.watchBoardById(_boardId).listen((board) {
      if (board == null) {
        if (!_hasSeenBoardMetadata) {
          return;
        }
        _scheduleBoardUnavailableCheck();
        return;
      }

      _boardUnavailableTimer?.cancel();
      _boardUnavailableTimer = null;
      _hasSeenBoardMetadata = true;
      add(
        CanvasBoardTitleUpdated(
          board.title,
          currentUserRole: board.currentUserRole,
        ),
      );
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
          (members) {
            add(CanvasBoardMembersUpdated(members));
          },
          onError: (e) {
            // Silently handle member fetch errors; do not interrupt canvas
          },
        );
  }

  bool _ensureCanEdit(Emitter<CanvasState> emit) {
    return _ensureCanEditWithOptions(emit, clearStroke: false);
  }

  bool _ensureCanEditWithOptions(
    Emitter<CanvasState> emit, {
    required bool clearStroke,
  }) {
    if (_currentUserRole != Board.roleViewer) {
      return true;
    }

    const warningMessage =
        'You are a viewer. Request editor role from the owner to edit this board.';

    if (clearStroke && state.currentStroke.isNotEmpty) {
      emit(state.copyWith(currentStroke: const []));
    }

    final now = DateTime.now();
    final shouldShowWarning =
        _lastViewerWarningAt == null ||
        now.difference(_lastViewerWarningAt!).inMilliseconds > 1200;

    if (shouldShowWarning) {
      _lastViewerWarningAt = now;
      emit(state.copyWith(error: null));
      emit(state.copyWith(error: warningMessage));
    }

    return false;
  }

  void _scheduleBoardUnavailableCheck() {
    _boardUnavailableTimer?.cancel();
    _boardUnavailableTimer = Timer(
      const Duration(milliseconds: 1400),
      () async {
        final canvasService = _canvasService;
        if (canvasService == null || _boardId.isEmpty || isClosed) {
          return;
        }

        try {
          await canvasService.ensureBoardCached(_boardId);
        } catch (_) {
          // If recache fails, fallback to local check below.
        }

        final latestBoard = await canvasService.watchBoardById(_boardId).first;
        if (latestBoard != null || isClosed) {
          return;
        }

        add(
          CanvasBoardUnavailable(
            'This board is no longer available. Returning to the home screen.',
          ),
        );
      },
    );
  }

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

    // For element updates, check if we should do in-place edit instead of new update
    if (action == 'update' && _lastShapeUpdateId.containsKey(objectId)) {
      final existingUpdateId = _lastShapeUpdateId[objectId]!;
      await _updateCrdtUpdateInPlace(
        objectId: objectId,
        updateId: existingUpdateId,
        payload: update,
      );
    } else {
      final elementId = objectId;
      final publishedUpdateId = await _publishCrdtUpdate(
        update,
        elementId: elementId,
      );
      if (publishedUpdateId != null) {
        // Track this update for in-place edits
        _lastShapeUpdateId[objectId] = publishedUpdateId;
      }
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

  Future<void> _updateCrdtUpdateInPlace({
    required String objectId,
    required String updateId,
    required Uint8List payload,
  }) async {
    if (!_canSync) return;

    final canvasService = _canvasService;
    if (canvasService == null) return;

    _appliedCrdtUpdateIds.add(updateId);

    await canvasService.updateCrdtUpdatePayload(
      boardId: _boardId,
      updateId: updateId,
      payload: payload,
    );
  }

  void _refreshFromCrdtAdapter(Emitter<CanvasState> emit) {
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final rebuilt = _rebuildElementsFromCrdtState(
      adapter.materializeElements(),
    );
    emit(state.copyWith(elements: rebuilt));
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
        final pointMaps = (payload['points'] as List?) ?? const [];
        final points = pointMaps
            .whereType<Map>()
            .map(
              (p) => {
                'x': (p['x'] as num?)?.toDouble() ?? 0.0,
                'y': (p['y'] as num?)?.toDouble() ?? 0.0,
              },
            )
            .toList(growable: false);

        rebuilt.add(
          CanvasElement(
            id: id,
            type: 'stroke',
            data: {
              'z': _readElementOrder(
                elementId: id,
                payload: payload,
                currentOrder: currentOrder,
                fallbackOrder: maxExistingOrder + rebuilt.length,
              ),
              'color':
                  (payload['color'] as num?)?.toInt() ?? Colors.black.value,
              'strokeWidth':
                  (payload['strokeWidth'] as num?)?.toDouble() ?? 5.0,
              'opacity': (payload['opacity'] as num?)?.toDouble() ?? 1.0,
              'brushType': (payload['brushType'] as String?) ?? 'solid',
              'points': points,
            },
          ),
        );
        continue;
      }

      if (type == 'shape') {
        final shapeName =
            (payload['shapeType'] as String?) ?? CanvasShapeType.square.name;
        final shapeType = CanvasShapeType.values.firstWhere(
          (s) => s.name == shapeName,
          orElse: () => CanvasShapeType.square,
        );

        rebuilt.add(
          CanvasElement(
            id: id,
            type: 'shape',
            data: {
              'z': _readElementOrder(
                elementId: id,
                payload: payload,
                currentOrder: currentOrder,
                fallbackOrder: maxExistingOrder + rebuilt.length,
              ),
              'shapeType': shapeType.name,
              'cx': (payload['cx'] as num?)?.toDouble() ?? 0.0,
              'cy': (payload['cy'] as num?)?.toDouble() ?? 0.0,
              'size': (payload['size'] as num?)?.toDouble() ?? 64.0,
              'rotation': (payload['rotation'] as num?)?.toDouble() ?? 0.0,
              'borderRadius':
                  (payload['borderRadius'] as num?)?.toDouble() ?? 0.0,
              'isFilled': payload['isFilled'] as bool? ?? false,
              'color':
                  (payload['color'] as num?)?.toInt() ?? Colors.black.value,
              'strokeWidth':
                  (payload['strokeWidth'] as num?)?.toDouble() ?? 3.0,
            },
          ),
        );
        continue;
      }

      if (type == 'text') {
        rebuilt.add(
          CanvasElement(
            id: id,
            type: 'text',
            data: {
              'z': _readElementOrder(
                elementId: id,
                payload: payload,
                currentOrder: currentOrder,
                fallbackOrder: maxExistingOrder + rebuilt.length,
              ),
              'text': (payload['text'] as String?) ?? '',
              'cx': (payload['cx'] as num?)?.toDouble() ?? 0.0,
              'cy': (payload['cy'] as num?)?.toDouble() ?? 0.0,
              'color':
                  (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            },
          ),
        );
        continue;
      }

      if (type == 'image') {
        rebuilt.add(
          CanvasElement(
            id: id,
            type: 'image',
            data: {
              'z': _readElementOrder(
                elementId: id,
                payload: payload,
                currentOrder: currentOrder,
                fallbackOrder: maxExistingOrder + rebuilt.length,
              ),
              'cx': (payload['cx'] as num?)?.toDouble() ?? 0.0,
              'cy': (payload['cy'] as num?)?.toDouble() ?? 0.0,
              'width': (payload['width'] as num?)?.toDouble() ?? 220.0,
              'height': (payload['height'] as num?)?.toDouble() ?? 160.0,
              'imageBase64': (payload['imageBase64'] as String?) ?? '',
            },
          ),
        );
      }
    }

    rebuilt.sort((a, b) {
      final za = ((a.data as Map<String, dynamic>)['z'] as num?)?.toInt() ?? 0;
      final zb = ((b.data as Map<String, dynamic>)['z'] as num?)?.toInt() ?? 0;
      if (za != zb) return za.compareTo(zb);
      return a.id.compareTo(b.id);
    });
    return rebuilt;
  }

  int _nextZIndex() {
    var maxZ = -1;
    for (final element in state.elements) {
      final z = ((element.data as Map<String, dynamic>)['z'] as num?)?.toInt();
      if (z != null && z > maxZ) {
        maxZ = z;
      }
    }
    return maxZ + 1;
  }

  int _readElementOrder({
    required String elementId,
    required Map<String, dynamic> payload,
    required Map<String, int> currentOrder,
    required int fallbackOrder,
  }) {
    final explicit = (payload['z'] as num?)?.toInt();
    if (explicit != null) return explicit;

    if (currentOrder.containsKey(elementId)) {
      return currentOrder[elementId]!;
    }

    return fallbackOrder;
  }

  Offset randomShapeCenter() =>
      Offset(180 + _random.nextDouble() * 40, 220 + _random.nextDouble() * 80);

  Offset randomTextCenter() =>
      Offset(200 + _random.nextDouble() * 40, 240 + _random.nextDouble() * 60);

  @override
  Future<void> close() async {
    _boardUnavailableTimer?.cancel();
    _boardUnavailableTimer = null;
    await _boardMetaSub?.cancel();
    await _membersSub?.cancel();
    await _crdtUpdatesSub?.cancel();
    await _canvasService?.stopCrdtRemoteSync(_boardId);
    return super.close();
  }
}

class _EraserResult {
  final List<CanvasElement> nextElements;
  final List<String> deletedElementIds;
  final List<CanvasElement> createdStrokes;

  const _EraserResult({
    required this.nextElements,
    required this.deletedElementIds,
    required this.createdStrokes,
  });
}
