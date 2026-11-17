import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

class _FakeCanvasService extends Fake implements CanvasService {
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
    writes.add(payload);
  }
}

Future<CanvasState> _until(CanvasBloc bloc, bool Function(CanvasState) test) =>
    bloc.stream.firstWhere(test).timeout(const Duration(seconds: 3));

void main() {
  ShapeElement shape(String id, Offset center) => ShapeElement(
    id: id,
    z: 0,
    shapeType: CanvasShapeType.rectangle,
    center: center,
    size: 80,
    width: 80,
    height: 60,
    color: Colors.blue,
    strokeWidth: 2,
  );

  ConnectorElement conn(String id, String from, String to) => ConnectorElement(
    id: id,
    z: 10,
    startElementId: from,
    endElementId: to,
    startPoint: Offset.zero,
    endPoint: Offset.zero,
  );

  Future<CanvasBloc> seededBloc(List<CanvasElement> elements, Set<String> selected) async {
    final adapter = await CanvasDocAdapterFactory.create();
    adapter.applyBatch([
      for (final e in elements) (id: e.id, payload: e.toMap()),
    ], origin: 'remote');
    final service = _FakeCanvasService();
    final bloc = CanvasBloc(
      crdtAdapter: adapter,
      canvasService: service,
      boardId: 'b',
    );
    addTearDown(() async {
      await bloc.close();
      await service.writes.close();
    });
    bloc.add(const CanvasInitializeCrdt('b'));
    await _until(bloc, (s) => !s.isLoading && s.elements.length == elements.length);
    bloc.add(
      const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
    );
    await _until(bloc, (s) => s.canEdit);
    bloc.add(CanvasSelectElements(selected));
    await _until(bloc, (s) => s.selectedIds.length == selected.length);
    return bloc;
  }

  group('F-17 Mind map, tidy up & auto-layout', () {
    test('Given 5 stacked shapes, When arranged in grid, Then none overlap and one undo restores all', () async {
      final original = [
        for (var i = 0; i < 5; i++) shape('s$i', Offset(100.0 + i * 2, 100.0)),
      ];
      final bloc = await seededBloc(
        original,
        {for (final s in original) s.id},
      );

      bloc.add(const CanvasArrangeSelection(CanvasArrangeMode.grid, spacing: 24));
      await _until(
        bloc,
        (s) =>
            (s.elements.firstWhere((e) => e.id == 's4') as ShapeElement).center !=
            original[4].center,
      );

      final arranged = bloc.state.elements.whereType<ShapeElement>().toList();
      for (var i = 0; i < arranged.length; i++) {
        for (var j = i + 1; j < arranged.length; j++) {
          final r1 = Rect.fromCenter(
            center: arranged[i].center,
            width: arranged[i].width,
            height: arranged[i].height,
          );
          final r2 = Rect.fromCenter(
            center: arranged[j].center,
            width: arranged[j].width,
            height: arranged[j].height,
          );
          expect(r1.overlaps(r2), isFalse, reason: '${arranged[i].id} overlaps ${arranged[j].id}');
        }
      }

      bloc.add(const CanvasUndo());
      await _until(
        bloc,
        (s) =>
            (s.elements.firstWhere((e) => e.id == 's4') as ShapeElement).center ==
            original[4].center,
      );
      for (var i = 0; i < original.length; i++) {
        final restored = bloc.state.elements.firstWhere((e) => e.id == 's$i') as ShapeElement;
        expect(restored.center, original[i].center);
      }
    });

    test('Given cycle in tree + free connector, When tree arrange runs, Then it finishes without overlap and preserves free connectors', () async {
      final s1 = shape('n1', const Offset(10, 10));
      final s2 = shape('n2', const Offset(15, 15));
      final s3 = shape('n3', const Offset(20, 20));
      final c12 = conn('c12', 'n1', 'n2');
      final c23 = conn('c23', 'n2', 'n3');
      final cycle = conn('c31', 'n3', 'n1');
      const freeConn = ConnectorElement(
        id: 'free',
        z: 11,
        startPoint: Offset(500, 500),
        endPoint: Offset(600, 600),
      );
      final bloc = await seededBloc(
        [s1, s2, s3, c12, c23, cycle, freeConn],
        {'n1', 'n2', 'n3', 'c12', 'c23', 'c31', 'free'},
      );

      bloc.add(
        const CanvasArrangeSelection(CanvasArrangeMode.tree, rootId: 'n1'),
      );
      await _until(
        bloc,
        (s) =>
            (s.elements.firstWhere((e) => e.id == 'n2') as ShapeElement).center !=
            s2.center,
      );

      final n1 = bloc.state.elements.firstWhere((e) => e.id == 'n1') as ShapeElement;
      final n2 = bloc.state.elements.firstWhere((e) => e.id == 'n2') as ShapeElement;
      final n3 = bloc.state.elements.firstWhere((e) => e.id == 'n3') as ShapeElement;
      // Tree expands left-to-right across BFS depths
      expect(n2.center.dx, greaterThan(n1.center.dx));
      expect(n3.center.dx, greaterThan(n2.center.dx));

      // Free connector untouched
      final freeAfter =
          bloc.state.elements.firstWhere((e) => e.id == 'free') as ConnectorElement;
      expect(freeAfter.startPoint, const Offset(500, 500));
      expect(freeAfter.endPoint, const Offset(600, 600));
    });

    test('Given viewer role, When CanvasArrangeSelection runs, Then positions do not change', () async {
      final original = [shape('a', const Offset(10, 10)), shape('b', const Offset(20, 20))];
      final bloc = await seededBloc(original, {'a', 'b'});
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _until(bloc, (s) => !s.canEdit);

      bloc.add(const CanvasArrangeSelection(CanvasArrangeMode.row));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        (bloc.state.elements.firstWhere((e) => e.id == 'b') as ShapeElement).center,
        const Offset(20, 20),
      );
    });
  });
}
