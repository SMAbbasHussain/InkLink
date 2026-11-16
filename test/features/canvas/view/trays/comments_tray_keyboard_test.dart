import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/auth_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/comments_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

class _FakeAuthService implements AuthService {
  @override
  String? getCurrentUserId() => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('comment input stays above the keyboard on the canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const keyboardHeight = 420.0;
    final bloc = CanvasBloc(currentUserId: 'me', boardId: 'board-1');
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: RepositoryProvider<AuthService>.value(
          value: _FakeAuthService(),
          child: Scaffold(
            body: BlocProvider<CanvasBloc>.value(
              value: bloc,
              child: const MediaQuery(
                data: MediaQueryData(
                  size: Size(900, 1200),
                  viewInsets: EdgeInsets.only(bottom: keyboardHeight),
                ),
                child: Stack(
                  children: [CommentsTray()],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    bloc.add(const CanvasToggleCommentsTray());
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    expect(input, findsOneWidget);

    // With a 420px keyboard, the input bottom must sit above the keyboard —
    // not behind it.
    final keyboardTop = 1200 - keyboardHeight;
    expect(tester.getBottomLeft(input).dy, lessThanOrEqualTo(keyboardTop));
    expect(tester.getBottomLeft(input).dy, greaterThan(0));
  });
}
