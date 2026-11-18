import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/board_template.dart';

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
    String action = 'upsert',
  }) async {
    count++;
    writes.add(payload);
  }
}

Future<({CanvasBloc bloc, _Service service})> _editorBoard() async {
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
  final flow = canvasTemplates.firstWhere((template) => template.id == 'flow');

  test('Given a viewer, Then a template import is rejected', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(CanvasImportElements(flow.elements));

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.elements, isEmpty);
  });

  test('Given a flow template, Then ids are fresh, connectors remap and the '
      'offset applies', () async {
    final (:bloc, :service) = await _editorBoard();

    bloc.add(
      CanvasImportElements(flow.elements, offset: const Offset(1000, 500)),
    );
    final state = await _until(bloc, (state) => state.elements.length == 9);

    final shapes = state.elements.whereType<ShapeElement>().toList();
    final connectors = state.elements.whereType<ConnectorElement>().toList();
    expect(shapes.length, 3);
    expect(connectors.length, 2);
    expect(shapes.map((shape) => shape.id), isNot(contains('start')));
    expect(
      shapes.map((shape) => shape.id).toSet(),
      hasLength(3),
      reason: 'fresh ids must not collide',
    );
    expect(
      shapes.map((shape) => shape.center.dx),
      containsAll(<double>[660, 1000, 1340]),
    );
    expect(connectors[0].startElementId, shapes[0].id);
    expect(connectors[0].endElementId, shapes[1].id);
    expect(connectors[1].startElementId, shapes[1].id);
    expect(connectors[1].endElementId, shapes[2].id);
    expect(state.selectedIds, state.elements.map((e) => e.id).toSet());
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(service.count, 1, reason: 'one undoable batch');
    expect(bloc.state.infoMessage, contains('Imported 9 elements'));
  });

  test('Given existing art, Then an imported frame lands behind it while the '
      'notes stay on top', () async {
    final (:bloc, service: _) = await _editorBoard();
    final first = canvasTemplates.firstWhere(
      (template) => template.id == 'brainstorm',
    );

    bloc.add(CanvasImportElements(first.elements));
    final state = await _until(bloc, (state) => state.elements.length == 9);

    final frame = state.elements.whereType<FrameElement>().single;
    expect(frame.z, lessThan(0));
    for (final note in state.elements.whereType<StickyNoteElement>()) {
      expect(note.z, greaterThan(frame.z));
    }
  });

  test('Given a malformed payload, Then nothing is imported', () async {
    final (:bloc, :service) = await _editorBoard();

    bloc.add(
      const CanvasImportElements([
        {'id': 'good', 'type': 'sticky_note', 'cx': 0, 'cy': 0},
        {'id': 'bad', 'type': 'not-real', 'cx': 0, 'cy': 0},
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(bloc.state.elements, isEmpty);
    expect(service.count, 0);
    expect(bloc.state.infoMessage, contains('unsupported element'));
  });

  test('Given duplicate placeholders, Then nothing is imported', () async {
    final (:bloc, :service) = await _editorBoard();

    bloc.add(
      const CanvasImportElements([
        {'id': 'same', 'type': 'sticky_note', 'cx': 0, 'cy': 0},
        {'id': 'same', 'type': 'sticky_note', 'cx': 20, 'cy': 20},
      ]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(bloc.state.elements, isEmpty);
    expect(service.count, 0);
  });

  test(
    'Given two imports of the same template, Then ids stay unique',
    () async {
      final (:bloc, service: _) = await _editorBoard();

      bloc.add(CanvasImportElements(flow.elements));
      await _until(bloc, (state) => state.elements.length == 9);
      bloc.add(CanvasImportElements(flow.elements));
      final state = await _until(bloc, (state) => state.elements.length == 18);

      expect(
        state.elements.map((element) => element.id).toSet(),
        hasLength(18),
      );
    },
  );

  test('Given an empty payload list, Then the board does not change', () async {
    final (:bloc, :service) = await _editorBoard();

    bloc.add(const CanvasImportElements([]));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.elements, isEmpty);
    expect(service.count, 0);
  });
}
