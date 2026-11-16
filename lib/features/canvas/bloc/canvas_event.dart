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
  final double pressure;
  final double tilt;

  const CanvasStartStroke(this.point, {this.pressure = 1.0, this.tilt = 0});
}

/// Append point to current stroke
class CanvasAppendStroke extends CanvasEvent {
  final Offset point;
  final double pressure;
  final double tilt;

  const CanvasAppendStroke(this.point, {this.pressure = 1.0, this.tilt = 0});
}

/// End and save the current stroke
class CanvasEndStroke extends CanvasEvent {
  final List<Offset>? smoothedPoints;
  final List<double>? pressures;
  final List<double>? tilts;
  final bool smoothAfterDrawing;

  const CanvasEndStroke({
    this.smoothedPoints,
    this.pressures,
    this.tilts,
    this.smoothAfterDrawing = false,
  });
}

/// Toggle hold-to-snap QuickShape.
class CanvasSetQuickShapeEnabled extends CanvasEvent {
  final bool enabled;

  const CanvasSetQuickShapeEnabled(this.enabled);
}

/// Discard an in-progress stroke without committing it, used when palm or
/// multi-pointer input takes over the gesture.
class CanvasCancelStroke extends CanvasEvent {
  const CanvasCancelStroke();
}

/// Whether a one-finger drag paints (true) or pans (false). Stylus input
/// always paints.
class CanvasSetFingerDrawing extends CanvasEvent {
  final bool enabled;

  const CanvasSetFingerDrawing(this.enabled);
}

/// Commit a held stroke as a clean shape, replacing the freehand commit.
class CanvasCommitQuickShape extends CanvasEvent {
  final QuickShapeMatch match;
  final List<Offset> points;
  final List<double> pressures;
  final List<double> tilts;

  const CanvasCommitQuickShape({
    required this.match,
    required this.points,
    this.pressures = const [],
    this.tilts = const [],
  });
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

/// Create a first-class text object at [topLeft].
class CanvasAddText extends CanvasEvent {
  final Offset topLeft;
  final String text;
  final Color color;
  final double fontSize;
  final int fontWeight;
  final String textAlign;
  final double rotation;

  const CanvasAddText({
    required this.topLeft,
    required this.text,
    required this.color,
    this.fontSize = 16.0,
    this.fontWeight = 600,
    this.textAlign = 'left',
    this.rotation = 0,
  });
}

/// Update any subset of a text object's content or style.
class CanvasUpdateText extends CanvasEvent {
  final String elementId;
  final String? text;
  final Color? color;
  final double? fontSize;
  final int? fontWeight;
  final String? fontFamily;
  final String? textAlign;
  final double? rotation;
  final Offset? topLeft;
  final double? width;
  final double? height;
  final int? maxLines;
  final double? lineHeight;
  final bool? autoSize;
  final Color? backgroundColor;

  const CanvasUpdateText({
    required this.elementId,
    this.text,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.textAlign,
    this.rotation,
    this.topLeft,
    this.width,
    this.height,
    this.maxLines,
    this.lineHeight,
    this.autoSize,
    this.backgroundColor,
  });
}

/// Add image element to canvas
class CanvasAddImageElement extends CanvasEvent {
  final Uint8List imageBytes;
  final Offset center;
  final double width;
  final double height;

  final ImageElement? style;

  const CanvasAddImageElement(
    this.imageBytes,
    this.center, {
    required this.width,
    required this.height,
    this.style,
  });
}

/// Add sticky note to canvas
class CanvasAddStickyNote extends CanvasEvent {
  final Offset center;
  final String text;
  final Color color;
  final double width;
  final double height;

  final double fontSize;
  final int fontWeight;
  final Color textColor;
  final String textAlign;
  final bool autoSize;

  const CanvasAddStickyNote({
    required this.center,
    this.text = '',
    this.color = const Color(0xFFFFF9A6),
    this.width = 160.0,
    this.height = 160.0,
    this.fontSize = 14,
    this.fontWeight = 500,
    this.textColor = const Color(0xFF1E293B),
    this.textAlign = 'left',
    this.autoSize = true,
  });
}

/// Update existing sticky note
class CanvasUpdateStickyNote extends CanvasEvent {
  final String elementId;
  final String? text;
  final Color? color;
  final Offset? center;
  final double? width;
  final double? height;

