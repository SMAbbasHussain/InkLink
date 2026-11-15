import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';

Future<CanvasState> _until(CanvasBloc bloc, bool Function(CanvasState) test) {
  return bloc.stream.firstWhere(test).timeout(const Duration(seconds: 2));
}

Future<CanvasBloc> _editor({double strength = 0}) async {
  final bloc = CanvasBloc();
  addTearDown(bloc.close);
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
  await _until(bloc, (state) => state.canEdit);
  if (strength != 0) {
    bloc.add(CanvasUpdateStabilizer(strength));
    await _until(bloc, (state) => state.stabilizerStrength == strength);
  }
  return bloc;
}

Future<void> _point(CanvasBloc bloc, Offset point, double pressure) async {
  final count = bloc.state.currentStroke.length;
  bloc.add(CanvasAppendStroke(point, pressure: pressure));
  await _until(bloc, (state) => state.currentStroke.length > count);
}

class _RecordingCanvasService extends Fake implements CanvasService {
  final committed = Completer<Uint8List>();
  var writes = 0;

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
  }) async {
    writes++;
    if (!committed.isCompleted) committed.complete(payload);
  }

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {}
}

void main() {
  test(
    'Given a stabilized gesture, Then one CRDT write restores and undoes it',
    () async {
      final adapter = await CanvasCrdtAdapter.create();
      final service = _RecordingCanvasService();
      final bloc = CanvasBloc(
        crdtAdapter: adapter,
        canvasService: service,
        boardId: 'test-board',
      );
      addTearDown(bloc.close);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (state) => state.canEdit);
      bloc.add(const CanvasUpdateStabilizer(0.5));
      await _until(bloc, (state) => state.stabilizerStrength == 0.5);
      bloc.add(const CanvasStartStroke(Offset.zero, pressure: 0.2));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(20, 0), 0.8);
      expect(service.writes, 0);
      bloc.add(const CanvasEndStroke());
      final payload = await service.committed.future.timeout(
        const Duration(seconds: 2),
      );
      expect(service.writes, 1);
      final replica = await CanvasCrdtAdapter.create();
      replica.applyUpdate(payload);
      final replicaBloc = CanvasBloc(crdtAdapter: replica);
      addTearDown(replicaBloc.close);
      replicaBloc.add(const CanvasInitializeCrdt('test-board'));
      final replicaState = await _until(
        replicaBloc,
        (state) => !state.isLoading && state.elements.isNotEmpty,
      );
      final restored = replicaState.elements.single as StrokeElement;
      expect(restored.points, [
        Offset.zero,
        const Offset(10, 0),
        const Offset(20, 0),
      ]);
      expect(restored.pressures, [0.2, 0.8, 0.8]);
      final original = bloc.state.elements.single as StrokeElement;
      expect(restored.brushId, original.brushId);
      expect(restored.spacing, original.spacing);
      expect(restored.textureSeed, original.textureSeed);
      bloc.add(const CanvasUndo());
      await _until(bloc, (state) => state.infoMessageRedoable);
      expect(bloc.state.elements, isEmpty);
      expect(adapter.canUndo, isFalse);
    },
  );

  test(
    'Given role loss mid-stroke, Then points and pressure are discarded',
    () async {
      final bloc = await _editor(strength: 0.5);
      bloc.add(const CanvasStartStroke(Offset.zero, pressure: 0.2));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _until(bloc, (state) => !state.canEdit);
      bloc.add(const CanvasAppendStroke(Offset(20, 0), pressure: 0.4));
      await _until(bloc, (state) => state.error != null);
      expect(bloc.state.currentStroke, isEmpty);
      expect(bloc.state.currentStrokePressures, isEmpty);
      expect(bloc.state.elements, isEmpty);
    },
  );

  test(
    'Given stabilization, Then live and committed pressures align',
    () async {
      final bloc = await _editor(strength: 0.5);
      bloc.add(const CanvasStartStroke(Offset.zero, pressure: 0.2));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(10, 0), 0.4);
      await _point(bloc, const Offset(20, 0), 0.8);
      expect(bloc.state.currentStroke.last, const Offset(12.5, 0));
      expect(bloc.state.currentStrokePressures, [0.2, 0.4, 0.8]);

      bloc.add(const CanvasEndStroke());
      final state = await _until(bloc, (state) => state.elements.isNotEmpty);
      final stroke = state.elements.single as StrokeElement;
      expect(stroke.points, [
        Offset.zero,
        const Offset(5, 0),
        const Offset(12.5, 0),
        const Offset(20, 0),
      ]);
      expect(stroke.pressures, [0.2, 0.4, 0.8, 0.8]);
      final restored =
          CanvasElement.fromMap(stroke.id, stroke.toMap()) as StrokeElement;
      expect(restored.points, stroke.points);
      expect(restored.pressures, stroke.pressures);
    },
  );

  test(
    'Given a corner, Then added points retain matching raw pressures',
    () async {
      final bloc = await _editor(strength: 0.5);
      bloc.add(const CanvasStartStroke(Offset.zero, pressure: 0.2));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(20, 0), 0.4);
      await _point(bloc, const Offset(20, 20), 0.8);
      expect(bloc.state.currentStroke, [
        Offset.zero,
        const Offset(10, 0),
        const Offset(20, 0),
        const Offset(20, 20),
      ]);
      expect(bloc.state.currentStrokePressures, [0.2, 0.4, 0.4, 0.8]);
      bloc.add(const CanvasEndStroke());
      final state = await _until(bloc, (state) => state.elements.isNotEmpty);
      final stroke = state.elements.single as StrokeElement;
      expect(stroke.points.length, stroke.pressures.length);
    },
  );

  test(
    'Given pressure disabled, Then live and committed values are full',
    () async {
      final bloc = await _editor();
      bloc.add(const CanvasUpdateStylusPressure(false));
      await _until(bloc, (state) => !state.stylusPressureEnabled);
      bloc.add(const CanvasStartStroke(Offset.zero, pressure: 0.2));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(20, 0), 0.4);
      expect(bloc.state.currentStrokePressures, [1.0, 1.0]);
      bloc.add(const CanvasEndStroke(pressures: [0.2, 0.4]));
      final state = await _until(bloc, (state) => state.elements.isNotEmpty);
      expect((state.elements.single as StrokeElement).pressures, [1.0, 1.0]);
    },
  );

  test(
    'Given live stabilization, Then post-smoothing is not applied twice',
    () async {
      final bloc = await _editor(strength: 0.5);
      bloc.add(const CanvasStartStroke(Offset.zero));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(10, 0), 1);
      await _point(bloc, const Offset(20, 0), 1);
      bloc.add(const CanvasEndStroke(smoothAfterDrawing: true));
      final state = await _until(bloc, (state) => state.elements.isNotEmpty);
      expect(
        (state.elements.single as StrokeElement).points[1],
        const Offset(5, 0),
      );
    },
  );

  test(
    'Given a new gesture, Then the filter starts at its new origin',
    () async {
      final bloc = await _editor(strength: 0.5);
      bloc.add(const CanvasStartStroke(Offset.zero));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(10, 0), 1);
      bloc.add(const CanvasEndStroke());
      await _until(bloc, (state) => state.elements.length == 1);
      bloc.add(const CanvasStartStroke(Offset(100, 100)));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(110, 100), 1);
      expect(bloc.state.currentStroke.last, const Offset(105, 100));
    },
  );

  test(
    'Given eraser mode, Then stabilization never alters its sweep',
    () async {
      final bloc = await _editor(strength: 0.8);
      bloc.add(const CanvasSetToolMode(CanvasToolMode.eraser));
      await _until(
        bloc,
        (state) => state.currentToolMode == CanvasToolMode.eraser,
      );
      bloc.add(const CanvasStartStroke(Offset.zero));
      await _until(bloc, (state) => state.currentStroke.isNotEmpty);
      await _point(bloc, const Offset(20, 0), 1);
      expect(bloc.state.currentStroke.last, const Offset(20, 0));
    },
  );

  test('Given a viewer, Then stylus input cannot mutate the board', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(const CanvasStartStroke(Offset.zero, pressure: 0.5));
    await _until(bloc, (state) => state.error != null);
    expect(bloc.state.currentStroke, isEmpty);
    expect(bloc.state.elements, isEmpty);
  });

  test('Given an oversized setting, Then strength is clamped', () async {
    final bloc = await _editor();
    bloc.add(const CanvasUpdateStabilizer(1));
    final state = await _until(bloc, (state) => state.stabilizerStrength != 0);
    expect(state.stabilizerStrength, 0.9);
    expect(state.copyWith(stabilizerStrength: 0), isNot(state));
  });
}
