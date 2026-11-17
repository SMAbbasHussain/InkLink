import 'dart:ui';

import 'board_export_format.dart';
import 'canvas_element.dart';

enum CanvasExportScope { board, selection, frame, page }

/// User choices for one export. Not persisted; built per export request.
class CanvasExportOptions {
  static const double minScale = 1;
  static const double maxScale = 4;
  static const double boundsPadding = 16;
  static const double maxDimension = 8192;

  final BoardExportFormat format;
  final CanvasExportScope scope;
  final double scale;
  final bool transparentBackground;
  final bool includeBackground;
  final bool includePattern;
  final bool includeComments;
  final String? frameId;
  final String? suffix;

  const CanvasExportOptions({
    this.format = BoardExportFormat.png,
    this.scope = CanvasExportScope.board,
    this.scale = 2,
    this.transparentBackground = false,
    this.includeBackground = true,
    this.includePattern = true,
    this.includeComments = false,
    this.frameId,
    this.suffix,
  });

  /// Transparency is on when the user asks for it or turns the paper off.
  bool get hasTransparentBackground =>
      transparentBackground || !includeBackground;

  double get normalizedScale => scale.clamp(minScale, maxScale);

  CanvasExportOptions copyWith({
    BoardExportFormat? format,
    CanvasExportScope? scope,
    double? scale,
    bool? transparentBackground,
    bool? includeBackground,
    bool? includePattern,
    bool? includeComments,
    String? frameId,
    String? suffix,
  }) => CanvasExportOptions(
    format: format ?? this.format,
    scope: scope ?? this.scope,
    scale: scale ?? this.scale,
    transparentBackground:
        transparentBackground ?? this.transparentBackground,
    includeBackground: includeBackground ?? this.includeBackground,
    includePattern: includePattern ?? this.includePattern,
    includeComments: includeComments ?? this.includeComments,
    frameId: frameId ?? this.frameId,
    suffix: suffix ?? this.suffix,
  );

}

/// Resolved elements and crop box for one export.
class CanvasExportPlan {
  final List<CanvasElement> elements;
  final Rect bounds;
  final double scale;

  const CanvasExportPlan({
    required this.elements,
    required this.bounds,
    required this.scale,
  });

  int get widthPixels => (bounds.width * scale).ceil();
  int get heightPixels => (bounds.height * scale).ceil();
}

/// A user-facing export problem (empty selection, missing frame, too large).
class CanvasExportException implements Exception {
  final String message;

  const CanvasExportException(this.message);

  @override
  String toString() => message;
}
