import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
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

Future<ShapeElement> _oneShape(CanvasBloc bloc) async {
  _grantEditor(bloc);
  await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);
  bloc.add(
    const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 100)),
  );
  final state = await _nextWhere(bloc, (s) => s.elements.isNotEmpty);
  final shape = state.elements.single as ShapeElement;
  return shape;
}

void main() {
  group('single-element undoable toasts', () {
    test('moving a shape posts an undoable message', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      final shape = await _oneShape(bloc);

      bloc.add(const CanvasMoveSelectedShape(Offset(140, 160)));
      final state = await _nextWhere(
        bloc,
        (s) => s.infoMessage != null,
      );

      expect(state.infoMessage, contains('Moved element'));
      expect(state.infoMessageUndoable, isTrue);
      expect(state.infoMessageRedoable, isFalse);
      final moved = state.elements.single as ShapeElement;
      expect(moved.id, shape.id);
      expect(moved.center, const Offset(140, 160));
    });

    test('resizing a shape posts an undoable message', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      await _oneShape(bloc);

      bloc.add(const CanvasResizeSelectedShape(96));
      final state = await _nextWhere(bloc, (s) => s.infoMessage != null);

      expect(state.infoMessage, contains('Resized element'));
      expect(state.infoMessageUndoable, isTrue);
    });

    test('deleting a shape posts an undoable message', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      final shape = await _oneShape(bloc);

      bloc.add(CanvasDeleteElement(shape.id));
      final state = await _nextWhere(bloc, (s) => s.infoMessage != null);

      expect(state.elements, isEmpty);
      expect(state.infoMessage, contains('Deleted element'));
      expect(state.infoMessageUndoable, isTrue);
    });

    test('a zero-delta action does not post a message', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      await _oneShape(bloc);

      bloc.add(const CanvasMoveSelectedShape(Offset(100, 100)));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.infoMessage, isNull);
    });

    test('consuming the message clears both affordances', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      final shape = await _oneShape(bloc);
      bloc.add(CanvasDeleteElement(shape.id));
      await _nextWhere(bloc, (s) => s.infoMessage != null);

      bloc.add(const CanvasConsumeInfoMessage());
      final state = await _nextWhere(bloc, (s) => s.infoMessage == null);

      expect(state.infoMessageUndoable, isFalse);
      expect(state.infoMessageRedoable, isFalse);
    });
  });

  group('redo affordance', () {
    test('a successful undo offers redo until consumed', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('shape-1', const {
        'type': 'shape',
        'shapeType': 'rectangle',
        'cx': 40.0,
        'cy': 40.0,
        'size': 64.0,
      });
      final bloc = CanvasBloc(crdtAdapter: adapter);
      addTearDown(bloc.close);
      _grantEditor(bloc);
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);

      bloc.add(const CanvasUndo());
      final undoState = await _nextWhere(
        bloc,
        (s) => s.infoMessage != null,
      );

      expect(undoState.elements, isEmpty);
      expect(undoState.infoMessage, contains('Undone'));
      expect(undoState.infoMessageRedoable, isTrue);
      expect(undoState.infoMessageUndoable, isFalse);

      bloc.add(const CanvasConsumeInfoMessage());
      final consumed = await _nextWhere(bloc, (s) => s.infoMessage == null);
      expect(consumed.infoMessageRedoable, isFalse);
    });

    test('redo clears the redo affordance', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('shape-1', const {
        'type': 'shape',
        'shapeType': 'rectangle',
        'cx': 40.0,
        'cy': 40.0,
        'size': 64.0,
      });
      final bloc = CanvasBloc(crdtAdapter: adapter);
      addTearDown(bloc.close);
      _grantEditor(bloc);
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);

      bloc.add(const CanvasUndo());
      await _nextWhere(bloc, (s) => s.infoMessageRedoable);
      bloc.add(const CanvasRedo());
      final redone = await _nextWhere(
        bloc,
        (s) => s.infoMessage == 'Redone',
      );

      expect(redone.elements, hasLength(1));
      expect(redone.infoMessageRedoable, isFalse);
      expect(adapter.canRedo, isFalse);
    });

    test('a new edit clears a pending redo affordance', () async {
      final adapter = await CanvasCrdtAdapter.create();
      adapter.upsertElement('shape-1', const {
        'type': 'shape',
        'shapeType': 'rectangle',
        'cx': 40.0,
        'cy': 40.0,
        'size': 64.0,
      });
      final bloc = CanvasBloc(crdtAdapter: adapter);
      addTearDown(bloc.close);
      _grantEditor(bloc);
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleEditor);

      bloc.add(const CanvasUndo());
      await _nextWhere(bloc, (s) => s.infoMessageRedoable);

      // The added shape write goes through the same save path as production;
      // without a sync service it still invalidates the offered redo.
      bloc.add(
        const CanvasAddShape(CanvasShapeType.rectangle, Offset(200, 200)),
      );
      final afterEdit = await _nextWhere(
        bloc,
        (s) => !s.infoMessageRedoable && s.elements.length == 1,
      );
      expect(afterEdit.infoMessage, isNull);
    });
  });
}
