import 'package:flutter/material.dart';

import '../../../domain/models/board.dart';
import '../../../domain/models/history/board_activity_block.dart';
import '../../../domain/models/history/board_operation.dart';
import '../../../domain/models/history/revert_plan.dart';
import '../../../domain/models/history/undo_request.dart';
import '../models/board_chat_message.dart';
import '../models/canvas_comment.dart';
import '../models/canvas_element.dart';
import '../models/canvas_tool_mode.dart';
import '../models/voice_participant.dart';
import '../view/trays/canvas_shape_type.dart';

/// State for CanvasBloc
class CanvasState {
  final String? boardTitle;
  final List<CanvasElement> elements;
  final List<Offset> currentStroke;
  final Color selectedColor;
  final double strokeWidth;
  final double brushOpacity;
  final String brushType;
  final bool eraserEraseEverything;
  final String? activeTray;
  final bool showTrayTips;
  final bool isLoading;
  final String? error;
  final String? infoMessage;
  final String currentUserRole;
  final String currentUserId;
  final List<BoardMember> boardMembers;
  final String memberSearchQuery;
  final String? selectedShapeId;
  final bool selectedShapeIsFilled;
  final double selectedShapeRotation;
  final double selectedShapeBorderRadius;
  final int selectedStrokeColor;
  final double selectedStrokeWidth;
  final double selectedStrokeOpacity;
  final String selectedStrokeBrushType;
  final CanvasToolMode currentToolMode;
  final CanvasShapeType? pendingShapeType;
  final bool isDrawingShape;
  final Offset? shapeDrawStart;
  final Offset? shapeDrawCurrent;
  final bool isExporting;
  final String? exportSuccessMessage;
  final String? lastExportedFilePath;
  final List<CanvasComment> comments;
  final List<BoardChatMessage> chatMessages;
  final List<VoiceParticipant> voiceParticipants;
  final bool isVoiceCallActive;
  final bool isMicMuted;
  final bool isChatDrawerOpen;
  final bool isCommentsTrayOpen;
  final String? activeCommentId;
  final bool isPlacingComment;

  // ── Board history (owner-only) + member undo ──
  final bool isViewingHistory;
  final int? historyPreviewVersion;
  final List<CanvasElement> historyPreviewElements;
  final List<BoardActivityBlock> activityBlocks;
  final List<UndoRequest> undoRequests;
  final RevertPlan? activeRevertPlan;
  final bool isHistoryLoading;

  /// Non-null while an undo/redo was blocked because a collaborator changed
  /// the element(s) the top stack entry would revert (§7.2). The screen shows
  /// the conflict dialog from this; dismissed via [CanvasUndoConflictDismissed].
  final CanvasUndoConflict? undoConflict;
  final String? selectedUserUid;
  final List<BoardOperation> userOps;
  final bool hasMoreUserOps;
  final int? userOpsNextBeforeVersion;

  const CanvasState({
    this.boardTitle,
    this.elements = const [],
    this.currentStroke = const [],
    this.selectedColor = Colors.black,
    this.strokeWidth = 5,
    this.brushOpacity = 1.0,
    this.brushType = 'solid',
    this.eraserEraseEverything = false,
    this.activeTray,
    this.showTrayTips = false,
    this.isLoading = false,
    this.error,
    this.infoMessage,
    this.currentUserRole = 'viewer',
    this.currentUserId = '',
    this.boardMembers = const [],
    this.memberSearchQuery = '',
    this.selectedShapeId,
    this.selectedShapeIsFilled = false,
    this.selectedShapeRotation = 0,
    this.selectedShapeBorderRadius = 0,
    this.selectedStrokeColor = 0xFF000000,
    this.selectedStrokeWidth = 5,
    this.selectedStrokeOpacity = 1.0,
    this.selectedStrokeBrushType = 'solid',
    this.currentToolMode = CanvasToolMode.doodle,
    this.pendingShapeType,
    this.isDrawingShape = false,
    this.shapeDrawStart,
    this.shapeDrawCurrent,
    this.isExporting = false,
    this.exportSuccessMessage,
    this.lastExportedFilePath,
    this.comments = const [],
    this.chatMessages = const [],
    this.voiceParticipants = const [],
    this.isVoiceCallActive = false,
    this.isMicMuted = false,
    this.isChatDrawerOpen = false,
    this.isCommentsTrayOpen = false,
    this.activeCommentId,
    this.isPlacingComment = false,
    this.isViewingHistory = false,
    this.historyPreviewVersion,
    this.historyPreviewElements = const [],
    this.activityBlocks = const [],
    this.undoRequests = const [],
    this.activeRevertPlan,
    this.isHistoryLoading = false,
    this.undoConflict,
    this.selectedUserUid,
    this.userOps = const [],
    this.hasMoreUserOps = false,
    this.userOpsNextBeforeVersion,
  });

