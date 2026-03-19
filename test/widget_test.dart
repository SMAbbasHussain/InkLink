import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';

void main() {
  test('CanvasBloc toggles tray state', () async {
    final bloc = CanvasBloc();

    expect(bloc.state.activeTray, isNull);

    bloc.add(const CanvasToggleTray('tools'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.activeTray, 'tools');

    bloc.add(const CanvasToggleTray('tools'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.activeTray, isNull);

    await bloc.close();
  });
}
