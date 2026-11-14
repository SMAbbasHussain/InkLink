part of 'canvas_bloc.dart';

/// Events for the CanvasBloc
abstract class CanvasEvent {
  const CanvasEvent();
}

/// Rename current board through BoardService.
class CanvasRenameBoardRequested extends CanvasEvent {
  final String newName;

  const CanvasRenameBoardRequested(this.newName);
}

/// Initialize CRDT sync for a specific board
class CanvasInitializeCrdt extends CanvasEvent {
  final String boardId;

  const CanvasInitializeCrdt(this.boardId);
}

/// Internal board metadata update from repository stream
class CanvasBoardTitleUpdated extends CanvasEvent {
  final String? title;
  final String currentUserRole;

  const CanvasBoardTitleUpdated(this.title, {this.currentUserRole = 'viewer'});
}

/// Board metadata is no longer available (deleted or access lost).
class CanvasBoardUnavailable extends CanvasEvent {
  final String message;

  const CanvasBoardUnavailable(this.message);
}

/// Update canvas from remote CRDT changes
class CanvasApplyRemoteUpdate extends CanvasEvent {
  final List<LocalCrdtUpdate> updates;

  const CanvasApplyRemoteUpdate(this.updates);
}

/// Update canvas from remote live previews.
class CanvasApplyRemotePreview extends CanvasEvent {
  final List<LocalCrdtUpdate> previews;

  const CanvasApplyRemotePreview(this.previews);
}

/// Start a new stroke
class CanvasStartStroke extends CanvasEvent {
  final Offset point;

  const CanvasStartStroke(this.point);
}

/// Append point to current stroke
class CanvasAppendStroke extends CanvasEvent {
  final Offset point;

  const CanvasAppendStroke(this.point);
}

/// End and save the current stroke
class CanvasEndStroke extends CanvasEvent {
  final List<Offset>? smoothedPoints;
  const CanvasEndStroke({this.smoothedPoints});
}

/// Add a shape to the canvas
class CanvasAddShape extends CanvasEvent {
  final CanvasShapeType shapeType;
  final Offset center;

  const CanvasAddShape(this.shapeType, this.center);
}

/// Add AI-generated text to canvas
class CanvasAddAiText extends CanvasEvent {
  final String prompt;
  final Offset position;

  const CanvasAddAiText(this.prompt, this.position);
}

/// Add image element to canvas
class CanvasAddImageElement extends CanvasEvent {
  final Uint8List imageBytes;
  final Offset center;
  final double width;
  final double height;

  const CanvasAddImageElement(
    this.imageBytes,
    this.center, {
    required this.width,
    required this.height,
  });
}

/// Add sticky note to canvas
class CanvasAddStickyNote extends CanvasEvent {
  final Offset center;
  final String text;
  final Color color;
  final double width;
  final double height;

  const CanvasAddStickyNote({
    required this.center,
    this.text = '',
    this.color = const Color(0xFFFFF9A6),
    this.width = 160.0,
    this.height = 160.0,
  });
}

/// Update existing sticky note
class CanvasUpdateStickyNote extends CanvasEvent {
  final String elementId;
  final String? text;
  final Color? color;
  final Offset? center;

  const CanvasUpdateStickyNote({
    required this.elementId,
    this.text,
    this.color,
    this.center,
  });
}

/// Add connector element to canvas
class CanvasAddConnector extends CanvasEvent {
  final String? startElementId;
  final Offset startPoint;
  final String startAnchor;
  final String? endElementId;
  final Offset endPoint;
  final String endAnchor;
  final String lineStyle;
  final Color color;
  final double strokeWidth;
  final bool hasArrowhead;

  const CanvasAddConnector({
    this.startElementId,
    required this.startPoint,
    this.startAnchor = 'center',
    this.endElementId,
    required this.endPoint,
    this.endAnchor = 'center',
    this.lineStyle = 'straight',
    this.color = const Color(0xFF2D3748),
    this.strokeWidth = 2.5,
    this.hasArrowhead = true,
  });
}

