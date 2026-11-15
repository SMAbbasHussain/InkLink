import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
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

void main() {
  group('CanvasAddText', () {
    test('creates a measured, selected text object', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddText(
          topLeft: Offset(10, 20),
          text: 'Hello canvases',
          color: Colors.red,
        ),
      );

      final state = await _nextWhere(bloc, (s) => s.elements.isNotEmpty);
      expect(state.elements, hasLength(1));
      final text = state.elements.single as TextElement;
      expect(text.text, 'Hello canvases');
      expect(text.center, const Offset(10, 20));
      expect(text.color, Colors.red);
      expect(text.fontSize, 16);
      expect(text.maxLines, 0);
      expect(text.width, greaterThan(0));
      expect(text.height, greaterThan(0));
      expect(state.selectedShapeId, text.id);
    });

    test('viewer cannot create text', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      bloc.add(
        const CanvasAddText(
          topLeft: Offset.zero,
          text: 'Nope',
          color: Colors.black,
        ),
      );

      // The rejection emits a warning; the element list must stay empty.
      await _nextWhere(bloc, (s) => s.error != null);
      expect(bloc.state.elements, isEmpty);
    });

    test('empty text is ignored', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddText(
          topLeft: Offset.zero,
          text: '   ',
          color: Colors.black,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.elements, isEmpty);
    });
  });

  group('CanvasUpdateText', () {
    Future<(CanvasBloc, TextElement)> createText() async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddText(
          topLeft: Offset(0, 0),
          text: 'before',
          color: Colors.black,
        ),
      );
      final state = await _nextWhere(bloc, (s) => s.elements.isNotEmpty);
      return (bloc, state.elements.single as TextElement);
    }

    test('updates content and re-measures the box', () async {
      final (bloc, text) = await createText();
      addTearDown(bloc.close);
      bloc.add(
        CanvasUpdateText(
          elementId: text.id,
          text: 'a much longer line of text than before',
        ),
      );

      final state = await _nextWhere(
        bloc,
        (s) =>
            s.elements.single is TextElement &&
            (s.elements.single as TextElement).text.startsWith('a much'),
      );
      final updated = state.elements.single as TextElement;
      expect(updated.id, text.id);
      expect(updated.height, greaterThan(0));
    });

    test('persists style and rotation', () async {
      final (bloc, text) = await createText();
      addTearDown(bloc.close);
      bloc.add(
        CanvasUpdateText(
          elementId: text.id,
          fontSize: 32,
          fontWeight: 800,
          textAlign: 'center',
          rotation: 0.5,
          color: Colors.blue,
        ),
      );

      final state = await _nextWhere(
        bloc,
        (s) =>
            s.elements.single is TextElement &&
            (s.elements.single as TextElement).fontSize == 32,
      );
      final updated = state.elements.single as TextElement;
      expect(updated.fontWeight, 800);
      expect(updated.textAlign, 'center');
      expect(updated.rotation, 0.5);
      expect(updated.color, Colors.blue);
      expect(updated.text, 'before');
    });

    test('whitespace-only text deletes the object', () async {
      final (bloc, text) = await createText();
      addTearDown(bloc.close);
      bloc.add(CanvasUpdateText(elementId: text.id, text: '  '));

      final state = await _nextWhere(bloc, (s) => s.elements.isEmpty);
      expect(state.elements, isEmpty);
    });

    test('viewer cannot update text', () async {
      final (bloc, text) = await createText();
      addTearDown(bloc.close);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleViewer);

      bloc.add(CanvasUpdateText(elementId: text.id, text: 'hacked'));
      await _nextWhere(bloc, (s) => s.error != null);
      final current = bloc.state.elements.single as TextElement;
      expect(current.text, 'before');
    });

    test('moving text keeps its stacking order', () async {
      final (bloc, text) = await createText();
      addTearDown(bloc.close);
      final originalZ = text.z;
      bloc.add(CanvasUpdateText(elementId: text.id, topLeft: const Offset(80, 90)));

      final state = await _nextWhere(
        bloc,
        (s) => (s.elements.single as TextElement).center == const Offset(80, 90),
      );
      expect((state.elements.single as TextElement).z, originalZ);
    });
  });

  group('tool mode is the single source of truth for erasing', () {
    test('selecting the eraser sets the eraser brush, pen restores a pen',
        () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      bloc.add(const CanvasSetToolMode(CanvasToolMode.eraser));
      await _nextWhere(bloc, (s) => s.currentToolMode == CanvasToolMode.eraser);
      expect(bloc.state.brushType, 'eraser');

      bloc.add(const CanvasSetToolMode(CanvasToolMode.doodle));
      await _nextWhere(bloc, (s) => s.currentToolMode == CanvasToolMode.doodle);
      expect(bloc.state.brushType, 'solid');
    });

    test('switching tools cancels an in-progress shape draw', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(
        const CanvasSetToolMode(
          CanvasToolMode.shape,
          shapeType: CanvasShapeType.square,
        ),
      );
      bloc.add(const CanvasStartShapeDraw(Offset(10, 10)));
      await _nextWhere(bloc, (s) => s.isDrawingShape);

      bloc.add(const CanvasSetToolMode(CanvasToolMode.select));
      await _nextWhere(bloc, (s) => s.currentToolMode == CanvasToolMode.select);
      expect(bloc.state.isDrawingShape, isFalse);
      expect(bloc.state.shapeDrawStart, isNull);
      expect(bloc.state.elements, isEmpty);
    });

    test('select tool keeps the selection, drawing tools clear it', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddText(
          topLeft: Offset.zero,
          text: 'keep me',
          color: Colors.black,
        ),
      );
      final added = await _nextWhere(bloc, (s) => s.selectedShapeId != null);

      bloc.add(const CanvasSetToolMode(CanvasToolMode.select));
      await _nextWhere(bloc, (s) => s.currentToolMode == CanvasToolMode.select);
      expect(bloc.state.selectedShapeId, added.selectedShapeId);

      bloc.add(const CanvasSetToolMode(CanvasToolMode.doodle));
      await _nextWhere(bloc, (s) => s.currentToolMode == CanvasToolMode.doodle);
      expect(bloc.state.selectedShapeId, isNull);
    });
  });

  group('CanvasUpdateText metadata preservation', () {
    test('re-measuring updated text preserves hidden, locked, and opacity',
        () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(
        const CanvasAddText(
          topLeft: Offset(10, 20),
          text: 'initial',
          color: Colors.black,
        ),
      );
      final created = await _nextWhere(bloc, (s) => s.elements.length == 1);
      final id = created.elements.single.id;

      bloc.add(CanvasSetElementOpacity(id, 0.45));
      bloc.add(CanvasSetElementVisibility(id, false));
      bloc.add(CanvasSetElementLocked(id, true));
      await _nextWhere(
        bloc,
        (s) => s.elements.single.locked && s.elements.single.hidden,
      );

      // Unlock only so CanvasUpdateText can re-measure while keeping opacity/hidden.
      bloc.add(CanvasSetElementLocked(id, false));
      await _nextWhere(bloc, (s) => !s.elements.single.locked);

      bloc.add(
        CanvasUpdateText(
          elementId: id,
          text: 'longer measured text string',
          fontSize: 22,
        ),
      );
      final updatedState = await _nextWhere(
        bloc,
        (s) => (s.elements.single as TextElement).text ==
            'longer measured text string',
      );
      final textEl = updatedState.elements.single as TextElement;
      expect(textEl.hidden, isTrue);
      expect(textEl.opacity, closeTo(0.45, 1e-6));
    });
  });
}
