import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crdt/canvas_crdt_adapter.dart';
import '../../../domain/models/canvas/crdt_update.dart';
import '../../../domain/models/board.dart';
import '../../../domain/models/canvas/canvas_board_settings.dart';
import '../../../domain/models/canvas/canvas_export_options.dart';
import '../../../domain/models/history/board_activity_block.dart';
import '../../../domain/models/history/board_operation.dart';
import '../../../domain/models/history/history_scrub.dart';
import '../../../domain/models/history/revert_plan.dart';
import '../../../domain/models/history/undo_request.dart';
import '../../../domain/models/history/user_timeline.dart';
import '../../../domain/services/history/board_history_service.dart';
import '../../../domain/services/board/board_service.dart';
import '../../../domain/services/canvas/board_chat_service.dart';
import '../../../domain/services/canvas/board_comments_service.dart';
import '../../../domain/services/canvas/board_export_service.dart';
import '../../../domain/services/canvas/canvas_service.dart';
import '../../../domain/services/voice/voice_service.dart';
import '../../../core/utils/app_error_formatter.dart';
import '../geometry/canvas_element_geometry.dart';
import '../geometry/canvas_selection_transform.dart';
import '../geometry/quick_shape.dart';
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
  final BoardHistoryService? _historyService;

  /// Temporary CRDT doc backing the active history scrub preview — never the
  /// live adapter. Rebuilt from the base state whenever the slider moves back
  /// (CRDT deltas are not invertible).
  CanvasDocAdapter? _historyScrubAdapter;

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
  StreamSubscription<bool>? _voiceSpeakerStatusSub;
  StreamSubscription<List<BoardActivityBlock>>? _historyFeedSub;
  StreamSubscription<List<UndoRequest>>? _undoRequestsSub;
  StreamSubscription<List<UndoRequest>>? _myUndoRequestsSub;
  List<BoardActivityBlock> _archivedBlocks = const [];
  BoardActivityBlock? _liveTailBlock;
  Timer? _liveTailDebounceTimer;
  CanvasDocAdapter? _crdtAdapter;
  List<CanvasElement>? _cachedCrdtElements;
  List<CanvasElement> _committedElements = const <CanvasElement>[];
  Future<void>? _crdtInitFuture;
  Timer? _boardUnavailableTimer;
  final Set<String> _appliedCrdtUpdateIds = <String>{};
  final Map<String, CanvasElement> _remotePreviewElements =
      <String, CanvasElement>{};
  final Set<String> _remotePreviewDeletedIds = <String>{};
  final Map<String, DateTime> _remotePreviewDeletedAt = <String, DateTime>{};
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
  DateTime? _lastArchivedWarningAt;
  DateTime? _lastPausedWarningAt;

  final BoardExportService _boardExportService;

  CanvasBloc({
    this._canvasService,
    this._boardService,
    BoardExportService? boardExportService,
    this._boardCommentsService,
    this._boardChatService,
    this._voiceService,
    CanvasDocAdapter? crdtAdapter,
    this._historyService,
    String currentUserId = '',
    this._boardId = '',
  }) : _boardExportService =
           boardExportService ?? const BoardExportServiceImpl(),
       _crdtAdapter = crdtAdapter,
       super(CanvasInitial(currentUserId: currentUserId)) {
    if (crdtAdapter != null) {
      for (final entry in crdtAdapter.materializeElements().entries) {
        _myCommittedPayload[entry.key] = _deepCopyPayload(entry.value);
      }
    }
    on<CanvasRenameBoardRequested>(_onCanvasRenameBoardRequested);
    on<CanvasBoardTitleUpdated>(_onCanvasBoardTitleUpdated);
    on<CanvasBoardUnavailable>(_onCanvasBoardUnavailable);
    on<CanvasInitializeCrdt>(_onInitializeCrdt);
    on<CanvasApplyRemoteUpdate>(_onApplyRemoteUpdate);
    on<CanvasApplyRemotePreview>(_onApplyRemotePreview);
    on<CanvasStartStroke>(_onStartStroke);
    on<CanvasAppendStroke>(_onAppendStroke);
    on<CanvasEndStroke>(_onEndStroke);
    on<CanvasCancelStroke>(_onCancelStroke);
    on<CanvasSetFingerDrawing>(_onSetFingerDrawing);
    on<CanvasSetQuickShapeEnabled>(_onSetQuickShapeEnabled);
    on<CanvasCommitQuickShape>(_onCommitQuickShape);
    on<CanvasAddShape>(_onAddShape);
    on<CanvasAddAiText>(_onAddAiText);
    on<CanvasAddText>(_onAddText);
    on<CanvasUpdateText>(_onUpdateText);
    on<CanvasAddImageElement>(_onAddImageElement);
    on<CanvasAddAiImageElement>(_onAddAiImageElement);
    on<CanvasReplaceImageSource>(_onReplaceImageSource);
    on<CanvasPreviewImageElement>(_onPreviewImageElement);
    on<CanvasUpdateImageElement>(_onUpdateImageElement);
    on<CanvasUpdateImageStyle>(_onUpdateImageStyle);
    on<CanvasReplaceImageElement>(_onReplaceImageElement);
    on<CanvasAddStickyNote>(_onAddStickyNote);
    on<CanvasUpdateStickyNote>(_onUpdateStickyNote);
    on<CanvasConvertStickyNote>(_onConvertStickyNote);
    on<CanvasAddFrame>(_onAddFrame);
    on<CanvasUpdateFrame>(_onUpdateFrame);
    on<CanvasDeleteFrame>(_onDeleteFrame);
    on<CanvasCaptureElementsInFrame>(_onCaptureElementsInFrame);
    on<CanvasAddTable>(_onAddTable);
    on<CanvasUpdateTableCell>(_onUpdateTableCell);
    on<CanvasUpdateTableStyle>(_onUpdateTableStyle);
    on<CanvasSetBoardSettings>(_onSetBoardSettings);
    on<CanvasAddGuide>(_onAddGuide);
    on<CanvasMoveGuide>(_onMoveGuide);
    on<CanvasRemoveGuide>(_onRemoveGuide);
    on<CanvasImportElements>(_onImportElements);
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
    on<CanvasArrangeSelection>(_onArrangeSelection);
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
    on<CanvasUpdateLayerBlendMode>(_onUpdateLayerBlendMode);
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
    on<CanvasUpdateShapeFill>(_onUpdateShapeFill);
    on<CanvasUpdateSelectedShapeColor>(_onUpdateSelectedShapeColor);
    on<CanvasUpdateSelectedShapeStrokeColor>(
      _onUpdateSelectedShapeStrokeColor,
    );
    on<CanvasFlipSelectedShape>(_onFlipSelectedShape);
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
    on<CanvasFillStroke>(_onFillStroke);
    on<CanvasClearStrokeFill>(_onClearStrokeFill);
    on<CanvasUpdateSelectionStyle>(_onUpdateSelectionStyle);
    on<CanvasMoveSelectionToLayer>(_onMoveSelectionToLayer);
    on<CanvasRetrySync>(_onRetrySync);
    on<CanvasUpdateSelectedStrokeColor>(_onUpdateSelectedStrokeColor);
    on<CanvasUpdateSelectedStrokeWidth>(_onUpdateSelectedStrokeWidth);
    on<CanvasUpdateSelectedStrokeOpacity>(_onUpdateSelectedStrokeOpacity);
    on<CanvasUpdateSelectedStrokeBrushType>(_onUpdateSelectedStrokeBrushType);
    on<CanvasCommitSelectedStrokeEdits>(_onCommitSelectedStrokeEdits);
    on<CanvasSaveBoardPreviewRequested>(_onSaveBoardPreviewRequested);
    on<CanvasSetBoardPausedRequested>(_onSetBoardPausedRequested);
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
    on<CanvasVoiceSpeakerStatusChanged>(_onCanvasVoiceSpeakerStatusChanged);
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
    on<CanvasToggleVoiceSpeakerRequested>(_onCanvasToggleVoiceSpeakerRequested);
    on<CanvasVoiceSpeakingChanged>(_onCanvasVoiceSpeakingChanged);
    on<CanvasHistoryFeedRequested>(_onHistoryFeedRequested);
    on<CanvasHistoryLoadOlderVersionsRequested>(
      _onHistoryLoadOlderVersionsRequested,
    );
    on<CanvasHistoryFeedUpdated>(_onHistoryFeedUpdated);
    on<CanvasHistoryLiveTailUpdated>(_onHistoryLiveTailUpdated);
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
    on<CanvasToggleOwnerAreaHistorySelection>(
      _onToggleOwnerAreaHistorySelection,
    );
    on<CanvasHistoryAreaScrubRequested>(_onHistoryAreaScrubRequested);
    on<CanvasUndoRequestsUpdated>(_onUndoRequestsUpdated);
    on<CanvasMyUndoRequestsUpdated>(_onMyUndoRequestsUpdated);
    on<CanvasUndoConflictDismissed>(_onUndoConflictDismissed);
    on<CanvasUndoRequestDraftStarted>(_onUndoRequestDraftStarted);
    on<CanvasUndoRequestDraftScopeModeChanged>(
      _onUndoRequestDraftScopeModeChanged,
    );
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
    final wasOwner = _currentUserRole == Board.roleOwner;
    final wasArchived = state.isArchived;
    final wasPaused = state.isPaused;
    _currentUserRole = event.currentUserRole;
    _syncHistorySubscriptions();
    // The role can resolve AFTER the owner already opened the history screen
    // (the first feed request early-returns for non-owners and would never
    // be retried). Retry now that we know the role.
    if (!wasOwner && _currentUserRole == Board.roleOwner) {
      _ensureHistoryFeedSubscription();
      unawaited(_refreshLiveTail());
    }

    String? transitionInfo;
    if (!wasArchived && event.isArchived) {
      transitionInfo = _currentUserRole == Board.roleOwner
          ? 'This board is archived. Unarchive it from Settings to edit.'
          : 'This board was archived by the owner. Edits are disabled.';
    } else if (wasArchived && !event.isArchived) {
      transitionInfo = 'Board has been unarchived. Editing is enabled.';
    } else if (!wasPaused && event.isPaused) {
      transitionInfo = _currentUserRole == Board.roleOwner
          ? 'Board paused. No one can edit until you resume it.'
          : 'This board is paused by the owner. Edits are disabled until resumed.';
    } else if (wasPaused && !event.isPaused) {
      transitionInfo = 'Board resumed. Editing is enabled.';
    }

    final isLocked = event.isArchived || event.isPaused;
    emit(
      state.copyWith(
        boardTitle: event.title,
        currentUserRole: event.currentUserRole,
        isArchived: event.isArchived,
        isPaused: event.isPaused,
        currentStroke: isLocked ? const [] : null,
        infoMessage: transitionInfo,
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
    _liveTailDebounceTimer?.cancel();
    _liveTailDebounceTimer = null;
    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        syncStatus: _canSync ? CanvasSyncStatus.syncing : CanvasSyncStatus.idle,
        syncMessage: null,
      ),
    );
    try {
      if (isClosed) return;
      _startBoardMetadataListener();
      _startCommunicationListeners(event.boardId);
      if (_canSync) {
        await _ensureCrdtReady();
        if (isClosed) return;
        _startCrdtUpdatesListener();
        _startPreviewUpdatesListener();
        _refreshFromCrdtAdapter(emit);
      } else if (_crdtAdapter != null) {
        _refreshFromCrdtAdapter(emit);
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            error: null,
            syncStatus: _canSync
                ? CanvasSyncStatus.saved
                : CanvasSyncStatus.idle,
            syncMessage: null,
          ),
        );
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
            syncStatus: _canSync
                ? CanvasSyncStatus.offline
                : CanvasSyncStatus.idle,
            syncMessage: 'Could not reach the board service.',
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
            isArchived: board.isArchived,
            isPaused: board.isPaused,
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
    var appliedAny = false;

    for (final update in event.updates) {
      if (update.updateId.startsWith('__snapshot__')) {
        snapshotUpdate.add(update);
      } else {
        regularUpdates.add(update);
      }
    }

    // Apply snapshot FIRST (full state restore via CRDT hydration)
    for (final snapshot in snapshotUpdate) {
      if (_appliedCrdtUpdateIds.contains(snapshot.updateId)) continue;
      if (snapshot.payloadBase64.isEmpty) {
        _appliedCrdtUpdateIds.add(snapshot.updateId);
        continue;
      }
      try {
        final bytes = base64Decode(snapshot.payloadBase64);
        if (bytes.isEmpty) continue;
        adapter.applyUpdate(bytes, origin: 'remote');
        appliedAny = true;
        // A full-state hydration replaces the board, so the local stack is
        // meaningless afterwards (D14).
        adapter.clearLocalHistory();
        _appliedCrdtUpdateIds.add(snapshot.updateId);
        _myCommittedPayload.clear();
        _myRedoTarget.clear();
        _remotePreviewClearsBoard = false;
        _remotePreviewElements.clear();
        _remotePreviewDeletedIds.clear();
        _remotePreviewDeletedAt.clear();
        _remotePreviewReceivedAt.clear();
      } catch (_) {
        _appliedCrdtUpdateIds.add(snapshot.updateId);
      }
    }

    // Then apply remaining deltas in order
    for (final update in regularUpdates) {
      if (update.elementId != null &&
          _remotePreviewElements.containsKey(update.elementId)) {
        appliedAny = true;
        _forgetPreviews(update.elementId!);
      } else if (update.elementId != null) {
        _forgetPreviews(update.elementId!);
      }
      if (update.affectedElementIds != null) {
        for (final id in update.affectedElementIds!) {
          if (_remotePreviewElements.containsKey(id)) appliedAny = true;
          _forgetPreviews(id);
        }
      }
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
        appliedAny = true;
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
        if (update.affectedElementIds != null) {
          for (final id in update.affectedElementIds!) {
            _forgetPreviews(id);
          }
        }
        _appliedCrdtUpdateIds.add(update.updateId);
      } catch (_) {
        _appliedCrdtUpdateIds.add(update.updateId);
      }
    }
    if (_remotePreviewDeletedIds.isNotEmpty) {
      final materialized = adapter.materializeElements();
      for (final id in materialized.keys) {
        _forgetPreviews(id);
      }
      appliedAny = true;
    }
    if (!appliedAny) return;
    _refreshFromCrdtAdapter(emit);
    if (regularUpdates.isNotEmpty || snapshotUpdate.isNotEmpty) {
      _scheduleLiveTailRefresh();
    }
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
          _remotePreviewDeletedAt.clear();
          _remotePreviewReceivedAt.clear();
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
          _remotePreviewDeletedAt[elementId] = DateTime.now();
          _remotePreviewElements.remove(elementId);
          _remotePreviewReceivedAt.remove(elementId);
          continue;
        }
        _remotePreviewDeletedIds.remove(elementId);
        _remotePreviewDeletedAt.remove(elementId);
        if (type == 'image') {
          final incomingBase64 = decoded['imageBase64'] as String?;
          if (incomingBase64 == null || incomingBase64.isEmpty) {
            final existing =
                _remotePreviewElements[elementId] ??
                state.elements.where((e) => e.id == elementId).firstOrNull ??
                _cachedCrdtElements
                    ?.where((e) => e.id == elementId)
                    .firstOrNull;
            if (existing is ImageElement) {
              _carryAiImageFields(decoded, existing);
            }
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
          blendMode: activeLayer.blendMode,
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
      if (joinActiveLayer) {
        final layerPayload = <String, dynamic>{
          ...activeLayer.toMap(),
          'elementIds': [...activeLayer.elementIds, objectId],
        };
        _myCommittedPayload[activeLayer.id] = _deepCopyPayload(layerPayload);
        // Joining the active layer is part of the same transaction so undo
        // removes the element and its membership together.
        update = adapter.applyBatch([
          (id: objectId, payload: payload),
          (id: activeLayer.id, payload: layerPayload),
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
    // D13 hint: only a whole-board delete is a 'clear' (which forces a durable
    // pre-clear checkpoint server-side). The archive worker derives truth from
    // the CRDT diff, so this is never trusted for attribution.
    final actionHint = action == 'delete'
        ? (type == 'board' ? 'clear' : 'delete')
        : 'upsert';
    emit(
      state.copyWith(syncStatus: CanvasSyncStatus.syncing, syncMessage: null),
    );
    try {
      final publishedUpdateId = await _publishCrdtUpdate(
        update,
        elementId: elementId,
        action: actionHint,
      );
      if (publishedUpdateId != null) {
        _lastShapeUpdateId[objectId] = publishedUpdateId;
      }
      emit(
        state.copyWith(syncStatus: CanvasSyncStatus.saved, syncMessage: null),
      );
    } catch (_) {
      emit(
        state.copyWith(
          syncStatus: CanvasSyncStatus.offline,
          syncMessage:
              'Offline. Your changes are saved on this device and will sync when the connection returns.',
        ),
      );
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
      _forgetPreviews(write.objectId);
    }
    // Any new local transaction invalidates the undo manager's redo stack.
    if (state.infoMessageRedoable) {
      emit(state.copyWith(infoMessage: null, infoMessageRedoable: false));
    }
    if (!_canSync) return;
    await _ensureCrdtReady();
    final adapter = _crdtAdapter;
    if (adapter == null) return;

    final batchChanges = <({String id, Map<String, dynamic>? payload})>[];
    for (final write in writes) {
      if (write.action == 'delete') {
        _myCommittedPayload[write.objectId] = null;
        batchChanges.add((id: write.objectId, payload: null));
      } else {
        final payload = <String, dynamic>{'type': write.type, ...write.data};
        _myCommittedPayload[write.objectId] = _deepCopyPayload(payload);
        batchChanges.add((id: write.objectId, payload: payload));
      }
    }

    final update = adapter.applyBatch(batchChanges, origin: 'local');
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
    emit(
      state.copyWith(syncStatus: CanvasSyncStatus.syncing, syncMessage: null),
    );
    try {
      final updateId = await _publishCrdtUpdate(
        update,
        elementId: writes.length == 1 ? writes.single.objectId : null,
      );
      if (updateId != null) {
        for (final write in writes) {
          _lastShapeUpdateId[write.objectId] = updateId;
        }
      }
      emit(
        state.copyWith(syncStatus: CanvasSyncStatus.saved, syncMessage: null),
      );
    } catch (_) {
      emit(
        state.copyWith(
          syncStatus: CanvasSyncStatus.offline,
          syncMessage:
              'Offline. Your changes are saved on this device and will sync when the connection returns.',
        ),
      );
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
    _scheduleLiveTailRefresh();
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
      _committedElements = rebuilt;
    } else {
      rebuilt = _committedElements.isNotEmpty
          ? _committedElements
          : state.elements;
    }
    // A collaborator update can rebuild the board in the middle of an erase
    // gesture; re-apply the live erase so already-erased ink does not pop back.
    final withErase = _applyActiveEraserOverlay(rebuilt);
    emit(
      state.copyWith(
        elements: _composeElementsWithPreviews(withErase),
        boardSettings: _boardSettings,
      ),
    );
  }

  List<CanvasElement> _composeElementsWithPreviews(
    List<CanvasElement> committedElements,
  ) {
    if (_remotePreviewClearsBoard) return const <CanvasElement>[];
    _pruneExpiredPreviews();
    if (_remotePreviewElements.isEmpty && _remotePreviewDeletedIds.isEmpty) {
      return List<CanvasElement>.unmodifiable(committedElements);
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
    return List<CanvasElement>.unmodifiable(composed);
  }

  void _pruneExpiredPreviews() {
    final now = DateTime.now();
    if (_remotePreviewElements.isNotEmpty) {
      _remotePreviewElements.removeWhere((id, _) {
        final receivedAt = _remotePreviewReceivedAt[id];
        final expired = receivedAt != null &&
            now.difference(receivedAt) > _remotePreviewTtl;
        if (expired) _remotePreviewReceivedAt.remove(id);
        return expired;
      });
    }
    if (_remotePreviewDeletedIds.isNotEmpty) {
      _remotePreviewDeletedIds.removeWhere((id) {
        final deletedAt = _remotePreviewDeletedAt[id];
        final expired = deletedAt == null ||
            now.difference(deletedAt) > _remotePreviewTtl;
        if (expired) _remotePreviewDeletedAt.remove(id);
        return expired;
      });
    }
  }

  /// Drop every preview overlay for [elementId]. Called as soon as this device
  /// commits its own edit, so a collaborator's in-flight preview can never keep
  /// showing the pre-edit version to the person who just changed it.
  void _forgetPreviews(String elementId) {
    _remotePreviewElements.remove(elementId);
    _remotePreviewDeletedIds.remove(elementId);
    _remotePreviewReceivedAt.remove(elementId);
    _remotePreviewDeletedAt.remove(elementId);
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
      final payload = adapter.materializeElement(elementId);
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
    await _publishSelectedShapePreviewLazy(elementId, () => data);
  }

  Future<void> _publishSelectedShapePreviewLazy(
    String elementId,
    Map<String, dynamic> Function() dataBuilder,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    final preview = _pendingPreviewPublishes.putIfAbsent(
      elementId,
      _QueuedPreviewPublish.new,
    );
    preview.previewId = _uuid.v4();
    preview.elementId = elementId;
    preview.payloadBuilder = dataBuilder;
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
    final builder = preview.payloadBuilder;
    if (builder != null) {
      preview.payload = Uint8List.fromList(utf8.encode(jsonEncode(builder())));
      preview.payloadBuilder = null;
    }
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
      // A single malformed or previously-serialized element must not blank
      // the entire board. Skip it and keep every readable sibling.
      try {
        final type = payload['type'] as String?;
        if (type == CanvasBoardSettings.crdtType) {
          // Board settings are not rendered elements; keep them out of the
          // element list and merge them into the state on refresh.
          _boardSettings = CanvasBoardSettings.fromMap(payload);
          continue;
        }
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
              frameId: payload['frameId'] as String?,
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
              fillColor: payload['fillColor'] == null
                  ? null
                  : Color((payload['fillColor'] as num).toInt()),
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
          final legacyFilled = _parseBool(payload['isFilled']);
          final rawFillMode = payload['fillMode'] as String?;
          final fillMode =
              rawFillMode != null &&
                  const {
                    'none',
                    'solid',
                    'linear',
                    'radial',
                  }.contains(rawFillMode)
              ? rawFillMode
              : (legacyFilled ? 'solid' : 'none');
          rebuilt.add(
            ShapeElement(
              id: id,
              z: z,
              hidden: _parseBool(payload['hidden']),
              locked: _parseBool(payload['locked']),
              frameId: payload['frameId'] as String?,
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
              strokeColor: payload['strokeColor'] == null
                  ? null
                  : Color((payload['strokeColor'] as num).toInt()),
              strokeWidth: (payload['strokeWidth'] as num?)?.toDouble() ?? 3.0,
              strokeOpacity:
                  (payload['strokeOpacity'] as num?)?.toDouble() ?? 1.0,
              dashPattern: (payload['dashPattern'] as List?)
                  ?.map((e) => (e as num).toDouble())
                  .toList(),
              isFilled: fillMode != 'none',
              fillMode: fillMode,
              fillColor: payload['fillColor'] == null
                  ? null
                  : Color((payload['fillColor'] as num).toInt()),
              gradientStart: payload['gradientStart'] == null
                  ? null
                  : Color((payload['gradientStart'] as num).toInt()),
              gradientEnd: payload['gradientEnd'] == null
                  ? null
                  : Color((payload['gradientEnd'] as num).toInt()),
              gradientAngle:
                  (payload['gradientAngle'] as num?)?.toDouble() ?? 0.0,
              rotation: (payload['rotation'] as num?)?.toDouble() ?? 0.0,
              borderRadius:
                  (payload['borderRadius'] as num?)?.toDouble() ?? 0.0,
              opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
              label: (payload['label'] as String?) ?? '',
              labelColor: payload['labelColor'] == null
                  ? null
                  : Color((payload['labelColor'] as num).toInt()),
              labelFontSize:
                  (payload['labelFontSize'] as num?)?.toDouble() ?? 14.0,
              labelFontWeight:
                  (payload['labelFontWeight'] as num?)?.toInt() ?? 600,
              labelTextAlign:
                  (payload['labelTextAlign'] as String?) ?? 'center',
              startArrowhead: _parseBool(payload['startArrowhead']),
              endArrowhead: payload['endArrowhead'] == null
                  ? shapeType == CanvasShapeType.arrow
                  : _parseBool(payload['endArrowhead']),
              flipH: _parseBool(payload['flipH']),
              flipV: _parseBool(payload['flipV']),
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
              frameId: payload['frameId'] as String?,
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
              frameId: payload['frameId'] as String?,
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
              labelFontSize:
                  (payload['labelFontSize'] as num?)?.toDouble() ?? 14,
              opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
            ),
          );
          continue;
        }
        if (type == 'frame') {
          final z = _readElementOrder(
            elementId: id,
            payload: payload,
            currentOrder: currentOrder,
            fallbackOrder: maxExistingOrder + rebuilt.length,
          );
          rebuilt.add(
            FrameElement(
              id: id,
              z: z,
              hidden: _parseBool(payload['hidden']),
              locked: _parseBool(payload['locked']),
              opacity: (payload['opacity'] as num?)?.toDouble() ?? 1.0,
              center: Offset(
                (payload['cx'] as num?)?.toDouble() ?? 0.0,
                (payload['cy'] as num?)?.toDouble() ?? 0.0,
              ),
              width:
                  (payload['width'] as num?)?.toDouble() ??
                  FrameElement.defaultWidth,
              height:
                  (payload['height'] as num?)?.toDouble() ??
                  FrameElement.defaultHeight,
              title: (payload['title'] as String?) ?? '',
              color: Color((payload['color'] as num?)?.toInt() ?? 0xFF64748B),
              cornerRadius: (payload['cornerRadius'] as num?)?.toDouble() ?? 0,
              clipContents: _parseBool(payload['clipContents']),
            ),
          );
          continue;
        }
        if (type == 'table') {
          final z = _readElementOrder(
            elementId: id,
            payload: payload,
            currentOrder: currentOrder,
            fallbackOrder: maxExistingOrder + rebuilt.length,
          );
          rebuilt.add(
            CanvasElement.fromMap(id, {
              ...payload,
              'type': 'table',
              'z': z,
              'hidden': _parseBool(payload['hidden']),
              'locked': _parseBool(payload['locked']),
              'headerRow': payload['headerRow'] == null
                  ? true
                  : _parseBool(payload['headerRow']),
            }),
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
              blendMode: (payload['blendMode'] as String?) ?? 'normal',
              elementIds:
                  (payload['elementIds'] as List?)?.whereType<String>().toList(
                    growable: false,
                  ) ??
                  const <String>[],
            ),
          );
          continue;
        }
      } catch (error) {
        debugPrint('Skipped unreadable canvas element $id: $error');
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

  /// Frames paint behind existing art so wrapping a board never covers it.
  int _lowestZIndex() {
    var minZ = 0;
    for (final element in state.elements) {
      if (element.z < minZ) minZ = element.z;
    }
    return minZ - 1;
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
      FrameElement() => 'frame',
      TableElement() => 'table',
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
          currentStrokeTilts: [event.tilt],
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
        currentStrokeTilts: [event.tilt],
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
    final allowPressure =
        state.stylusPressureEnabled ||
        (state.boardSettings.inkSpillEnabled && event.pressure > 1.0);
    final pressure = allowPressure ? event.pressure : 1.0;
    final updatedPressures = List<double>.from(state.currentStrokePressures)
      ..addAll([
        if (points.length == 2) state.currentStrokePressures.last,
        pressure,
      ]);
    final updatedTilts = List<double>.from(state.currentStrokeTilts);
    if (updatedTilts.length != state.currentStroke.length) {
      updatedTilts
        ..clear()
        ..addAll(List<double>.filled(state.currentStroke.length, 0));
    }
    updatedTilts.addAll([
      if (points.length == 2 && updatedTilts.isNotEmpty) updatedTilts.last,
      event.tilt,
    ]);
    emit(
      state.copyWith(
        currentStroke: updated,
        currentStrokePressures: updatedPressures,
        currentStrokeTilts: updatedTilts,
      ),
    );
    if (_isErasing) {
      await _extendEraserStroke(updated, emit);
      return;
    }
    final canvasService = _canvasService;
    final strokeId = _activeStrokeId;
    if (canvasService == null || strokeId == null || _boardId.isEmpty) return;
    final z = _nextZIndex();
    final colorValue = state.selectedColor.value;
    final strokeWidth = state.strokeWidth;
    final brushOpacity = state.brushOpacity;
    final brushType = state.brushType;
    await _publishSelectedShapePreviewLazy(
      strokeId,
      () => {
        'type': 'stroke',
        'z': z,
        'color': colorValue,
        'strokeWidth': strokeWidth,
        'opacity': brushOpacity,
        'brushType': brushType,
        'brushId': brushType,
        'pressures': updatedPressures,
        'tilts': updatedTilts,
        'points': updated
            .map((p) => {'x': p.dx, 'y': p.dy})
            .toList(growable: false),
      },
    );
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
          currentStrokeTilts: const [],
        ),
      );
      return;
    }
    final rawCandidatePressures =
        event.pressures ?? state.currentStrokePressures;
    final hasSpillPressure =
        state.boardSettings.inkSpillEnabled &&
        rawCandidatePressures.any((p) => p > 1.0);
    var usePressures = (state.stylusPressureEnabled || hasSpillPressure)
        ? rawCandidatePressures
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
    var useTilts = event.tilts ?? state.currentStrokeTilts;
    if (useTilts.length != usePoints.length) {
      if (useTilts.isEmpty) {
        useTilts = List<double>.filled(usePoints.length, 0);
      } else if (useTilts.length < usePoints.length) {
        final lastTilt = useTilts.last;
        useTilts = [
          ...useTilts,
          ...List<double>.filled(usePoints.length - useTilts.length, lastTilt),
        ];
      } else {
        useTilts = useTilts.sublist(0, usePoints.length);
      }
    }
    final strokeId = _activeStrokeId ?? _uuid.v4();
    final preset = brushPresetFor(state.brushType);
    final baseZ = _nextZIndex();
    final textureSeed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    final stroke = StrokeElement(
      id: strokeId,
      z: baseZ,
      color: state.selectedColor,
      strokeWidth: state.strokeWidth,
      opacity: state.brushOpacity,
      brushType: state.brushType,
      brushId: state.brushType,
      points: usePoints,
      pressures: usePressures,
      tilts: useTilts,
      spacing: preset.spacing,
      textureSeed: textureSeed,
    );

    final mirroredPolylines = symmetryMirroredPolylines(
      usePoints,
      _boardSettings,
    );
    final createdStrokes = <StrokeElement>[
      stroke,
      for (var i = 0; i < mirroredPolylines.length; i++)
        StrokeElement(
          id: _uuid.v4(),
          z: baseZ + i + 1,
          color: state.selectedColor,
          strokeWidth: state.strokeWidth,
          opacity: state.brushOpacity,
          brushType: state.brushType,
          brushId: state.brushType,
          points: mirroredPolylines[i],
          pressures: usePressures,
          tilts: useTilts,
          spacing: preset.spacing,
          textureSeed: textureSeed + i + 1,
        ),
    ];

    final attachedStrokes = [
      for (final s in createdStrokes)
        _attachOrDetachFrame(s, state.elements) as StrokeElement,
    ];
    final nextElements = List<CanvasElement>.from(state.elements)
      ..addAll(attachedStrokes);
    _committedElements = nextElements;
    emit(
      state.copyWith(
        elements: nextElements,
        currentStroke: const [],
        currentStrokePressures: const [],
        currentStrokeTilts: const [],
      ),
    );
    _activeStrokeId = null;
    if (attachedStrokes.length == 1) {
      final created = attachedStrokes.first;
      await _saveCrdtOperation(
        action: 'create',
        type: _elementType(created),
        objectId: created.id,
        data: created.toMap(),
        emit: emit,
      );
    } else {
      await _saveCrdtBatch([
        for (final s in attachedStrokes)
          (
            action: 'create',
            type: _elementType(s),
            objectId: s.id,
            data: s.toMap(),
          ),
      ], emit);
    }
  }

  void _onCancelStroke(CanvasCancelStroke event, Emitter<CanvasState> emit) {
    _activeStrokeId = null;
    _strokeStabilizer = null;
    _eraserSession = null;
    _strokeClock.stop();
    emit(
      state.copyWith(
        currentStroke: const [],
        currentStrokePressures: const [],
        currentStrokeTilts: const [],
      ),
    );
  }

  void _onSetFingerDrawing(
    CanvasSetFingerDrawing event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(fingerDrawingEnabled: event.enabled));
  }

  void _onSetQuickShapeEnabled(
    CanvasSetQuickShapeEnabled event,
    Emitter<CanvasState> emit,
  ) {
    if (!_ensureCanEdit(emit)) return;
    emit(state.copyWith(quickShapeEnabled: event.enabled));
  }

  Future<void> _onCommitQuickShape(
    CanvasCommitQuickShape event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final match = event.match;
    final id = _activeStrokeId ?? _uuid.v4();
    _activeStrokeId = null;
    _strokeStabilizer = null;
    _strokeClock.stop();
    final rawShape = ShapeElement(
      id: id,
      z: _nextZIndex(),
      shapeType: match.shapeType,
      center: match.center,
      size: math.max(match.width, match.height),
      width: match.width,
      height: match.height,
      color: state.selectedColor,
      strokeWidth: state.strokeWidth,
      opacity: state.brushOpacity,
      rotation: match.rotation,
    );
    final shape =
        _attachOrDetachFrame(rawShape, state.elements) as ShapeElement;
    final next = List<CanvasElement>.from(state.elements)..add(shape);
    emit(
      state.copyWith(
        elements: next,
        currentStroke: const [],
        currentStrokePressures: const [],
        currentStrokeTilts: const [],
        selectedShapeId: shape.id,
        selectedIds: {shape.id},
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: 'shape',
      objectId: shape.id,
      data: shape.toMap(),
      emit: emit,
    );
    _announceUndoable(emit, 'Snapped to ${match.shapeType.name}');
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
    final attached = _attachOrDetachFrame(shape, state.elements) as ShapeElement;
    final nextElements = List<CanvasElement>.from(state.elements)
      ..add(attached);
    _committedElements = nextElements;
    var next = state.copyWith(
      elements: nextElements,
      activeTray: null,
      selectedShapeId: attached.id,
      selectedIds: <String>{attached.id},
      selectedShapeRotation: attached.rotation,
      selectedShapeIsFilled: attached.isFilled,
      selectedShapeBorderRadius: attached.borderRadius,
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
      type: _elementType(attached),
      objectId: attached.id,
      data: attached.toMap(),
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
    final measuredText = _measureText(
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
    final textElement =
        _attachOrDetachFrame(measuredText, state.elements) as TextElement;
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

  /// Width the text would need on a single line, with no wrapping.
  ///
  /// Compared against a text element's box width to tell a box the user
  /// resized from one that still auto-fits its text.
  double _naturalTextWidth(TextElement element) {
    final layout = CanvasTextLayout.layout(
      text: element.text,
      fontSize: element.fontSize,
      fontWeight: element.fontWeight,
      fontFamily: element.fontFamily,
      textAlign: element.textAlign,
      lineHeight: element.lineHeight,
      maxWidth: 1e6,
      maxLines: 0,
      color: element.color,
    );
    try {
      return layout.size.width;
    } finally {
      layout.dispose();
    }
  }

  /// Rewrites the measured width/height from the element's real text style.
  ///
  /// With [keepWidth] the box keeps the requested wrapping width instead of
  /// collapsing back to the text's natural width, so widening a text box stays
  /// wide until the text itself changes.
  TextElement _measureText(TextElement element, {bool keepWidth = false}) {
    final layout = CanvasTextLayout.forElement(element);
    final size = layout.size;
    layout.dispose();
    return TextElement(
      id: element.id,
      z: element.z,
      hidden: element.hidden,
      locked: element.locked,
      opacity: element.opacity,
      frameId: element.frameId,
      text: element.text,
      center: element.center,
      color: element.color,
      width: keepWidth && element.width > 0
          ? element.width
          : size.width,
      height: size.height,
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
      frameId: existing.frameId,
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
    if (needsMeasure) {
      // Changing the text size (or any other style) must not throw away a
      // width the user dragged: keep a customised width, but still let an
      // untouched box keep fitting its text.
      final wasResized =
          existing.width > 0 &&
          (existing.width - _naturalTextWidth(existing)).abs() > 1.0;
      updated = _measureText(
        updated,
        keepWidth:
            event.autoSize != true && (event.width != null || wasResized),
      );
    }
    if (event.topLeft != null) {
      final attached = _attachOrDetachFrame(updated, state.elements);
      if (attached is TextElement) updated = attached;
    }
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
    final rawImage =
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
    final imageElement = style?.isReference == true
        ? rawImage
        : _attachOrDetachFrame(rawImage, state.elements) as ImageElement;
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
    final moved = oldElement.copyWith(
      center: Offset(newCx, newCy),
      width: newW,
      height: newH,
    );
    final updated = _attachOrDetachFrame(moved, state.elements) as ImageElement;
    final meta = updated.toMap()..remove('imageBase64');
    if (updated.frameId == null) meta['frameId'] = null;
    await _updateElementMeta(
      event.elementId,
      meta,
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

  /// Copies the optional AI image fields from [from] into [target] when
  /// [target] does not already have them, so an update never drops them.
  /// Does nothing for ordinary images (the fields are null).
  void _carryAiImageFields(Map<String, dynamic> target, ImageElement from) {
    final values = <String, String?>{
      'imageUrl': from.imageUrl,
      'aiPrompt': from.aiPrompt,
      'generationId': from.generationId,
    };
    for (final key in ImageElement.aiFieldKeys) {
      final value = values[key];
      if (value != null && target[key] == null) {
        target[key] = value;
      }
    }
  }

  /// Canvas size for an image of [sourceWidth] x [sourceHeight] pixels:
  /// longest side [maxSide], aspect ratio kept, within the image limits.
  Size _fitImageSize(int sourceWidth, int sourceHeight, double maxSide) {
    final w = sourceWidth <= 0 ? 1.0 : sourceWidth.toDouble();
    final h = sourceHeight <= 0 ? 1.0 : sourceHeight.toDouble();
    final scale = maxSide / math.max(w, h);
    return Size(
      (w * scale).clamp(80.0, 720.0).toDouble(),
      (h * scale).clamp(80.0, 720.0).toDouble(),
    );
  }

  Future<void> _onAddAiImageElement(
    CanvasAddAiImageElement event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final imageId = _uuid.v4();
    final rawAiImage = ImageElement(
      id: imageId,
      z: _nextZIndex(),
      center: event.center,
      width: event.width.clamp(80.0, 720.0),
      height: event.height.clamp(80.0, 720.0),
      imageBase64: event.thumbnailBase64,
      imageUrl: event.imageUrl,
      aiPrompt: ImageElement.optionalString(event.aiPrompt),
      generationId: ImageElement.optionalString(event.generationId),
    );
    final imageElement =
        _attachOrDetachFrame(rawAiImage, state.elements) as ImageElement;
    final nextElements =
        List<CanvasElement>.from(state.elements)..add(imageElement);
    emit(state.copyWith(elements: nextElements));
    await _saveCrdtOperation(
      action: 'create',
      type: _elementType(imageElement),
      objectId: imageId,
      data: imageElement.toMap(),
      emit: emit,
    );
  }

  Future<void> _onReplaceImageSource(
    CanvasReplaceImageSource event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    ImageElement? oldElement;
    for (final element in state.elements) {
      if (element.id == event.elementId && element is ImageElement) {
        oldElement = element;
        break;
      }
    }
    // The image was deleted while the request was running: nothing to replace.
    if (oldElement == null) return;

    // Keep the position and the longest side; follow the new aspect ratio.
    final size = _fitImageSize(
      event.sourceWidth,
      event.sourceHeight,
      math.max(oldElement.width, oldElement.height),
    );
    final replaced = ImageElement(
      id: oldElement.id,
      z: oldElement.z,
      hidden: oldElement.hidden,
      locked: oldElement.locked,
      opacity: oldElement.opacity,
      frameId: oldElement.frameId,
      center: oldElement.center,
      width: size.width,
      height: size.height,
      imageBase64: event.thumbnailBase64,
      rotation: oldElement.rotation,
      flipped: oldElement.flipped,
      flipV: oldElement.flipV,
      crop: ImageElement.fullCrop,
      borderRadius: oldElement.borderRadius,
      borderWidth: oldElement.borderWidth,
      borderColor: oldElement.borderColor,
      brightness: oldElement.brightness,
      contrast: oldElement.contrast,
      saturation: oldElement.saturation,
      isReference: oldElement.isReference,
      imageUrl: event.imageUrl,
      aiPrompt: ImageElement.optionalString(event.aiPrompt) ?? oldElement.aiPrompt,
      generationId: ImageElement.optionalString(event.generationId),
    );
    final next = state.elements
        .map((e) => e.id == event.elementId ? replaced : e)
        .toList();
    emit(state.copyWith(elements: next));
    // One upsert = one CRDT update = one undo step back to the old version.
    await _saveCrdtOperation(
      action: 'update',
      type: 'image',
      objectId: event.elementId,
      data: replaced.toMap(),
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
    final rawNote = fitStickyNoteHeight(
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
    final note = _attachOrDetachFrame(rawNote, state.elements) as StickyNoteElement;
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
            frameId: note.frameId,
            shapeType: CanvasShapeType.rectangle,
            size: math.max(note.width, note.height),
            width: note.width,
            height: note.height,
            color: note.color,
            rotation: note.rotation,
            isFilled: true,
            fillMode: 'solid',
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
            frameId: note.frameId,
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
        width: event.width?.clamp(40.0, 480.0),
        height: event.height?.clamp(40.0, 480.0),
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

  // ──────────────────────────────────────────────
  // Template import
  // ──────────────────────────────────────────────

  Future<void> _onImportElements(
    CanvasImportElements event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (event.payloads.isEmpty) return;

    final parsed = <({String placeholder, CanvasElement element})>[];
    final placeholders = <String>{};
    try {
      for (var i = 0; i < event.payloads.length; i++) {
        final raw = Map<String, dynamic>.from(event.payloads[i]);
        final placeholder = (raw.remove('id') as String?) ?? 'import_$i';
        if (!placeholders.add(placeholder)) {
          throw ArgumentError('Duplicate template id: $placeholder');
        }
        raw.remove('z');
        parsed.add((
          placeholder: placeholder,
          element: CanvasElement.fromMap(placeholder, raw),
        ));
      }
    } catch (_) {
      // All-or-nothing: a malformed template must not leave a partial board.
      emit(
        state.copyWith(
          infoMessage: 'This template contains an unsupported element.',
        ),
      );
      return;
    }

    final ids = {for (final entry in parsed) entry.placeholder: _uuid.v4()};
    final frameZ = _lowestZIndex();
    var nextZ = _nextZIndex();
    final imported = <CanvasElement>[];
    final writes = <_CrdtWrite>[];

    for (final entry in parsed) {
      final data = _translatedPayload(entry.element, event.offset);
      data['z'] = entry.element is FrameElement ? frameZ : nextZ++;
      if (entry.element is ConnectorElement) {
        for (final key in const ['startElementId', 'endElementId']) {
          final target = data[key];
          if (target is! String) continue;
          final mapped = ids[target];
          if (mapped == null) {
            data.remove(key);
          } else {
            data[key] = mapped;
          }
        }
      }
      final element = CanvasElement.fromMap(ids[entry.placeholder]!, data);
      imported.add(element);
      writes.add((
        action: 'create',
        type: _elementType(element),
        objectId: element.id,
        data: element.toMap(),
      ));
    }

    final next = [...state.elements, ...imported]..sort(_compareByZ);
    emit(
      state.copyWith(
        elements: next,
        selectedIds: imported.map((element) => element.id).toSet(),
        selectedShapeId: imported.first.id,
        activeTray: null,
      ),
    );
    await _saveCrdtBatch(writes, emit);
    _announceUndoable(emit, _groupActionMessage('Imported', imported.length));
  }

  // ──────────────────────────────────────────────
  // Board settings
  // ──────────────────────────────────────────────

  Future<void> _onSetBoardSettings(
    CanvasSetBoardSettings event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (event.settings == _boardSettings) return;
    _boardSettings = event.settings;
    emit(state.copyWith(boardSettings: event.settings));
    await _saveCrdtOperation(
      action: 'update',
      type: CanvasBoardSettings.crdtType,
      objectId: CanvasBoardSettings.crdtId,
      data: event.settings.toMap(),
      emit: emit,
    );
  }

  Future<void> _onAddGuide(
    CanvasAddGuide event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final guide = CanvasGuide(
      id: _uuid.v4(),
      axis: event.axis,
      position: event.position,
    );
    final updated = _boardSettings.copyWith(
      guides: [..._boardSettings.guides, guide],
    );
    await _onSetBoardSettings(CanvasSetBoardSettings(updated), emit);
  }

  Future<void> _onMoveGuide(
    CanvasMoveGuide event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    var changed = false;
    final nextGuides = <CanvasGuide>[
      for (final g in _boardSettings.guides)
        if (g.id == event.guideId)
          (() {
            changed = true;
            return g.copyWith(position: event.position);
          })()
        else
          g,
    ];
    if (!changed) return;
    await _onSetBoardSettings(
      CanvasSetBoardSettings(_boardSettings.copyWith(guides: nextGuides)),
      emit,
    );
  }

  Future<void> _onRemoveGuide(
    CanvasRemoveGuide event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final nextGuides = _boardSettings.guides
        .where((g) => g.id != event.guideId)
        .toList(growable: false);
    if (nextGuides.length == _boardSettings.guides.length) return;
    await _onSetBoardSettings(
      CanvasSetBoardSettings(_boardSettings.copyWith(guides: nextGuides)),
      emit,
    );
  }

  // ──────────────────────────────────────────────
  // Frame operations
  // ──────────────────────────────────────────────

  Future<void> _onAddFrame(
    CanvasAddFrame event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final id = _uuid.v4();
    final frame = FrameElement(
      id: id,
      z: _lowestZIndex(),
      center: event.center,
      width: event.width.clamp(120.0, 4000.0),
      height: event.height.clamp(80.0, 4000.0),
      title: event.title,
      color: event.color,
    );
    final next = <CanvasElement>[...state.elements, frame]..sort(_compareByZ);
    emit(
      state.copyWith(
        elements: next,
        activeTray: null,
        selectedShapeId: id,
        selectedIds: <String>{id},
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: 'frame',
      objectId: id,
      data: frame.toMap(),
      emit: emit,
    );
  }

  Future<void> _onUpdateFrame(
    CanvasUpdateFrame event,
    Emitter<CanvasState> emit, {
    String verb = 'Updated',
  }) async {
    if (!_ensureCanEdit(emit)) return;
    final target = state.elements
        .where((element) => element.id == event.elementId)
        .firstOrNull;
    if (target is! FrameElement || target.locked) return;
    final updated = target.copyWith(
      title: event.title,
      color: event.color,
      center: event.center,
      width: event.width?.clamp(120.0, 4000.0),
      height: event.height?.clamp(80.0, 4000.0),
      cornerRadius: event.cornerRadius?.clamp(0.0, 48.0),
      clipContents: event.clipContents,
    );
    if (updated == target) return;
    final next =
        state.elements
            .map((element) => element.id == updated.id ? updated : element)
            .toList()
          ..sort(_compareByZ);
    emit(state.copyWith(elements: next));
    await _saveCrdtOperation(
      action: 'update',
      type: 'frame',
      objectId: updated.id,
      data: updated.toMap(),
      emit: emit,
    );
    _announceUndoable(emit, _singleActionMessage(verb));
  }

  Future<void> _onDeleteFrame(
    CanvasDeleteFrame event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final frame = state.elements
        .whereType<FrameElement>()
        .where((e) => e.id == event.frameId)
        .firstOrNull;
    if (frame == null || frame.locked) return;
    final idsToDelete = <String>{frame.id};
    if (event.deleteContents) {
      for (final child in elementsContainedByFrame(frame, state.elements)) {
        if (!child.locked) idsToDelete.add(child.id);
      }
    }
    await _deleteElementsByIds(
      idsToDelete,
      emit,
      messageForCount: (count) => count <= 1
          ? 'Deleted frame · Undo to revert'
          : _groupActionMessage('Deleted frame &', count - 1),
    );
  }

  /// Captures all background elements (not already on a frame) whose bounds lie
  /// within the target frame and attaches them to that frame.
  Future<void> _onCaptureElementsInFrame(
    CanvasCaptureElementsInFrame event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final frame = state.elements
        .whereType<FrameElement>()
        .where((e) => e.id == event.frameId)
        .firstOrNull;
    if (frame == null || frame.locked) return;

    final updatedById = <String, CanvasElement>{};
    final writes = <_CrdtWrite>[];
    var nextZ = _nextZIndex();
    for (final element in state.elements) {
      if (element is FrameElement || element is LayerElement) continue;
      if (element.locked || element.frameId != null) continue;
      if (!frameContainsElement(frame, element)) continue;
      final map = Map<String, dynamic>.from(element.toMap())
        ..['frameId'] = frame.id;
      if (element.z <= frame.z) {
        map['z'] = nextZ++;
      }
      updatedById[element.id] = CanvasElement.fromMap(element.id, map);
      writes.add((
        action: 'update',
        type: _elementType(element),
        objectId: element.id,
        data: map,
      ));
    }
    if (writes.isEmpty) {
      emit(
        state.copyWith(
          infoMessage: 'No background elements inside frame bounds',
          infoMessageUndoable: false,
          infoMessageRedoable: false,
        ),
      );
      return;
    }
    final next =
        state.elements
            .map((element) => updatedById[element.id] ?? element)
            .toList()
          ..sort(_compareByZ);
    emit(state.copyWith(elements: next));
    await _saveCrdtBatch(writes, emit);
  }

  FrameElement? _containingFrameFor(
    CanvasElement element,
    List<CanvasElement> elements,
  ) {
    if (element is FrameElement || element is LayerElement) return null;
    // Keep the element on its current frame as long as any part of it still
    // overlaps the frame; only detach when the whole element leaves.
    if (element.frameId != null) {
      for (final candidate in elements) {
        if (candidate is FrameElement &&
            candidate.id == element.frameId &&
            !candidate.hidden &&
            frameOverlapsElement(candidate, element)) {
          return candidate;
        }
      }
    }
    for (var i = elements.length - 1; i >= 0; i--) {
      final candidate = elements[i];
      if (candidate is FrameElement &&
          !candidate.hidden &&
          _shouldAttachToFrame(candidate, element)) {
        return candidate;
      }
    }
    return null;
  }

  /// Whether an unattached [element] was placed inside [frame] (as opposed to
  /// merely enclosing or passing across a small frame at low zoom).
  bool _shouldAttachToFrame(FrameElement frame, CanvasElement element) {
    final rect = frameRect(frame);
    final bounds = elementBounds(element);
    if (bounds == null || !rect.overlaps(bounds)) return false;
    if (element is StrokeElement) {
      if (element.points.isEmpty) return false;
      if (rect.contains(element.points.first)) return true;
      var insideCount = 0;
      for (final point in element.points) {
        if (rect.contains(point)) insideCount++;
      }
      return insideCount * 2 >= element.points.length;
    }
    final intersection = rect.intersect(bounds);
    if (intersection.width <= 0 || intersection.height <= 0) {
      return rect.contains(bounds.center) &&
          bounds.width <= rect.width &&
          bounds.height <= rect.height;
    }
    final boundsArea = bounds.width * bounds.height;
    if (boundsArea <= 0) return rect.contains(bounds.center);
    return intersection.width * intersection.height * 2 >= boundsArea;
  }

  CanvasElement _attachOrDetachFrame(
    CanvasElement element,
    List<CanvasElement> elements,
  ) {
    if (element is FrameElement || element is LayerElement) return element;
    final host = _containingFrameFor(element, elements);
    final nextFrameId = host?.id;
    if (nextFrameId == element.frameId) return element;
    final map = Map<String, dynamic>.from(element.toMap());
    if (nextFrameId == null) {
      map.remove('frameId');
    } else {
      map['frameId'] = nextFrameId;
      if (element.z <= host!.z) {
        map['z'] = _nextZIndex();
      }
    }
    return CanvasElement.fromMap(element.id, map);
  }

  /// Moves the frame together with any elements explicitly attached to it
  /// (`frameId == frame.id`). Background elements that only overlap
  /// geometrically stay where the user put them.
  Future<void> _moveFrame(
    FrameElement frame,
    Offset center,
    Emitter<CanvasState> emit,
  ) async {
    final delta = center - frame.center;
    if (delta == Offset.zero) return;
    await _applySelectionDeltas({frame.id: delta}, emit);
    _announceUndoable(emit, _singleActionMessage('Moved'));
  }

  // ──────────────────────────────────────────────
  // Table operations (F-16)
  // ──────────────────────────────────────────────

  Future<void> _onAddTable(
    CanvasAddTable event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final rows = event.rows.clamp(1, TableElement.maxRows);
    final maxCols = (TableElement.maxTotalCells ~/ rows).clamp(
      1,
      TableElement.maxColumns,
    );
    final cols = event.columns.clamp(1, maxCols);
    final id = _uuid.v4();
    final rawTable = TableElement(
      id: id,
      z: _nextZIndex(),
      center: event.center,
      width: event.width
          .clamp(TableElement.minCellWidth * cols, 4000.0)
          .toDouble(),
      height: event.height
          .clamp(TableElement.minCellHeight * rows, 4000.0)
          .toDouble(),
      rows: rows,
      columns: cols,
      cells: TableElement.normalizeCells(const [], rows, cols),
      headerRow: event.headerRow,
    );
    final table = _attachOrDetachFrame(rawTable, state.elements) as TableElement;
    final next = <CanvasElement>[...state.elements, table]..sort(_compareByZ);
    emit(
      state.copyWith(
        elements: next,
        activeTray: null,
        selectedShapeId: id,
        selectedIds: <String>{id},
      ),
    );
    await _saveCrdtOperation(
      action: 'create',
      type: 'table',
      objectId: id,
      data: table.toMap(),
      emit: emit,
    );
  }

  Future<void> _onUpdateTableCell(
    CanvasUpdateTableCell event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final table = state.elements
        .whereType<TableElement>()
        .where((e) => e.id == event.tableId)
        .firstOrNull;
    if (table == null || table.locked) return;
    if (event.row < 0 ||
        event.row >= table.rows ||
        event.column < 0 ||
        event.column >= table.columns) {
      return;
    }
    final nextCells = List<TableCellData>.from(
      TableElement.normalizeCells(table.cells, table.rows, table.columns),
    );
    final idx = event.row * table.columns + event.column;
    final prev = nextCells[idx];
    final nextCell = prev.copyWith(
      text: event.text,
      backgroundColor: event.backgroundColor,
      clearBackgroundColor: event.clearBackgroundColor,
      textColor: event.textColor,
      clearTextColor: event.clearTextColor,
      fontWeight: event.fontWeight,
      textAlign: event.textAlign,
    );
    if (nextCell == prev) return;
    nextCells[idx] = nextCell;
    final updated = table.copyWith(cells: nextCells);
    await _updateElementMeta(
      table.id,
      updated.toMap(),
      emit,
    );
    _announceUndoable(emit, _singleActionMessage('Updated cell'));
  }

  Future<void> _onUpdateTableStyle(
    CanvasUpdateTableStyle event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final table = state.elements
        .whereType<TableElement>()
        .where((e) => e.id == event.tableId)
        .firstOrNull;
    if (table == null || table.locked) return;

    var rows = table.rows;
    var cols = table.columns;
    var cells = List<TableCellData>.from(
      TableElement.normalizeCells(table.cells, rows, cols),
    );
    var colFractions = List<double>.from(table.resolvedColumnFractions);
    var rowFractions = List<double>.from(table.resolvedRowFractions);
    var width = table.width;
    var height = table.height;

    if (event.insertRowAt != null &&
        rows < TableElement.maxRows &&
        (rows + 1) * cols <= TableElement.maxTotalCells) {
      final at = event.insertRowAt!.clamp(0, rows);
      final inserted = List<TableCellData>.filled(cols, const TableCellData());
      cells.insertAll(at * cols, inserted);
      final newRowH = height / rows;
      height = (height + newRowH).clamp(
        TableElement.minCellHeight * (rows + 1),
        4000.0,
      );
      rowFractions.insert(at, 1.0 / (rows + 1));
      rows += 1;
    } else if (event.removeRowAt != null && rows > 1) {
      final at = event.removeRowAt!.clamp(0, rows - 1);
      cells.removeRange(at * cols, at * cols + cols);
      final removedFrac = rowFractions.removeAt(at);
      height = (height * (1.0 - removedFrac)).clamp(
        TableElement.minCellHeight * (rows - 1),
        4000.0,
      );
      rows -= 1;
    }

    if (event.insertColumnAt != null &&
        cols < TableElement.maxColumns &&
        rows * (cols + 1) <= TableElement.maxTotalCells) {
      final at = event.insertColumnAt!.clamp(0, cols);
      for (var r = rows - 1; r >= 0; r--) {
        cells.insert(r * cols + at, const TableCellData());
      }
      final newColW = width / cols;
      width = (width + newColW).clamp(
        TableElement.minCellWidth * (cols + 1),
        4000.0,
      );
      colFractions.insert(at, 1.0 / (cols + 1));
      cols += 1;
    } else if (event.removeColumnAt != null && cols > 1) {
      final at = event.removeColumnAt!.clamp(0, cols - 1);
      for (var r = rows - 1; r >= 0; r--) {
        cells.removeAt(r * cols + at);
      }
      final removedFrac = colFractions.removeAt(at);
      width = (width * (1.0 - removedFrac)).clamp(
        TableElement.minCellWidth * (cols - 1),
        4000.0,
      );
      cols -= 1;
    }

    if (event.columnFractions != null) {
      colFractions = List<double>.from(event.columnFractions!);
    }
    if (event.rowFractions != null) {
      rowFractions = List<double>.from(event.rowFractions!);
    }
    if (event.width != null) {
      width = event.width!.clamp(TableElement.minCellWidth * cols, 4000.0);
    }
    if (event.height != null) {
      height = event.height!.clamp(TableElement.minCellHeight * rows, 4000.0);
    }

    final updated = table.copyWith(
      rows: rows,
      columns: cols,
      cells: cells,
      width: width,
      height: height,
      headerRow: event.headerRow,
      borderColor: event.borderColor,
      borderWidth: event.borderWidth?.clamp(0.5, 12.0),
      fontSize: event.fontSize?.clamp(8.0, 64.0),
      textColor: event.textColor,
      backgroundColor: event.backgroundColor,
      headerBackgroundColor: event.headerBackgroundColor,
      columnFractions: TableElement.normalizeFractions(colFractions, cols),
      rowFractions: TableElement.normalizeFractions(rowFractions, rows),
    );
    if (updated == table) return;
    await _updateElementMeta(
      table.id,
      updated.toMap(),
      emit,
      syncConnectors: true,
    );
    _announceUndoable(emit, _singleActionMessage('Updated table'));
  }

  Future<void> _onAddConnector(
    CanvasAddConnector event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final connectorId = _uuid.v4();
    final rawConnector = ConnectorElement(
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
    final connector =
        _attachOrDetachFrame(rawConnector, state.elements) as ConnectorElement;
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
      frameId: target.frameId,
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
      frameId: connector.frameId,
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
    final conflicts = <String>[];
    for (final id in ids) {
      final recorded = _myCommittedPayload[id];
      final current = adapter.materializeElement(id);
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
    for (final id in ids) {
      _myCommittedPayload[id] = adapter.materializeElement(id);
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
    final conflicts = <String>[];
    for (final id in ids) {
      final live = adapter.materializeElement(id);
      final target = _myRedoTarget[id] ?? _myCommittedPayload[id];
      final baseline = _myCommittedPayload[id];
      if (_payloadEquals(live, baseline)) continue;
      if (_payloadEquals(live, target)) continue;
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

  static String _brushSizeKey(String brushType) =>
      brushType == 'eraser' ? 'eraser' : brushPresetFor(brushType).id;

  static double _defaultWidthForBrushKey(String key) =>
      key == 'eraser' ? 12.0 : brushPresetFor(key).defaultWidth;

  void _onUpdateStrokeWidth(
    CanvasUpdateStrokeWidth event,
    Emitter<CanvasState> emit,
  ) {
    final key = _brushSizeKey(state.brushType);
    emit(
      state.copyWith(
        strokeWidth: event.strokeWidth,
        brushWidths: {...state.brushWidths, key: event.strokeWidth},
      ),
    );
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
    final currentKey = _brushSizeKey(state.brushType);
    final nextKey = _brushSizeKey(event.brushType);
    final updatedWidths = <String, double>{
      ...state.brushWidths,
      currentKey: state.strokeWidth,
    };
    final nextWidth =
        updatedWidths[nextKey] ?? _defaultWidthForBrushKey(nextKey);
    if (event.brushType == 'marker') {
      // The marker preset starts at its own opacity; the sliders
      // remain free to adjust it afterwards.
      final preset = brushPresetFor(event.brushType);
      emit(
        state.copyWith(
          brushType: event.brushType,
          strokeWidth: nextWidth,
          brushWidths: updatedWidths,
          brushOpacity: preset.defaultOpacity,
          currentToolMode: _toolModeForBrush(event.brushType),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        brushType: event.brushType,
        strokeWidth: nextWidth,
        brushWidths: updatedWidths,
        currentToolMode: _toolModeForBrush(event.brushType),
      ),
    );
  }

  void _onApplyBrushPreset(
    CanvasApplyBrushPreset event,
    Emitter<CanvasState> emit,
  ) {
    final preset = brushPresetFor(event.presetId);
    final currentKey = _brushSizeKey(state.brushType);
    final nextKey = _brushSizeKey(preset.id);
    final updatedWidths = <String, double>{
      ...state.brushWidths,
      currentKey: state.strokeWidth,
    };
    final nextWidth = updatedWidths[nextKey] ?? preset.defaultWidth;
    emit(
      state.copyWith(
        brushType: preset.id,
        strokeWidth: nextWidth,
        brushWidths: updatedWidths,
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
    var updatedWidths = state.brushWidths;
    var nextWidth = state.strokeWidth;
    if (nextBrushType != state.brushType) {
      final currentKey = _brushSizeKey(state.brushType);
      final nextKey = _brushSizeKey(nextBrushType);
      updatedWidths = <String, double>{
        ...state.brushWidths,
        currentKey: state.strokeWidth,
      };
      nextWidth = updatedWidths[nextKey] ?? _defaultWidthForBrushKey(nextKey);
    }
    emit(
      state.copyWith(
        currentToolMode: event.mode,
        pendingShapeType: event.shapeType,
        isDrawingShape: false,
        shapeDrawStart: null,
        shapeDrawCurrent: null,
        brushType: nextBrushType,
        strokeWidth: nextWidth,
        brushWidths: updatedWidths,
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
    if (state.currentToolMode == CanvasToolMode.frame) {
      _activeShapeDrawingId = null;
      emit(
        state.copyWith(
          isDrawingShape: true,
          shapeDrawStart: event.point,
          shapeDrawCurrent: event.point,
        ),
      );
      return;
    }
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
    if (state.currentToolMode == CanvasToolMode.frame) {
      if (start == null || current == null) return;
      final dx = (current.dx - start.dx).abs();
      final dy = (current.dy - start.dy).abs();
      if (dx < 10 && dy < 10) {
        await _onCancelShapeDraw(CanvasCancelShapeDraw(), emit);
        return;
      }
      final rect = Rect.fromPoints(start, current);
      emit(
        state.copyWith(
          currentToolMode: CanvasToolMode.select,
          isDrawingShape: false,
          shapeDrawStart: null,
          shapeDrawCurrent: null,
        ),
      );
      await _onAddFrame(
        CanvasAddFrame(
          center: rect.center,
          width: rect.width,
          height: rect.height,
        ),
        emit,
      );
      return;
    }
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
    final selectedFrameIds = {
      for (final element in state.elements)
        if (element is FrameElement && ids.contains(element.id)) element.id,
    };
    if (selectedFrameIds.isNotEmpty) {
      ids.removeWhere((id) {
        final el = _findElement(id);
        return el != null &&
            el.frameId != null &&
            selectedFrameIds.contains(el.frameId);
      });
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
    final table = primary is TableElement ? primary : null;
    final stroke = primary is StrokeElement ? primary : null;
    emit(
      state.copyWith(
        selectedShapeId: ordered.isEmpty ? null : ordered.first,
        selectedIds: ordered.toSet(),
        selectedShapeIsFilled: shape?.isFilled ?? false,
        selectedShapeBorderRadius: shape?.borderRadius ?? 0.0,
        selectedShapeRotation:
            shape?.rotation ??
            text?.rotation ??
            sticky?.rotation ??
            table?.rotation ??
            0.0,
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
    final selectedFrameIds = {
      for (final element in state.elements)
        if (element is FrameElement && ids.contains(element.id)) element.id,
    };
    if (selectedFrameIds.isNotEmpty) {
      ids.removeWhere((id) {
        final el = _findElement(id);
        return el != null &&
            el.frameId != null &&
            selectedFrameIds.contains(el.frameId);
      });
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

  Future<void> _onArrangeSelection(
    CanvasArrangeSelection event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final nodes = <CanvasElement>[];
    final bounds = <String, Rect>{};
    for (final element in state.elements) {
      if (!state.selectedIds.contains(element.id)) continue;
      if (element.locked || element is LayerElement || element is ConnectorElement) {
        continue;
      }
      final rect = elementBounds(element);
      if (rect == null) continue;
      nodes.add(element);
      bounds[element.id] = rect;
    }
    if (nodes.length < 2) return;

    final nodeIds = bounds.keys.toSet();
    final spacing = event.spacing.clamp(8.0, 240.0);

    var union = bounds.values.first;
    for (final r in bounds.values.skip(1)) {
      union = union.expandToInclude(r);
    }

    // Build directed graph from selected connectors attached at both ends.
    final outgoing = <String, List<String>>{for (final id in nodeIds) id: []};
    final inDegree = <String, int>{for (final id in nodeIds) id: 0};
    for (final element in state.elements) {
      if (element is! ConnectorElement) continue;
      if (!state.selectedIds.contains(element.id)) continue;
      final s = element.startElementId;
      final e = element.endElementId;
      if (s == null || e == null || s == e) continue;
      if (!nodeIds.contains(s) || !nodeIds.contains(e)) continue;
      if (!outgoing[s]!.contains(e)) {
        outgoing[s]!.add(e);
        inDegree[e] = (inDegree[e] ?? 0) + 1;
      }
    }

    final targetTopLeft = <String, Offset>{};
    final byPos = List<String>.from(nodeIds)
      ..sort((a, b) {
        final ra = bounds[a]!;
        final rb = bounds[b]!;
        final cmpX = ra.left.compareTo(rb.left);
        return cmpX != 0 ? cmpX : ra.top.compareTo(rb.top);
      });

    switch (event.mode) {
      case CanvasArrangeMode.row:
        var x = union.left;
        for (final id in byPos) {
          final r = bounds[id]!;
          targetTopLeft[id] = Offset(x, union.center.dy - r.height / 2);
          x += r.width + spacing;
        }
      case CanvasArrangeMode.column:
        final byY = List<String>.from(nodeIds)
          ..sort((a, b) => bounds[a]!.top.compareTo(bounds[b]!.top));
        var y = union.top;
        for (final id in byY) {
          final r = bounds[id]!;
          targetTopLeft[id] = Offset(union.center.dx - r.width / 2, y);
          y += r.height + spacing;
        }
      case CanvasArrangeMode.grid:
        final gridOrder = List<String>.from(nodeIds)
          ..sort((a, b) {
            final ra = bounds[a]!;
            final rb = bounds[b]!;
            final cmpY = ra.top.compareTo(rb.top);
            return cmpY != 0 ? cmpY : ra.left.compareTo(rb.left);
          });
        final cols = math.max(1, math.sqrt(gridOrder.length).ceil());
        var curY = union.top;
        for (var i = 0; i < gridOrder.length; i += cols) {
          final rowEnd = math.min(i + cols, gridOrder.length);
          var curX = union.left;
          var rowHeight = 0.0;
          for (var j = i; j < rowEnd; j++) {
            final r = bounds[gridOrder[j]]!;
            if (r.height > rowHeight) rowHeight = r.height;
          }
          for (var j = i; j < rowEnd; j++) {
            final id = gridOrder[j];
            final r = bounds[id]!;
            targetTopLeft[id] = Offset(
              curX,
              curY + (rowHeight - r.height) / 2,
            );
            curX += r.width + spacing;
          }
          curY += rowHeight + spacing;
        }
      case CanvasArrangeMode.tree:
        final visited = <String>{};
        final treeChildren = <String, List<String>>{
          for (final id in nodeIds) id: [],
        };
        final depthOf = <String, int>{};
        final roots = <String>[];

        String pickRoot() {
          if (event.rootId != null &&
              nodeIds.contains(event.rootId) &&
              !visited.contains(event.rootId)) {
            return event.rootId!;
          }
          final remaining = nodeIds.where((id) => !visited.contains(id)).toList()
            ..sort((a, b) {
              final zeroInA = (inDegree[a] ?? 0) == 0 ? 0 : 1;
              final zeroInB = (inDegree[b] ?? 0) == 0 ? 0 : 1;
              if (zeroInA != zeroInB) return zeroInA - zeroInB;
              final outCmp =
                  (outgoing[b]?.length ?? 0).compareTo(outgoing[a]?.length ?? 0);
              if (outCmp != 0) return outCmp;
              final cmpX = bounds[a]!.left.compareTo(bounds[b]!.left);
              return cmpX != 0
                  ? cmpX
                  : bounds[a]!.top.compareTo(bounds[b]!.top);
            });
          return remaining.first;
        }

        while (visited.length < nodeIds.length) {
          final root = pickRoot();
          roots.add(root);
          visited.add(root);
          depthOf[root] = 0;
          final queue = <String>[root];
          while (queue.isNotEmpty) {
            final cur = queue.removeAt(0);
            final kids = List<String>.from(outgoing[cur] ?? const [])
              ..sort((a, b) => bounds[a]!.top.compareTo(bounds[b]!.top));
            for (final next in kids) {
              if (visited.add(next)) {
                treeChildren[cur]!.add(next);
                depthOf[next] = (depthOf[cur] ?? 0) + 1;
                queue.add(next);
              }
            }
          }
        }

        final colWidth = <int, double>{};
        for (final id in nodeIds) {
          final d = depthOf[id] ?? 0;
          final w = bounds[id]!.width;
          if (w > (colWidth[d] ?? 0)) colWidth[d] = w;
        }
        final colX = <int, double>{};
        final maxDepth = colWidth.keys.fold(0, math.max);
        var xCursor = union.left;
        for (var d = 0; d <= maxDepth; d++) {
          colX[d] = xCursor;
          xCursor += (colWidth[d] ?? 0) + spacing;
        }

        final subtreeH = <String, double>{};
        double measureSubtree(String id) {
          final kids = treeChildren[id]!;
          final selfH = bounds[id]!.height;
          if (kids.isEmpty) {
            subtreeH[id] = selfH;
            return selfH;
          }
          var total = 0.0;
          for (var i = 0; i < kids.length; i++) {
            total += measureSubtree(kids[i]);
            if (i + 1 < kids.length) total += spacing;
          }
          final h = math.max(selfH, total);
          subtreeH[id] = h;
          return h;
        }

        void layoutSubtree(String id, double topY) {
          final kids = treeChildren[id]!;
          final d = depthOf[id] ?? 0;
          final rect = bounds[id]!;
          final subH = subtreeH[id] ?? rect.height;
          targetTopLeft[id] = Offset(
            colX[d]!,
            topY + (subH - rect.height) / 2,
          );
          if (kids.isEmpty) return;
          var childrenTotal = 0.0;
          for (var i = 0; i < kids.length; i++) {
            childrenTotal += subtreeH[kids[i]]!;
            if (i + 1 < kids.length) childrenTotal += spacing;
          }
          var childY = topY + (subH - childrenTotal) / 2;
          for (final kid in kids) {
            layoutSubtree(kid, childY);
            childY += subtreeH[kid]! + spacing;
          }
        }

        var rootY = union.top;
        for (final root in roots) {
          final h = measureSubtree(root);
          layoutSubtree(root, rootY);
          rootY += h + spacing;
        }
      case CanvasArrangeMode.flow:
        // Topological layers (Kahn), falling back to left-to-right order on cycles.
        final remainingIn = Map<String, int>.from(inDegree);
        final layerOf = <String, int>{};
        final ready = <String>[
          for (final id in byPos)
            if ((remainingIn[id] ?? 0) == 0) id,
        ];
        final order = <String>[];
        while (order.length < nodeIds.length) {
          if (ready.isEmpty) {
            for (final id in byPos) {
              if (!order.contains(id)) {
                ready.add(id);
                break;
              }
            }
          }
          final cur = ready.removeAt(0);
          if (order.contains(cur)) continue;
          order.add(cur);
          final curLayer = layerOf[cur] ?? 0;
          for (final nxt in outgoing[cur] ?? const []) {
            if (!order.contains(nxt)) {
              final nextLayer = curLayer + 1;
              if (nextLayer > (layerOf[nxt] ?? 0)) {
                layerOf[nxt] = nextLayer;
              }
              remainingIn[nxt] = (remainingIn[nxt] ?? 1) - 1;
              if (remainingIn[nxt]! <= 0 && !ready.contains(nxt)) {
                ready.add(nxt);
              }
            }
          }
        }
        final colGroups = <int, List<String>>{};
        for (final id in order) {
          final l = layerOf[id] ?? 0;
          colGroups.putIfAbsent(l, () => []).add(id);
        }
        final layers = colGroups.keys.toList()..sort();
        var xCursor = union.left;
        for (final layer in layers) {
          final items = colGroups[layer]!
            ..sort((a, b) => bounds[a]!.top.compareTo(bounds[b]!.top));
          final colW = items.map((id) => bounds[id]!.width).reduce(math.max);
          final totalH = items.fold<double>(
            0,
            (sum, id) => sum + bounds[id]!.height,
          ) + spacing * (items.length - 1);
          var yCursor = union.center.dy - totalH / 2;
          for (final id in items) {
            final r = bounds[id]!;
            targetTopLeft[id] = Offset(xCursor + (colW - r.width) / 2, yCursor);
            yCursor += r.height + spacing;
          }
          xCursor += colW + spacing;
        }
    }

    final deltas = <String, Offset>{
      for (final id in nodeIds)
        if (targetTopLeft[id] != null)
          id: targetTopLeft[id]! - bounds[id]!.topLeft,
    };

    // Translate nodes and keep attached connectors pinned in a single CRDT batch.
    final updatedById = <String, CanvasElement>{};
    for (final node in nodes) {
      final d = deltas[node.id];
      if (d == null || (d.dx.abs() < 0.01 && d.dy.abs() < 0.01)) continue;
      final data = _translatedPayload(node, d);
      updatedById[node.id] = CanvasElement.fromMap(node.id, data);
    }
    if (updatedById.isEmpty) return;

    final elementById = <String, CanvasElement>{
      for (final el in state.elements) el.id: updatedById[el.id] ?? el,
    };
    for (final el in state.elements) {
      if (el is! ConnectorElement) continue;
      final startMoved =
          el.startElementId != null && updatedById.containsKey(el.startElementId);
      final endMoved =
          el.endElementId != null && updatedById.containsKey(el.endElementId);
      if (!startMoved && !endMoved) continue;
      final (newStart, newEnd) = resolveConnectorEndpoints(el, elementById);
      final data = Map<String, dynamic>.from(el.toMap())
        ..['sx'] = newStart.dx
        ..['sy'] = newStart.dy
        ..['ex'] = newEnd.dx
        ..['ey'] = newEnd.dy;
      updatedById[el.id] = CanvasElement.fromMap(el.id, data);
    }

    final next = state.elements
        .map((el) => updatedById[el.id] ?? el)
        .toList(growable: false);
    emit(state.copyWith(elements: next));
    await _saveCrdtBatch([
      for (final el in updatedById.values)
        (
          action: 'update',
          type: _elementType(el),
          objectId: el.id,
          data: el.toMap(),
        ),
    ], emit);
    _announceUndoable(
      emit,
      _groupActionMessage('Arranged', nodes.length),
    );
  }

  Future<void> _onDuplicateElements(
    CanvasDuplicateElements event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    // Duplicating a frame duplicates what it visually contains, and the
    // existing connector remap keeps links between the clones internal.
    final requested = <String>{...event.ids};
    for (final frame in state.elements.whereType<FrameElement>()) {
      if (!requested.contains(frame.id)) continue;
      for (final element in elementsContainedByFrame(frame, state.elements)) {
        requested.add(element.id);
      }
    }
    final originals = state.elements
        .where((element) => requested.contains(element.id))
        .toList();
    if (originals.isEmpty) return;
    final idMap = <String, String>{
      for (final element in originals) element.id: _uuid.v4(),
    };
    var nextZ = _nextZIndex();
    // A cloned frame must sit behind its clones, not above the original art.
    final frameCloneZ = _lowestZIndex();
    final clones = <CanvasElement>[];
    for (final element in originals) {
      final data = _translatedPayload(element, const Offset(16, 16));
      data['z'] = element is FrameElement ? frameCloneZ : nextZ++;
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
    // Copying a frame copies what it contains, so paste behaves like
    // duplicate instead of producing an empty section.
    final requested = <String>{...ids};
    for (final frame in state.elements.whereType<FrameElement>()) {
      if (!ids.contains(frame.id)) continue;
      for (final element in elementsContainedByFrame(frame, state.elements)) {
        requested.add(element.id);
      }
    }
    final copied = state.elements
        .where(
          (element) =>
              requested.contains(element.id) &&
              !element.hidden &&
              !element.locked,
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
    // Pasted frames stay behind the art instead of covering it.
    final framePasteZ = _lowestZIndex();
    final pasted = <CanvasElement>[];

    for (final entry in _clipboard) {
      final source = CanvasElement.fromMap(entry.id, entry.data);
      final data = _translatedPayload(source, delta);
      data['z'] = source is FrameElement ? framePasteZ : nextZ++;
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
        blendMode: layer.blendMode,
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

  Future<void> _onUpdateLayerBlendMode(
    CanvasUpdateLayerBlendMode event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final layer = state.elements
        .whereType<LayerElement>()
        .where((layer) => layer.id == event.layerId)
        .firstOrNull;
    if (layer == null || layer.blendMode == event.blendMode) return;
    final updated = LayerElement(
      id: layer.id,
      z: layer.z,
      hidden: layer.hidden,
      locked: layer.locked,
      opacity: layer.opacity,
      name: layer.name,
      blendMode: event.blendMode,
      elementIds: layer.elementIds,
    );
    emit(
      state.copyWith(
        elements: state.elements
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false),
      ),
    );
    await _saveCrdtOperation(
      action: 'update',
      type: 'layer',
      objectId: updated.id,
      data: updated.toMap(),
      emit: emit,
    );
    _announceUndoable(emit, 'Layer blend updated');
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
      blendMode: existing.blendMode,
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
    final effectiveDeltas = Map<String, Offset>.from(deltas);
    final movedFrameIds = <String>{};
    for (final element in state.elements) {
      if (element is FrameElement &&
          !element.locked &&
          effectiveDeltas.containsKey(element.id)) {
        movedFrameIds.add(element.id);
        final frameDelta = effectiveDeltas[element.id]!;
        if (frameDelta == Offset.zero) continue;
        for (final child in state.elements) {
          if (!child.locked &&
              hostFrameId(child, state.elements) == element.id) {
            effectiveDeltas.putIfAbsent(child.id, () => frameDelta);
          }
        }
      }
    }

    final updatedById = <String, CanvasElement>{};
    final payloads = <String, Map<String, dynamic>>{};
    final types = <String, String>{};
    for (final element in state.elements) {
      if (element.locked) continue;
      final delta = effectiveDeltas[element.id];
      if (delta == null || delta == Offset.zero) continue;
      final data = _translatedPayload(element, delta);
      var moved = CanvasElement.fromMap(element.id, data);
      final host = hostFrameId(element, state.elements);
      if (host != null && movedFrameIds.contains(host)) {
        // Travels with its frame: keep (and persist) the membership.
        if (moved.frameId != host) {
          moved = CanvasElement.fromMap(element.id, {
            ...moved.toMap(),
            'frameId': host,
          });
        }
      } else {
        moved = _attachOrDetachFrame(moved, state.elements);
      }
      final finalData = moved.toMap();
      updatedById[element.id] = moved;
      payloads[element.id] = finalData;
      types[element.id] = _elementType(moved);
    }
    if (updatedById.isEmpty) return;
    final elementById = <String, CanvasElement>{
      for (final el in state.elements) el.id: updatedById[el.id] ?? el,
    };
    for (final el in state.elements) {
      if (el is! ConnectorElement || updatedById.containsKey(el.id)) continue;
      final sMoved =
          el.startElementId != null && updatedById.containsKey(el.startElementId);
      final eMoved =
          el.endElementId != null && updatedById.containsKey(el.endElementId);
      if (!sMoved && !eMoved) continue;
      final (newStart, newEnd) = resolveConnectorEndpoints(el, elementById);
      if ((newStart - el.startPoint).distance < 0.01 &&
          (newEnd - el.endPoint).distance < 0.01) {
        continue;
      }
      final data = Map<String, dynamic>.from(el.toMap())
        ..['sx'] = newStart.dx
        ..['sy'] = newStart.dy
        ..['ex'] = newEnd.dx
        ..['ey'] = newEnd.dy;
      updatedById[el.id] = CanvasElement.fromMap(el.id, data);
      payloads[el.id] = data;
      types[el.id] = 'connector';
    }
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
    if (shape is FrameElement) {
      await _moveFrame(shape, event.center, emit);
      return;
    }
    if (shape is TableElement) {
      if (shape.center == event.center) return;
      final moved = TableElement(
        id: shape.id,
        z: shape.z,
        hidden: shape.hidden,
        locked: shape.locked,
        opacity: shape.opacity,
        frameId: shape.frameId,
        center: event.center,
        width: shape.width,
        height: shape.height,
        rows: shape.rows,
        columns: shape.columns,
        cells: shape.cells,
        headerRow: shape.headerRow,
        borderColor: shape.borderColor,
        borderWidth: shape.borderWidth,
        cellPadding: shape.cellPadding,
        fontSize: shape.fontSize,
        textColor: shape.textColor,
        backgroundColor: shape.backgroundColor,
        headerBackgroundColor: shape.headerBackgroundColor,
        columnFractions: shape.columnFractions,
        rowFractions: shape.rowFractions,
        rotation: shape.rotation,
      );
      final updated = _attachOrDetachFrame(moved, state.elements);
      await _updateElementMeta(
        shape.id,
        {
          'cx': event.center.dx,
          'cy': event.center.dy,
          'frameId': updated.frameId,
          if (updated.z != shape.z) 'z': updated.z,
        },
        emit,
        syncConnectors: true,
      );
      _announceUndoable(emit, _singleActionMessage('Moved'));
      return;
    }
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
      final moved = ConnectorElement(
        id: shape.id,
        z: shape.z,
        hidden: shape.hidden,
        locked: shape.locked,
        opacity: shape.opacity,
        frameId: shape.frameId,
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
      final updated = _attachOrDetachFrame(moved, state.elements);
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
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['cx'] = event.center.dx
      ..['cy'] = event.center.dy;
    final moved = CanvasElement.fromMap(shape.id, data);
    final host = _containingFrameFor(moved, state.elements);
    if (host == null) {
      data.remove('frameId');
    } else {
      data['frameId'] = host.id;
      if (moved.z <= host.z) {
        data['z'] = _nextZIndex();
      }
    }
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
    if (shape is TableElement) {
      await _updateElementMeta(
        shape.id,
        {'rotation': normalized},
        emit,
        syncConnectors: true,
      );
      _announceUndoable(emit, _singleActionMessage('Rotated'));
      return;
    }
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    )..['rotation'] = normalized;
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
      final newW = (event.width > 0 ? event.width : event.size).clamp(
        40.0,
        480.0,
      );
      final ratio = shape.width > 0 ? shape.height / shape.width : 1.0;
      final newH = (event.height > 0 ? event.height : newW * ratio).clamp(
        40.0,
        480.0,
      );
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
    if (shape is FrameElement) {
      final width = (event.width > 0 ? event.width : event.size)
          .clamp(120.0, 4000.0)
          .toDouble();
      final ratio = shape.width > 0 ? shape.height / shape.width : 1.0;
      final height = (event.height > 0 ? event.height : width * ratio)
          .clamp(80.0, 4000.0)
          .toDouble();
      await _onUpdateFrame(
        CanvasUpdateFrame(elementId: shape.id, width: width, height: height),
        emit,
        verb: 'Resized',
      );
      return;
    }
    if (shape is TableElement) {
      final minW = TableElement.minCellWidth * shape.columns;
      final minH = TableElement.minCellHeight * shape.rows;
      final width = (event.width > 0 ? event.width : event.size)
          .clamp(minW, 4000.0)
          .toDouble();
      final ratio = shape.width > 0 ? shape.height / shape.width : 0.5;
      final height = (event.height > 0 ? event.height : width * ratio)
          .clamp(minH, 4000.0)
          .toDouble();
      await _onUpdateTableStyle(
        CanvasUpdateTableStyle(
          tableId: shape.id,
          width: width,
          height: height,
        ),
        emit,
      );
      return;
    }
    final clampedSize = event.size.clamp(24.0, 320.0);
    if (shape is TextElement) {
      // Text has no `size`: the resize handle sets its box width, and the
      // height follows from how the text wraps at that width.
      final width = (event.width > 0 ? event.width : clampedSize)
          .clamp(40.0, 4000.0)
          .toDouble();
      await _onUpdateText(
        CanvasUpdateText(elementId: shape.id, width: width),
        emit,
        infoMessage: _singleActionMessage('Resized'),
      );
      return;
    }
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    );
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    )..['isFilled'] = event.isFilled;
    emit(state.copyWith(selectedShapeIsFilled: event.isFilled));
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Updated'));
    }
  }

  Future<void> _onUpdateShapeFill(
    CanvasUpdateShapeFill event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final element = event.shapeId != null
        ? _findElement(event.shapeId!)
        : _selectedShape();
    if (element is! ShapeElement || element.locked) return;
    final data = Map<String, dynamic>.from(element.toMap());
    final mode = event.fillMode;
    if (mode != null) {
      data['fillMode'] = mode;
      data['isFilled'] = mode != 'none';
    }
    if (event.fillColor != null) {
      data['fillColor'] = event.fillColor!.value;
    }
    if (event.gradientStart != null) {
      data['gradientStart'] = event.gradientStart!.value;
    }
    if (event.gradientEnd != null) {
      data['gradientEnd'] = event.gradientEnd!.value;
    }
    if (event.gradientAngle != null) {
      data['gradientAngle'] = event.gradientAngle;
    }
    if (await _updateShape(element.id, data, emit)) {
      if (mode != null) {
        emit(state.copyWith(selectedShapeIsFilled: mode != 'none'));
      }
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    )..['color'] = event.color.value;
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Recolored'));
    }
  }

  Future<void> _onUpdateSelectedShapeStrokeColor(
    CanvasUpdateSelectedShapeStrokeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    )..['strokeColor'] = event.strokeColor.value;
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Recolored'));
    }
  }

  Future<void> _onFlipSelectedShape(
    CanvasFlipSelectedShape event,
    Emitter<CanvasState> emit,
  ) async {
    final shape = _selectedShape();
    if (shape == null || shape.locked || !_ensureCanEdit(emit)) return;
    if (shape is! ShapeElement) return;
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    );
    if (event.horizontal) {
      data['flipH'] = !_parseBool(data['flipH']);
    }
    if (event.vertical) {
      data['flipV'] = !_parseBool(data['flipV']);
    }
    final changed = await _updateShape(shape.id, data, emit);
    if (changed) {
      _announceUndoable(emit, _singleActionMessage('Flipped'));
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
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    );
    _applyPendingShapeEdits(data, event.pendingData);
    if (shape is StickyNoteElement &&
        event.pendingData.containsKey('size') &&
        !event.pendingData.containsKey('width') &&
        !event.pendingData.containsKey('height')) {
      final size = _toDoubleValue(data['size']);
      if (size != null) {
        final noteSize = size.clamp(40.0, 480.0);
        data['width'] = noteSize;
        data['height'] = noteSize;
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
    final updated = _attachOrDetachFrame(
      element.copyWith(points: newPoints),
      state.elements,
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

  Future<void> _onFillStroke(
    CanvasFillStroke event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final element = _findElement(event.strokeId);
    if (element is! StrokeElement || element.locked) return;
    final data = Map<String, dynamic>.from(element.toMap())
      ..['fillColor'] = event.color.value;
    if (await _updateStroke(element.id, data, emit)) {
      _announceUndoable(emit, _singleActionMessage('Filled'));
    }
  }

  Future<void> _onClearStrokeFill(
    CanvasClearStrokeFill event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    final element = _findElement(event.strokeId);
    if (element is! StrokeElement || element.locked) return;
    final data = Map<String, dynamic>.from(element.toMap())
      ..remove('fillColor');
    if (await _updateStroke(element.id, data, emit)) {
      _announceUndoable(emit, _singleActionMessage('Fill removed'));
    }
  }

  Future<void> _onUpdateSelectionStyle(
    CanvasUpdateSelectionStyle event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (event.ids.isEmpty) return;
    final idSet = event.ids;
    final updated = <CanvasElement>{};
    final writes = <_CrdtWrite>[];
    for (final element in state.elements) {
      if (!idSet.contains(element.id) || element is LayerElement) continue;
      final data = Map<String, dynamic>.from(element.toMap());
      var changed = false;
      if (event.color != null) {
        final color = event.color!;
        switch (element) {
          case ShapeElement e:
            data['color'] = color.value;
            if (e.effectiveFillMode != 'none') {
              data['fillColor'] = color.value;
            }
            changed = true;
          case TextElement _:
          case StickyNoteElement _:
          case FrameElement _:
          case ConnectorElement _:
          case StrokeElement _:
            data['color'] = color.value;
            changed = true;
          case TableElement _:
            data['borderColor'] = color.toARGB32();
            changed = true;
          case ImageElement _:
          case LayerElement _:
            break;
        }
      }
      if (event.opacity != null) {
        data['opacity'] = event.opacity!.clamp(0.0, 1.0);
        changed = true;
      }
      if (event.locked != null) {
        data['locked'] = event.locked;
        changed = true;
      }
      if (event.visible != null) {
        data['hidden'] = !event.visible!;
        changed = true;
      }
      if (!changed) continue;
      final parsed = CanvasElement.fromMap(element.id, data);
      updated.add(parsed);
      writes.add((
        action: 'update',
        type: _elementType(element),
        objectId: element.id,
        data: data,
      ));
    }
    if (writes.isEmpty) return;
    final updatedById = {for (final element in updated) element.id: element};
    final next = [
      for (final element in state.elements) updatedById[element.id] ?? element,
    ]..sort(_compareByZ);
    emit(
      state.copyWith(
        elements: next,
        selectedIds: event.visible == false
            ? state.selectedIds.difference(idSet)
            : state.selectedIds,
        selectedShapeId: event.visible == false
            ? (idSet.contains(state.selectedShapeId)
                  ? null
                  : state.selectedShapeId)
            : state.selectedShapeId,
      ),
    );
    await _saveCrdtBatch(writes, emit);
    _announceUndoable(emit, _singleActionMessage('Selection updated'));
  }

  Future<void> _onMoveSelectionToLayer(
    CanvasMoveSelectionToLayer event,
    Emitter<CanvasState> emit,
  ) async {
    if (!_ensureCanEdit(emit)) return;
    if (event.ids.isEmpty) return;
    if (event.layerId != null &&
        !state.elements.whereType<LayerElement>().any(
          (layer) => layer.id == event.layerId,
        )) {
      return;
    }
    final changed = <LayerElement>[];
    for (final layer in state.elements.whereType<LayerElement>()) {
      final nextIds = <String>[
        for (final id in layer.elementIds)
          if (!event.ids.contains(id)) id,
        if (layer.id == event.layerId) ...event.ids,
      ];
      var same = nextIds.length == layer.elementIds.length;
      if (same) {
        for (var i = 0; i < nextIds.length; i++) {
          if (nextIds[i] != layer.elementIds[i]) {
            same = false;
            break;
          }
        }
      }
      if (same) continue;
      changed.add(
        LayerElement(
          id: layer.id,
          z: layer.z,
          hidden: layer.hidden,
          locked: layer.locked,
          opacity: layer.opacity,
          name: layer.name,
          blendMode: layer.blendMode,
          elementIds: nextIds,
        ),
      );
    }
    if (changed.isEmpty) return;
    final byId = {for (final layer in changed) layer.id: layer};
    emit(
      state.copyWith(
        elements: [
          for (final element in state.elements) byId[element.id] ?? element,
        ],
      ),
    );
    await _saveCrdtBatch([
      for (final layer in changed)
        (
          action: 'update',
          type: 'layer',
          objectId: layer.id,
          data: layer.toMap(),
        ),
    ], emit);
    _announceUndoable(emit, _singleActionMessage('Moved to layer'));
  }

  Future<void> _onRetrySync(
    CanvasRetrySync event,
    Emitter<CanvasState> emit,
  ) async {
    final canvasService = _canvasService;
    if (canvasService == null || _boardId.isEmpty) return;
    emit(
      state.copyWith(syncStatus: CanvasSyncStatus.syncing, syncMessage: null),
    );
    try {
      final succeeded = await canvasService.retryPendingSync(_boardId);
      emit(
        state.copyWith(
          syncStatus: succeeded
              ? CanvasSyncStatus.saved
              : CanvasSyncStatus.offline,
          syncMessage: succeeded
              ? null
              : 'Still offline. Changes are saved on this device.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          syncStatus: CanvasSyncStatus.offline,
          syncMessage: 'Still offline. Changes are saved on this device.',
        ),
      );
    }
  }

  Future<void> _onUpdateSelectedStrokeColor(
    CanvasUpdateSelectedStrokeColor event,
    Emitter<CanvasState> emit,
  ) async {
    final element = _selectedShape();
    if (element is! StrokeElement || element.locked || !_ensureCanEdit(emit)) {
      return;
    }
    final data = Map<String, dynamic>.from(
      _committedElementPayload(element.id) ?? element.toMap(),
    )..['color'] = event.color;
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(element.id) ?? element.toMap(),
    )..['strokeWidth'] = event.strokeWidth;
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(element.id) ?? element.toMap(),
    )..['opacity'] = event.opacity;
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(element.id) ?? element.toMap(),
    )
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
        frameId: el.frameId,
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
        data['width'] = nextSize.clamp(40.0, 480.0);
        data['height'] = (nextSize * ratio).clamp(40.0, 480.0);
      } else {
        data['width'] = (rawNextW ?? nextSize).clamp(40.0, 480.0);
        data['height'] = (rawNextH ?? existing.height).clamp(40.0, 480.0);
      }
    }
    if (existing is ImageElement) {
      data['imageBase64'] ??= existing.imageBase64;
      _carryAiImageFields(data, existing);
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
    final currentFrameId = existing.frameId;
    final nextFrameId = data['frameId'] as String?;
    final unchanged = existing is ShapeElement
        ? _shapeFingerprint(shapeId, existing.toMap()) ==
                  _shapeFingerprint(shapeId, data) &&
              nextFrameId == currentFrameId
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
              nextZ == currentZ &&
              nextFrameId == currentFrameId;
    if (unchanged) return false;
    final fingerprint = '${_shapeFingerprint(shapeId, data)}|frame:$nextFrameId';
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
    final data = Map<String, dynamic>.from(
      _committedElementPayload(shape.id) ?? shape.toMap(),
    );
    _applyPendingShapeEdits(data, event.pendingData);
    if (shape is StickyNoteElement &&
        event.pendingData.containsKey('size') &&
        !event.pendingData.containsKey('width') &&
        !event.pendingData.containsKey('height')) {
      final size = _toDoubleValue(data['size']);
      if (size != null) {
        final noteSize = size.clamp(40.0, 480.0);
        data['width'] = noteSize;
        data['height'] = noteSize;
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
    if (shape == null ||
        shape.locked ||
        canvasService == null ||
        _boardId.isEmpty) {
      return;
    }
    if (!_ensureCanEdit(emit)) return;
    final data = Map<String, dynamic>.from(_committedElementPayload(shape.id) ?? shape.toMap())
      ..['size'] = event.size.clamp(24.0, 320.0);
    if (shape is ImageElement) {
      data.remove('imageBase64');
      data['width'] = event.size.clamp(80.0, 720.0);
      data['height'] = event.size.clamp(80.0, 720.0);
    } else if (shape is StickyNoteElement) {
      final newW = (event.width > 0 ? event.width : event.size).clamp(
        40.0,
        480.0,
      );
      final ratio = shape.width > 0 ? shape.height / shape.width : 1.0;
      data['width'] = newW;
      data['height'] = (event.height > 0 ? event.height : newW * ratio).clamp(
        40.0,
        480.0,
      );
    } else if (shape is TextElement) {
      // Preview the wider/narrower text box; the receiver measures the height
      // from the wrapping width, so a stale height would draw the wrong box.
      data['width'] = (event.width > 0 ? event.width : event.size)
          .clamp(40.0, 4000.0)
          .toDouble();
      data.remove('height');
    } else if (shape is ShapeElement && (event.width > 0 || event.height > 0)) {
      final w = event.width.clamp(1.0, 4000.0);
      final h = shape.isLinear ? 0.0 : event.height.clamp(1.0, 4000.0);
      data['width'] = w;
      data['height'] = h;
      data['size'] = math.max(w, h);
    } else if (shape is FrameElement) {
      final w = (event.width > 0 ? event.width : event.size)
          .clamp(120.0, 4000.0)
          .toDouble();
      final ratio = shape.width > 0 ? shape.height / shape.width : 1.0;
      data['width'] = w;
      data['height'] = (event.height > 0 ? event.height : w * ratio)
          .clamp(80.0, 4000.0)
          .toDouble();
    } else if (shape is TableElement) {
      final minW = TableElement.minCellWidth * shape.columns;
      final minH = TableElement.minCellHeight * shape.rows;
      final w = (event.width > 0 ? event.width : event.size)
          .clamp(minW, 4000.0)
          .toDouble();
      final ratio = shape.width > 0 ? shape.height / shape.width : 0.5;
      data['width'] = w;
      data['height'] = (event.height > 0 ? event.height : w * ratio)
          .clamp(minH, 4000.0)
          .toDouble();
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
      _remotePreviewReceivedAt.remove(id);
      if (_remotePreviewElements.remove(id) != null) {
        _remotePreviewDeletedIds.add(id);
        _remotePreviewDeletedAt[id] = DateTime.now();
      }
    }
    final changes = <({String id, Map<String, dynamic>? payload})>[];
    final current = adapter.materializeElements();
    for (final id in deletedElementIds) {
      if (current.containsKey(id)) {
        _myCommittedPayload[id] = null;
        changes.add((id: id, payload: null));
      }
    }
    for (final stroke in createdStrokes) {
      final payload = <String, dynamic>{'type': 'stroke', ...stroke.toMap()};
      _myCommittedPayload[stroke.id] = _deepCopyPayload(payload);
      changes.add((id: stroke.id, payload: payload));
    }
    final update = adapter.applyBatch(changes, origin: 'local');
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
        final replacement = element.copyWith(
          // Deterministic ids keep the live erase idempotent: re-splitting the
          // same stroke while dragging reuses the same fragments instead of
          // spawning (and duplicating) new ones on every sample.
          id: '${element.id}~e$index',
          // Fragments inherit the source stroke's z, so erasing never lifts a
          // stroke above shapes it was drawn behind.
          points: segment,
          // Per-point samples no longer line up with the shortened fragment.
          pressures: const [],
          tilts: const [],
          // An open fragment should not keep filling the original closed loop.
          clearFillColor: true,
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
    // Keep the current user's effective role in sync with live member changes
    // (e.g. when the owner promotes/demotes them from the Members tray)
    // without waiting for a separate board metadata snapshot.
    String? nextRole;
    final uid = state.currentUserId;
    if (uid.isNotEmpty && _currentUserRole != Board.roleOwner) {
      for (final member in event.members) {
        if (member.uid == uid) {
          nextRole =
              (member.role == Board.roleEditor ||
                  member.role == Board.roleOwner)
              ? member.role
              : Board.roleViewer;
          break;
        }
      }
    }

    if (nextRole != null && nextRole != _currentUserRole) {
      final wasOwner = _currentUserRole == Board.roleOwner;
      _currentUserRole = nextRole;
      _syncHistorySubscriptions();
      if (!wasOwner && _currentUserRole == Board.roleOwner) {
        _ensureHistoryFeedSubscription();
        unawaited(_refreshLiveTail());
      }
      if (nextRole == Board.roleViewer && state.currentStroke.isNotEmpty) {
        _activeStrokeId = null;
        _strokeStabilizer = null;
        _strokeClock.stop();
      }
      emit(
        state.copyWith(
          boardMembers: event.members,
          currentUserRole: nextRole,
          currentStroke: nextRole == Board.roleViewer ? const [] : null,
          currentStrokePressures:
              nextRole == Board.roleViewer ? const [] : null,
          currentStrokeTilts: nextRole == Board.roleViewer ? const [] : null,
        ),
      );
      return;
    }

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
    try {
      final canvasService = _canvasService;
      if (canvasService == null || _boardId.isEmpty) return;
      await canvasService.saveBoardPreview(_boardId, event.pngBytes);
    } catch (_) {
    } finally {
      if (event.completer != null && !event.completer!.isCompleted) {
        event.completer!.complete();
      }
    }
  }

  Future<void> _onSetBoardPausedRequested(
    CanvasSetBoardPausedRequested event,
    Emitter<CanvasState> emit,
  ) async {
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(error: 'Only the board owner can pause or resume this board.'));
      return;
    }
    final boardService = _boardService;
    if (boardService == null || _boardId.isEmpty) return;

    try {
      await boardService.setBoardPaused(_boardId, isPaused: event.isPaused);
      emit(
        state.copyWith(
          isPaused: event.isPaused,
          currentStroke: event.isPaused ? const [] : null,
          infoMessage: event.isPaused
              ? 'Board paused. No one can edit until you resume it.'
              : 'Board resumed. Editing is enabled.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          error: 'Failed to update board pause state. Please try again.',
        ),
      );
    }
  }

  int _activeExportCount = 0;

  CanvasBoardSettings _boardSettings = const CanvasBoardSettings();

  Future<void> _onExportBoardRequested(
    CanvasExportBoardRequested event,
    Emitter<CanvasState> emit,
  ) async {
    _activeExportCount++;
    emit(state.copyWith(isExporting: true, error: null));
    try {
      final boardTitle = state.boardTitle ?? 'Board';
      final options =
          event.options ?? CanvasExportOptions(format: event.format);

      // Web: the export is bytes, so "share" uses the browser's share sheet
      // (Web Share API, through share_plus) and falls back to a download when
      // the browser has no share support. Phones continue below, unchanged.
      if (kIsWeb) {
        final exported = await _boardExportService.renderCanvasExport(
          boardTitle: boardTitle,
          elements: state.elements,
          options: options,
          settings: state.boardSettings,
          selectedIds: state.selectedIds,
        );
        var shareOutcome = BoardShareOutcome.dismissed;
        if (event.shareAfterExport) {
          try {
            final result = await SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile.fromData(
                    exported.bytes,
                    mimeType: exported.mimeType,
                    name: exported.fileName,
                  ),
                ],
                subject: boardTitle,
                title: boardTitle,
              ),
            );
            shareOutcome = switch (result.status) {
              ShareResultStatus.success => BoardShareOutcome.shared,
              ShareResultStatus.dismissed => BoardShareOutcome.dismissed,
              ShareResultStatus.unavailable => BoardShareOutcome.unavailable,
            };
          } catch (_) {
            shareOutcome = BoardShareOutcome.unavailable;
          }
        }
        if (shareOutcome != BoardShareOutcome.shared &&
            shareOutcome != BoardShareOutcome.dismissed) {
          await _boardExportService.saveExportAsDownload(exported);
        }
        _activeExportCount = math.max(0, _activeExportCount - 1);
        final extension = options.format.name.toUpperCase();
        emit(
          state.copyWith(
            isExporting: _activeExportCount > 0,
            exportSuccessMessage: switch (shareOutcome) {
              BoardShareOutcome.shared =>
                'Board shared as $extension (${exported.fileName}).',
              BoardShareOutcome.dismissed => 'Sharing cancelled.',
              BoardShareOutcome.unavailable =>
                'Board downloaded as $extension (${exported.fileName}).',
            },
          ),
        );
        return;
      }

      final file = await _boardExportService.exportCanvas(
        boardTitle: boardTitle,
        elements: state.elements,
        options: options,
        settings: state.boardSettings,
        selectedIds: state.selectedIds,
      );

      var shareOutcome = BoardShareOutcome.dismissed;
      if (event.shareAfterExport) {
        shareOutcome = await _boardExportService.shareBoardFile(
          file: file,
          boardTitle: boardTitle,
          sharePositionOrigin: event.sharePositionOrigin,
        );
      }

      final ext = options.format.name.toUpperCase();
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
        case 'pending_exists':
          return 'You already have a pending undo request on this board. '
              'The owner has to approve or deny it first.';
        case 'board_missing':
          return 'This board no longer exists.';
        case 'invalid_request':
          return error.message.isNotEmpty && error.message != error.code
              ? error.message
              : 'That undo request was not accepted. Please try again.';
        case 'submit_unavailable':
          return 'Could not reach the undo request service. Please retry.';
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
    final service = _historyService;
    if (service == null || _boardId.isEmpty || isClosed) return;
    if (_currentUserRole == Board.roleOwner) {
      _myUndoRequestsSub?.cancel();
      _myUndoRequestsSub = null;
      _undoRequestsSub ??= service.watchUndoRequests(_boardId).listen(
        (requests) {
          if (!isClosed) add(CanvasUndoRequestsUpdated(requests));
        },
        onError: (Object error, StackTrace stackTrace) {
          // A listener that errored (rules/network hiccup while the board doc
          // was still loading) never delivers again, and `??=` would keep it
          // forever. Drop it so the next board update or history-screen open
          // subscribes afresh — otherwise undo requests silently never reach
          // the owner.
          debugPrint(
            'Undo request feed failed for board $_boardId: $error',
          );
          unawaited(_undoRequestsSub?.cancel());
          _undoRequestsSub = null;
        },
      );
    } else {
      _undoRequestsSub?.cancel();
      _undoRequestsSub = null;
      if (_currentUserRole == Board.roleEditor &&
          state.currentUserId.isNotEmpty) {
        // Members see their own pending request so the canvas can say it is
        // waiting on the owner instead of letting them send it twice.
        _myUndoRequestsSub ??= service
            .watchMyUndoRequests(_boardId, state.currentUserId)
            .listen(
              (requests) {
                if (!isClosed) add(CanvasMyUndoRequestsUpdated(requests));
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint(
                  'My undo request feed failed for board $_boardId: $error',
                );
                unawaited(_myUndoRequestsSub?.cancel());
                _myUndoRequestsSub = null;
              },
            );
      } else {
        _myUndoRequestsSub?.cancel();
        _myUndoRequestsSub = null;
      }
    }
  }

  /// Owner-only: subscribe to the archived-block feed. Idempotent so every
  /// history-screen entry point (ToolsTray button, role resolving late) can
  /// call it without stacking duplicate Firestore listeners.
  void _ensureHistoryFeedSubscription() {
    final service = _historyService;
    if (service == null || _currentUserRole != Board.roleOwner) return;
    if (_boardId.isEmpty || isClosed || _historyFeedSub != null) return;
    _historyFeedSub = service.watchActivityFeed(_boardId).listen(
      (blocks) {
        if (!isClosed) add(CanvasHistoryFeedUpdated(blocks));
      },
      onError: (_) {},
    );
  }

  List<BoardActivityBlock> _composeActivityBlocks() {
    final highestArchived = _archivedBlocks.isEmpty
        ? 0
        : _archivedBlocks.map((b) => b.toVersion).reduce(math.max);
    final tail = _liveTailBlock;
    if (tail == null ||
        tail.operationCount <= 0 ||
        tail.toVersion <= highestArchived) {
      return _archivedBlocks;
    }
    return [tail, ..._archivedBlocks];
  }

  void _scheduleLiveTailRefresh() {
    if (isClosed ||
        _currentUserRole != Board.roleOwner ||
        _historyService == null ||
        _boardId.isEmpty) {
      return;
    }
    _liveTailDebounceTimer?.cancel();
    _liveTailDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      _liveTailDebounceTimer = null;
      unawaited(_refreshLiveTail());
    });
  }

  Future<void> _refreshLiveTail() async {
    final service = _historyService;
    if (isClosed ||
        _currentUserRole != Board.roleOwner ||
        service == null ||
        _boardId.isEmpty) {
      return;
    }
    try {
      final block = await service.getLiveTail(_boardId);
      if (!isClosed) {
        add(CanvasHistoryLiveTailUpdated(block));
      }
    } catch (_) {
      // Best-effort live tail sync; archived blocks from Firestore remain shown.
    }
  }

  List<BoardActivityBlock> _mergeArchivedBlocks(
    List<BoardActivityBlock> existing,
    List<BoardActivityBlock> incoming,
  ) {
    final byId = <String, BoardActivityBlock>{
      for (final b in existing) b.blockId: b,
      for (final b in incoming) b.blockId: b,
    };
    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => b.toVersion.compareTo(a.toVersion));
    return merged;
  }

  int? get _oldestArchivedFromVersion {
    if (_archivedBlocks.isEmpty) return null;
    return _archivedBlocks.map((b) => b.fromVersion).reduce(math.min);
  }

  Future<void> _onHistoryFeedRequested(
    CanvasHistoryFeedRequested event,
    Emitter<CanvasState> emit,
  ) async {
    if (_currentUserRole != Board.roleOwner) return;
    final service = _historyService;
    if (event.forceRefresh) {
      emit(state.copyWith(isHistoryLoading: true, error: null));
      unawaited(_historyFeedSub?.cancel());
      _historyFeedSub = null;
    }
    _syncHistorySubscriptions();
    _ensureHistoryFeedSubscription();
    if (service == null || _boardId.isEmpty) {
      if (event.forceRefresh) {
        emit(state.copyWith(isHistoryLoading: false));
      }
      return;
    }
    try {
      final page = await service.getVersions(
        _boardId,
        forceRefresh: event.forceRefresh,
      );
      if (isClosed) return;
      if (page.blocks.isNotEmpty) {
        _archivedBlocks = _mergeArchivedBlocks(_archivedBlocks, page.blocks);
      }
      if (page.liveTail != null) {
        _liveTailBlock = page.liveTail;
      } else {
        try {
          _liveTailBlock = await service.getLiveTail(_boardId);
        } catch (_) {}
      }
      if (isClosed) return;
      final oldestFrom = _oldestArchivedFromVersion;
      final hasMore = page.hasMore || (oldestFrom != null && oldestFrom > 1);
      final nextBefore =
          page.nextBeforeVersion ?? (oldestFrom != null && oldestFrom > 1 ? oldestFrom : null);
      emit(state.copyWith(
        isHistoryLoading: false,
        activityBlocks: _composeActivityBlocks(),
        hasMoreHistoryVersions: hasMore,
        historyNextBeforeVersion: nextBefore,
      ));
    } catch (_) {
      unawaited(_refreshLiveTail());
      if (!isClosed && event.forceRefresh) {
        emit(state.copyWith(isHistoryLoading: false));
      }
    }
  }

  Future<void> _onHistoryLoadOlderVersionsRequested(
    CanvasHistoryLoadOlderVersionsRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null || _currentUserRole != Board.roleOwner) return;
    if (_boardId.isEmpty || state.isHistoryLoading) return;
    final beforeVersion =
        event.beforeVersion ??
        state.historyNextBeforeVersion ??
        _oldestArchivedFromVersion;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final page = await service.getVersions(
        _boardId,
        beforeVersion: beforeVersion,
      );
      if (isClosed) return;
      if (page.blocks.isNotEmpty) {
        _archivedBlocks = _mergeArchivedBlocks(_archivedBlocks, page.blocks);
      }
      final oldestFrom = _oldestArchivedFromVersion;
      final hasMore = page.hasMore && (oldestFrom != null && oldestFrom > 1);
      final nextBefore = page.nextBeforeVersion ??
          (hasMore ? oldestFrom : null);
      emit(state.copyWith(
        isHistoryLoading: false,
        activityBlocks: _composeActivityBlocks(),
        hasMoreHistoryVersions: hasMore,
        historyNextBeforeVersion: nextBefore,
        infoMessage: page.blocks.isEmpty
            ? 'All available previous versions are already loaded.'
            : 'Loaded ${page.blocks.length} previous version(s).',
      ));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          isHistoryLoading: false,
          error: _historyMessage(e),
        ));
      }
    }
  }

  void _onHistoryFeedUpdated(
    CanvasHistoryFeedUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole != Board.roleOwner) return;
    _archivedBlocks = _mergeArchivedBlocks(_archivedBlocks, event.blocks);
    final oldestFrom = _oldestArchivedFromVersion;
    final hasMore =
        state.hasMoreHistoryVersions || (oldestFrom != null && oldestFrom > 1);
    final nextBefore =
        state.historyNextBeforeVersion ??
        (oldestFrom != null && oldestFrom > 1 ? oldestFrom : null);
    emit(state.copyWith(
      activityBlocks: _composeActivityBlocks(),
      hasMoreHistoryVersions: hasMore,
      historyNextBeforeVersion: nextBefore,
    ));
    unawaited(_refreshLiveTail());
  }

  void _onHistoryLiveTailUpdated(
    CanvasHistoryLiveTailUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole != Board.roleOwner) return;
    _liveTailBlock = event.block;
    emit(state.copyWith(activityBlocks: _composeActivityBlocks()));
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
      final scopeMode = request?.scopeMode ?? UndoRequestScopeMode.myChanges;
      if (request != null &&
          targetVersion != null &&
          (scopeIds.isNotEmpty || (area != null && area.isValid))) {
        try {
          final timeline = await service.getUserTimeline(
            _boardId,
            scopeMode == UndoRequestScopeMode.areaState
                ? ''
                : request.requesterUid,
            elementIds: scopeIds,
            area: area,
            scopeMode: scopeMode,
            afterVersion: targetVersion,
          );
          if (isClosed) return;
          if (timeline.ops.isNotEmpty && timeline.steps.isNotEmpty) {
            final requestedStop = BoardOperation(
              version: targetVersion,
              summary: 'Requested state (v$targetVersion)',
            );
            final scrub = HistoryScrub(
              stops: [requestedStop, ...timeline.ops],
              baseStateBytes: timeline.baseStateBytes,
              stepDeltas: [
                Uint8List(0),
                ..._alignedStepDeltas(timeline),
              ],
              targetUid: scopeMode == UndoRequestScopeMode.areaState
                  ? null
                  : request.requesterUid,
              elementIds: scopeIds,
              area: area,
              scopeMode: scopeMode,
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
        } catch (_) {
          // Fall back to plan-based comparison when timeline is unavailable.
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

  Future<void> _onHistoryEvidenceViewToggled(
    CanvasHistoryEvidenceViewToggled event,
    Emitter<CanvasState> emit,
  ) async {
    // The past/current toggle is shared by undo-request evidence and the
    // per-log compare screen (historyPreviewCompare). When a scrub slider is
    // active, toggling jumps between stop 0 (Requested) and lastIndex (Current).
    if (!state.isViewingHistory) return;
    final scrub = state.historyScrub;
    if (scrub != null) {
      final targetIndex = event.showDesired ? 0 : scrub.lastIndex;
      emit(state.copyWith(historyPreviewShowsDesired: event.showDesired));
      await _onHistoryScrubMoved(CanvasHistoryScrubMoved(targetIndex), emit);
      return;
    }
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
      isSelectingHistoryArea: false,
      activeTray: null,
      // Picking a new area starts from a clean canvas selection: whatever was
      // selected before (the previous area's elements) must not stay marked.
      selectedIds: enable ? const <String>{} : state.selectedIds,
      selectedShapeId: null,
    ));
  }

  void _onToggleOwnerAreaHistorySelection(
    CanvasToggleOwnerAreaHistorySelection event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(
        error: 'Only the board owner can view area history.',
      ));
      return;
    }
    final enable = event.enable ?? !state.isSelectingHistoryArea;
    if (enable && state.isViewingHistory) return;
    emit(state.copyWith(
      isSelectingHistoryArea: enable,
      isSelectingUndoRequestArea: false,
      activeTray: null,
      // A new area history selection replaces the previous one, including the
      // elements that were selected on the canvas.
      selectedIds: enable ? const <String>{} : state.selectedIds,
      selectedShapeId: null,
    ));
  }

  Future<void> _onHistoryAreaScrubRequested(
    CanvasHistoryAreaScrubRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    if (service == null) return;
    if (_currentUserRole != Board.roleOwner) {
      emit(state.copyWith(
        error: 'Only the board owner can view board history.',
      ));
      return;
    }
    final area = event.area;
    if (!area.isValid) {
      emit(state.copyWith(error: 'Select a valid area on the board first.'));
      return;
    }
    final returnTray = state.isViewingHistory
        ? state.historyPreviewReturnTray
        : state.activeTray;
    final returnUserUid = state.isViewingHistory
        ? state.historyPreviewReturnUserUid
        : state.selectedUserUid;
    emit(state.copyWith(
      isHistoryLoading: true,
      isSelectingHistoryArea: false,
      error: null,
    ));
    try {
      final timeline = await service.getUserTimeline(
        _boardId,
        '',
        elementIds: event.elementIds,
        area: area,
        scopeMode: UndoRequestScopeMode.areaState,
      );
      if (isClosed) return;
      if (timeline.ops.isEmpty || timeline.steps.isEmpty) {
        emit(state.copyWith(
          isHistoryLoading: false,
          error: 'No recorded changes were found in that part of the board.',
        ));
        return;
      }
      final beforeStop = BoardOperation(
        version: timeline.baseVersion,
        summary: 'Before changes in this area (v${timeline.baseVersion})',
      );
      final scrub = HistoryScrub(
        stops: [beforeStop, ...timeline.ops],
        baseStateBytes: timeline.baseStateBytes,
        stepDeltas: [
          Uint8List(0),
          ..._alignedStepDeltas(timeline),
        ],
        targetUid: null,
        elementIds: event.elementIds,
        area: area,
        scopeMode: UndoRequestScopeMode.areaState,
        hasMore: timeline.hasMore,
        nextBeforeVersion: timeline.nextBeforeVersion,
      );
      await _enterScrub(
        scrub,
        emit: emit,
        returnTray: returnTray,
        returnUserUid: returnUserUid,
        title:
            'Area history (${area.width.round()} × ${area.height.round()} px)',
        startIndex: scrub.lastIndex,
        focusBounds: Rect.fromLTWH(
          area.left,
          area.top,
          area.width,
          area.height,
        ),
        highlightElementIds: event.elementIds,
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          isHistoryLoading: false,
          error: _historyMessage(e),
        ));
      }
    }
  }

  // ──────────────────────────────────────────────
  // Member undo request (D5): desired-state flow
  // ──────────────────────────────────────────────

  void _onUndoRequestDraftStarted(
    CanvasUndoRequestDraftStarted event,
    Emitter<CanvasState> emit,
  ) {
    final existingMode = state.undoRequestDraft?.scopeMode;
    emit(state.copyWith(
      undoRequestDraft: UndoRequestDraft(
        elementIds: List<String>.unmodifiable(event.preselectedIds),
        area: event.area,
        scopeMode: event.scopeMode ?? existingMode ?? UndoRequestScopeMode.myChanges,
      ),
    ));
  }

  void _onUndoRequestDraftScopeModeChanged(
    CanvasUndoRequestDraftScopeModeChanged event,
    Emitter<CanvasState> emit,
  ) {
    final draft = state.undoRequestDraft ?? const UndoRequestDraft();
    emit(state.copyWith(
      undoRequestDraft: draft.withScopeMode(event.scopeMode),
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

  /// Loads the member's timeline (either their own changes or the whole area
  /// state according to `draft.scopeMode`) scoped to the draft's elements/area
  /// and opens the request scrub: stop 0 is the virtual "before these changes"
  /// state, the slider then walks through what changed in the scope.
  Future<void> _onUndoRequestPreviewRequested(
    CanvasUndoRequestPreviewRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    final draft = state.undoRequestDraft;
    if (service == null || draft == null) return;
    final scopeIds = draft.elementIds;
    final area = draft.area;
    final hasArea = area != null && area.isValid;
    if (scopeIds.isEmpty && !hasArea) {
      emit(state.copyWith(
        error: 'Select at least one element or board area first.',
      ));
      return;
    }
    final returnTray = state.activeTray;
    final returnUserUid = state.selectedUserUid;
    final isAreaState = draft.scopeMode == UndoRequestScopeMode.areaState;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final timeline = await service.getUserTimeline(
        _boardId,
        isAreaState ? '' : state.currentUserId,
        elementIds: scopeIds,
        area: area,
        scopeMode: draft.scopeMode,
      );
      if (isClosed) return;
      if (timeline.ops.isEmpty || timeline.steps.isEmpty) {
        emit(state.copyWith(
          isHistoryLoading: false,
          error: isAreaState
              ? 'No changes are recorded in that part of the board yet.'
              : 'No changes of yours are recorded in that scope yet.',
        ));
        return;
      }
      // Virtual first stop: the state before the page's first scoped op.
      final beforeStop = BoardOperation(
        version: timeline.baseVersion,
        summary: isAreaState
            ? 'Before changes in this area (v${timeline.baseVersion})'
            : 'Before my changes (v${timeline.baseVersion})',
      );
      final scrub = HistoryScrub(
        stops: [beforeStop, ...timeline.ops],
        baseStateBytes: timeline.baseStateBytes,
        stepDeltas: [
          Uint8List(0),
          ..._alignedStepDeltas(timeline),
        ],
        targetUid: isAreaState ? null : state.currentUserId,
        elementIds: scopeIds,
        area: area,
        scopeMode: draft.scopeMode,
        hasMore: timeline.hasMore,
        nextBeforeVersion: timeline.nextBeforeVersion,
      );
      await _enterScrub(
        scrub,
        emit: emit,
        returnTray: returnTray,
        returnUserUid: returnUserUid,
        title: isAreaState
            ? 'Your undo request · Whole area state'
            : 'Your undo request · Only my changes',
        startIndex: 0,
        focusBounds: hasArea
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
    // One pending request per board: submitting again would be rejected by the
    // server, so refuse locally and point the member at the one waiting.
    if (state.myPendingUndoRequest != null) {
      emit(state.copyWith(
        isHistoryLoading: false,
        error:
            'You already have an undo request waiting for the owner. '
            'They have to approve or deny it first.',
      ));
      return;
    }
    final reason = event.reason.trim();
    if (reason.isEmpty) {
      emit(state.copyWith(error: 'A reason is required.'));
      return;
    }
    final hasArea = draft.area != null && draft.area!.isValid;
    if (scrub == null || (draft.elementIds.isEmpty && !hasArea)) {
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
        scopeMode: draft.scopeMode,
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
      area: event.area,
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
    UndoRequestArea? area,
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
        area: area,
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
      elementIds: event.elementIds,
      area: event.area,
      requestId: event.requestId,
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
        stepDeltas: _alignedStepDeltas(timeline),
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

  /// Applies one update during a history replay.
  ///
  /// An archived update can be unreadable — a partial or corrupt CRDT payload
  /// recorded by an older client — and `applyUpdate` answers with a bare
  /// `RangeError`. Letting it escape aborted the whole replay (the member's
  /// undo-request preview died with "RangeError (length): …"), so a bad delta
  /// is skipped and the replay continues from the last state that did apply.
  void _applyHistoryUpdate(
    CanvasDocAdapter adapter,
    Uint8List bytes, {
    required String label,
  }) {
    if (bytes.isEmpty) return;
    try {
      adapter.applyUpdate(bytes, origin: 'remote');
    } catch (error, stackTrace) {
      debugPrint('Skipped unreadable history $label: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Materializes a replayed document, falling back to [fallback] when the
  /// document is left unreadable by an update that could not be applied.
  List<CanvasElement> _materializeHistoryElements(
    CanvasDocAdapter adapter,
    List<CanvasElement> fallback,
  ) {
    try {
      return _rebuildElementsFromCrdtState(adapter.materializeElements());
    } catch (error, stackTrace) {
      debugPrint('Unreadable history replay state: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallback;
    }
  }

  /// Aligns `timeline.steps` 1:1 with `timeline.ops` by version, falling back
  /// to positional index or an empty delta when the server omitted a step.
  List<Uint8List> _alignedStepDeltas(UserTimeline timeline) {
    final byVersion = <int, Uint8List>{
      for (final step in timeline.steps) step.version: step.deltaBytes,
    };
    return [
      for (var i = 0; i < timeline.ops.length; i++)
        byVersion[timeline.ops[i].version] ??
            (i < timeline.steps.length
                ? timeline.steps[i].deltaBytes
                : Uint8List(0)),
    ];
  }

  Future<HistoryScrub> _computeScrubWithDiffs(HistoryScrub scrub) async {
    if (scrub.stops.isEmpty) return scrub;
    final stepElements = <List<CanvasElement>>[];
    final adapter = await CanvasDocAdapterFactory.create();
    _applyHistoryUpdate(adapter, scrub.baseStateBytes, label: 'base state');
    for (var i = 0; i < scrub.stops.length; i++) {
      _applyHistoryUpdate(
        adapter,
        scrub.deltaAt(i),
        label: 'step ${i + 1} of the replay',
      );
      stepElements.add(
        _materializeHistoryElements(
          adapter,
          stepElements.isEmpty ? const <CanvasElement>[] : stepElements.last,
        ),
      );
    }
    final reference =
        state.elements.isNotEmpty ? state.elements : stepElements.last;
    final refById = <String, CanvasElement>{
      for (final e in reference) e.id: e,
    };
    final scopeSet = scrub.elementIds.toSet();
    final area = scrub.area;
    final areaRect = (area != null && area.isValid)
        ? Rect.fromLTWH(area.left, area.top, area.width, area.height)
        : null;

    bool inScope(String id, CanvasElement? a, CanvasElement? b) {
      if (scopeSet.isEmpty && areaRect == null) return true;
      if (scopeSet.contains(id)) return true;
      if (areaRect != null) {
        if (a != null && elementBounds(a)?.overlaps(areaRect) == true) {
          return true;
        }
        if (b != null && elementBounds(b)?.overlaps(areaRect) == true) {
          return true;
        }
      }
      return false;
    }

    final diffs = <HistoryScrubDiff>[];
    for (final stopList in stepElements) {
      final stopById = <String, CanvasElement>{
        for (final e in stopList) e.id: e,
      };
      final allIds = <String>{...refById.keys, ...stopById.keys};
      var added = 0;
      var updated = 0;
      var deleted = 0;
      final changed = <String>[];
      for (final id in allIds) {
        final cur = refById[id];
        final past = stopById[id];
        if (!inScope(id, cur, past)) continue;
        if (cur != null && past == null) {
          added++;
          changed.add(id);
        } else if (cur == null && past != null) {
          deleted++;
          changed.add(id);
        } else if (cur != null && past != null && cur != past) {
          updated++;
          changed.add(id);
        }
      }
      diffs.add(
        HistoryScrubDiff(
          addedCount: added,
          updatedCount: updated,
          deletedCount: deleted,
          changedElementIds: changed,
        ),
      );
    }

    return HistoryScrub(
      stops: scrub.stops,
      baseStateBytes: scrub.baseStateBytes,
      stepDeltas: scrub.stepDeltas,
      targetUid: scrub.targetUid,
      elementIds: scrub.elementIds,
      area: scrub.area,
      scopeMode: scrub.scopeMode,
      stepDiffs: diffs,
      hasMore: scrub.hasMore,
      nextBeforeVersion: scrub.nextBeforeVersion,
    );
  }

  List<CanvasElement> _composeScopedScrubPreviewElements(
    HistoryScrub scrub,
    List<CanvasElement> rawPreviewElements,
  ) {
    final area = scrub.area;
    final hasArea = area != null && area.isValid;
    if (state.elements.isEmpty || (scrub.elementIds.isEmpty && !hasArea)) {
      return rawPreviewElements;
    }
    final areaRect = hasArea
        ? Rect.fromLTWH(area.left, area.top, area.width, area.height)
        : null;
    final scopeSet = <String>{...scrub.elementIds};
    if (areaRect != null) {
      for (final e in state.elements) {
        if (elementBounds(e)?.overlaps(areaRect) == true) scopeSet.add(e.id);
      }
      for (final e in rawPreviewElements) {
        if (elementBounds(e)?.overlaps(areaRect) == true) scopeSet.add(e.id);
      }
    }
    if (scopeSet.isEmpty) return rawPreviewElements;
    final rawById = <String, CanvasElement>{
      for (final e in rawPreviewElements) e.id: e,
    };
    final liveById = <String, CanvasElement>{
      for (final e in state.elements) e.id: e,
    };
    final composed = <String, Map<String, dynamic>>{};
    for (final entry in liveById.entries) {
      if (!scopeSet.contains(entry.key)) {
        composed[entry.key] = entry.value.toMap();
      }
    }
    for (final id in scopeSet) {
      final past = rawById[id];
      if (past != null) {
        composed[id] = past.toMap();
      }
    }
    return _rebuildElementsFromCrdtState(composed);
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
    final enrichedScrub = await _computeScrubWithDiffs(scrub);
    final adapter = await CanvasDocAdapterFactory.create();
    _applyHistoryUpdate(
      adapter,
      enrichedScrub.baseStateBytes,
      label: 'base state',
    );
    final index =
        (startIndex ?? enrichedScrub.lastIndex).clamp(0, enrichedScrub.lastIndex);
    for (var i = 0; i <= index; i++) {
      _applyHistoryUpdate(
        adapter,
        enrichedScrub.deltaAt(i),
        label: 'step ${i + 1} of the preview',
      );
    }
    _historyScrubAdapter = adapter;
    final rawPreview = _materializeHistoryElements(adapter, state.elements);
    final previewElements =
        _composeScopedScrubPreviewElements(enrichedScrub, rawPreview);
    final stepDiff = enrichedScrub.diffAt(index);
    final effectiveHighlights = highlightElementIds.isNotEmpty
        ? highlightElementIds
        : (stepDiff?.changedElementIds ?? const <String>[]);
    if (isClosed) return;
    emit(state.copyWith(
      isViewingHistory: true,
      isHistoryLoading: false,
      historyScrub: enrichedScrub,
      historyScrubIndex: index,
      historyPreviewVersion: enrichedScrub.stops[index].version,
      historyPreviewElements: previewElements,
      historyHighlightElementIds: effectiveHighlights,
      historyPreviewTitle: title,
      historyPreviewReturnTray: returnTray,
      historyPreviewReturnUserUid: returnUserUid,
      historyPreviewFocusBounds: focusBounds,
      historyPreviewRequestId: requestId,
      historyPreviewShowsDesired: index < enrichedScrub.lastIndex,
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
        _applyHistoryUpdate(
          adapter,
          scrub.deltaAt(i),
          label: 'step ${i + 1} of the preview',
        );
      }
    } else {
      final rebuilt = await CanvasDocAdapterFactory.create();
      _applyHistoryUpdate(rebuilt, scrub.baseStateBytes, label: 'base state');
      for (var i = 0; i <= index; i++) {
        _applyHistoryUpdate(
          rebuilt,
          scrub.deltaAt(i),
          label: 'step ${i + 1} of the preview',
        );
      }
      _historyScrubAdapter = rebuilt;
    }
    final active = _historyScrubAdapter;
    if (active == null || isClosed) return;
    final rawPreview = _materializeHistoryElements(
      active,
      state.historyPreviewElements,
    );
    final previewElements =
        _composeScopedScrubPreviewElements(scrub, rawPreview);
    emit(state.copyWith(
      historyScrubIndex: index,
      historyPreviewElements: previewElements,
      historyPreviewShowsDesired: index < scrub.lastIndex,
    ));
  }

  /// Prepend older ops to the active scrub.
  Future<void> _onHistoryScrubLoadOlderRequested(
    CanvasHistoryScrubLoadOlderRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final service = _historyService;
    final scrub = state.historyScrub;
    if (service == null || scrub == null) return;
    if (scrub.targetUid == null &&
        scrub.area == null &&
        scrub.scopeMode != UndoRequestScopeMode.areaState) {
      return;
    }
    if (!scrub.hasMore || scrub.nextBeforeVersion == null) return;
    if (state.isHistoryLoading) return;
    emit(state.copyWith(isHistoryLoading: true, error: null));
    try {
      final timeline = await service.getUserTimeline(
        _boardId,
        scrub.targetUid ?? '',
        beforeVersion: scrub.nextBeforeVersion,
        elementIds: scrub.elementIds.isEmpty ? null : scrub.elementIds,
        area: scrub.area,
        scopeMode: scrub.scopeMode,
        afterVersion: state.historyPreviewRequestId != null
            ? scrub.stops.first.version
            : null,
      );
      if (isClosed) return;
      if (timeline.ops.isEmpty || timeline.steps.isEmpty) {
        emit(state.copyWith(isHistoryLoading: false));
        return;
      }
      final merged = await _computeScrubWithDiffs(
        HistoryScrub(
          stops: [...timeline.ops, ...scrub.stops],
          baseStateBytes: timeline.baseStateBytes,
          stepDeltas: [
            ..._alignedStepDeltas(timeline),
            ...scrub.stepDeltas,
          ],
          targetUid: scrub.targetUid,
          elementIds: scrub.elementIds,
          area: scrub.area,
          scopeMode: scrub.scopeMode,
          hasMore: timeline.hasMore,
          nextBeforeVersion: timeline.nextBeforeVersion,
        ),
      );
      if (isClosed) return;
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
      _scheduleLiveTailRefresh();
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
      _scheduleLiveTailRefresh();
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

  void _onMyUndoRequestsUpdated(
    CanvasMyUndoRequestsUpdated event,
    Emitter<CanvasState> emit,
  ) {
    if (_currentUserRole == Board.roleOwner) return;
    emit(state.copyWith(myUndoRequests: event.requests));
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
    if (state.isArchived) {
      if (clearStroke && state.currentStroke.isNotEmpty) {
        _activeStrokeId = null;
        _strokeStabilizer = null;
        _strokeClock.stop();
        emit(
          state.copyWith(
            currentStroke: const [],
            currentStrokePressures: const [],
            currentStrokeTilts: const [],
          ),
        );
      }
      final now = DateTime.now();
      final shouldShowWarning = _lastArchivedWarningAt == null ||
          now.difference(_lastArchivedWarningAt!).inMilliseconds > 1200;
      if (shouldShowWarning) {
        _lastArchivedWarningAt = now;
        emit(state.copyWith(error: null));
        emit(state.copyWith(
          error: _currentUserRole == Board.roleOwner
              ? 'This board is archived. Unarchive it from Settings to edit.'
              : 'This board was archived by the owner. Edits are disabled.',
        ));
      }
      return false;
    }
    if (state.isPaused) {
      if (clearStroke && state.currentStroke.isNotEmpty) {
        _activeStrokeId = null;
        _strokeStabilizer = null;
        _strokeClock.stop();
        emit(
          state.copyWith(
            currentStroke: const [],
            currentStrokePressures: const [],
            currentStrokeTilts: const [],
          ),
        );
      }
      final now = DateTime.now();
      final shouldShowWarning = _lastPausedWarningAt == null ||
          now.difference(_lastPausedWarningAt!).inMilliseconds > 1200;
      if (shouldShowWarning) {
        _lastPausedWarningAt = now;
        emit(state.copyWith(error: null));
        emit(state.copyWith(
          error: _currentUserRole == Board.roleOwner
              ? 'This board is paused. Resume it to continue editing.'
              : 'This board is paused by the owner. Edits are disabled.',
        ));
      }
      return false;
    }
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
          currentStrokeTilts: const [],
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
    _voiceSpeakerStatusSub?.cancel();

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
      _voiceSpeakerStatusSub = voiceService.watchIsSpeakerOn().listen((
        isSpeakerOn,
      ) {
        if (!isClosed) add(CanvasVoiceSpeakerStatusChanged(isSpeakerOn));
      }, onError: (_) {});
      // Presence is separate from joining: keep the board observing the voice
      // room so a call started by another member is visible immediately.
      unawaited(voiceService.observeBoard(boardId));
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

  void _onCanvasVoiceSpeakerStatusChanged(
    CanvasVoiceSpeakerStatusChanged event,
    Emitter<CanvasState> emit,
  ) {
    emit(state.copyWith(isSpeakerOn: event.isSpeakerOn));
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
        mentions: event.mentions,
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
        mentions: event.mentions,
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

  Future<void> _onCanvasToggleVoiceSpeakerRequested(
    CanvasToggleVoiceSpeakerRequested event,
    Emitter<CanvasState> emit,
  ) async {
    final voiceService = _voiceService;
    if (voiceService == null || _boardId.isEmpty) return;
    try {
      await voiceService.toggleSpeaker();
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
    _liveTailDebounceTimer?.cancel();
    _liveTailDebounceTimer = null;
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
    await _voiceSpeakerStatusSub?.cancel();
    _voiceSpeakerStatusSub = null;
    if (_boardId.isNotEmpty && state.isVoiceCallActive) {
      _voiceService?.leaveCall(_boardId);
    }
    if (_boardId.isNotEmpty) {
      _voiceService?.unobserveBoard(_boardId);
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
    await _myUndoRequestsSub?.cancel();
    _myUndoRequestsSub = null;
    await _previewUpdatesSub?.cancel();
    _previewUpdatesSub = null;
    await _canvasService?.stopCrdtRemoteSync(_boardId);
    return super.close();
  }
}