  static const Object _unset = Object();

  CanvasState copyWith({
    Object? boardTitle = _unset,
    List<CanvasElement>? elements,
    List<Offset>? currentStroke,
    Color? selectedColor,
    double? strokeWidth,
    double? brushOpacity,
    String? brushType,
    bool? eraserEraseEverything,
    Object? activeTray = _unset,
    bool? showTrayTips,
    bool? isLoading,
    Object? error = _unset,
    Object? infoMessage = _unset,
    String? currentUserRole,
    String? currentUserId,
    List<BoardMember>? boardMembers,
    String? memberSearchQuery,
    Object? selectedShapeId = _unset,
    bool? selectedShapeIsFilled,
    double? selectedShapeRotation,
    double? selectedShapeBorderRadius,
    int? selectedStrokeColor,
    double? selectedStrokeWidth,
    double? selectedStrokeOpacity,
    String? selectedStrokeBrushType,
    CanvasToolMode? currentToolMode,
    Object? pendingShapeType = _unset,
    bool? isDrawingShape,
    Object? shapeDrawStart = _unset,
    Object? shapeDrawCurrent = _unset,
    bool? isExporting,
    Object? exportSuccessMessage = _unset,
    Object? lastExportedFilePath = _unset,
    List<CanvasComment>? comments,
    List<BoardChatMessage>? chatMessages,
    List<VoiceParticipant>? voiceParticipants,
    bool? isVoiceCallActive,
    bool? isMicMuted,
    bool? isChatDrawerOpen,
    bool? isCommentsTrayOpen,
    Object? activeCommentId = _unset,
    bool? isPlacingComment,
    bool? isViewingHistory,
    Object? historyPreviewVersion = _unset,
    List<CanvasElement>? historyPreviewElements,
    List<BoardActivityBlock>? activityBlocks,
    List<UndoRequest>? undoRequests,
    Object? activeRevertPlan = _unset,
    bool? isHistoryLoading,
    Object? undoConflict = _unset,
    Object? selectedUserUid = _unset,
    List<BoardOperation>? userOps,
    bool? hasMoreUserOps,
    Object? userOpsNextBeforeVersion = _unset,
  }) {
    return CanvasState(
      boardTitle: boardTitle == _unset
          ? this.boardTitle
          : boardTitle as String?,
      elements: elements ?? this.elements,
      currentStroke: currentStroke ?? this.currentStroke,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      brushOpacity: brushOpacity ?? this.brushOpacity,
      brushType: brushType ?? this.brushType,
      eraserEraseEverything:
          eraserEraseEverything ?? this.eraserEraseEverything,
      activeTray: activeTray == _unset
          ? this.activeTray
          : activeTray as String?,
      showTrayTips: showTrayTips ?? this.showTrayTips,
      isLoading: isLoading ?? this.isLoading,
      error: error == _unset ? this.error : error as String?,
      infoMessage:
          infoMessage == _unset ? this.infoMessage : infoMessage as String?,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      currentUserId: currentUserId ?? this.currentUserId,
      boardMembers: boardMembers ?? this.boardMembers,
      memberSearchQuery: memberSearchQuery ?? this.memberSearchQuery,
      selectedShapeId: selectedShapeId == _unset
          ? this.selectedShapeId
          : selectedShapeId as String?,
      selectedShapeIsFilled:
          selectedShapeIsFilled ?? this.selectedShapeIsFilled,
      selectedShapeRotation:
          selectedShapeRotation ?? this.selectedShapeRotation,
      selectedShapeBorderRadius:
          selectedShapeBorderRadius ?? this.selectedShapeBorderRadius,
      selectedStrokeColor:
          selectedStrokeColor ?? this.selectedStrokeColor,
      selectedStrokeWidth:
          selectedStrokeWidth ?? this.selectedStrokeWidth,
      selectedStrokeOpacity:
          selectedStrokeOpacity ?? this.selectedStrokeOpacity,
      selectedStrokeBrushType:
          selectedStrokeBrushType ?? this.selectedStrokeBrushType,
      currentToolMode: currentToolMode ?? this.currentToolMode,
      pendingShapeType: pendingShapeType == _unset
          ? this.pendingShapeType
          : pendingShapeType as CanvasShapeType?,
      isDrawingShape: isDrawingShape ?? this.isDrawingShape,
      shapeDrawStart: shapeDrawStart == _unset
          ? this.shapeDrawStart
          : shapeDrawStart as Offset?,
      shapeDrawCurrent: shapeDrawCurrent == _unset
          ? this.shapeDrawCurrent
          : shapeDrawCurrent as Offset?,
      isExporting: isExporting ?? this.isExporting,
      exportSuccessMessage: exportSuccessMessage == _unset
          ? this.exportSuccessMessage
          : exportSuccessMessage as String?,
      lastExportedFilePath: lastExportedFilePath == _unset
          ? this.lastExportedFilePath
          : lastExportedFilePath as String?,
      comments: comments ?? this.comments,
      chatMessages: chatMessages ?? this.chatMessages,
      voiceParticipants: voiceParticipants ?? this.voiceParticipants,
      isVoiceCallActive: isVoiceCallActive ?? this.isVoiceCallActive,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isChatDrawerOpen: isChatDrawerOpen ?? this.isChatDrawerOpen,
      isCommentsTrayOpen: isCommentsTrayOpen ?? this.isCommentsTrayOpen,
      activeCommentId: activeCommentId == _unset
          ? this.activeCommentId
          : activeCommentId as String?,
      isPlacingComment: isPlacingComment ?? this.isPlacingComment,
      isViewingHistory: isViewingHistory ?? this.isViewingHistory,
      historyPreviewVersion: historyPreviewVersion == _unset
          ? this.historyPreviewVersion
          : historyPreviewVersion as int?,
      historyPreviewElements:
          historyPreviewElements ?? this.historyPreviewElements,
      activityBlocks: activityBlocks ?? this.activityBlocks,
      undoRequests: undoRequests ?? this.undoRequests,
      activeRevertPlan: activeRevertPlan == _unset
          ? this.activeRevertPlan
          : activeRevertPlan as RevertPlan?,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      undoConflict: undoConflict == _unset
          ? this.undoConflict
          : undoConflict as CanvasUndoConflict?,
      selectedUserUid: selectedUserUid == _unset
          ? this.selectedUserUid
          : selectedUserUid as String?,
      userOps: userOps ?? this.userOps,
      hasMoreUserOps: hasMoreUserOps ?? this.hasMoreUserOps,
      userOpsNextBeforeVersion: userOpsNextBeforeVersion == _unset
          ? this.userOpsNextBeforeVersion
          : userOpsNextBeforeVersion as int?,
    );
  }

