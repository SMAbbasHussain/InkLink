import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';

Future<CanvasState> _until(
  CanvasBloc bloc,
  bool Function(CanvasState) predicate,
) => bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));
Future<CanvasBloc> _editor() async {
  final bloc = CanvasBloc();
  addTearDown(bloc.close);
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
  await _until(bloc, (s) => s.canEdit);
  bloc.add(const CanvasAddStickyNote(center: Offset(100, 100), text: 'Idea'));
  await _until(bloc, (s) => s.elements.isNotEmpty);
  return bloc;
}

StickyNoteElement _note(CanvasState state) =>
    state.elements.whereType<StickyNoteElement>().single;

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

void main() {
  test(
    'Given text edit, Then auto-height grows and manual resize disables it',
    () async {
      final bloc = await _editor();
      final id = _note(bloc.state).id;
      bloc.add(
        CanvasUpdateStickyNote(
          elementId: id,
          text: List.filled(30, 'idea').join(' '),
          fontSize: 24,
          fontWeight: 700,
          textAlign: 'right',
          textColor: const Color(0xFF123456),
        ),
      );
      final styled = _note(await _until(bloc, (s) => _note(s).fontSize == 24));
      expect(styled.height, greaterThan(160));
      expect(styled.fontWeight, 700);
      expect(styled.textAlign, 'right');
      expect(styled.textColor, const Color(0xFF123456));
      bloc.add(CanvasUpdateStickyNote(elementId: id, height: 100));
      await _until(bloc, (s) => !_note(s).autoSize);
      bloc.add(
        CanvasUpdateStickyNote(
          elementId: id,
          text: List.filled(100, 'long').join(' '),
        ),
      );
      final manual = _note(
        await _until(bloc, (s) => _note(s).text.startsWith('long')),
      );
      expect(manual.height, 100);
      bloc.add(CanvasUpdateStickyNote(elementId: id, autoSize: true));
      expect(_note(await _until(bloc, (s) => _note(s).autoSize)).height, 480);
    },
  );

  test(
    'Given styled note, Then duplicate keeps content and metadata with a new id',
    () async {
      final bloc = await _editor();
      final id = _note(bloc.state).id;
      bloc.add(
        CanvasUpdateStickyNote(
          elementId: id,
          fontSize: 22,
          fontWeight: 700,
          textAlign: 'center',
        ),
      );
      final source = _note(await _until(bloc, (s) => _note(s).fontSize == 22));
      bloc.add(CanvasDuplicateElements({id}));
      final state = await _until(bloc, (s) => s.elements.length == 2);
      final copy = state.elements.whereType<StickyNoteElement>().firstWhere(
        (n) => n.id != id,
      );
      expect(copy.text, source.text);
      expect(copy.fontSize, 22);
      expect(copy.fontWeight, 700);
      expect(copy.textAlign, 'center');
      expect(copy.center, isNot(source.center));
    },
  );

  for (final toShape in [false, true]) {
    test(
      'Given attached note, Then conversion to ${toShape ? 'shape' : 'text'} preserves topology and undoes in one transaction',
      () async {
        final adapter = await CanvasCrdtAdapter.create();
        const note = StickyNoteElement(
          id: 'note',
          z: 2,
          center: Offset(100, 100),
          text: 'Keep me',
          fontSize: 22,
          fontWeight: 700,
          textAlign: 'right',
          rotation: 0.2,
          autoSize: true,
          authorUid: 'author',
        );
        const connector = ConnectorElement(
          id: 'link',
          z: 3,
          startElementId: 'note',
          startAnchor: 'left',
          startPoint: Offset(20, 100),
          endPoint: Offset(300, 100),
          label: 'Link',
        );
        const layer = LayerElement(
          id: 'layer',
          z: 0,
          name: 'Ideas',
          elementIds: ['note', 'link'],
        );
        adapter.applyBatch([
          for (final e in [note, connector, layer])
            (id: e.id, payload: e.toMap()),
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
        await _until(bloc, (s) => !s.isLoading && s.elements.length == 3);
        expect(_note(bloc.state), note);
        bloc.add(
          const CanvasBoardTitleUpdated(
            null,
            currentUserRole: Board.roleEditor,
          ),
        );
        await _until(bloc, (s) => s.canEdit);
        final write = service.writes.stream.first;
        bloc.add(CanvasConvertStickyNote('note', toShape: toShape));
        await write.timeout(const Duration(seconds: 3));
        expect(service.count, 1);
        final converted = bloc.state.elements.firstWhere((e) => e.id == 'note');
        expect(converted, toShape ? isA<ShapeElement>() : isA<TextElement>());
        expect(converted.toMap()[toShape ? 'label' : 'text'], note.text);
        expect(converted.toMap()[toShape ? 'labelFontSize' : 'fontSize'], 22);
        expect(converted.z, note.z);
        expect(
          bloc.state.elements.whereType<LayerElement>().single.elementIds,
          contains('note'),
        );
        final link = bloc.state.elements.whereType<ConnectorElement>().single;
        expect(link.startElementId, 'note');
        expect(link.label, 'Link');
        expect(
          link.startPoint,
          resolveConnectorEndpoints(link, {'note': converted}).$1,
        );
        bloc.add(const CanvasUndo());
        final undone = await _until(
          bloc,
          (s) => s.elements.any((e) => e is StickyNoteElement),
        );
        expect(_note(undone), note);
        expect(adapter.canUndo, isFalse);
      },
    );
  }

  for (final locked in [false, true]) {
    test(
      'Given ${locked ? 'locked note' : 'viewer'}, Then styling and conversion are rejected',
      () async {
        final bloc = await _editor();
        final id = _note(bloc.state).id;
        if (locked) {
          bloc.add(CanvasSetElementLocked(id, true));
          await _until(bloc, (s) => _note(s).locked);
        } else {
          bloc.add(
            const CanvasBoardTitleUpdated(
              null,
              currentUserRole: Board.roleViewer,
            ),
          );
          await _until(bloc, (s) => !s.canEdit);
        }
        final before = _note(bloc.state);
        bloc.add(
          CanvasUpdateStickyNote(elementId: id, text: 'changed', fontSize: 60),
        );
        bloc.add(CanvasConvertStickyNote(id));
        bloc.add(const CanvasToggleTray('barrier'));
        await _until(bloc, (s) => s.activeTray == 'barrier');
        expect(_note(bloc.state), before);
      },
    );
  }
}
