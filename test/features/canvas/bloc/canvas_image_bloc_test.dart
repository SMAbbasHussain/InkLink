import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

ImageElement _image(CanvasState state) =>
    state.elements.whereType<ImageElement>().single;

Future<CanvasBloc> _editor({ImageElement? style}) async {
  final bloc = CanvasBloc();
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
  await _until(bloc, (s) => s.canEdit);
  bloc.add(
    CanvasAddImageElement(
      Uint8List.fromList([1, 2, 3]),
      const Offset(100, 100),
      width: 200,
      height: 100,
      style: style,
    ),
  );
  await _until(bloc, (s) => s.elements.isNotEmpty);
  return bloc;
}

class _Service extends Fake implements CanvasService {
  final committed = StreamController<Uint8List>.broadcast(sync: true);
  int writes = 0;

  @override
  Stream<Board?> watchBoardById(String boardId) => const Stream.empty();

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) =>
      const Stream.empty();

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) =>
      const Stream.empty();

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
  }) async {
    writes++;
    committed.add(payload);
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
    'image style applies all fields without replacing source pixels',
    () async {
      final bloc = await _editor();
      addTearDown(bloc.close);
      final id = _image(bloc.state).id;
      bloc.add(
        CanvasUpdateImageStyle(
          elementId: id,
          flipH: true,
          flipV: true,
          quarterTurns: 1,
          opacity: 0.6,
          borderRadius: 20,
          borderWidth: 3,
          borderColor: const Color(0xFF123456),
          brightness: 0.4,
          contrast: -0.2,
          saturation: -0.8,
        ),
      );
      final state = await _until(bloc, (s) => _image(s).flipV);
      final image = _image(state);
      expect(image.flipped, isTrue);
      expect(image.rotation, closeTo(math.pi / 2, 1e-9));
      expect(image.opacity, 0.6);
      expect(image.borderRadius, 20);
      expect(image.borderWidth, 3);
      expect(image.borderColor, const Color(0xFF123456));
      expect(image.brightness, 0.4);
      expect(image.contrast, -0.2);
      expect(image.saturation, -0.8);
      expect(image.imageBase64, base64Encode([1, 2, 3]));
      expect(CanvasElement.fromMap(id, image.toMap()), image);
    },
  );

  test('crop and reset retain image scale and source', () async {
    final bloc = await _editor();
    addTearDown(bloc.close);
    final original = _image(bloc.state);
    bloc.add(
      CanvasUpdateImageStyle(
        elementId: original.id,
        crop: const Rect.fromLTRB(0.5, 0, 1, 1),
      ),
    );
    final cropped = _image(
      await _until(bloc, (s) => _image(s).crop.width == 0.5),
    );
    expect(cropped.center, const Offset(150, 100));
    expect(cropped.width, 100);
    expect(cropped.imageBase64, original.imageBase64);
    bloc.add(CanvasUpdateImageStyle(elementId: original.id, resetCrop: true));
    expect(
      _image(
        await _until(bloc, (s) => _image(s).crop == ImageElement.fullCrop),
      ),
      original,
    );
  });

  test('reference mode locks, deselects and stays within its band', () async {
    final bloc = await _editor();
    addTearDown(bloc.close);
    final id = _image(bloc.state).id;
    bloc.add(
      const CanvasAddText(
        text: 'Foreground',
        topLeft: Offset.zero,
        color: Colors.black,
      ),
    );
    await _until(bloc, (s) => s.elements.length == 2);
    bloc.add(CanvasSelectElements({id}));
    await _until(bloc, (s) => s.selectedIds.contains(id));
    bloc.add(CanvasUpdateImageStyle(elementId: id, isReference: true));
    final state = await _until(bloc, (s) => _image(s).locked);
    expect(_image(state).isReference, isTrue);
    expect(state.selectedIds, isEmpty);
    expect(canvasPaintOrder(state.elements).bandFor(id)!.elements.first.id, id);
    bloc.add(
      CanvasUpdateImageStyle(elementId: id, isReference: false, brightness: 1),
    );
    final released = _image(await _until(bloc, (s) => !_image(s).locked));
    expect(released.isReference, isFalse);
    expect(released.brightness, 0);
  });

  test(
    'replacement reference locks and moves to the back without crossing bands',
    () async {
      final bloc = await _editor();
      addTearDown(bloc.close);
      final id = _image(bloc.state).id;
      bloc.add(
        const CanvasAddText(
          text: 'Art',
          topLeft: Offset.zero,
          color: Colors.black,
        ),
      );
      await _until(bloc, (s) => s.elements.length == 2);
      bloc.add(
        CanvasReplaceImageElement(
          id,
          Uint8List.fromList([4]),
          style: const ImageElement(
            id: 'preview',
            z: 0,
            center: Offset.zero,
            isReference: true,
          ),
        ),
      );
      final image = _image(await _until(bloc, (s) => _image(s).locked));
      expect(image.isReference, isTrue);
      expect(
        canvasPaintOrder(bloc.state.elements).bandFor(id)!.elements.first.id,
        id,
      );
    },
  );

  test(
    'moving a narrow crop preserves its small dimensions and style',
    () async {
      final bloc = await _editor();
      addTearDown(bloc.close);
      final id = _image(bloc.state).id;
      bloc.add(
        CanvasUpdateImageStyle(
          elementId: id,
          crop: const Rect.fromLTRB(0.9, 0, 1, 1),
          flipV: true,
        ),
      );
      final before = _image(await _until(bloc, (s) => _image(s).flipV));
      bloc.add(
        CanvasUpdateImageElement(
          elementId: id,
          center: Offset.zero,
          width: before.width,
          height: before.height,
        ),
      );
      final after = _image(
        await _until(bloc, (s) => _image(s).center == Offset.zero),
      );
      expect(after.width, closeTo(20, 1e-9));
      expect(after.crop, before.crop);
      expect(after.flipV, isTrue);
    },
  );

  test('clamps style values and resets filters', () async {
    final bloc = await _editor();
    addTearDown(bloc.close);
    final id = _image(bloc.state).id;
    bloc.add(
      CanvasUpdateImageStyle(
        elementId: id,
        opacity: 2,
        borderWidth: -3,
        borderRadius: 999,
        brightness: 3,
        contrast: -5,
        saturation: 7,
      ),
    );
    final image = _image(await _until(bloc, (s) => _image(s).hasFilters));
    expect(image.opacity, 1);
    expect(image.borderWidth, 0);
    expect(image.borderRadius, 360);
    expect(image.brightness, 1);
    expect(image.contrast, -1);
    expect(image.saturation, 1);
    bloc.add(CanvasUpdateImageStyle(elementId: id, resetFilters: true));
    expect(
      _image(await _until(bloc, (s) => !_image(s).hasFilters)).hasFilters,
      isFalse,
    );
  });

  test('replacement preserves the frame and resets crop', () async {
    final bloc = await _editor();
    addTearDown(bloc.close);
    final id = _image(bloc.state).id;
    bloc.add(
      CanvasUpdateImageStyle(
        elementId: id,
        crop: const Rect.fromLTRB(0.5, 0, 1, 1),
        flipV: true,
      ),
    );
    final before = _image(await _until(bloc, (s) => _image(s).flipV));
    bloc.add(CanvasReplaceImageElement(id, Uint8List.fromList([4, 5, 6])));
    final after = _image(
      await _until(bloc, (s) => _image(s).imageBase64 != before.imageBase64),
    );
    expect(after.center, before.center);
    expect(after.width, before.width);
    expect(after.height, before.height);
    expect(after.flipV, isTrue);
    expect(after.crop, ImageElement.fullCrop);
  });

  for (final locked in [false, true]) {
    test(
      '${locked ? 'locked image' : 'viewer'} rejects all image mutations',
      () async {
        final bloc = await _editor();
        addTearDown(bloc.close);
        final id = _image(bloc.state).id;
        if (locked) {
          bloc.add(CanvasSetElementLocked(id, true));
          await _until(bloc, (s) => _image(s).locked);
        } else {
          bloc.add(
            const CanvasBoardTitleUpdated(
              null,
              currentUserRole: Board.roleViewer,
            ),
          );
          await _until(bloc, (s) => !s.canEdit);
        }
        final before = _image(bloc.state);
        bloc.add(
          CanvasUpdateImageStyle(
            elementId: id,
            crop: const Rect.fromLTRB(0, 0, 0.5, 1),
            brightness: 1,
          ),
        );
        bloc.add(CanvasReplaceImageElement(id, Uint8List.fromList([4])));
        bloc.add(
          CanvasUpdateImageElement(
            elementId: id,
            center: Offset.zero,
            width: 80,
            height: 80,
          ),
        );
        bloc.add(const CanvasToggleTray('verification-barrier'));
        await _until(bloc, (s) => s.activeTray == 'verification-barrier');
        expect(_image(bloc.state), before);
      },
    );
  }

  test(
    'pre-insertion styles persist and reference joins the active layer',
    () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);
      bloc.add(const CanvasAddLayer('References'));
      final layerState = await _until(bloc, (s) => s.activeLayerId != null);
      const style = ImageElement(
        id: 'preview',
        z: 0,
        center: Offset.zero,
        crop: Rect.fromLTRB(0.25, 0, 0.75, 1),
        isReference: true,
        flipV: true,
        saturation: -1,
      );
      bloc.add(
        CanvasAddImageElement(
          Uint8List.fromList([1]),
          const Offset(60, 60),
          width: 100,
          height: 100,
          style: style,
        ),
      );
      final state = await _until(
        bloc,
        (s) =>
            s.elements.whereType<LayerElement>().single.elementIds.isNotEmpty,
      );
      final image = _image(state);
      expect(image.id, isNot('preview'));
      expect(image.crop, style.crop);
      expect(image.saturation, -1);
      expect(image.locked, isTrue);
      expect(
        canvasPaintOrder(state.elements).bandFor(image.id)!.layer!.id,
        layerState.activeLayerId,
      );
    },
  );

  test(
    'crop and connector anchor update persist and undo in one transaction',
    () async {
      final adapter = await CanvasCrdtAdapter.create();
      const image = ImageElement(
        id: 'image',
        z: 0,
        center: Offset(100, 100),
        width: 200,
        height: 100,
      );
      const connector = ConnectorElement(
        id: 'connector',
        z: 1,
        startElementId: 'image',
        startAnchor: 'left',
        startPoint: Offset(0, 100),
        endPoint: Offset(300, 100),
        label: 'Link',
      );
      adapter.applyBatch([
        (id: image.id, payload: image.toMap()),
        (id: connector.id, payload: connector.toMap()),
      ], origin: 'remote');
      final service = _Service();
      final bloc = CanvasBloc(
        crdtAdapter: adapter,
        canvasService: service,
        boardId: 'test-board',
      );
      addTearDown(() async {
        await bloc.close();
        await service.committed.close();
      });
      bloc.add(const CanvasInitializeCrdt('test-board'));
      await _until(bloc, (s) => !s.isLoading && s.elements.length == 2);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);
      final write = service.committed.stream.first;
      bloc.add(
        const CanvasUpdateImageStyle(
          elementId: 'image',
          crop: Rect.fromLTRB(0.5, 0, 1, 1),
        ),
      );
      await write;
      expect(service.writes, 1);
      expect(
        (CanvasElement.fromMap('image', adapter.materializeElements()['image']!)
                as ImageElement)
            .crop
            .width,
        0.5,
      );
      expect(
        bloc.state.elements.whereType<ConnectorElement>().single.startPoint,
        const Offset(100, 100),
      );
      bloc.add(const CanvasUndo());
      final undone = await _until(
        bloc,
        (s) => _image(s).crop == ImageElement.fullCrop,
      );
      expect(_image(undone), image);
      expect(
        undone.elements.whereType<ConnectorElement>().single.startPoint,
        connector.startPoint,
      );
    },
  );
}
