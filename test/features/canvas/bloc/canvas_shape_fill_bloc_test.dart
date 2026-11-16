import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

Future<CanvasState> _until(
  CanvasBloc bloc,
  bool Function(CanvasState) predicate,
) => bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));

class _Service extends Fake implements CanvasService {
  int count = 0;
  bool failWrites = false;
  bool retryResult = true;
  final writes = StreamController<Uint8List>.broadcast(sync: true);

  @override
  String? get currentClientId => 'author';
  @override
  Stream<Board?> watchBoardById(String id) => const Stream.empty();
  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String id) =>
      const Stream.empty();
  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String id) =>
      const Stream.empty();
  @override
  Future<void> stopCrdtRemoteSync(String id) async {}
  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}
  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {
    if (failWrites) throw StateError('offline');
    count++;
    writes.add(payload);
  }

  @override
  Future<bool> retryPendingSync(String boardId) async => retryResult;
}

Future<({CanvasBloc bloc, _Service service})> _editor() async {
  final adapter = await CanvasCrdtAdapter.create();
  final service = _Service();
  final bloc = CanvasBloc(
    crdtAdapter: adapter,
    canvasService: service,
    boardId: 'board',
  );
  addTearDown(() async {
    await bloc.close();
    await service.writes.close();
  });
  bloc.add(const CanvasInitializeCrdt('board'));
  await _until(bloc, (state) => !state.isLoading);
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
  await _until(bloc, (state) => state.canEdit);
  return (bloc: bloc, service: service);
}