  List<BoardMember> get filteredBoardMembers {
    if (memberSearchQuery.trim().isEmpty) return boardMembers;
    final query = memberSearchQuery.trim().toLowerCase();
    return boardMembers.where((m) {
      final nameMatches = m.displayName?.toLowerCase().contains(query) ?? false;
      final emailMatches = m.email?.toLowerCase().contains(query) ?? false;
      return nameMatches || emailMatches;
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasState &&
          runtimeType == other.runtimeType &&
          boardTitle == other.boardTitle &&
          elements == other.elements &&
          currentStroke == other.currentStroke &&
          selectedColor == other.selectedColor &&
          strokeWidth == other.strokeWidth &&
          brushOpacity == other.brushOpacity &&
          brushType == other.brushType &&
          eraserEraseEverything == other.eraserEraseEverything &&
          activeTray == other.activeTray &&
          showTrayTips == other.showTrayTips &&
          isLoading == other.isLoading &&
          error == other.error &&
          infoMessage == other.infoMessage &&
          currentUserRole == other.currentUserRole &&
          currentUserId == other.currentUserId &&
          boardMembers == other.boardMembers &&
          memberSearchQuery == other.memberSearchQuery &&
          selectedShapeId == other.selectedShapeId &&
          selectedShapeIsFilled == other.selectedShapeIsFilled &&
          selectedShapeBorderRadius == other.selectedShapeBorderRadius &&
          selectedShapeRotation == other.selectedShapeRotation &&
          selectedStrokeColor == other.selectedStrokeColor &&
          selectedStrokeWidth == other.selectedStrokeWidth &&
          selectedStrokeOpacity == other.selectedStrokeOpacity &&
          selectedStrokeBrushType == other.selectedStrokeBrushType &&
          currentToolMode == other.currentToolMode &&
          pendingShapeType == other.pendingShapeType &&
          isDrawingShape == other.isDrawingShape &&
          shapeDrawStart == other.shapeDrawStart &&
          shapeDrawCurrent == other.shapeDrawCurrent &&
          isExporting == other.isExporting &&
          exportSuccessMessage == other.exportSuccessMessage &&
          lastExportedFilePath == other.lastExportedFilePath &&
          comments == other.comments &&
          chatMessages == other.chatMessages &&
          voiceParticipants == other.voiceParticipants &&
          isVoiceCallActive == other.isVoiceCallActive &&
          isMicMuted == other.isMicMuted &&
          isChatDrawerOpen == other.isChatDrawerOpen &&
          isCommentsTrayOpen == other.isCommentsTrayOpen &&
          activeCommentId == other.activeCommentId &&
          isPlacingComment == other.isPlacingComment &&
          isViewingHistory == other.isViewingHistory &&
          historyPreviewVersion == other.historyPreviewVersion &&
          historyPreviewElements == other.historyPreviewElements &&
          activityBlocks == other.activityBlocks &&
          undoRequests == other.undoRequests &&
          activeRevertPlan == other.activeRevertPlan &&
          isHistoryLoading == other.isHistoryLoading &&
          undoConflict == other.undoConflict &&
          selectedUserUid == other.selectedUserUid &&
          userOps == other.userOps &&
          hasMoreUserOps == other.hasMoreUserOps &&
          userOpsNextBeforeVersion == other.userOpsNextBeforeVersion;

  @override
  int get hashCode =>
      boardTitle.hashCode ^
      elements.hashCode ^
      currentStroke.hashCode ^
      selectedColor.hashCode ^
      strokeWidth.hashCode ^
      brushOpacity.hashCode ^
      brushType.hashCode ^
      eraserEraseEverything.hashCode ^
      activeTray.hashCode ^
      showTrayTips.hashCode ^
      isLoading.hashCode ^
      error.hashCode ^
      infoMessage.hashCode ^
      currentUserRole.hashCode ^
      currentUserId.hashCode ^
      boardMembers.hashCode ^
      memberSearchQuery.hashCode ^
      selectedShapeId.hashCode ^
      selectedShapeIsFilled.hashCode ^
      selectedShapeBorderRadius.hashCode ^
      selectedShapeRotation.hashCode ^
      selectedStrokeColor.hashCode ^
      selectedStrokeWidth.hashCode ^
      selectedStrokeOpacity.hashCode ^
      selectedStrokeBrushType.hashCode ^
      currentToolMode.hashCode ^
      pendingShapeType.hashCode ^
      isDrawingShape.hashCode ^
      shapeDrawStart.hashCode ^
      shapeDrawCurrent.hashCode ^
      isExporting.hashCode ^
      exportSuccessMessage.hashCode ^
      lastExportedFilePath.hashCode ^
      comments.hashCode ^
      chatMessages.hashCode ^
      voiceParticipants.hashCode ^
      isVoiceCallActive.hashCode ^
      isMicMuted.hashCode ^
      isChatDrawerOpen.hashCode ^
      isCommentsTrayOpen.hashCode ^
      activeCommentId.hashCode ^
      isPlacingComment.hashCode ^
      isViewingHistory.hashCode ^
      historyPreviewVersion.hashCode ^
      historyPreviewElements.hashCode ^
      activityBlocks.hashCode ^
      undoRequests.hashCode ^
      activeRevertPlan.hashCode ^
      isHistoryLoading.hashCode ^
      undoConflict.hashCode ^
      selectedUserUid.hashCode ^
      userOps.hashCode ^
      hasMoreUserOps.hashCode ^
      userOpsNextBeforeVersion.hashCode;
}

class CanvasInitial extends CanvasState {
  const CanvasInitial({super.currentUserId});
}

class CanvasCreating extends CanvasState {
  const CanvasCreating() : super(isLoading: true);
}

class CanvasReady extends CanvasState {
  final String boardId;

  const CanvasReady(this.boardId) : super();
}

class CanvasErrorState extends CanvasState {
  final String message;

  const CanvasErrorState(this.message) : super(error: message);
}

/// An undo/redo entry could not be applied because the element(s) it would
/// revert have since been changed by another user. Carried on [CanvasState]
/// until the user dismisses the dialog or chooses an action (member: send an
/// undo request to the owner; owner: review their own changes).
class CanvasUndoConflict {
  /// Elements the collaborator changed on top of this user's work.
  final List<String> elementIds;

  const CanvasUndoConflict({required this.elementIds});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasUndoConflict &&
          runtimeType == other.runtimeType &&
          _listEquals(elementIds, other.elementIds);

  @override
  int get hashCode => Object.hashAll(elementIds);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
