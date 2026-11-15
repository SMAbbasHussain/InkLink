import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

void _grantEditor(CanvasBloc bloc) {
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
}

Future<CanvasState> _nextWhere(
  CanvasBloc bloc,
  bool Function(CanvasState state) predicate,
) {
  return bloc.stream.firstWhere(predicate).timeout(
    const Duration(seconds: 2),
  );
}

Future<(CanvasBloc, List<ShapeElement>)> _threeShapes() async {
  final bloc = CanvasBloc();
  _grantEditor(bloc);
  for (final center in const [Offset(0, 0), Offset(200, 0), Offset(400, 0)]) {
    bloc.add(CanvasAddShape(CanvasShapeType.square, center));
  }
  final state = await _nextWhere(bloc, (s) => s.elements.length == 3);
  return (bloc, state.elements.cast<ShapeElement>().toList());
}

Future<LayerElement> _addLayer(CanvasBloc bloc, String name) async {
  final count = bloc.state.elements.whereType<LayerElement>().length;
  bloc.add(CanvasAddLayer(name));
  final state = await _nextWhere(
    bloc,
    (s) => s.elements.whereType<LayerElement>().length == count + 1,
  );
  return state.elements.whereType<LayerElement>().last;
}

LayerElement _layerById(CanvasState state, String id) =>
    state.elements.whereType<LayerElement>().firstWhere((lay) => lay.id == id);