/// Update connector line style or anchors
class CanvasUpdateConnector extends CanvasEvent {
  final String elementId;
  final String? lineStyle;
  final Color? color;
  final double? strokeWidth;
  final bool? hasArrowhead;

  const CanvasUpdateConnector({
    required this.elementId,
    this.lineStyle,
    this.color,
    this.strokeWidth,
    this.hasArrowhead,
  });
}

/// Reattach one end of a connector to another element, or detach it to a free
/// point in world space.
class CanvasRewireConnector extends CanvasEvent {
  final String connectorId;
  final bool isStart;
  final String? targetElementId;
  final String anchor;
  final Offset point;

  const CanvasRewireConnector({
    required this.connectorId,
    required this.isStart,
    this.targetElementId,
    this.anchor = 'auto',
    required this.point,
  });
}

/// Update existing image transform
class CanvasUpdateImageElement extends CanvasEvent {
  final String elementId;
  final Offset center;
  final double width;
  final double height;

  const CanvasUpdateImageElement({
    required this.elementId,
    required this.center,
    required this.width,
    required this.height,
  });
}

/// Publish an in-progress image transform preview.
class CanvasPreviewImageElement extends CanvasEvent {
  final String elementId;
  final Offset center;
  final double width;
  final double height;

  const CanvasPreviewImageElement({
    required this.elementId,
    required this.center,
    required this.width,
    required this.height,
  });
}

/// Undo last operation
class CanvasUndo extends CanvasEvent {
  const CanvasUndo();
}

/// Redo last undone operation
class CanvasRedo extends CanvasEvent {
  const CanvasRedo();
}

/// Clear all elements on canvas
class CanvasClearAll extends CanvasEvent {
  const CanvasClearAll();
}

/// Delete a specific element
class CanvasDeleteElement extends CanvasEvent {
  final String elementId;

  const CanvasDeleteElement(this.elementId);
}

/// Update brush color
class CanvasUpdateColor extends CanvasEvent {
  final Color color;

  const CanvasUpdateColor(this.color);
}

/// Update stroke width
class CanvasUpdateStrokeWidth extends CanvasEvent {
  final double strokeWidth;

  const CanvasUpdateStrokeWidth(this.strokeWidth);
}

/// Update brush opacity
class CanvasUpdateBrushOpacity extends CanvasEvent {
  final double opacity;

  const CanvasUpdateBrushOpacity(this.opacity);
}

/// Update brush type
class CanvasUpdateBrushType extends CanvasEvent {
  final String brushType;

  const CanvasUpdateBrushType(this.brushType);
}

/// Set the current tool mode (doodle, shape, eraser, text, etc.)
class CanvasSetToolMode extends CanvasEvent {
  final CanvasToolMode mode;
  final CanvasShapeType? shapeType;
  final bool keepTray;

  const CanvasSetToolMode(
    this.mode, {
    this.shapeType,
    this.keepTray = false,
  });
}

/// Start drawing a shape on the canvas
class CanvasStartShapeDraw extends CanvasEvent {
  final Offset point;

  const CanvasStartShapeDraw(this.point);
}

/// Update the current shape draw preview
class CanvasUpdateShapeDraw extends CanvasEvent {
  final Offset point;

  const CanvasUpdateShapeDraw(this.point);
}

/// Finish drawing a shape and create it
class CanvasEndShapeDraw extends CanvasEvent {
  const CanvasEndShapeDraw();
}

/// Cancel shape drawing (Escape or tap)
class CanvasCancelShapeDraw extends CanvasEvent {
  const CanvasCancelShapeDraw();
}

/// Update eraser target mode
class CanvasUpdateEraserScope extends CanvasEvent {
  final bool eraseEverything;

  const CanvasUpdateEraserScope(this.eraseEverything);
}

