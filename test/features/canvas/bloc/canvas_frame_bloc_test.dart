import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';

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
    'Given a selected frame, Then moving it leaves unattached overlapping art in place',
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

  test(
    'Given a frame, Then capturing background elements attaches them and moves them with the frame',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      // Capture elements within frame bounds ('inside' is at (300,300), 'outside' is at (900,900)).
      bloc.add(const CanvasCaptureElementsInFrame('frame'));
      final captured = await _until(
        bloc,
        (state) =>
            state.elements.firstWhere((e) => e.id == 'inside').frameId ==
            'frame',
      );
      expect(
        captured.elements.firstWhere((e) => e.id == 'outside').frameId,
        isNull,
      );

      // Moving the frame now moves 'inside' with it, leaving 'outside' in place.
      bloc.add(const CanvasSelectShape('frame'));
      await _until(bloc, (state) => state.selectedShapeId == 'frame');
      bloc.add(const CanvasMoveSelectedShape(Offset(350, 340)));
      final moved = await _until(
        bloc,
        (state) =>
            (state.elements.firstWhere((e) => e.id == 'frame') as FrameElement)
                .center ==
            const Offset(350, 340),
      );
      expect(
        (moved.elements.firstWhere((e) => e.id == 'inside')
                as StickyNoteElement)
            .center,
        const Offset(350, 340),
      );
      expect(
        (moved.elements.firstWhere((e) => e.id == 'outside')
                as StickyNoteElement)
            .center,
        const Offset(900, 900),
      );
    },
  );

  test(
    'Given an element dragged onto and off a frame, Then frameId attaches and detaches',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      // Drag 'outside' (900,900) onto 'frame' (center 300,300).
      bloc.add(const CanvasSelectShape('outside'));
      await _until(bloc, (state) => state.selectedShapeId == 'outside');
      bloc.add(const CanvasMoveSelectedShape(Offset(260, 260)));
      final attached = await _until(
        bloc,
        (state) =>
            state.elements.firstWhere((e) => e.id == 'outside').frameId ==
            'frame',
      );
      expect(
        attached.elements.firstWhere((e) => e.id == 'outside').frameId,
        'frame',
      );

      // Drag 'outside' halfway off 'frame' (frame right edge is 500; sticky width is 160 so center 540 puts [460..620] overlapping):
      // it must stay attached until the whole element is outside.
      bloc.add(const CanvasMoveSelectedShape(Offset(540, 260)));
      final halfway = await _until(
        bloc,
        (state) =>
            (state.elements.firstWhere((e) => e.id == 'outside')
                    as StickyNoteElement)
                .center ==
            const Offset(540, 260),
      );
      expect(
        halfway.elements.firstWhere((e) => e.id == 'outside').frameId,
        'frame',
      );

      // Drag 'outside' back outside the frame.
      bloc.add(const CanvasMoveSelectedShape(Offset(950, 950)));
      final detached = await _until(
        bloc,
        (state) =>
            state.elements.firstWhere((e) => e.id == 'outside').frameId == null,
      );
      expect(
        detached.elements.firstWhere((e) => e.id == 'outside').frameId,
        isNull,
      );
    },
  );

  test(
    'Given frame draw tool, Then dragging creates a frame with custom bounds and cornerRadius defaults to 0',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      bloc.add(const CanvasSetToolMode(CanvasToolMode.frame));
      bloc.add(const CanvasStartShapeDraw(Offset(100, 100)));
      bloc.add(const CanvasUpdateShapeDraw(Offset(500, 350)));
      bloc.add(const CanvasEndShapeDraw());

      final state = await _until(
        bloc,
        (state) => state.elements.whereType<FrameElement>().length == 2,
      );
      final created = state.elements.whereType<FrameElement>().firstWhere(
        (e) => e.id != 'frame',
      );
      expect(created.center, const Offset(300, 225));
      expect(created.width, 400);
      expect(created.height, 250);
      expect(created.cornerRadius, 0);
      expect(state.currentToolMode, CanvasToolMode.select);
    },
  );

  test(
    'Given a frame, Then newly created elements inside it attach and move with the frame',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      bloc.add(
        const CanvasAddStickyNote(
          center: Offset(260, 260),
          text: 'Created on frame',
        ),
      );
      final added = await _until(
        bloc,
        (state) => state.elements.whereType<StickyNoteElement>().any(
          (e) => e.text == 'Created on frame',
        ),
      );
      final note = added.elements.whereType<StickyNoteElement>().firstWhere(
        (e) => e.text == 'Created on frame',
      );
      expect(note.frameId, 'frame');

      // Moving the frame moves the newly created note along with it.
      bloc.add(const CanvasSelectShape('frame'));
      await _until(bloc, (state) => state.selectedShapeId == 'frame');
      bloc.add(const CanvasMoveSelectedShape(Offset(350, 340)));
      final moved = await _until(
        bloc,
        (state) =>
            (state.elements.firstWhere((e) => e.id == 'frame') as FrameElement)
                .center ==
            const Offset(350, 340),
      );
      final movedNote =
          moved.elements.firstWhere((e) => e.id == note.id)
              as StickyNoteElement;
      expect(movedNote.center, const Offset(310, 300));
    },
  );

  test(
    'Given a clipping frame, When drawing a huge circle around it or line across it, Then stroke is not swallowed by the frame',
    () async {
      final (:bloc, service: _) = await _boardWithContents();

      if (bloc.state.currentToolMode != CanvasToolMode.doodle) {
        bloc.add(const CanvasSetToolMode(CanvasToolMode.doodle));
        await _until(bloc, (s) => s.currentToolMode == CanvasToolMode.doodle);
      }

      // Draw a huge circle around the frame (center 300,300, radius 2500).
      const center = Offset(300, 300);
      const radius = 2500.0;
      bloc.add(CanvasStartStroke(center + const Offset(radius, 0)));
      for (var i = 1; i <= 48; i++) {
        final theta = (i / 48) * 2 * math.pi;
        bloc.add(
          CanvasAppendStroke(
            center + Offset(math.cos(theta) * radius, math.sin(theta) * radius),
          ),
        );
      }
      bloc.add(const CanvasEndStroke());

      final afterCircle = await _until(
        bloc,
        (s) => s.elements.whereType<StrokeElement>().isNotEmpty,
      );
      final circle = afterCircle.elements.whereType<StrokeElement>().single;
      expect(circle.frameId, isNull);

      // Draw a stroke starting inside the frame: it SHOULD still attach.
      bloc.add(const CanvasStartStroke(Offset(250, 250)));
      bloc.add(const CanvasAppendStroke(Offset(320, 320)));
      bloc.add(const CanvasEndStroke());

      final afterInside = await _until(
        bloc,
        (s) => s.elements.whereType<StrokeElement>().length == 2,
      );
      final insideStroke = afterInside.elements
          .whereType<StrokeElement>()
          .firstWhere((e) => e.id != circle.id);
      expect(insideStroke.frameId, 'frame');
    },
  );
}