  final double? fontSize;
  final int? fontWeight;
  final Color? textColor;
  final String? textAlign;
  final bool? autoSize;

  const CanvasUpdateStickyNote({
    required this.elementId,
    this.text,
    this.color,
    this.center,
    this.width,
    this.height,
    this.fontSize,
    this.fontWeight,
    this.textColor,
    this.textAlign,
    this.autoSize,
  });
}

class CanvasConvertStickyNote extends CanvasEvent {
  const CanvasConvertStickyNote(this.elementId, {this.toShape = false});
  final String elementId;
  final bool toShape;
}

/// Insert a titled frame behind the board's existing content.
class CanvasAddFrame extends CanvasEvent {
  final Offset center;
  final String title;
  final Color color;
  final double width;
  final double height;

  const CanvasAddFrame({
    required this.center,
    this.title = 'Frame',
    this.color = const Color(0xFF64748B),
    this.width = FrameElement.defaultWidth,
    this.height = FrameElement.defaultHeight,
  });
}

/// Replace the board background/page settings (one collaborative payload).
class CanvasSetBoardSettings extends CanvasEvent {
  final CanvasBoardSettings settings;

  const CanvasSetBoardSettings(this.settings);
}

/// Bulk-create elements from a template or pasted layout.
///
/// Each payload may carry a template-local `id`; imported elements get fresh
/// ids and connector endpoints are remapped to them in one undo step.
class CanvasImportElements extends CanvasEvent {
  final List<Map<String, dynamic>> payloads;
  final Offset offset;

  const CanvasImportElements(this.payloads, {this.offset = Offset.zero});
}

/// Update a frame's title, colour or box. Null fields are left unchanged.
class CanvasUpdateFrame extends CanvasEvent {
  final String elementId;
  final String? title;
  final Color? color;
  final Offset? center;
  final double? width;
  final double? height;