/// Select an element by id (shape, stroke, text, image)
class CanvasSelectShape extends CanvasEvent {
  final String? shapeId;

  const CanvasSelectShape(this.shapeId);
}

/// Move selected shape center
class CanvasMoveSelectedShape extends CanvasEvent {
  final Offset center;

  const CanvasMoveSelectedShape(this.center);
}

/// Translate all points of a selected stroke
class CanvasMoveSelectedStroke extends CanvasEvent {
  final Offset delta;
  const CanvasMoveSelectedStroke(this.delta);
}

/// Update selected stroke color
class CanvasUpdateSelectedStrokeColor extends CanvasEvent {
  final int color;
  const CanvasUpdateSelectedStrokeColor(this.color);
}

/// Update selected stroke width
class CanvasUpdateSelectedStrokeWidth extends CanvasEvent {
  final double strokeWidth;
  const CanvasUpdateSelectedStrokeWidth(this.strokeWidth);
}

/// Update selected stroke opacity
class CanvasUpdateSelectedStrokeOpacity extends CanvasEvent {
  final double opacity;
  const CanvasUpdateSelectedStrokeOpacity(this.opacity);
}

/// Update selected stroke brush type
class CanvasUpdateSelectedStrokeBrushType extends CanvasEvent {
  final String brushType;
  const CanvasUpdateSelectedStrokeBrushType(this.brushType);
}

/// Publish an in-progress selected-shape move preview.
class CanvasPreviewMoveSelectedShape extends CanvasEvent {
  final Offset center;

  const CanvasPreviewMoveSelectedShape(this.center);
}

/// Resize selected shape
class CanvasResizeSelectedShape extends CanvasEvent {
  final double size;

  /// Sticky notes are not square-by-definition: their resize handle drags the
  /// width and height independently, so both are carried alongside `size`.
  final double? width;
  final double? height;

  const CanvasResizeSelectedShape(this.size, {this.width, this.height});
}

/// Publish an in-progress selected-shape resize preview.
class CanvasPreviewResizeSelectedShape extends CanvasEvent {
  final double size;
  final double? width;
  final double? height;

  const CanvasPreviewResizeSelectedShape(this.size, {this.width, this.height});
}

/// Toggle fill mode for selected shape
class CanvasToggleSelectedShapeFill extends CanvasEvent {
  final bool isFilled;

  const CanvasToggleSelectedShapeFill(this.isFilled);
}

/// Update selected shape color
class CanvasUpdateSelectedShapeColor extends CanvasEvent {
  final Color color;

  const CanvasUpdateSelectedShapeColor(this.color);
}

/// Update selected shape corner radius
class CanvasUpdateSelectedShapeBorderRadius extends CanvasEvent {
  final double borderRadius;

  const CanvasUpdateSelectedShapeBorderRadius(this.borderRadius);
}

/// Rotate selected shape
class CanvasRotateSelectedShape extends CanvasEvent {
  final double rotation;

  const CanvasRotateSelectedShape(this.rotation);
}

/// Publish an in-progress selected-shape rotation preview.
class CanvasPreviewRotateSelectedShape extends CanvasEvent {
  final double rotation;

  const CanvasPreviewRotateSelectedShape(this.rotation);
}

/// Commit pending shape edits (batched from sliders/UI)
class CanvasCommitPendingShapeEdits extends CanvasEvent {
  final String shapeId;
  final Map<String, dynamic> pendingData;

  const CanvasCommitPendingShapeEdits({
    required this.shapeId,
    required this.pendingData,
  });
}

/// Publish pending shape edits as a live preview.
class CanvasPreviewPendingShapeEdits extends CanvasEvent {
  final String shapeId;
  final Map<String, dynamic> pendingData;

  const CanvasPreviewPendingShapeEdits({
    required this.shapeId,
    required this.pendingData,
  });
}

/// Open/close a tray panel
class CanvasToggleTray extends CanvasEvent {
  final String trayName;

