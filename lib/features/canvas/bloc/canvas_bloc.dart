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
import '../../../domain/models/history/board_activity_block.dart';
import '../../../domain/models/history/board_operation.dart';
import '../../../domain/models/history/history_scrub.dart';
import '../../../domain/models/history/revert_plan.dart';
import '../../../domain/models/history/undo_request.dart';
import '../../../domain/repositories/history/board_history_repository.dart';
import '../../../domain/services/history/board_history_service.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/canvas/board_chat_service.dart';
import '../../../domain/services/canvas/board_comments_service.dart';
import '../../../domain/services/canvas/board_export_service.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../../../domain/services/voice/voice_service.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../models/board_chat_message.dart';
import '../models/canvas_comment.dart';
import '../models/canvas_element.dart';
import '../models/canvas_tool_mode.dart';
import '../models/voice_participant.dart';
import '../view/trays/canvas_shape_type.dart';
import 'canvas_state.dart';

export '../../../domain/services/canvas/board_export_service.dart';
export '../models/board_chat_message.dart';
export '../models/canvas_comment.dart';
export '../models/canvas_element.dart';
export '../models/voice_participant.dart';
export 'canvas_state.dart';

part 'canvas_event.dart';
part 'canvas_helpers.dart';

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final CanvasService? _canvasService;
  final BoardService? _boardService;
  final BoardCommentsService? _boardCommentsService;
  final BoardChatService? _boardChatService;
  final VoiceService? _voiceService;
  final BoardHistoryService? _historyService;
  final BoardHistoryRepository? _historyRepository;

  /// Temporary CRDT doc backing the active history scrub preview — never the
  /// live adapter. Rebuilt from the base state whenever the slider moves back
  /// (CRDT deltas are not invertible).
  CanvasDocAdapter? _historyScrubAdapter;

  final Uuid _uuid = const Uuid();
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
  StreamSubscription<List<BoardActivityBlock>>? _historyFeedSub;
  StreamSubscription<List<UndoRequest>>? _undoRequestsSub;
  CanvasDocAdapter? _crdtAdapter;
  List<CanvasElement>? _cachedCrdtElements;
  Future<void>? _crdtInitFuture;
  Timer? _boardUnavailableTimer;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  final Map<String, CanvasElement> _remotePreviewElements =
      <String, CanvasElement>{};
  final Set<String> _remotePreviewDeletedIds = <String>{};
  /// When each remote preview arrived. Previews are transient overlays: without
  /// an expiry a peer's in-flight drag (or a preview that never got a matching
  /// committed update) masks the element's real state on this device forever.
  final Map<String, DateTime> _remotePreviewReceivedAt =
      <String, DateTime>{};
  static const Duration _remotePreviewTtl = Duration(seconds: 3);
  bool _remotePreviewClearsBoard = false;
  final Map<String, String> _lastShapePayloadFingerprint = <String, String>{};
  /// The payload THIS device last committed to the CRDT per element id
  /// (upsert → payload, delete → null). Undo/redo compares the live CRDT
  /// value against it: a mismatch means a collaborator changed the element
  /// on top of our work, and the undo entry must NOT be consumed (§7.2
  /// conflict flow). Key order-insensitive deep equality is used.
  final Map<String, Map<String, dynamic>?> _myCommittedPayload =
      <String, Map<String, dynamic>?>{};
  /// What each element held when the matching undo entry was captured — the
  /// value a REDO of that entry must restore. The redo conflict gate compares
  /// the live value against THIS (not the post-undo baseline): after a peer
  /// undoes their overwrite, the element holds our value again, which is
  /// exactly what the redo would produce — a harmless no-op, not a conflict
  /// (§7.2).
  final Map<String, Map<String, dynamic>?> _myRedoTarget =
      <String, Map<String, dynamic>?>{};
  final Map<String, String> _lastShapeUpdateId =
      <String, String>{};
  final Map<String, _QueuedPreviewPublish> _pendingPreviewPublishes =
      <String, _QueuedPreviewPublish>{};
  String? _activeStrokeId;
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
    BoardHistoryService? historyService,
    BoardHistoryRepository? historyRepository,
    String currentUserId = '',
    String boardId = '',
  }) : _canvasService = canvasService,
       _boardService = boardService,
       _boardExportService = boardExportService ?? const BoardExportServiceImpl(),
       _boardCommentsService = boardCommentsService,
       _boardChatService = boardChatService,
       _voiceService = voiceService,
       _historyService = historyService,
       _historyRepository = historyRepository,
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
    on<CanvasAddImageElement>(_onAddImageElement);
    on<CanvasPreviewImageElement>(_onPreviewImageElement);
    on<CanvasUpdateImageElement>(_onUpdateImageElement);
    on<CanvasAddStickyNote>(_onAddStickyNote);
    on<CanvasUpdateStickyNote>(_onUpdateStickyNote);
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
    on<CanvasHistoryFeedRequested>(_onHistoryFeedRequested);
    on<CanvasHistoryFeedUpdated>(_onHistoryFeedUpdated);
    on<CanvasHistoryPreviewRequested>(_onHistoryPreviewRequested);
    on<CanvasHistoryPreviewExited>(_onHistoryPreviewExited);
    on<CanvasHistoryRequestEvidenceRequested>(
      _onHistoryRequestEvidenceRequested,
    );
    on<CanvasHistoryEvidenceViewToggled>(_onHistoryEvidenceViewToggled);
    on<CanvasHistoryRestoreRequested>(_onHistoryRestoreRequested);
    on<CanvasHistoryRevertUserRequested>(_onHistoryRevertUserRequested);
    on<CanvasHistoryUndoRequestReviewRequested>(
      _onHistoryUndoRequestReviewRequested,
    );
    on<CanvasHistoryUserOpsRequested>(_onHistoryUserOpsRequested);
    on<CanvasHistoryUserOpsUpdated>(_onHistoryUserOpsUpdated);
    on<CanvasHistoryUserTimelineExited>(_onHistoryUserTimelineExited);
    on<CanvasHistoryVersionScrubRequested>(_onHistoryVersionScrubRequested);
    on<CanvasHistoryUserScrubRequested>(_onHistoryUserScrubRequested);
    on<CanvasHistoryScrubMoved>(_onHistoryScrubMoved);
    on<CanvasHistoryScrubLoadOlderRequested>(_onHistoryScrubLoadOlderRequested);
    on<CanvasHistoryOpCompareRequested>(_onHistoryOpCompareRequested);
    on<CanvasHistoryRevertOpsRequested>(_onHistoryRevertOpsRequested);
    on<CanvasHistoryPlanLoaded>(_onHistoryPlanLoaded);
    on<CanvasHistoryPlanFailed>(_onHistoryPlanFailed);
    on<CanvasHistoryPlanDismissed>(_onHistoryPlanDismissed);
    on<CanvasHistoryApplyRevert>(_onHistoryApplyRevert);
    on<CanvasHistoryUndoOwn>(_onHistoryUndoOwn);
    on<CanvasToggleUndoRequestAreaSelection>(
      _onToggleUndoRequestAreaSelection,
    );
    on<CanvasUndoRequestsUpdated>(_onUndoRequestsUpdated);
    on<CanvasUndoConflictDismissed>(_onUndoConflictDismissed);
    on<CanvasUndoRequestDraftStarted>(_onUndoRequestDraftStarted);
    on<CanvasUndoRequestDraftElementToggled>(_onUndoRequestDraftElementToggled);
    on<CanvasUndoRequestDraftAreaSet>(_onUndoRequestDraftAreaSet);
    on<CanvasUndoRequestDraftCleared>(_onUndoRequestDraftCleared);
    on<CanvasUndoRequestPreviewRequested>(_onUndoRequestPreviewRequested);
    on<CanvasUndoRequestSubmitRequested>(_onUndoRequestSubmitRequested);
    on<CanvasHistoryRevertOpsAfterRequested>(_onHistoryRevertOpsAfterRequested);
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
      emit(state.copyWith(error: 'Failed to rename board: ${AppErrorFormatter.cleanMessage(e)}'));
    }
  }

  void _onCanvasBoardTitleUpdated(
    CanvasBoardTitleUpdated event,
    Emitter<CanvasState> emit,
  ) {
    final wasOwner = _currentUserRole == Board.roleOwner;
    _currentUserRole = event.currentUserRole;
    _syncHistorySubscriptions();
    // The role can resolve AFTER the owner already opened the history screen
    // (the first feed request early-returns for non-owners and would never
    // be retried). Retry now that we know the role.
    if (!wasOwner && _currentUserRole == Board.roleOwner) {
      _ensureHistoryFeedSubscription();
    }
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
        emit(state.copyWith(
          isLoading: false,
          error: AppErrorFormatter.cleanMessage(
            e,
            fallback: 'Failed to load canvas.',
          ),
        ));
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
    if (isClosed || _crdtUpdatesSub != null || !_canSync) return;
    final canvasService = _canvasService;
    if (canvasService == null) return;
    _crdtUpdatesSub = canvasService
        .listenToCrdtUpdates(_boardId)
        .listen(
          (updates) {
            if (!isClosed) {
              add(CanvasApplyRemoteUpdate(updates));
            }
          },
          onError: (_) {},
        );
  }

  void _startPreviewUpdatesListener() {
    if (isClosed || _previewUpdatesSub != null || !_canSync) return;
    final canvasService = _canvasService;
    if (canvasService == null) return;
    _previewUpdatesSub = canvasService
        .listenToCanvasPreviews(_boardId)
        .listen(
          (previews) {
            if (!isClosed) {
              add(CanvasApplyRemotePreview(previews));
            }
          },
          onError: (_) {},
        );
  }

  void _startBoardMetadataListener() {
    if (isClosed) return;
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    _boardMetaSub?.cancel();
    _boardMetaSub = canvasService.watchBoardById(_boardId).listen(
      (board) {
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
          add(CanvasBoardTitleUpdated(
            board.title,
            currentUserRole: board.currentUserRole,
          ));
        }
      },
      onError: (_) {},
    );
    _startBoardMembersListener();
  }

  void _startBoardMembersListener() {
    if (isClosed) return;
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;
    _membersSub?.cancel();
    _membersSub = boardService
        .getBoardMembers(_boardId)
        .listen(
          (members) {
            if (!isClosed) {
              add(CanvasBoardMembersUpdated(members));
            }
          },
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
        // A full-state hydration replaces the board, so the local stack is
        // meaningless afterwards (D14).
        adapter.clearLocalHistory();
        _appliedCrdtUpdateIds.add(snapshot.updateId);
        _myCommittedPayload.clear();
        _myRedoTarget.clear();
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
        // D14: an owner's revert/restore/clear is authoritative locally — the
        // member may redraw but cannot resurrect the reverted work via Ctrl+Z.
        if (update.sourceClientId != state.currentUserId) {
          switch (update.action) {
            case 'restore':
            case 'clear':
              adapter.clearLocalHistory();
              _myCommittedPayload.clear();
              _myRedoTarget.clear();
              break;
            case 'revert':
              adapter.pruneReverted(
                (update.affectedElementIds ?? const <String>[]).toSet(),
              );
              // D14: the owner's revert replaced those entries; their commit
              // baselines are meaningless now (a fresh local edit re-records).
              _dropCommitRecords(
                update.affectedElementIds ?? const <String>[],
              );
              break;
          }
        }
        _remotePreviewClearsBoard = false;
        // A committed update supersedes any preview/deletion overlay for that
        // element, otherwise a stale preview would keep masking the real value.
        if (update.elementId != null) {
          _forgetPreviews(update.elementId!);
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
          _remotePreviewReceivedAt.remove(elementId);
          continue;
        }
        _remotePreviewDeletedIds.remove(elementId);
        if (type == 'image') {
          final incomingBase64 = decoded['imageBase64'] as String?;
          if (incomingBase64 == null || incomingBase64.isEmpty) {
            final existing = _remotePreviewElements[elementId] ??
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
        _remotePreviewElements[preview.elementId!] =
            CanvasElement.fromMap(elementId, decoded);
        _remotePreviewReceivedAt[preview.elementId!] = DateTime.now();
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
    // Our own edit wins over any overlay still being shown for this element.
    _forgetPreviews(objectId);
    if (!_canSync) return;
    await _ensureCrdtReady();
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    Uint8List update;
    if (action == 'delete' && type == 'board') {
      // D13 clear: every element in the CRDT doc is removed by this device.
      // Record the removals so a later undo compares against the right
      // baseline (an undo of the clear must not look like a conflict).
      for (final id in adapter.materializeElements().keys) {
        _myCommittedPayload[id] = null;
      }
      update = adapter.clearElements(origin: 'local');
    } else if (action == 'delete') {
      _myCommittedPayload[objectId] = null;
      update = adapter.deleteElement(objectId, origin: 'local');
    } else {
      final payload = <String, dynamic>{'type': type, ...data};
      _myCommittedPayload[objectId] = _deepCopyPayload(payload);
      update = adapter.upsertElement(objectId, payload, origin: 'local');
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
    // D13 hint: only a whole-board delete is a 'clear' (which forces a durable
    // pre-clear checkpoint server-side). The archive worker derives truth from
    // the CRDT diff, so this is never trusted for attribution.
    final actionHint = action == 'delete'
        ? (type == 'board' ? 'clear' : 'delete')
        : 'upsert';
    final publishedUpdateId = await _publishCrdtUpdate(
      update,
      elementId: elementId,
      action: actionHint,
    );
    if (publishedUpdateId != null) {
      _lastShapeUpdateId[objectId] = publishedUpdateId;
    }
  }

  Future<String?> _publishCrdtUpdate(
    Uint8List update, {
    String? elementId,
    String action = 'upsert',
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
      action: action,
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
    _pruneExpiredPreviews();
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

  void _pruneExpiredPreviews() {
    if (_remotePreviewElements.isEmpty) return;
    final now = DateTime.now();
    _remotePreviewElements.removeWhere((id, _) {
      final receivedAt = _remotePreviewReceivedAt[id];
      final expired = receivedAt != null &&
          now.difference(receivedAt) > _remotePreviewTtl;
      if (expired) _remotePreviewReceivedAt.remove(id);
      return expired;
    });
  }

  /// Drop every preview overlay for [elementId]. Called as soon as this device
  /// commits its own edit, so a collaborator's in-flight preview can never keep
  /// showing the pre-edit version to the person who just changed it.
  void _forgetPreviews(String elementId) {
    _remotePreviewElements.remove(elementId);
    _remotePreviewDeletedIds.remove(elementId);
    _remotePreviewReceivedAt.remove(elementId);
  }

  /// Payload of the element as committed to the CRDT document.
  ///
  /// Edits must never be built from `state.elements`, because that view is
  /// composited with transient collaborator previews: persisting it would copy
  /// a preview's stale values over the real ones (an opacity change rewriting
  /// the stroke width, a colour change rewriting the points, ...).
  Map<String, dynamic>? _committedElementPayload(String elementId) {
    final adapter = _crdtAdapter;
    if (adapter != null) {
      final payload = adapter.materializeElements()[elementId];
      if (payload != null) return Map<String, dynamic>.from(payload);
    }
    for (final element in state.elements) {
      if (element.id == elementId) {
        return Map<String, dynamic>.from(element.toMap());
      }
    }
    return null;
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
          width: (payload['width'] as num?)?.toDouble() ?? 0.0,
          height: (payload['height'] as num?)?.toDouble() ?? 0.0,
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
        continue;
      }
      if (type == 'sticky_note') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(StickyNoteElement(
          id: id,
          z: z,
          center: Offset(
            (payload['cx'] as num?)?.toDouble() ?? 0.0,
            (payload['cy'] as num?)?.toDouble() ?? 0.0,
          ),
          width: (payload['width'] as num?)?.toDouble() ?? 160.0,
          height: (payload['height'] as num?)?.toDouble() ?? 160.0,
          text: (payload['text'] as String?) ?? '',
          color: Color((payload['color'] as num?)?.toInt() ?? 0xFFFFF9A6),
          rotation: (payload['rotation'] as num?)?.toDouble() ?? 0.0,
        ));
        continue;
      }
      if (type == 'connector') {
        final z = _readElementOrder(
          elementId: id,
          payload: payload,
          currentOrder: currentOrder,
          fallbackOrder: maxExistingOrder + rebuilt.length,
        );
        rebuilt.add(ConnectorElement(
          id: id,
          z: z,
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
          color: Color((payload['color'] as num?)?.toInt() ?? Colors.black.value),
          strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 2.5,
          hasArrowhead: _parseBool(payload['hasArrowhead'] ?? true),
        ));
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

  String _elementType(CanvasElement element) {
    return switch (element) {
      StrokeElement() => 'stroke',
      ShapeElement() => 'shape',
      TextElement() => 'text',
      ImageElement() => 'image',
      StickyNoteElement() => 'sticky_note',
      ConnectorElement() => 'connector',
    };
  }

  // ──────────────────────────────────────────────
  // Stroke operations
  // ──────────────────────────────────────────────

  void _onStartStroke(CanvasStartStroke event, Emitter<CanvasState> emit) {
    if (!_ensureCanEditWithOptions(emit, clearStroke: true)) return;
    if (state.brushType == 'eraser') {
      _beginEraserStroke(event.point);
      emit(state.copyWith(currentStroke: [event.point]));
      return;
    }
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
    if (state.brushType == 'eraser') {
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
    if (state.brushType == 'eraser' || _eraserSession != null) {
      await _finishEraserStroke(emit, event.smoothedPoints);
      return;
    }
    final usePoints = event.smoothedPoints ?? state.currentStroke;
    if (usePoints.length < 2) {
      emit(state.copyWith(currentStroke: const []));
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
    final measured = measureTextElementBounds(prompt);
    final textElement = TextElement(
      id: textId,
      z: _nextZIndex(),
      text: prompt,
      center: event.position,
      color: state.selectedColor,
      width: measured.width,
      height: measured.height,
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
    final moved = (newCx - oldElement.center.dx).abs() >= 0.1 ||
        (newCy - oldElement.center.dy).abs() >= 0.1;
    final newZ = moved ? _nextZIndex() : oldElement.z;
    final next = state.elements
        .map((e) => e.id == event.elementId
            ? ImageElement(
                id: e.id,
                z: newZ,
                center: Offset(newCx, newCy),
                width: newW,
                height: newH,
                imageBase64: (e as ImageElement).imageBase64,
              )
            : e)
        .toList();
    next.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: next));
    final updateData = <String, dynamic>{
      'type': 'image',
      'z': newZ,
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

  Future<void> _onAddStickyNote(
    CanvasAddStickyNote event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final noteId = _uuid.v4();
    final note = StickyNoteElement(
      id: noteId,
      z: _nextZIndex(),
      center: event.center,
      width: event.width,
      height: event.height,
      text: event.text,
      color: event.color,
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(note);
    emit(state.copyWith(
      elements: nextElements,
      activeTray: null,
      selectedShapeId: noteId,
    ));
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(note),
      objectId: noteId,
      data: note.toMap(),
      emit: emit,
    );
  }

  Future<void> _onUpdateStickyNote(
    CanvasUpdateStickyNote event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final target =
        state.elements.where((e) => e.id == event.elementId).firstOrNull;
    if (target == null || target is! StickyNoteElement) return;

    final newZ = event.center != null ? _nextZIndex() : target.z;
    final updated = StickyNoteElement(
      id: target.id,
      z: newZ,
      center: event.center ?? target.center,
      width: target.width,
      height: target.height,
      text: event.text ?? target.text,
      color: event.color ?? target.color,
      rotation: target.rotation,
    );
    final nextElements =
        state.elements.map((e) => e.id == target.id ? updated : e).toList();
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
    final nextElements = List<CanvasElement>.from(state.elements)..add(connector);
    emit(state.copyWith(
      elements: nextElements,
      activeTray: null,
      selectedShapeId: connectorId,
    ));
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
    final target =
        state.elements.where((e) => e.id == event.elementId).firstOrNull;
    if (target == null || target is! ConnectorElement) return;

    final updated = ConnectorElement(
      id: target.id,
      z: target.z,
      startElementId: target.startElementId,
      startPoint: target.startPoint,
      startAnchor: target.startAnchor,
      endElementId: target.endElementId,
      endPoint: target.endPoint,
      endAnchor: target.endAnchor,
      lineStyle: event.lineStyle ?? target.lineStyle,
      color: event.color ?? target.color,
      strokeWidth: event.strokeWidth ?? target.strokeWidth,
      hasArrowhead: event.hasArrowhead ?? target.hasArrowhead,
    );
    final nextElements =
        state.elements.map((e) => e.id == target.id ? updated : e).toList();
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
    if (connector == null) return;

    // Linking both ends to the same element collapses the connector into a
    // zero-length line, so ignore that drop.
    final otherEndId =
        event.isStart ? connector.endElementId : connector.startElementId;
    if (event.targetElementId != null && event.targetElementId == otherEndId) {
      return;
    }

    // A detached end has nothing to anchor to, so it falls back to 'center'.
    final anchor = event.targetElementId == null ? 'center' : event.anchor;
    final updated = ConnectorElement(
      id: connector.id,
      z: connector.z,
      startElementId:
          event.isStart ? event.targetElementId : connector.startElementId,
      startPoint: event.isStart ? event.point : connector.startPoint,
      startAnchor: event.isStart ? anchor : connector.startAnchor,
      endElementId:
          event.isStart ? connector.endElementId : event.targetElementId,
      endPoint: event.isStart ? connector.endPoint : event.point,
      endAnchor: event.isStart ? connector.endAnchor : anchor,
      lineStyle: connector.lineStyle,
      color: connector.color,
      strokeWidth: connector.strokeWidth,
      hasArrowhead: connector.hasArrowhead,
    );
    final nextElements =
        state.elements.map((e) => e.id == updated.id ? updated : e).toList();
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

  /// Detaches a payload map from the caller's (possibly mutated) object.
  static Map<String, dynamic> _deepCopyPayload(Map<String, dynamic> source) {
    dynamic copy(dynamic value) {
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), copy(v)));
      }
      if (value is List) {
        return value.map(copy).toList();
      }
      return value; // JSON-safe leaves are immutable
    }

    return Map<String, dynamic>.from(
      source.map((k, v) => MapEntry(k, copy(v))),
    );
  }

  /// Deep equality that ignores Map key order (Yjs and payload builders do
  /// not guarantee it) but keeps List order (stroke points are ordered).
  static bool _payloadEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_payloadEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_payloadEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// Elements among [ids] whose live CRDT value no longer matches what this
  /// device last committed there — i.e. a collaborator changed our work.
  /// A missing record means this device never committed that element locally
  /// (e.g. a stack item restored across a snapshot), which is treated as a
  /// conflict so a stale undo can never clobber unknown state.
  List<String> _myCommitConflicts(Set<String> ids) {
    final adapter = _crdtAdapter;
    if (adapter == null) return const [];
    final live = adapter.materializeElements();
    final conflicts = <String>[];
    for (final id in ids) {
      final recorded = _myCommittedPayload[id];
      final current = live[id];
      if (_payloadEquals(current, recorded)) continue;
      conflicts.add(id);
    }
    return conflicts;
  }

  /// After a successful local undo/redo the elements now hold the value this
  /// device produced by reverting — re-record it so the NEXT conflict check
  /// compares against the right baseline. (Once a collaborator undoes their
  /// overwrite, our recorded value matches the live one again and our undo
  /// works — the 15-minute window permitting, per D2.)
  void _refreshCommitRecords(Set<String> ids) {
    final adapter = _crdtAdapter;
    if (adapter == null || ids.isEmpty) return;
    final live = adapter.materializeElements();
    for (final id in ids) {
      _myCommittedPayload[id] = live[id];
    }
  }

  /// The stack these ids belonged to is gone (owner revert, own server undo,
  /// full restore): drop the baselines too so they cannot cause false
  /// conflicts if the elements are edited again later.
  void _dropCommitRecords(Iterable<String> ids) {
    for (final id in ids) {
      _myCommittedPayload.remove(id);
      _myRedoTarget.remove(id);
    }
  }

  /// Before the commit baselines are refreshed to the post-undo values,
  /// remember what the elements held when the entry was captured: a later
  /// REDO must restore exactly this, so this is what its conflict gate
  /// compares against.
  void _captureRedoTargets(Set<String> ids) {
    for (final id in ids) {
      _myRedoTarget[id] = _myCommittedPayload[id];
    }
  }

  /// Elements among [ids] whose live CRDT value differs from BOTH the value
  /// left by the matching undo (the commit baseline) AND the value the redo
  /// would restore (the pre-undo target). That means a collaborator changed
  /// the element to something else since our undo, and redoing would clobber
  /// their content. When the live value equals either one, redoing is either
  /// exactly right or an honest no-op (e.g. the peer undid their overwrite,
  /// which already restored our content) — not a conflict (§7.2).
  List<String> _myRedoConflicts(Set<String> ids) {
    final adapter = _crdtAdapter;
    if (adapter == null) return const [];
    final live = adapter.materializeElements();
    final conflicts = <String>[];
    for (final id in ids) {
      final target = _myRedoTarget[id] ?? _myCommittedPayload[id];
      final baseline = _myCommittedPayload[id];
      if (_payloadEquals(live[id], baseline)) continue;
      if (_payloadEquals(live[id], target)) continue;
      conflicts.add(id);
    }
    return conflicts;
  }

  /// Baselines for the pending local undo/redo: a peeked top entry whose
  /// elements no longer match what this device committed means a collaborator
  /// changed our work.
  Future<void> _onUndo(CanvasUndo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) return;
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    final peeked = adapter.peekUndoElementIds();
    if (peeked != null) {
      final conflicts = _myCommitConflicts(peeked);
      if (conflicts.isNotEmpty) {
        // Do NOT pop the stack item: Yjs would leave the collaborator's newer
        // value visible (LWW per key, D10) while consuming the entry, making
        // the undo a silent no-op that also destroys redo. Surface the
        // conflict instead (§7.2).
        emit(state.copyWith(
          undoConflict: CanvasUndoConflict(elementIds: conflicts),
          isHistoryLoading: false,
        ));
        return;
      }
    }
    final update = adapter.undoLast(origin: 'local');
    if (update == null || update.isEmpty) {
      // D2: the local stack is empty OR its top entry is older than 15 minutes.
      // Either way the server-side log fallback is the correct path.
      await _undoOwnViaLog(emit);
      return;
    }
    // Undo can revert an element to a payload identical to the last one
    // received from a peer; clear the dedup guard so the next remote
    // update is not silently dropped.
    _lastShapePayloadFingerprint.clear();
    _refreshFromCrdtAdapter(emit);
    // The reverted elements now hold the value THIS device produced; re-record
    // it so the next conflict check compares against the right baseline. The
    // PRE-undo values are captured first — that is what a later REDO of this
    // entry must restore, and what its conflict gate compares against.
    if (peeked != null) _captureRedoTargets(peeked);
    if (peeked != null) _refreshCommitRecords(peeked);
    emit(state.copyWith(activeTray: null));
    await _publishCrdtUpdate(update);
  }

  Future<void> _onRedo(CanvasRedo event, Emitter<CanvasState> emit) async {
    if (!_ensureCanEdit(emit)) return;
    final adapter = _crdtAdapter;
    if (adapter == null) return;
    final peeked = adapter.peekRedoElementIds();
    if (peeked != null) {
      final conflicts = _myRedoConflicts(peeked);
      if (conflicts.isNotEmpty) {
        emit(state.copyWith(
          undoConflict: CanvasUndoConflict(elementIds: conflicts),
          isHistoryLoading: false,
        ));
        return;
      }
    }
    final update = adapter.redoLast(origin: 'local');
    if (update == null || update.isEmpty) {
      // Redo is local-only and equally 15-minute capped: there is no log redo.
      // Empty also covers a redo whose target already holds the restored
      // value (the peer undid their overwrite) — an honest no-op.
      emit(state.copyWith(infoMessage: 'Nothing to redo.', error: null));
      return;
    }
    // Redo can re-apply a payload identical to the last one received from
    // a peer; clear the dedup guard so the next remote update is not
    // silently dropped.
    _lastShapePayloadFingerprint.clear();
    _refreshFromCrdtAdapter(emit);
    if (peeked != null) _refreshCommitRecords(peeked);
    // The entry was consumed; its redo target is meaningless now.
    if (peeked != null) {
      for (final id in peeked) {
        _myRedoTarget.remove(id);
      }
    }
    emit(state.copyWith(activeTray: null));
    await _publishCrdtUpdate(update);
  }

  Future<void> _onClearAll(
    CanvasClearAll event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(
        error: 'Only the board owner can clear the canvas.',
      ));
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
  // Tool mode & shape draw
  // ──────────────────────────────────────────────

  void _onSetToolMode(
    CanvasSetToolMode event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(
      currentToolMode: event.mode,
      pendingShapeType: event.shapeType,
      isDrawingShape: false,
      shapeDrawStart: null,
      shapeDrawCurrent: null,
      activeTray: event.keepTray ? state.activeTray : null,
    ));
  }

  void _onStartShapeDraw(
    CanvasStartShapeDraw event,
    Emitter<CanvasState> emit,
  ) {
    if (!_ensureCanEdit(emit)) return;
    final isArrow = state.currentToolMode == CanvasToolMode.arrow ||
        (state.currentToolMode == CanvasToolMode.shape &&
            state.pendingShapeType == CanvasShapeType.arrow);
    if (state.currentToolMode != CanvasToolMode.shape && !isArrow) return;
    final shapeType =
        state.pendingShapeType ?? (isArrow ? CanvasShapeType.arrow : null);
    if (shapeType == null) return;
    _activeShapeDrawingId = _uuid.v4();
    emit(state.copyWith(
      isDrawingShape: true,
      pendingShapeType: shapeType,
      shapeDrawStart: event.point,
      shapeDrawCurrent: event.point,
    ));
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
    final shapeType = state.pendingShapeType ??
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

    final previewData = <String, dynamic>{
      'action': 'upsert',
      'type': 'shape',
      'elementId': shapeId,
      'shapeType': shapeType.name,
      'cx': geom.center.dx,
      'cy': geom.center.dy,
      'size': geom.size,
      'color': state.selectedColor.value,
      'strokeWidth': 3.0,
      'isFilled': false,
      'rotation': geom.rotation,
      'borderRadius': 0.0,
      'z': _nextZIndex(),
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
    final shapeType = state.pendingShapeType ??
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

    final shape = ShapeElement(
      id: shapeId,
      z: _nextZIndex(),
      shapeType: shapeType,
      center: geom.center,
      size: geom.size,
      color: state.selectedColor,
      strokeWidth: 3.0,
      isFilled: false,
      rotation: geom.rotation,
    );
    final nextElements = List<CanvasElement>.from(state.elements)..add(shape);
    emit(state.copyWith(
      elements: nextElements,
      activeTray: null,
      selectedShapeId: shapeId,
      selectedShapeRotation: geom.rotation,
      selectedShapeIsFilled: false,
      selectedShapeBorderRadius: 0.0,
      isDrawingShape: false,
      shapeDrawStart: null,
      shapeDrawCurrent: null,
      currentToolMode: CanvasToolMode.doodle,
      pendingShapeType: null,
    ));
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(shape),
      objectId: shapeId,
      data: shape.toMap(),
      emit: emit,
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
    emit(state.copyWith(
      currentToolMode: CanvasToolMode.doodle,
      pendingShapeType: null,
      isDrawingShape: false,
      shapeDrawStart: null,
      shapeDrawCurrent: null,
    ));
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
    final nextZ = _nextZIndex();
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
        z: nextZ,
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
      final next =
          state.elements.map((e) => e.id == updated.id ? updated : e).toList();
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
      return;
    }
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy
      ..['z'] = nextZ;
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onRotateSelectedShape(
    CanvasRotateSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final normalized = _normalizeRotation(event.rotation);
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['rotation'] = normalized;
    emit(state.copyWith(selectedShapeRotation: normalized));
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onResizeSelectedShape(
    CanvasResizeSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['size'] = event.size.clamp(24.0, 320.0);
    if (shape is StickyNoteElement) {
      // Sticky notes are drawn from width/height; `size` is only used by the
      // slider/resize gesture. Without this the note never changes size.
      final width = (event.width ?? event.size).clamp(40.0, 480.0).toDouble();
      final height = (event.height ?? event.size).clamp(40.0, 480.0).toDouble();
      data['width'] = width;
      data['height'] = height;
    }
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onToggleSelectedShapeFill(
    CanvasToggleSelectedShapeFill event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['isFilled'] = event.isFilled;
    emit(state.copyWith(selectedShapeIsFilled: event.isFilled));
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onUpdateSelectedShapeColor(
    CanvasUpdateSelectedShapeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
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
    final clampedRadius = event.borderRadius.clamp(0.0, maxRadius);
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['borderRadius'] = clampedRadius;
    emit(state.copyWith(selectedShapeBorderRadius: clampedRadius));
    await _updateShape(shape.id, data, emit);
  }

  Future<void> _onCommitPendingShapeEdits(
    CanvasCommitPendingShapeEdits event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final shape = _selectedShape();
    if (shape == null) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap());
    for (final entry in event.pendingData.entries) {
      if (entry.key == 'rotation') {
        final rotation = _toDoubleValue(entry.value);
        if (rotation == null) continue;
        data[entry.key] = _normalizeRotation(rotation);
      } else if (entry.key == 'size') {
        final size = _toDoubleValue(entry.value);
        if (size == null) continue;
        final clamped = size.clamp(24.0, 320.0);
        data[entry.key] = clamped;
        if (shape is StickyNoteElement) {
          final noteSize = clamped.clamp(40.0, 480.0);
          data['width'] = noteSize;
          data['height'] = noteSize;
        }
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
    final nextZ = _nextZIndex();
    final updated = StrokeElement(
      id: element.id,
      z: nextZ,
      color: element.color,
      strokeWidth: element.strokeWidth,
      opacity: element.opacity,
      brushType: element.brushType,
      points: newPoints,
    );
    final next =
        state.elements.map((e) => e.id == element.id ? updated : e).toList();
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
  }

  Future<void> _onUpdateSelectedStrokeColor(
    CanvasUpdateSelectedStrokeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(element.id) ?? element.toMap())
      ..['color'] = event.color;
    emit(state.copyWith(selectedStrokeColor: event.color));
    await _updateStroke(element.id, data, emit);
  }

  Future<void> _onUpdateSelectedStrokeWidth(
    CanvasUpdateSelectedStrokeWidth event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(element.id) ?? element.toMap())
      ..['strokeWidth'] = event.strokeWidth;
    emit(state.copyWith(selectedStrokeWidth: event.strokeWidth));
    await _updateStroke(element.id, data, emit);
  }

  Future<void> _onUpdateSelectedStrokeOpacity(
    CanvasUpdateSelectedStrokeOpacity event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(element.id) ?? element.toMap())
      ..['opacity'] = event.opacity;
    emit(state.copyWith(selectedStrokeOpacity: event.opacity));
    await _updateStroke(element.id, data, emit);
  }

  Future<void> _onUpdateSelectedStrokeBrushType(
    CanvasUpdateSelectedStrokeBrushType event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || !_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(element.id) ?? element.toMap())
      ..['brushType'] = event.brushType;
    emit(state.copyWith(selectedStrokeBrushType: event.brushType));
    await _updateStroke(element.id, data, emit);
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

  Offset _computeElementAnchor(
    CanvasElement element,
    String anchor, {
    Offset? overrideCenter,
  }) {
    Offset center = overrideCenter ?? Offset.zero;
    double w = 100.0;
    double h = 100.0;

    if (element is ShapeElement) {
      center = overrideCenter ?? element.center;
      w = element.size * 1.2;
      h = element.size * 1.2;
    } else if (element is StickyNoteElement) {
      center = overrideCenter ?? element.center;
      w = element.width;
      h = element.height;
    } else if (element is ImageElement) {
      center = overrideCenter ?? element.center;
      w = element.width;
      h = element.height;
    } else if (element is TextElement) {
      center = overrideCenter ?? element.center;
      w = 120.0;
      h = 40.0;
    }

    switch (anchor) {
      case 'top':
        return Offset(center.dx, center.dy - h / 2);
      case 'bottom':
        return Offset(center.dx, center.dy + h / 2);
      case 'left':
        return Offset(center.dx - w / 2, center.dy);
      case 'right':
        return Offset(center.dx + w / 2, center.dy);
      case 'center':
      default:
        return center;
    }
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
    if (existing is! ShapeElement &&
        existing is! StickyNoteElement &&
        existing is! ImageElement) {
      return;
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
    final currentRotation = existing is ShapeElement
        ? (existing.rotation % (math.pi * 2))
        : existing is StickyNoteElement
            ? existing.rotation
            : 0.0;
    final currentBorderRadius =
        existing is ShapeElement ? existing.borderRadius : 0.0;
    final currentColor = existing is ShapeElement
        ? existing.color.value
        : existing is StickyNoteElement
            ? existing.color.value
            : 0;
    final currentFilled = existing is ShapeElement ? existing.isFilled : true;
    final nextCx = (data['cx'] as num?)?.toDouble() ?? 0.0;
    final nextCy = (data['cy'] as num?)?.toDouble() ?? 0.0;
    final nextSize = (data['size'] as num?)?.toDouble() ??
        (existing is ShapeElement
            ? 64.0
            : existing is StickyNoteElement
                ? 160.0
                : (existing as ImageElement).width);
    final nextRotation =
        ((data['rotation'] as num?)?.toDouble() ?? 0.0) % (math.pi * 2);
    final nextBorderRadius = (data['borderRadius'] as num?)?.toDouble() ?? 0.0;
    final nextColor = (data['color'] as num?)?.toInt() ?? 0;
    final nextFilled = (data['isFilled'] as bool?) ?? false;
    final currentZ = existing.z;
    final nextZ = (data['z'] as num?)?.toInt() ?? currentZ;
    final unchanged = (nextCx - currentCx).abs() < 0.01 &&
        (nextCy - currentCy).abs() < 0.01 &&
        (nextSize - currentSize).abs() < 0.01 &&
        (nextRotation - currentRotation).abs() < 0.0001 &&
        (nextBorderRadius - currentBorderRadius).abs() < 0.01 &&
        nextColor == currentColor &&
        nextFilled == currentFilled &&
        nextZ == currentZ;
    if (unchanged) return;
    if (existing is StickyNoteElement) {
      data['width'] ??= nextSize;
      data['height'] ??= nextSize;
    }
    if (existing is ImageElement) {
      data['imageBase64'] ??= existing.imageBase64;
      data['width'] ??= (data['width'] as num?)?.toDouble() ??
          (data['size'] as num?)?.toDouble() ??
          existing.width;
      data['height'] ??= (data['height'] as num?)?.toDouble() ??
          (data['size'] as num?)?.toDouble() ??
          existing.height;
    }
    final fingerprint = _shapeFingerprint(shapeId, data);
    if (_lastShapePayloadFingerprint[shapeId] == fingerprint) return;
    _lastShapePayloadFingerprint[shapeId] = fingerprint;
    final next = state.elements
        .map((e) =>
            e.id == shapeId ? CanvasElement.fromMap(e.id, data) : e)
        .toList();
    next.sort((a, b) {
      if (a.z != b.z) return a.z.compareTo(b.z);
      return a.id.compareTo(b.id);
    });
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: _elementType(existing),
      objectId: shapeId,
      data: data,
      emit: emit,
    );

    // Maintain dynamic link topology for attached connectors (FR05-15)
    final updatedTarget = CanvasElement.fromMap(shapeId, data);
    for (final el in state.elements) {
      if (el is ConnectorElement &&
          (el.startElementId == shapeId || el.endElementId == shapeId)) {
        final newStart = el.startElementId == shapeId
            ? _computeElementAnchor(updatedTarget, el.startAnchor,
                overrideCenter: Offset(nextCx, nextCy))
            : el.startPoint;
        final newEnd = el.endElementId == shapeId
            ? _computeElementAnchor(updatedTarget, el.endAnchor,
                overrideCenter: Offset(nextCx, nextCy))
            : el.endPoint;
        final connectorData = Map<String, dynamic>.from(el.toMap())
          ..['sx'] = newStart.dx
          ..['sy'] = newStart.dy
          ..['ex'] = newEnd.dx
          ..['ey'] = newEnd.dy;
        await _saveCrdtOperation(
          action: 'update',
          type: 'connector',
          objectId: el.id,
          data: connectorData,
          emit: emit,
        );
      }
    }
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
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap());
    for (final entry in event.pendingData.entries) {
      if (entry.key == 'rotation') {
        final rotation = _toDoubleValue(entry.value);
        if (rotation == null) continue;
        data[entry.key] = _normalizeRotation(rotation);
      } else if (entry.key == 'size') {
        final size = _toDoubleValue(entry.value);
        if (size == null) continue;
        final clamped = size.clamp(24.0, 320.0);
        data[entry.key] = clamped;
        if (shape is StickyNoteElement) {
          final noteSize = clamped.clamp(40.0, 480.0);
          data['width'] = noteSize;
          data['height'] = noteSize;
        }
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
    if (shape == null || canvasService == null || _boardId.isEmpty) return;
    // Connectors carry endpoints, not a centre; moving one is committed on
    // drag end, so there is no cx/cy preview to publish here.
    if (shape is ConnectorElement) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
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
    if (shape == null || canvasService == null || _boardId.isEmpty) return;
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['size'] = event.size.clamp(24.0, 320.0);
    if (shape is ImageElement) {
      data.remove('imageBase64');
      data['width'] = event.size.clamp(80.0, 720.0);
      data['height'] = event.size.clamp(80.0, 720.0);
    } else if (shape is StickyNoteElement) {
      data['width'] = (event.width ?? event.size).clamp(40.0, 480.0);
      data['height'] = (event.height ?? event.size).clamp(40.0, 480.0);
    }
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
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
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
    emit(state.copyWith(
      elements: result.nextElements,
      selectedShapeId:
          selectedId != null && result.deletedElementIds.contains(selectedId)
              ? null
              : selectedId,
    ));
    await _publishEraserCursor(session, path.last);
  }

  Future<void> _publishEraserCursor(
    _EraserSession session,
    Offset position,
  ) {
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
    emit(state.copyWith(
      elements: nextElements,
      currentStroke: const [],
      selectedShapeId: selectedId != null && deletedIds.contains(selectedId)
          ? null
          : selectedId,
    ));
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
      adapter.upsertElement(
        stroke.id,
        <String, dynamic>{'type': 'stroke', ...stroke.toMap()},
        origin: 'local',
      );
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
      final strokePoints = element.points;
      if (strokePoints.isEmpty) {
        nextElements.add(element);
        continue;
      }
      // Cheap reject: only strokes near the eraser swath are re-split.
      if (!_strokeBounds(strokePoints, element.strokeWidth / 2)
          .overlaps(eraseBounds)) {
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
    // Kept for any legacy tray-toggle path: the archived-block feed is what
    // the history screen renders, and opening it must subscribe even if the
    // explicit history route request was missed.
    if (nextTray == 'history') {
      _ensureHistoryFeedSubscription();
    }
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
      emit(state.copyWith(error: 'Failed to revoke member access: ${AppErrorFormatter.cleanMessage(e)}'));
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
      emit(state.copyWith(error: 'Failed to update member role: ${AppErrorFormatter.cleanMessage(e)}'));
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
      final destination = file.path.contains('Download') ? 'Downloads' : 'device storage';
      final String successMsg;
      if (!event.shareAfterExport) {
        successMsg = 'Board saved locally to $destination as $ext!\n${file.path}';
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
      emit(state.copyWith(
        infoMessage: 'Edit access request sent to board owner.',
      ));
    } catch (e) {
      emit(state.copyWith(
        error: AppErrorFormatter.cleanMessage(
          e,
          fallback: 'Failed to request edit access.',
        ),
      ));
    }
  }

  void _onConsumeInfoMessage(
    CanvasConsumeInfoMessage event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(infoMessage: null));
  }

  // ──────────────────────────────────────────────
  // Board history (owner-only) + member undo (D2/D3/D15)
  // ──────────────────────────────────────────────

  String _historyMessage(Object error) {
    if (error is HistoryServiceException) {
      switch (error.code) {
        case 'forbidden':
          return 'Only the board owner can view board history.';
        case 'archive_unavailable':
        case 'persistence_unavailable':
          return 'Board history is temporarily unavailable. Please try again.';
        case 'plan_expired':
          return 'That revert expired. Please try again.';
        case 'socket_unavailable':
        case 'unauthenticated':
          return 'Could not reach the history service. Please retry.';
        default:
          return 'History request failed. Please try again.';
      }
    }
    return AppErrorFormatter.cleanMessage(
      error,
      fallback: 'History request failed. Please try again.',
    );
  }

  /// Owner-only: keeps the undo-request list live for the history screen.
  void _syncHistorySubscriptions() {
    final repo = _historyRepository;
    if (repo == null || _boardId.isEmpty || isClosed) return;
    if (_currentUserRole == Board.roleOwner) {
      _undoRequestsSub ??= repo.watchUndoRequests(_boardId).listen(
        (requests) {
          if (!isClosed) add(CanvasUndoRequestsUpdated(requests));
        },
        onError: (_) {},
      );
    } else {
      _undoRequestsSub?.cancel();
      _undoRequestsSub = null;
    }
  }

  /// Owner-only: subscribe to the archived-block feed. Idempotent so every
  /// history-screen entry point (ToolsTray button, role resolving late) can
  /// call it without stacking duplicate Firestore listeners.
  void _ensureHistoryFeedSubscription() {
    final repo = _historyRepository;
    if (repo == null || _currentUserRole != Board.roleOwner) return;
    if (_boardId.isEmpty || isClosed || _historyFeedSub != null) return;
    _historyFeedSub = repo.watchActivityFeed(_boardId).listen(
      (blocks) {
        if (!isClosed) add(CanvasHistoryFeedUpdated(blocks));
      },
      onError: (_) {},
    );
  }

  void _onHistoryFeedRequested(
    CanvasHistoryFeedRequested event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole != Board.roleOwner) return;
    _syncHistorySubscriptions();
    _ensureHistoryFeedSubscription();
  }

  void _onHistoryFeedUpdated(
    CanvasHistoryFeedUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole != Board.roleOwner) return;
    emit(state.copyWith(activityBlocks: event.blocks));
  }

  Future<void> _onHistoryPreviewRequested(
    CanvasHistoryPreviewRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can view board history.'));
      return;
    }
    // Remember where the owner launched the preview from so exiting returns
    // them to the same tray/timeline. Preserve the original anchor when
    // hopping between versions while already previewing.
    final returnTray = state.isViewingHistory
        ? state.historyPreviewReturnTray
        : state.activeTray;
    final returnUserUid = state.isViewingHistory
        ? state.historyPreviewReturnUserUid
        : state.selectedUserUid;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final preview = await service.previewVersion(_boardId, event.version);
      // Render through a TEMPORARY adapter — never the live one.
      final temp = await CanvasDocAdapterFactory.create();
      if (preview.stateUpdateBytes.isNotEmpty) {
        temp.applyUpdate(preview.stateUpdateBytes, origin: 'remote');
      }
      final previewElements =
          _rebuildElementsFromCrdtState(temp.materializeElements());
      if (isClosed) return;
      emit(state.copyWith(
        isViewingHistory: true,
        historyPreviewVersion: preview.version,
        historyPreviewElements: previewElements,
        historyHighlightElementIds: event.highlightElementIds,
        historyPreviewTitle: event.title,
        historyPreviewReturnTray: returnTray,
        historyPreviewReturnUserUid: returnUserUid,
        historyPreviewFocusBounds: event.focusBounds,
        historyPreviewRequestId: null,
        historyPreviewShowsDesired: false,
        isHistoryLoading: false,
        activeTray: null,
        selectedShapeId: null,
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  void _onHistoryPreviewExited(
    CanvasHistoryPreviewExited event,
    Emitter<CanvasState> emit,
  ) {
    final returnTray = state.historyPreviewReturnTray;
    final returnUserUid = state.historyPreviewReturnUserUid;
    _historyScrubAdapter = null;
    emit(state.copyWith(
      isViewingHistory: false,
      historyPreviewVersion: null,
      historyPreviewElements: const [],
      historyHighlightElementIds: const [],
      historyPreviewTitle: null,
      historyPreviewReturnTray: null,
      historyPreviewReturnUserUid: null,
      historyPreviewFocusBounds: null,
      historyPreviewRequestId: null,
      historyPreviewShowsDesired: false,
      historyScrub: null,
      historyScrubIndex: 0,
      historyPreviewCompare: false,
      historyPreviewOpVersions: const [],
      // Leaving the preview abandons an in-progress member request too.
      undoRequestDraft: null,
      activeTray: returnTray,
      selectedUserUid: returnUserUid,
    ));
  }

  Future<void> _onHistoryRequestEvidenceRequested(
    CanvasHistoryRequestEvidenceRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(
        error: 'Only the board owner can review undo requests.',
      ));
      return;
    }
    UndoRequest? request;
    for (final r in state.undoRequests) {
      if (r.requestId == event.requestId) {
        request = r;
        break;
      }
    }
    final returnTray = state.isViewingHistory
        ? state.historyPreviewReturnTray
        : state.activeTray;
    final returnUserUid = state.isViewingHistory
        ? state.historyPreviewReturnUserUid
        : state.selectedUserUid;
    final area = request?.area;
    final focusBounds = (area != null && area.isValid)
        ? Rect.fromLTWH(area.left, area.top, area.width, area.height)
        : null;
    final List<String>? highlightIds =
        (request != null && request.targetElementIds.isNotEmpty)
            ? request.targetElementIds
            : null;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      // New-style requests carry the member's chosen stop version: the
      // evidence is a scrub over everything that happened to the scope
      // since that requested state, starting ON the requested state.
      final targetVersion = request?.targetVersion;
      final scopeIds = request?.targetElementIds ?? const <String>[];
      if (request != null && targetVersion != null && scopeIds.isNotEmpty) {
        final timeline = await service.getUserTimeline(
          _boardId,
          request.requesterUid,
          elementIds: scopeIds,
          afterVersion: targetVersion,
        );
        if (isClosed) return;
        if (timeline.ops.isNotEmpty && timeline.steps.isNotEmpty) {
          // Virtual first stop: the requested state itself (the base, with
          // an empty delta). The slider then walks the window between what
          // the member asked for and the current board.
          final requestedStop = BoardOperation(
            version: targetVersion,
            summary: 'Requested state (v$targetVersion)',
          );
          final scrub = HistoryScrub(
            stops: [requestedStop, ...timeline.ops],
            baseStateBytes: timeline.baseStateBytes,
            stepDeltas: [
              Uint8List(0),
              ...timeline.steps.map((step) => step.deltaBytes),
            ],
            targetUid: request.requesterUid,
            elementIds: scopeIds,
            hasMore: timeline.hasMore,
            nextBeforeVersion: timeline.nextBeforeVersion,
          );
          await _enterScrub(
            scrub,
            emit: emit,
            returnTray: returnTray,
            returnUserUid: returnUserUid,
            title: 'Undo request from ${request.requesterName}',
            startIndex: 0,
            requestId: event.requestId,
            focusBounds: focusBounds,
            highlightElementIds: highlightIds ?? const <String>[],
          );
          return;
        }
      }
      // Legacy requests (no targetVersion) or an empty window: build the
      // desired board directly from the plan instead of emitting
      // activeRevertPlan, which would auto-open the review sheet on top of
      // the evidence preview.
      final plan = await service.planRevert(
        _boardId,
        mode: 'user',
        requestId: event.requestId,
      );
      if (isClosed) return;
      final desiredElements = _buildDesiredElements(plan.items);
      emit(state.copyWith(
        isViewingHistory: true,
        historyPreviewVersion: null,
        historyPreviewElements: desiredElements,
        historyHighlightElementIds: highlightIds ??
            plan.items.map((i) => i.elementId).toList(growable: false),
        historyPreviewTitle: request != null
            ? 'Undo request from ${request.requesterName}'
            : 'Undo request evidence',
        historyPreviewReturnTray: returnTray,
        historyPreviewReturnUserUid: returnUserUid,
        historyPreviewFocusBounds: focusBounds,
        historyPreviewRequestId: event.requestId,
        historyPreviewShowsDesired: true,
        isHistoryLoading: false,
        activeRevertPlan: null,
        activeTray: null,
        selectedShapeId: null,
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  void _onHistoryEvidenceViewToggled(
    CanvasHistoryEvidenceViewToggled event,
    Emitter<CanvasState> emit,
  ) {
    // The past/current toggle is shared by undo-request evidence and the
    // per-log compare screen (historyPreviewCompare).
    if (!state.isViewingHistory) return;
    if (state.historyPreviewRequestId == null &&
        !state.historyPreviewCompare) {
      return;
    }
    emit(state.copyWith(historyPreviewShowsDesired: event.showDesired));
  }

  void _onToggleUndoRequestAreaSelection(
    CanvasToggleUndoRequestAreaSelection event,
    Emitter<CanvasState> emit,
  ) {
    final enable = event.enable ?? !state.isSelectingUndoRequestArea;
    if (enable && state.isViewingHistory) return;
    emit(state.copyWith(
      isSelectingUndoRequestArea: enable,
      activeTray: null,
      selectedShapeId: null,
    ));
  }

  // ──────────────────────────────────────────────
  // Member undo request (D5): desired-state flow
  // ──────────────────────────────────────────────

  void _onUndoRequestDraftStarted(
    CanvasUndoRequestDraftStarted event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(
      undoRequestDraft: UndoRequestDraft(
        elementIds: List<String>.unmodifiable(event.preselectedIds),
        area: event.area,
      ),
    ));
  }

  void _onUndoRequestDraftElementToggled(
    CanvasUndoRequestDraftElementToggled event,
    Emitter<CanvasState> emit,
  ) {
    final draft = state.undoRequestDraft;
    if (draft == null) return;
    emit(state.copyWith(
      undoRequestDraft: draft.withToggledElement(event.elementId),
    ));
  }

  void _onUndoRequestDraftAreaSet(
    CanvasUndoRequestDraftAreaSet event,
    Emitter<CanvasState> emit,
  ) {
    final draft = state.undoRequestDraft ?? const UndoRequestDraft();
    emit(state.copyWith(
      undoRequestDraft: draft.withArea(event.area, event.elementIds),
    ));
  }

  void _onUndoRequestDraftCleared(
    CanvasUndoRequestDraftCleared event,
    Emitter<CanvasState> emit,
  ) {
    if (state.undoRequestDraft == null) return;
    emit(state.copyWith(undoRequestDraft: null));
  }

  /// Loads the member's OWN timeline scoped to the draft's elements and opens
  /// the request scrub: stop 0 is the virtual "before these changes" state,
  /// the slider then walks through what they did in the scope.
  Future<void> _onUndoRequestPreviewRequested(
    CanvasUndoRequestPreviewRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    final draft = state.undoRequestDraft;
    if (service == null || draft == null) return;
    final scopeIds = draft.elementIds;
    if (scopeIds.isEmpty) {
      emit(state.copyWith(error: 'Select at least one element first.'));
      return;
    }
    final returnTray = state.activeTray;
    final returnUserUid = state.selectedUserUid;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final timeline = await service.getUserTimeline(
        _boardId,
        state.currentUserId,
        elementIds: scopeIds,
      );
      if (isClosed) return;
      if (timeline.ops.isEmpty || timeline.steps.isEmpty) {
        emit(state.copyWith(
          isHistoryLoading: false,
          error: 'No changes of yours are recorded in that scope yet.',
        ));
        return;
      }
      // Virtual first stop: the state before the page's first scoped op.
      // Picking it asks the owner to undo ALL the member's in-scope changes
      // on the page; picking any later stop asks for that moment instead.
      final beforeStop = BoardOperation(
        version: timeline.baseVersion,
        summary: 'Before these changes (v${timeline.baseVersion})',
      );
      final scrub = HistoryScrub(
        stops: [beforeStop, ...timeline.ops],
        baseStateBytes: timeline.baseStateBytes,
        stepDeltas: [
          Uint8List(0),
          ...timeline.steps.map((step) => step.deltaBytes),
        ],
        targetUid: state.currentUserId,
        elementIds: scopeIds,
        hasMore: timeline.hasMore,
        nextBeforeVersion: timeline.nextBeforeVersion,
      );
      final area = draft.area;
      await _enterScrub(
        scrub,
        emit: emit,
        returnTray: returnTray,
        returnUserUid: returnUserUid,
        title: 'Your undo request',
        startIndex: 0,
        focusBounds: (area != null && area.isValid)
            ? Rect.fromLTWH(area.left, area.top, area.width, area.height)
            : null,
        highlightElementIds: scopeIds,
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  /// Submits the request with the member's chosen desired state: the version
  /// of the stop they settled on (never the newest — that would be a no-op).
  Future<void> _onUndoRequestSubmitRequested(
    CanvasUndoRequestSubmitRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    final draft = state.undoRequestDraft;
    final scrub = state.historyScrub;
    if (service == null || draft == null) return;
    final reason = event.reason.trim();
    if (reason.isEmpty) {
      emit(state.copyWith(error: 'A reason is required.'));
      return;
    }
    if (scrub == null || draft.elementIds.isEmpty) {
      emit(state.copyWith(error: 'Pick what the owner should restore first.'));
      return;
    }
    final index = state.historyScrubIndex.clamp(0, scrub.lastIndex);
    if (index >= scrub.lastIndex) {
      emit(state.copyWith(
        error:
            'Move the slider back to the state you want the owner to restore.',
      ));
      return;
    }
    final targetVersion = scrub.stops[index].version;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      await service.submitUndoRequest(
        boardId: _boardId,
        elementIds: draft.elementIds,
        reason: reason,
        targetVersion: targetVersion,
        area: draft.area,
      );
      if (isClosed) return;
      // The request is with the owner now: leave the preview, drop the draft.
      _historyScrubAdapter = null;
      emit(state.copyWith(
        isHistoryLoading: false,
        isViewingHistory: false,
        historyPreviewVersion: null,
        historyPreviewElements: const [],
        historyHighlightElementIds: const [],
        historyPreviewTitle: null,
        historyPreviewReturnTray: null,
        historyPreviewReturnUserUid: null,
        historyPreviewFocusBounds: null,
        historyPreviewRequestId: null,
        historyPreviewShowsDesired: false,
        historyScrub: null,
        historyScrubIndex: 0,
        historyPreviewCompare: false,
        historyPreviewOpVersions: const [],
        activeTray: null,
        undoRequestDraft: null,
        infoMessage: 'Undo request sent to the board owner.',
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  // ──────────────────────────────────────────────
  // Owner: restore to a point between a request's state and now
  // ──────────────────────────────────────────────

  /// Plans the revert of the requester's in-scope ops after [afterVersion].
  /// The review sheet confirms per element, exactly like the other ops
  /// reverts (D4 conflicts default to keep).
  Future<void> _onHistoryRevertOpsAfterRequested(
    CanvasHistoryRevertOpsAfterRequested event,
    Emitter<CanvasState> emit,
  ) {
    return _planHistoryRevert(
      mode: 'ops',
      targetUid: event.targetUid,
      afterVersion: event.afterVersion,
      elementIds: event.elementIds,
      requestId: event.requestId,
      emit: emit,
    );
  }

  /// The full board as it would look after applying [items]: live elements with
  /// each plan item's desired (`after`) value upserted, or removed when null.
  List<CanvasElement> _buildDesiredElements(List<RevertPlanItem> items) {
    final maps = <String, Map<String, dynamic>>{
      for (final e in state.elements) e.id: e.toMap(),
    };
    for (final item in items) {
      final after = item.after;
      if (after == null) {
        maps.remove(item.elementId);
      } else {
        maps[item.elementId] = after;
      }
    }
    return _rebuildElementsFromCrdtState(maps);
  }

  Future<void> _planHistoryRevert({
    required String mode,
    required Emitter<CanvasState> emit,
    int? targetVersion,
    String? targetUid,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? elementIds,
    String? requestId,
    List<int>? opVersions,
    int? afterVersion,
  }) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can revert edits.'));
      return;
    }
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final plan = await service.planRevert(
        _boardId,
        mode: mode,
        targetVersion: targetVersion,
        targetUid: targetUid,
        fromTime: fromTime,
        toTime: toTime,
        elementIds: elementIds,
        requestId: requestId,
        opVersions: opVersions,
        afterVersion: afterVersion,
      );
      if (isClosed) return;
      if (plan.items.isEmpty) {
        emit(state.copyWith(
          isHistoryLoading: false,
          infoMessage: 'Nothing to revert — the board already matches.',
        ));
        return;
      }
      emit(state.copyWith(isHistoryLoading: false, activeRevertPlan: plan));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  Future<void> _onHistoryRestoreRequested(
    CanvasHistoryRestoreRequested event,
    Emitter<CanvasState> emit,
  ) {
    return _planHistoryRevert(
      mode: 'restore',
      targetVersion: event.version,
      emit: emit,
    );
  }

  Future<void> _onHistoryRevertUserRequested(
    CanvasHistoryRevertUserRequested event,
    Emitter<CanvasState> emit,
  ) {
    return _planHistoryRevert(
      mode: 'user',
      targetUid: event.targetUid,
      fromTime: event.fromTime,
      toTime: event.toTime,
      elementIds: event.elementIds,
      emit: emit,
    );
  }

  Future<void> _onHistoryUndoRequestReviewRequested(
    CanvasHistoryUndoRequestReviewRequested event,
    Emitter<CanvasState> emit,
  ) {
    return _planHistoryRevert(
      mode: 'user',
      requestId: event.requestId,
      emit: emit,
    );
  }

  Future<void> _onHistoryUserOpsRequested(
    CanvasHistoryUserOpsRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) return;
    emit(state.copyWith(
      isHistoryLoading: true,
      selectedUserUid: event.targetUid,
      error: null,
    ));
    try {
      final page = await service.getUserOps(
        _boardId,
        event.targetUid,
        fromTime: event.fromTime,
        toTime: event.toTime,
        beforeVersion: event.beforeVersion,
      );
      if (isClosed) return;
      add(
        CanvasHistoryUserOpsUpdated(
          targetUid: event.targetUid,
          ops: page.ops,
          hasMore: page.hasMore,
          nextBeforeVersion: page.nextBeforeVersion,
          append: event.beforeVersion != null,
        ),
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  void _onHistoryUserOpsUpdated(
    CanvasHistoryUserOpsUpdated event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(
      isHistoryLoading: false,
      selectedUserUid: event.targetUid,
      userOps: event.append ? [...state.userOps, ...event.ops] : event.ops,
      hasMoreUserOps: event.hasMore,
      userOpsNextBeforeVersion: event.nextBeforeVersion,
    ));
  }

  void _onHistoryUserTimelineExited(
    CanvasHistoryUserTimelineExited event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(
      selectedUserUid: null,
      userOps: const [],
      hasMoreUserOps: false,
      userOpsNextBeforeVersion: null,
    ));
  }

  // ──────────────────────────────────────────────
  // Scrub previews: version slider + per-user replay (§ version scrub)
  // ──────────────────────────────────────────────

  String _memberLabel(String uid) {
    for (final member in state.boardMembers) {
      if (member.uid == uid) return member.label;
    }
    return 'User';
  }

  /// Version scrub: fetch the block's ops + the board state just before the
  /// block starts, then replay them on a temporary adapter. The preview opens
  /// on the block's LAST state; the banner slider moves back op-by-op.
  Future<void> _onHistoryVersionScrubRequested(
    CanvasHistoryVersionScrubRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can view board history.'));
      return;
    }
    final block = event.block;
    final returnTray = state.isViewingHistory
        ? state.historyPreviewReturnTray
        : state.activeTray;
    final returnUserUid = state.isViewingHistory
        ? state.historyPreviewReturnUserUid
        : state.selectedUserUid;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final ops = (await service.getBlock(_boardId, block.blockId))
          .where((op) =>
              op.version >= block.fromVersion && op.version <= block.toVersion)
          .toList()
        ..sort((a, b) => a.version.compareTo(b.version));
      if (ops.isEmpty) {
        throw const HistoryServiceException(
          'block_empty',
          'This version has no logged operations to scrub.',
        );
      }
      // Base = the board right before the block's first op. Each block op is
      // itself the delta to the previous state, so the ops replay the block.
      final base = await service.previewVersion(
        _boardId,
        math.max(0, block.fromVersion - 1),
      );
      final scrub = HistoryScrub(
        stops: ops,
        baseStateBytes: base.stateUpdateBytes,
        stepDeltas: [for (final op in ops) base64Decode(op.payloadBase64)],
      );
      if (isClosed) return;
      await _enterScrub(
        scrub,
        returnTray: returnTray,
        returnUserUid: returnUserUid,
        title: 'Scrubbing v${block.fromVersion}–v${block.toVersion}',
        emit: emit,
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  /// User scrub: the user's logged ops replayed as true board states. Opens
  /// on their latest change; the slider moves back through their work.
  Future<void> _onHistoryUserScrubRequested(
    CanvasHistoryUserScrubRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can view board history.'));
      return;
    }
    final returnTray = state.isViewingHistory
        ? state.historyPreviewReturnTray
        : state.activeTray;
    final returnUserUid = state.isViewingHistory
        ? state.historyPreviewReturnUserUid
        : state.selectedUserUid;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final timeline = await service.getUserTimeline(_boardId, event.targetUid);
      if (isClosed) return;
      if (timeline.ops.isEmpty || timeline.steps.isEmpty) {
        emit(state.copyWith(
          isHistoryLoading: false,
          error: 'No replayable changes recorded for this user yet.',
        ));
        return;
      }
      final scrub = HistoryScrub(
        stops: timeline.ops,
        baseStateBytes: timeline.baseStateBytes,
        stepDeltas: [for (final step in timeline.steps) step.deltaBytes],
        targetUid: event.targetUid,
        hasMore: timeline.hasMore,
        nextBeforeVersion: timeline.nextBeforeVersion,
      );
      final name = _memberLabel(event.targetUid);
      await _enterScrub(
        scrub,
        returnTray: returnTray,
        returnUserUid: returnUserUid,
        title: "Replaying $name's changes",
        emit: emit,
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  /// Renders a scrub session on a fresh temporary adapter. [startIndex]
  /// defaults to the LAST stop (the newest state in range — the slider then
  /// moves back from there); request/evidence scrubs open at 0 (the base
  /// state: "before your changes" / "the requested state").
  Future<void> _enterScrub(
    HistoryScrub scrub, {
    required String? returnTray,
    required String? returnUserUid,
    required Emitter<CanvasState> emit,
    String? title,
    int? startIndex,
    String? requestId,
    Rect? focusBounds,
    List<String> highlightElementIds = const [],
  }) async {
    final adapter = await CanvasDocAdapterFactory.create();
    if (scrub.baseStateBytes.isNotEmpty) {
      adapter.applyUpdate(scrub.baseStateBytes, origin: 'remote');
    }
    final index = (startIndex ?? scrub.lastIndex).clamp(0, scrub.lastIndex);
    for (var i = 0; i <= index; i++) {
      final delta = scrub.stepDeltas[i];
      if (delta.isNotEmpty) adapter.applyUpdate(delta, origin: 'remote');
    }
    _historyScrubAdapter = adapter;
    final previewElements =
        _rebuildElementsFromCrdtState(adapter.materializeElements());
    if (isClosed) return;
    emit(state.copyWith(
      isViewingHistory: true,
      isHistoryLoading: false,
      historyScrub: scrub,
      historyScrubIndex: index,
      historyPreviewVersion: scrub.stops[index].version,
      historyPreviewElements: previewElements,
      // Highlights are set once here (never per step), so the focus key does
      // not change and the viewport never refits mid-scrub.
      historyHighlightElementIds: highlightElementIds,
      historyPreviewTitle: title,
      historyPreviewReturnTray: returnTray,
      historyPreviewReturnUserUid: returnUserUid,
      historyPreviewFocusBounds: focusBounds,
      historyPreviewRequestId: requestId,
      historyPreviewShowsDesired: false,
      historyPreviewCompare: false,
      historyPreviewOpVersions: const [],
      activeRevertPlan: null,
      activeTray: null,
      selectedShapeId: null,
    ));
  }

  /// Slider moved: forward steps apply the committed deltas in order; moving
  /// back rebuilds from the base because CRDT deltas cannot be inverted.
  Future<void> _onHistoryScrubMoved(
    CanvasHistoryScrubMoved event,
    Emitter<CanvasState> emit,
  ) async {
    final scrub = state.historyScrub;
    final adapter = _historyScrubAdapter;
    if (scrub == null || adapter == null) return;
    final index = event.index.clamp(0, scrub.lastIndex);
    if (index == state.historyScrubIndex) return;
    if (index > state.historyScrubIndex) {
      for (var i = state.historyScrubIndex + 1; i <= index; i++) {
        final delta = scrub.stepDeltas[i];
        if (delta.isNotEmpty) adapter.applyUpdate(delta, origin: 'remote');
      }
    } else {
      final rebuilt = await CanvasDocAdapterFactory.create();
      if (scrub.baseStateBytes.isNotEmpty) {
        rebuilt.applyUpdate(scrub.baseStateBytes, origin: 'remote');
      }
      for (var i = 0; i <= index; i++) {
        final delta = scrub.stepDeltas[i];
        if (delta.isNotEmpty) rebuilt.applyUpdate(delta, origin: 'remote');
      }
      _historyScrubAdapter = rebuilt;
    }
    final active = _historyScrubAdapter;
    if (active == null || isClosed) return;
    final previewElements =
        _rebuildElementsFromCrdtState(active.materializeElements());
    emit(state.copyWith(
      historyScrubIndex: index,
      historyPreviewElements: previewElements,
      // historyPreviewVersion stays at the anchor so the viewport never
      // refits mid-scrub; the banner reads the stop from historyScrub.
    ));
  }

  /// Prepend the user's older ops to the active scrub. The adapter already
  /// holds the board at the previously selected stop — the same op, now at a
  /// shifted index — so no replay is needed, only the merged session.
  Future<void> _onHistoryScrubLoadOlderRequested(
    CanvasHistoryScrubLoadOlderRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    final scrub = state.historyScrub;
    if (service == null || scrub == null || scrub.targetUid == null) return;
    if (!scrub.hasMore || scrub.nextBeforeVersion == null) return;
    if (state.isHistoryLoading) return;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final timeline = await service.getUserTimeline(
        _boardId,
        scrub.targetUid!,
        beforeVersion: scrub.nextBeforeVersion,
        // Request scrubs stay scoped to the picked elements; an evidence
        // scrub is additionally anchored at the requested state, so its
        // virtual stop 0 stays the window's floor.
        elementIds: scrub.elementIds.isEmpty ? null : scrub.elementIds,
        afterVersion: state.historyPreviewRequestId != null
            ? scrub.stops.first.version
            : null,
      );
      if (isClosed) return;
      if (timeline.ops.isEmpty || timeline.steps.isEmpty) {
        emit(state.copyWith(isHistoryLoading: false));
        return;
      }
      final merged = HistoryScrub(
        stops: [...timeline.ops, ...scrub.stops],
        baseStateBytes: timeline.baseStateBytes,
        stepDeltas: [
          ...timeline.steps.map((step) => step.deltaBytes),
          ...scrub.stepDeltas,
        ],
        targetUid: scrub.targetUid,
        elementIds: scrub.elementIds,
        hasMore: timeline.hasMore,
        nextBeforeVersion: timeline.nextBeforeVersion,
      );
      emit(state.copyWith(
        isHistoryLoading: false,
        historyScrub: merged,
        historyScrubIndex:
            (state.historyScrubIndex + timeline.ops.length)
                .clamp(0, merged.lastIndex),
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  /// Log compare: the board as it was when the tapped op was made (highlighted),
  /// toggled against the live board from the banner. First view = the past.
  Future<void> _onHistoryOpCompareRequested(
    CanvasHistoryOpCompareRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can view board history.'));
      return;
    }
    final op = event.operation;
    final highlight = <String>{
      for (final change in op.changes)
        if (change.elementId.isNotEmpty) change.elementId,
      if (op.elementId != null && op.elementId!.isNotEmpty) op.elementId!,
    }.toList(growable: false);
    final returnTray = state.isViewingHistory
        ? state.historyPreviewReturnTray
        : state.activeTray;
    final returnUserUid = state.isViewingHistory
        ? state.historyPreviewReturnUserUid
        : state.selectedUserUid;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final preview = await service.previewVersion(_boardId, op.version);
      final temp = await CanvasDocAdapterFactory.create();
      if (preview.stateUpdateBytes.isNotEmpty) {
        temp.applyUpdate(preview.stateUpdateBytes, origin: 'remote');
      }
      final previewElements =
          _rebuildElementsFromCrdtState(temp.materializeElements());
      _historyScrubAdapter = null;
      if (isClosed) return;
      emit(state.copyWith(
        isViewingHistory: true,
        isHistoryLoading: false,
        historyScrub: null,
        historyScrubIndex: 0,
        historyPreviewVersion: preview.version,
        historyPreviewElements: previewElements,
        historyHighlightElementIds: highlight,
        historyPreviewTitle: op.headline,
        historyPreviewReturnTray: returnTray,
        historyPreviewReturnUserUid: returnUserUid,
        historyPreviewFocusBounds: null,
        historyPreviewRequestId: null,
        // Start on the state when the change was made; the banner toggles to
        // the live board.
        historyPreviewShowsDesired: true,
        historyPreviewCompare: true,
        historyPreviewOpVersions: [op.version],
        activeRevertPlan: null,
        activeTray: null,
        selectedShapeId: null,
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  /// Plan the undo of specific logged ops (per-op revert, a multi-selection,
  /// or a scrub replay's tail). The review sheet confirms per element.
  Future<void> _onHistoryRevertOpsRequested(
    CanvasHistoryRevertOpsRequested event,
    Emitter<CanvasState> emit,
  ) {
    return _planHistoryRevert(
      mode: 'ops',
      opVersions: event.opVersions,
      emit: emit,
    );
  }

  void _onHistoryPlanLoaded(
    CanvasHistoryPlanLoaded event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(activeRevertPlan: event.plan, isHistoryLoading: false));
  }

  void _onHistoryPlanFailed(
    CanvasHistoryPlanFailed event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(isHistoryLoading: false, error: event.message));
  }

  void _onHistoryPlanDismissed(
    CanvasHistoryPlanDismissed event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(activeRevertPlan: null));
  }

  Future<void> _onHistoryApplyRevert(
    CanvasHistoryApplyRevert event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    // D3: reverting board history is the owner's right; the server rejects it
    // too, but a member should never reach the request in the first place.
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(
        error: 'Only the board owner can revert board history.',
      ));
      return;
    }
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final result = await service.applyRevert(
        _boardId,
        planId: event.planId,
        decisions: event.decisions,
        requestId: event.requestId,
      );
      // The canvas itself converges through the normal crdt_update broadcast.
      if (event.requestId != null) {
        try {
          await service.resolveUndoRequest(
            boardId: _boardId,
            requestId: event.requestId!,
            status: 'approved',
            appliedVersion: result.appliedVersion,
          );
        } catch (_) {}
      }
      // Our own revert is a new op the local stack never saw; drop the stack
      // entries it replaced so Ctrl+Z cannot re-apply them.
      _crdtAdapter?.pruneReverted(result.reverted.toSet());
      _dropCommitRecords(result.reverted);
      if (isClosed) return;
      final message = result.skipped.isEmpty
          ? 'Reverted ${result.reverted.length} change(s).'
          : 'Reverted ${result.reverted.length}; kept ${result.skipped.length} change(s) others modified.';
      final wasPreviewing = state.isViewingHistory;
      final returnTray = state.historyPreviewReturnTray;
      final returnUserUid = state.historyPreviewReturnUserUid;
      _historyScrubAdapter = null;
      emit(state.copyWith(
        isHistoryLoading: false,
        activeRevertPlan: null,
        infoMessage: message,
        isViewingHistory: false,
        historyPreviewVersion: null,
        historyPreviewElements: const [],
        historyHighlightElementIds: const [],
        historyPreviewTitle: null,
        historyPreviewReturnTray: null,
        historyPreviewReturnUserUid: null,
        historyPreviewFocusBounds: null,
        historyPreviewRequestId: null,
        historyPreviewShowsDesired: false,
        historyScrub: null,
        historyScrubIndex: 0,
        historyPreviewCompare: false,
        historyPreviewOpVersions: const [],
        activeTray: wasPreviewing ? returnTray : state.activeTray,
        selectedUserUid: wasPreviewing ? returnUserUid : state.selectedUserUid,
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isHistoryLoading: false, error: _historyMessage(e)));
      }
    }
  }

  Future<void> _onHistoryUndoOwn(
    CanvasHistoryUndoOwn event,
    Emitter<CanvasState> emit,
  ) async {
    await _undoOwnViaLog(emit);
  }

  /// D2: cross-device fallback for a member's own ≤15-minute edits.
  Future<void> _undoOwnViaLog(Emitter<CanvasState> emit) async {
    final service = _historyService;
    // Server-side undo only needs the history socket, not canvas sync: a device
    // that has not finished its CRDT handshake can still undo its own edits.
    if (service == null || _boardId.isEmpty) return;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final result = await service.undoOwn(_boardId);
      if (isClosed) return;
      if (result.reverted.isEmpty) {
        if (result.conflicts.isNotEmpty) {
          // Every in-window edit was later changed by someone else. Show the
          // conflict flow instead of a dead-end "nothing to undo" error
          // (§7.2): members can send the owner an undo request.
          emit(state.copyWith(
            isHistoryLoading: false,
            undoConflict: CanvasUndoConflict(
              elementIds: result.conflicts.map((c) => c.elementId).toList(),
            ),
          ));
          return;
        }
        emit(state.copyWith(
          isHistoryLoading: false,
          error:
              'No edits to undo from the last 15 minutes. Older edits can only be reverted by the board owner.',
        ));
        return;
      }
      // The server already reverted these elements on our behalf, so drop the
      // matching local stack entries — otherwise a later Ctrl+Z would undo the
      // same edits a second time (D14 semantics, applied to our own ops).
      _crdtAdapter?.pruneReverted(result.reverted.toSet());
      _dropCommitRecords(result.reverted);
      final message = result.skipped.isEmpty
          ? 'Undid ${result.reverted.length} recent edit(s).'
          : 'Undid ${result.reverted.length}; ${result.skipped.length} could not be undone because others modified them.';
      emit(state.copyWith(isHistoryLoading: false, infoMessage: message));
    } on HistoryServiceException catch (e) {
      if (isClosed) return;
      final message = (e.code == 'nothing_to_undo' || e.code == 'window_expired')
          ? 'No edits to undo from the last 15 minutes. Older edits can only be reverted by the board owner.'
          : _historyMessage(e);
      emit(state.copyWith(isHistoryLoading: false, error: message));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(isHistoryLoading: false));
    }
  }

  void _onUndoConflictDismissed(
    CanvasUndoConflictDismissed event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(undoConflict: null));
  }

  void _onUndoRequestsUpdated(
    CanvasUndoRequestsUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole != Board.roleOwner) return;
    emit(state.copyWith(undoRequests: event.requests));
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
    if (state.isViewingHistory) {
      if (clearStroke && state.currentStroke.isNotEmpty) {
        emit(state.copyWith(currentStroke: const []));
      }
      emit(state.copyWith(
        error: 'You are viewing history. Exit preview to edit the board.',
      ));
      return false;
    }
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
      _commentsSub = commentsService
          .watchComments(boardId)
          .listen(
            (comments) {
              if (!isClosed) add(CanvasCommentsUpdated(comments));
            },
            onError: (_) {},
          );
    }

    final chatService = _boardChatService;
    if (chatService != null) {
      chatService.connect(boardId);
      _chatSub = chatService
          .watchChatMessages(boardId)
          .listen(
            (msg) {
              if (!isClosed) add(CanvasChatMessageReceived(msg));
            },
            onError: (_) {},
          );
      chatService.getChatHistory(boardId).then((history) {
        if (!isClosed && history.isNotEmpty) {
          add(CanvasChatMessagesUpdated(history));
        }
      }).catchError((_) {});
    }

    final voiceService = _voiceService;
    if (voiceService != null) {
      _voiceParticipantsSub = voiceService
          .watchParticipants(boardId)
          .listen(
            (participants) {
              if (!isClosed) add(CanvasVoiceParticipantsUpdated(participants));
            },
            onError: (_) {},
          );
      _voiceCallStatusSub = voiceService
          .watchIsInCall()
          .listen(
            (isInCall) {
              if (!isClosed) add(CanvasVoiceCallStatusChanged(isInCall));
            },
            onError: (_) {},
          );
      _voiceMuteStatusSub = voiceService
          .watchIsMuted()
          .listen(
            (isMuted) {
              if (!isClosed) add(CanvasVoiceMuteStatusChanged(isMuted));
            },
            onError: (_) {},
          );
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
    final updated = List<BoardChatMessage>.from(state.chatMessages)..add(event.message);
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
    emit(state.copyWith(
      isChatDrawerOpen: nextOpen,
      isCommentsTrayOpen: nextOpen ? false : state.isCommentsTrayOpen,
    ));
  }

  void _onCanvasToggleCommentsTray(
    CanvasToggleCommentsTray event,
    Emitter<CanvasState> emit,
  ) {
    final nextOpen = !state.isCommentsTrayOpen;
    emit(state.copyWith(
      isCommentsTrayOpen: nextOpen,
      isChatDrawerOpen: nextOpen ? false : state.isChatDrawerOpen,
    ));
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
      emit(state.copyWith(error: 'Failed to add comment: ${AppErrorFormatter.cleanMessage(e)}'));
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
      emit(state.copyWith(error: 'Failed to add reply: ${AppErrorFormatter.cleanMessage(e)}'));
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
      emit(state.copyWith(error: 'Failed to delete comment: ${AppErrorFormatter.cleanMessage(e)}'));
    }
  }

  Future<void> _onCanvasSendChatMessageRequested(
    CanvasSendChatMessageRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final chatService = _boardChatService;
    if (chatService == null || _boardId.isEmpty || event.text.trim().isEmpty) return;
    try {
      final msg = await chatService.sendMessage(
        boardId: _boardId,
        text: event.text.trim(),
      );
      if (!state.chatMessages.any((m) => m.id == msg.id)) {
        final updated = List<BoardChatMessage>.from(state.chatMessages)..add(msg);
        emit(state.copyWith(chatMessages: updated));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to send message: ${AppErrorFormatter.cleanMessage(e)}'));
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
      emit(state.copyWith(error: 'Failed to join voice call: ${AppErrorFormatter.cleanMessage(e)}'));
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
      emit(state.copyWith(error: 'Failed to leave voice call: ${AppErrorFormatter.cleanMessage(e)}'));
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
    await _historyFeedSub?.cancel();
    _historyFeedSub = null;
    await _undoRequestsSub?.cancel();
    _undoRequestsSub = null;
    await _previewUpdatesSub?.cancel();
    _previewUpdatesSub = null;
    await _canvasService?.stopCrdtRemoteSync(_boardId);
    return super.close();
  }
}
