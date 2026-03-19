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
  final List<CanvasElement> elements;
  final List<Offset> currentStroke;
  final Color selectedColor;
  final double strokeWidth;
  final String? activeTray;
  final bool showTrayTips;
  final bool isLoading;
  final String? error;

  CanvasState({
    this.elements = const [],
    this.currentStroke = const [],
    this.selectedColor = Colors.black,
    this.strokeWidth = 5,
    this.activeTray,
    this.showTrayTips = false,
    this.isLoading = false,
    this.error,
  });

  /// Create a copy with optional field overrides
  CanvasState copyWith({
    List<CanvasElement>? elements,
    List<Offset>? currentStroke,
    Color? selectedColor,
    double? strokeWidth,
    Object? activeTray = _unset,
    bool? showTrayTips,
    bool? isLoading,
    Object? error = _unset,
  }) {
    return CanvasState(
      elements: elements ?? this.elements,
      currentStroke: currentStroke ?? this.currentStroke,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      activeTray: activeTray == _unset
          ? this.activeTray
          : activeTray as String?,
      showTrayTips: showTrayTips ?? this.showTrayTips,
      isLoading: isLoading ?? this.isLoading,
      error: error == _unset ? this.error : error as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasState &&
          runtimeType == other.runtimeType &&
          elements == other.elements &&
          currentStroke == other.currentStroke &&
          selectedColor == other.selectedColor &&
          strokeWidth == other.strokeWidth &&
          activeTray == other.activeTray &&
          showTrayTips == other.showTrayTips &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode =>
      elements.hashCode ^
      currentStroke.hashCode ^
      selectedColor.hashCode ^
      strokeWidth.hashCode ^
      activeTray.hashCode ^
      showTrayTips.hashCode ^
      isLoading.hashCode ^
      error.hashCode;
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