  const CanvasToggleTray(this.trayName);
}

/// Update board members list
class CanvasBoardMembersUpdated extends CanvasEvent {
  final List<BoardMember> members;

  const CanvasBoardMembersUpdated(this.members);
}

/// Update member search query
class CanvasMemberSearchQueryChanged extends CanvasEvent {
  final String query;

  const CanvasMemberSearchQueryChanged(this.query);
}

/// Show tray tips overlay
class CanvasShowTrayTips extends CanvasEvent {
  const CanvasShowTrayTips();
}

/// Dismiss tray tips overlay
class CanvasDismissTrayTips extends CanvasEvent {
  const CanvasDismissTrayTips();
}

class CanvasSaveBoardPreviewRequested extends CanvasEvent {
  final Uint8List pngBytes;

  const CanvasSaveBoardPreviewRequested(this.pngBytes);
}

/// Revoke a member's access from the board (Owner only)
class CanvasRemoveBoardMember extends CanvasEvent {
  final String targetUid;

  const CanvasRemoveBoardMember(this.targetUid);
}

/// Update a member's role (Editor/Viewer) on the board (Owner only)
class CanvasUpdateBoardMemberRole extends CanvasEvent {
  final String targetUid;
  final String newRole;

  const CanvasUpdateBoardMemberRole({
    required this.targetUid,
    required this.newRole,
  });
}

/// Export canvas board in specified format (PNG, PDF, SVG) and optionally share
class CanvasExportBoardRequested extends CanvasEvent {
  final BoardExportFormat format;
  final bool shareAfterExport;
  /// Global rect of the tap target, used to anchor the native share popover on
  /// iPad/Mac. Null is tolerated on phones but fails to present on tablets.
  final Rect? sharePositionOrigin;

  const CanvasExportBoardRequested({
    required this.format,
    this.shareAfterExport = false,
    this.sharePositionOrigin,
  });
}

/// Reset export message and status
class CanvasConsumeExportMessage extends CanvasEvent {
  const CanvasConsumeExportMessage();
}

// ============================================================
// Module 11: In-App Communication & Audio Events
// ============================================================

/// Comments stream updated
class CanvasCommentsUpdated extends CanvasEvent {
  final List<CanvasComment> comments;
  const CanvasCommentsUpdated(this.comments);
}

/// Chat history / message list updated
class CanvasChatMessagesUpdated extends CanvasEvent {
  final List<BoardChatMessage> messages;
  const CanvasChatMessagesUpdated(this.messages);
}

/// Single new chat message received
class CanvasChatMessageReceived extends CanvasEvent {
  final BoardChatMessage message;
  const CanvasChatMessageReceived(this.message);
}

/// Voice participants updated
class CanvasVoiceParticipantsUpdated extends CanvasEvent {
  final List<VoiceParticipant> participants;
  const CanvasVoiceParticipantsUpdated(this.participants);
}

/// Voice call active status changed
class CanvasVoiceCallStatusChanged extends CanvasEvent {
  final bool isInCall;
  const CanvasVoiceCallStatusChanged(this.isInCall);
}

/// Voice call mute status changed
class CanvasVoiceMuteStatusChanged extends CanvasEvent {
  final bool isMuted;
  const CanvasVoiceMuteStatusChanged(this.isMuted);
}

/// Toggle chat drawer open/close
class CanvasToggleChatDrawer extends CanvasEvent {
  const CanvasToggleChatDrawer();
}

/// Toggle comments tray open/close
class CanvasToggleCommentsTray extends CanvasEvent {
  const CanvasToggleCommentsTray();
}

/// Toggle placing comment mode (pin drop on canvas)
class CanvasToggleCommentPlacementMode extends CanvasEvent {
  final bool? enable;
  const CanvasToggleCommentPlacementMode({this.enable});
}

/// Set active comment thread for viewing / replying
class CanvasSetActiveComment extends CanvasEvent {
  final String? commentId;
  const CanvasSetActiveComment(this.commentId);
}

