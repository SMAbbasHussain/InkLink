import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<(CanvasBloc, ShapeElement, ShapeElement)> _twoShapes() async {
  final bloc = CanvasBloc();
  _grantEditor(bloc);
  bloc.add(
    const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 100)),
  );
  bloc.add(
    const CanvasAddShape(CanvasShapeType.rectangle, Offset(300, 300)),
  );
  final state = await _nextWhere(bloc, (s) => s.elements.length == 2);
  final shapes = state.elements.cast<ShapeElement>().toList();
  return (bloc, shapes[0], shapes[1]);
}

void main() {
  group('marquee selection', () {
    test('selects only elements whose bounds intersect the rect', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);

      bloc.add(
        CanvasSelectInRect(
          Rect.fromLTRB(40, 40, 160, 160),
          additive: false,
        ),
      );
      final state = await _nextWhere(bloc, (s) => s.selectedIds.isNotEmpty);
      expect(state.selectedIds, {first.id});
      expect(state.selectedShapeId, first.id);
      expect(state.selectedIds.contains(second.id), isFalse);
    });

    test('marquee over empty space clears the selection', () async {
      final (bloc, _, _) = await _twoShapes();
      addTearDown(bloc.close);
      expect(bloc.state.selectedIds, isNotEmpty);

      // Selecting nothing produces the same state, so wait a beat instead of
      // waiting for an emission the bloc correctly suppresses.
      bloc.add(
        CanvasSelectInRect(const Rect.fromLTRB(-500, -500, -400, -400)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.selectedIds, isEmpty);
      expect(bloc.state.selectedShapeId, isNull);
    });

    test('additive marquee keeps the previous selection', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 1);

      bloc.add(
        CanvasSelectInRect(
          Rect.fromLTRB(250, 250, 360, 360),
          additive: true,
        ),
      );
      final state = await _nextWhere(bloc, (s) => s.selectedIds.length == 2);
      expect(state.selectedIds, {first.id, second.id});
    });
  });

  group('lasso selection', () {
    test('selects elements inside the loop and ignores outside ones', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);

      bloc.add(
        CanvasSelectInLasso(const [
          Offset(30, 30),
          Offset(200, 30),
          Offset(200, 200),
          Offset(30, 200),
        ]),
      );
      final state = await _nextWhere(bloc, (s) => s.selectedIds.isNotEmpty);
      expect(state.selectedIds, {first.id});
      expect(state.selectedIds.contains(second.id), isFalse);
    });

    test('additive lasso keeps the previous selection', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 1);

      bloc.add(
        CanvasSelectInLasso(
          const [
            Offset(230, 230),
            Offset(370, 230),
            Offset(370, 370),
            Offset(230, 370),
          ],
          additive: true,
        ),
      );
      final state = await _nextWhere(bloc, (s) => s.selectedIds.length == 2);
      expect(state.selectedIds, {first.id, second.id});
    });

    test('locked and hidden elements are skipped', () async {
      final (bloc, first, _) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSetElementLocked(first.id, true));
      await _nextWhere(
        bloc,
        (s) => s.elements.firstWhere((e) => e.id == first.id).locked,
      );

      bloc.add(
        CanvasSelectInLasso(const [
          Offset(30, 30),
          Offset(200, 30),
          Offset(200, 200),
          Offset(30, 200),
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.selectedIds, isEmpty);
    });

    test('selection mode changes without touching the selection', () async {
      final (bloc, _, _) = await _twoShapes();
      addTearDown(bloc.close);
      final before = bloc.state.selectedIds;
      bloc.add(
        const CanvasSetSelectionMode(CanvasSelectionMode.lasso),
      );
      final state = await _nextWhere(
        bloc,
        (s) => s.selectionMode == CanvasSelectionMode.lasso,
      );
      expect(state.selectedIds, before);
    });
  });

  group('group transform', () {
    test('align left moves every selected centre to the union left edge',
        () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      bloc.add(
        const CanvasAlignSelection(CanvasSelectionAlignment.left),
      );
      final state = await _nextWhere(
        bloc,
        (s) =>
            s.elements
                .whereType<ShapeElement>()
                .map((shape) => shape.center.dx)
                .toSet()
                .length ==
            1,
      );
      final shapes = state.elements.whereType<ShapeElement>().toList();
      expect(shapes[0].center.dx, closeTo(shapes[1].center.dx, 0.001));
      expect(shapes[0].center.dx, closeTo(100, 0.001));
      // Alignment is horizontal only.
      expect(shapes[0].center.dy, 100);
      expect(shapes[1].center.dy, 300);
    });

    test('translate moves all selected elements and preserves z', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      bloc.add(const CanvasTranslateSelection(Offset(10, -5)));
      final state = await _nextWhere(
        bloc,
        (s) =>
            s.elements.whereType<ShapeElement>().first.center ==
            const Offset(110, 95),
      );
      final shapes = state.elements.whereType<ShapeElement>().toList();
      expect(shapes[1].center, const Offset(310, 295));
      expect(shapes[0].z, first.z);
      expect(shapes[1].z, second.z);
    });

    test('viewer cannot translate the selection', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleViewer);

      bloc.add(const CanvasTranslateSelection(Offset(40, 40)));
      await _nextWhere(bloc, (s) => s.error != null);
      final shapes = bloc.state.elements.whereType<ShapeElement>().toList();
      expect(shapes[0].center, const Offset(100, 100));
      expect(shapes[1].center, const Offset(300, 300));
    });

    test('scales the whole selection from the union box', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      final before = bloc.state.elements.whereType<ShapeElement>().toList();
      final source = elementsBounds(before)!;
      final target = Rect.fromLTWH(
        source.left,
        source.top,
        source.width * 2,
        source.height * 2,
      );
      // Free aspect (C-11): width and height scale independently from the
      // rendered box, and size tracks the larger dimension.
      final firstBox = shapeElementRect(before[0]);
      final expectedWidth = firstBox.width * 2;
      final expectedHeight = firstBox.height * 2;
      final expectedSize = math.max(expectedWidth, expectedHeight);
      final expectedFirstCenter = Offset(
        source.left + (before[0].center.dx - source.left) * 2,
        source.top + (before[0].center.dy - source.top) * 2,
      );
      bloc.add(
        CanvasScaleSelection(sourceBounds: source, targetBounds: target),
      );
      final state = await _nextWhere(
        bloc,
        (s) =>
            (s.elements.whereType<ShapeElement>().first.width - expectedWidth)
                .abs() <
            0.01,
      );
      final shapes = state.elements.whereType<ShapeElement>().toList();
      expect(shapes[0].width, closeTo(expectedWidth, 0.001));
      expect(shapes[0].height, closeTo(expectedHeight, 0.001));
      expect(shapes[0].size, closeTo(expectedSize, 0.001));
      expect(shapes[0].center.dx, closeTo(expectedFirstCenter.dx, 0.001));
      expect(shapes[0].center.dy, closeTo(expectedFirstCenter.dy, 0.001));
      expect(shapes[1].center.dx, greaterThan(shapes[0].center.dx));
      expect(shapes[0].z, first.z);
      expect(shapes[1].z, second.z);
    });

    test('rotates the whole selection around the union centre', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      final bounds = elementsBounds(
        bloc.state.elements.whereType<ShapeElement>(),
      )!;
      final pivot = bounds.center;
      final radius = (first.center - pivot).distance;
      bloc.add(CanvasRotateSelection(pivot: pivot, radians: math.pi / 2));
      final state = await _nextWhere(
        bloc,
        (s) =>
            s.elements
                .whereType<ShapeElement>()
                .first
                .rotation
                .abs() >
            0.1,
      );
      final rotated = state.elements.whereType<ShapeElement>().first;
      expect((rotated.center - pivot).distance, closeTo(radius, 0.001));
      expect(rotated.rotation, closeTo(math.pi / 2, 1e-6));
    });

    test('viewer cannot scale or rotate the selection', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleViewer);

      final before = bloc.state.elements.whereType<ShapeElement>().toList();
      final bounds = elementsBounds(before)!;
      bloc.add(
        CanvasScaleSelection(
          sourceBounds: bounds,
          targetBounds: Rect.fromLTWH(
            bounds.left,
            bounds.top,
            bounds.width * 2,
            bounds.height * 2,
          ),
        ),
      );
      bloc.add(
        CanvasRotateSelection(pivot: bounds.center, radians: math.pi / 2),
      );
      await _nextWhere(bloc, (s) => s.error != null);

      final after = bloc.state.elements.whereType<ShapeElement>().toList();
      expect(after[0].center, before[0].center);
      expect(after[0].rotation, before[0].rotation);
    });

    test('group actions post a short undo summary', () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      bloc.add(const CanvasTranslateSelection(Offset(10, 10)));
      final moved = await _nextWhere(bloc, (s) => s.infoMessage != null);
      expect(moved.infoMessage, contains('Moved 2 elements'));
      expect(moved.infoMessage, contains('Undo'));
      expect(moved.infoMessageUndoable, isTrue);

      bloc.add(const CanvasConsumeInfoMessage());
      final consumed = await _nextWhere(bloc, (s) => s.infoMessage == null);
      expect(consumed.infoMessageUndoable, isFalse);

      bloc.add(CanvasDuplicateElements({first.id, second.id}));
      final duplicated = await _nextWhere(
        bloc,
        (s) => s.infoMessage?.contains('Duplicated') ?? false,
      );
      expect(duplicated.infoMessage, contains('Duplicated 2 elements'));
    });

    test('distribute horizontally evens the gaps of three elements', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(0, 0)));
      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(50, 0)));
      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(300, 0)));
      await _nextWhere(bloc, (s) => s.elements.length == 3);
      final ids = bloc.state.elements.map((e) => e.id).toSet();
      bloc.add(CanvasSelectElements(ids));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 3);

      bloc.add(
        const CanvasAlignSelection(
          CanvasSelectionAlignment.distributeHorizontal,
        ),
      );
      final state = await _nextWhere(
        bloc,
        (s) =>
            (s.elements
                    .whereType<ShapeElement>()
                    .firstWhere((shape) => shape.center.dx == 150)
                    .center
                    .dx) ==
            150,
      );
      final centers = state.elements
          .whereType<ShapeElement>()
          .map((shape) => shape.center.dx)
          .toList()
        ..sort();
      expect(centers, [0, 150, 300]);
    });
  });

  group('duplicate and delete', () {
    test('duplicate clones every selected element and selects the clones',
        () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      bloc.add(CanvasDuplicateElements({first.id, second.id}));
      final state = await _nextWhere(bloc, (s) => s.elements.length == 4);
      final ids = state.elements.map((element) => element.id).toSet();
      expect(ids, hasLength(4));
      expect(state.selectedIds, hasLength(2));
      expect(state.selectedIds.intersection({first.id, second.id}), isEmpty);
      final clones =
          state.elements.where((e) => state.selectedIds.contains(e.id));
      expect(
        clones.whereType<ShapeElement>().map((shape) => shape.center).toSet(),
        {const Offset(116, 116), const Offset(316, 316)},
      );
    });

    test('deleting an element detaches connectors that reference it',
        () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(
        CanvasAddConnector(
          startElementId: first.id,
          startPoint: first.center,
          endElementId: second.id,
          endPoint: second.center,
        ),
      );
      final addedConnState = await _nextWhere(bloc, (s) => s.elements.length == 3);
      final addedConn =
          addedConnState.elements.whereType<ConnectorElement>().single;
      expect(addedConnState.selectedShapeId, addedConn.id);
      expect(addedConnState.selectedIds, {addedConn.id});

      bloc.add(
        CanvasUpdateConnector(
          elementId: addedConn.id,
          lineStyle: 'orthogonal',
          cornerRadius: 12,
          dashPattern: const [12, 8],
          startArrowhead: true,
          label: 'flows to',
        ),
      );
      await _nextWhere(
        bloc,
        (s) => s.elements
            .whereType<ConnectorElement>()
            .any((c) => c.label == 'flows to'),
      );

      bloc.add(CanvasDeleteElements({first.id}));
      final state = await _nextWhere(
        bloc,
        (s) => s.elements.length == 2,
      );
      final connector =
          state.elements.whereType<ConnectorElement>().single;
      expect(connector.startElementId, isNull);
      expect(connector.endElementId, second.id);
      expect(connector.startAnchor, 'center');
      expect(state.selectedIds, {connector.id});
      // The detached connector degrades to a free end but keeps its style.
      expect(connector.lineStyle, 'orthogonal');
      expect(connector.cornerRadius, 12);
      expect(connector.dashPattern, [12, 8]);
      expect(connector.startArrowhead, isTrue);
      expect(connector.label, 'flows to');
    });

    test('deleting one element keeps other surviving selected IDs selected',
        () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(CanvasSelectElements({first.id, second.id}));
      await _nextWhere(bloc, (s) => s.selectedIds.length == 2);

      bloc.add(CanvasDeleteElements({first.id}));
      final state = await _nextWhere(bloc, (s) => s.elements.length == 1);
      expect(state.selectedIds, {second.id});
    });
  });

  group('sticky note resize and connector sync', () {
    test('CanvasAddStickyNote selects sticky note and CanvasUpdateStickyNote resizes while keeping z',
        () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddStickyNote(
          center: Offset(100, 100),
          text: 'Initial',
          width: 160,
          height: 120,
        ),
      );
      final added = await _nextWhere(bloc, (s) => s.elements.length == 1);
      final note = added.elements.single as StickyNoteElement;
      expect(added.selectedShapeId, note.id);
      expect(added.selectedIds, {note.id});

      bloc.add(
        CanvasUpdateStickyNote(
          elementId: note.id,
          width: 240,
          height: 180,
          text: 'Updated',
        ),
      );
      final resized = await _nextWhere(
        bloc,
        (s) => (s.elements.single as StickyNoteElement).width == 240,
      );
      final updated = resized.elements.single as StickyNoteElement;
      expect(updated.height, 180);
      expect(updated.text, 'Updated');
      expect(updated.z, note.z);

      bloc.add(const CanvasResizeSelectedShape(320));
      final scaled = await _nextWhere(
        bloc,
        (s) => (s.elements.single as StickyNoteElement).width == 320,
      );
      final scaledNote = scaled.elements.single as StickyNoteElement;
      // Aspect ratio 180 / 240 = 0.75 -> height 240.
      expect(scaledNote.height, closeTo(240, 1e-6));
    });

    test('moving a connected shape updates attached connector endpoints in state',
        () async {
      final (bloc, first, second) = await _twoShapes();
      addTearDown(bloc.close);
      bloc.add(
        CanvasAddConnector(
          startElementId: first.id,
          startPoint: first.center,
          endElementId: second.id,
          endPoint: second.center,
        ),
      );
      await _nextWhere(bloc, (s) => s.elements.length == 3);

      bloc.add(CanvasSelectShape(first.id));
      await _nextWhere(bloc, (s) => s.selectedShapeId == first.id);

      bloc.add(const CanvasMoveSelectedShape(Offset(150, 220)));
      final moved = await _nextWhere(
        bloc,
        (s) =>
            (s.elements.firstWhere((e) => e.id == first.id) as ShapeElement)
                .center ==
            const Offset(150, 220),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final connector =
          bloc.state.elements.whereType<ConnectorElement>().single;
      expect(moved.elements.length, 3);
      expect(connector.startPoint, const Offset(150, 220));
      expect(connector.endPoint, second.center);
    });
  });
}
