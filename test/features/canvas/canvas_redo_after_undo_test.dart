import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// Minimal in-memory CanvasService, as in `undo_conflict_flow_test.dart`:
/// enough for the bloc to sync local edits into its CRDT adapter.
class _FakeCanvasService implements CanvasService {
  final List<Uint8List> pushedPayloads = <Uint8List>[];

  @override
  bool get canSync => true;

  @override
  Future<bool> retryPendingSync(String boardId) async => true;

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

void main() {
  late _FakeCanvasService canvas;

  CanvasBloc buildBloc() {
    canvas = _FakeCanvasService();
    return CanvasBloc(
      canvasService: canvas,
      boardId: 'board-1',
      currentUserId: 'me-1',
    );
  }

  Future<CanvasBloc> editorBloc() async {
    final bloc = buildBloc();
    bloc.add(const CanvasInitializeCrdt('board-1'));
    await _settle();
    bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: 'editor'));
    await _settle();
    return bloc;
  }

  test('redo after undo restores a deleted creation', () async {
    final bloc = await editorBloc();
    addTearDown(bloc.close);

    bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(10, 10)));
    await _settle();
    final id = bloc.state.elements.single.id;
    canvas.pushedPayloads.clear();

    bloc.add(const CanvasUndo());
    await _settle();
    expect(bloc.state.elements, isEmpty, reason: 'undo should remove it');
    expect(canvas.pushedPayloads, isNotEmpty, reason: 'undo should publish');

    bloc.add(const CanvasRedo());
    await _settle();

    expect(
      bloc.state.elements.where((e) => e.id == id),
      isNotEmpty,
      reason: 'redo should bring the shape back',
    );
    expect(bloc.state.infoMessage, 'Redone');
  });

  test('two undos then two redos restore both shapes', () async {
    final bloc = await editorBloc();
    addTearDown(bloc.close);

    bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(10, 10)));
    await _settle();
    // Separate the transactions so the undo manager cannot merge them.
    await _settle(700);
    bloc.add(const CanvasAddShape(CanvasShapeType.ellipse, Offset(120, 120)));
    await _settle();
    expect(bloc.state.elements, hasLength(2));

    bloc.add(const CanvasUndo());
    await _settle();
    bloc.add(const CanvasUndo());
    await _settle();
    // Each creation is its own undo step, so two undos remove both.
    expect(bloc.state.elements, isEmpty);

    bloc.add(const CanvasRedo());
    await _settle();
    expect(bloc.state.elements, hasLength(1), reason: 'first redo');
    bloc.add(const CanvasRedo());
    await _settle();
    expect(bloc.state.elements, hasLength(2), reason: 'second redo');
  });

  test('repeated undo/redo cycles keep working', () async {
    final bloc = await editorBloc();
    addTearDown(bloc.close);

    bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(10, 10)));
    await _settle();

    for (var i = 0; i < 3; i++) {
      bloc.add(const CanvasUndo());
      await _settle();
      expect(bloc.state.elements, isEmpty, reason: 'undo cycle $i');

      bloc.add(const CanvasRedo());
      await _settle();
      expect(
        bloc.state.elements,
        hasLength(1),
        reason: 'redo cycle $i (message: ${bloc.state.infoMessage})',
      );
    }
  });

  test('redo after undoing a shape edit restores the edited value', () async {
    final bloc = await editorBloc();
    addTearDown(bloc.close);

    bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(10, 10)));
    await _settle();
    await _settle(700);
    final original = bloc.state.elements.single as ShapeElement;

    bloc.add(
      CanvasMoveSelectedShape(original.center + const Offset(100, 40)),
    );
    await _settle();
    final moved = bloc.state.elements.single as ShapeElement;
    expect(moved.center, isNot(original.center));

    bloc.add(const CanvasUndo());
    await _settle();
    expect(
      (bloc.state.elements.single as ShapeElement).center,
      original.center,
    );

    bloc.add(const CanvasRedo());
    await _settle();
    expect(
      (bloc.state.elements.single as ShapeElement).center,
      moved.center,
      reason: 'redo should re-apply the move (message: ${bloc.state.infoMessage})',
    );
  });
}