/// Add new comment (pinned or board-level)
class CanvasAddCommentRequested extends CanvasEvent {
  final String text;
  final Offset? canvasPosition;

  const CanvasAddCommentRequested({
    required this.text,
    this.canvasPosition,
  });
}

/// Add reply to comment thread
class CanvasAddCommentReplyRequested extends CanvasEvent {
  final String commentId;
  final String text;

  const CanvasAddCommentReplyRequested({
    required this.commentId,
    required this.text,
  });
}

/// Delete comment (author or board owner)
class CanvasDeleteCommentRequested extends CanvasEvent {
  final String commentId;
  const CanvasDeleteCommentRequested(this.commentId);
}

/// Send chat message via WebSocket
class CanvasSendChatMessageRequested extends CanvasEvent {
  final String text;
  const CanvasSendChatMessageRequested(this.text);
}

/// Join voice call
class CanvasJoinVoiceCallRequested extends CanvasEvent {
  const CanvasJoinVoiceCallRequested();
}

/// Leave voice call
class CanvasLeaveVoiceCallRequested extends CanvasEvent {
  const CanvasLeaveVoiceCallRequested();
}

/// Toggle mic mute
class CanvasToggleVoiceMuteRequested extends CanvasEvent {
  const CanvasToggleVoiceMuteRequested();
}

/// Report speaking activity
class CanvasVoiceSpeakingChanged extends CanvasEvent {
  final bool isSpeaking;
  const CanvasVoiceSpeakingChanged(this.isSpeaking);
}

/// Request edit access from the board owner
class CanvasRequestEditAccess extends CanvasEvent {
  final String? message;
  const CanvasRequestEditAccess({this.message});
}

/// Consume info message
class CanvasConsumeInfoMessage extends CanvasEvent {
  const CanvasConsumeInfoMessage();
}

// ============================================================
// Board history (owner-only) + member undo (D2/D3/D15)
// ============================================================

/// Subscribe to the owner-only activity feed (`activity_index`).
class CanvasHistoryFeedRequested extends CanvasEvent {
  const CanvasHistoryFeedRequested();
}

/// Internal: the Firestore activity-feed stream emitted a new page.
class CanvasHistoryFeedUpdated extends CanvasEvent {
  final List<BoardActivityBlock> blocks;
  const CanvasHistoryFeedUpdated(this.blocks);
}

/// Preview a past version read-only. [highlightElementIds] marks the elements
/// the owner is inspecting; [focusBounds] (world space) overrides the camera
/// focus when set (e.g. a request's selected area).
class CanvasHistoryPreviewRequested extends CanvasEvent {
  final int version;
  final List<String> highlightElementIds;
  final String? title;
  final Rect? focusBounds;
  const CanvasHistoryPreviewRequested(
    this.version, {
    this.highlightElementIds = const [],
    this.title,
    this.focusBounds,
  });
}

/// Leave preview mode and return to the live board.
class CanvasHistoryPreviewExited extends CanvasEvent {
  const CanvasHistoryPreviewExited();
}

/// Owner opens a pending undo request's attached evidence in a board preview,
/// comparing the live board against the state the member is asking for (D5).
class CanvasHistoryRequestEvidenceRequested extends CanvasEvent {
  final String requestId;
  const CanvasHistoryRequestEvidenceRequested(this.requestId);
}

/// Switch the evidence preview between the live board and the requested state.
class CanvasHistoryEvidenceViewToggled extends CanvasEvent {
  final bool showDesired;
  const CanvasHistoryEvidenceViewToggled(this.showDesired);
}

/// Owner wants to restore the previewed version.
class CanvasHistoryRestoreRequested extends CanvasEvent {
  final int version;
  const CanvasHistoryRestoreRequested(this.version);
}

