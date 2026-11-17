import 'package:flutter_test/flutter_test.dart';
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

Future<(CanvasBloc, ShapeElement, ShapeElement)> _twoShapes() async {
  final bloc = CanvasBloc();
  _grantEditor(bloc);
  bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(100, 100)));
  bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(300, 300)));
  final state = await _nextWhere(bloc, (s) => s.elements.length == 2);
  final shapes = state.elements.cast<ShapeElement>().toList();
  return (bloc, shapes[0], shapes[1]);
}

void main() {
  test('copying without a selection keeps the clipboard empty', () async {
    final bloc = CanvasBloc();
    addTearDown(bloc.close);
    _grantEditor(bloc);

    bloc.add(const CanvasCopySelection());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(bloc.state.hasClipboard, isFalse);
  });

  test('paste clones the selection with a cascading offset', () async {
    final (bloc, first, _) = await _twoShapes();
    addTearDown(bloc.close);
    bloc.add(CanvasSelectElements({first.id}));
    await _nextWhere(bloc, (s) => s.selectedIds.length == 1);

    bloc.add(const CanvasCopySelection());
    await _nextWhere(bloc, (s) => s.hasClipboard);

    bloc.add(const CanvasPasteSelection());
    var state = await _nextWhere(bloc, (s) => s.elements.length == 3);
    expect(state.selectedIds, hasLength(1));
    final firstPaste = state.elements
        .whereType<ShapeElement>()
        .firstWhere((shape) => state.selectedIds.contains(shape.id));
    expect(firstPaste.center, const Offset(116, 116));
    expect(firstPaste.id, isNot(first.id));

    bloc.add(const CanvasPasteSelection());
    state = await _nextWhere(bloc, (s) => s.elements.length == 4);
    final secondPaste = state.elements
        .whereType<ShapeElement>()
        .firstWhere((shape) => state.selectedIds.contains(shape.id));
    expect(secondPaste.center, const Offset(132, 132));
  });

  test('pasted connectors follow the cloned endpoints', () async {
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
    final linked = await _nextWhere(bloc, (s) => s.elements.length == 3);
    bloc.add(CanvasSelectElements(
      linked.elements.map((element) => element.id).toSet(),
    ));
    await _nextWhere(bloc, (s) => s.selectedIds.length == 3);

    bloc.add(const CanvasCopySelection());
    await _nextWhere(bloc, (s) => s.hasClipboard);
    bloc.add(const CanvasPasteSelection());
    final state = await _nextWhere(bloc, (s) => s.elements.length == 6);

    final clonedConnector = state.elements
        .whereType<ConnectorElement>()
        .firstWhere((connector) => state.selectedIds.contains(connector.id));
    expect(clonedConnector.startElementId, isNotNull);
    expect(clonedConnector.endElementId, isNotNull);
    expect(state.selectedIds, contains(clonedConnector.startElementId));
    expect(state.selectedIds, contains(clonedConnector.endElementId));

    // The original connector still points at the original pair.
    final originalConnector = state.elements
        .whereType<ConnectorElement>()
        .firstWhere((connector) => !state.selectedIds.contains(connector.id));
    expect(originalConnector.startElementId, first.id);
    expect(originalConnector.endElementId, second.id);
  });

  test('viewers cannot paste even after copying', () async {
    final (bloc, first, _) = await _twoShapes();
    addTearDown(bloc.close);
    bloc.add(CanvasSelectElements({first.id}));
    await _nextWhere(bloc, (s) => s.selectedIds.length == 1);
    bloc.add(const CanvasCopySelection());
    await _nextWhere(bloc, (s) => s.hasClipboard);

    bloc.add(
      const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleViewer),
    );
    await _nextWhere(bloc, (s) => s.currentUserRole == Board.roleViewer);
    bloc.add(const CanvasPasteSelection());
    await _nextWhere(bloc, (s) => s.error != null);

    expect(bloc.state.elements, hasLength(2));
  });

  test('locked elements are not copied', () async {
    final (bloc, first, second) = await _twoShapes();
    addTearDown(bloc.close);
    bloc.add(CanvasSetElementLocked(first.id, true));
    await _nextWhere(
      bloc,
      (s) => s.elements.firstWhere((e) => e.id == first.id).locked,
    );

    bloc.add(CanvasSelectElements({first.id, second.id}));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    // The locked element is filtered out; only the unlocked one is selected.
    expect(bloc.state.selectedIds, {second.id});

    bloc.add(const CanvasCopySelection());
    await _nextWhere(bloc, (s) => s.hasClipboard);
    bloc.add(const CanvasPasteSelection());
    final state = await _nextWhere(bloc, (s) => s.elements.length == 3);
    expect(state.selectedIds, hasLength(1));
    final clone = state.elements
        .whereType<ShapeElement>()
        .firstWhere((shape) => state.selectedIds.contains(shape.id));
    expect(clone.center, const Offset(316, 316));
  });
}
