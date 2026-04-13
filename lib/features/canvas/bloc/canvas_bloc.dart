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
  CanvasDocAdapter? _crdtAdapter;
  Future<void>? _crdtInitFuture;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  bool _hasSeenBoardMetadata = false;
  String _boardId;

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
    on<CanvasUndo>(_onUndo);
    on<CanvasRedo>(_onRedo);
    on<CanvasClearAll>(_onClearAll);
    on<CanvasDeleteElement>(_onDeleteElement);
    on<CanvasUpdateColor>(_onUpdateColor);
    on<CanvasUpdateStrokeWidth>(_onUpdateStrokeWidth);
    on<CanvasToggleTray>(_onToggleTray);
    on<CanvasShowTrayTips>(_onShowTrayTips);
    on<CanvasDismissTrayTips>(_onDismissTrayTips);
    on<CanvasSaveBoardPreviewRequested>(_onSaveBoardPreviewRequested);
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
    _hasSeenBoardMetadata = false;
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
    emit(state.copyWith(boardTitle: event.title));
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
      if (_appliedCrdtUpdateIds.contains(update.updateId)) {
        continue;
      }

      final bytes = base64Decode(update.payloadBase64);
      adapter.applyUpdate(bytes, origin: 'remote');
      _appliedCrdtUpdateIds.add(update.updateId);
    }

    _refreshFromCrdtAdapter(emit);
  }

  void _onStartStroke(CanvasStartStroke event, Emitter<CanvasState> emit) {
    emit(state.copyWith(currentStroke: [event.point]));
  }

  void _onAppendStroke(CanvasAppendStroke event, Emitter<CanvasState> emit) {
    final updated = List<Offset>.from(state.currentStroke)..add(event.point);
    emit(state.copyWith(currentStroke: updated));
  }

  Future<void> _onEndStroke(
    CanvasEndStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (state.currentStroke.length < 2) {
      emit(state.copyWith(currentStroke: const []));
      return;
    }

    final strokeId = _uuid.v4();
    final strokeData = {
      'z': _nextZIndex(),
      'color': state.selectedColor.value,
      'strokeWidth': state.strokeWidth,
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
    final shapeId = _uuid.v4();
    final shapeData = {
      'z': _nextZIndex(),
      'shapeType': event.shapeType.name,
      'cx': event.center.dx,
      'cy': event.center.dy,
      'size': 64.0,
      'color': state.selectedColor.value,
      'strokeWidth': 3.0,
    };

    final shape = CanvasElement(id: shapeId, type: 'shape', data: shapeData);
    final nextElements = List<CanvasElement>.from(state.elements)..add(shape);

    emit(state.copyWith(elements: nextElements, activeTray: null));

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

  Future<void> _onUndo(CanvasUndo event, Emitter<CanvasState> emit) async {
    final adapter = _crdtAdapter;
    if (adapter == null || !_canSync) return;

    final update = adapter.undoLast(origin: 'local');
    if (update == null) return;

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
  }

  Future<void> _onRedo(CanvasRedo event, Emitter<CanvasState> emit) async {
    final adapter = _crdtAdapter;
    if (adapter == null || !_canSync) return;

    final update = adapter.redoLast(origin: 'local');
    if (update == null) return;

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
  }

  Future<void> _onClearAll(
    CanvasClearAll event,
    Emitter<CanvasState> emit,
  ) async {
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
    final nextElements = state.elements
        .where((e) => e.id != event.elementId)
        .toList(growable: false);

    emit(state.copyWith(elements: nextElements));
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

  Future<void> _initializeCrdtSync() async {
    if (_crdtAdapter != null && _crdtUpdatesSub != null) return;

    try {
      _crdtAdapter ??= await CanvasDocAdapterFactory.create();
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
        add(
          CanvasBoardUnavailable(
            'This board is no longer available. Returning to the home screen.',
          ),
        );
        return;
      }

      _hasSeenBoardMetadata = true;
      add(CanvasBoardTitleUpdated(board.title));
    });
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

    await _publishCrdtUpdate(update);
    _refreshFromCrdtAdapter(emit);
  }

  Future<void> _publishCrdtUpdate(Uint8List update) async {
    if (!_canSync) return;

    final canvasService = _canvasService;
    if (canvasService == null) return;

    final updateId = _uuid.v4();
    _appliedCrdtUpdateIds.add(updateId);

    await canvasService.pushCrdtUpdate(
      boardId: _boardId,
      updateId: updateId,
      payload: update,
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
    await _boardMetaSub?.cancel();
    await _crdtUpdatesSub?.cancel();
    if (_canSync) {
      await _canvasService?.stopCrdtRemoteSync(_boardId);
    }
    return super.close();
  }
}