  const CanvasUpdateFrame({
    required this.elementId,
    this.title,
    this.color,
    this.center,
    this.width,
    this.height,
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

/// Update a connector's style, arrowheads, dash, corner radius or label.
///
/// Null fields are left unchanged. An empty [dashPattern] clears the dash
/// (solid line); [clearLabelColor] reverts the label to the line colour.
/// [hasArrowhead] is the legacy end-arrow flag; [endArrowhead] wins if both.
class CanvasUpdateConnector extends CanvasEvent {
  final String elementId;
  final String? lineStyle;
  final Color? color;
  final double? strokeWidth;
  final bool? hasArrowhead;
  final bool? startArrowhead;
  final bool? endArrowhead;
  final List<double>? dashPattern;
  final double? cornerRadius;
  final String? label;
  final Color? labelColor;
  final bool clearLabelColor;
  final double? labelFontSize;

  const CanvasUpdateConnector({
    required this.elementId,
    this.lineStyle,
    this.color,
    this.strokeWidth,
    this.hasArrowhead,
    this.startArrowhead,
    this.endArrowhead,
    this.dashPattern,
    this.cornerRadius,
    this.label,
    this.labelColor,
    this.clearLabelColor = false,
    this.labelFontSize,
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

class CanvasReplaceImageElement extends CanvasEvent {
  const CanvasReplaceImageElement(
    this.elementId,
    this.imageBytes, {
    this.style,
  });

  final String elementId;
  final Uint8List imageBytes;
  final ImageElement? style;
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

/// Non-destructive image styling: flips, quarter turns, crop, border,
/// colour filters and reference mode. Null fields are left unchanged.
class CanvasUpdateImageStyle extends CanvasEvent {
  final String elementId;
  final bool? flipH;
  final bool? flipV;

  /// Clockwise quarter turns added to the current rotation.
  final int quarterTurns;

  /// Normalized crop of the source image; [resetCrop] restores the full image.
  final Rect? crop;
  final bool resetCrop;
  final double? borderRadius;
  final double? borderWidth;
  final Color? borderColor;
  final double? brightness;
  final double? contrast;
  final double? saturation;
  final bool resetFilters;

  /// Enabling locks the image and sends it to the back of its layer;
  /// disabling is the one style change a locked reference image accepts.
  final bool? isReference;
  final double? opacity;

  const CanvasUpdateImageStyle({
    required this.elementId,
    this.flipH,
    this.flipV,
    this.quarterTurns = 0,
    this.crop,
    this.resetCrop = false,
    this.borderRadius,
    this.borderWidth,
    this.borderColor,
    this.brightness,
    this.contrast,
    this.saturation,
    this.resetFilters = false,
    this.isReference,
    this.opacity,
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

/// Select a brush preset atomically: brush id, default width and opacity.
class CanvasApplyBrushPreset extends CanvasEvent {
  final String presetId;

  const CanvasApplyBrushPreset(this.presetId);
}

/// Enable or disable stylus pressure dynamics.
class CanvasUpdateStylusPressure extends CanvasEvent {
  final bool enabled;

  const CanvasUpdateStylusPressure(this.enabled);
}

class CanvasUpdateStabilizer extends CanvasEvent {
  final double strength;

  const CanvasUpdateStabilizer(this.strength);
}

/// Set the current tool mode (doodle, shape, eraser, text, etc.)
class CanvasSetToolMode extends CanvasEvent {
  final CanvasToolMode mode;
  final CanvasShapeType? shapeType;
  final bool keepTray;

  const CanvasSetToolMode(this.mode, {this.shapeType, this.keepTray = false});
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

/// Replace the selection with [ids] (ids that no longer exist are ignored).
class CanvasSelectElements extends CanvasEvent {
  final Set<String> ids;

  const CanvasSelectElements(this.ids);
}

/// Select every element whose bounds intersect [rect] (marquee selection).
class CanvasSelectInRect extends CanvasEvent {
  final Rect rect;
  final bool additive;

  const CanvasSelectInRect(this.rect, {this.additive = false});
}

/// Translate every selected element by [delta] in world coordinates.
class CanvasTranslateSelection extends CanvasEvent {
  final Offset delta;

  const CanvasTranslateSelection(this.delta);
}

/// Scale every selected element from [sourceBounds] into [targetBounds].
///
/// The union box is scaled, not each element independently, so relative
/// spacing changes exactly like a design tool's group resize.
class CanvasScaleSelection extends CanvasEvent {
  final Rect sourceBounds;
  final Rect targetBounds;

  const CanvasScaleSelection({
    required this.sourceBounds,
    required this.targetBounds,
  });
}

/// Rotate every selected element around [pivot] by [radians].
class CanvasRotateSelection extends CanvasEvent {
  final Offset pivot;
  final double radians;

  const CanvasRotateSelection({required this.pivot, required this.radians});
}

/// Select elements whose centre or whole box falls inside a freehand loop.
class CanvasSelectInLasso extends CanvasEvent {
  final List<Offset> points;
  final bool additive;

  const CanvasSelectInLasso(this.points, {this.additive = false});
}

/// Switch how empty-canvas drags collect elements.
class CanvasSetSelectionMode extends CanvasEvent {
  final CanvasSelectionMode mode;

  const CanvasSetSelectionMode(this.mode);
}

/// Copy the current selection into the in-app clipboard.
class CanvasCopySelection extends CanvasEvent {
  const CanvasCopySelection();
}

/// Paste the in-app clipboard above the board with a cascading offset.
class CanvasPasteSelection extends CanvasEvent {
  const CanvasPasteSelection();
}

/// Show or hide an element from the layers panel.
class CanvasSetElementVisibility extends CanvasEvent {
  final String elementId;
  final bool visible;

  const CanvasSetElementVisibility(this.elementId, this.visible);
}

/// Lock or unlock an element from the layers panel.
class CanvasSetElementLocked extends CanvasEvent {
  final String elementId;
  final bool locked;

  const CanvasSetElementLocked(this.elementId, this.locked);
}

/// Set an element's paint opacity (0..1).
class CanvasSetElementOpacity extends CanvasEvent {
  final String elementId;
  final double opacity;

  const CanvasSetElementOpacity(this.elementId, this.opacity);
}

/// Create a named layer and make it the active drawing target.
class CanvasAddLayer extends CanvasEvent {
  final String name;

  const CanvasAddLayer(this.name);
}

/// Rename an existing layer.
class CanvasRenameLayer extends CanvasEvent {
  final String layerId;
  final String name;

  const CanvasRenameLayer(this.layerId, this.name);
}

/// Delete a layer. Its elements stay on the board as ungrouped content.
class CanvasDeleteLayer extends CanvasEvent {
  final String layerId;

  const CanvasDeleteLayer(this.layerId);
}

/// Choose which layer receives new elements; null selects the default group.
class CanvasSetActiveLayer extends CanvasEvent {
  final String? layerId;

  const CanvasSetActiveLayer(this.layerId);
}

/// Move an element to [newIndex] in bottom-to-top paint order.
class CanvasReorderElement extends CanvasEvent {
  final String elementId;
  final int newIndex;

  const CanvasReorderElement(this.elementId, this.newIndex);
}

/// Move an element into [layerId] (null for the Default band) without
/// rewriting the element payload or its z order.
class CanvasMoveElementToLayer extends CanvasEvent {
  final String elementId;
  final String? layerId;

  const CanvasMoveElementToLayer(this.elementId, this.layerId);
}

/// Change a layer's blend mode (`normal`, `multiply`, `screen`, `overlay`,
/// `darken` or `lighten`).
class CanvasUpdateLayerBlendMode extends CanvasEvent {
  final String layerId;
  final String blendMode;

  const CanvasUpdateLayerBlendMode(this.layerId, this.blendMode);
}

/// Move a layer band to [newIndex] in bottom-to-top layer order.
class CanvasReorderLayer extends CanvasEvent {
  final String layerId;
  final int newIndex;

  const CanvasReorderLayer(this.layerId, this.newIndex);
}

/// Alignment/distribution actions for a multi-element selection.
enum CanvasSelectionAlignment {
  left,
  centerX,
  right,
  top,
  centerY,
  bottom,
  distributeHorizontal,
  distributeVertical,
}

class CanvasAlignSelection extends CanvasEvent {
  final CanvasSelectionAlignment alignment;

  const CanvasAlignSelection(this.alignment);
}

/// Clone [ids] with new element ids, offset slightly, and select the clones.
class CanvasDuplicateElements extends CanvasEvent {
  final Set<String> ids;

  const CanvasDuplicateElements(this.ids);
}

/// Delete [ids] as one action, detaching any connector ends that referenced
/// them.
class CanvasDeleteElements extends CanvasEvent {
  final Set<String> ids;

  const CanvasDeleteElements(this.ids);
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

/// Fill the closed interior of a freehand stroke.
class CanvasFillStroke extends CanvasEvent {
  final String strokeId;
  final Color color;

  const CanvasFillStroke({required this.strokeId, required this.color});
}

/// Remove a freehand stroke's interior fill.
class CanvasClearStrokeFill extends CanvasEvent {
  final String strokeId;

  const CanvasClearStrokeFill(this.strokeId);
}

/// Apply shared style values to every editable element in a multi-selection
/// as one undoable CRDT batch. Null fields are left untouched.
class CanvasUpdateSelectionStyle extends CanvasEvent {
  final Set<String> ids;
  final Color? color;
  final double? opacity;
  final bool? locked;
  final bool? visible;

  const CanvasUpdateSelectionStyle(
    this.ids, {
    this.color,
    this.opacity,
    this.locked,
    this.visible,
  });
}

/// Move every selected element into [layerId] (null for the Default band) as
/// one undoable batch.
class CanvasMoveSelectionToLayer extends CanvasEvent {
  final Set<String> ids;
  final String? layerId;

  const CanvasMoveSelectionToLayer(this.ids, this.layerId);
}

/// Restore a local version checkpoint. Each entry is `{id, data}` where data is
/// the serialized element payload. The whole restore is one undoable batch.
class CanvasRestoreSnapshot extends CanvasEvent {
  final List<Map<String, dynamic>> elements;

  const CanvasRestoreSnapshot(this.elements);
}

/// Retry local CRDT updates that could not reach the collaboration service.
class CanvasRetrySync extends CanvasEvent {
  const CanvasRetrySync();
}

/// Update selected stroke brush type
class CanvasUpdateSelectedStrokeBrushType extends CanvasEvent {
  final String brushType;
  const CanvasUpdateSelectedStrokeBrushType(this.brushType);
}

/// Confirms the end of a continuous stroke-property edit (slider gesture)
/// so the snackbar offers one undo affordance after the live writes.
class CanvasCommitSelectedStrokeEdits extends CanvasEvent {
  const CanvasCommitSelectedStrokeEdits();
}

/// Publish an in-progress selected-shape move preview.
class CanvasPreviewMoveSelectedShape extends CanvasEvent {
  final Offset center;

  const CanvasPreviewMoveSelectedShape(this.center);
}

/// Resize selected shape.
///
/// [size] drives uniform resize (sticky/image/text and legacy callers); when
/// [width]/[height] are positive they drive a free-aspect shape resize.
class CanvasResizeSelectedShape extends CanvasEvent {
  final double size;
  final double width;
  final double height;

  const CanvasResizeSelectedShape(this.size, {this.width = 0, this.height = 0});
}

/// Publish an in-progress selected-shape resize preview.
class CanvasPreviewResizeSelectedShape extends CanvasEvent {
  final double size;
  final double width;
  final double height;

  const CanvasPreviewResizeSelectedShape(
    this.size, {
    this.width = 0,
    this.height = 0,
  });
}

/// Toggle fill mode for selected shape
class CanvasToggleSelectedShapeFill extends CanvasEvent {
  final bool isFilled;

  const CanvasToggleSelectedShapeFill(this.isFilled);
}

/// Update a shape's independent fill (solid, linear, radial or none).
class CanvasUpdateShapeFill extends CanvasEvent {
  final String? shapeId;
  final String? fillMode;
  final Color? fillColor;
  final Color? gradientStart;
  final Color? gradientEnd;
  final double? gradientAngle;

  const CanvasUpdateShapeFill({
    this.shapeId,
    this.fillMode,
    this.fillColor,
    this.gradientStart,
    this.gradientEnd,
    this.gradientAngle,
  });
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

/// Update the outline width of the selected shape (independent of fill).
class CanvasUpdateSelectedShapeStrokeWidth extends CanvasEvent {
  final double strokeWidth;

  const CanvasUpdateSelectedShapeStrokeWidth(this.strokeWidth);
}

/// Update the outline opacity of the selected shape (0..1).
class CanvasUpdateSelectedShapeStrokeOpacity extends CanvasEvent {
  final double strokeOpacity;

  const CanvasUpdateSelectedShapeStrokeOpacity(this.strokeOpacity);
}

/// Set the outline dash pattern; null restores a solid stroke.
class CanvasUpdateSelectedShapeDash extends CanvasEvent {
  final List<double>? dashPattern;

  const CanvasUpdateSelectedShapeDash(this.dashPattern);
}

/// Edit the centered shape label. Null fields are left unchanged;
/// [clearLabelColor] resets the label color to inherit the stroke color.
class CanvasUpdateSelectedShapeLabel extends CanvasEvent {
  final String? label;
  final Color? labelColor;
  final bool clearLabelColor;
  final double? labelFontSize;
  final int? labelFontWeight;
  final String? labelTextAlign;

  const CanvasUpdateSelectedShapeLabel({
    this.label,
    this.labelColor,
    this.clearLabelColor = false,
    this.labelFontSize,
    this.labelFontWeight,
    this.labelTextAlign,
  });
}

/// Toggle the start/end arrowheads on a linear shape.
class CanvasUpdateSelectedShapeArrowheads extends CanvasEvent {
  final bool? startArrowhead;
  final bool? endArrowhead;

  const CanvasUpdateSelectedShapeArrowheads({
    this.startArrowhead,
    this.endArrowhead,
  });
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
  final CanvasExportOptions? options;
  final bool shareAfterExport;

  /// Global rect of the tap target, used to anchor the native share popover on
  /// iPad/Mac. Null is tolerated on phones but fails to present on tablets.
  final Rect? sharePositionOrigin;

  const CanvasExportBoardRequested({
    required this.format,
    this.options,
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

  const CanvasAddCommentRequested({required this.text, this.canvasPosition});
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
