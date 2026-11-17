import 'dart:typed_data';
import 'dart:ui';

sealed class AiImageEvent {
  const AiImageEvent();
}

/// Generate a new image. A local placeholder is shown at [center] until the
/// image is ready.
class AiImageGenerateRequested extends AiImageEvent {
  final String boardId;
  final String prompt;
  final String aspectRatio;

  /// Where the image will be placed, in canvas coordinates.
  final Offset center;
  final double width;
  final double height;

  const AiImageGenerateRequested({
    required this.boardId,
    required this.prompt,
    required this.aspectRatio,
    required this.center,
    required this.width,
    required this.height,
  });
}

/// Edit a whole AI image from a text instruction.
class AiImageEditRequested extends AiImageEvent {
  final String boardId;
  final String elementId;
  final String sourceImageUrl;
  final String prompt;
  final double? strength;

  const AiImageEditRequested({
    required this.boardId,
    required this.elementId,
    required this.sourceImageUrl,
    required this.prompt,
    this.strength,
  });
}

/// Repaint only the masked part of an AI image (white in the mask = repaint).
class AiImageInpaintRequested extends AiImageEvent {
  final String boardId;
  final String elementId;
  final String sourceImageUrl;
  final Uint8List maskPng;
  final String prompt;

  const AiImageInpaintRequested({
    required this.boardId,
    required this.elementId,
    required this.sourceImageUrl,
    required this.maskPng,
    required this.prompt,
  });
}

/// Run the same prompt again and replace the image with the new variation.
class AiImageRegenerateRequested extends AiImageEvent {
  final String boardId;
  final String elementId;
  final String prompt;
  final String aspectRatio;

  const AiImageRegenerateRequested({
    required this.boardId,
    required this.elementId,
    required this.prompt,
    required this.aspectRatio,
  });
}

/// Download the full-size bytes of a URL image so the canvas can draw it.
class AiImageBytesRequested extends AiImageEvent {
  final String url;

  const AiImageBytesRequested(this.url);
}
