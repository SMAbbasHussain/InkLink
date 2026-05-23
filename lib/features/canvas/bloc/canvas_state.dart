part of 'canvas_bloc.dart';

const Object _unset = Object();

/// Canvas element model for the BLoC
class CanvasElement {
  final String id;
  final String type; // 'stroke', 'shape', 'text'
  final dynamic data;

  CanvasElement({required this.id, required this.type, required this.data});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasElement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

/// State for CanvasBloc
class CanvasState {
  final String? boardTitle;
  final List<CanvasElement> elements;
  final List<Offset> currentStroke;
  final Color selectedColor;
  final double strokeWidth;
  final double brushOpacity;
  final String brushType; // 'solid', 'textured', 'watercolor'
  final bool eraserEraseEverything;
  final String? activeTray;
  final bool showTrayTips;
  final bool isLoading;
  final String? error;
  final String currentUserRole;
  final List<BoardMember> boardMembers;
  final String memberSearchQuery;
  final String? selectedShapeId; // ID of currently selected shape for editing
  final bool selectedShapeIsFilled; // Whether the selected shape is filled
  final double selectedShapeRotation;
  final double selectedShapeBorderRadius;

  CanvasState({
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
    this.currentUserRole = 'viewer',
    this.boardMembers = const [],
    this.memberSearchQuery = '',
    this.selectedShapeId,
    this.selectedShapeIsFilled = false,
    this.selectedShapeRotation = 0,
    this.selectedShapeBorderRadius = 0,
  });

  /// Create a copy with optional field overrides
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
    String? currentUserRole,
    List<BoardMember>? boardMembers,
    String? memberSearchQuery,
    Object? selectedShapeId = _unset,
    bool? selectedShapeIsFilled,
    double? selectedShapeRotation,
    double? selectedShapeBorderRadius,
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
      currentUserRole: currentUserRole ?? this.currentUserRole,
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
    );
  }

  /// Get filtered members based on search query (strict local filtering)
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
          currentUserRole == other.currentUserRole &&
          boardMembers == other.boardMembers &&
          memberSearchQuery == other.memberSearchQuery &&
          selectedShapeId == other.selectedShapeId &&
          selectedShapeIsFilled == other.selectedShapeIsFilled &&
          selectedShapeBorderRadius == other.selectedShapeBorderRadius &&
          selectedShapeRotation == other.selectedShapeRotation;

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
      currentUserRole.hashCode ^
      boardMembers.hashCode ^
      memberSearchQuery.hashCode ^
      selectedShapeId.hashCode ^
      selectedShapeIsFilled.hashCode ^
      selectedShapeBorderRadius.hashCode ^
      selectedShapeRotation.hashCode;
}

/// Old-style states for board creation (backward compatibility)
class CanvasInitial extends CanvasState {
  CanvasInitial() : super();
}

class CanvasCreating extends CanvasState {
  CanvasCreating() : super(isLoading: true);
}

class CanvasReady extends CanvasState {
  final String boardId;

  CanvasReady(this.boardId) : super();
}

class CanvasErrorState extends CanvasState {
  final String message;

  CanvasErrorState(this.message) : super(error: message);
}
