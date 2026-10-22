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

  const CanvasResizeSelectedShape(this.size);
}

/// Publish an in-progress selected-shape resize preview.
class CanvasPreviewResizeSelectedShape extends CanvasEvent {
  final double size;

  const CanvasPreviewResizeSelectedShape(this.size);
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

  const CanvasExportBoardRequested({
    required this.format,
    this.shareAfterExport = false,
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

