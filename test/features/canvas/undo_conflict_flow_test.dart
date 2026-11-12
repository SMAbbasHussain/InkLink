import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/history/board_operation.dart';
import 'package:inklink/domain/models/history/revert_plan.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/domain/services/history/board_history_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// Minimal in-memory CanvasService: enough for the bloc to treat itself as
/// syncable (`_canSync`) so local edits reach the CRDT adapter.
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

/// Records history calls; only `undoOwn` is exercised here.
class _FakeHistoryService implements BoardHistoryService {
  int undoOwnCalls = 0;
  RevertResult undoOwnResult = const RevertResult();

  @override
  Future<RevertResult> undoOwn(String boardId, {List<String>? updateIds}) async {
    undoOwnCalls++;
    return undoOwnResult;
  }

  @override
  Future<List<BoardOperation>> getBlock(String boardId, String blockId) =>
      throw UnimplementedError();

  @override
  Future<UserOpsPage> getUserOps(
    String boardId,
    String targetUid, {
    DateTime? fromTime,
    DateTime? toTime,
    int? beforeVersion,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<HistoryPreview> previewVersion(String boardId, int version) =>
      throw UnimplementedError();

  @override
  Future<RevertPlan> planRevert(
    String boardId, {
    required String mode,
    int? targetVersion,
    String? targetUid,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? elementIds,
    String? requestId,
  }) => throw UnimplementedError();

  @override
  Future<RevertResult> applyRevert(
    String boardId, {
    required String planId,
    required Map<String, String> decisions,
    String? requestId,
  }) => throw UnimplementedError();

  @override
  Future<String> submitUndoRequest({
    required String boardId,
    required List<String> elementIds,
    required String reason,
    DateTime? fromTime,
    DateTime? toTime,
  }) => throw UnimplementedError();

  @override
  Future<void> resolveUndoRequest({
    required String boardId,
    required String requestId,
    required String status,
    String? note,
    int? appliedVersion,
  }) => throw UnimplementedError();

  @override
  void dispose() {}
}

Future<void> _settle([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

LocalCrdtUpdate _remoteUpdate({
  required String updateId,
  required String elementId,
  required String action,
  required Uint8List payload,
}) {
  return LocalCrdtUpdate()
    ..updateId = updateId
    ..boardId = 'board-1'
    ..elementId = elementId
    ..action = action
    ..payloadBase64 = base64Encode(payload)
    ..sourceClientId = 'peer-2'
    ..appliedAt = DateTime.now();
}

/// Builds a peer overwrite whose Yjs clock strictly beats the local item AND
/// whose transmitted diff is self-contained: the peer captures the state
/// vector BEFORE its throwaway + overwrite upserts, then broadcasts ONE
/// update covering both ops — exactly how a real multi-edit broadcast
/// travels. (Applying a diff whose origin items are missing makes elements
/// VANISH in yjs_dart; real-app diffs always carry what they reference.)
Future<(Uint8List overwrite, CanvasCrdtAdapter peer)> _peerOverwrite(
  Uint8List myCreate,
  String elementId,
  Map<String, dynamic> overwritePayload,
) async {
  final peer = await CanvasCrdtAdapter.create();
  peer.applyUpdate(myCreate, origin: 'remote');
  // Capture before the local edits so the diff carries both of them.
  final before = peer.encodeStateVector();
  peer.upsertElement(elementId, const {'type': 'shape', 'throwaway': true});
  peer.upsertElement(elementId, overwritePayload);
  final overwrite = peer.encodeStateUpdate(vector: before);
  return (overwrite, peer);
}

void main() {
  late _FakeCanvasService canvas;
  late _FakeHistoryService history;

  CanvasBloc buildBloc() {
    canvas = _FakeCanvasService();
    history = _FakeHistoryService();
    return CanvasBloc(
      canvasService: canvas,
      historyService: history,
      boardId: 'board-1',
      currentUserId: 'me-1',
    );
  }

  /// Creates the CRDT adapter, makes this device an editor, adds one shape.
  /// Returns the bloc, the shape, and the CRDT bytes of its creation.
  Future<(CanvasBloc, ShapeElement, Uint8List)> setupWithLocalShape() async {
    final bloc = buildBloc();
    bloc.add(const CanvasInitializeCrdt('board-1'));
    await _settle();
    bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: 'editor'));
    await _settle();
    bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(10, 10)));
    await _settle(80);
    final shape = bloc.state.elements.single as ShapeElement;
    final myCreate = canvas.pushedPayloads.single;
    canvas.pushedPayloads.clear();
    return (bloc, shape, myCreate);
  }

