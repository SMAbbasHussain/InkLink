import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/ai/ai_image_result.dart';
import '../../../domain/services/ai/ai_image_service.dart';
import 'ai_image_event.dart';
import 'ai_image_state.dart';

export 'ai_image_event.dart';
export 'ai_image_state.dart';

/// Tracks AI image requests for one canvas.
///
/// It never touches the board itself. When a request finishes it publishes an
/// [AiImageCompletion]; the canvas screen turns that into a normal CanvasBloc
/// event, so the image goes through the usual CRDT path. Requests run
/// concurrently, so the user can keep working (and start more) meanwhile.
class AiImageBloc extends Bloc<AiImageEvent, AiImageState> {
  final AiImageService _aiImageService;

  int _nextPlaceholderNumber = 0;
  int _nextSequence = 0;
  final Set<String> _requestedUrls = <String>{};

  AiImageBloc({required AiImageService aiImageService})
    : _aiImageService = aiImageService,
      super(const AiImageState()) {
    on<AiImageGenerateRequested>(_onGenerate);
    on<AiImageEditRequested>(_onEdit);
    on<AiImageInpaintRequested>(_onInpaint);
    on<AiImageRegenerateRequested>(_onRegenerate);
    on<AiImageBytesRequested>(_onBytesRequested);
  }

  Future<void> _onGenerate(
    AiImageGenerateRequested event,
    Emitter<AiImageState> emit,
  ) async {
    final prompt = event.prompt.trim();
    if (prompt.isEmpty) return;

    final placeholder = AiImagePlaceholder(
      id: 'ai-placeholder-${_nextPlaceholderNumber++}',
      prompt: prompt,
      aspectRatio: event.aspectRatio,
      center: event.center,
      width: event.width,
      height: event.height,
    );
    emit(
      state.copyWith(
        status: AiImageStatus.generating,
        placeholders: [...state.placeholders, placeholder],
        generatingPlaceholderId: placeholder.id,
      ),
    );

    try {
      final result = await _aiImageService.generateImage(
        boardId: event.boardId,
        prompt: prompt,
        aspectRatio: event.aspectRatio,
      );
      emit(
        _withoutPlaceholder(placeholder.id).copyWith(
          status: AiImageStatus.success,
          lastCompletion: AiImageCompletion(
            sequence: ++_nextSequence,
            result: result,
            prompt: prompt,
            placeholder: placeholder,
          ),
        ),
      );
    } catch (error) {
      // The placeholder is removed and the board is left unchanged.
      emit(
        _withoutPlaceholder(placeholder.id).copyWith(
          status: AiImageStatus.failure,
          lastFailure: _failure(error),
        ),
      );
    }
  }

  Future<void> _onEdit(
    AiImageEditRequested event,
    Emitter<AiImageState> emit,
  ) {
    return _replaceElementImage(
      emit: emit,
      elementId: event.elementId,
      prompt: event.prompt,
      request: (prompt) => _aiImageService.editImage(
        boardId: event.boardId,
        sourceImageUrl: event.sourceImageUrl,
        prompt: prompt,
        strength: event.strength,
      ),
    );
  }

  Future<void> _onInpaint(
    AiImageInpaintRequested event,
    Emitter<AiImageState> emit,
  ) {
    return _replaceElementImage(
      emit: emit,
      elementId: event.elementId,
      prompt: event.prompt,
      request: (prompt) => _aiImageService.inpaintImage(
        boardId: event.boardId,
        sourceImageUrl: event.sourceImageUrl,
        maskPng: event.maskPng,
        prompt: prompt,
      ),
    );
  }

  Future<void> _onRegenerate(
    AiImageRegenerateRequested event,
    Emitter<AiImageState> emit,
  ) {
    return _replaceElementImage(
      emit: emit,
      elementId: event.elementId,
      prompt: event.prompt,
      request: (prompt) => _aiImageService.generateImage(
        boardId: event.boardId,
        prompt: prompt,
        aspectRatio: event.aspectRatio,
      ),
    );
  }

  Future<void> _replaceElementImage({
    required Emitter<AiImageState> emit,
    required String elementId,
    required String prompt,
    required Future<AiImageResult> Function(String prompt) request,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    // One request per image at a time.
    if (state.busyElementIds.contains(elementId)) return;

    emit(
      state.copyWith(
        status: AiImageStatus.generating,
        busyElementIds: {...state.busyElementIds, elementId},
      ),
    );

    try {
      final result = await request(trimmed);
      emit(
        _withoutBusyElement(elementId).copyWith(
          status: AiImageStatus.success,
          lastCompletion: AiImageCompletion(
            sequence: ++_nextSequence,
            result: result,
            prompt: trimmed,
            elementId: elementId,
          ),
        ),
      );
    } catch (error) {
      emit(
        _withoutBusyElement(elementId).copyWith(
          status: AiImageStatus.failure,
          lastFailure: _failure(error),
        ),
      );
    }
  }

  Future<void> _onBytesRequested(
    AiImageBytesRequested event,
    Emitter<AiImageState> emit,
  ) async {
    final url = event.url;
    if (url.isEmpty || state.imageBytes.containsKey(url)) return;
    if (!_requestedUrls.add(url)) return;

    try {
      final Uint8List bytes = await _aiImageService.fetchImageBytes(url);
      emit(state.copyWith(imageBytes: {...state.imageBytes, url: bytes}));
    } catch (_) {
      // The canvas keeps showing the inline thumbnail. Forget the URL so a
      // later request (for example after reconnecting) can try again.
      _requestedUrls.remove(url);
    }
  }

  AiImageState _withoutPlaceholder(String placeholderId) {
    final remaining = state.placeholders
        .where((p) => p.id != placeholderId)
        .toList(growable: false);
    return state.copyWith(
      placeholders: remaining,
      generatingPlaceholderId: remaining.isEmpty ? null : remaining.last.id,
      clearGeneratingPlaceholderId: remaining.isEmpty,
    );
  }

  AiImageState _withoutBusyElement(String elementId) {
    return state.copyWith(
      busyElementIds: {...state.busyElementIds}..remove(elementId),
    );
  }

  AiImageFailure _failure(Object error) {
    if (error is AiImageException) {
      return AiImageFailure(
        sequence: ++_nextSequence,
        message: error.message,
        isLimitReached: error.isLimitReached,
      );
    }
    return AiImageFailure(
      sequence: ++_nextSequence,
      message: 'The AI image request failed. Please try again.',
    );
  }
}