void main() {
  group('element metadata', () {
    test('legacy payloads default to visible, unlocked and opaque', () {
      final element = CanvasElement.fromMap('a', {
        'type': 'shape',
        'z': 0,
        'shapeType': 'square',
        'cx': 10.0,
        'cy': 20.0,
        'size': 40.0,
        'color': 0xFF000000,
        'strokeWidth': 2.0,
      });
      expect(element.hidden, isFalse);
      expect(element.locked, isFalse);
      expect(element.opacity, 1.0);
    });

    test('round-trips layer fields through the payload', () {
      const original = TextElement(
        id: 't1',
        z: 4,
        text: 'hi',
        center: Offset(5, 6),
        color: Colors.black,
        hidden: true,
        locked: true,
        opacity: 0.35,
      );
      final restored = CanvasElement.fromMap('t1', original.toMap());
      expect(restored, original);
      expect(restored.hidden, isTrue);
      expect(restored.locked, isTrue);
      expect(restored.opacity, 0.35);
    });
  });

  group('layers panel actions', () {
    test('hiding an element removes it from the selection and marquee',
        () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final target = shapes.first;
      bloc.add(CanvasSelectElements({target.id, shapes[1].id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      bloc.add(CanvasSetElementVisibility(target.id, false));
      final state = await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == target.id).hidden,
      );
      expect(state.selectedIds, {shapes[1].id});
      expect(state.selectedShapeId, shapes[1].id);

      bloc.add(const CanvasSelectInRect(Rect.fromLTRB(-100, -100, 900, 100)));
      final after = await _nextWhere(
        bloc,
        (s) => s.selectedIds.length == 2 && !s.selectedIds.contains(target.id),
      );
      expect(after.selectedIds.contains(shapes[2].id), isTrue);
    });

    test('locked elements cannot be selected or deleted', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final target = shapes.first;
      bloc.add(CanvasSetElementLocked(target.id, true));
      await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == target.id).locked,
      );

      bloc.add(CanvasSelectShape(target.id));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.selectedIds, isEmpty);

      bloc.add(CanvasDeleteElements({target.id}));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.elements.any((e) => e.id == target.id), isTrue);
    });

    test('opacity is clamped and persisted on the element', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final target = shapes.first;

      bloc.add(CanvasSetElementOpacity(target.id, 0.4));
      final state = await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == target.id).opacity == 0.4,
      );
      expect(state.canEdit, isTrue);

      bloc.add(CanvasSetElementOpacity(target.id, 4.0));
      final clamped = await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == target.id).opacity == 1.0,
      );
      expect(
        clamped.elements.firstWhere((e) => e.id == target.id).opacity,
        1.0,
      );
    });

    test('viewers cannot change layer state', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final target = shapes.first;
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleViewer);

      bloc.add(CanvasSetElementVisibility(target.id, false));
      bloc.add(CanvasSetElementOpacity(target.id, 0.2));
      await _nextWhere(bloc, (s) => s.error != null);
      final element = bloc.state.elements.firstWhere((e) => e.id == target.id);
      expect(element.hidden, isFalse);
      expect(element.opacity, 1.0);
    });
  });

  group('reorder', () {
    test('moves an element to the requested paint index and renumbers z',
        () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final top = shapes.reduce((a, b) => a.z > b.z ? a : b);

      bloc.add(CanvasReorderElement(top.id, 0));
      final state = await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == top.id).z == 0,
      );
      final ordered = List<CanvasElement>.from(state.elements)
        ..sort((a, b) => a.z.compareTo(b.z));
      expect(ordered.map((e) => e.id), [
        top.id,
        for (final shape in shapes)
          if (shape.id != top.id) shape.id,
      ]);
      expect(ordered.map((e) => e.z), [0, 1, 2]);
    });

    test('a locked element cannot be reordered', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final top = shapes.reduce((a, b) => a.z > b.z ? a : b);
      bloc.add(CanvasSetElementLocked(top.id, true));
      await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == top.id).locked,
      );

      bloc.add(CanvasReorderElement(top.id, 0));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        bloc.state.elements.firstWhere((e) => e.id == top.id).z,
        top.z,
      );
    });
  });

  group('named layers', () {
    test('adds a layer, names it and makes it the active target', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);

      bloc.add(const CanvasAddLayer('Sketch'));
      final state = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isNotEmpty,
      );

      final layer = state.elements.whereType<LayerElement>().single;
      expect(layer.name, 'Sketch');
      expect(layer.elementIds, isEmpty);
      expect(state.activeLayerId, layer.id);
      expect(state.infoMessage, contains('Sketch'));
      expect(state.infoMessageUndoable, isFalse);
    });

    test('renames a layer without disturbing its membership', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(const CanvasAddLayer('Layer 1'));
      final added = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isNotEmpty,
      );
      final layerId = added.elements.whereType<LayerElement>().single.id;

      bloc.add(CanvasRenameLayer(layerId, 'Ink'));
      final renamed = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().single.name == 'Ink',
      );
      expect(renamed.elements.whereType<LayerElement>().single.id, layerId);
    });

    test('switches the active layer and rejects unknown ids', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(const CanvasAddLayer('Layer 1'));
      final first = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isNotEmpty,
      );
      final firstId = first.activeLayerId!;

      bloc.add(const CanvasAddLayer('Layer 2'));
      final second = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().length == 2,
      );
      expect(second.activeLayerId, isNot(firstId));

      bloc.add(const CanvasSetActiveLayer(null));
      final cleared = await _nextWhere(bloc, (s) => s.activeLayerId == null);
      expect(cleared.activeLayerId, isNull);

      bloc.add(CanvasSetActiveLayer(firstId));
      final switched = await _nextWhere(bloc, (s) => s.activeLayerId == firstId);
      expect(switched.activeLayerId, firstId);

      bloc.add(const CanvasSetActiveLayer('missing'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeLayerId, firstId);
    });

    test('deleting a layer keeps its elements on the board', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      bloc.add(const CanvasAddLayer('Scratch'));
      final added = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isNotEmpty,
      );
      final layerId = added.activeLayerId!;

      bloc.add(CanvasDeleteLayer(layerId));
      final after = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isEmpty,
      );
      expect(after.elements.whereType<ShapeElement>().length, shapes.length);
      expect(after.activeLayerId, isNull);
      expect(after.infoMessage, contains('stay on the board'));
    });

    test('round-trips layer names and membership through the payload', () {
      const original = LayerElement(
        id: 'layer-1',
        z: 7,
        name: 'Background',
        elementIds: ['a', 'b'],
      );
      final restored = CanvasElement.fromMap('layer-1', original.toMap());
      expect(restored, original);
      expect((restored as LayerElement).name, 'Background');
      expect(restored.elementIds, ['a', 'b']);
      expect(restored.z, 7);
    });
  });

  group('layers as paint bands', () {
    test('moves an element between layers without touching its z', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final shape = shapes.first;
      final a = await _addLayer(bloc, 'A');
      final b = await _addLayer(bloc, 'B');

      bloc.add(CanvasMoveElementToLayer(shape.id, a.id));
      var state = await _nextWhere(
        bloc,
        (s) => s.infoMessage == 'Moved to A · Undo to revert',
      );
      expect(_layerById(state, a.id).elementIds, [shape.id]);
      expect(_layerById(state, b.id).elementIds, isEmpty);
      expect(
        state.elements.firstWhere((e) => e.id == shape.id).z,
        shape.z,
      );
      expect(state.infoMessage, contains('Moved to A'));

      bloc.add(CanvasMoveElementToLayer(shape.id, b.id));
      state = await _nextWhere(
        bloc,
        (s) => s.infoMessage == 'Moved to B · Undo to revert',
      );
      expect(_layerById(state, a.id).elementIds, isEmpty);
      expect(_layerById(state, b.id).elementIds, [shape.id]);
      expect(
        state.elements.firstWhere((e) => e.id == shape.id).z,
        shape.z,
      );
    });

    test('moving to Default removes the element from every layer', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final shape = shapes.first;
      final a = await _addLayer(bloc, 'A');
      final b = await _addLayer(bloc, 'B');
      bloc.add(CanvasMoveElementToLayer(shape.id, a.id));
      await _nextWhere(
        bloc,
        (s) => s.infoMessage == 'Moved to A · Undo to revert',
      );

      bloc.add(CanvasMoveElementToLayer(shape.id, null));
      final state = await _nextWhere(
        bloc,
        (s) => s.infoMessage == 'Moved to Default · Undo to revert',
      );
      expect(_layerById(state, b.id).elementIds, isEmpty);
      expect(state.infoMessage, contains('Moved to Default'));

      // The element falls back into the bottom Default band.
      final band = canvasPaintOrder(state.elements).bandFor(shape.id);
      expect(band?.layer, isNull);
    });

    test('reorders layer bands and renumbers layer z densely', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);
      final a = await _addLayer(bloc, 'A');
      final b = await _addLayer(bloc, 'B');
      final c = await _addLayer(bloc, 'C');

      bloc.add(CanvasReorderLayer(a.id, 2));
      final state = await _nextWhere(
        bloc,
        (s) => _layerById(s, a.id).z == 2,
      );

      final layers = state.elements.whereType<LayerElement>().toList()
        ..sort((l, r) => l.z.compareTo(r.z));
      expect(layers.map((layer) => layer.id), [b.id, c.id, a.id]);
      expect(layers.map((layer) => layer.z), [0, 1, 2]);
      expect(
        canvasPaintOrder(state.elements)
            .bands
            .map((band) => band.layer?.id),
        [null, b.id, c.id, a.id],
      );
    });

    test('element reorder stays inside its own band', () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final a = await _addLayer(bloc, 'A');
      final b = await _addLayer(bloc, 'B');
      final first = shapes[0];
      final second = shapes[1];
      final third = shapes[2];
      bloc.add(CanvasMoveElementToLayer(first.id, a.id));
      bloc.add(CanvasMoveElementToLayer(second.id, a.id));
      bloc.add(CanvasMoveElementToLayer(third.id, b.id));
      await _nextWhere(
        bloc,
        (s) => _layerById(s, a.id).elementIds.length == 2,
      );

      // Put `first` on top of the A band; z 0/1 are rewritten, third's z 2
      // and every other band stay untouched.
      bloc.add(CanvasReorderElement(first.id, 1));
      final state = await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == first.id).z == 1,
      );

      expect(state.elements.firstWhere((e) => e.id == second.id).z, 0);
      expect(state.elements.firstWhere((e) => e.id == third.id).z, 2);
      final band = canvasPaintOrder(state.elements).bandFor(first.id);
      expect(band?.layer?.id, a.id);
      expect(band!.elements.map((e) => e.id), [second.id, first.id]);
      expect(
        canvasPaintOrder(state.elements).bandFor(third.id)?.layer?.id,
        b.id,
      );
    });

    test('CRDT rebuild restores layers and element metadata', () async {
      final source = await CanvasCrdtAdapter.create();
      source.upsertElement('shape-1', const {
        'type': 'shape',
        'z': 0,
        'shapeType': 'square',
        'cx': 10.0,
        'cy': 20.0,
        'size': 40.0,
        'color': 0xFF112233,
        'strokeWidth': 3.0,
        'rotation': 0.5,
        'hidden': true,
        'locked': true,
        'opacity': 0.4,
      });
      source.upsertElement('image-1', const {
        'type': 'image',
        'z': 1,
        'cx': 80.0,
        'cy': 80.0,
        'width': 120.0,
        'height': 90.0,
        'imageBase64': '',
        'rotation': 1.25,
        'flipped': true,
      });
      source.upsertElement('layer-1', const {
        'type': 'layer',
        'z': 3,
        'name': 'Ink',
        'elementIds': ['shape-1'],
        'hidden': false,
        'locked': false,
        'opacity': 1.0,
      });

      final bloc = CanvasBloc(crdtAdapter: await CanvasCrdtAdapter.create());
      addTearDown(bloc.close);
      _grantEditor(bloc);
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);

      final update = LocalCrdtUpdate()
        ..updateId = 'remote-1'
        ..boardId = 'board'
        ..elementId = null
        ..payloadBase64 = base64Encode(source.encodeStateUpdate())
        ..sourceClientId = 'peer'
        ..appliedAt = DateTime.utc(2026, 1, 1);
      bloc.add(CanvasApplyRemoteUpdate([update]));

      final state = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isNotEmpty,
      );
      final layer = state.elements.whereType<LayerElement>().single;
      expect(layer.name, 'Ink');
      expect(layer.z, 3);
      expect(layer.elementIds, ['shape-1']);

      final shape =
          state.elements.firstWhere((e) => e.id == 'shape-1') as ShapeElement;
      expect(shape.hidden, isTrue);
      expect(shape.locked, isTrue);
      expect(shape.opacity, 0.4);
      expect(shape.rotation, 0.5);

      final image =
          state.elements.firstWhere((e) => e.id == 'image-1') as ImageElement;
      expect(image.rotation, 1.25);
      expect(image.flipped, isTrue);
    });

    test('creating an element offline attaches it to the active layer and deleting prunes layer elementIds',
        () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(const CanvasAddLayer('Foreground'));
      final withLayer = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<LayerElement>().isNotEmpty,
      );
      final layer = withLayer.elements.whereType<LayerElement>().single;
      expect(withLayer.activeLayerId, layer.id);

      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(60, 60)));
      final withShape = await _nextWhere(
        bloc,
        (s) =>
            s.elements.whereType<ShapeElement>().isNotEmpty &&
            s.elements.whereType<LayerElement>().single.elementIds.isNotEmpty,
      );
      final shape = withShape.elements.whereType<ShapeElement>().single;
      final updatedLayer =
          withShape.elements.whereType<LayerElement>().single;
      expect(updatedLayer.elementIds, contains(shape.id));

      bloc.add(CanvasDeleteElement(shape.id));
      final afterDelete = await _nextWhere(
        bloc,
        (s) => s.elements.whereType<ShapeElement>().isEmpty,
      );
      expect(
        afterDelete.elements.whereType<LayerElement>().single.elementIds,
        isEmpty,
      );
    });

    test('single-element delete and transform edits ignore locked elements',
        () async {
      final (bloc, shapes) = await _threeShapes();
      addTearDown(bloc.close);
      final target = shapes.first;
      bloc.add(CanvasSelectShape(target.id));
      await _nextWhere(bloc, (s) => s.selectedShapeId == target.id);
      bloc.add(CanvasSetElementLocked(target.id, true));
      await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == target.id).locked,
      );

      bloc.add(CanvasMoveSelectedShape(const Offset(999, 999)));
      bloc.add(CanvasDeleteElement(target.id));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final lockedShape = bloc.state.elements
          .whereType<ShapeElement>()
          .firstWhere((e) => e.id == target.id);
      expect(lockedShape.center, target.center);
    });
  });
}
