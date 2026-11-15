import 'package:flutter/material.dart';

import '../models/canvas_element.dart';
import 'canvas_element_geometry.dart';

/// Colour of the topmost visible element under [point], or `null` when the
/// point is over empty canvas.
///
/// This is the eyedropper's source of truth. It walks the same geometry used
/// for hit-testing, so a sampled colour always comes from an element the user
/// could actually select at that spot. Images carry no single colour and are
/// skipped; hidden elements never sample.
Color? sampleCanvasColorAt(Iterable<CanvasElement> elements, Offset point) {
  // Walk the same layers-as-bands order the painter uses, topmost first, so
  // the sampled colour belongs to the element the user sees at that spot.
  final ordered = orderedElementsForPaint(
    elements.toList(growable: false),
  );
  for (final element in ordered.reversed) {
    if (element.hidden) continue;
    if (!elementContains(element, point)) continue;

    final color = switch (element) {
      StrokeElement e => e.color,
      ShapeElement e => e.color,
      TextElement e => e.color,
      StickyNoteElement e => e.color,
      ConnectorElement e => e.color,
      // Images are skipped: sampling one bitmap pixel is not what the
      // vector eyedropper reports for every other element type.
      ImageElement _ => null,
      LayerElement _ => null,
    };
    if (color == null) continue;
    return color;
  }

  return null;
}
