import 'package:flutter/material.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';

/// Canvas size the paint tests render into.
const Size paintGoldenSceneSize = Size(420, 440);

/// 8x8 PNG filled with [paintGoldenImageColor] on every pixel.
///
/// Generated (no hand-edited base64): 8-bit RGB, one IDAT, solid #FF2D55.
const String paintGoldenImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGP4rxuK'
    'FTEMLQkAxnNgQXz+Uj0AAAAASUVORK5CYII=';

/// The colour of every pixel in [paintGoldenImageBase64].
const Color paintGoldenImageColor = Color(0xFFFF2D55);

/// Side of the image element, in canvas pixels.
const double paintGoldenImageSide = 60;

/// Centre of the image element, in canvas coordinates.
const Offset paintGoldenImageCenter = Offset(380, 120);

/// Opaque colours that uniquely identify an element in the rendered scene.
///
/// These let the tests prove an element reached the raster without pinning
/// platform-specific bytes. The stroke (translucent ink and fill) and the frame
/// (12% fill, 65% border) are intentionally absent: their composited colours
/// depend on the board background, so they are covered by the ablation test and
/// the per-element cross-path equivalence test instead.
const Map<String, Color> paintGoldenSignatureColors = {
  'shape': Color(0xFFE0245E),
  'text': Color(0xFFE8ECF2),
  'connector': Color(0xFF1B4DFF),
  'sticky': Color(0xFFFFF9A6),
  'image': paintGoldenImageColor,
  'table': Color(0xFFCBD5E1),
};

/// The canonical scene for the paint tests.
///
/// Shared by `paint_parity_test.dart` (export pipeline) and
/// `view/canvas_painter_golden_test.dart` (interactive painter) so the two
/// render paths are compared against exactly the same input. It covers every
/// element the painters draw:
///
/// 1. filled freehand stroke  — `paintStrokeFill` + `paintCanvasStroke`
/// 2. stroked shape           — `paintShapeElement`
/// 3. rotated text + plate    — `paintTextLayoutBox`
/// 4. connector + arrowhead   — connector polyline and head
/// 5. rounded frame + title   — frame chrome
/// 6. rotated sticky note     — note plate and wrapped text
/// 7. solid-colour image     — decode + image paint; both tests assert the
///                             decoded colour covers the element's area. The
///                             interactive capture is taken under the canvas
///                             fit zoom, so its block is scaled and the
///                             assertion tolerance absorbs that.
/// 8. table with header row   — grid, header band and cell text
List<CanvasElement> paintGoldenScene() => [
  const StrokeElement(
    id: 'stroke',
    z: 1,
    points: [Offset(30, 30), Offset(90, 20), Offset(130, 55), Offset(70, 80)],
    color: Color(0xFF1B4DFF),
    strokeWidth: 6,
    opacity: 0.85,
    fillColor: Color(0xFFFFB020),
  ),
  const ShapeElement(
    id: 'shape',
    z: 2,
    shapeType: CanvasShapeType.square,
    center: Offset(210, 60),
    size: 60,
    color: Color(0xFFE0245E),
    strokeWidth: 4,
    isFilled: false,
  ),
  const TextElement(
    id: 'text',
    z: 3,
    text: 'Ink',
    center: Offset(300, 30),
    color: Color(0xFF101828),
    width: 90,
    height: 40,
    fontSize: 22,
    rotation: 0.2,
    backgroundColor: Color(0xFFE8ECF2),
    padding: 5,
  ),
  const ConnectorElement(
    id: 'connector',
    z: 4,
    startPoint: Offset(30, 150),
    endPoint: Offset(190, 150),
    color: Color(0xFF1B4DFF),
    strokeWidth: 2.5,
    hasArrowhead: true,
  ),
  const FrameElement(
    id: 'frame',
    z: 5,
    center: Offset(110, 235),
    width: 150,
    height: 100,
    title: 'Frame',
    color: Color(0xFF64748B),
    cornerRadius: 8,
  ),
  const StickyNoteElement(
    id: 'sticky',
    z: 6,
    center: Offset(280, 235),
    width: 110,
    height: 90,
    text: 'Note',
    color: Color(0xFFFFF9A6),
    rotation: -0.05,
  ),
  const ImageElement(
    id: 'image',
    z: 7,
    center: paintGoldenImageCenter,
    width: paintGoldenImageSide,
    height: paintGoldenImageSide,
    imageBase64: paintGoldenImageBase64,
  ),
  const TableElement(
    id: 'table',
    z: 8,
    center: Offset(210, 380),
    width: 300,
    height: 90,
    rows: 2,
    columns: 3,
    headerRow: true,
    borderColor: Color(0xFFCBD5E1),
    borderWidth: 1.5,
    cells: [
      TableCellData(text: 'A'),
      TableCellData(text: 'B'),
      TableCellData(text: 'C'),
      TableCellData(text: '1'),
      TableCellData(text: '2'),
      TableCellData(text: '3'),
    ],
  ),
];
