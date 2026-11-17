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
  final bool isArchived;

  const CanvasBoardTitleUpdated(
    this.title, {
    this.currentUserRole = 'viewer',
    this.isArchived = false,
  });
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

/// Add an AI image to the canvas. The full image is stored by URL; the small
/// thumbnail goes into the element's inline image field.
class CanvasAddAiImageElement extends CanvasEvent {
  final String imageUrl;
  final String thumbnailBase64;
  final Offset center;
  final double width;
  final double height;
  final String? aiPrompt;
  final String? generationId;

  const CanvasAddAiImageElement({
    required this.imageUrl,
    required this.thumbnailBase64,
    required this.center,
    required this.width,
    required this.height,
    this.aiPrompt,
    this.generationId,
  });
}

/// Replace the picture of an existing image element (AI edit, repaint or
/// regenerate) in ONE CRDT update, so a single undo restores the old version.
class CanvasReplaceImageSource extends CanvasEvent {
  final String elementId;
  final String imageUrl;
  final String thumbnailBase64;

  /// Pixel size of the new image, used to keep its aspect ratio.
  final int sourceWidth;
  final int sourceHeight;
  final String? aiPrompt;
  final String? generationId;

  const CanvasReplaceImageSource({
    required this.elementId,
    required this.imageUrl,
    required this.thumbnailBase64,
    required this.sourceWidth,
    required this.sourceHeight,
    this.aiPrompt,
    this.generationId,
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

/// Update a frame's title, colour, clipping or box. Null fields are left unchanged.
class CanvasUpdateFrame extends CanvasEvent {
  final String elementId;
  final String? title;
  final Color? color;
  final Offset? center;
  final double? width;
  final double? height;
  final bool? clipContents;

  const CanvasUpdateFrame({
    required this.elementId,
    this.title,
    this.color,
    this.center,
    this.width,
    this.height,
    this.clipContents,
  });
}

/// Delete a frame, either keeping its contents on the board or deleting them
/// together with the frame in one undoable CRDT batch (F-14).
class CanvasDeleteFrame extends CanvasEvent {
  final String frameId;
  final bool deleteContents;

  const CanvasDeleteFrame(this.frameId, {this.deleteContents = false});
}

/// Insert a structured table element on the canvas (F-16).
class CanvasAddTable extends CanvasEvent {
  final Offset center;
  final int rows;
  final int columns;
  final double width;
  final double height;
  final bool headerRow;

  const CanvasAddTable({
    required this.center,
    this.rows = 3,
    this.columns = 3,
    this.width = 360,
    this.height = 180,
    this.headerRow = true,
  });
}

/// Update one cell's text or style in a [TableElement] (F-16).
class CanvasUpdateTableCell extends CanvasEvent {
  final String tableId;
  final int row;
  final int column;
  final String? text;
  final Color? backgroundColor;
  final bool clearBackgroundColor;
  final Color? textColor;
  final bool clearTextColor;
  final int? fontWeight;
  final String? textAlign;

  const CanvasUpdateTableCell({
    required this.tableId,
    required this.row,
    required this.column,
    this.text,
    this.backgroundColor,
    this.clearBackgroundColor = false,
    this.textColor,
    this.clearTextColor = false,
    this.fontWeight,
    this.textAlign,
  });
}

/// Update table structure (add/remove rows or columns, header toggle, resize
/// fractions, borders/colors/fontSize) in one undo step (F-16).
class CanvasUpdateTableStyle extends CanvasEvent {
  final String tableId;
  final int? insertRowAt;
  final int? removeRowAt;
  final int? insertColumnAt;
  final int? removeColumnAt;
  final bool? headerRow;
  final Color? borderColor;
  final double? borderWidth;
  final double? fontSize;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? headerBackgroundColor;
  final List<double>? columnFractions;
  final List<double>? rowFractions;
  final double? width;
  final double? height;

  const CanvasUpdateTableStyle({
    required this.tableId,
    this.insertRowAt,
    this.removeRowAt,
    this.insertColumnAt,
    this.removeColumnAt,
    this.headerRow,
    this.borderColor,
    this.borderWidth,
    this.fontSize,
    this.textColor,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.columnFractions,
    this.rowFractions,
    this.width,
    this.height,
  });
}

/// Add a ruler guide line at [position] along [axis] (F-18).
class CanvasAddGuide extends CanvasEvent {
  final CanvasGuideAxis axis;
  final double position;

  const CanvasAddGuide({required this.axis, required this.position});
}

/// Move an existing ruler guide by id to [position] (F-18).
class CanvasMoveGuide extends CanvasEvent {
  final String guideId;
  final double position;

  const CanvasMoveGuide({required this.guideId, required this.position});
}

/// Remove an existing ruler guide by id (F-18).
class CanvasRemoveGuide extends CanvasEvent {
  final String guideId;

  const CanvasRemoveGuide(this.guideId);
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

/// Auto-layout / tidy-up modes for a multi-element selection (F-17).
enum CanvasArrangeMode { grid, row, column, tree, flow }

/// Automatically arrange selected elements in [mode] while keeping connectors
/// attached, committed in one CRDT batch (F-17).
class CanvasArrangeSelection extends CanvasEvent {
  final CanvasArrangeMode mode;
  final String? rootId;
  final double spacing;

  const CanvasArrangeSelection(
    this.mode, {
    this.rootId,
    this.spacing = 32,
  });
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

/// Update only the outline color of the selected shape without altering its
/// independent fill color (F-10).
class CanvasUpdateSelectedShapeStrokeColor extends CanvasEvent {
  final Color strokeColor;

  const CanvasUpdateSelectedShapeStrokeColor(this.strokeColor);
}

/// Flip the selected shape horizontally or vertically (F-10).
class CanvasFlipSelectedShape extends CanvasEvent {
  final bool horizontal;
  final bool vertical;

  const CanvasFlipSelectedShape({this.horizontal = false, this.vertical = false});
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

// ============================================================
// Board history (owner-only) + member undo (D2/D3/D15)
// ============================================================

/// Subscribe to (or refresh) the owner-only activity feed (`activity_index`).
class CanvasHistoryFeedRequested extends CanvasEvent {
  final bool forceRefresh;
  const CanvasHistoryFeedRequested({this.forceRefresh = false});
}

/// Request older archived version blocks not yet loaded locally.
class CanvasHistoryLoadOlderVersionsRequested extends CanvasEvent {
  final int? beforeVersion;
  const CanvasHistoryLoadOlderVersionsRequested({this.beforeVersion});
}

/// Internal: the Firestore activity-feed stream emitted a new page.
class CanvasHistoryFeedUpdated extends CanvasEvent {
  final List<BoardActivityBlock> blocks;
  const CanvasHistoryFeedUpdated(this.blocks);
}

/// Internal: the unarchived Redis tail block was fetched or updated.
class CanvasHistoryLiveTailUpdated extends CanvasEvent {
  final BoardActivityBlock? block;
  const CanvasHistoryLiveTailUpdated(this.block);
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

/// Owner wants to restore the previewed version (whole board or scoped area).
class CanvasHistoryRestoreRequested extends CanvasEvent {
  final int version;
  final List<String>? elementIds;
  final UndoRequestArea? area;
  final String? requestId;
  const CanvasHistoryRestoreRequested(
    this.version, {
    this.elementIds,
    this.area,
    this.requestId,
  });
}

/// Toggle marquee area-selection mode for the owner to inspect the history
/// of a specific part of the board.
class CanvasToggleOwnerAreaHistorySelection extends CanvasEvent {
  final bool? enable;
  const CanvasToggleOwnerAreaHistorySelection({this.enable});
}

/// Owner selected a part of the board to view only its history and scrub/revert
/// it to a chosen point.
class CanvasHistoryAreaScrubRequested extends CanvasEvent {
  final UndoRequestArea area;
  final List<String> elementIds;
  const CanvasHistoryAreaScrubRequested({
    required this.area,
    this.elementIds = const [],
  });
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
  final UndoRequestScopeMode? scopeMode;
  const CanvasUndoRequestDraftStarted({
    this.preselectedIds = const [],
    this.area,
    this.scopeMode,
  });
}

/// Member changed whether they want only their changes undone or the whole
/// state of the selected part of the board restored.
class CanvasUndoRequestDraftScopeModeChanged extends CanvasEvent {
  final UndoRequestScopeMode scopeMode;
  const CanvasUndoRequestDraftScopeModeChanged(this.scopeMode);
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
  final UndoRequestArea? area;
  final String? requestId;
  const CanvasHistoryRevertOpsAfterRequested({
    required this.targetUid,
    required this.afterVersion,
    required this.elementIds,
    this.area,
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
