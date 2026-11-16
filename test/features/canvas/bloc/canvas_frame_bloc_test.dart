import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

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

Future<({CanvasBloc bloc, _Service service})> _boardWithContents() async {
  final adapter = await CanvasCrdtAdapter.create();
  const frame = FrameElement(
    id: 'frame',
    z: 0,
    center: Offset(300, 300),
    width: 400,
    height: 300,
    title: 'Section',
  );
  const inside = StickyNoteElement(
    id: 'inside',
    z: 1,
    center: Offset(300, 300),
    text: 'Inside',
  );
  const outside = StickyNoteElement(
    id: 'outside',
    z: 2,
    center: Offset(900, 900),
    text: 'Outside',
  );
  adapter.applyBatch([
    for (final element in [frame, inside, outside])
      (id: element.id, payload: element.toMap()),
  ], origin: 'remote');
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
  await _until(bloc, (state) => !state.isLoading && state.elements.length == 3);
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
  await _until(bloc, (state) => state.canEdit);
  return (bloc: bloc, service: service);
}

void main() {
  test('Given a viewer, Then adding a frame is rejected', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    bloc.add(const CanvasAddFrame(center: Offset(100, 100)));

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.elements, isEmpty);
  });

  test(
    'Given an editor, Then a frame lands behind the art and is selected',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      bloc.add(
        const CanvasAddFrame(center: Offset(100, 100), title: 'New section'),
      );
      final state = await _until(
        bloc,
        (state) => state.elements.whereType<FrameElement>().length == 2,
      );
      final frame = state.elements.whereType<FrameElement>().firstWhere(
        (element) => element.title == 'New section',
      );

      expect(frame.width, FrameElement.defaultWidth);
      expect(frame.height, FrameElement.defaultHeight);
      expect(frame.z, lessThan(0));
      expect(bloc.state.selectedShapeId, frame.id);
      expect(bloc.state.selectedIds, {frame.id});
    },
  );

  test(
    'Given a frame, Then title and colour updates persist and clamp',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      bloc.add(
        const CanvasUpdateFrame(
          elementId: 'frame',
          title: 'Renamed',
          color: Color(0xFF2563EB),
          width: 10,
          height: 10,
        ),
      );
      final state = await _until(
        bloc,
        (state) =>
            (state.elements.firstWhere((e) => e.id == 'frame') as FrameElement)
                .title ==
            'Renamed',
      );
      final frame =
          state.elements.firstWhere((e) => e.id == 'frame') as FrameElement;

      expect(frame.title, 'Renamed');
      expect(frame.color, const Color(0xFF2563EB));
      expect(frame.width, 120);
      expect(frame.height, 80);
      expect(frame.z, 0);
    },
  );

  test(
    'Given a selected frame, Then moving it leaves overlapping art in place',
    () async {
      final (:bloc, :service) = await _boardWithContents();

      bloc.add(const CanvasSelectShape('frame'));
      await _until(bloc, (state) => state.selectedShapeId == 'frame');

      final write = service.writes.stream.first;
      bloc.add(const CanvasMoveSelectedShape(Offset(340, 320)));
      await write.timeout(const Duration(seconds: 3));
      final moved = await _until(
        bloc,
        (state) =>
            (state.elements.firstWhere((e) => e.id == 'frame') as FrameElement)
                .center ==
            const Offset(340, 320),
      );

      expect(service.count, 1, reason: 'one frame update');
      expect(
        (moved.elements.firstWhere((e) => e.id == 'inside')
                as StickyNoteElement)
            .center,
        const Offset(300, 300),
      );
      expect(
        (moved.elements.firstWhere((e) => e.id == 'outside')
                as StickyNoteElement)
            .center,
        const Offset(900, 900),
      );
    },
  );

  test('Given a frame, Then duplicating it clones contained elements with new '
      'ids and leaves partially outside art alone', () async {
    final (:bloc, service: _) = await _boardWithContents();

    bloc.add(const CanvasDuplicateElements({'frame'}));
    final state = await _until(
      bloc,
      (state) =>
          state.elements.whereType<FrameElement>().length == 2 &&
          state.elements.whereType<StickyNoteElement>().length == 3,
    );

    final frames = state.elements.whereType<FrameElement>().toList();
    final clone = frames.firstWhere((element) => element.id != 'frame');
    expect(clone.center, const Offset(316, 316));
    expect(clone.title, 'Section');
    expect(clone.z, lessThan(0), reason: 'cloned frames stay behind the art');

    final stickies = state.elements.whereType<StickyNoteElement>();
    expect(stickies.any((note) => note.id == 'inside'), isTrue);
    expect(stickies.any((note) => note.id == 'outside'), isTrue);
    expect(
      stickies.where((note) => note.center == const Offset(316, 316)).length,
      1,
      reason: 'only the contained note is cloned',
    );
  });

  test('Given a frame, Then deleting it keeps the contents', () async {
    final (:bloc, service: _) = await _boardWithContents();

    bloc.add(const CanvasDeleteElement('frame'));
    final state = await _until(
      bloc,
      (state) => state.elements.whereType<FrameElement>().isEmpty,
    );

    expect(state.elements.whereType<StickyNoteElement>().length, 2);
  });
}
