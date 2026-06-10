import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// Editor role must be active for mutation events. The default
/// currentUserRole is `viewer`, which makes the BLoC short-circuit edits.
/// Apply this inside `act:` so the role is set on the live bloc before
/// the action that requires editor permissions.
void _grantEditor(CanvasBloc bloc) {
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
}

void main() {
  group('CanvasBloc — brush / tool settings', () {
    blocTest<CanvasBloc, CanvasState>(
      'CanvasUpdateColor updates selectedColor',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasUpdateColor(Colors.red)),
      verify: (b) => expect(b.state.selectedColor, Colors.red),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasUpdateStrokeWidth updates strokeWidth',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasUpdateStrokeWidth(8)),
      verify: (b) => expect(b.state.strokeWidth, 8),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasUpdateBrushOpacity updates brushOpacity',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasUpdateBrushOpacity(0.5)),
      verify: (b) => expect(b.state.brushOpacity, 0.5),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasUpdateBrushType updates brushType',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasUpdateBrushType('watercolor')),
      verify: (b) => expect(b.state.brushType, 'watercolor'),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasUpdateEraserScope updates eraserEraseEverything',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasUpdateEraserScope(true)),
      verify: (b) => expect(b.state.eraserEraseEverything, isTrue),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasUpdateEraserScope toggles back to false',
      build: CanvasBloc.new,
      act: (b) {
        b.add(const CanvasUpdateEraserScope(true));
        b.add(const CanvasUpdateEraserScope(false));
      },
      verify: (b) => expect(b.state.eraserEraseEverything, isFalse),
    );
  });

  group('CanvasBloc — tray & tips', () {
    blocTest<CanvasBloc, CanvasState>(
      'CanvasToggleTray opens a tray',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasToggleTray('brush')),
      verify: (b) => expect(b.state.activeTray, 'brush'),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasToggleTray closes the same tray',
      build: CanvasBloc.new,
      act: (b) {
        b.add(const CanvasToggleTray('brush'));
        b.add(const CanvasToggleTray('brush'));
      },
      verify: (b) => expect(b.state.activeTray, isNull),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasToggleTray switches between trays without lingering',
      build: CanvasBloc.new,
      act: (b) {
        b.add(const CanvasToggleTray('brush'));
        b.add(const CanvasToggleTray('shapes'));
      },
      verify: (b) => expect(b.state.activeTray, 'shapes'),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasShowTrayTips flips showTrayTips to true',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasShowTrayTips()),
      verify: (b) => expect(b.state.showTrayTips, isTrue),
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasDismissTrayTips flips showTrayTips to false',
      build: CanvasBloc.new,
      seed: () => const CanvasState(showTrayTips: true),
      act: (b) => b.add(const CanvasDismissTrayTips()),
      verify: (b) => expect(b.state.showTrayTips, isFalse),
    );
  });

  group('CanvasBloc — strokes', () {
    blocTest<CanvasBloc, CanvasState>(
      'CanvasStartStroke sets currentStroke to a single point',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasStartStroke(Offset(10, 20)));
      },
      verify: (b) {
        expect(b.state.currentStroke, hasLength(1));
        expect(b.state.currentStroke.first, const Offset(10, 20));
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasAppendStroke appends to currentStroke',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasStartStroke(Offset(0, 0)));
        b.add(const CanvasAppendStroke(Offset(1, 1)));
        b.add(const CanvasAppendStroke(Offset(2, 2)));
      },
      verify: (b) {
        expect(
          b.state.currentStroke,
          const [Offset(0, 0), Offset(1, 1), Offset(2, 2)],
        );
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasEndStroke creates a StrokeElement and clears currentStroke',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasStartStroke(Offset(0, 0)));
        b.add(const CanvasAppendStroke(Offset(5, 5)));
        b.add(const CanvasAppendStroke(Offset(10, 10)));
        b.add(const CanvasEndStroke());
      },
      verify: (b) {
        expect(b.state.currentStroke, isEmpty);
        expect(b.state.elements, hasLength(1));
        final stroke = b.state.elements.first;
        expect(stroke, isA<StrokeElement>());
        final s = stroke as StrokeElement;
        expect(s.points, hasLength(3));
        expect(s.color, b.state.selectedColor);
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasEndStroke with smoothedPoints replaces points',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasStartStroke(Offset(0, 0)));
        b.add(const CanvasAppendStroke(Offset(10, 10)));
        b.add(
          const CanvasEndStroke(
            smoothedPoints: [Offset(0, 0), Offset(5, 5), Offset(10, 10)],
          ),
        );
      },
      verify: (b) {
        final stroke = b.state.elements.single as StrokeElement;
        expect(stroke.points, hasLength(3));
        expect(stroke.points.first, const Offset(0, 0));
        expect(stroke.points.last, const Offset(10, 10));
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasEndStroke with fewer than 2 points is a no-op (no element)',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasStartStroke(Offset(0, 0)));
        b.add(const CanvasEndStroke());
      },
      verify: (b) {
        expect(b.state.currentStroke, isEmpty);
        expect(b.state.elements, isEmpty);
      },
    );
  });

  group('CanvasBloc — shapes & text', () {
    blocTest<CanvasBloc, CanvasState>(
      'CanvasAddShape creates a ShapeElement and selects it',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(
          const CanvasAddShape(CanvasShapeType.star, Offset(100, 100)),
        );
      },
      verify: (b) {
        expect(b.state.elements, hasLength(1));
        final shape = b.state.elements.first;
        expect(shape, isA<ShapeElement>());
        final s = shape as ShapeElement;
        expect(s.shapeType, CanvasShapeType.star);
        expect(s.center, const Offset(100, 100));
        expect(b.state.selectedShapeId, s.id);
        expect(b.state.activeTray, isNull);
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasAddAiText creates a TextElement',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasAddAiText('hello world', Offset(50, 60)));
      },
      verify: (b) {
        expect(b.state.elements, hasLength(1));
        final text = b.state.elements.first;
        expect(text, isA<TextElement>());
        final t = text as TextElement;
        expect(t.text, 'hello world');
        expect(t.center, const Offset(50, 60));
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'CanvasAddAiText with empty prompt is a no-op',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasAddAiText('   ', Offset(0, 0)));
      },
      verify: (b) => expect(b.state.elements, isEmpty),
    );

    blocTest<CanvasBloc, CanvasState>(
      'multiple CanvasAddShape accumulate elements',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasAddShape(CanvasShapeType.circle, Offset(10, 10)));
        b.add(const CanvasAddShape(CanvasShapeType.square, Offset(20, 20)));
        b.add(
          const CanvasAddShape(CanvasShapeType.triangle, Offset(30, 30)),
        );
      },
      verify: (b) {
        expect(b.state.elements, hasLength(3));
        final types = b.state.elements
            .whereType<ShapeElement>()
            .map((e) => e.shapeType)
            .toList();
        expect(
          types,
          [
            CanvasShapeType.circle,
            CanvasShapeType.square,
            CanvasShapeType.triangle,
          ],
        );
      },
    );
  });

  group('CanvasBloc — delete & clear', () {
    test('CanvasDeleteElement removes a specific element', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(0, 0)));
      await Future<void>.delayed(Duration.zero);
      final firstId = bloc.state.elements.first.id;
      bloc.add(CanvasDeleteElement(firstId));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.elements, hasLength(1));
      final remaining =
          bloc.state.elements.whereType<ShapeElement>().single;
      expect(remaining.shapeType, CanvasShapeType.square);
      await bloc.close();
    });

    test(
      'CanvasDeleteElement clears selectedShapeId when deleting the selection',
      () async {
        final bloc = CanvasBloc();
        _grantEditor(bloc);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)));
        await Future<void>.delayed(Duration.zero);
        final id = bloc.state.elements.single.id;
        bloc.add(CanvasDeleteElement(id));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.elements, isEmpty);
        expect(bloc.state.selectedShapeId, isNull);
        await bloc.close();
      },
    );

    test(
      'CanvasDeleteElement leaves selectedShapeId alone when deleting another element',
      () async {
        final bloc = CanvasBloc();
        _grantEditor(bloc);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(0, 0)));
        await Future<void>.delayed(Duration.zero);
        final selectedId = bloc.state.selectedShapeId!;
        final otherId = bloc.state.elements
            .firstWhere((e) => e.id != selectedId)
            .id;
        bloc.add(CanvasDeleteElement(otherId));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.selectedShapeId, isNotNull);
        expect(bloc.state.elements, hasLength(1));
        await bloc.close();
      },
    );

    test('CanvasClearAll empties the elements list', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(0, 0)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasClearAll());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.elements, isEmpty);
      expect(bloc.state.activeTray, isNull);
      await bloc.close();
    });

    blocTest<CanvasBloc, CanvasState>(
      'CanvasClearAll on an empty canvas is a no-op (no error)',
      build: CanvasBloc.new,
      act: (b) {
        _grantEditor(b);
        b.add(const CanvasClearAll());
      },
      // Only the role-grant emits. The clear itself is a no-op.
      expect: () => [predicate<CanvasState>(
        (s) => s.currentUserRole == Board.roleEditor,
      )],
    );
  });

  group('CanvasBloc — selection', () {
    test('CanvasSelectShape sets selectedShapeId', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(CanvasSelectShape(bloc.state.elements.single.id));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selectedShapeId, isNotNull);
      await bloc.close();
    });

    test('CanvasSelectShape(null) clears the selection', () async {
      final bloc = CanvasBloc();
      _grantEditor(bloc);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)));
      await Future<void>.delayed(Duration.zero);
      bloc.add(CanvasSelectShape(bloc.state.elements.single.id));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const CanvasSelectShape(null));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.selectedShapeId, isNull);
      await bloc.close();
    });
  });

  group('CanvasBloc — viewer role enforcement', () {
    blocTest<CanvasBloc, CanvasState>(
      'viewers cannot add a shape',
      build: CanvasBloc.new,
      // no _grantEditor call
      act: (b) => b.add(
        const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)),
      ),
      verify: (b) {
        expect(b.state.elements, isEmpty);
        expect(
          b.state.error,
          contains('viewer'),
          reason: 'expected viewer warning in state.error',
        );
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'viewers cannot start a stroke',
      build: CanvasBloc.new,
      act: (b) => b.add(const CanvasStartStroke(Offset(0, 0))),
      verify: (b) {
        expect(b.state.currentStroke, isEmpty);
      },
    );

    blocTest<CanvasBloc, CanvasState>(
      'promoting a viewer to editor re-enables edits',
      build: CanvasBloc.new,
      act: (b) {
        b.add(
          const CanvasBoardTitleUpdated(
            null,
            currentUserRole: Board.roleEditor,
          ),
        );
        b.add(
          const CanvasAddShape(CanvasShapeType.circle, Offset(0, 0)),
        );
      },
      verify: (b) {
        expect(b.state.elements, hasLength(1));
        expect(b.state.currentUserRole, Board.roleEditor);
      },
    );
  });
}