  group('local undo/redo vs collaborator overwrite (§7.2)', () {
    test(
      'undo of an overwritten element shows a conflict and keeps the entry',
      () async {
        final (bloc, shape, myCreate) = await setupWithLocalShape();

        final peerShape = ShapeElement(
          id: shape.id,
          z: shape.z,
          shapeType: shape.shapeType,
          center: shape.center,
          size: shape.size,
          color: const Color(0xFF00FF00),
          strokeWidth: shape.strokeWidth,
        );
        final (overwrite, _) = await _peerOverwrite(
          myCreate,
          shape.id,
          peerShape.toMap(),
        );

        bloc.add(CanvasApplyRemoteUpdate([
          _remoteUpdate(
            updateId: 'remote-overwrite',
            elementId: shape.id,
            action: 'upsert',
            payload: overwrite,
          ),
        ]));
        await _settle();
        expect(
          (bloc.state.elements.single as ShapeElement).color.value,
          peerShape.color.value,
        );

        bloc.add(const CanvasUndo());
        await _settle(80);

        // The conflict surfaces, the peer's value stays live, and the stack
        // entry was NOT popped (no publish, no server fallback).
        expect(bloc.state.undoConflict, isNotNull);
        expect(bloc.state.undoConflict!.elementIds, [shape.id]);
        expect(
          (bloc.state.elements.single as ShapeElement).color.value,
          peerShape.color.value,
        );
        expect(history.undoOwnCalls, 0);
        expect(canvas.pushedPayloads, isEmpty);

        bloc.add(const CanvasUndoConflictDismissed());
        await _settle();
        expect(bloc.state.undoConflict, isNull);

        await bloc.close();
      },
    );

    test('undo works again once the peer undoes their overwrite', () async {
      final (bloc, shape, myCreate) = await setupWithLocalShape();

      final (overwrite, peer) = await _peerOverwrite(
        myCreate,
        shape.id,
        ShapeElement(
          id: shape.id,
          z: shape.z,
          shapeType: shape.shapeType,
          center: shape.center,
          size: shape.size,
          color: const Color(0xFF00FF00),
        ).toMap(),
      );

      bloc.add(CanvasApplyRemoteUpdate([
        _remoteUpdate(
          updateId: 'remote-overwrite',
          elementId: shape.id,
          action: 'upsert',
          payload: overwrite,
        ),
      ]));
      await _settle();

      bloc.add(const CanvasUndo());
      await _settle(80);
      expect(bloc.state.undoConflict, isNotNull);
      bloc.add(const CanvasUndoConflictDismissed());
      await _settle();

      // The peer undoes their own overwrite: their single merged entry
      // (throwaway + overwrite) is deleted, so the element reverts to my
      // payload and my undo must work again (within the 15-minute window,
      // D2).
      final peerUndo = peer.undoLast();
      expect(peerUndo, isNotNull);
      bloc.add(CanvasApplyRemoteUpdate([
        _remoteUpdate(
          updateId: 'remote-peer-undo',
          elementId: shape.id,
          action: 'upsert',
          payload: peerUndo!,
        ),
      ]));
      await _settle();
      expect(
        (bloc.state.elements.single as ShapeElement).color.value,
        shape.color.value,
      );

      bloc.add(const CanvasUndo());
      await _settle(80);

      // The local stack entry could not act structurally (its items were
      // tombstoned by the peer), so the adapter completed the undo as an
      // element-level revert: the element is gone and the change published.
      expect(bloc.state.undoConflict, isNull);
      expect(bloc.state.elements.where((e) => e.id == shape.id), isEmpty);
      expect(history.undoOwnCalls, 0, reason: 'local undo, not the log path');
      expect(canvas.pushedPayloads.length, 1);

      await bloc.close();
    });

    test('redo is conflict-gated, and after the peer undoes there is no false '
        'conflict', () async {
      final (bloc, shape, myCreate) = await setupWithLocalShape();

      // Clean undo: my creation is reverted, the baseline refreshed to
      // "absent" and the entry moved to the redo stack.
      bloc.add(const CanvasUndo());
      await _settle(80);
      expect(bloc.state.elements, isEmpty);
      expect(canvas.pushedPayloads.length, 1);
      canvas.pushedPayloads.clear();

      // A peer re-creates the element with different content.
      final (overwrite, peer) = await _peerOverwrite(
        myCreate,
        shape.id,
        ShapeElement(
          id: shape.id,
          z: shape.z,
          shapeType: shape.shapeType,
          center: shape.center,
          size: shape.size,
          color: const Color(0xFFFF0000),
        ).toMap(),
      );
      bloc.add(CanvasApplyRemoteUpdate([
        _remoteUpdate(
          updateId: 'remote-overwrite',
          elementId: shape.id,
          action: 'upsert',
          payload: overwrite,
        ),
      ]));
      await _settle();

      bloc.add(const CanvasRedo());
      await _settle(80);
      expect(bloc.state.undoConflict, isNotNull);
      expect(
        (bloc.state.elements.single as ShapeElement).color.value,
        const Color(0xFFFF0000).value,
      );
      bloc.add(const CanvasUndoConflictDismissed());
      await _settle();

      // The peer removes their merged overwrite entry again. Their undo
      // restores the pre-overwrite state — which is MY payload — so the
      // element comes back on its own and redoing my entry would change
      // nothing. That must NOT surface a conflict (the work is already
      // restored); it is an honest no-op.
      final peerUndo = peer.undoLast();
      expect(peerUndo, isNotNull);
      bloc.add(CanvasApplyRemoteUpdate([
        _remoteUpdate(
          updateId: 'remote-peer-undo',
          elementId: shape.id,
          action: 'upsert',
          payload: peerUndo!,
        ),
      ]));
      await _settle();
      expect(
        (bloc.state.elements.single as ShapeElement).color.value,
        shape.color.value,
      );

      bloc.add(const CanvasRedo());
      await _settle(80);

      expect(bloc.state.undoConflict, isNull);
      expect(canvas.pushedPayloads, isEmpty);
      expect(bloc.state.infoMessage, 'Nothing to redo.');
      expect(
        (bloc.state.elements.single as ShapeElement).color.value,
        shape.color.value,
      );

      await bloc.close();
    });
  });

