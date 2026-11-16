import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../ui/theme/ink_theme.dart';
import '../../../../ui/theme/ink_tokens.dart';
import '../../geometry/canvas_element_geometry.dart';
import '../../models/canvas_element.dart';

/// Maps world coordinates into a fixed-size minimap box.
class MinimapProjection {
  final Rect contentBounds;
  final Size size;
  final double scale;
  final Offset contentOffset;

  const MinimapProjection({
    required this.contentBounds,
    required this.size,
    required this.scale,
    required this.contentOffset,
  });

  factory MinimapProjection.fit({
    required List<CanvasElement> elements,
    required Size size,
    double padding = 80,
  }) {
    Rect? union;
    for (final element in elements) {
      if (element.hidden) continue;
      final bounds = elementBounds(element);
      if (bounds == null) continue;
      union = union == null ? bounds : union.expandToInclude(bounds);
    }
    final content = (union ?? const Rect.fromLTWH(0, 0, 1000, 700)).inflate(
      padding,
    );
    final scale = math.min(
      size.width / content.width,
      size.height / content.height,
    );
    return MinimapProjection(
      contentBounds: content,
      size: size,
      scale: scale,
      contentOffset: Offset(
        (size.width - content.width * scale) / 2,
        (size.height - content.height * scale) / 2,
      ),
    );
  }

  Offset toMinimap(Offset world) =>
      contentOffset + (world - contentBounds.topLeft) * scale;

  Offset toWorld(Offset local) =>
      contentBounds.topLeft + (local - contentOffset) / scale;

  Rect viewportRect({
    required Offset viewportOffset,
    required double viewportScale,
    required Size viewportSize,
  }) {
    final worldRect = Rect.fromLTWH(
      -viewportOffset.dx / viewportScale,
      -viewportOffset.dy / viewportScale,
      viewportSize.width / viewportScale,
      viewportSize.height / viewportScale,
    );
    final topLeft = toMinimap(worldRect.topLeft);
    final bottomRight = toMinimap(worldRect.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight).intersect(Offset.zero & size);
  }
}

/// Small overview of the board with a draggable viewport rectangle.
class CanvasMinimap extends StatelessWidget {
  final List<CanvasElement> elements;
  final double viewportScale;
  final Offset viewportOffset;
  final Size viewportSize;
  final ValueChanged<Offset> onJump;
  final Size size;

  const CanvasMinimap({
    super.key,
    required this.elements,
    required this.viewportScale,
    required this.viewportOffset,
    required this.viewportSize,
    required this.onJump,
    this.size = const Size(168, 112),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.ink;
    final projection = MinimapProjection.fit(elements: elements, size: size);
    return Semantics(
      label: 'Canvas minimap',
      button: true,
      onTap: () => onJump(projection.toWorld(size.center(Offset.zero))),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            onJump(projection.toWorld(details.localPosition)),
        onPanUpdate: (details) =>
            onJump(projection.toWorld(details.localPosition)),
        child: CustomPaint(
          size: size,
          painter: _MinimapPainter(
            elements: elements,
            projection: projection,
            viewportRect: projection.viewportRect(
              viewportOffset: viewportOffset,
              viewportScale: viewportScale,
              viewportSize: viewportSize,
            ),
            background: tokens.paper,
            border: tokens.glassStroke,
            accent: tokens.accent,
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final List<CanvasElement> elements;
  final MinimapProjection projection;
  final Rect viewportRect;
  final Color background;
  final Color border;
  final Color accent;

  const _MinimapPainter({
    required this.elements,
    required this.projection,
    required this.viewportRect,
    required this.background,
    required this.border,
    required this.accent,
  });

  Color _colorFor(CanvasElement element) {
    if (element is FrameElement) return border;
    if (element is ConnectorElement) return border;
    if (element is StickyNoteElement) return const Color(0xFFEAB308);
    if (element is ShapeElement) return accent;
    if (element is ImageElement) return const Color(0xFF22C55E);
    if (element is TextElement) return const Color(0xFF64748B);
    return accent;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(InkRadii.chip),
    );
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    for (final element in elements) {
      if (element.hidden) continue;
      final bounds = elementBounds(element);
      if (bounds == null) continue;
      final topLeft = projection.toMinimap(bounds.topLeft);
      final bottomRight = projection.toMinimap(bounds.bottomRight);
      final rect = Rect.fromPoints(topLeft, bottomRight);
      if (rect.width < 0.5 && rect.height < 0.5) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        Paint()..color = _colorFor(element).withValues(alpha: 0.75),
      );
    }

    if (!viewportRect.isEmpty) {
      canvas.drawRect(
        viewportRect,
        Paint()..color = accent.withValues(alpha: 0.12),
      );
      canvas.drawRect(
        viewportRect,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      clip.deflate(0.75),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) =>
      oldDelegate.elements != elements ||
      oldDelegate.viewportRect != viewportRect ||
      oldDelegate.projection.contentBounds != projection.contentBounds ||
      oldDelegate.projection.scale != projection.scale;
}
