import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/models/canvas/canvas_toolbar_action.dart';

/// Shared icon lookup for [CanvasToolbarAction] across canvas & settings UI.
IconData iconForCanvasToolbarAction(CanvasToolbarAction action) {
  return switch (action) {
    CanvasToolbarAction.select => LucideIcons.mousePointer2,
    CanvasToolbarAction.hand => LucideIcons.hand,
    CanvasToolbarAction.pen => LucideIcons.penLine,
    CanvasToolbarAction.highlight => LucideIcons.highlighter,
    CanvasToolbarAction.eraser => LucideIcons.eraser,
    CanvasToolbarAction.fill => LucideIcons.paintBucket,
    CanvasToolbarAction.shape => LucideIcons.shapes,
    CanvasToolbarAction.arrow => LucideIcons.arrowRight,
    CanvasToolbarAction.stickyNote => LucideIcons.stickyNote,
    CanvasToolbarAction.frame => LucideIcons.frame,
    CanvasToolbarAction.text => LucideIcons.type,
    CanvasToolbarAction.image => LucideIcons.image,
    CanvasToolbarAction.layers => LucideIcons.layers,
    CanvasToolbarAction.templates => LucideIcons.layoutTemplate,
    CanvasToolbarAction.table => LucideIcons.table,
    CanvasToolbarAction.connector => LucideIcons.spline,
  };
}