/// Owner wants to plan a revert of one user's work.
class CanvasHistoryRevertUserRequested extends CanvasEvent {
  final String targetUid;
  final DateTime? fromTime;
  final DateTime? toTime;

  /// When set (e.g. from the undo-conflict dialog), the plan is scoped to
  /// exactly these elements instead of the user's whole in-range history.
  final List<String>? elementIds;
  const CanvasHistoryRevertUserRequested(
    this.targetUid, {
    this.fromTime,
    this.toTime,
    this.elementIds,
  });
}

/// Owner opens the review flow for a pending undo request (D5).
class CanvasHistoryUndoRequestReviewRequested extends CanvasEvent {
  final String requestId;
  const CanvasHistoryUndoRequestReviewRequested(this.requestId);
}

/// Load (or page) one user's action timeline (D15).
class CanvasHistoryUserOpsRequested extends CanvasEvent {
  final String targetUid;
  final DateTime? fromTime;
  final DateTime? toTime;
  final int? beforeVersion;
  const CanvasHistoryUserOpsRequested(
    this.targetUid, {
    this.fromTime,
    this.toTime,
    this.beforeVersion,
  });
}

/// A user-timeline page arrived.
class CanvasHistoryUserOpsUpdated extends CanvasEvent {
  final String targetUid;
  final List<BoardOperation> ops;
  final bool hasMore;
  final int? nextBeforeVersion;
  final bool append;
  const CanvasHistoryUserOpsUpdated({
    required this.targetUid,
    required this.ops,
    required this.hasMore,
    this.nextBeforeVersion,
    this.append = false,
  });
}

/// Close the per-user timeline view.
class CanvasHistoryUserTimelineExited extends CanvasEvent {
  const CanvasHistoryUserTimelineExited();
}

/// Owner opens a version's scrub preview: it starts on the block's last state
/// and the banner slider moves back/forward op-by-op (§ version scrub).
class CanvasHistoryVersionScrubRequested extends CanvasEvent {
  final BoardActivityBlock block;
  const CanvasHistoryVersionScrubRequested(this.block);
}

/// Owner replays one user's logged changes on the canvas. The slider starts
/// at that user's latest change and moves back (§ user scrub).
class CanvasHistoryUserScrubRequested extends CanvasEvent {
  final String targetUid;
  const CanvasHistoryUserScrubRequested(this.targetUid);
}

/// The scrub slider moved: apply/undo the committed updates in the preview
/// accordingly, then settle and revert if wanted.
class CanvasHistoryScrubMoved extends CanvasEvent {
  final int index;
  const CanvasHistoryScrubMoved(this.index);
}

/// Prepend the replayed user's older ops to the active scrub session.
class CanvasHistoryScrubLoadOlderRequested extends CanvasEvent {
  const CanvasHistoryScrubLoadOlderRequested();
}

/// ── Member undo request (D5): desired-state flow ────────────────────────────

/// Member starts (or reopens) an undo request: the scope draft is created and
/// the scope sheet opens. [preselectedIds] pre-ticks the scope (e.g. the
/// undo-conflict elements or an area just resolved on the canvas); [area]
/// carries the drawn area when the scope was resolved from one. Both REPLACE
/// any existing draft so stale picks never linger.
class CanvasUndoRequestDraftStarted extends CanvasEvent {
  final List<String> preselectedIds;
  final UndoRequestArea? area;
  const CanvasUndoRequestDraftStarted({
    this.preselectedIds = const [],
    this.area,
  });
}

/// Member toggled one element in their undo-request scope: a sheet checkbox
/// or a double-tap on the live canvas.
class CanvasUndoRequestDraftElementToggled extends CanvasEvent {
  final String elementId;
  const CanvasUndoRequestDraftElementToggled(this.elementId);
}

/// Member finished an area selection: the area is stored and the scope resets
/// to the elements overlapping it.
class CanvasUndoRequestDraftAreaSet extends CanvasEvent {
  final UndoRequestArea area;
  final List<String> elementIds;
  const CanvasUndoRequestDraftAreaSet(this.area, this.elementIds);
}

