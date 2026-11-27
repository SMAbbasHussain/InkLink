import 'dart:math' as math;
import 'dart:ui';

import '../models/canvas_tool_mode.dart';

const double minCanvasZoom = 0.1;
const double maxCanvasZoom = 4.0;
const double _scrollZoomSensitivity = 0.0015;

double clampCanvasZoom(double scale) =>
    scale.clamp(minCanvasZoom, maxCanvasZoom);

/// True when the current gesture should move/zoom the camera instead of
/// drawing. Viewers, two-finger gestures, the hand tool and held Space all pan.
/// [forceOneFingerPan] is used when finger drawing is disabled: an unclaimed
/// single-finger drag on a brush tool becomes a canvas pan.
bool startsCanvasTransform({
  required CanvasToolMode tool,
  required bool spacePressed,
  required int pointerCount,
  required bool canEdit,
  bool forceOneFingerPan = false,
}) =>
    tool == CanvasToolMode.hand ||
    spacePressed ||
    pointerCount >= 2 ||
    forceOneFingerPan ||
    !canEdit;

/// Offset that keeps [worldPoint] under [focalPoint] after zooming to [scale].
Offset canvasOffsetForZoom({
  required Offset focalPoint,
  required Offset worldPoint,
  required double scale,
}) => Offset(
  focalPoint.dx - worldPoint.dx * scale,
  focalPoint.dy - worldPoint.dy * scale,
);

/// Offset for a pinch that keeps the world point under the initial pinch
/// centre pinned while the scale changes. Focal drift is deliberately ignored:
/// a pinch must zoom without also panning.
Offset canvasOffsetForPinch({
  required Offset startFocal,
  required Offset startOffset,
  required double startScale,
  required double nextScale,
}) => startFocal - (startFocal - startOffset) * (nextScale / startScale);

/// Wheel/trackpad zoom factor. Scrolling up (negative dy) zooms in.
double canvasZoomForScrollDelta(double current, double deltaY) {
  final next = current * math.exp(-deltaY * _scrollZoomSensitivity);
  return clampCanvasZoom(next);
}

/// Rounded percentage shown in the zoom chip.
String canvasZoomPercentLabel(double scale) =>
    '${(clampCanvasZoom(scale) * 100).round()}%';

/// Plain wheel/trackpad scrolling pans the board by the scroll delta.
Offset canvasOffsetForPan(Offset current, Offset scrollDelta) =>
    current - scrollDelta;

Offset worldPointForViewport({
  required Offset localPoint,
  required Offset viewportOffset,
  required double scale,
}) => Offset(
  (localPoint.dx - viewportOffset.dx) / scale,
  (localPoint.dy - viewportOffset.dy) / scale,
);
