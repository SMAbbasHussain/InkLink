import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/canvas/canvas_board_settings.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';

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
  group('F-18 CanvasBoardSettings, guides, snapping & symmetry math', () {
    test('Given F-18 guides, symmetry & perspective fields, When serialized, Then fromMap preserves all', () {
      const settings = CanvasBoardSettings(
        backgroundColor: Color(0xFF0F172A),
        backgroundPattern: CanvasBackgroundPattern.grid,
        patternSpacing: 40,
        rulersEnabled: true,
        snapEnabled: true,
        snapDistance: 12,
        guides: [
          CanvasGuide(id: 'g1', axis: CanvasGuideAxis.vertical, position: 120),
          CanvasGuide(id: 'g2', axis: CanvasGuideAxis.horizontal, position: -50),
        ],
        symmetryMode: CanvasSymmetryMode.radial,
        symmetryCenter: Offset(100, 200),
        symmetryCount: 6,
        perspectiveEnabled: true,
        vanishingPoints: [Offset(300, -100)],
      );

      final parsed = CanvasBoardSettings.fromMap(settings.toMap());
      expect(parsed, equals(settings));
    });

    test('Given guides and grid, When snapBoundsAdjustment runs, Then guides take priority within scaled threshold', () {
      const settings = CanvasBoardSettings(
        patternSpacing: 50,
        snapEnabled: true,
        snapDistance: 10,
        guides: [
          CanvasGuide(id: 'gv', axis: CanvasGuideAxis.vertical, position: 103),
          CanvasGuide(id: 'gh', axis: CanvasGuideAxis.horizontal, position: 204),
        ],
      );
      final adj = snapBoundsAdjustment(
        const Rect.fromLTWH(100, 200, 40, 40),
        settings,
        viewportScale: 1.0,
      );
      expect(adj.dx, closeTo(3.0, 1e-6));
      expect(adj.dy, closeTo(4.0, 1e-6));

      final disabled = snapBoundsAdjustment(
        const Rect.fromLTWH(100, 200, 40, 40),
        settings.copyWith(snapEnabled: false),
      );
      expect(disabled, Offset.zero);
    });

    test('Given symmetry modes, When symmetryMirroredCopies runs, Then vertical/horizontal/radial points mirror accurately', () {
      const vSettings = CanvasBoardSettings(
        symmetryMode: CanvasSymmetryMode.vertical,
        symmetryCenter: Offset(100, 50),
      );
      expect(
        symmetryMirroredCopies(const Offset(130, 80), vSettings),
        [const Offset(70, 80)],
      );

      const hSettings = CanvasBoardSettings(
        symmetryMode: CanvasSymmetryMode.horizontal,
        symmetryCenter: Offset(100, 50),
      );
      expect(
        symmetryMirroredCopies(const Offset(130, 80), hSettings),
        [const Offset(130, 20)],
      );

      const rSettings = CanvasBoardSettings(
        symmetryMode: CanvasSymmetryMode.radial,
        symmetryCenter: Offset.zero,
        symmetryCount: 4,
      );
      final radial = symmetryMirroredCopies(const Offset(10, 0), rSettings);
      expect(radial.length, 3);
      expect(radial[0].dx, closeTo(0, 1e-6));
      expect(radial[0].dy, closeTo(10, 1e-6));
      expect(radial[1].dx, closeTo(-10, 1e-6));
      expect(radial[1].dy, closeTo(0, 1e-6));
      expect(radial[2].dx, closeTo(0, 1e-6));
      expect(radial[2].dy, closeTo(-10, 1e-6));
    });
  });

  group('F-18 Guides & symmetry strokes in CanvasBloc', () {
    test('Given guide events, When added/moved/removed, Then board settings persist through CRDT', () async {
      final adapter = await CanvasDocAdapterFactory.create();
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
      await _until(bloc, (s) => !s.isLoading);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);

      bloc.add(
        const CanvasAddGuide(axis: CanvasGuideAxis.vertical, position: 150),
      );
      await _until(bloc, (s) => s.boardSettings.guides.length == 1);
      final guideId = bloc.state.boardSettings.guides.single.id;

      bloc.add(CanvasMoveGuide(guideId: guideId, position: 220));
      await _until(
        bloc,
        (s) => s.boardSettings.guides.single.position == 220,
      );

      bloc.add(CanvasRemoveGuide(guideId));
      await _until(bloc, (s) => s.boardSettings.guides.isEmpty);
    });

    test('Given vertical or radial symmetry, When stroke ends, Then mirrored strokes commit in one undoable batch', () async {
      final adapter = await CanvasDocAdapterFactory.create();
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
      await _until(bloc, (s) => !s.isLoading);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);

      bloc.add(
        const CanvasSetBoardSettings(
          CanvasBoardSettings(
            symmetryMode: CanvasSymmetryMode.radial,
            symmetryCenter: Offset.zero,
            symmetryCount: 4,
          ),
        ),
      );
      await _until(
        bloc,
        (s) => s.boardSettings.symmetryMode == CanvasSymmetryMode.radial,
      );

      bloc.add(const CanvasStartStroke(Offset(10, 0)));
      bloc.add(const CanvasAppendStroke(Offset(20, 5)));
      bloc.add(const CanvasEndStroke());
      await _until(
        bloc,
        (s) => s.elements.whereType<StrokeElement>().length == 4,
      );

      expect(bloc.state.elements.whereType<StrokeElement>().length, 4);

      // One undo removes all 4 symmetry strokes together
      bloc.add(const CanvasUndo());
      await _until(
        bloc,
        (s) => s.elements.whereType<StrokeElement>().isEmpty,
      );
      expect(bloc.state.elements.whereType<StrokeElement>(), isEmpty);
    });
  });
}
