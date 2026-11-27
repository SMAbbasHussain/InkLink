// Domain-facing alias for the canvas geometry module.
//
// Kept as a re-export (like `domain/models/canvas/canvas_element.dart`) so
// services such as the exporter can share painter geometry without importing
// deep into the feature tree.
export '../../../features/canvas/geometry/canvas_element_geometry.dart';
export '../../../features/canvas/geometry/canvas_element_drawer.dart';
export '../../../features/canvas/models/brush_preset.dart';
export 'canvas_render_utils.dart';