  group('server-side undo conflicts (D2 fallback)', () {
    test('a fully conflicted log undo surfaces the conflict flow', () async {
      final bloc = buildBloc();
      history.undoOwnResult = const RevertResult(
        conflicts: [
          RevertConflict(elementId: 'e-1', lastEditorUid: 'peer-2'),
          RevertConflict(elementId: 'e-2'),
        ],
      );

      bloc.add(const CanvasHistoryUndoOwn());
      await _settle(80);

      expect(history.undoOwnCalls, 1);
      expect(bloc.state.undoConflict, isNotNull);
      expect(bloc.state.undoConflict!.elementIds, ['e-1', 'e-2']);
      expect(bloc.state.isHistoryLoading, isFalse);

      bloc.add(const CanvasUndoConflictDismissed());
      await _settle();
      expect(bloc.state.undoConflict, isNull);

      await bloc.close();
    });

    test('a mixed log undo reports the count without a conflict dialog',
        () async {
      final bloc = buildBloc();
      history.undoOwnResult = const RevertResult(
        appliedVersion: 7,
        reverted: ['e-1'],
        skipped: ['e-2'],
        conflicts: [RevertConflict(elementId: 'e-2', lastEditorUid: 'peer-2')],
      );

      bloc.add(const CanvasHistoryUndoOwn());
      await _settle(80);

      expect(bloc.state.undoConflict, isNull);
      expect(bloc.state.infoMessage, contains('Undid 1'));

      await bloc.close();
    });
  });
}
