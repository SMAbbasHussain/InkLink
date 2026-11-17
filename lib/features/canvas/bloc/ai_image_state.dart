import 'dart:typed_data';
import 'dart:ui';

import '../../../domain/models/ai/ai_image_result.dart';

/// Aspect ratios offered in the UI. The server accepts exactly these.
const List<String> kAiAspectRatios = ['1:1', '16:9', '9:16'];

/// Longest prompt the server accepts.
const int kAiMaxPromptLength = 1000;

/// Longest side of a new AI image on the canvas, in canvas units. Matches
/// the size used for uploaded images.
const double kAiImageCanvasMaxSide = 280;

/// Canvas size of an image with the given aspect ratio ("16:9").
Size aiCanvasSizeForAspectRatio(String aspectRatio) {
  final parts = aspectRatio.split(':');
  final w = parts.length == 2 ? double.tryParse(parts[0]) : null;
  final h = parts.length == 2 ? double.tryParse(parts[1]) : null;
  if (w == null || h == null || w <= 0 || h <= 0) {
    return const Size(kAiImageCanvasMaxSide, kAiImageCanvasMaxSide);
  }
  final scale = kAiImageCanvasMaxSide / (w > h ? w : h);
  return Size(w * scale, h * scale);
}

/// The offered aspect ratio closest to a [width] x [height] image.
String aiNearestAspectRatio(double width, double height) {
  if (width <= 0 || height <= 0) return kAiAspectRatios.first;
  final ratio = width / height;
  var best = kAiAspectRatios.first;
  var bestDistance = double.infinity;
  for (final candidate in kAiAspectRatios) {
    final size = aiCanvasSizeForAspectRatio(candidate);
    final distance = (size.width / size.height - ratio).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

enum AiImageStatus { idle, generating, success, failure }

/// A loading box shown on the canvas while an image is being generated.
/// It is local only: collaborators never see it.
class AiImagePlaceholder {
  final String id;
  final String prompt;
  final String aspectRatio;
  final Offset center;
  final double width;
  final double height;

  const AiImagePlaceholder({
    required this.id,
    required this.prompt,
    required this.aspectRatio,
    required this.center,
    required this.width,
    required this.height,
  });
}

/// A finished request that the canvas must apply: insert a new image
/// (when [placeholder] is set) or replace the picture of [elementId].
class AiImageCompletion {
  /// Increases with every completion, so the view applies each one once.
  final int sequence;
  final AiImageResult result;
  final String prompt;
  final AiImagePlaceholder? placeholder;
  final String? elementId;

  const AiImageCompletion({
    required this.sequence,
    required this.result,
    required this.prompt,
    this.placeholder,
    this.elementId,
  });

  bool get isInsert => placeholder != null;
}

/// A failed request, to be shown once as a message.
class AiImageFailure {
  final int sequence;
  final String message;
  final bool isLimitReached;

  const AiImageFailure({
    required this.sequence,
    required this.message,
    this.isLimitReached = false,
  });
}

class AiImageState {
  final AiImageStatus status;

  /// Images being generated right now.
  final List<AiImagePlaceholder> placeholders;

  /// The placeholder of the most recently started generation, if any.
  final String? generatingPlaceholderId;

  /// Existing image elements with an edit, repaint or regenerate running.
  final Set<String> busyElementIds;

  /// Downloaded full-size image bytes, by URL.
  final Map<String, Uint8List> imageBytes;

  final AiImageCompletion? lastCompletion;
  final AiImageFailure? lastFailure;

  const AiImageState({
    this.status = AiImageStatus.idle,
    this.placeholders = const [],
    this.generatingPlaceholderId,
    this.busyElementIds = const {},
    this.imageBytes = const {},
    this.lastCompletion,
    this.lastFailure,
  });

  /// True while any generate, edit, repaint or regenerate is running.
  bool get isBusy => placeholders.isNotEmpty || busyElementIds.isNotEmpty;

  /// True while a new image is being generated.
  bool get isGenerating => placeholders.isNotEmpty;

  String? get failureMessage =>
      status == AiImageStatus.failure ? lastFailure?.message : null;

  AiImageState copyWith({
    AiImageStatus? status,
    List<AiImagePlaceholder>? placeholders,
    String? generatingPlaceholderId,
    bool clearGeneratingPlaceholderId = false,
    Set<String>? busyElementIds,
    Map<String, Uint8List>? imageBytes,
    AiImageCompletion? lastCompletion,
    AiImageFailure? lastFailure,
  }) {
    return AiImageState(
      status: status ?? this.status,
      placeholders: placeholders ?? this.placeholders,
      generatingPlaceholderId: clearGeneratingPlaceholderId
          ? null
          : (generatingPlaceholderId ?? this.generatingPlaceholderId),
      busyElementIds: busyElementIds ?? this.busyElementIds,
      imageBytes: imageBytes ?? this.imageBytes,
      lastCompletion: lastCompletion ?? this.lastCompletion,
      lastFailure: lastFailure ?? this.lastFailure,
    );
  }
}
