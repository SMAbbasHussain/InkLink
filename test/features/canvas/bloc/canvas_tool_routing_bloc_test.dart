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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void _drawStroke(CanvasBloc bloc, Offset from, Offset to) {
  bloc.add(CanvasStartStroke(from));
  bloc.add(CanvasAppendStroke(Offset.lerp(from, to, 0.5)!));
  bloc.add(CanvasAppendStroke(to));
  bloc.add(const CanvasEndStroke());
}

void main() {
  group('C-07: the active tool, not the brush style, decides erasing', () {
    test('picking the eraser from the brush tray enters eraser mode', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(const CanvasUpdateBrushType('eraser'));
      await _settle();
      expect(bloc.state.currentToolMode, CanvasToolMode.eraser);
    });

    test('eraser then pen preset draws instead of erasing', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      _drawStroke(bloc, const Offset(0, 0), const Offset(200, 0));
      await _settle();
      expect(bloc.state.elements, hasLength(1));

      bloc.add(const CanvasSetToolMode(CanvasToolMode.eraser));
      bloc.add(const CanvasApplyBrushPreset('solid'));
      await _settle();
      expect(bloc.state.currentToolMode, CanvasToolMode.doodle);

      // Crossing the existing stroke must add ink, not split it.
      _drawStroke(bloc, const Offset(100, -40), const Offset(100, 40));
      await _settle();
      expect(bloc.state.elements.whereType<StrokeElement>(), hasLength(2));
    });

    test('a stale eraser brush type does not erase in pen mode', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      _drawStroke(bloc, const Offset(0, 0), const Offset(200, 0));
      await _settle();

      bloc.add(const CanvasSetToolMode(CanvasToolMode.eraser));
      await _settle();
      bloc.add(const CanvasSetToolMode(CanvasToolMode.doodle));
      await _settle();
      expect(bloc.state.brushType, isNot('eraser'));

      _drawStroke(bloc, const Offset(100, -40), const Offset(100, 40));
      await _settle();
      expect(bloc.state.elements.whereType<StrokeElement>(), hasLength(2));
    });

    test('eraser mode erases even when brush type was never set', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      _drawStroke(bloc, const Offset(0, 0), const Offset(200, 0));
      await _settle();

      bloc.add(const CanvasSetToolMode(CanvasToolMode.eraser));
      bloc.add(const CanvasUpdateStrokeWidth(24));
      _drawStroke(bloc, const Offset(100, -40), const Offset(100, 40));
      await _settle();
      // The single stroke is split into two fragments, no new ink is added.
      expect(bloc.state.elements.whereType<StrokeElement>(), hasLength(2));
      for (final stroke in bloc.state.elements.whereType<StrokeElement>()) {
        expect(stroke.brushType, isNot('eraser'));
      }
    });
  });

  group('C-12: a fresh selection never blocks the next drawing', () {
    test('drawing right after creating a shape adds a stroke', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      _grantEditor(bloc);
      bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(50, 50)));
      await _settle();
      expect(bloc.state.selectedShapeId, isNotNull);

      _drawStroke(bloc, const Offset(300, 300), const Offset(400, 300));
      await _settle();
      expect(bloc.state.elements.whereType<StrokeElement>(), hasLength(1));
    });
  });

  group('C-19: both shape-creation paths share one builder', () {
    test(
      'CanvasAddShape and the draw gesture write the same payload shape',
      () async {
        final bloc = CanvasBloc();
        addTearDown(bloc.close);
        _grantEditor(bloc);
        bloc.add(
          const CanvasAddShape(CanvasShapeType.rectangle, Offset(50, 50)),
        );
        await _settle();
        bloc.add(
          const CanvasSetToolMode(
            CanvasToolMode.shape,
            shapeType: CanvasShapeType.rectangle,
          ),
        );
        bloc.add(const CanvasStartShapeDraw(Offset(200, 200)));
        bloc.add(const CanvasUpdateShapeDraw(Offset(300, 260)));
        bloc.add(const CanvasEndShapeDraw());
        await _settle();

        final shapes = bloc.state.elements.whereType<ShapeElement>().toList();
        expect(shapes, hasLength(2));
        final added = shapes[0];
        final drawn = shapes[1];
        expect(drawn.toMap().keys.toSet(), added.toMap().keys.toSet());
        expect(drawn.strokeWidth, added.strokeWidth);
        expect(drawn.isFilled, added.isFilled);
        expect(drawn.color, added.color);
        expect(drawn.z, greaterThan(added.z));
        expect(bloc.state.selectedShapeId, drawn.id);
        expect(bloc.state.currentToolMode, CanvasToolMode.doodle);
      },
    );
  });
}
