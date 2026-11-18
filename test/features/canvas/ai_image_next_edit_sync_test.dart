import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/repositories/board/board_repository.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

class _InMemoryIsarCanvasService implements CanvasService {
  final List<LocalCrdtUpdate> _store = <LocalCrdtUpdate>[];
  final StreamController<List<LocalCrdtUpdate>> _controller =
      StreamController<List<LocalCrdtUpdate>>.broadcast();

  void seedSnapshot(Uint8List bytes) {
    _store.add(
      LocalCrdtUpdate()
        ..updateId = '__snapshot__1'
        ..boardId = 'board-1'
        ..payloadBase64 = base64Encode(bytes)
        ..sourceClientId = '__server_snapshot__'
        ..appliedAt = DateTime.now()
        ..isSynced = true
        ..version = 1,
    );
  }

  @override
  bool get canSync => true;

  @override
  String? get currentClientId => 'me-1';

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {
    _store.add(
      LocalCrdtUpdate()
        ..updateId = updateId
        ..boardId = boardId
        ..elementId = elementId
        ..action = action
        ..payloadBase64 = base64Encode(payload)
        ..sourceClientId = 'me-1'
        ..appliedAt = DateTime.now()
        ..isSynced = false,
    );
    _controller.add(List<LocalCrdtUpdate>.of(_store));
  }

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) async* {
    yield List<LocalCrdtUpdate>.of(_store);
    yield* _controller.stream;
  }

  @override
  Stream<Board?> watchBoardById(String boardId) =>
      Stream.fromIterable(const [null]);

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) =>
      const Stream.empty();

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {}

  @override
  Future<bool> retryPendingSync(String boardId) async => true;

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

  Future<void> dispose() => _controller.close();
}

class _FakeBoardRepo implements BoardRepository {
  int deactivateCount = 0;

  @override
  Future<void> deactivateBoard() async {
    deactivateCount++;
  }

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TransientFailSyncRepo implements CanvasSyncRepository {
  @override
  String? get currentUserId => 'user-1';

  @override
  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update) async {}

  @override
  Future<void> writeRemoteCrdtUpdate({
    required String boardId,
    required String updateId,
    required String payloadBase64,
    required String sourceClientId,
    String? elementId,
    String action = 'upsert',
  }) async {}

  @override
  Future<bool> batchSyncPendingUpdates(String boardId, String userId) async =>
      false;

  @override
  Future<void> persistCursorForBoard(String boardId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'importing AI image then making next edit preserves all board elements and undo history across snapshot re-emissions',
    () async {
      final seedAdapter = await CanvasDocAdapterFactory.create();
      seedAdapter.upsertElement('existing-shape', {
        'type': 'shape',
        'z': 0,
        'shapeType': 'square',
        'cx': 50.0,
        'cy': 50.0,
        'size': 64.0,
        'color': 0xFF000000,
      });

      final service = _InMemoryIsarCanvasService()
        ..seedSnapshot(seedAdapter.encodeStateUpdate());

      final bloc = CanvasBloc(
        canvasService: service,
        boardId: 'board-1',
        currentUserId: 'me-1',
      );
      bloc.add(const CanvasInitializeCrdt('board-1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: 'editor'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.elements.map((e) => e.id), ['existing-shape']);

      // Import an image (e.g. AI generated image from device)
      bloc.add(
        CanvasAddImageElement(
          Uint8List.fromList([1, 2, 3, 4]),
          const Offset(200, 200),
          width: 280,
          height: 280,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(bloc.state.elements, hasLength(2));

      // Next edit on the board (adding a shape / stroke)
      bloc.add(
        const CanvasAddShape(CanvasShapeType.circle, Offset(350, 350)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.elements, hasLength(3));
      expect(
        bloc.state.elements.whereType<ImageElement>(),
        hasLength(1),
      );

      // Undo should still undo the latest edit without being wiped by __snapshot__
      bloc.add(const CanvasUndo());
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(bloc.state.elements, hasLength(2));

      await bloc.close();
      await service.dispose();
    },
  );

  test(
    'CanvasServiceImpl does not tear down remote sync when batchSyncPendingUpdates returns false',
    () async {
      final boardRepo = _FakeBoardRepo();
      final syncRepo = _TransientFailSyncRepo();
      final service = CanvasServiceImpl(
        boardRepository: boardRepo,
        syncRepository: syncRepo,
      );

      await service.pushCrdtUpdate(
        boardId: 'board-1',
        updateId: 'u-1',
        payload: Uint8List.fromList([1, 2, 3]),
      );

      expect(boardRepo.deactivateCount, 0);
    },
  );
}
