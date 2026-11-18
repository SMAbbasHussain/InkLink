import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

Future<CanvasState> _until(CanvasBloc bloc, bool Function(CanvasState) test) {
  return bloc.stream.firstWhere(test).timeout(const Duration(seconds: 2));
}

ShapeElement _selectedShape(CanvasState state) => state.elements
    .firstWhere((e) => e.id == state.selectedShapeId) as ShapeElement;

Future<CanvasBloc> _editorWithShape(CanvasShapeType type) async {
  final bloc = CanvasBloc();
  addTearDown(bloc.close);
  bloc.add(
    const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
  );
  await _until(bloc, (s) => s.canEdit);
  bloc.add(CanvasAddShape(type, const Offset(100, 100)));
  await _until(bloc, (s) => s.elements.isNotEmpty && s.selectedShapeId != null);
  return bloc;
}

void main() {
  group('CanvasBloc — F-10 shape editing', () {
    test('resize writes an explicit 200x80 box into the payload', () async {
      final bloc = await _editorWithShape(CanvasShapeType.rectangle);

      bloc.add(const CanvasResizeSelectedShape(200, width: 200, height: 80));
      await _until(bloc, (s) => _selectedShape(s).width == 200);

      final shape = _selectedShape(bloc.state);
      expect(shape.width, 200);
      expect(shape.height, 80);
      expect(shape.size, 200);
      expect(shape.toMap()['width'], 200);
      expect(shape.toMap()['height'], 80);
      expect(shape.toMap()['size'], 200);
    });

    test('resize keeps a linear shape flat', () async {
      final bloc = await _editorWithShape(CanvasShapeType.arrow);

      bloc.add(const CanvasResizeSelectedShape(300, width: 300, height: 120));
      await _until(bloc, (s) => _selectedShape(s).width == 300);

      final shape = _selectedShape(bloc.state);
      expect(shape.width, 300);
      expect(shape.height, 0);
      expect(shape.size, 300);
    });

    test('stroke width updates and clamps to 0..64', () async {
      final bloc = await _editorWithShape(CanvasShapeType.rectangle);

      bloc.add(const CanvasUpdateSelectedShapeStrokeWidth(12));
      await _until(bloc, (s) => _selectedShape(s).strokeWidth == 12);

      bloc.add(const CanvasUpdateSelectedShapeStrokeWidth(999));
      await _until(bloc, (s) => _selectedShape(s).strokeWidth == 64);
      expect(_selectedShape(bloc.state).strokeWidth, 64);
    });

    test('stroke opacity updates and clamps to 0..1', () async {
      final bloc = await _editorWithShape(CanvasShapeType.rectangle);

      bloc.add(const CanvasUpdateSelectedShapeStrokeOpacity(0.4));
      await _until(bloc, (s) => _selectedShape(s).strokeOpacity == 0.4);

      bloc.add(const CanvasUpdateSelectedShapeStrokeOpacity(2));
      await _until(bloc, (s) => _selectedShape(s).strokeOpacity == 1);
    });

    test('dash pattern sets and clears', () async {
      final bloc = await _editorWithShape(CanvasShapeType.rectangle);

      bloc.add(const CanvasUpdateSelectedShapeDash([12, 8]));
      await _until(bloc, (s) => _selectedShape(s).dashPattern != null);
      expect(_selectedShape(bloc.state).dashPattern, [12, 8]);

      bloc.add(const CanvasUpdateSelectedShapeDash(null));
      await _until(bloc, (s) => _selectedShape(s).dashPattern == null);
    });

    test('label text, color, size, weight and align edit independently',
        () async {
      final bloc = await _editorWithShape(CanvasShapeType.rectangle);

      bloc.add(const CanvasUpdateSelectedShapeLabel(
        label: 'Hi',
        labelColor: Color(0xFFF44336),
        labelFontSize: 20,
        labelFontWeight: 700,
        labelTextAlign: 'left',
      ));
      await _until(bloc, (s) => _selectedShape(s).label == 'Hi');

      final shape = _selectedShape(bloc.state);
      expect(shape.labelColor, const Color(0xFFF44336));
      expect(shape.labelFontSize, 20);
      expect(shape.labelFontWeight, 700);
      expect(shape.labelTextAlign, 'left');

      bloc.add(const CanvasUpdateSelectedShapeLabel(clearLabelColor: true));
      await _until(bloc, (s) => _selectedShape(s).labelColor == null);
      expect(_selectedShape(bloc.state).label, 'Hi');
    });

    test('arrowhead toggles apply to a linear shape', () async {
      final bloc = await _editorWithShape(CanvasShapeType.line);

      bloc.add(const CanvasUpdateSelectedShapeArrowheads(
        startArrowhead: true,
        endArrowhead: false,
      ));
      await _until(bloc, (s) => _selectedShape(s).startArrowhead);

      final shape = _selectedShape(bloc.state);
      expect(shape.startArrowhead, isTrue);
      expect(shape.endArrowhead, isFalse);
    });

    test('a viewer cannot edit shape stroke width', () async {
      final bloc = await _editorWithShape(CanvasShapeType.rectangle);
      final before = _selectedShape(bloc.state).strokeWidth;

      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
      );
      await _until(bloc, (s) => !s.canEdit);
      bloc.add(const CanvasUpdateSelectedShapeStrokeWidth(12));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(_selectedShape(bloc.state).strokeWidth, before);
    });
  });

  group('CanvasBloc — F-10 CRDT rebuild', () {
    test('rebuild preserves new shape fields and defaults legacy payloads',
        () async {
      final adapter = await CanvasDocAdapterFactory.create();
      adapter.upsertElement('modern', {
        'type': 'shape',
        'z': 0,
        'shapeType': 'rectangle',
        'cx': 100.0,
        'cy': 100.0,
        'size': 200.0,
        'width': 200.0,
        'height': 80.0,
        'color': 0xFF2563EB,
        'strokeWidth': 3.0,
        'strokeOpacity': 0.5,
        'dashPattern': [12.0, 8.0],
        'isFilled': true,
        'label': 'Hello',
        'labelColor': 0xFFF44336,
        'labelFontSize': 20.0,
        'labelFontWeight': 700,
        'labelTextAlign': 'left',
        'startArrowhead': true,
        'endArrowhead': true,
      });
      adapter.upsertElement('legacy', {
        'type': 'shape',
        'z': 1,
        'shapeType': 'arrow',
        'cx': 0.0,
        'cy': 0.0,
        'size': 50.0,
        'color': 0xFF000000,
        'strokeWidth': 2.0,
      });

      final replica = CanvasBloc(crdtAdapter: adapter);
      addTearDown(replica.close);
      replica.add(const CanvasInitializeCrdt('board-x'));
      final state = await _until(
        replica,
        (s) => !s.isLoading && s.elements.length >= 2,
      );

      final modern =
          state.elements.firstWhere((e) => e.id == 'modern') as ShapeElement;
      expect(modern.width, 200);
      expect(modern.height, 80);
      expect(modern.strokeOpacity, 0.5);
      expect(modern.dashPattern, [12, 8]);
      expect(modern.label, 'Hello');
      expect(modern.labelColor, const Color(0xFFF44336));
      expect(modern.labelFontSize, 20);
      expect(modern.labelFontWeight, 700);
      expect(modern.labelTextAlign, 'left');
      expect(modern.startArrowhead, isTrue);
      expect(modern.endArrowhead, isTrue);

      final legacy =
          state.elements.firstWhere((e) => e.id == 'legacy') as ShapeElement;
      expect(legacy.width, 0);
      expect(legacy.height, 0);
      expect(legacy.strokeOpacity, 1);
      expect(legacy.dashPattern, isNull);
      expect(legacy.label, '');
      expect(legacy.labelColor, isNull);
      // Legacy arrows keep their historical end head.
      expect(legacy.endArrowhead, isTrue);
      expect(legacy.startArrowhead, isFalse);
    });
  });
}