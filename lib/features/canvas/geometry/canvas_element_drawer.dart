import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/canvas_element.dart';
import 'canvas_element_geometry.dart';

/// Paints the "no decoded bitmap yet" stand-in for an image element.
///
/// The two render paths draw different placeholders on purpose: the canvas
/// shows the pending size so the author can keep working, the exporter shows a
/// neutral plate so a file never ships a debug string. Each path supplies its
/// own; the drawer only decides *when* it is used.
typedef ImagePlaceholderPainter = void Function(
  Canvas canvas,
  Rect rect,
  RRect rrect,
);

/// Draws one [element] with the shared painters.
///
/// This is the single dispatch for element painting. The export pipeline feeds
/// persisted [CanvasElement]s straight in; the interactive painter feeds its
/// view models through adapters. An element type therefore cannot be wired into
/// one path and forgotten in the other — adding a case here serves both.
///
/// Parameters the two paths legitimately disagree on stay explicit:
///
/// * [strokeSpacing] — the canvas passes the element's persisted spacing, the
///   exporter leaves it null so the brush preset decides (a preserved
///   difference catalogued in `docs/canvas/paint-parity.md`).
/// * [imagePlaceholder] — see [ImagePlaceholderPainter].
/// * [resolvedConnectorEnds] — the canvas resolves anchors against its view
///   models, which carry live geometry; the exporter resolves against the
///   persisted [elementMap] when no ends are supplied.
void paintSharedElement(
  Canvas canvas,
  CanvasElement element, {
  Map<String, CanvasElement> elementMap = const {},
  ui.Image? decodedImage,
  double? strokeSpacing,
  ImagePlaceholderPainter? imagePlaceholder,
  (Offset, Offset)? resolvedConnectorEnds,
}) {
  switch (element) {
    case StrokeElement stroke:
      paintStrokeFill(
        canvas: canvas,
        points: stroke.points,
        fillColor: stroke.fillColor,
        opacity: stroke.opacity,
      );
      paintCanvasStroke(
        canvas: canvas,
        points: stroke.points,
        pressures: stroke.pressures,
        tilts: stroke.tilts,
        color: stroke.color,
        strokeWidth: stroke.strokeWidth,
        strokeOpacity: stroke.opacity,
        brushType: stroke.brushType,
        brushId: stroke.brushId,
        spacing: strokeSpacing,
        textureSeed: stroke.textureSeed,
      );

    case ShapeElement shape:
      paintShapeElement(canvas, shape);

    case TextElement text:
      if (text.text.isEmpty) return;
      // Same layout the canvas uses, so exported text cannot drift in size,
      // alignment or wrapping.
      final layout = CanvasTextLayout.forElement(text);
      try {
        paintTextLayoutBox(
          canvas,
          layout: layout,
          box: textElementRect(text),
          rotation: text.rotation,
          background: text.backgroundColor,
          backgroundPadding: text.padding,
        );
      } finally {
        layout.dispose();
      }

    case StickyNoteElement note:
      paintStickyNoteElement(canvas, note);

    case ConnectorElement connector:
      final (start, end) =
          resolvedConnectorEnds ??
          resolveConnectorEndpoints(connector, elementMap);
      paintConnectorElement(
        canvas,
        start,
        end,
        lineStyle: connector.lineStyle,
        color: connector.color,
        strokeWidth: connector.strokeWidth,
        cornerRadius: connector.cornerRadius,
        dashPattern: connector.dashPattern,
        startArrowhead: connector.startArrowhead,
        endArrowhead: connector.endArrowhead,
        label: connector.label,
        labelColor: connector.labelColor,
        labelFontSize: connector.labelFontSize,
      );

    case ImageElement image:
      paintImageElement(
        canvas,
        image,
        decodedImage,
        placeholder: imagePlaceholder,
      );

    case FrameElement frame:
      paintFrameElement(canvas, frame);

    case TableElement table:
      paintTableElement(canvas, table);

    case LayerElement _:
      // Layers are organisational and never draw ink.
      break;
  }
}
