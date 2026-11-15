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
import '../../../domain/services/canvas/board_chat_service.dart';
import '../../../domain/services/canvas/board_comments_service.dart';
import '../../../domain/services/canvas/board_export_service.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../../../domain/services/voice/voice_service.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../geometry/canvas_element_geometry.dart';
import '../geometry/canvas_selection_transform.dart';
import '../geometry/stroke_input.dart';
import '../models/board_chat_message.dart';
import '../models/brush_preset.dart';
import '../models/canvas_comment.dart';
import '../models/canvas_element.dart';
import '../models/canvas_selection_mode.dart';
import '../models/canvas_tool_mode.dart';
import '../models/voice_participant.dart';
import '../view/trays/canvas_shape_type.dart';
import 'canvas_state.dart';

export '../../../domain/services/canvas/board_export_service.dart';
export '../models/board_chat_message.dart';
export '../models/canvas_comment.dart';
export '../models/canvas_element.dart';
export '../models/canvas_selection_mode.dart';
export '../models/voice_participant.dart';
export 'canvas_state.dart';

part 'canvas_event.dart';
part 'canvas_helpers.dart';

/// One element write inside a batched CRDT transaction.
typedef _CrdtWrite = ({
  String action,
  String type,
  String objectId,
  Map<String, dynamic> data,
});

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final CanvasService? _canvasService;
  final BoardService? _boardService;
  final BoardCommentsService? _boardCommentsService;
  final BoardChatService? _boardChatService;
  final VoiceService? _voiceService;
  final Uuid _uuid = const Uuid();

  /// In-app clipboard of serialized elements (not the OS clipboard).
  final List<({String id, Map<String, dynamic> data})> _clipboard = [];
  double _pasteOffset = 16;
  final math.Random _random = math.Random();
  static const Duration _previewPublishThrottle = Duration(milliseconds: 32);

  StreamSubscription<List<LocalCrdtUpdate>>? _crdtUpdatesSub;
  StreamSubscription<List<LocalCrdtUpdate>>? _previewUpdatesSub;
  StreamSubscription<Board?>? _boardMetaSub;
  StreamSubscription<List<BoardMember>>? _membersSub;
  StreamSubscription<List<CanvasComment>>? _commentsSub;
  StreamSubscription<BoardChatMessage>? _chatSub;
  StreamSubscription<List<VoiceParticipant>>? _voiceParticipantsSub;
  StreamSubscription<bool>? _voiceCallStatusSub;
  StreamSubscription<bool>? _voiceMuteStatusSub;
  CanvasDocAdapter? _crdtAdapter;
  List<CanvasElement>? _cachedCrdtElements;
  Future<void>? _crdtInitFuture;
  Timer? _boardUnavailableTimer;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  final Map<String, CanvasElement> _remotePreviewElements =
      <String, CanvasElement>{};
  final Set<String> _remotePreviewDeletedIds = <String>{};
  bool _remotePreviewClearsBoard = false;
  final Map<String, String> _lastShapePayloadFingerprint = <String, String>{};
  final Map<String, String> _lastShapeUpdateId = <String, String>{};
  final Map<String, _QueuedPreviewPublish> _pendingPreviewPublishes =
      <String, _QueuedPreviewPublish>{};
  String? _activeStrokeId;
  StrokeStabilizer? _strokeStabilizer;
  final Stopwatch _strokeClock = Stopwatch();
  String? _activeShapeDrawingId;
  _EraserSession? _eraserSession;
  final Map<String, RemoteEraserCursor> _remoteEraserCursors =
      <String, RemoteEraserCursor>{};
  bool _hasSeenBoardMetadata = false;
  String _boardId;
  String _currentUserRole = Board.roleViewer;
  DateTime? _lastViewerWarningAt;

  final BoardExportService _boardExportService;

  CanvasBloc({
    CanvasService? canvasService,
    BoardService? boardService,
    BoardExportService? boardExportService,
    BoardCommentsService? boardCommentsService,
    BoardChatService? boardChatService,
    VoiceService? voiceService,
    CanvasDocAdapter? crdtAdapter,
    String currentUserId = '',
    String boardId = '',
  }) : _canvasService = canvasService,
       _boardService = boardService,
       _boardExportService =
           boardExportService ?? const BoardExportServiceImpl(),
       _boardCommentsService = boardCommentsService,
       _boardChatService = boardChatService,
       _voiceService = voiceService,
       _crdtAdapter = crdtAdapter,
       _boardId = boardId,
       super(CanvasInitial(currentUserId: currentUserId)) {
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
    on<CanvasAddText>(_onAddText);
    on<CanvasUpdateText>(_onUpdateText);
    on<CanvasAddImageElement>(_onAddImageElement);
    on<CanvasPreviewImageElement>(_onPreviewImageElement);
    on<CanvasUpdateImageElement>(_onUpdateImageElement);
    on<CanvasUpdateImageStyle>(_onUpdateImageStyle);
    on<CanvasReplaceImageElement>(_onReplaceImageElement);
    on<CanvasAddStickyNote>(_onAddStickyNote);
    on<CanvasUpdateStickyNote>(_onUpdateStickyNote);
    on<CanvasConvertStickyNote>(_onConvertStickyNote);
    on<CanvasAddConnector>(_onAddConnector);
    on<CanvasUpdateConnector>(_onUpdateConnector);
    on<CanvasRewireConnector>(_onRewireConnector);
    on<CanvasUndo>(_onUndo);
    on<CanvasRedo>(_onRedo);
    on<CanvasClearAll>(_onClearAll);
    on<CanvasDeleteElement>(_onDeleteElement);
    on<CanvasUpdateColor>(_onUpdateColor);
    on<CanvasUpdateStrokeWidth>(_onUpdateStrokeWidth);
    on<CanvasUpdateBrushOpacity>(_onUpdateBrushOpacity);
    on<CanvasUpdateBrushType>(_onUpdateBrushType);
    on<CanvasApplyBrushPreset>(_onApplyBrushPreset);
    on<CanvasUpdateStylusPressure>(_onUpdateStylusPressure);
    on<CanvasUpdateStabilizer>(_onUpdateStabilizer);
    on<CanvasUpdateEraserScope>(_onUpdateEraserScope);
    on<CanvasSelectShape>(_onSelectShape);
    on<CanvasSelectElements>(_onSelectElements);
    on<CanvasSelectInRect>(_onSelectInRect);
    on<CanvasSelectInLasso>(_onSelectInLasso);
    on<CanvasScaleSelection>(_onScaleSelection);
    on<CanvasRotateSelection>(_onRotateSelection);
    on<CanvasSetSelectionMode>(_onSetSelectionMode);
    on<CanvasTranslateSelection>(_onTranslateSelection);
    on<CanvasAlignSelection>(_onAlignSelection);
    on<CanvasDuplicateElements>(_onDuplicateElements);
    on<CanvasDeleteElements>(_onDeleteElements);
    on<CanvasCopySelection>(_onCopySelection);
    on<CanvasPasteSelection>(_onPasteSelection);
    on<CanvasSetElementVisibility>(_onSetElementVisibility);
    on<CanvasSetElementLocked>(_onSetElementLocked);
    on<CanvasSetElementOpacity>(_onSetElementOpacity);
    on<CanvasReorderElement>(_onReorderElement);
    on<CanvasMoveElementToLayer>(_onMoveElementToLayer);
    on<CanvasReorderLayer>(_onReorderLayer);
    on<CanvasAddLayer>(_onAddLayer);
    on<CanvasRenameLayer>(_onRenameLayer);
    on<CanvasDeleteLayer>(_onDeleteLayer);
    on<CanvasSetActiveLayer>(_onSetActiveLayer);
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
    on<CanvasUpdateSelectedShapeStrokeWidth>(_onUpdateSelectedShapeStrokeWidth);
    on<CanvasUpdateSelectedShapeStrokeOpacity>(
      _onUpdateSelectedShapeStrokeOpacity,
    );
    on<CanvasUpdateSelectedShapeDash>(_onUpdateSelectedShapeDash);
    on<CanvasUpdateSelectedShapeLabel>(_onUpdateSelectedShapeLabel);
    on<CanvasUpdateSelectedShapeArrowheads>(_onUpdateSelectedShapeArrowheads);
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
    on<CanvasCommitSelectedStrokeEdits>(_onCommitSelectedStrokeEdits);
    on<CanvasSaveBoardPreviewRequested>(_onSaveBoardPreviewRequested);
    on<CanvasBoardMembersUpdated>(_onBoardMembersUpdated);
    on<CanvasMemberSearchQueryChanged>(_onMemberSearchQueryChanged);
    on<CanvasRemoveBoardMember>(_onRemoveBoardMember);
    on<CanvasUpdateBoardMemberRole>(_onUpdateBoardMemberRole);
    on<CanvasSetToolMode>(_onSetToolMode);
    on<CanvasStartShapeDraw>(_onStartShapeDraw);
    on<CanvasUpdateShapeDraw>(_onUpdateShapeDraw);
    on<CanvasEndShapeDraw>(_onEndShapeDraw);
    on<CanvasCancelShapeDraw>(_onCancelShapeDraw);
    on<CanvasExportBoardRequested>(_onExportBoardRequested);
    on<CanvasConsumeExportMessage>(_onConsumeExportMessage);
    on<CanvasRequestEditAccess>(_onRequestEditAccess);
    on<CanvasConsumeInfoMessage>(_onConsumeInfoMessage);
    // Module 11 Event Handlers
    on<CanvasCommentsUpdated>(_onCanvasCommentsUpdated);
    on<CanvasChatMessagesUpdated>(_onCanvasChatMessagesUpdated);
    on<CanvasChatMessageReceived>(_onCanvasChatMessageReceived);
    on<CanvasVoiceParticipantsUpdated>(_onCanvasVoiceParticipantsUpdated);
    on<CanvasVoiceCallStatusChanged>(_onCanvasVoiceCallStatusChanged);
    on<CanvasVoiceMuteStatusChanged>(_onCanvasVoiceMuteStatusChanged);
    on<CanvasToggleChatDrawer>(_onCanvasToggleChatDrawer);
    on<CanvasToggleCommentsTray>(_onCanvasToggleCommentsTray);
    on<CanvasToggleCommentPlacementMode>(_onCanvasToggleCommentPlacementMode);
    on<CanvasSetActiveComment>(_onCanvasSetActiveComment);
    on<CanvasAddCommentRequested>(_onCanvasAddCommentRequested);
    on<CanvasAddCommentReplyRequested>(_onCanvasAddCommentReplyRequested);
    on<CanvasDeleteCommentRequested>(_onCanvasDeleteCommentRequested);
    on<CanvasSendChatMessageRequested>(_onCanvasSendChatMessageRequested);
    on<CanvasJoinVoiceCallRequested>(_onCanvasJoinVoiceCallRequested);
    on<CanvasLeaveVoiceCallRequested>(_onCanvasLeaveVoiceCallRequested);
    on<CanvasToggleVoiceMuteRequested>(_onCanvasToggleVoiceMuteRequested);
    on<CanvasVoiceSpeakingChanged>(_onCanvasVoiceSpeakingChanged);
  }

  String get boardId => _boardId;

  bool get _canSync => _canvasService != null && _boardId.isNotEmpty;

  String? get _currentClientId => _canvasService?.currentClientId;

  /// Live eraser positions of collaborators, for the ghost eraser rings.
  List<RemoteEraserCursor> get remoteEraserCursors =>
      List<RemoteEraserCursor>.unmodifiable(_remoteEraserCursors.values);

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
      emit(
        state.copyWith(
          error: 'Failed to rename board: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
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
      if (isClosed) return;
      _startBoardMetadataListener();
      await _ensureCrdtReady();
      if (isClosed) return;
      _startCrdtUpdatesListener();
      _startPreviewUpdatesListener();
      _startCommunicationListeners(event.boardId);
      _refreshFromCrdtAdapter(emit);
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: null));
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            error: AppErrorFormatter.cleanMessage(
              e,
              fallback: 'Failed to load canvas.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _initializeCrdtSync() async {
    if (_crdtAdapter != null && _crdtUpdatesSub != null) return;
    try {
      _crdtAdapter ??= await CanvasDocAdapterFactory.create();
      _cachedCrdtElements = null;
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
      final remoteUpdates = await canvasService
          .listenToCrdtUpdates(_boardId)
          .first;
      for (final update in remoteUpdates) {
        if (update.elementId != null && !update.isDeleted) {
          _lastShapeUpdateId[update.elementId!] = update.updateId;
        }
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  // Listeners
  // ──────────────────────────────────────────────

  void _startCrdtUpdatesListener() {
    if (isClosed || _crdtUpdatesSub != null || !_canSync) return;
    final canvasService = _canvasService;
    if (canvasService == null) return;
    _crdtUpdatesSub = canvasService.listenToCrdtUpdates(_boardId).listen((
      updates,
    ) {
      if (!isClosed) {
        add(CanvasApplyRemoteUpdate(updates));
      }
    }, onError: (_) {});
  }

  void _startPreviewUpdatesListener() {
    if (isClosed || _previewUpdatesSub != null || !_canSync) return;
    final canvasService = _canvasService;
    if (canvasService == null) return;
    _previewUpdatesSub = canvasService.listenToCanvasPreviews(_boardId).listen((
      previews,
    ) {
      if (!isClosed) {
        add(CanvasApplyRemotePreview(previews));
      }
    }, onError: (_) {});
  }

  void _startBoardMetadataListener() {
    if (isClosed) return;
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    _boardMetaSub?.cancel();
    _boardMetaSub = canvasService.watchBoardById(_boardId).listen((board) {
      if (isClosed) return;
      if (board == null) {
        if (!_hasSeenBoardMetadata) return;
        _scheduleBoardUnavailableCheck();
        return;
      }
      _boardUnavailableTimer?.cancel();
      _boardUnavailableTimer = null;
      _hasSeenBoardMetadata = true;
      _canvasService?.setBoardSingleUserStatus(board.members.length <= 1);
      if (!isClosed) {
        add(
          CanvasBoardTitleUpdated(
            board.title,
            currentUserRole: board.currentUserRole,
          ),
        );
      }
    }, onError: (_) {});
    _startBoardMembersListener();
  }

  void _startBoardMembersListener() {
    if (isClosed) return;
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    _membersSub?.cancel();
    _membersSub = boardService.getBoardMembers(_boardId).listen((members) {
      if (!isClosed) {
        add(CanvasBoardMembersUpdated(members));
      }
    }, onError: (_) {});
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
        final latestBoard = await canvasService.watchBoardById(_boardId).first;
        if (latestBoard != null || isClosed) return;
        add(
          CanvasBoardUnavailable(
            'This board is no longer available. Returning to the home screen.',
          ),
        );
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

    // Separate snapshot from regular updates
    List<LocalCrdtUpdate> snapshotUpdate = [];
    List<LocalCrdtUpdate> regularUpdates = [];

    for (final update in event.updates) {
      if (update.updateId.startsWith('__snapshot__')) {
        snapshotUpdate.add(update);
      } else {
        regularUpdates.add(update);
      }
    }

    // Apply snapshot FIRST (full state restore via CRDT hydration)
    for (final snapshot in snapshotUpdate) {
      if (snapshot.payloadBase64.isEmpty) continue;
      try {
        final bytes = base64Decode(snapshot.payloadBase64);
        if (bytes.isEmpty) continue;
        adapter.applyUpdate(bytes, origin: 'remote');
        _appliedCrdtUpdateIds.add(snapshot.updateId);
        _remotePreviewClearsBoard = false;
        _remotePreviewElements.clear();
        _remotePreviewDeletedIds.clear();
      } catch (_) {
        _appliedCrdtUpdateIds.add(snapshot.updateId);
      }
    }

    // Then apply remaining deltas in order
    for (final update in regularUpdates) {
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
    _pruneRemoteEraserCursors();
    final currentClientId = _currentClientId;
    for (final preview in event.previews) {
      if (preview.elementId == null || preview.payloadBase64.isEmpty) continue;
      if (currentClientId != null &&
          currentClientId.isNotEmpty &&
          preview.sourceClientId == currentClientId) {
        continue;
      }
      try {
        final decoded = jsonDecode(
          utf8.decode(base64Decode(preview.payloadBase64)),
        );
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
        // Eraser gestures are never ink. Older clients published them as
        // strokes with the eraser brush, which used to leave a permanent
        // coloured stroke on everyone else's board.
        if (type == 'eraser' || decoded['brushType'] == 'eraser') {
          if (action == 'delete') {
            _remoteEraserCursors.remove(elementId);
          } else {
            final x = _toDoubleValue(decoded['x']);
            final y = _toDoubleValue(decoded['y']);
            final radius = _toDoubleValue(decoded['radius']);
            if (x != null && y != null) {
              _remoteEraserCursors[elementId] = RemoteEraserCursor(
                position: Offset(x, y),
                radius: (radius ?? 24).clamp(1.0, 400.0),
                updatedAt: DateTime.now(),
              );
            }
          }
          continue;
        }
        if (action == 'delete') {
          _remotePreviewDeletedIds.add(elementId);
          _remotePreviewElements.remove(elementId);
          continue;
        }
        _remotePreviewDeletedIds.remove(elementId);
        if (type == 'image') {
          final incomingBase64 = decoded['imageBase64'] as String?;
          if (incomingBase64 == null || incomingBase64.isEmpty) {
            final existing =
                _remotePreviewElements[elementId] ??
                state.elements.where((e) => e.id == elementId).firstOrNull ??
                _cachedCrdtElements
                    ?.where((e) => e.id == elementId)
                    .firstOrNull;
            if (existing is ImageElement && existing.imageBase64.isNotEmpty) {
              decoded['imageBase64'] = existing.imageBase64;
            } else {
              final adapter = _crdtAdapter;
              if (adapter != null) {
                final elemData = adapter.materializeElements()[elementId];
                final base64 = elemData?['imageBase64'] as String?;
                if (base64 != null && base64.isNotEmpty) {
                  decoded['imageBase64'] = base64;
                }
              }
            }
          }
        }
        _remotePreviewElements[preview.elementId!] = CanvasElement.fromMap(
          elementId,
          decoded,
        );
      } catch (_) {}
    }
    _refreshFromCrdtAdapter(emit, rebuildFromCrdt: false);
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
    _cancelPendingPreview(objectId);
    // Any new local transaction invalidates the undo manager's redo stack.
    if (state.infoMessageRedoable) {
      emit(state.copyWith(infoMessage: null, infoMessageRedoable: false));
    }
    final activeLayer = action == 'create' && type != 'layer'
        ? _activeLayerFor(state)
        : null;
    final joinActiveLayer =
        activeLayer != null && !activeLayer.elementIds.contains(objectId);
    if (!_canSync) {
      if (joinActiveLayer) {
        final updatedLayer = LayerElement(
          id: activeLayer.id,
          z: activeLayer.z,
          name: activeLayer.name,
          hidden: activeLayer.hidden,
          locked: activeLayer.locked,
          opacity: activeLayer.opacity,
          elementIds: [...activeLayer.elementIds, objectId],
        );
        final next = state.elements
            .map((e) => e.id == updatedLayer.id ? updatedLayer : e)
            .toList(growable: false);
        emit(state.copyWith(elements: next));
      }
      return;
    }
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
      if (joinActiveLayer) {
        // Joining the active layer is part of the same transaction so undo
        // removes the element and its membership together.
        update = adapter.applyBatch([
          (id: objectId, payload: payload),
          (
            id: activeLayer.id,
            payload: <String, dynamic>{
              ...activeLayer.toMap(),
              'elementIds': [...activeLayer.elementIds, objectId],
            },
          ),
        ], origin: 'local');
      } else {
        update = adapter.upsertElement(objectId, payload, origin: 'local');
      }
    }
    _refreshFromCrdtAdapter(emit);
    if (update.isEmpty) {
      return;
    }
    final previewData = (type == 'image' && action == 'update')
        ? (Map<String, dynamic>.from(data)..remove('imageBase64'))
        : data;
    await _publishOperationPreview(
      action: action,
      type: type,
      objectId: objectId,
      data: previewData,
    );
    final elementId = objectId;
    final publishedUpdateId = await _publishCrdtUpdate(
      update,
      elementId: elementId,
    );
    if (publishedUpdateId != null) {
      _lastShapeUpdateId[objectId] = publishedUpdateId;
    }
  }

  /// Persists several element writes as one CRDT transaction so a group
  /// gesture becomes a single undo/redo step and a single network update.
  Future<void> _saveCrdtBatch(
    List<_CrdtWrite> writes,
    Emitter<CanvasState> emit,
  ) async {
    if (writes.isEmpty) return;
    for (final write in writes) {
      _cancelPendingPreview(write.objectId);
    }
    // Any new local transaction invalidates the undo manager's redo stack.
    if (state.infoMessageRedoable) {
      emit(state.copyWith(infoMessage: null, infoMessageRedoable: false));
    }
    if (!_canSync) return;
    await _ensureCrdtReady();
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final update = adapter.applyBatch([
      for (final write in writes)
        (
          id: write.objectId,
          payload: write.action == 'delete'
              ? null
              : <String, dynamic>{'type': write.type, ...write.data},
        ),
    ], origin: 'local');
    _refreshFromCrdtAdapter(emit);
    if (update.isEmpty) return;

    for (final write in writes) {
      final previewData = (write.type == 'image' && write.action == 'update')
          ? (Map<String, dynamic>.from(write.data)..remove('imageBase64'))
          : write.data;
      await _publishOperationPreview(
        action: write.action,
        type: write.type,
        objectId: write.objectId,
        data: previewData,
      );
    }
    final updateId = await _publishCrdtUpdate(
      update,
      elementId: writes.length == 1 ? writes.single.objectId : null,
    );
    if (updateId != null) {
      for (final write in writes) {
        _lastShapeUpdateId[write.objectId] = updateId;
      }
    }
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

  void _refreshFromCrdtAdapter(
    Emitter<CanvasState> emit, {
    bool rebuildFromCrdt = true,
  }) {
    final adapter = _crdtAdapter;
    final List<CanvasElement> rebuilt;
    if (adapter != null) {
      if (rebuildFromCrdt || _cachedCrdtElements == null) {
        _cachedCrdtElements = _rebuildElementsFromCrdtState(
          adapter.materializeElements(),
        );
      }
      rebuilt = _cachedCrdtElements!;
    } else {
      rebuilt = state.elements;
    }
    // A collaborator update can rebuild the board in the middle of an erase
    // gesture; re-apply the live erase so already-erased ink does not pop back.
    final withErase = _applyActiveEraserOverlay(rebuilt);
    emit(state.copyWith(elements: _composeElementsWithPreviews(withErase)));
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
            .map(
              (p) => Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList(growable: false);
        rebuilt.add(
          StrokeElement(
            id: id,
            z: z,
            hidden: _parseBool(payload['hidden']),
            locked: _parseBool(payload['locked']),
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
            strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 5.0,
            opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
            brushType: (payload['brushType'] as String?) ?? 'solid',
            brushId:
                (payload['brushId'] as String?) ??
                (payload['brushType'] as String?) ??
                'solid',
            points: points,
            pressures:
                (payload['pressures'] as List?)
                    ?.map((p) => (p as num).toDouble())
                    .toList(growable: false) ??
                const [],
            spacing: (payload['spacing'] as num?)?.toDouble() ?? 0.25,
            textureSeed: (payload['textureSeed'] as num?)?.toInt() ?? 0,
          ),
        );
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
        rebuilt.add(
          ShapeElement(
            id: id,
            z: z,
            hidden: _parseBool(payload['hidden']),
            locked: _parseBool(payload['locked']),
            shapeType: shapeType,
            center: Offset(
              (payload['cx'] as num?)?.toDouble() ?? 0.0,
              (payload['cy'] as num?)?.toDouble() ?? 0.0,
            ),
            size: (payload['size'] as num?)?.toDouble() ?? 64.0,
            width: (payload['width'] as num?)?.toDouble() ?? 0.0,
            height: (payload['height'] as num?)?.toDouble() ?? 0.0,
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
            strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 3.0,
            strokeOpacity:
                (payload['strokeOpacity'] as num?)?.toDouble() ?? 1.0,
            dashPattern: (payload['dashPattern'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList(),
            isFilled: _parseBool(payload['isFilled']),
            rotation: (payload['rotation'] as num?)?.toDouble() ?? 0.0,
            borderRadius: (payload['borderRadius'] as num?)?.toDouble() ?? 0.0,
            opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
            label: (payload['label'] as String?) ?? '',
            labelColor: payload['labelColor'] == null
                ? null
                : Color((payload['labelColor'] as num).toInt()),
            labelFontSize:
                (payload['labelFontSize'] as num?)?.toDouble() ?? 14.0,
            labelFontWeight:
                (payload['labelFontWeight'] as num?)?.toInt() ?? 600,
            labelTextAlign: (payload['labelTextAlign'] as String?) ?? 'center',
            startArrowhead: _parseBool(payload['startArrowhead']),
            endArrowhead: payload['endArrowhead'] == null
                ? shapeType == CanvasShapeType.arrow
                : _parseBool(payload['endArrowhead']),
          ),
        );
        continue;
      }
      if (type == 'text') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(
          TextElement(
            id: id,
            z: z,
            hidden: _parseBool(payload['hidden']),
            locked: _parseBool(payload['locked']),
            text: (payload['text'] as String?) ?? '',
            center: Offset(
              (payload['cx'] as num?)?.toDouble() ?? 0.0,
              (payload['cy'] as num?)?.toDouble() ?? 0.0,
            ),
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
            width: (payload['width'] as num?)?.toDouble() ?? 0.0,
            height: (payload['height'] as num?)?.toDouble() ?? 0.0,
            fontSize: (payload['fontSize'] as num?)?.toDouble() ?? 16.0,
            fontWeight: (payload['fontWeight'] as num?)?.toInt() ?? 600,
            fontFamily: payload['fontFamily'] as String?,
            textAlign: (payload['textAlign'] as String?) ?? 'left',
            lineHeight: (payload['lineHeight'] as num?)?.toDouble() ?? 1.2,
            rotation: (payload['rotation'] as num?)?.toDouble() ?? 0.0,
            maxLines: (payload['maxLines'] as num?)?.toInt() ?? 0,
            autoSize: _parseBool(payload['autoSize']),
            backgroundColor: payload['backgroundColor'] == null
                ? null
                : Color((payload['backgroundColor'] as num).toInt()),
            padding: (payload['padding'] as num?)?.toDouble() ?? 4.0,
            opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
          ),
        );
        continue;
      }
      if (type == 'image') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        final parsed =
            CanvasElement.fromMap(id, {
                  ...payload,
                  'type': 'image',
                  'z': z,
                  'cx': (payload['cx'] as num?)?.toDouble() ?? 0.0,
                  'cy': (payload['cy'] as num?)?.toDouble() ?? 0.0,
                  'width': (payload['width'] as num?)?.toDouble() ?? 220.0,
                  'height': (payload['height'] as num?)?.toDouble() ?? 160.0,
                  'hidden': _parseBool(payload['hidden']),
                  'locked': _parseBool(payload['locked']),
                  'flipped': _parseBool(payload['flipped']),
                  'flipV': _parseBool(payload['flipV']),
                  'isReference': _parseBool(payload['isReference']),
                })
                as ImageElement;
        rebuilt.add(parsed);
        continue;
      }
      if (type == 'sticky_note') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(
          CanvasElement.fromMap(id, {
            ...payload,
            'type': 'sticky_note',
            'z': z,
            'cx': payload['cx'] ?? 0.0,
            'cy': payload['cy'] ?? 0.0,
          }),
        );
        continue;
      }
      if (type == 'connector') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(
          ConnectorElement(
            id: id,
            z: z,
            hidden: _parseBool(payload['hidden']),
            locked: _parseBool(payload['locked']),
            startElementId: payload['startElementId'] as String?,
            startPoint: Offset(
              (payload['sx'] as num?)?.toDouble() ?? 0.0,
              (payload['sy'] as num?)?.toDouble() ?? 0.0,
            ),
            startAnchor: (payload['startAnchor'] as String?) ?? 'center',
            endElementId: payload['endElementId'] as String?,
            endPoint: Offset(
              (payload['ex'] as num?)?.toDouble() ?? 0.0,
              (payload['ey'] as num?)?.toDouble() ?? 0.0,
            ),
            endAnchor: (payload['endAnchor'] as String?) ?? 'center',
            lineStyle: (payload['lineStyle'] as String?) ?? 'straight',
            color: Color(
              (payload['color'] as num?)?.toInt() ?? Colors.black.value,
            ),
            strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 2.5,
            hasArrowhead: _parseBool(
              payload['endArrowhead'] ?? payload['hasArrowhead'] ?? true,
            ),
            startArrowhead: _parseBool(payload['startArrowhead']),
            cornerRadius: (payload['cornerRadius'] as num?)?.toDouble() ?? 0,
            dashPattern: (payload['dashPattern'] as List<dynamic>?)
                ?.map((d) => (d as num).toDouble())
                .toList(growable: false),
            label: (payload['label'] as String?) ?? '',
            labelColor: payload['labelColor'] == null
                ? null
                : Color((payload['labelColor'] as num).toInt()),
            labelFontSize: (payload['labelFontSize'] as num?)?.toDouble() ?? 14,
            opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
          ),
        );
        continue;
      }
      if (type == 'layer') {
        // Layers are structure, but they must survive a CRDT rebuild or the
        // whole layers panel empties on the first remote update.
        rebuilt.add(
          LayerElement(
            id: id,
            z: (payload['z'] as num?)?.toInt() ?? 0,
            hidden: _parseBool(payload['hidden']),
            locked: _parseBool(payload['locked']),
            opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
            name: (payload['name'] as String?) ?? 'Layer',
            elementIds:
                (payload['elementIds'] as List?)?.whereType<String>().toList(
                  growable: false,
                ) ??
                const <String>[],
          ),
        );
        continue;
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

  /// Gesture behaviour follows the active tool, never the stroke style.
  bool get _isErasing => state.currentToolMode == CanvasToolMode.eraser;

  /// The tool a brush style implies when it is picked from the brush tray.
  CanvasToolMode _toolModeForBrush(String brushType) {
    if (brushType == 'eraser') return CanvasToolMode.eraser;
    if (brushType == 'highlighter') return CanvasToolMode.highlight;
    final mode = state.currentToolMode;
    return mode == CanvasToolMode.eraser || mode == CanvasToolMode.highlight
        ? CanvasToolMode.doodle
        : mode;
  }

  String _elementType(CanvasElement element) {
    return switch (element) {
      StrokeElement() => 'stroke',
      ShapeElement() => 'shape',
      TextElement() => 'text',
      ImageElement() => 'image',
      StickyNoteElement() => 'sticky_note',
      ConnectorElement() => 'connector',
      LayerElement() => 'layer',
    };
  }

  // ──────────────────────────────────────────────
  // Stroke operations
  // ──────────────────────────────────────────────

  void _onStartStroke(CanvasStartStroke event, Emitter<CanvasState> emit) {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) return;
    if (_isErasing) {
      _beginEraserStroke(event.point);
      emit(
        state.copyWith(
          currentStroke: [event.point],
          currentStrokePressures: [event.pressure],
        ),
      );
      return;
    }
    _activeStrokeId = _uuid.v4();
    _strokeClock
      ..reset()
      ..start();
    _strokeStabilizer = StrokeStabilizer(strength: state.stabilizerStrength)
      ..add(event.point, elapsed: Duration.zero);
    emit(
      state.copyWith(
        currentStroke: [event.point],
        currentStrokePressures: [
          state.stylusPressureEnabled ? event.pressure : 1.0,
        ],
      ),
    );
  }

  Future<void> _onAppendStroke(
    CanvasAppendStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) return;
    if (state.currentStroke.isEmpty) return;
    final points = _isErasing
        ? [event.point]
        : _strokeStabilizer!.add(event.point, elapsed: _strokeClock.elapsed);
    final updated = List<Offset>.from(state.currentStroke)..addAll(points);
    final pressure = state.stylusPressureEnabled ? event.pressure : 1.0;
    final updatedPressures = List<double>.from(state.currentStrokePressures)
      ..addAll([
        if (points.length == 2) state.currentStrokePressures.last,
        pressure,
      ]);
    emit(
      state.copyWith(
        currentStroke: updated,
        currentStrokePressures: updatedPressures,
      ),
    );
    if (_isErasing) {
      await _extendEraserStroke(updated, emit);
      return;
    }
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
      'brushId': state.brushType,
      'pressures': updatedPressures,
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
    if (_isErasing || _eraserSession != null) {
      await _finishEraserStroke(emit, event.smoothedPoints);
      return;
    }
    final stabilizer = _strokeStabilizer;
    final finalPoints = stabilizer?.finish() ?? const <Offset>[];
    _strokeStabilizer = null;
    _strokeClock.stop();
    var usePoints = List<Offset>.of(event.smoothedPoints ?? state.currentStroke)
      ..addAll(finalPoints);
    if (event.smoothAfterDrawing &&
        (stabilizer == null || stabilizer.strength == 0)) {
      usePoints = smoothStrokePoints(usePoints);
    }
    if (usePoints.length < 2) {
      _activeStrokeId = null;
      emit(
        state.copyWith(
          currentStroke: const [],
          currentStrokePressures: const [],
        ),
      );
      return;
    }
    var usePressures = state.stylusPressureEnabled
        ? event.pressures ?? state.currentStrokePressures
        : List<double>.filled(usePoints.length, 1.0);
    if (usePressures.length != usePoints.length) {
      if (usePressures.isEmpty) {
        usePressures = List<double>.filled(usePoints.length, 1.0);
      } else if (usePressures.length < usePoints.length) {
        final lastP = usePressures.last;
        usePressures = [
          ...usePressures,
          ...List<double>.filled(usePoints.length - usePressures.length, lastP),
        ];
      } else {
        usePressures = usePressures.sublist(0, usePoints.length);
      }
    }
    final strokeId = _activeStrokeId ?? _uuid.v4();
    final preset = brushPresetFor(state.brushType);
    final stroke = StrokeElement(
      id: strokeId,
      z: _nextZIndex(),
      color: state.selectedColor,
      strokeWidth: state.strokeWidth,
      opacity: state.brushOpacity,
      brushType: state.brushType,
      brushId: state.brushType,
      points: usePoints,
      pressures: usePressures,
      spacing: preset.spacing,
      textureSeed: DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(stroke);
    emit(
      state.copyWith(
        elements: nextElements,
        currentStroke: const [],
        currentStrokePressures: const [],
      ),
    );
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
    await _commitNewShape(
      _newShape(
        id: _uuid.v4(),
        shapeType: event.shapeType,
        center: event.center,
        size: 64.0,
      ),
      emit,
    );
  }

  /// Every shape-creation path builds its element here so defaults, z and
  /// payload fields cannot drift between the gesture and programmatic paths.
  ShapeElement _newShape({
    required String id,
    required CanvasShapeType shapeType,
    required Offset center,
    required double size,
    double rotation = 0,
    double width = 0,
    double height = 0,
  }) {
    final effectiveSize = (width > 0 || height > 0)
        ? math.max(width, height)
        : size;
    return ShapeElement(
      id: id,
      z: _nextZIndex(),
      shapeType: shapeType,
      center: center,
      size: effectiveSize,
      width: width,
      height: height,
      color: state.selectedColor,
      strokeWidth: 3.0,
      isFilled: false,
      rotation: rotation,
      endArrowhead: shapeType == CanvasShapeType.arrow,
    );
  }

  /// Adds [shape], selects it and persists it as one CRDT create.
  /// [resetDrawState] also leaves shape-draw mode, as the drag gesture does.
  Future<void> _commitNewShape(
    ShapeElement shape,
    Emitter<CanvasState> emit, {
    bool resetDrawState = false,
  }) async {
    final nextElements = List<CanvasElement>.from(state.elements)..add(shape);
    var next = state.copyWith(
      elements: nextElements,
      activeTray: null,
      selectedShapeId: shape.id,
      selectedIds: <String>{shape.id},
      selectedShapeRotation: shape.rotation,
      selectedShapeIsFilled: shape.isFilled,
      selectedShapeBorderRadius: shape.borderRadius,
    );
    if (resetDrawState) {
      next = next.copyWith(
        isDrawingShape: false,
        shapeDrawStart: null,
        shapeDrawCurrent: null,
        currentToolMode: CanvasToolMode.doodle,
        pendingShapeType: null,
      );
    }
    emit(next);
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(shape),
      objectId: shape.id,
      data: shape.toMap(),
      emit: emit,
    );
  }

  Future<void> _onAddAiText(
    CanvasAddAiText event,
    Emitter<CanvasState> emit,
  ) async {
    // The AI tray only inserts text today; route it through the single text
    // creation path so defaults, measurement and CRDT writes cannot drift.
    await _onAddText(
      CanvasAddText(
        topLeft: event.position,
        text: event.prompt,
        color: state.selectedColor,
      ),
      emit,
    );
  }

  Future<void> _onAddText(
    CanvasAddText event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final text = event.text.trim();
    if (text.isEmpty) return;
    final textId = _uuid.v4();
    final textElement = _measureText(
      TextElement(
        id: textId,
        z: _nextZIndex(),
        text: event.text,
        center: event.topLeft,
        color: event.color,
        fontSize: event.fontSize,
        fontWeight: event.fontWeight,
        textAlign: event.textAlign,
        rotation: event.rotation,
      ),
    );
    final nextElements = List<CanvasElement>.from(state.elements)
      ..add(textElement);
    emit(
      state.copyWith(
        elements: nextElements,
        activeTray: null,
        selectedShapeId: textId,
        selectedIds: <String>{textId},
        selectedShapeRotation: textElement.rotation,
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(textElement),
      objectId: textId,
      data: textElement.toMap(),
      emit: emit,
    );
  }

  /// Rewrites the measured width/height from the element's real text style.
  TextElement _measureText(TextElement element) {
    final layout = CanvasTextLayout.forElement(element);
    return TextElement(
      id: element.id,
      z: element.z,
      hidden: element.hidden,
      locked: element.locked,
      opacity: element.opacity,
      text: element.text,
      center: element.center,
      color: element.color,
      width: layout.size.width,
      height: layout.size.height,
      fontSize: element.fontSize,
      fontWeight: element.fontWeight,
      fontFamily: element.fontFamily,
      textAlign: element.textAlign,
      lineHeight: element.lineHeight,
      rotation: element.rotation,
      maxLines: element.maxLines,
      autoSize: element.autoSize,
      backgroundColor: element.backgroundColor,
      padding: element.padding,
    );
  }

  Future<void> _onUpdateText(
    CanvasUpdateText event,
    Emitter<CanvasState> emit, {
    String? infoMessage,
  }) async {
    if (!_ensureCanEdit(emit)) return;
    final existing = _findElement(event.elementId);
    if (existing is! TextElement || existing.locked) return;
    final nextText = event.text ?? existing.text;
    if (nextText.trim().isEmpty) {
      // Never leave an invisible text object behind.
      await _onDeleteElement(CanvasDeleteElement(event.elementId), emit);
      return;
    }
    final needsMeasure =
        event.text != null ||
        event.fontSize != null ||
        event.fontWeight != null ||
        event.fontFamily != null ||
        event.textAlign != null ||
        event.lineHeight != null ||
        event.maxLines != null ||
        event.width != null ||
        event.autoSize == true;
    var updated = TextElement(
      id: existing.id,
      z: existing.z,
      hidden: existing.hidden,
      locked: existing.locked,
      opacity: existing.opacity,
      text: nextText,
      center: event.topLeft ?? existing.center,
      color: event.color ?? existing.color,
      width: event.width ?? existing.width,
      height: event.height ?? existing.height,
      fontSize: event.fontSize ?? existing.fontSize,
      fontWeight: event.fontWeight ?? existing.fontWeight,
      fontFamily: event.fontFamily ?? existing.fontFamily,
      textAlign: event.textAlign ?? existing.textAlign,
      lineHeight: event.lineHeight ?? existing.lineHeight,
      rotation: event.rotation ?? existing.rotation,
      maxLines: event.maxLines ?? existing.maxLines,
      autoSize: event.autoSize ?? existing.autoSize,
      backgroundColor: event.backgroundColor ?? existing.backgroundColor,
      padding: existing.padding,
    );
    if (needsMeasure) updated = _measureText(updated);
    if (updated == existing) return;
    final next = state.elements
        .map((e) => e.id == updated.id ? updated : e)
        .toList();
    next.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(updated),
      objectId: updated.id,
      data: updated.toMap(),
      emit: emit,
    );
    await _syncAttachedConnectors(updated, emit);
    if (infoMessage != null) {
      _announceUndoable(emit, infoMessage);
    }
  }

  CanvasElement? _findElement(String elementId) {
    for (final element in state.elements) {
      if (element.id == elementId) return element;
    }
    return null;
  }

  Future<void> _onAddImageElement(
    CanvasAddImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final imageId = _uuid.v4();
    final style = event.style;
    var z = _nextZIndex();
    if (style?.isReference == true) {
      final activeLayer = _activeLayerFor(state);
      final band = canvasPaintOrder(
        state.elements,
      ).bands.firstWhere((band) => band.layer?.id == activeLayer?.id);
      if (band.elements.isNotEmpty) {
        z = band.elements.map((element) => element.z).reduce(math.min) - 1;
      }
    }
    final imageElement =
        CanvasElement.fromMap(imageId, {
              ...?style?.toMap(),
              'type': 'image',
              'z': z,
              'cx': event.center.dx,
              'cy': event.center.dy,
              'width': event.width.clamp(1.0, 720.0),
              'height': event.height.clamp(1.0, 720.0),
              'locked': style?.isReference == true,
              'imageBase64': base64Encode(event.imageBytes),
            })
            as ImageElement;
    final nextElements = List<CanvasElement>.from(state.elements)
      ..add(imageElement);
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
    if (oldElement.locked) return;
    final newCx = event.center.dx;
    final newCy = event.center.dy;
    final newW = event.width.clamp(1.0, 720.0);
    final newH = event.height.clamp(1.0, 720.0);
    final unchanged =
        (newCx - oldElement.center.dx).abs() < 0.1 &&
        (newCy - oldElement.center.dy).abs() < 0.1 &&
        (newW - oldElement.width).abs() < 0.1 &&
        (newH - oldElement.height).abs() < 0.1;
    if (unchanged) return;
    final updated = oldElement.copyWith(
      center: Offset(newCx, newCy),
      width: newW,
      height: newH,
    );
    await _updateElementMeta(
      event.elementId,
      updated.toMap()..remove('imageBase64'),
      emit,
      syncConnectors: true,
    );
  }

  Future<void> _onReplaceImageElement(
    CanvasReplaceImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final existing = _findElement(event.elementId);
    if (existing is! ImageElement ||
        existing.locked ||
        event.imageBytes.isEmpty) {
      return;
    }
    final fields =
        (event.style ?? existing.copyWith(crop: ImageElement.fullCrop)).toMap()
          ..remove('cx')
          ..remove('cy')
          ..remove('width')
          ..remove('height')
          ..remove('z')
          ..['imageBase64'] = base64Encode(event.imageBytes)
          ..['locked'] = event.style?.isReference == true;
    if (event.style?.isReference == true) {
      final siblings = canvasPaintOrder(
        state.elements,
      ).bandFor(existing.id)?.elements.where((e) => e.id != existing.id);
      if (siblings != null && siblings.isNotEmpty) {
        final lowest = siblings.map((e) => e.z).reduce(math.min);
        if (lowest <= existing.z) fields['z'] = lowest - 1;
      }
    }
    await _updateElementMeta(
      event.elementId,
      fields,
      emit,
      syncConnectors: true,
    );
  }

  Future<void> _onUpdateImageStyle(
    CanvasUpdateImageStyle event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final existing = _findElement(event.elementId);
    if (existing is! ImageElement) return;
    final releasingReference =
        event.isReference == false && existing.isReference;
    if (existing.locked && !releasingReference) return;

    var image = existing;
    if (existing.locked) {
      image = image.copyWith(isReference: false, locked: false);
    } else {
      if (event.flipH != null) image = image.copyWith(flipped: event.flipH);
      if (event.flipV != null) image = image.copyWith(flipV: event.flipV);
      if (event.quarterTurns % 4 != 0) {
        image = image.copyWith(
          rotation: _normalizeRotation(
            image.rotation + event.quarterTurns * math.pi / 2,
          ),
        );
      }
      if (event.resetCrop) {
        image = applyImageCrop(image, ImageElement.fullCrop);
      } else if (event.crop != null) {
        image = applyImageCrop(image, event.crop!);
      }
      if (event.resetFilters) {
        image = image.copyWith(brightness: 0, contrast: 0, saturation: 0);
      }
      image = image.copyWith(
        borderRadius: event.borderRadius?.clamp(0.0, 360.0),
        borderWidth: event.borderWidth?.clamp(0.0, 32.0),
        borderColor: event.borderColor,
        brightness: event.brightness?.clamp(-1.0, 1.0),
        contrast: event.contrast?.clamp(-1.0, 1.0),
        saturation: event.saturation?.clamp(-1.0, 1.0),
        opacity: event.opacity?.clamp(0.0, 1.0),
      );
      if (event.isReference != null) {
        image = image.copyWith(
          isReference: event.isReference,
          locked: event.isReference! ? true : null,
        );
        if (event.isReference! && !existing.isReference) {
          final band = canvasPaintOrder(state.elements).bandFor(image.id);
          final others = band?.elements.where((e) => e.id != image.id);
          if (others != null && others.isNotEmpty) {
            final lowest = others.map((e) => e.z).reduce(math.min);
            if (lowest <= image.z) image = image.copyWith(z: lowest - 1);
          }
        }
      }
    }
    if (image == existing) return;
    final fields = image.toMap()..remove('imageBase64');
    await _updateElementMeta(
      event.elementId,
      fields,
      emit,
      syncConnectors: true,
    );
  }

  Future<void> _onPreviewImageElement(
    CanvasPreviewImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final existing = _findElement(event.elementId);
    if (existing is! ImageElement || existing.locked) return;
    final payload = Map<String, dynamic>.from(existing.toMap())
      ..remove('imageBase64')
      ..addAll({
        'type': 'image',
        'action': 'upsert',
        'elementId': event.elementId,
        'cx': event.center.dx,
        'cy': event.center.dy,
        'width': event.width.clamp(1.0, 720.0),
        'height': event.height.clamp(1.0, 720.0),
      });
    await _publishSelectedShapePreview(event.elementId, payload);
  }

  Future<void> _onAddStickyNote(
    CanvasAddStickyNote event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final noteId = _uuid.v4();
    final note = fitStickyNoteHeight(
      StickyNoteElement(
        id: noteId,
        z: _nextZIndex(),
        center: event.center,
        width: event.width.clamp(80.0, 480.0),
        height: event.height.clamp(80.0, 480.0),
        text: event.text,
        color: event.color,
        fontSize: event.fontSize.clamp(8.0, 72.0),
        fontWeight: event.fontWeight.clamp(100, 900),
        textColor: event.textColor,
        textAlign: const ['left', 'center', 'right'].contains(event.textAlign)
            ? event.textAlign
            : 'left',
        autoSize: event.autoSize,
        authorUid: _canvasService?.currentClientId,
      ),
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(note);
    emit(
      state.copyWith(
        elements: nextElements,
        activeTray: null,
        selectedShapeId: noteId,
        selectedIds: <String>{noteId},
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(note),
      objectId: noteId,
      data: note.toMap(),
      emit: emit,
    );
  }

  Future<void> _onConvertStickyNote(
    CanvasConvertStickyNote event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final note = _findElement(event.elementId);
    if (note is! StickyNoteElement || note.locked) return;
    final CanvasElement converted = event.toShape
        ? ShapeElement(
            id: note.id,
            z: note.z,
            center: note.center,
            hidden: note.hidden,
            opacity: note.opacity,
            shapeType: CanvasShapeType.rectangle,
            size: math.max(note.width, note.height),
            width: note.width,
            height: note.height,
            color: note.color,
            rotation: note.rotation,
            isFilled: true,
            borderRadius: 8,
            strokeWidth: 0,
            label: note.text,
            labelFontSize: note.fontSize,
            labelFontWeight: note.fontWeight,
            labelColor: note.textColor,
            labelTextAlign: note.textAlign,
          )
        : TextElement(
            id: note.id,
            z: note.z,
            center: note.center - Offset(note.width / 2, note.height / 2),
            hidden: note.hidden,
            opacity: note.opacity,
            text: note.text,
            width: note.width,
            height: note.height,
            color: note.textColor,
            rotation: note.rotation,
            fontSize: note.fontSize,
            fontWeight: note.fontWeight,
            textAlign: note.textAlign,
            lineHeight: 1.4,
          );
    await _updateElementMeta(
      note.id,
      converted.toMap(),
      emit,
      syncConnectors: true,
    );
    _emitSelection({note.id}, emit);
    _announceUndoable(emit, _singleActionMessage('Converted'));
  }

  Future<void> _onUpdateStickyNote(
    CanvasUpdateStickyNote event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final target = state.elements
        .where((e) => e.id == event.elementId)
        .firstOrNull;
    if (target == null || target is! StickyNoteElement || target.locked) return;

    final updated = fitStickyNoteHeight(
      target.copyWith(
        center: event.center,
        width: event.width?.clamp(80.0, 480.0),
        height: event.height?.clamp(80.0, 480.0),
        text: event.text,
        color: event.color,
        fontSize: event.fontSize?.clamp(8.0, 72.0),
        fontWeight: event.fontWeight?.clamp(100, 900),
        textColor: event.textColor,
        textAlign: const ['left', 'center', 'right'].contains(event.textAlign)
            ? event.textAlign
            : null,
        autoSize:
            event.autoSize ?? (event.height != null ? false : target.autoSize),
      ),
    );
    if (updated == target) return;
    await _updateElementMeta(
      updated.id,
      updated.toMap(),
      emit,
      syncConnectors: true,
    );
    if (event.width != null || event.height != null) {
      _announceUndoable(emit, _singleActionMessage('Resized'));
    }
  }

  Future<void> _onAddConnector(
    CanvasAddConnector event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final connectorId = _uuid.v4();
    final connector = ConnectorElement(
      id: connectorId,
      z: _nextZIndex(),
      startElementId: event.startElementId,
      startPoint: event.startPoint,
      startAnchor: event.startAnchor,
      endElementId: event.endElementId,
      endPoint: event.endPoint,
      endAnchor: event.endAnchor,
      lineStyle: event.lineStyle,
      color: event.color,
      strokeWidth: event.strokeWidth,
      hasArrowhead: event.hasArrowhead,
    );
    final nextElements = List<CanvasElement>.from(state.elements)
      ..add(connector);
    emit(
      state.copyWith(
        elements: nextElements,
        activeTray: null,
        selectedShapeId: connectorId,
        selectedIds: <String>{connectorId},
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(connector),
      objectId: connectorId,
      data: connector.toMap(),
      emit: emit,
    );
  }

  Future<void> _onUpdateConnector(
    CanvasUpdateConnector event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final target = state.elements
        .where((e) => e.id == event.elementId)
        .firstOrNull;
    if (target == null || target is! ConnectorElement || target.locked) return;

    const lineStyles = {'straight', 'curved', 'orthogonal'};
    final requestedStyle = event.lineStyle;
    final dash = event.dashPattern;
    final updated = ConnectorElement(
      id: target.id,
      z: target.z,
      hidden: target.hidden,
      locked: target.locked,
      opacity: target.opacity,
      startElementId: target.startElementId,
      startPoint: target.startPoint,
      startAnchor: target.startAnchor,
      endElementId: target.endElementId,
      endPoint: target.endPoint,
      endAnchor: target.endAnchor,
      lineStyle: requestedStyle != null && lineStyles.contains(requestedStyle)
          ? requestedStyle
          : target.lineStyle,
      color: event.color ?? target.color,
      strokeWidth: event.strokeWidth?.clamp(0.5, 32.0) ?? target.strokeWidth,
      hasArrowhead:
          event.endArrowhead ?? event.hasArrowhead ?? target.hasArrowhead,
      startArrowhead: event.startArrowhead ?? target.startArrowhead,
      cornerRadius:
          event.cornerRadius?.clamp(0.0, 120.0) ?? target.cornerRadius,
      dashPattern: dash == null
          ? target.dashPattern
          : dash.isEmpty
          ? null
          : [for (final length in dash) length.clamp(0.5, 200.0)],
      label: event.label ?? target.label,
      labelColor: event.clearLabelColor
          ? null
          : event.labelColor ?? target.labelColor,
      labelFontSize:
          event.labelFontSize?.clamp(6.0, 96.0) ?? target.labelFontSize,
    );
    if (updated == target) return;
    final nextElements = state.elements
        .map((e) => e.id == target.id ? updated : e)
        .toList();
    nextElements.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: nextElements));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(updated),
      objectId: updated.id,
      data: updated.toMap(),
      emit: emit,
    );
    _announceUndoable(emit, _singleActionMessage('Updated'));
  }

  Future<void> _onRewireConnector(
    CanvasRewireConnector event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    ConnectorElement? connector;
    for (final element in state.elements) {
      if (element.id == event.connectorId && element is ConnectorElement) {
        connector = element;
        break;
      }
    }
    if (connector == null || connector.locked) return;

    // Linking both ends to the same element collapses the connector into a
    // zero-length line, so ignore that drop.
    final otherEndId = event.isStart
        ? connector.endElementId
        : connector.startElementId;
    if (event.targetElementId != null && event.targetElementId == otherEndId) {
      return;
    }

    // A detached end has nothing to anchor to, so it falls back to 'center'.
    final anchor = event.targetElementId == null ? 'center' : event.anchor;
    final updated = ConnectorElement(
      id: connector.id,
      z: connector.z,
      hidden: connector.hidden,
      locked: connector.locked,
      opacity: connector.opacity,
      startElementId: event.isStart
          ? event.targetElementId
          : connector.startElementId,
      startPoint: event.isStart ? event.point : connector.startPoint,
      startAnchor: event.isStart ? anchor : connector.startAnchor,
      endElementId: event.isStart
          ? connector.endElementId
          : event.targetElementId,
      endPoint: event.isStart ? connector.endPoint : event.point,
      endAnchor: event.isStart ? connector.endAnchor : anchor,
      lineStyle: connector.lineStyle,
      color: connector.color,
      strokeWidth: connector.strokeWidth,
      hasArrowhead: connector.hasArrowhead,
      startArrowhead: connector.startArrowhead,
      cornerRadius: connector.cornerRadius,
      dashPattern: connector.dashPattern,
      label: connector.label,
      labelColor: connector.labelColor,
      labelFontSize: connector.labelFontSize,
    );
    final nextElements = state.elements
        .map((e) => e.id == updated.id ? updated : e)
        .toList();
    nextElements.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: nextElements));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(updated),
      objectId: updated.id,
      data: updated.toMap(),
      emit: emit,
    );
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
    // Undo can revert an element to a payload identical to the last one
    // received from a peer; clear the dedup guard so the next remote
    // update is not silently dropped.
    _lastShapePayloadFingerprint.clear();
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
    await _publishCrdtUpdate(update);
    // The undo manager is the authority: only offer Redo while it can
    // actually replay the step we just undid.
    final canRedo = adapter.canRedo;
    emit(
      state.copyWith(
        infoMessage: canRedo ? 'Undone · Redo to reapply' : 'Undone',
        infoMessageUndoable: false,
        infoMessageRedoable: canRedo,
      ),
    );
  }

  Future<void> _onRedo(CanvasRedo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) return;
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    final update = adapter.redoLast(origin: 'local');
    if (update == null || update.isEmpty) return;
    // Redo can re-apply a payload identical to the last one received from
    // a peer; clear the dedup guard so the next remote update is not
    // silently dropped.
    _lastShapePayloadFingerprint.clear();
    _refreshFromCrdtAdapter(emit);
    emit(state.copyWith(activeTray: null));
    await _publishCrdtUpdate(update);
    emit(
      state.copyWith(
        infoMessage: 'Redone',
        infoMessageUndoable: false,
        infoMessageRedoable: false,
      ),
    );
  }

  Future<void> _onClearAll(
    CanvasClearAll event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can clear the canvas.'));
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
    await _deleteElementsByIds(
      <String>{event.elementId},
      emit,
      messageForCount: (_) => _singleActionMessage('Deleted'),
    );
  }

  Future<void> _deleteElementsByIds(
    Set<String> candidateIds,
    Emitter<CanvasState> emit, {
    required String Function(int count) messageForCount,
  }) async {
    if (!_ensureCanEdit(emit)) return;
    final existingIds = state.elements.map((element) => element.id).toSet();
    final lockedIds = {
      for (final element in state.elements)
        if (element.locked) element.id,
    };
    final ids = candidateIds
        .where(existingIds.contains)
        .where((id) => !lockedIds.contains(id))
        .toSet();
    if (ids.isEmpty) return;

    // Deleting a shape must not leave connectors pointing at a ghost: detach
    // the affected ends to their stored free points, and prune layer lists.
    final elementUpdates =
        <String, ({String type, Map<String, dynamic> data})>{};
    for (final element in state.elements) {
      if (element is ConnectorElement) {
        final startRemoved =
            element.startElementId != null &&
            ids.contains(element.startElementId);
        final endRemoved =
            element.endElementId != null && ids.contains(element.endElementId);
        if (!startRemoved && !endRemoved) continue;
        final data = Map<String, dynamic>.from(element.toMap());
        if (startRemoved) {
          data.remove('startElementId');
          data['startAnchor'] = 'center';
        }
        if (endRemoved) {
          data.remove('endElementId');
          data['endAnchor'] = 'center';
        }
        elementUpdates[element.id] = (type: 'connector', data: data);
      } else if (element is LayerElement && !ids.contains(element.id)) {
        final filtered = element.elementIds
            .where((id) => !ids.contains(id))
            .toList(growable: false);
        if (filtered.length != element.elementIds.length) {
          final data = Map<String, dynamic>.from(element.toMap())
            ..['elementIds'] = filtered;
          elementUpdates[element.id] = (type: 'layer', data: data);
        }
      }
    }

    final remaining = <CanvasElement>[];
    for (final element in state.elements) {
      if (ids.contains(element.id)) continue;
      final update = elementUpdates[element.id];
      remaining.add(
        update == null
            ? element
            : CanvasElement.fromMap(element.id, update.data),
      );
    }
    final remainingIds = state.selectedIds
        .where((id) => !ids.contains(id))
        .toSet();
    emit(
      state.copyWith(
        elements: remaining,
        selectedShapeId: ids.contains(state.selectedShapeId)
            ? null
            : state.selectedShapeId,
        selectedIds: remainingIds,
      ),
    );
    if (ids.length == 1 && elementUpdates.isEmpty) {
      await _saveCrdtOperation(
        action: 'delete',
        type: 'element',
        objectId: ids.first,
        data: const <String, dynamic>{},
        emit: emit,
      );
    } else {
      await _saveCrdtBatch([
        for (final id in ids)
          (
            action: 'delete',
            type: 'element',
            objectId: id,
            data: const <String, dynamic>{},
          ),
        for (final entry in elementUpdates.entries)
          (
            action: 'update',
            type: entry.value.type,
            objectId: entry.key,
            data: entry.value.data,
          ),
      ], emit);
    }
    _announceUndoable(emit, messageForCount(ids.length));
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
    if (event.brushType == 'marker') {
      // The marker preset starts at its own width and opacity; the sliders
      // remain free to adjust it afterwards.
      final preset = brushPresetFor(event.brushType);
      emit(
        state.copyWith(
          brushType: event.brushType,
          strokeWidth: preset.defaultWidth,
          brushOpacity: preset.defaultOpacity,
          currentToolMode: _toolModeForBrush(event.brushType),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        brushType: event.brushType,
        currentToolMode: _toolModeForBrush(event.brushType),
      ),
    );
  }

  void _onApplyBrushPreset(
    CanvasApplyBrushPreset event,
    Emitter<CanvasState> emit,
  ) {
    final preset = brushPresetFor(event.presetId);
    emit(
      state.copyWith(
        brushType: preset.id,
        strokeWidth: preset.defaultWidth,
        brushOpacity: preset.defaultOpacity,
        currentToolMode: _toolModeForBrush(preset.id),
      ),
    );
  }

  void _onUpdateEraserScope(
    CanvasUpdateEraserScope event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(eraserEraseEverything: event.eraseEverything));
  }

  void _onUpdateStylusPressure(
    CanvasUpdateStylusPressure event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(stylusPressureEnabled: event.enabled));
  }

  void _onUpdateStabilizer(
    CanvasUpdateStabilizer event,
    Emitter<CanvasState> emit,
  ) {
    if (!event.strength.isFinite) return;
    emit(
      state.copyWith(
        stabilizerStrength: event.strength.clamp(0.0, maxStabilizerStrength),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Tool mode & shape draw
  // ──────────────────────────────────────────────

  void _onSetToolMode(CanvasSetToolMode event, Emitter<CanvasState> emit) {
    // Tapping the active tool again closes its options tray without resetting
    // in-progress state.
    if (state.currentToolMode == event.mode &&
        event.shapeType == null &&
        !event.keepTray) {
      emit(state.copyWith(activeTray: null));
      return;
    }
    // `currentToolMode` is the single source of truth for gestures; brushType
    // only describes how a committed stroke is painted.
    final nextBrushType = switch (event.mode) {
      CanvasToolMode.eraser => 'eraser',
      CanvasToolMode.highlight => 'highlighter',
      CanvasToolMode.doodle =>
        (state.brushType == 'eraser' || state.brushType == 'highlighter')
            ? 'solid'
            : state.brushType,
      _ => state.brushType,
    };
    emit(
      state.copyWith(
        currentToolMode: event.mode,
        pendingShapeType: event.shapeType,
        isDrawingShape: false,
        shapeDrawStart: null,
        shapeDrawCurrent: null,
        brushType: nextBrushType,
        // Drawing tools start from a clean slate; Select keeps the selection.
        selectedShapeId: event.mode == CanvasToolMode.select
            ? state.selectedShapeId
            : null,
        selectedIds: event.mode == CanvasToolMode.select
            ? state.selectedIds
            : const <String>{},
        activeTray: event.keepTray ? state.activeTray : null,
      ),
    );
  }

  void _onStartShapeDraw(
    CanvasStartShapeDraw event,
    Emitter<CanvasState> emit,
  ) {
    if (!_ensureCanEdit(emit)) return;
    final isArrow =
        state.currentToolMode == CanvasToolMode.arrow ||
        (state.currentToolMode == CanvasToolMode.shape &&
            state.pendingShapeType == CanvasShapeType.arrow);
    if (state.currentToolMode != CanvasToolMode.shape && !isArrow) return;
    final shapeType =
        state.pendingShapeType ?? (isArrow ? CanvasShapeType.arrow : null);
    if (shapeType == null) return;
    _activeShapeDrawingId = _uuid.v4();
    emit(
      state.copyWith(
        isDrawingShape: true,
        pendingShapeType: shapeType,
        shapeDrawStart: event.point,
        shapeDrawCurrent: event.point,
      ),
    );
  }

  Future<void> _onUpdateShapeDraw(
    CanvasUpdateShapeDraw event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) {
      if (state.isDrawingShape) {
        await _onCancelShapeDraw(CanvasCancelShapeDraw(), emit);
      }
      return;
    }
    if (!state.isDrawingShape) return;
    emit(state.copyWith(shapeDrawCurrent: event.point));

    final start = state.shapeDrawStart;
    final current = event.point;
    final shapeType =
        state.pendingShapeType ??
        (state.currentToolMode == CanvasToolMode.arrow
            ? CanvasShapeType.arrow
            : null);
    final shapeId = _activeShapeDrawingId;
    if (start == null || shapeType == null || shapeId == null) return;

    final dx = (current.dx - start.dx).abs();
    final dy = (current.dy - start.dy).abs();
    if (dx < 5 && dy < 5) return;

    final geom = ShapeGeometry.compute(
      shapeType: shapeType,
      start: start,
      current: current,
    );

    // The preview carries exactly the payload the commit will write.
    final previewData = <String, dynamic>{
      ..._newShape(
        id: shapeId,
        shapeType: shapeType,
        center: geom.center,
        size: geom.size,
        rotation: geom.rotation,
        width: geom.width,
        height: geom.height,
      ).toMap(),
      'action': 'upsert',
      'elementId': shapeId,
    };
    await _publishSelectedShapePreview(shapeId, previewData);
  }

  Future<void> _onEndShapeDraw(
    CanvasEndShapeDraw event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) {
      if (state.isDrawingShape) {
        await _onCancelShapeDraw(CanvasCancelShapeDraw(), emit);
      }
      return;
    }
    if (!state.isDrawingShape) return;
    final start = state.shapeDrawStart;
    final current = state.shapeDrawCurrent;
    final shapeType =
        state.pendingShapeType ??
        (state.currentToolMode == CanvasToolMode.arrow
            ? CanvasShapeType.arrow
            : null);
    if (start == null || current == null || shapeType == null) return;

    final dx = (current.dx - start.dx).abs();
    final dy = (current.dy - start.dy).abs();
    if (dx < 10 && dy < 10) {
      await _onCancelShapeDraw(CanvasCancelShapeDraw(), emit);
      return;
    }

    final geom = ShapeGeometry.compute(
      shapeType: shapeType,
      start: start,
      current: current,
    );

    final shapeId = _activeShapeDrawingId ?? _uuid.v4();
    _activeShapeDrawingId = null;
    _pendingPreviewPublishes.remove(shapeId)?.timer?.cancel();

    await _commitNewShape(
      _newShape(
        id: shapeId,
        shapeType: shapeType,
        center: geom.center,
        size: geom.size,
        rotation: geom.rotation,
        width: geom.width,
        height: geom.height,
      ),
      emit,
      resetDrawState: true,
    );
  }

  Future<void> _onCancelShapeDraw(
    CanvasCancelShapeDraw event,
    Emitter<CanvasState> emit,
  ) async {
    final shapeId = _activeShapeDrawingId;
    _activeShapeDrawingId = null;
    if (shapeId != null) {
      _pendingPreviewPublishes.remove(shapeId)?.timer?.cancel();
      await _publishSelectedShapePreview(shapeId, {
        'action': 'delete',
        'type': 'shape',
        'elementId': shapeId,
      });
    }
    emit(
      state.copyWith(
        currentToolMode: CanvasToolMode.doodle,
        pendingShapeType: null,
        isDrawingShape: false,
        shapeDrawStart: null,
        shapeDrawCurrent: null,
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Selection
  // ──────────────────────────────────────────────

  void _onSelectShape(CanvasSelectShape event, Emitter<CanvasState> emit) {
    _emitSelection(
      event.shapeId == null ? const <String>{} : <String>{event.shapeId!},
      emit,
    );
  }

  void _onSelectElements(
    CanvasSelectElements event,
    Emitter<CanvasState> emit,
  ) {
    _emitSelection(event.ids, emit);
  }

  void _onSelectInRect(CanvasSelectInRect event, Emitter<CanvasState> emit) {
    final ids = event.additive
        ? Set<String>.from(state.selectedIds)
        : <String>{};
    for (final element in state.elements) {
      if (element.hidden || element.locked) continue;
      final bounds = elementBounds(element);
      if (bounds != null && bounds.overlaps(event.rect)) {
        ids.add(element.id);
      }
    }
    _emitSelection(ids, emit);
  }

  /// Sets the selection (primary + full set) and refreshes the per-type
  /// inspector fields for the primary element.
  void _emitSelection(Set<String> ids, Emitter<CanvasState> emit) {
    final ordered = <String>[];
    CanvasElement? primary;
    for (final element in state.elements) {
      if (!ids.contains(element.id)) continue;
      // Hidden and locked elements are not selectable from the canvas.
      if (element.hidden || element.locked) continue;
      ordered.add(element.id);
      primary ??= element;
    }
    final shape = primary is ShapeElement ? primary : null;
    final text = primary is TextElement ? primary : null;
    final sticky = primary is StickyNoteElement ? primary : null;
    final stroke = primary is StrokeElement ? primary : null;
    emit(
      state.copyWith(
        selectedShapeId: ordered.isEmpty ? null : ordered.first,
        selectedIds: ordered.toSet(),
        selectedShapeIsFilled: shape?.isFilled ?? false,
        selectedShapeBorderRadius: shape?.borderRadius ?? 0.0,
        selectedShapeRotation:
            shape?.rotation ?? text?.rotation ?? sticky?.rotation ?? 0.0,
        selectedStrokeColor: stroke?.color.value ?? state.selectedStrokeColor,
        selectedStrokeWidth: stroke?.strokeWidth ?? state.selectedStrokeWidth,
        selectedStrokeOpacity: stroke?.opacity ?? state.selectedStrokeOpacity,
        selectedStrokeBrushType:
            stroke?.brushType ?? state.selectedStrokeBrushType,
      ),
    );
  }

  void _onSetSelectionMode(
    CanvasSetSelectionMode event,
    Emitter<CanvasState> emit,
  ) {
    if (state.selectionMode == event.mode) return;
    emit(state.copyWith(selectionMode: event.mode));
  }

  void _onSelectInLasso(CanvasSelectInLasso event, Emitter<CanvasState> emit) {
    if (event.points.length < 3) return;
    final path = Path()..addPolygon(event.points, true);
    final ids = event.additive
        ? Set<String>.from(state.selectedIds)
        : <String>{};
    for (final element in state.elements) {
      if (element.hidden || element.locked) continue;
      final elementBox = elementBounds(element);
      if (elementBox == null) continue;
      final centreInside = path.contains(elementBox.center);
      final fullyInside =
          path.contains(elementBox.topLeft) &&
          path.contains(elementBox.topRight) &&
          path.contains(elementBox.bottomLeft) &&
          path.contains(elementBox.bottomRight);
      if (centreInside || fullyInside) ids.add(element.id);
    }
    _emitSelection(ids, emit);
  }

  Future<void> _onTranslateSelection(
    CanvasTranslateSelection event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (state.selectedIds.isEmpty || event.delta == Offset.zero) return;
    final count = state.selectedIds.length;
    await _applySelectionDeltas({
      for (final id in state.selectedIds) id: event.delta,
    }, emit);
    emit(
      state.copyWith(
        infoMessage: _groupActionMessage('Moved', count),
        infoMessageUndoable: true,
      ),
    );
  }

  Future<void> _onScaleSelection(
    CanvasScaleSelection event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final source = event.sourceBounds;
    final target = event.targetBounds;
    if (source.width.abs() < 0.01 || source.height.abs() < 0.01) return;
    if (source.width == target.width && source.height == target.height) return;

    final updatedById = <String, CanvasElement>{};
    final writes = <_CrdtWrite>[];
    for (final element in state.elements) {
      if (!state.selectedIds.contains(element.id) || element.locked) continue;
      final data = scaleElementPayload(element, source, target);
      updatedById[element.id] = CanvasElement.fromMap(element.id, data);
      writes.add((
        action: 'update',
        type: _elementType(element),
        objectId: element.id,
        data: data,
      ));
    }
    if (writes.isEmpty) return;
    final next =
        state.elements
            .map((element) => updatedById[element.id] ?? element)
            .toList()
          ..sort(_compareByZ);
    emit(state.copyWith(elements: next));
    await _saveCrdtBatch(writes, emit);
    emit(
      state.copyWith(
        infoMessage: _groupActionMessage('Resized', writes.length),
        infoMessageUndoable: true,
      ),
    );
  }

  Future<void> _onRotateSelection(
    CanvasRotateSelection event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (event.radians.abs() < 0.001) return;

    final updatedById = <String, CanvasElement>{};
    final writes = <_CrdtWrite>[];
    for (final element in state.elements) {
      if (!state.selectedIds.contains(element.id) || element.locked) continue;
      final data = rotateElementPayload(element, event.pivot, event.radians);
      updatedById[element.id] = CanvasElement.fromMap(element.id, data);
      writes.add((
        action: 'update',
        type: _elementType(element),
        objectId: element.id,
        data: data,
      ));
    }
    if (writes.isEmpty) return;
    final next =
        state.elements
            .map((element) => updatedById[element.id] ?? element)
            .toList()
          ..sort(_compareByZ);
    emit(state.copyWith(elements: next));
    await _saveCrdtBatch(writes, emit);
    emit(
      state.copyWith(
        infoMessage: _groupActionMessage('Rotated', writes.length),
        infoMessageUndoable: true,
      ),
    );
  }

  Future<void> _onAlignSelection(
    CanvasAlignSelection event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final bounds = <String, Rect>{};
    for (final element in state.elements) {
      if (!state.selectedIds.contains(element.id)) continue;
      final elementRect = elementBounds(element);
      if (elementRect != null) bounds[element.id] = elementRect;
    }
    if (bounds.length < 2) return;
    var union = bounds.values.first;
    for (final rect in bounds.values.skip(1)) {
      union = union.expandToInclude(rect);
    }
    final deltas = <String, Offset>{};
    if (event.alignment == CanvasSelectionAlignment.distributeHorizontal) {
      _distributeSelectionDeltas(bounds, horizontal: true, out: deltas);
    } else if (event.alignment == CanvasSelectionAlignment.distributeVertical) {
      _distributeSelectionDeltas(bounds, horizontal: false, out: deltas);
    } else {
      for (final entry in bounds.entries) {
        final rect = entry.value;
        deltas[entry.key] = switch (event.alignment) {
          CanvasSelectionAlignment.left => Offset(union.left - rect.left, 0),
          CanvasSelectionAlignment.centerX => Offset(
            union.center.dx - rect.center.dx,
            0,
          ),
          CanvasSelectionAlignment.right => Offset(union.right - rect.right, 0),
          CanvasSelectionAlignment.top => Offset(0, union.top - rect.top),
          CanvasSelectionAlignment.centerY => Offset(
            0,
            union.center.dy - rect.center.dy,
          ),
          CanvasSelectionAlignment.bottom => Offset(
            0,
            union.bottom - rect.bottom,
          ),
          _ => Offset.zero,
        };
      }
    }
    await _applySelectionDeltas(deltas, emit);
    final distributed =
        event.alignment == CanvasSelectionAlignment.distributeHorizontal ||
        event.alignment == CanvasSelectionAlignment.distributeVertical;
    emit(
      state.copyWith(
        infoMessage: _groupActionMessage(
          distributed ? 'Distributed' : 'Aligned',
          bounds.length,
        ),
        infoMessageUndoable: true,
      ),
    );
  }

  void _distributeSelectionDeltas(
    Map<String, Rect> bounds, {
    required bool horizontal,
    required Map<String, Offset> out,
  }) {
    if (bounds.length < 3) return;
    final entries = bounds.entries.toList()
      ..sort(
        (a, b) => horizontal
            ? a.value.center.dx.compareTo(b.value.center.dx)
            : a.value.center.dy.compareTo(b.value.center.dy),
      );
    final first = horizontal
        ? entries.first.value.center.dx
        : entries.first.value.center.dy;
    final last = horizontal
        ? entries.last.value.center.dx
        : entries.last.value.center.dy;
    final step = (last - first) / (entries.length - 1);
    for (var i = 1; i < entries.length - 1; i++) {
      final entry = entries[i];
      final target = first + step * i;
      final current = horizontal
          ? entry.value.center.dx
          : entry.value.center.dy;
      out[entry.key] = horizontal
          ? Offset(target - current, 0)
          : Offset(0, target - current);
    }
  }

  Future<void> _onDuplicateElements(
    CanvasDuplicateElements event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final originals = state.elements
        .where((element) => event.ids.contains(element.id))
        .toList();
    if (originals.isEmpty) return;
    final idMap = <String, String>{
      for (final element in originals) element.id: _uuid.v4(),
    };
    var nextZ = _nextZIndex();
    final clones = <CanvasElement>[];
    for (final element in originals) {
      final data = _translatedPayload(element, const Offset(16, 16));
      data['z'] = nextZ++;
      if (element is ConnectorElement) {
        final startId = element.startElementId;
        final endId = element.endElementId;
        if (startId != null && idMap.containsKey(startId)) {
          data['startElementId'] = idMap[startId];
        }
        if (endId != null && idMap.containsKey(endId)) {
          data['endElementId'] = idMap[endId];
        }
      }
      clones.add(CanvasElement.fromMap(idMap[element.id]!, data));
    }
    final next = <CanvasElement>[...state.elements, ...clones];
    next.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(
      state.copyWith(
        elements: next,
        selectedShapeId: clones.first.id,
        selectedIds: clones.map((element) => element.id).toSet(),
      ),
    );
    await _saveCrdtBatch([
      for (final clone in clones)
        (
          action: 'create',
          type: _elementType(clone),
          objectId: clone.id,
          data: clone.toMap(),
        ),
    ], emit);
    emit(
      state.copyWith(
        infoMessage: _groupActionMessage('Duplicated', clones.length),
        infoMessageUndoable: true,
      ),
    );
  }

  Future<void> _onDeleteElements(
    CanvasDeleteElements event,
    Emitter<CanvasState> emit,
  ) async {
    await _deleteElementsByIds(
      event.ids,
      emit,
      messageForCount: (count) => _groupActionMessage('Deleted', count),
    );
  }

  void _onCopySelection(CanvasCopySelection event, Emitter<CanvasState> emit) {
    final ids = state.selectedIds.isNotEmpty
        ? state.selectedIds
        : (state.selectedShapeId != null
              ? <String>{state.selectedShapeId!}
              : const <String>{});
    if (ids.isEmpty) return;
    final copied = state.elements
        .where(
          (element) =>
              ids.contains(element.id) && !element.hidden && !element.locked,
        )
        .toList();
    if (copied.isEmpty) return;
    _clipboard
      ..clear()
      ..addAll([
        for (final element in copied)
          (id: element.id, data: Map<String, dynamic>.from(element.toMap())),
      ]);
    _pasteOffset = 16;
    emit(state.copyWith(hasClipboard: true));
  }

  Future<void> _onPasteSelection(
    CanvasPasteSelection event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (_clipboard.isEmpty) return;

    final existingIds = state.elements.map((element) => element.id).toSet();
    final idMap = {for (final entry in _clipboard) entry.id: _uuid.v4()};
    final delta = Offset(_pasteOffset, _pasteOffset);
    _pasteOffset += 16;
    var nextZ = _nextZIndex();
    final pasted = <CanvasElement>[];

    for (final entry in _clipboard) {
      final source = CanvasElement.fromMap(entry.id, entry.data);
      final data = _translatedPayload(source, delta);
      data['z'] = nextZ++;
      if (source is ConnectorElement) {
        // Internal links follow the pasted clones; external links survive only
        // if the target element still exists, otherwise the end is detached.
        final startId = source.startElementId;
        if (startId != null) {
          final cloneId = idMap[startId];
          if (cloneId != null) {
            data['startElementId'] = cloneId;
          } else if (!existingIds.contains(startId)) {
            data.remove('startElementId');
            data['sx'] = ((data['sx'] as num?)?.toDouble() ?? 0) + delta.dx;
            data['sy'] = ((data['sy'] as num?)?.toDouble() ?? 0) + delta.dy;
          }
        }
        final endId = source.endElementId;
        if (endId != null) {
          final cloneId = idMap[endId];
          if (cloneId != null) {
            data['endElementId'] = cloneId;
          } else if (!existingIds.contains(endId)) {
            data.remove('endElementId');
            data['ex'] = ((data['ex'] as num?)?.toDouble() ?? 0) + delta.dx;
            data['ey'] = ((data['ey'] as num?)?.toDouble() ?? 0) + delta.dy;
          }
        }
      }
      pasted.add(CanvasElement.fromMap(idMap[entry.id]!, data));
    }

    final next = <CanvasElement>[...state.elements, ...pasted]
      ..sort(_compareByZ);
    emit(
      state.copyWith(
        elements: next,
        selectedShapeId: pasted.first.id,
        selectedIds: pasted.map((element) => element.id).toSet(),
      ),
    );
    await _saveCrdtBatch([
      for (final element in pasted)
        (
          action: 'create',
          type: _elementType(element),
          objectId: element.id,
          data: element.toMap(),
        ),
    ], emit);
    emit(
      state.copyWith(
        infoMessage: _groupActionMessage('Pasted', pasted.length),
        infoMessageUndoable: true,
      ),
    );
  }

  Future<void> _onSetElementVisibility(
    CanvasSetElementVisibility event,
    Emitter<CanvasState> emit,
  ) {
    return _updateElementMeta(event.elementId, {
      'hidden': !event.visible,
    }, emit);
  }

  Future<void> _onSetElementLocked(
    CanvasSetElementLocked event,
    Emitter<CanvasState> emit,
  ) {
    return _updateElementMeta(event.elementId, {'locked': event.locked}, emit);
  }

  Future<void> _onSetElementOpacity(
    CanvasSetElementOpacity event,
    Emitter<CanvasState> emit,
  ) {
    return _updateElementMeta(event.elementId, {
      'opacity': event.opacity.clamp(0.0, 1.0),
    }, emit);
  }

  Future<void> _onReorderElement(
    CanvasReorderElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    // Reorder inside the element's own band. Layers decide the band; z only
    // orders siblings within that band, so a global list would let a drag
    // push an element out of its layer.
    final order = canvasPaintOrder(state.elements);
    final band = order.bandFor(event.elementId);
    if (band == null) return;
    final sorted = List<CanvasElement>.from(band.elements);
    final index = sorted.indexWhere((element) => element.id == event.elementId);
    if (index < 0) return;
    if (sorted[index].locked) return;
    final target = event.newIndex.clamp(0, sorted.length - 1);
    if (target == index) return;
    sorted.insert(target, sorted.removeAt(index));

    final updated = <CanvasElement>[];
    final payloads = <String, Map<String, dynamic>>{};
    final types = <String, String>{};
    for (var i = 0; i < sorted.length; i++) {
      final element = sorted[i];
      if (element.z == i) {
        updated.add(element);
        continue;
      }
      final data = Map<String, dynamic>.from(element.toMap())..['z'] = i;
      updated.add(CanvasElement.fromMap(element.id, data));
      payloads[element.id] = data;
      types[element.id] = _elementType(element);
    }
    final byId = {for (final element in updated) element.id: element};
    emit(
      state.copyWith(
        elements: [
          for (final element in state.elements) byId[element.id] ?? element,
        ],
      ),
    );
    // Reordering rewrites several z values; keep it one undo step.
    await _saveCrdtBatch([
      for (final entry in payloads.entries)
        (
          action: 'update',
          type: types[entry.key]!,
          objectId: entry.key,
          data: entry.value,
        ),
    ], emit);
  }

  Future<void> _onMoveElementToLayer(
    CanvasMoveElementToLayer event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    CanvasElement? element;
    for (final candidate in state.elements) {
      if (candidate.id == event.elementId) {
        element = candidate;
        break;
      }
    }
    if (element == null || element is LayerElement) return;

    LayerElement? targetLayer;
    if (event.layerId != null) {
      for (final candidate in state.elements.whereType<LayerElement>()) {
        if (candidate.id == event.layerId) {
          targetLayer = candidate;
          break;
        }
      }
      if (targetLayer == null) return;
    }

    final changedLayers = <LayerElement>[];
    final payloads = <String, Map<String, dynamic>>{};
    for (final layer in state.elements.whereType<LayerElement>()) {
      final isTarget = layer.id == event.layerId;
      final contains = layer.elementIds.contains(event.elementId);
      if (isTarget && contains) {
        // Already in the destination; membership order has no meaning, so
        // moving within the same section is a no-op.
        continue;
      }
      if (!isTarget && !contains) continue;
      final nextIds = <String>[
        for (final id in layer.elementIds)
          if (id != event.elementId) id,
        if (isTarget) event.elementId,
      ];
      final updated = LayerElement(
        id: layer.id,
        z: layer.z,
        hidden: layer.hidden,
        locked: layer.locked,
        opacity: layer.opacity,
        name: layer.name,
        elementIds: nextIds,
      );
      changedLayers.add(updated);
      payloads[updated.id] = updated.toMap();
    }
    if (changedLayers.isEmpty) return;

    final byId = {for (final layer in changedLayers) layer.id: layer};
    emit(
      state.copyWith(
        elements: [
          for (final element in state.elements) byId[element.id] ?? element,
        ],
      ),
    );
    // Membership lives on the layers only; the element payload is untouched.
    await _saveCrdtBatch([
      for (final entry in payloads.entries)
        (
          action: 'update',
          type: 'layer',
          objectId: entry.key,
          data: entry.value,
        ),
    ], emit);
    final label = targetLayer?.name ?? 'Default';
    _announceUndoable(emit, 'Moved to $label · Undo to revert');
  }

  Future<void> _onReorderLayer(
    CanvasReorderLayer event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final layers = state.elements.whereType<LayerElement>().toList()
      ..sort(_compareByZ);
    final index = layers.indexWhere((layer) => layer.id == event.layerId);
    if (index < 0) return;
    final target = event.newIndex.clamp(0, layers.length - 1);
    if (target == index) return;
    layers.insert(target, layers.removeAt(index));

    final updatedLayers = <LayerElement>[];
    final payloads = <String, Map<String, dynamic>>{};
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (layer.z == i) {
        updatedLayers.add(layer);
        continue;
      }
      final data = Map<String, dynamic>.from(layer.toMap())..['z'] = i;
      updatedLayers.add(CanvasElement.fromMap(layer.id, data) as LayerElement);
      payloads[layer.id] = data;
    }
    final byId = {for (final layer in updatedLayers) layer.id: layer};
    emit(
      state.copyWith(
        elements: [
          for (final element in state.elements) byId[element.id] ?? element,
        ],
      ),
    );
    // All layer z rewrites belong to one undo step.
    await _saveCrdtBatch([
      for (final entry in payloads.entries)
        (
          action: 'update',
          type: 'layer',
          objectId: entry.key,
          data: entry.value,
        ),
    ], emit);
  }

  LayerElement? _activeLayerFor(CanvasState snapshot) {
    final activeId = snapshot.activeLayerId;
    if (activeId == null) return null;
    for (final element in snapshot.elements) {
      if (element is LayerElement && element.id == activeId) return element;
    }
    return null;
  }

  Future<void> _onAddLayer(
    CanvasAddLayer event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final name = event.name.trim().isEmpty ? 'Layer' : event.name.trim();
    final layer = LayerElement(id: _uuid.v4(), z: _nextZIndex(), name: name);
    emit(
      state.copyWith(
        elements: [...state.elements, layer],
        activeLayerId: layer.id,
        infoMessage: 'Added $name · new elements go here',
        infoMessageUndoable: false,
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: 'layer',
      objectId: layer.id,
      data: layer.toMap(),
      emit: emit,
    );
  }

  Future<void> _onRenameLayer(
    CanvasRenameLayer event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final name = event.name.trim();
    if (name.isEmpty) return;
    final existing = state.elements
        .whereType<LayerElement>()
        .where((layer) => layer.id == event.layerId)
        .firstOrNull;
    if (existing == null || existing.name == name) return;
    final renamed = LayerElement(
      id: existing.id,
      z: existing.z,
      hidden: existing.hidden,
      locked: existing.locked,
      opacity: existing.opacity,
      name: name,
      elementIds: existing.elementIds,
    );
    emit(
      state.copyWith(
        elements: [
          for (final element in state.elements)
            element.id == existing.id ? renamed : element,
        ],
      ),
    );
    await _saveCrdtOperation(
      action: 'update',
      type: 'layer',
      objectId: renamed.id,
      data: renamed.toMap(),
      emit: emit,
    );
  }

  Future<void> _onDeleteLayer(
    CanvasDeleteLayer event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final exists = state.elements.whereType<LayerElement>().any(
      (layer) => layer.id == event.layerId,
    );
    if (!exists) return;
    emit(
      state.copyWith(
        elements: state.elements
            .where((element) => element.id != event.layerId)
            .toList(growable: false),
        activeLayerId: state.activeLayerId == event.layerId
            ? null
            : state.activeLayerId,
        infoMessage: 'Layer removed · its elements stay on the board',
        infoMessageUndoable: false,
      ),
    );
    await _saveCrdtOperation(
      action: 'delete',
      type: 'layer',
      objectId: event.layerId,
      data: const <String, dynamic>{},
      emit: emit,
    );
  }

  void _onSetActiveLayer(
    CanvasSetActiveLayer event,
    Emitter<CanvasState> emit,
  ) {
    if (event.layerId != null &&
        !state.elements.whereType<LayerElement>().any(
          (layer) => layer.id == event.layerId,
        )) {
      return;
    }
    emit(state.copyWith(activeLayerId: event.layerId));
  }

  /// Short confirmation shown in a snackbar after a multi-element action.
  String _groupActionMessage(String verb, int count) =>
      '$verb $count ${count == 1 ? 'element' : 'elements'} · Undo to revert';

  /// Short confirmation shown in a snackbar after a single-element action.
  String _singleActionMessage(String verb) => '$verb element · Undo to revert';

  /// Posts an undoable snackbar message after [emit] has the final state.
  void _announceUndoable(Emitter<CanvasState> emit, String message) {
    emit(
      state.copyWith(
        infoMessage: message,
        infoMessageUndoable: true,
        infoMessageRedoable: false,
      ),
    );
  }

  static int _compareByZ(CanvasElement a, CanvasElement b) {
    if (a.z != b.z) return a.z.compareTo(b.z);
    return a.id.compareTo(b.id);
  }

  /// Rewrites one element's payload fields (layer visibility/lock/opacity)
  /// and persists the result. Hidden or locked elements drop out of the
  /// selection so canvas gestures cannot touch them.
  Future<void> _updateElementMeta(
    String elementId,
    Map<String, dynamic> fields,
    Emitter<CanvasState> emit, {
    bool syncConnectors = false,
  }) async {
    if (!_ensureCanEdit(emit)) return;
    final index = state.elements.indexWhere((e) => e.id == elementId);
    if (index < 0) return;
    final element = state.elements[index];
    final data = Map<String, dynamic>.from(element.toMap())..addAll(fields);
    final updated = CanvasElement.fromMap(elementId, data);
    final attached = syncConnectors
        ? _attachedConnectorUpdates(updated)
        : <String, ConnectorElement>{};
    final next = [
      for (final candidate in state.elements)
        candidate.id == elementId
            ? updated
            : attached[candidate.id] ?? candidate,
    ]..sort(_compareByZ);
    final dropFromSelection = updated.hidden || updated.locked;
    final remainingIds = dropFromSelection
        ? (Set<String>.from(state.selectedIds)..remove(elementId))
        : state.selectedIds;
    // If the dropped element was the primary, promote the next survivor so
    // single-element panels keep working with the remaining selection.
    String? nextPrimary = state.selectedShapeId;
    if (nextPrimary == null || !remainingIds.contains(nextPrimary)) {
      nextPrimary = null;
      for (final candidate in next) {
        if (remainingIds.contains(candidate.id)) {
          nextPrimary = candidate.id;
          break;
        }
      }
    }
    emit(
      state.copyWith(
        elements: next,
        selectedShapeId: nextPrimary,
        selectedIds: remainingIds,
      ),
    );
    await _saveCrdtBatch([
      (
        action: 'update',
        type: _elementType(updated),
        objectId: elementId,
        data: updated.toMap(),
      ),
      for (final connector in attached.values)
        (
          action: 'update',
          type: 'connector',
          objectId: connector.id,
          data: connector.toMap(),
        ),
    ], emit);
  }

  /// Applies a per-element world-space translation and persists only the
  /// elements that actually move.
  Future<void> _applySelectionDeltas(
    Map<String, Offset> deltas,
    Emitter<CanvasState> emit,
  ) async {
    final updatedById = <String, CanvasElement>{};
    final payloads = <String, Map<String, dynamic>>{};
    final types = <String, String>{};
    for (final element in state.elements) {
      if (element.locked) continue;
      final delta = deltas[element.id];
      if (delta == null || delta == Offset.zero) continue;
      final data = _translatedPayload(element, delta);
      updatedById[element.id] = CanvasElement.fromMap(element.id, data);
      payloads[element.id] = data;
      types[element.id] = _elementType(element);
    }
    if (updatedById.isEmpty) return;
    final next = state.elements
        .map((element) => updatedById[element.id] ?? element)
        .toList();
    next.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: next));
    await _saveCrdtBatch([
      for (final entry in updatedById.entries)
        (
          action: 'update',
          type: types[entry.key]!,
          objectId: entry.key,
          data: payloads[entry.key]!,
        ),
    ], emit);
  }

  /// Returns a payload translated by [delta]. Attached connector ends stay
  /// pinned to their element; only free ends (and centres) move.
  Map<String, dynamic> _translatedPayload(CanvasElement element, Offset delta) {
    final data = Map<String, dynamic>.from(element.toMap());
    if (element is StrokeElement) {
      data['points'] = element.points
          .map(
            (point) => <String, double>{
              'x': point.dx + delta.dx,
              'y': point.dy + delta.dy,
            },
          )
          .toList(growable: false);
    } else if (element is ConnectorElement) {
      if (element.startElementId == null) {
        data['sx'] = element.startPoint.dx + delta.dx;
        data['sy'] = element.startPoint.dy + delta.dy;
      }
      if (element.endElementId == null) {
        data['ex'] = element.endPoint.dx + delta.dx;
        data['ey'] = element.endPoint.dy + delta.dy;
      }
    } else {
      data['cx'] = ((data['cx'] as num?)?.toDouble() ?? 0) + delta.dx;
      data['cy'] = ((data['cy'] as num?)?.toDouble() ?? 0) + delta.dy;
    }
    return data;
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
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is TextElement) {
      await _onUpdateText(
        CanvasUpdateText(elementId: shape.id, topLeft: event.center),
        emit,
        infoMessage: _singleActionMessage('Moved'),
      );
      return;
    }
    if (shape is ConnectorElement) {
      // A connector has no geometry of its own: translate only the ends that
      // are not pinned to an element so attached ends stay attached.
      final currentCenter = Offset(
        (shape.startPoint.dx + shape.endPoint.dx) / 2,
        (shape.startPoint.dy + shape.endPoint.dy) / 2,
      );
      final delta = event.center - currentCenter;
      if (delta == Offset.zero) return;
      final updated = ConnectorElement(
        id: shape.id,
        z: shape.z,
        hidden: shape.hidden,
        locked: shape.locked,
        opacity: shape.opacity,
        startElementId: shape.startElementId,
        startPoint: shape.startElementId == null
            ? shape.startPoint + delta
            : shape.startPoint,
        startAnchor: shape.startAnchor,
        endElementId: shape.endElementId,
        endPoint: shape.endElementId == null
            ? shape.endPoint + delta
            : shape.endPoint,
        endAnchor: shape.endAnchor,
        lineStyle: shape.lineStyle,
        color: shape.color,
        strokeWidth: shape.strokeWidth,
        hasArrowhead: shape.hasArrowhead,
      );
      final next = state.elements
          .map((e) => e.id == updated.id ? updated : e)
          .toList();
      next.sort((a, b) {
        if (a.z != b.z) return a.z.compareTo(b.z);
        return a.id.compareTo(b.id);
      });
      emit(state.copyWith(elements: next));
      await _saveCrdtOperation(
        action: 'update',
        type: _elementType(updated),
        objectId: updated.id,
        data: updated.toMap(),
        emit: emit,
      );
      _announceUndoable(emit, _singleActionMessage('Moved'));
      return;
    }
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy;
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Moved'));
    }
  }

  Future<void> _onRotateSelectedShape(
    CanvasRotateSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    final normalized = _normalizeRotation(event.rotation);
    emit(state.copyWith(selectedShapeRotation: normalized));
    if (shape is TextElement) {
      await _onUpdateText(
        CanvasUpdateText(elementId: shape.id, rotation: normalized),
        emit,
        infoMessage: _singleActionMessage('Rotated'),
      );
      return;
    }
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['rotation'] = normalized;
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Rotated'));
    }
  }

  Future<void> _onResizeSelectedShape(
    CanvasResizeSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is StickyNoteElement) {
      final newW = event.size.clamp(80.0, 480.0);
      final ratio = shape.width > 0 ? shape.height / shape.width : 1.0;
      final newH = (newW * ratio).clamp(80.0, 480.0);
      await _onUpdateStickyNote(
        CanvasUpdateStickyNote(
          elementId: shape.id,
          width: newW,
          height: newH,
          autoSize: false,
        ),
        emit,
      );
      return;
    }
    final clampedSize = event.size.clamp(24.0, 320.0);
    if (shape is TextElement) {
      await _onUpdateText(
        CanvasUpdateText(elementId: shape.id, width: clampedSize),
        emit,
        infoMessage: _singleActionMessage('Resized'),
      );
      return;
    }
    final data = Map<String, dynamic>.from(shape.toMap());
    if (shape is ShapeElement && (event.width > 0 || event.height > 0)) {
      final w = event.width.clamp(1.0, 4000.0);
      final h = shape.isLinear ? 0.0 : event.height.clamp(1.0, 4000.0);
      data['width'] = w;
      data['height'] = h;
      data['size'] = math.max(w, h);
    } else {
      data['size'] = clampedSize;
    }
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Resized'));
    }
  }

  Future<void> _onToggleSelectedShapeFill(
    CanvasToggleSelectedShapeFill event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['isFilled'] = event.isFilled;
    emit(state.copyWith(selectedShapeIsFilled: event.isFilled));
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateSelectedShapeColor(
    CanvasUpdateSelectedShapeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is TextElement) {
      await _onUpdateText(
        CanvasUpdateText(elementId: shape.id, color: event.color),
        emit,
        infoMessage: _singleActionMessage('Recolored'),
      );
      return;
    }
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['color'] = event.color.value;
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Recolored'));
    }
  }

  Future<void> _onUpdateSelectedShapeBorderRadius(
    CanvasUpdateSelectedShapeBorderRadius event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final size = shape.size;
    final maxRadius = (size / 2).clamp(0.0, 180.0);
    final clampedRadius = event.borderRadius.clamp(0.0, maxRadius);
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['borderRadius'] = clampedRadius;
    emit(state.copyWith(selectedShapeBorderRadius: clampedRadius));
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateSelectedShapeStrokeWidth(
    CanvasUpdateSelectedShapeStrokeWidth event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['strokeWidth'] = event.strokeWidth.clamp(0.0, 64.0);
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateSelectedShapeStrokeOpacity(
    CanvasUpdateSelectedShapeStrokeOpacity event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['strokeOpacity'] = event.strokeOpacity.clamp(0.0, 1.0);
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateSelectedShapeDash(
    CanvasUpdateSelectedShapeDash event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(shape.toMap());
    final pattern = event.dashPattern;
    if (pattern == null || pattern.isEmpty) {
      data.remove('dashPattern');
    } else {
      data['dashPattern'] = [
        for (final length in pattern) length.clamp(0.5, 200.0),
      ];
    }
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateSelectedShapeLabel(
    CanvasUpdateSelectedShapeLabel event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(shape.toMap());
    if (event.label != null) data['label'] = event.label;
    if (event.clearLabelColor) {
      data.remove('labelColor');
    } else if (event.labelColor != null) {
      data['labelColor'] = event.labelColor!.value;
    }
    if (event.labelFontSize != null) {
      data['labelFontSize'] = event.labelFontSize!.clamp(6.0, 96.0);
    }
    if (event.labelFontWeight != null) {
      data['labelFontWeight'] = event.labelFontWeight;
    }
    if (event.labelTextAlign != null) {
      data['labelTextAlign'] = event.labelTextAlign;
    }
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateSelectedShapeArrowheads(
    CanvasUpdateSelectedShapeArrowheads event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(shape.toMap());
    if (event.startArrowhead != null) {
      data['startArrowhead'] = event.startArrowhead;
    }
    if (event.endArrowhead != null) {
      data['endArrowhead'] = event.endArrowhead;
    }
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onCommitPendingShapeEdits(
    CanvasCommitPendingShapeEdits event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final shape = _selectedShape();
    if (shape == null || shape.locked) return;
    final verb =
        event.pendingData.containsKey('size') ||
            event.pendingData.containsKey('width') ||
            event.pendingData.containsKey('height')
        ? 'Resized'
        : event.pendingData.containsKey('rotation')
        ? 'Rotated'
        : 'Updated';
    if (shape is TextElement) {
      await _onUpdateText(
        CanvasUpdateText(
          elementId: shape.id,
          rotation: _toDoubleValue(event.pendingData['rotation']),
          width: _toDoubleValue(event.pendingData['size']),
        ),
        emit,
        infoMessage: _singleActionMessage(verb),
      );
      return;
    }
    final data = Map<String, dynamic>.from(shape.toMap());
    _applyPendingShapeEdits(data, event.pendingData);
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
    if (await _updateShape(shape.id, data, emit)) {
      _announceUndoable(emit, _singleActionMessage(verb));
    }
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
    if (element is! StrokeElement || element.locked) return;
    if (event.delta == Offset.zero) return;
    final newPoints = element.points.map((p) => p + event.delta).toList();
    final updated = StrokeElement(
      id: element.id,
      z: element.z,
      hidden: element.hidden,
      locked: element.locked,
      color: element.color,
      strokeWidth: element.strokeWidth,
      opacity: element.opacity,
      brushType: element.brushType,
      points: newPoints,
    );
    final next = state.elements
        .map((e) => e.id == element.id ? updated : e)
        .toList();
    next.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(updated),
      objectId: element.id,
      data: updated.toMap(),
      emit: emit,
    );
    _announceUndoable(emit, _singleActionMessage('Moved'));
  }

  Future<void> _onUpdateSelectedStrokeColor(
    CanvasUpdateSelectedStrokeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || element.locked || !_ensureCanEdit(emit)) {
      return;
    }
    final data = Map<String, dynamic>.from(element.toMap())
      ..['color'] = event.color;
    emit(state.copyWith(selectedStrokeColor: event.color));
    if (await _updateStroke(element.id, data, emit)) {
      _announceUndoable(emit, _singleActionMessage('Recolored'));
    }
  }

  Future<void> _onUpdateSelectedStrokeWidth(
    CanvasUpdateSelectedStrokeWidth event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || element.locked || !_ensureCanEdit(emit)) {
      return;
    }
    final data = Map<String, dynamic>.from(element.toMap())
      ..['strokeWidth'] = event.strokeWidth;
    emit(state.copyWith(selectedStrokeWidth: event.strokeWidth));
    // Live slider writes stay silent; the screen posts one undoable toast on
    // `CanvasCommitSelectedStrokeEdits` when the gesture ends.
    await _updateStroke(element.id, data, emit);
  }

  Future<void> _onUpdateSelectedStrokeOpacity(
    CanvasUpdateSelectedStrokeOpacity event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || element.locked || !_ensureCanEdit(emit)) {
      return;
    }
    final data = Map<String, dynamic>.from(element.toMap())
      ..['opacity'] = event.opacity;
    emit(state.copyWith(selectedStrokeOpacity: event.opacity));
    // See `_onUpdateSelectedStrokeWidth`: the commit event posts the toast.
    await _updateStroke(element.id, data, emit);
  }

  Future<void> _onUpdateSelectedStrokeBrushType(
    CanvasUpdateSelectedStrokeBrushType event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || element.locked || !_ensureCanEdit(emit)) {
      return;
    }
    final data = Map<String, dynamic>.from(element.toMap())
      ..['brushType'] = event.brushType
      ..['brushId'] = event.brushType;
    emit(state.copyWith(selectedStrokeBrushType: event.brushType));
    if (await _updateStroke(element.id, data, emit)) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  void _onCommitSelectedStrokeEdits(
    CanvasCommitSelectedStrokeEdits event,
    Emitter<CanvasState> emit,
  ) {
    if (!_ensureCanEdit(emit)) return;
    final element = _selectedShape();
    if (element is! StrokeElement || element.locked) return;
    _announceUndoable(emit, _singleActionMessage('Updated'));
  }

  // ──────────────────────────────────────────────
  // Update helpers
  // ──────────────────────────────────────────────

  Future<bool> _updateStroke(
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
    if (existing == null || existing.locked) return false;
    final next = state.elements
        .map((e) => e.id == elementId ? CanvasElement.fromMap(e.id, data) : e)
        .toList(growable: false);
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(existing),
      objectId: elementId,
      data: data,
      emit: emit,
    );
    return true;
  }

  Map<String, ConnectorElement> _attachedConnectorUpdates(
    CanvasElement updatedTarget,
  ) {
    final elementById = <String, CanvasElement>{
      for (final el in state.elements)
        el.id: el.id == updatedTarget.id ? updatedTarget : el,
    };
    final updates = <String, ConnectorElement>{};
    for (final el in state.elements) {
      if (el is! ConnectorElement) continue;
      if (el.startElementId != updatedTarget.id &&
          el.endElementId != updatedTarget.id) {
        continue;
      }
      final (newStart, newEnd) = resolveConnectorEndpoints(el, elementById);
      if ((newStart - el.startPoint).distance < 0.01 &&
          (newEnd - el.endPoint).distance < 0.01) {
        continue;
      }
      updates[el.id] = ConnectorElement(
        id: el.id,
        z: el.z,
        hidden: el.hidden,
        locked: el.locked,
        opacity: el.opacity,
        startElementId: el.startElementId,
        startPoint: newStart,
        startAnchor: el.startAnchor,
        endElementId: el.endElementId,
        endPoint: newEnd,
        endAnchor: el.endAnchor,
        lineStyle: el.lineStyle,
        color: el.color,
        strokeWidth: el.strokeWidth,
        hasArrowhead: el.hasArrowhead,
        startArrowhead: el.startArrowhead,
        cornerRadius: el.cornerRadius,
        dashPattern: el.dashPattern,
        label: el.label,
        labelColor: el.labelColor,
        labelFontSize: el.labelFontSize,
      );
    }
    return updates;
  }

  Future<void> _syncAttachedConnectors(
    CanvasElement updatedTarget,
    Emitter<CanvasState> emit,
  ) async {
    final updates = _attachedConnectorUpdates(updatedTarget);
    if (updates.isEmpty) return;

    final nextElements = state.elements
        .map((el) => updates[el.id] ?? el)
        .toList(growable: false);
    emit(state.copyWith(elements: nextElements));
    await _saveCrdtBatch([
      for (final updatedConnector in updates.values)
        (
          action: 'update',
          type: 'connector',
          objectId: updatedConnector.id,
          data: updatedConnector.toMap(),
        ),
    ], emit);
  }

  Future<bool> _updateShape(
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
    if (existing == null || existing.locked) return false;
    if (existing is! ShapeElement &&
        existing is! StickyNoteElement &&
        existing is! ImageElement) {
      return false;
    }

    final currentCx = existing is ShapeElement
        ? existing.center.dx
        : existing is StickyNoteElement
        ? existing.center.dx
        : (existing as ImageElement).center.dx;
    final currentCy = existing is ShapeElement
        ? existing.center.dy
        : existing is StickyNoteElement
        ? existing.center.dy
        : (existing as ImageElement).center.dy;
    final currentSize = existing is ShapeElement
        ? existing.size
        : existing is StickyNoteElement
        ? existing.width
        : (existing as ImageElement).width;
    final currentWidth = existing is StickyNoteElement
        ? existing.width
        : existing is ImageElement
        ? existing.width
        : (existing as ShapeElement).size;
    final currentHeight = existing is StickyNoteElement
        ? existing.height
        : existing is ImageElement
        ? existing.height
        : (existing as ShapeElement).size;
    final currentRotation = existing is ShapeElement
        ? _normalizeRotation(existing.rotation)
        : existing is StickyNoteElement
        ? _normalizeRotation(existing.rotation)
        : _normalizeRotation((existing as ImageElement).rotation);
    final currentBorderRadius = existing is ShapeElement
        ? existing.borderRadius
        : 0.0;
    final currentColor = existing is ShapeElement
        ? existing.color.value
        : existing is StickyNoteElement
        ? existing.color.value
        : 0;
    final currentFilled = existing is ShapeElement ? existing.isFilled : true;
    final currentText = existing is StickyNoteElement ? existing.text : '';
    final nextCx = (data['cx'] as num?)?.toDouble() ?? 0.0;
    final nextCy = (data['cy'] as num?)?.toDouble() ?? 0.0;
    final nextSize =
        (data['size'] as num?)?.toDouble() ??
        (existing is ShapeElement
            ? 64.0
            : existing is StickyNoteElement
            ? existing.width
            : (existing as ImageElement).width);
    final rawNextW = (data['width'] as num?)?.toDouble();
    final rawNextH = (data['height'] as num?)?.toDouble();
    if (existing is StickyNoteElement) {
      final widthExplicitlyChanged =
          rawNextW != null && (rawNextW - existing.width).abs() >= 0.01;
      final heightExplicitlyChanged =
          rawNextH != null && (rawNextH - existing.height).abs() >= 0.01;
      if (!widthExplicitlyChanged &&
          !heightExplicitlyChanged &&
          (nextSize - existing.width).abs() >= 0.01) {
        final ratio = existing.width > 0
            ? existing.height / existing.width
            : 1.0;
        data['width'] = nextSize.clamp(80.0, 480.0);
        data['height'] = (nextSize * ratio).clamp(80.0, 480.0);
      } else {
        data['width'] = (rawNextW ?? nextSize).clamp(80.0, 480.0);
        data['height'] = (rawNextH ?? existing.height).clamp(80.0, 480.0);
      }
    }
    if (existing is ImageElement) {
      data['imageBase64'] ??= existing.imageBase64;
      final widthExplicitlyChanged =
          rawNextW != null && (rawNextW - existing.width).abs() >= 0.01;
      final heightExplicitlyChanged =
          rawNextH != null && (rawNextH - existing.height).abs() >= 0.01;
      if (!widthExplicitlyChanged &&
          !heightExplicitlyChanged &&
          (nextSize - existing.width).abs() >= 0.01) {
        final ratio = existing.width > 0
            ? existing.height / existing.width
            : 1.0;
        data['width'] = nextSize.clamp(80.0, 720.0);
        data['height'] = (nextSize * ratio).clamp(80.0, 720.0);
      } else {
        data['width'] = (rawNextW ?? existing.width).clamp(80.0, 720.0);
        data['height'] = (rawNextH ?? existing.height).clamp(80.0, 720.0);
      }
    }
    if (existing is ShapeElement) {
      // Explicit width/height win; otherwise resolve the rendered box from the
      // incoming payload so a `size`-only resize scales the legacy aspect box
      // (the first edit migrates legacy shapes to explicit width/height).
      // `size` tracks max(width, height); linear shapes stay flat.
      final dw = (data['width'] as num?)?.toDouble() ?? 0.0;
      final dh = (data['height'] as num?)?.toDouble() ?? 0.0;
      double w;
      double h;
      if (dw > 0 || dh > 0) {
        w = dw;
        h = dh;
      } else {
        final incoming = CanvasElement.fromMap(shapeId, data);
        final box = shapeElementRect(
          incoming is ShapeElement ? incoming : existing,
        );
        w = box.width;
        h = box.height;
      }
      if (existing.isLinear) h = 0.0;
      data['width'] = w;
      data['height'] = h;
      data['size'] = math.max(w, h);
    }
    final nextWidth = (data['width'] as num?)?.toDouble() ?? nextSize;
    final nextHeight = (data['height'] as num?)?.toDouble() ?? nextSize;
    final nextRotation = _normalizeRotation(
      (data['rotation'] as num?)?.toDouble() ?? 0.0,
    );
    final nextBorderRadius = (data['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final nextColor = (data['color'] as num?)?.toInt() ?? 0;
    final nextFilled = (data['isFilled'] as bool?) ?? false;
    final nextText = (data['text'] as String?) ?? currentText;
    final currentZ = existing.z;
    final nextZ = (data['z'] as num?)?.toInt() ?? currentZ;
    final unchanged = existing is ShapeElement
        ? _shapeFingerprint(shapeId, existing.toMap()) ==
              _shapeFingerprint(shapeId, data)
        : (nextCx - currentCx).abs() < 0.01 &&
              (nextCy - currentCy).abs() < 0.01 &&
              (nextSize - currentSize).abs() < 0.01 &&
              (nextWidth - currentWidth).abs() < 0.01 &&
              (nextHeight - currentHeight).abs() < 0.01 &&
              (nextRotation - currentRotation).abs() < 0.0001 &&
              (nextBorderRadius - currentBorderRadius).abs() < 0.01 &&
              nextColor == currentColor &&
              nextFilled == currentFilled &&
              nextText == currentText &&
              nextZ == currentZ;
    if (unchanged) return false;
    final fingerprint = _shapeFingerprint(shapeId, data);
    if (_lastShapePayloadFingerprint[shapeId] == fingerprint) return false;
    _lastShapePayloadFingerprint[shapeId] = fingerprint;
    final updatedTarget = CanvasElement.fromMap(shapeId, data);
    final next = state.elements
        .map((e) => e.id == shapeId ? updatedTarget : e)
        .toList();
    next.sort(_compareByZ);
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(existing),
      objectId: shapeId,
      data: data,
      emit: emit,
    );

    // Maintain dynamic link topology for attached connectors (FR05-15)
    await _syncAttachedConnectors(updatedTarget, emit);
    return true;
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
    if (shape == null ||
        shape.locked ||
        canvasService == null ||
        _boardId.isEmpty) {
      return;
    }
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap());
    _applyPendingShapeEdits(data, event.pendingData);
    if (shape is ImageElement) {
      data.remove('imageBase64');
    }
    await _publishSelectedShapePreview(shape.id, data);
  }

  Future<void> _onPreviewMoveSelectedShape(
    CanvasPreviewMoveSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null ||
        shape.locked ||
        canvasService == null ||
        _boardId.isEmpty) {
      return;
    }
    // Connectors carry endpoints, not a centre; moving one is committed on
    // drag end, so there is no cx/cy preview to publish here.
    if (shape is ConnectorElement) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy;
    if (shape is ImageElement) {
      data.remove('imageBase64');
    }
    await _publishSelectedShapePreview(shape.id, data);
  }

  Future<void> _onPreviewResizeSelectedShape(
    CanvasPreviewResizeSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null ||
        shape.locked ||
        canvasService == null ||
        _boardId.isEmpty) {
      return;
    }
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['size'] = event.size.clamp(24.0, 320.0);
    if (shape is ImageElement) {
      data.remove('imageBase64');
      data['width'] = event.size.clamp(80.0, 720.0);
      data['height'] = event.size.clamp(80.0, 720.0);
    } else if (shape is StickyNoteElement) {
      final newW = event.size.clamp(80.0, 480.0);
      final ratio = shape.width > 0 ? shape.height / shape.width : 1.0;
      data['width'] = newW;
      data['height'] = (newW * ratio).clamp(80.0, 480.0);
    } else if (shape is ShapeElement && (event.width > 0 || event.height > 0)) {
      final w = event.width.clamp(1.0, 4000.0);
      final h = shape.isLinear ? 0.0 : event.height.clamp(1.0, 4000.0);
      data['width'] = w;
      data['height'] = h;
      data['size'] = math.max(w, h);
    }
    await _publishSelectedShapePreview(shape.id, data);
  }

  Future<void> _onPreviewRotateSelectedShape(
    CanvasPreviewRotateSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    final canvasService = _canvasService;
    if (shape == null ||
        shape.locked ||
        canvasService == null ||
        _boardId.isEmpty) {
      return;
    }
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(shape.toMap())
      ..['rotation'] = _normalizeRotation(event.rotation);
    await _publishSelectedShapePreview(shape.id, data);
  }

  // ──────────────────────────────────────────────
  // Eraser
  // ──────────────────────────────────────────────

  void _beginEraserStroke(Offset point) {
    _activeStrokeId = null;
    _activeShapeDrawingId = null;
    _eraserSession = _EraserSession(
      previewId: _uuid.v4(),
      radius: state.strokeWidth / 2,
      baseElementIds: {for (final element in state.elements) element.id},
    )..path.add(point);
  }

  /// Applies the erase on every pointer sample so ink disappears under the
  /// eraser as the user drags, instead of only on release.
  Future<void> _extendEraserStroke(
    List<Offset> path,
    Emitter<CanvasState> emit,
  ) async {
    final session = _eraserSession ??= _EraserSession(
      previewId: _uuid.v4(),
      radius: state.strokeWidth / 2,
      baseElementIds: {for (final element in state.elements) element.id},
    );
    session.path
      ..clear()
      ..addAll(path);
    final result = _applyEraserStroke(
      elements: state.elements,
      erasePath: session.path,
      eraserRadius: session.radius,
      eraseEverything: state.eraserEraseEverything,
    );
    session.absorb(result);
    final selectedId = state.selectedShapeId;
    emit(
      state.copyWith(
        elements: result.nextElements,
        selectedShapeId:
            selectedId != null && result.deletedElementIds.contains(selectedId)
            ? null
            : selectedId,
      ),
    );
    await _publishEraserCursor(session, path.last);
  }

  Future<void> _publishEraserCursor(_EraserSession session, Offset position) {
    return _publishSelectedShapePreview(session.previewId, {
      'type': 'eraser',
      'radius': session.radius,
      'x': position.dx,
      'y': position.dy,
    });
  }

  void _cancelPendingPreview(String elementId) {
    _pendingPreviewPublishes.remove(elementId)?.timer?.cancel();
  }

  Future<void> _finishEraserStroke(
    Emitter<CanvasState> emit,
    List<Offset>? smoothedPoints,
  ) async {
    final session = _eraserSession;
    _eraserSession = null;
    _activeStrokeId = null;
    _activeShapeDrawingId = null;
    final path = (session != null && session.path.isNotEmpty)
        ? List<Offset>.from(session.path)
        : List<Offset>.from(smoothedPoints ?? state.currentStroke);
    if (path.isEmpty) {
      emit(state.copyWith(currentStroke: const []));
      return;
    }
    final baseIds =
        session?.baseElementIds ??
        {for (final element in state.elements) element.id};
    final createdIds = session?.createdIds ?? <String>{};
    final erasedIds = session?.erasedIds ?? <String>{};
    final result = _applyEraserStroke(
      elements: state.elements,
      erasePath: path,
      eraserRadius: session?.radius ?? (state.strokeWidth / 2),
      eraseEverything: state.eraserEraseEverything,
    );
    // Fragments first produced by this final pass (e.g. a tap erase with no
    // drag samples) still have to be persisted.
    session?.absorb(result);
    final nextElements = result.nextElements;
    final survivingIds = {for (final element in nextElements) element.id};
    final deletedIds = <String>{
      ...erasedIds,
      ...result.deletedElementIds,
      ...baseIds.difference(survivingIds),
    }..removeAll(survivingIds);
    final created = <CanvasElement>[
      for (final element in nextElements)
        if (createdIds.contains(element.id)) element,
    ];
    final selectedId = state.selectedShapeId;
    emit(
      state.copyWith(
        elements: nextElements,
        currentStroke: const [],
        selectedShapeId: selectedId != null && deletedIds.contains(selectedId)
            ? null
            : selectedId,
      ),
    );
    final previewId = session?.previewId;
    if (previewId != null) {
      // Stop the throttled cursor preview so no stray ring is left behind.
      _cancelPendingPreview(previewId);
    }
    await _commitEraser(
      deletedElementIds: deletedIds,
      createdStrokes: created,
      emit: emit,
    );
    if (previewId != null) {
      await _publishOperationPreview(
        action: 'delete',
        type: 'eraser',
        objectId: previewId,
        data: const {},
      );
    }
  }

  /// Persists a finished erase as a single CRDT update: one round trip and one
  /// state rebuild, so the result never flickers through half-applied states
  /// and collaborators never see a partially erased board.
  Future<void> _commitEraser({
    required Set<String> deletedElementIds,
    required List<CanvasElement> createdStrokes,
    required Emitter<CanvasState> emit,
  }) async {
    if (!_canSync) return;
    await _ensureCrdtReady();
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    if (deletedElementIds.isEmpty && createdStrokes.isEmpty) return;
    for (final id in deletedElementIds) {
      // Elements that exist locally only as collaborator previews have no CRDT
      // entry to tombstone, so hide their preview too instead of letting the
      // erased ink reappear on the next rebuild.
      if (_remotePreviewElements.remove(id) != null) {
        _remotePreviewDeletedIds.add(id);
      }
    }
    final beforeVector = adapter.encodeStateVector();
    for (final id in deletedElementIds) {
      adapter.deleteElement(id, origin: 'local');
    }
    for (final stroke in createdStrokes) {
      adapter.upsertElement(stroke.id, <String, dynamic>{
        'type': 'stroke',
        ...stroke.toMap(),
      }, origin: 'local');
    }
    final update = adapter.encodeStateUpdate(vector: beforeVector);
    _refreshFromCrdtAdapter(emit);
    if (update.isNotEmpty) {
      await _publishCrdtUpdate(update);
    }
  }

  /// Re-applies an in-flight erase over freshly rebuilt elements.
  List<CanvasElement> _applyActiveEraserOverlay(List<CanvasElement> elements) {
    final session = _eraserSession;
    if (session == null || session.path.isEmpty) return elements;
    final result = _applyEraserStroke(
      elements: elements,
      erasePath: session.path,
      eraserRadius: session.radius,
      eraseEverything: state.eraserEraseEverything,
    );
    session.absorb(result);
    return result.nextElements;
  }

  void _pruneRemoteEraserCursors() {
    if (_remoteEraserCursors.isEmpty) return;
    final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
    _remoteEraserCursors.removeWhere(
      (_, cursor) => cursor.updatedAt.isBefore(cutoff),
    );
  }

  _EraserResult _applyEraserStroke({
    required List<CanvasElement> elements,
    required List<Offset> erasePath,
    required double eraserRadius,
    required bool eraseEverything,
  }) {
    final deletedIds = <String>[];
    final createdStrokes = <CanvasElement>[];
    final nextElements = <CanvasElement>[];
    final eraseBounds = _erasePathBounds(erasePath, eraserRadius);
    if (eraseBounds == null) {
      return _EraserResult(
        nextElements: List<CanvasElement>.from(elements),
        deletedElementIds: deletedIds,
        createdStrokes: createdStrokes,
      );
    }
    for (final element in elements) {
      // Locked art is protected; hidden art is not part of the visible board.
      if (element.locked || element.hidden) {
        nextElements.add(element);
        continue;
      }
      if (element is! StrokeElement) {
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
      final strokePoints = element.points;
      if (strokePoints.isEmpty) {
        nextElements.add(element);
        continue;
      }
      // Cheap reject: only strokes near the eraser swath are re-split.
      if (!_strokeBounds(
        strokePoints,
        element.strokeWidth / 2,
      ).overlaps(eraseBounds)) {
        nextElements.add(element);
        continue;
      }
      final keepSegments = splitStrokeByEraserPath(
        strokePoints: strokePoints,
        erasePath: erasePath,
        eraseRadius: eraserRadius + (element.strokeWidth / 2),
      );
      if (keepSegments.length == 1 &&
          (identical(keepSegments.first, strokePoints) ||
              _samePointList(keepSegments.first, strokePoints))) {
        nextElements.add(element);
        continue;
      }
      deletedIds.add(element.id);
      for (var index = 0; index < keepSegments.length; index++) {
        final segment = keepSegments[index];
        if (segment.length < 2) continue;
        final replacement = StrokeElement(
          // Deterministic ids keep the live erase idempotent: re-splitting the
          // same stroke while dragging reuses the same fragments instead of
          // spawning (and duplicating) new ones on every sample.
          id: '${element.id}~e$index',
          // Fragments inherit the source stroke's z, so erasing never lifts a
          // stroke above shapes it was drawn behind.
          z: element.z,
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

  Future<void> _onRemoveBoardMember(
    CanvasRemoveBoardMember event,
    Emitter<CanvasState> emit,
  ) async {
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    try {
      await boardService.removeBoardMember(_boardId, event.targetUid);
      emit(state.copyWith(error: null));
    } catch (e) {
      emit(
        state.copyWith(
          error:
              'Failed to revoke member access: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onUpdateBoardMemberRole(
    CanvasUpdateBoardMemberRole event,
    Emitter<CanvasState> emit,
  ) async {
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    try {
      await boardService.updateBoardMemberRole(
        _boardId,
        event.targetUid,
        event.newRole,
      );
      emit(state.copyWith(error: null));
    } catch (e) {
      emit(
        state.copyWith(
          error:
              'Failed to update member role: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
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

  int _activeExportCount = 0;

  Future<void> _onExportBoardRequested(
    CanvasExportBoardRequested event,
    Emitter<CanvasState> emit,
  ) async {
    _activeExportCount++;
    emit(state.copyWith(isExporting: true, error: null));
    try {
      final boardTitle = state.boardTitle ?? 'Board';
      final file = await _boardExportService.exportBoard(
        boardTitle: boardTitle,
        elements: state.elements,
        format: event.format,
      );

      var shareOutcome = BoardShareOutcome.dismissed;
      if (event.shareAfterExport) {
        shareOutcome = await _boardExportService.shareBoardFile(
          file: file,
          boardTitle: boardTitle,
          sharePositionOrigin: event.sharePositionOrigin,
        );
      }

      final ext = event.format.name.toUpperCase();
      final destination = file.path.contains('Download')
          ? 'Downloads'
          : 'device storage';
      final String successMsg;
      if (!event.shareAfterExport) {
        successMsg =
            'Board saved locally to $destination as $ext!\n${file.path}';
      } else if (shareOutcome == BoardShareOutcome.shared) {
        successMsg = 'Board exported as $ext and opened in Share Sheet!';
      } else if (shareOutcome == BoardShareOutcome.unavailable) {
        successMsg =
            'Board saved as $ext, but sharing is not available on this device.\n${file.path}';
      } else {
        successMsg = 'Board exported as $ext.\n${file.path}';
      }
      _activeExportCount = math.max(0, _activeExportCount - 1);
      emit(
        state.copyWith(
          isExporting: _activeExportCount > 0,
          lastExportedFilePath: file.path,
          exportSuccessMessage: successMsg,
        ),
      );
    } catch (e) {
      _activeExportCount = math.max(0, _activeExportCount - 1);
      emit(
        state.copyWith(
          isExporting: _activeExportCount > 0,
          error: 'Failed to export board: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  void _onConsumeExportMessage(
    CanvasConsumeExportMessage event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(exportSuccessMessage: null));
  }

  Future<void> _onRequestEditAccess(
    CanvasRequestEditAccess event,
    Emitter<CanvasState> emit,
  ) async {
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    try {
      await boardService.requestBoardAccess(
        boardId: _boardId,
        requestType: 'edit',
        message: event.message,
      );
      emit(
        state.copyWith(
          infoMessage: 'Edit access request sent to board owner.',
          infoMessageUndoable: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: AppErrorFormatter.cleanMessage(
            e,
            fallback: 'Failed to request edit access.',
          ),
        ),
      );
    }
  }

  void _onConsumeInfoMessage(
    CanvasConsumeInfoMessage event,
    Emitter<CanvasState> emit,
  ) {
    emit(
      state.copyWith(
        infoMessage: null,
        infoMessageUndoable: false,
        infoMessageRedoable: false,
      ),
    );
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
      _activeStrokeId = null;
      _strokeStabilizer = null;
      _strokeClock.stop();
      emit(
        state.copyWith(
          currentStroke: const [],
          currentStrokePressures: const [],
        ),
      );
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

  Offset randomShapeCenter() =>
      Offset(180 + _random.nextDouble() * 40, 220 + _random.nextDouble() * 80);

  Offset randomTextCenter() =>
      Offset(200 + _random.nextDouble() * 40, 240 + _random.nextDouble() * 60);

  // ──────────────────────────────────────────────
  // Module 11: In-App Communication & Voice Listeners & Handlers
  // ──────────────────────────────────────────────

  void _startCommunicationListeners(String boardId) {
    if (isClosed) return;
    _commentsSub?.cancel();
    _chatSub?.cancel();
    _voiceParticipantsSub?.cancel();
    _voiceCallStatusSub?.cancel();
    _voiceMuteStatusSub?.cancel();

    final commentsService = _boardCommentsService;
    if (commentsService != null) {
      _commentsSub = commentsService.watchComments(boardId).listen((comments) {
        if (!isClosed) add(CanvasCommentsUpdated(comments));
      }, onError: (_) {});
    }

    final chatService = _boardChatService;
    if (chatService != null) {
      chatService.connect(boardId);
      _chatSub = chatService.watchChatMessages(boardId).listen((msg) {
        if (!isClosed) add(CanvasChatMessageReceived(msg));
      }, onError: (_) {});
      chatService
          .getChatHistory(boardId)
          .then((history) {
            if (!isClosed && history.isNotEmpty) {
              add(CanvasChatMessagesUpdated(history));
            }
          })
          .catchError((_) {});
    }

    final voiceService = _voiceService;
    if (voiceService != null) {
      _voiceParticipantsSub = voiceService.watchParticipants(boardId).listen((
        participants,
      ) {
        if (!isClosed) add(CanvasVoiceParticipantsUpdated(participants));
      }, onError: (_) {});
      _voiceCallStatusSub = voiceService.watchIsInCall().listen((isInCall) {
        if (!isClosed) add(CanvasVoiceCallStatusChanged(isInCall));
      }, onError: (_) {});
      _voiceMuteStatusSub = voiceService.watchIsMuted().listen((isMuted) {
        if (!isClosed) add(CanvasVoiceMuteStatusChanged(isMuted));
      }, onError: (_) {});
    }
  }

  void _onCanvasCommentsUpdated(
    CanvasCommentsUpdated event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(comments: event.comments));
  }

  void _onCanvasChatMessagesUpdated(
    CanvasChatMessagesUpdated event,
    Emitter<CanvasState> emit,
  ) {
    // History can resolve after live messages have already arrived; merge
    // by id instead of replacing so messages received live are not dropped.
    final merged = <String, BoardChatMessage>{
      for (final m in state.chatMessages) m.id: m,
    };
    merged.addAll({for (final m in event.messages) m.id: m});
    final messages = merged.values.toList()
      ..sort((a, b) {
        final byTime = a.timestamp.compareTo(b.timestamp);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    emit(state.copyWith(chatMessages: messages));
  }

  void _onCanvasChatMessageReceived(
    CanvasChatMessageReceived event,
    Emitter<CanvasState> emit,
  ) {
    if (state.chatMessages.any((m) => m.id == event.message.id)) return;
    final updated = List<BoardChatMessage>.from(state.chatMessages)
      ..add(event.message);
    emit(state.copyWith(chatMessages: updated));
  }

  void _onCanvasVoiceParticipantsUpdated(
    CanvasVoiceParticipantsUpdated event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(voiceParticipants: event.participants));
  }

  void _onCanvasVoiceCallStatusChanged(
    CanvasVoiceCallStatusChanged event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(isVoiceCallActive: event.isInCall));
  }

  void _onCanvasVoiceMuteStatusChanged(
    CanvasVoiceMuteStatusChanged event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(isMicMuted: event.isMuted));
  }

  void _onCanvasToggleChatDrawer(
    CanvasToggleChatDrawer event,
    Emitter<CanvasState> emit,
  ) {
    final nextOpen = !state.isChatDrawerOpen;
    emit(
      state.copyWith(
        isChatDrawerOpen: nextOpen,
        isCommentsTrayOpen: nextOpen ? false : state.isCommentsTrayOpen,
      ),
    );
  }

  void _onCanvasToggleCommentsTray(
    CanvasToggleCommentsTray event,
    Emitter<CanvasState> emit,
  ) {
    final nextOpen = !state.isCommentsTrayOpen;
    emit(
      state.copyWith(
        isCommentsTrayOpen: nextOpen,
        isChatDrawerOpen: nextOpen ? false : state.isChatDrawerOpen,
      ),
    );
  }

  void _onCanvasToggleCommentPlacementMode(
    CanvasToggleCommentPlacementMode event,
    Emitter<CanvasState> emit,
  ) {
    final nextVal = event.enable ?? !state.isPlacingComment;
    emit(state.copyWith(isPlacingComment: nextVal));
  }

  void _onCanvasSetActiveComment(
    CanvasSetActiveComment event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(activeCommentId: event.commentId));
  }

  Future<void> _onCanvasAddCommentRequested(
    CanvasAddCommentRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final commentsService = _boardCommentsService;
    if (commentsService == null || _boardId.isEmpty) return;
    try {
      await commentsService.addComment(
        boardId: _boardId,
        text: event.text,
        canvasPosition: event.canvasPosition,
        boardTitle: state.boardTitle,
      );
      emit(state.copyWith(isPlacingComment: false));
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Failed to add comment: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onCanvasAddCommentReplyRequested(
    CanvasAddCommentReplyRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final commentsService = _boardCommentsService;
    if (commentsService == null || _boardId.isEmpty) return;
    try {
      await commentsService.addReply(
        boardId: _boardId,
        commentId: event.commentId,
        text: event.text,
        boardTitle: state.boardTitle,
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Failed to add reply: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onCanvasDeleteCommentRequested(
    CanvasDeleteCommentRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final commentsService = _boardCommentsService;
    if (commentsService == null || _boardId.isEmpty) return;
    try {
      await commentsService.deleteComment(
        boardId: _boardId,
        commentId: event.commentId,
      );
      if (state.activeCommentId == event.commentId) {
        emit(state.copyWith(activeCommentId: null));
      }
    } catch (e) {
      emit(
        state.copyWith(
          error:
              'Failed to delete comment: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onCanvasSendChatMessageRequested(
    CanvasSendChatMessageRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final chatService = _boardChatService;
    if (chatService == null || _boardId.isEmpty || event.text.trim().isEmpty) {
      return;
    }
    try {
      final msg = await chatService.sendMessage(
        boardId: _boardId,
        text: event.text.trim(),
      );
      if (!state.chatMessages.any((m) => m.id == msg.id)) {
        final updated = List<BoardChatMessage>.from(state.chatMessages)
          ..add(msg);
        emit(state.copyWith(chatMessages: updated));
      }
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Failed to send message: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onCanvasJoinVoiceCallRequested(
    CanvasJoinVoiceCallRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final voiceService = _voiceService;
    if (voiceService == null || _boardId.isEmpty) return;
    try {
      await voiceService.joinCall(_boardId);
      emit(state.copyWith(isVoiceCallActive: true));
    } catch (e) {
      emit(
        state.copyWith(
          error:
              'Failed to join voice call: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onCanvasLeaveVoiceCallRequested(
    CanvasLeaveVoiceCallRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final voiceService = _voiceService;
    if (voiceService == null || _boardId.isEmpty) return;
    try {
      await voiceService.leaveCall(_boardId);
      emit(state.copyWith(isVoiceCallActive: false));
    } catch (e) {
      emit(
        state.copyWith(
          error:
              'Failed to leave voice call: ${AppErrorFormatter.cleanMessage(e)}',
        ),
      );
    }
  }

  Future<void> _onCanvasToggleVoiceMuteRequested(
    CanvasToggleVoiceMuteRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final voiceService = _voiceService;
    if (voiceService == null || _boardId.isEmpty) return;
    try {
      await voiceService.toggleMute(_boardId);
    } catch (_) {}
  }

  Future<void> _onCanvasVoiceSpeakingChanged(
    CanvasVoiceSpeakingChanged event,
    Emitter<CanvasState> emit,
  ) async {
    final voiceService = _voiceService;
    if (voiceService == null || _boardId.isEmpty) return;
    try {
      await voiceService.setSpeaking(
        boardId: _boardId,
        isSpeaking: event.isSpeaking,
      );
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _boardUnavailableTimer?.cancel();
    _boardUnavailableTimer = null;
    for (final preview in _pendingPreviewPublishes.values) {
      preview.timer?.cancel();
    }
    _pendingPreviewPublishes.clear();
    _activeStrokeId = null;
    _activeShapeDrawingId = null;
    await _commentsSub?.cancel();
    _commentsSub = null;
    await _chatSub?.cancel();
    _chatSub = null;
    await _voiceParticipantsSub?.cancel();
    _voiceParticipantsSub = null;
    await _voiceCallStatusSub?.cancel();
    _voiceCallStatusSub = null;
    await _voiceMuteStatusSub?.cancel();
    _voiceMuteStatusSub = null;
    if (_boardId.isNotEmpty && state.isVoiceCallActive) {
      _voiceService?.leaveCall(_boardId);
    }
    await _boardMetaSub?.cancel();
    _boardMetaSub = null;
    await _membersSub?.cancel();
    _membersSub = null;
    await _crdtUpdatesSub?.cancel();
    _crdtUpdatesSub = null;
    await _previewUpdatesSub?.cancel();
    _previewUpdatesSub = null;
    await _canvasService?.stopCrdtRemoteSync(_boardId);
    return super.close();
  }
}
