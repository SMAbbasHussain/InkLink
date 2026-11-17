/// Result of an AI image request (generate, edit or repaint).
///
/// The app never needs to know which provider produced the image; `provider`
/// and `model` are informational only.
class AiImageResult {
  /// Public URL of the full-size PNG.
  final String imageUrl;

  /// Small JPEG preview (about 256px), base64 encoded. Stored inline in the
  /// canvas element so older app versions still show a picture.
  final String thumbnailBase64;

  final int width;
  final int height;
  final String provider;
  final String model;
  final String generationId;

  const AiImageResult({
    required this.imageUrl,
    required this.thumbnailBase64,
    required this.width,
    required this.height,
    required this.provider,
    required this.model,
    required this.generationId,
  });

  /// Parses a callable response. Throws [FormatException] when the response
  /// has no usable image URL or size.
  factory AiImageResult.fromMap(Map<dynamic, dynamic> map) {
    final imageUrl = (map['imageUrl'] as Object?)?.toString().trim() ?? '';
    final width = _toInt(map['width']);
    final height = _toInt(map['height']);
    if (imageUrl.isEmpty || width <= 0 || height <= 0) {
      throw const FormatException('AI image response is missing image data.');
    }
    return AiImageResult(
      imageUrl: imageUrl,
      thumbnailBase64: (map['thumbnailBase64'] as Object?)?.toString() ?? '',
      width: width,
      height: height,
      provider: (map['provider'] as Object?)?.toString() ?? '',
      model: (map['model'] as Object?)?.toString() ?? '',
      generationId: (map['generationId'] as Object?)?.toString() ?? '',
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiImageResult &&
          imageUrl == other.imageUrl &&
          thumbnailBase64 == other.thumbnailBase64 &&
          width == other.width &&
          height == other.height &&
          provider == other.provider &&
          model == other.model &&
          generationId == other.generationId;

  @override
  int get hashCode => Object.hash(
        imageUrl,
        thumbnailBase64,
        width,
        height,
        provider,
        model,
        generationId,
      );
}
