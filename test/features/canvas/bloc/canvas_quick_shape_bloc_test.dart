import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/canvas/canvas_shape_type.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/quick_shape.dart';

Future<CanvasState> _until(
  CanvasBloc bloc,
  bool Function(CanvasState) predicate,
) => bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));

class _Service extends Fake implements CanvasService {
  final writes = StreamController<Uint8List>.broadcast(sync: true);
  int count = 0;

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
  }) async {
    count++;
    writes.add(payload);
  }
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
  test('Given a viewer, Then a QuickShape commit is rejected', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(
      const CanvasCommitQuickShape(
        match: QuickShapeMatch(
          shapeType: CanvasShapeType.rectangle,
          center: Offset(10, 10),
          width: 100,
          height: 50,
        ),
        points: [Offset.zero],
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.elements, isEmpty);
  });

  test('Given an editor, Then a held stroke becomes one selected shape',
      () async {
    final (:bloc, :service) = await _editor();
    const match = QuickShapeMatch(
      shapeType: CanvasShapeType.ellipse,
      center: Offset(100, 80),
      width: 200,
      height: 120,
    );

    bloc.add(
      const CanvasCommitQuickShape(
        match: match,
        points: [Offset.zero, Offset(10, 10)],
        pressures: [0.5, 0.8],
        tilts: [0, 0.4],
      ),
    );
    final state = await _until(bloc, (state) => state.elements.length == 1);
    final shape = state.elements.single as ShapeElement;

    expect(shape.shapeType, CanvasShapeType.ellipse);
    expect(shape.center, const Offset(100, 80));
    expect(shape.width, 200);
    expect(shape.height, 120);
    expect(shape.size, 200);
    expect(state.selectedIds, {shape.id});
    expect(state.currentStroke, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(service.count, 1, reason: 'one undoable create');
    expect(bloc.state.infoMessage, contains('Snapped'));
  });

  test('Given the QuickShape toggle, Then editors can turn it off', () async {
    final (:bloc, service: _) = await _editor();
    expect(bloc.state.quickShapeEnabled, isTrue);

    bloc.add(const CanvasSetQuickShapeEnabled(false));
    await _until(bloc, (state) => !state.quickShapeEnabled);
    expect(bloc.state.quickShapeEnabled, isFalse);
  });

  test('Given a viewer, Then the QuickShape toggle is rejected', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(const CanvasSetQuickShapeEnabled(false));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.quickShapeEnabled, isTrue);
  });
}
