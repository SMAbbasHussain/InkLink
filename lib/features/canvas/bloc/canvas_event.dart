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

  const CanvasBoardTitleUpdated(this.title);
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
  const CanvasEndStroke();
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

/// Open/close a tray panel
class CanvasToggleTray extends CanvasEvent {
  final String trayName;

  const CanvasToggleTray(this.trayName);
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
