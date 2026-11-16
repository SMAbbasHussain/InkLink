import 'package:flutter/material.dart';

import '../../../domain/models/board.dart';
import '../../../domain/models/canvas/canvas_board_settings.dart';
import '../models/board_chat_message.dart';
import '../models/canvas_comment.dart';
import '../models/canvas_element.dart';
import '../models/canvas_selection_mode.dart';
import '../models/canvas_tool_mode.dart';
import '../models/voice_participant.dart';
import '../view/trays/canvas_shape_type.dart';

/// Whether local board changes have reached the collaboration service.
enum CanvasSyncStatus { idle, syncing, saved, offline }

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

  /// Whether [infoMessage] describes an action that the snackbar can undo.
  final bool infoMessageUndoable;

  /// Whether [infoMessage] describes an undo that the snackbar can redo.
  final bool infoMessageRedoable;
  final String currentUserRole;
  final String currentUserId;
  final List<BoardMember> boardMembers;
  final String memberSearchQuery;
  final String? selectedShapeId;
  final Set<String> selectedIds;
  final bool selectedShapeIsFilled;
  final double selectedShapeRotation;
  final double selectedShapeBorderRadius;
  final int selectedStrokeColor;
  final double selectedStrokeWidth;
  final double selectedStrokeOpacity;
  final String selectedStrokeBrushType;
  final CanvasToolMode currentToolMode;
  final CanvasSelectionMode selectionMode;
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

  /// Whether the in-app element clipboard holds anything to paste.
  final bool hasClipboard;

  /// Layer that receives newly drawn elements; null means the default group.
  final String? activeLayerId;

  /// Collaborative background/page look, persisted as a CRDT payload.
  final CanvasBoardSettings boardSettings;

  /// Parallel pressures captured for [currentStroke]. Empty means all 1.0.
  final List<double> currentStrokePressures;

  /// Parallel stylus tilt captured for [currentStroke]. Empty means upright.
  final List<double> currentStrokeTilts;

  /// Whether stylus pressure affects stroke width / opacity.
  final bool stylusPressureEnabled;

  /// Whether holding at the end of a stroke snaps it to a clean shape.
  final bool quickShapeEnabled;

  /// When false, one-finger drags pan instead of drawing with a brush.
  /// Stylus input always draws.
  final bool fingerDrawingEnabled;

  final double stabilizerStrength;

  /// Sync state surfaced in the board header. [syncMessage] explains the
  /// offline/recovery case; it is null while everything is healthy.
  final CanvasSyncStatus syncStatus;
  final String? syncMessage;

  const CanvasState({
    this.boardTitle,
    this.elements = const [],
    this.currentStroke = const [],
    this.currentStrokePressures = const [],
    this.currentStrokeTilts = const [],
    this.stylusPressureEnabled = true,
    this.quickShapeEnabled = true,
    this.fingerDrawingEnabled = true,
    this.stabilizerStrength = 0,
    this.syncStatus = CanvasSyncStatus.idle,
    this.syncMessage,
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
    this.infoMessageUndoable = false,
    this.infoMessageRedoable = false,
    this.currentUserRole = 'viewer',
    this.currentUserId = '',
    this.boardMembers = const [],
    this.memberSearchQuery = '',
    this.selectedShapeId,
    this.selectedIds = const <String>{},
    this.selectedShapeIsFilled = false,
    this.selectedShapeRotation = 0,
    this.selectedShapeBorderRadius = 0,
    this.selectedStrokeColor = 0xFF000000,
    this.selectedStrokeWidth = 5,
    this.selectedStrokeOpacity = 1.0,
    this.selectedStrokeBrushType = 'solid',
    this.currentToolMode = CanvasToolMode.doodle,
    this.selectionMode = CanvasSelectionMode.marquee,
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
    this.hasClipboard = false,
    this.activeLayerId,
    this.boardSettings = const CanvasBoardSettings(),
  });

  static const Object _unset = Object();

  CanvasState copyWith({
    Object? boardTitle = _unset,
    List<CanvasElement>? elements,
    List<Offset>? currentStroke,
    List<double>? currentStrokePressures,
    List<double>? currentStrokeTilts,
    bool? stylusPressureEnabled,
    bool? quickShapeEnabled,
    bool? fingerDrawingEnabled,
    double? stabilizerStrength,
    CanvasSyncStatus? syncStatus,
    Object? syncMessage = _unset,
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
    bool? infoMessageUndoable,
    bool? infoMessageRedoable,
    String? currentUserRole,
    String? currentUserId,
    List<BoardMember>? boardMembers,
    String? memberSearchQuery,
    Object? selectedShapeId = _unset,
    Set<String>? selectedIds,
    bool? selectedShapeIsFilled,
    double? selectedShapeRotation,
    double? selectedShapeBorderRadius,
    int? selectedStrokeColor,
    double? selectedStrokeWidth,
    double? selectedStrokeOpacity,
    String? selectedStrokeBrushType,
    CanvasToolMode? currentToolMode,
    CanvasSelectionMode? selectionMode,
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
    bool? hasClipboard,
    Object? activeLayerId = _unset,
    CanvasBoardSettings? boardSettings,
  }) {
    return CanvasState(
      boardTitle: boardTitle == _unset
          ? this.boardTitle
          : boardTitle as String?,
      elements: elements ?? this.elements,
      currentStroke: currentStroke ?? this.currentStroke,
      currentStrokePressures:
          currentStrokePressures ?? this.currentStrokePressures,
      currentStrokeTilts: currentStrokeTilts ?? this.currentStrokeTilts,
      stylusPressureEnabled:
          stylusPressureEnabled ?? this.stylusPressureEnabled,
      quickShapeEnabled: quickShapeEnabled ?? this.quickShapeEnabled,
      fingerDrawingEnabled: fingerDrawingEnabled ?? this.fingerDrawingEnabled,
      stabilizerStrength: stabilizerStrength ?? this.stabilizerStrength,
      syncStatus: syncStatus ?? this.syncStatus,
      syncMessage: syncMessage == _unset
          ? this.syncMessage
          : syncMessage as String?,
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
      infoMessage: infoMessage == _unset
          ? this.infoMessage
          : infoMessage as String?,
      infoMessageUndoable: infoMessageUndoable ?? this.infoMessageUndoable,
      infoMessageRedoable: infoMessageRedoable ?? this.infoMessageRedoable,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      currentUserId: currentUserId ?? this.currentUserId,
      boardMembers: boardMembers ?? this.boardMembers,
      memberSearchQuery: memberSearchQuery ?? this.memberSearchQuery,
      selectedShapeId: selectedShapeId == _unset
          ? this.selectedShapeId
          : selectedShapeId as String?,
      selectedIds: selectedIds ?? this.selectedIds,
      selectedShapeIsFilled:
          selectedShapeIsFilled ?? this.selectedShapeIsFilled,
      selectedShapeRotation:
          selectedShapeRotation ?? this.selectedShapeRotation,
      selectedShapeBorderRadius:
          selectedShapeBorderRadius ?? this.selectedShapeBorderRadius,
      selectedStrokeColor: selectedStrokeColor ?? this.selectedStrokeColor,
      selectedStrokeWidth: selectedStrokeWidth ?? this.selectedStrokeWidth,
      selectedStrokeOpacity:
          selectedStrokeOpacity ?? this.selectedStrokeOpacity,
      selectedStrokeBrushType:
          selectedStrokeBrushType ?? this.selectedStrokeBrushType,
      currentToolMode: currentToolMode ?? this.currentToolMode,
      selectionMode: selectionMode ?? this.selectionMode,
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
      hasClipboard: hasClipboard ?? this.hasClipboard,
      activeLayerId: activeLayerId == _unset
          ? this.activeLayerId
          : activeLayerId as String?,
      boardSettings: boardSettings ?? this.boardSettings,
    );
  }

  /// Whether this session may edit the board.
  ///
  /// This is UI gating only; every mutation handler still calls
  /// `_ensureCanEdit` so a stale screen cannot bypass the permission check.
  bool get canEdit => currentUserRole != Board.roleViewer;

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
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
          currentStrokePressures == other.currentStrokePressures &&
          currentStrokeTilts == other.currentStrokeTilts &&
          stylusPressureEnabled == other.stylusPressureEnabled &&
          quickShapeEnabled == other.quickShapeEnabled &&
          fingerDrawingEnabled == other.fingerDrawingEnabled &&
          stabilizerStrength == other.stabilizerStrength &&
          syncStatus == other.syncStatus &&
          syncMessage == other.syncMessage &&
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
          infoMessageUndoable == other.infoMessageUndoable &&
          infoMessageRedoable == other.infoMessageRedoable &&
          currentUserRole == other.currentUserRole &&
          currentUserId == other.currentUserId &&
          boardMembers == other.boardMembers &&
          memberSearchQuery == other.memberSearchQuery &&
          selectedShapeId == other.selectedShapeId &&
          _setEquals(selectedIds, other.selectedIds) &&
          selectedShapeIsFilled == other.selectedShapeIsFilled &&
          selectedShapeBorderRadius == other.selectedShapeBorderRadius &&
          selectedShapeRotation == other.selectedShapeRotation &&
          selectedStrokeColor == other.selectedStrokeColor &&
          selectedStrokeWidth == other.selectedStrokeWidth &&
          selectedStrokeOpacity == other.selectedStrokeOpacity &&
          selectedStrokeBrushType == other.selectedStrokeBrushType &&
          currentToolMode == other.currentToolMode &&
          selectionMode == other.selectionMode &&
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
          hasClipboard == other.hasClipboard &&
          activeLayerId == other.activeLayerId &&
          boardSettings == other.boardSettings;

  @override
  int get hashCode =>
      boardTitle.hashCode ^
      elements.hashCode ^
      currentStroke.hashCode ^
      currentStrokePressures.hashCode ^
      currentStrokeTilts.hashCode ^
      stylusPressureEnabled.hashCode ^
      quickShapeEnabled.hashCode ^
      fingerDrawingEnabled.hashCode ^
      stabilizerStrength.hashCode ^
      syncStatus.hashCode ^
      syncMessage.hashCode ^
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
      infoMessageUndoable.hashCode ^
      infoMessageRedoable.hashCode ^
      currentUserRole.hashCode ^
      currentUserId.hashCode ^
      boardMembers.hashCode ^
      memberSearchQuery.hashCode ^
      selectedShapeId.hashCode ^
      Object.hashAllUnordered(selectedIds).hashCode ^
      selectedShapeIsFilled.hashCode ^
      selectedShapeBorderRadius.hashCode ^
      selectedShapeRotation.hashCode ^
      selectedStrokeColor.hashCode ^
      selectedStrokeWidth.hashCode ^
      selectedStrokeOpacity.hashCode ^
      selectedStrokeBrushType.hashCode ^
      currentToolMode.hashCode ^
      selectionMode.hashCode ^
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
      hasClipboard.hashCode ^
      activeLayerId.hashCode ^
      boardSettings.hashCode;
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
