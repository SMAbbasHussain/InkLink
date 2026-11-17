/// Customizable canvas actions that can be pinned to the bottom toolbar or
/// accessed from the bottom-right tools tray.
enum CanvasToolbarAction {
  select,
  hand,
  pen,
  highlight,
  eraser,
  fill,
  shape,
  arrow,
  stickyNote,
  frame,
  text,
  image,
  layers,
  templates,
  table,
  connector;

  /// Balanced default subset shown on the bottom toolbar for new users.
  /// Remaining actions live in the bottom-right tools tray.
  static const List<CanvasToolbarAction> defaultBottomBarActions = [
    CanvasToolbarAction.select,
    CanvasToolbarAction.hand,
    CanvasToolbarAction.pen,
    CanvasToolbarAction.eraser,
    CanvasToolbarAction.shape,
    CanvasToolbarAction.stickyNote,
    CanvasToolbarAction.text,
  ];

  /// Stable persistence key used in local preferences.
  String get id => switch (this) {
    CanvasToolbarAction.select => 'select',
    CanvasToolbarAction.hand => 'hand',
    CanvasToolbarAction.pen => 'pen',
    CanvasToolbarAction.highlight => 'highlight',
    CanvasToolbarAction.eraser => 'eraser',
    CanvasToolbarAction.fill => 'fill',
    CanvasToolbarAction.shape => 'shape',
    CanvasToolbarAction.arrow => 'arrow',
    CanvasToolbarAction.stickyNote => 'sticky_note',
    CanvasToolbarAction.frame => 'frame',
    CanvasToolbarAction.text => 'text',
    CanvasToolbarAction.image => 'image',
    CanvasToolbarAction.layers => 'layers',
    CanvasToolbarAction.templates => 'templates',
    CanvasToolbarAction.table => 'table',
    CanvasToolbarAction.connector => 'connector',
  };

  /// Full label displayed in settings and lists.
  String get label => switch (this) {
    CanvasToolbarAction.select => 'Select',
    CanvasToolbarAction.hand => 'Hand (Pan)',
    CanvasToolbarAction.pen => 'Pen',
    CanvasToolbarAction.highlight => 'Highlighter',
    CanvasToolbarAction.eraser => 'Eraser',
    CanvasToolbarAction.fill => 'Fill',
    CanvasToolbarAction.shape => 'Shapes',
    CanvasToolbarAction.arrow => 'Arrow',
    CanvasToolbarAction.stickyNote => 'Sticky Note',
    CanvasToolbarAction.frame => 'Frame',
    CanvasToolbarAction.text => 'Text',
    CanvasToolbarAction.image => 'Image',
    CanvasToolbarAction.layers => 'Layers',
    CanvasToolbarAction.templates => 'Templates',
    CanvasToolbarAction.table => 'Table',
    CanvasToolbarAction.connector => 'Connector / Link',
  };

  /// Compact label rendered beneath toolbar and tray buttons.
  String get shortLabel => switch (this) {
    CanvasToolbarAction.select => 'Select',
    CanvasToolbarAction.hand => 'Hand',
    CanvasToolbarAction.pen => 'Pen',
    CanvasToolbarAction.highlight => 'Highlight',
    CanvasToolbarAction.eraser => 'Eraser',
    CanvasToolbarAction.fill => 'Fill',
    CanvasToolbarAction.shape => 'Shape',
    CanvasToolbarAction.arrow => 'Arrow',
    CanvasToolbarAction.stickyNote => 'Sticky',
    CanvasToolbarAction.frame => 'Frame',
    CanvasToolbarAction.text => 'Text',
    CanvasToolbarAction.image => 'Image',
    CanvasToolbarAction.layers => 'Layers',
    CanvasToolbarAction.templates => 'Templates',
    CanvasToolbarAction.table => 'Table',
    CanvasToolbarAction.connector => 'Link',
  };

  /// Tooltip / subtitle explaining what the action does.
  String get description => switch (this) {
    CanvasToolbarAction.select => 'Select, move, and resize elements',
    CanvasToolbarAction.hand => 'Pan the canvas (or hold Space)',
    CanvasToolbarAction.pen => 'Freehand pen & brush settings',
    CanvasToolbarAction.highlight => 'Wide translucent marker',
    CanvasToolbarAction.eraser => 'Erase strokes or elements',
    CanvasToolbarAction.fill => 'Tap a shape to fill with current color',
    CanvasToolbarAction.shape => 'Choose a shape to draw on canvas',
    CanvasToolbarAction.arrow => 'Drag, or tap two elements to connect',
    CanvasToolbarAction.stickyNote => 'Insert a colored sticky note',
    CanvasToolbarAction.frame => 'Add a titled section frame',
    CanvasToolbarAction.text => 'Tap the canvas to add text',
    CanvasToolbarAction.image => 'Insert an image onto the board',
    CanvasToolbarAction.layers => 'Manage layers, order, and visibility',
    CanvasToolbarAction.templates => 'Insert a starter board template',
    CanvasToolbarAction.table => 'Insert a structured table',
    CanvasToolbarAction.connector => 'Link two elements with a connector',
  };

  /// Whether the user must have edit permission to invoke this action.
  bool get requiresEdit => switch (this) {
    CanvasToolbarAction.select ||
    CanvasToolbarAction.hand ||
    CanvasToolbarAction.layers => false,
    _ => true,
  };

  static CanvasToolbarAction? fromId(String id) {
    for (final value in CanvasToolbarAction.values) {
      if (value.id == id) return value;
    }
    return null;
  }

  static List<String> encodeIds(List<CanvasToolbarAction> actions) => [
    for (final action in actions) action.id,
  ];

  /// Parses saved action IDs in order, deduplicating unknown/repeated tokens.
  /// Returns [defaultBottomBarActions] when [rawIds] is null (never configured).
  static List<CanvasToolbarAction> decodeIds(List<String>? rawIds) {
    if (rawIds == null) return defaultBottomBarActions;
    final seen = <CanvasToolbarAction>{};
    final result = <CanvasToolbarAction>[];
    for (final raw in rawIds) {
      final parsed = fromId(raw);
      if (parsed != null && seen.add(parsed)) {
        result.add(parsed);
      }
    }
    if (rawIds.isNotEmpty && result.isEmpty) {
      return defaultBottomBarActions;
    }
    return result;
  }

  /// Returns all remaining actions not included in [barActions], preserving
  /// canonical enum order.
  static List<CanvasToolbarAction> actionsNotOnBar(
    List<CanvasToolbarAction> barActions,
  ) {
    final pinned = barActions.toSet();
    return [
      for (final action in CanvasToolbarAction.values)
        if (!pinned.contains(action)) action,
    ];
  }
}
