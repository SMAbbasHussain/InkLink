import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/cloud_functions_service.dart';
import '../../models/ai/ai_image_result.dart';

/// A user-readable AI image failure. [code] is the Cloud Functions error code
/// when one is known (for example `resource-exhausted`).
class AiImageException implements Exception {
  final String message;
  final String? code;

  const AiImageException(this.message, {this.code});

  bool get isLimitReached => code == 'resource-exhausted';

  @override
  String toString() => message;
}

/// AI image generation and editing. The provider lives behind Cloud
/// Functions; the app only ever sees image URLs.
abstract class AiImageService {
  Future<AiImageResult> generateImage({
    required String boardId,
    required String prompt,
    required String aspectRatio,
  });

  Future<AiImageResult> editImage({
    required String boardId,
    required String sourceImageUrl,
    required String prompt,
    double? strength,
  });

  Future<AiImageResult> inpaintImage({
    required String boardId,
    required String sourceImageUrl,
    required Uint8List maskPng,
    required String prompt,
  });

  /// Downloads image bytes by URL, with a small in-memory cache. Bytes only
  /// (no file paths), so this also works on Flutter web.
  Future<Uint8List> fetchImageBytes(String url);
}

class AiImageServiceImpl implements AiImageService {
  static const int _maxCachedImages = 24;
  static const Duration _callTimeout = Duration(seconds: 130);
  static const Duration _downloadTimeout = Duration(seconds: 30);

  final CloudFunctionsService _cloudFunctionsService;
  final http.Client _httpClient;

  /// Insertion-ordered; the first key is the least recently used.
  final LinkedHashMap<String, Uint8List> _imageCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List>> _inFlightDownloads = {};

  AiImageServiceImpl({
    required this._cloudFunctionsService,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<AiImageResult> generateImage({
    required String boardId,
    required String prompt,
    required String aspectRatio,
  }) {
    return _call('generateAiImage', {
      'boardId': boardId,
      'prompt': prompt.trim(),
      'aspectRatio': aspectRatio,
    });
  }

  @override
  Future<AiImageResult> editImage({
    required String boardId,
    required String sourceImageUrl,
    required String prompt,
    double? strength,
  }) {
    return _call('editAiImage', {
      'boardId': boardId,
      'sourceImageUrl': sourceImageUrl,
      'prompt': prompt.trim(),
      if (strength != null) 'strength': strength,
    });
  }

  @override
  Future<AiImageResult> inpaintImage({
    required String boardId,
    required String sourceImageUrl,
    required Uint8List maskPng,
    required String prompt,
  }) {
    return _call('inpaintAiImage', {
      'boardId': boardId,
      'sourceImageUrl': sourceImageUrl,
      'maskBase64': base64Encode(maskPng),
      'prompt': prompt.trim(),
    });
  }

  Future<AiImageResult> _call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _cloudFunctionsService
          .httpsCallable(functionName)
          .call(payload)
          .timeout(_callTimeout);

      final data = result.data;
      if (data is! Map || data['success'] != true) {
        throw const AiImageException(
          'The AI image request failed. Please try again.',
        );
      }
      return AiImageResult.fromMap(data);
    } on AiImageException {
      rethrow;
    } on FirebaseException catch (e) {
      // FirebaseFunctionsException extends FirebaseException.
      developer.log(
        'Cloud Function Error ($functionName): ${e.code} - ${e.message}',
        name: 'AiImageServiceImpl',
      );
      throw AiImageException(_messageForCode(e.code, e.message), code: e.code);
    } on TimeoutException {
      throw const AiImageException(
        'The AI image request took too long. Please try again.',
        code: 'deadline-exceeded',
      );
    } on FormatException {
      throw const AiImageException(
        'The AI service returned an unexpected response. Please try again.',
      );
    } catch (e) {
      developer.log(
        'Unexpected error ($functionName): $e',
        name: 'AiImageServiceImpl',
      );
      throw const AiImageException(
        'Could not reach the AI image service. Check your connection and try again.',
      );
    }
  }

  static String _messageForCode(String code, String? serverMessage) {
    final message = serverMessage?.trim() ?? '';
    switch (code) {
      case 'resource-exhausted':
        return message.isNotEmpty
            ? message
            : "You have reached today's AI image limit. Try again tomorrow.";
      case 'failed-precondition':
        return 'AI image generation is not set up on the server yet.';
      case 'deadline-exceeded':
        return 'The AI service took too long to respond. Please try again.';
      case 'unavailable':
        return 'The AI image service is unavailable. Check your connection and try again.';
      case 'permission-denied':
        return message.isNotEmpty
            ? message
            : 'You need edit access to this board to use AI images.';
      case 'unauthenticated':
        return 'Please sign in again to use AI images.';
      case 'invalid-argument':
        return message.isNotEmpty
            ? message
            : 'That request was not accepted. Try a different prompt.';
      case 'not-found':
        return message.isNotEmpty
            ? message
            : 'The board or image could not be found.';
      default:
        return 'The AI image request failed. Please try again.';
    }
  }

  @override
  Future<Uint8List> fetchImageBytes(String url) {
    final key = url.trim();
    final cached = _imageCache.remove(key);
    if (cached != null) {
      // Re-insert so this entry becomes the most recently used.
      _imageCache[key] = cached;
      return Future<Uint8List>.value(cached);
    }

    final inFlight = _inFlightDownloads[key];
    if (inFlight != null) return inFlight;

    final download = _download(key).whenComplete(() {
      _inFlightDownloads.remove(key);
    });
    _inFlightDownloads[key] = download;
    return download;
  }

  Future<Uint8List> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw const AiImageException('The image address is not valid.');
    }
    try {
      final response = await _httpClient.get(uri).timeout(_downloadTimeout);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw const AiImageException('The image could not be downloaded.');
      }
      final bytes = response.bodyBytes;
      _imageCache[url] = bytes;
      while (_imageCache.length > _maxCachedImages) {
        _imageCache.remove(_imageCache.keys.first);
      }
      return bytes;
    } on AiImageException {
      rethrow;
    } catch (_) {
      throw const AiImageException(
        'The image could not be downloaded. Check your connection.',
      );
    }
  }
}