/// Member abandoned their in-progress undo request.
class CanvasUndoRequestDraftCleared extends CanvasEvent {
  const CanvasUndoRequestDraftCleared();
}

/// Member wants to see their own scoped changes: loads their timeline
/// restricted to the draft's elements and opens the request scrub slider
/// (start = "before these changes").
class CanvasUndoRequestPreviewRequested extends CanvasEvent {
  const CanvasUndoRequestPreviewRequested();
}

/// Member submits the request. The desired state is the currently selected
/// stop of their request scrub (never the newest stop — that would be a
/// no-op), stored as the request's targetVersion.
class CanvasUndoRequestSubmitRequested extends CanvasEvent {
  final String reason;
  const CanvasUndoRequestSubmitRequested(this.reason);
}

/// ── Owner: restore to a point between a request's state and now ────────────

/// Owner settled on a stop between an undo request's requested state and the
/// current state: undo the requester's in-scope ops after [afterVersion]. The
/// review sheet confirms per element. [requestId] binds the applied plan to
/// the request so applying it resolves the request as approved.
class CanvasHistoryRevertOpsAfterRequested extends CanvasEvent {
  final String targetUid;
  final int afterVersion;
  final List<String> elementIds;
  final String? requestId;
  const CanvasHistoryRevertOpsAfterRequested({
    required this.targetUid,
    required this.afterVersion,
    required this.elementIds,
    this.requestId,
  });
}

/// Owner taps a log row: preview the board as it was when the op was made,
/// with a Past/Current toggle against the live board (§ log compare).
class CanvasHistoryOpCompareRequested extends CanvasEvent {
  final BoardOperation operation;
  const CanvasHistoryOpCompareRequested(this.operation);
}

/// Owner wants to undo specific logged ops — a single op, a multi-selection
/// from a user's timeline, or the tail of a scrub replay.
class CanvasHistoryRevertOpsRequested extends CanvasEvent {
  final List<int> opVersions;
  const CanvasHistoryRevertOpsRequested(this.opVersions);
}

/// A server-built revert plan is ready for review.
class CanvasHistoryPlanLoaded extends CanvasEvent {
  final RevertPlan plan;
  const CanvasHistoryPlanLoaded(this.plan);
}

/// Owner confirmed the per-element keep/revert decisions.
class CanvasHistoryApplyRevert extends CanvasEvent {
  final String planId;
  final Map<String, String> decisions;
  final String? requestId;
  const CanvasHistoryApplyRevert({
    required this.planId,
    required this.decisions,
    this.requestId,
  });
}

/// Dismiss the revert review sheet without applying.
class CanvasHistoryPlanDismissed extends CanvasEvent {
  const CanvasHistoryPlanDismissed();
}

/// Cross-device fallback for a member's own ≤15-minute edits (D2).
class CanvasHistoryUndoOwn extends CanvasEvent {
  const CanvasHistoryUndoOwn();
}

/// Toggle marquee area-selection mode so a member can pick a whole region for
/// an undo request. The screen computes the intersecting elements locally and
/// never reads the owner-only log (D3).
class CanvasToggleUndoRequestAreaSelection extends CanvasEvent {
  final bool? enable;
  const CanvasToggleUndoRequestAreaSelection({this.enable});
}

/// Owner's undo-request list changed.
class CanvasUndoRequestsUpdated extends CanvasEvent {
  final List<UndoRequest> requests;
  const CanvasUndoRequestsUpdated(this.requests);
}

/// Internal: a plan-build request failed.
class CanvasHistoryPlanFailed extends CanvasEvent {
  final String message;
  const CanvasHistoryPlanFailed(this.message);
}

/// Dismiss the "your work has been changed" conflict dialog without acting.
class CanvasUndoConflictDismissed extends CanvasEvent {
  const CanvasUndoConflictDismissed();
}


