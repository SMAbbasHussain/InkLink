import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/repositories/board/board_repository.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository_impl.dart';
import 'package:inklink/domain/repositories/canvas/crdt_local_store.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

import '../../domain/repositories/canvas/crdt_store_test_support.dart';

/// The real CanvasBloc → CanvasServiceImpl → FirestoreCanvasSyncRepository
/// stack (signed out, so no socket) behaves the same on the phone store
/// (Isar) and the web store (memory): edits are stored, and a fresh canvas
/// on the same store rebuilds the same board.
class _BoardRepository implements BoardRepository {
  @override
  Stream<Board?> getBoardById(String boardId) => Stream.value(null);

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<void> deactivateBoard() async {}

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}

const _urlA = 'http://127.0.0.1:5005/ai-images/board-1/genA.png';
const _urlB = 'http://127.0.0.1:5005/ai-images/board-1/genB.png';

Future<void> _settle([int ms = 120]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

CanvasBloc _bloc(CrdtLocalStore store) => CanvasBloc(
  canvasService: CanvasServiceImpl(
    boardRepository: _BoardRepository(),
    syncRepository: FirestoreCanvasSyncRepository(
      authService: SignedOutAuthService(),
      store: store,
    ),
  ),
  boardId: 'board-1',
  currentUserId: 'me-1',
);

Future<CanvasBloc> _open(CrdtLocalStore store) async {
  final bloc = _bloc(store);
  bloc.add(const CanvasInitializeCrdt('board-1'));
  await _settle(300);
  bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: 'editor'));
  await _settle();
  return bloc;
}

/// Draws, edits and undoes on one canvas, then reopens the board.
Future<Map<String, Object?>> _scenario(CrdtLocalStore store) async {
  final first = await _open(store);
  first.add(
    const CanvasAddAiImageElement(
      imageUrl: _urlA,
      thumbnailBase64: 'dGh1bWJB',
      center: Offset(100, 100),
      width: 280,
      height: 280,
      aiPrompt: 'a cat',
      generationId: 'genA',
    ),
  );
  await _settle(700);
  final id = first.state.elements.single.id;
  first.add(
    CanvasReplaceImageSource(
      elementId: id,
      imageUrl: _urlB,
      thumbnailBase64: 'dGh1bWJC',
      sourceWidth: 1024,
      sourceHeight: 576,
      aiPrompt: 'a cat at night',
      generationId: 'genB',
    ),
  );
  await _settle(700);
  final afterEdit = (first.state.elements.single as ImageElement).imageUrl;
  first.add(const CanvasUndo());
  await _settle(300);
  final afterUndo = (first.state.elements.single as ImageElement).imageUrl;
  first.add(const CanvasRedo());
  await _settle(300);
  final afterRedo = first.state.elements.length == 1
      ? (first.state.elements.single as ImageElement).imageUrl
      : 'count=${first.state.elements.length}';
  await first.close();
  await _settle();

  final stored = await store.updatesForBoard('board-1');

  final reopened = await _open(store);
  await _settle(500);
  final reopenedUrls = [
    for (final e in reopened.state.elements)
      if (e is ImageElement) e.imageUrl,
  ];
  final reopenedIds = [for (final e in reopened.state.elements) e.id];
  await reopened.close();

  return {
    'afterEdit': afterEdit,
    'afterUndo': afterUndo,
    'afterRedo': afterRedo,
    'storedSomething': stored.isNotEmpty,
    'allUnsynced': stored.every((u) => !u.isSynced),
    'reopenedIds': reopenedIds..sort(),
    'reopenedUrls': reopenedUrls,
    'sameElementBack': reopenedIds.contains(id),
  };
}

void main() {
  final isarLib = resolveBundledIsarLibraryPath();

  test('memory store: edits are stored and the board reopens', () async {
    final h = await memoryStoreFactory();
    addTearDown(h.dispose);
    final r = await _scenario(h.store);
    expect(r['afterEdit'], _urlB);
    expect(r['afterUndo'], _urlA);
    expect(r['storedSomething'], isTrue);
    expect(r['allUnsynced'], isTrue);
    expect(r['sameElementBack'], isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'Isar and memory stores give the same canvas results',
    () async {
      final mem = await memoryStoreFactory();
      final isar = await isarStoreFactory(isarLib!);
      addTearDown(mem.dispose);
      addTearDown(isar.dispose);
      final memResult = await _scenario(mem.store);
      final isarResult = await _scenario(isar.store);
      // Element ids are random per run, so compare everything else and
      // check each run got its own element back.
      memResult.remove('reopenedIds');
      isarResult.remove('reopenedIds');
      expect(isarResult, memResult);
    },
    skip: isarLib == null
        ? 'Native Isar library not found in pub cache on this host'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