void main() {
  test(
    'Given an editor, Then fill colour is independent from the stroke',
    () async {
      final (:bloc, :service) = await _editor();
      bloc.add(
        const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 100)),
      );
      final added = await _until(bloc, (state) => state.elements.length == 1);
      final id = added.elements.single.id;

      bloc.add(
        const CanvasUpdateShapeFill(
          fillMode: 'solid',
          fillColor: Color(0xFFEF4444),
        ),
      );
      final state = await _until(
        bloc,
        (state) =>
            (state.elements.single as ShapeElement).fillColor ==
            const Color(0xFFEF4444),
      );
      final shape = state.elements.single as ShapeElement;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(shape.fillMode, 'solid');
      expect(shape.color, isNot(const Color(0xFFEF4444)));
      expect(shape.isFilled, isTrue);
      expect(bloc.state.selectedShapeIsFilled, isTrue);
      expect(service.count, greaterThanOrEqualTo(2));
      expect(bloc.state.selectedShapeId, id);
    },
  );

  test(
    'Given fill updates, Then linear gradients persist their angle',
    () async {
      final (:bloc, service: _) = await _editor();
      bloc.add(const CanvasAddShape(CanvasShapeType.ellipse, Offset(100, 100)));
      await _until(bloc, (state) => state.elements.length == 1);

      bloc.add(
        const CanvasUpdateShapeFill(
          fillMode: 'linear',
          gradientStart: Color(0xFFEF4444),
          gradientEnd: Color(0xFF22C55E),
          gradientAngle: 90,
        ),
      );
      final state = await _until(
        bloc,
        (state) => (state.elements.single as ShapeElement).fillMode == 'linear',
      );
      final shape = state.elements.single as ShapeElement;

      expect(shape.gradientAngle, 90);
      expect(shape.gradientStart, const Color(0xFFEF4444));
      expect(shape.gradientEnd, const Color(0xFF22C55E));
    },
  );

  test(
    'Given a freehand outline, Then its interior fill is persisted',
    () async {
      final (:bloc, service: _) = await _editor();
      bloc.add(const CanvasStartStroke(Offset.zero));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      for (final point in const [
        Offset(100, 0),
        Offset(100, 100),
        Offset(0, 100),
        Offset(2, 2),
      ]) {
        final count = bloc.state.currentStroke.length;
        bloc.add(CanvasAppendStroke(point));
        await _until(bloc, (state) => state.currentStroke.length > count);
      }
      bloc.add(const CanvasEndStroke());
      final drawn = await _until(bloc, (state) => state.elements.length == 1);
      final strokeId = drawn.elements.single.id;

      bloc.add(
        const CanvasFillStroke(
          strokeId: 'placeholder',
          color: Color(0xFF2563EB),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((bloc.state.elements.single as StrokeElement).fillColor, isNull);

      bloc.add(
        CanvasFillStroke(strokeId: strokeId, color: const Color(0xFF2563EB)),
      );
      final filled = await _until(
        bloc,
        (state) =>
            (state.elements.single as StrokeElement).fillColor ==
            const Color(0xFF2563EB),
      );
      expect(filled.elements.single, isA<StrokeElement>());
    },
  );

  test('Given a filled freehand stroke, Then remove fill clears it', () async {
    final (:bloc, service: _) = await _editor();
    bloc.add(const CanvasStartStroke(Offset.zero));
    await _until(bloc, (state) => state.currentStroke.isNotEmpty);
    for (final point in const [
      Offset(100, 0),
      Offset(100, 100),
      Offset(0, 100),
      Offset(2, 2),
    ]) {
      final count = bloc.state.currentStroke.length;
      bloc.add(CanvasAppendStroke(point));
      await _until(bloc, (state) => state.currentStroke.length > count);
    }
    bloc.add(const CanvasEndStroke());
    final drawn = await _until(bloc, (state) => state.elements.length == 1);
    final strokeId = drawn.elements.single.id;
    bloc.add(
      CanvasFillStroke(strokeId: strokeId, color: const Color(0xFF2563EB)),
    );
    await _until(
      bloc,
      (state) =>
          (state.elements.single as StrokeElement).fillColor ==
          const Color(0xFF2563EB),
    );

    bloc.add(CanvasClearStrokeFill(strokeId));
    final cleared = await _until(
      bloc,
      (state) => (state.elements.single as StrokeElement).fillColor == null,
    );
    expect(cleared.elements.single, isA<StrokeElement>());
  });

  test('Given a multi-selection, Then shared style is one batch', () async {
    final (:bloc, service: _) = await _editor();
    bloc.add(const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 100)));
    await _until(bloc, (state) => state.elements.length == 1);
    bloc.add(const CanvasAddShape(CanvasShapeType.ellipse, Offset(240, 100)));
    final added = await _until(bloc, (state) => state.elements.length == 2);
    final ids = added.elements.map((element) => element.id).toSet();
    bloc.add(CanvasSelectElements(ids));
    await _until(bloc, (state) => state.selectedIds.length == 2);

    bloc.add(
      CanvasUpdateSelectionStyle(
        ids,
        color: const Color(0xFF16A34A),
        opacity: 0.4,
        locked: true,
      ),
    );
    final styled = await _until(
      bloc,
      (state) => state.elements.every(
        (element) =>
            element is ShapeElement &&
            element.color == const Color(0xFF16A34A) &&
            element.opacity == 0.4 &&
            element.locked,
      ),
    );
    expect(styled.elements.length, 2);
  });

  test(
    'Given a multi-selection, Then it moves to a layer as one batch',
    () async {
      final (:bloc, service: _) = await _editor();
      bloc.add(const CanvasAddLayer('Ideas'));
      final layered = await _until(
        bloc,
        (state) => state.elements.whereType<LayerElement>().isNotEmpty,
      );
      final layerId = layered.elements.whereType<LayerElement>().single.id;
      bloc.add(
        const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 100)),
      );
      await _until(bloc, (state) => state.elements.length == 2);
      bloc.add(const CanvasAddShape(CanvasShapeType.ellipse, Offset(240, 100)));
      final added = await _until(bloc, (state) => state.elements.length == 3);
      final ids = added.elements
          .whereType<ShapeElement>()
          .map((element) => element.id)
          .toSet();
      bloc.add(CanvasSelectElements(ids));
      await _until(bloc, (state) => state.selectedIds.length == 2);

      bloc.add(CanvasMoveSelectionToLayer(ids, null));
      final moved = await _until(
        bloc,
        (state) =>
            state.elements.whereType<LayerElement>().single.elementIds.isEmpty,
      );
      expect(moved.selectedIds, ids);
      expect(
        moved.elements.whereType<LayerElement>().single.elementIds,
        isEmpty,
      );
      expect(layerId, isNotEmpty);
    },
  );

  test('Given a cancelled stroke, Then nothing is committed', () async {
    final (:bloc, service: _) = await _editor();
    bloc.add(const CanvasStartStroke(Offset.zero));
    await _until(bloc, (state) => state.currentStroke.isNotEmpty);
    bloc.add(const CanvasAppendStroke(Offset(80, 40)));
    await _until(bloc, (state) => state.currentStroke.length == 2);

    bloc.add(const CanvasCancelStroke());
    final cancelled = await _until(
      bloc,
      (state) => state.currentStroke.isEmpty,
    );
    expect(cancelled.elements, isEmpty);
  });

  test('Given a failed write, Then sync becomes offline and retries', () async {
    final (:bloc, :service) = await _editor();
    service.failWrites = true;
    bloc.add(const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 100)));
    final offline = await _until(
      bloc,
      (state) => state.syncStatus == CanvasSyncStatus.offline,
    );
    expect(offline.syncMessage, isNotNull);

    service.failWrites = false;
    service.retryResult = true;
    bloc.add(const CanvasRetrySync());
    final saved = await _until(
      bloc,
      (state) => state.syncStatus == CanvasSyncStatus.saved,
    );
    expect(saved.syncMessage, isNull);
  });

  test('Given a viewer, Then fill is rejected', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(
      const CanvasUpdateShapeFill(
        shapeId: 'shape',
        fillMode: 'solid',
        fillColor: Color(0xFFEF4444),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.elements, isEmpty);
  });
}
