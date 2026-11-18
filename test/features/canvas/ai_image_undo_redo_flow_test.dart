import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

/// In-memory CanvasService so the bloc syncs through the real CRDT adapter.
class _FakeCanvasService implements CanvasService {
  final List<Uint8List> pushedPayloads = <Uint8List>[];

  @override
  bool get canSync => true;

  @override
  String? get currentClientId => 'test-client';

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {
    pushedPayloads.add(payload);
  }

  @override
  Stream<Board?> watchBoardById(String boardId) =>
      Stream.fromIterable(const [null]);

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) =>
      Stream.fromIterable(const [<LocalCrdtUpdate>[]]);

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) =>
      Stream.fromIterable(const [<LocalCrdtUpdate>[]]);

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {}

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {}

  @override
  Future<bool> retryPendingSync(String boardId) async => true;

  @override
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) async {}

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate({
    required String boardId,
    required String elementId,
  }) async => null;

  @override
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required Uint8List payload,
  }) async {}
}

Future<void> _settle([int ms = 80]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

const _urlA = 'http://127.0.0.1:5005/ai-images/board-1/genA.png';
const _urlB = 'http://127.0.0.1:5005/ai-images/board-1/genB.png';

void main() {
  test('AI image: generate, edit, undo, redo keeps the edited image', () async {
    final canvas = _FakeCanvasService();
    final bloc = CanvasBloc(
      canvasService: canvas,
      boardId: 'board-1',
      currentUserId: 'me-1',
    );
    bloc.add(const CanvasInitializeCrdt('board-1'));
    await _settle();
    bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: 'editor'));
    await _settle();

    bloc.add(const CanvasAddAiImageElement(
      imageUrl: _urlA,
      thumbnailBase64: 'dGh1bWJB',
      center: Offset(100, 100),
      width: 280,
      height: 280,
      aiPrompt: 'a cat',
      generationId: 'genA',
    ));
    await _settle(700); // the edit comes seconds later: a separate undo step
    final id = bloc.state.elements.single.id;

    bloc.add(CanvasReplaceImageSource(
      elementId: id,
      imageUrl: _urlB,
      thumbnailBase64: 'dGh1bWJC',
      sourceWidth: 1024,
      sourceHeight: 576,
      aiPrompt: 'a cat at night',
      generationId: 'genB',
    ));
    await _settle(700);
    expect((bloc.state.elements.single as ImageElement).imageUrl, _urlB);

    bloc.add(const CanvasUndo());
    await _settle();
    expect((bloc.state.elements.single as ImageElement).imageUrl, _urlA);

    bloc.add(const CanvasRedo());
    await _settle();
    expect(bloc.state.elements, hasLength(1));
    expect((bloc.state.elements.single as ImageElement).imageUrl, _urlB);
    await bloc.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
