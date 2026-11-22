import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends Fake implements NotificationService {}

/// Seeds a canvas with the Select tool active.
Future<CanvasBloc> _seedBloc(
  WidgetTester tester, {
  bool withText = false,
}) async {
  final bloc = CanvasBloc(currentUserId: 'owner-1', boardId: 'board-1');
  bloc.add(
    const CanvasBoardTitleUpdated(
      'Text editing bar',
      currentUserRole: Board.roleOwner,
    ),
  );
  await tester.pump();
  if (withText) {
    bloc.add(
      CanvasAddText(
        topLeft: const Offset(40, 40),
        text: 'Hello board',
        color: Colors.black,
      ),
    );
    await tester.pump();
  }
  bloc.add(const CanvasSetToolMode(CanvasToolMode.select));
  await tester.pump();
  return bloc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Widget wrap(CanvasBloc bloc) {
    return MaterialApp(
      theme: InkTheme.light(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CanvasBloc>.value(value: bloc),
          BlocProvider<NotificationsBloc>(
            create: (_) => NotificationsBloc(
              notificationService: _FakeNotificationService(),
              notificationPreferences: NotificationPreferences(prefs: prefs),
            ),
          ),
        ],
        child: const CanvasScreen(boardId: 'board-1'),
      ),
    );
  }

  Future<void> pumpCanvas(WidgetTester tester, CanvasBloc bloc) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(bloc));
    await tester.pump();
    if (bloc.state.isLoading) {
      await tester.runAsync(
        () => bloc.stream.firstWhere((s) => !s.isLoading),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'selected text element builds the element editing bar',
    timeout: const Timeout(Duration(seconds: 5)),
    (tester) async {
      final bloc = await _seedBloc(tester, withText: true);
      final text = bloc.state.elements.whereType<TextElement>().single;
      expect(bloc.state.currentToolMode, CanvasToolMode.select);
      expect(bloc.state.selectedShapeId, text.id);

      await pumpCanvas(tester, bloc);

      // Before the CanvasElement.fromMap payload fix this build threw
      // "type 'Null' is not a subtype of type 'String' in type cast": the text
      // view-model only carried {'rotation': …} and the bar re-parsed it,
      // reading data['type'] as String.
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Size'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      bloc.close();
      await tester.pump();
    },
  );

  testWidgets(
    'finishing new text keeps it selected and leaves its editing bar open',
    (tester) async {
      final bloc = await _seedBloc(tester);
      expect(bloc.state.elements, isEmpty);

      await pumpCanvas(tester, bloc);
      bloc.add(const CanvasSetToolMode(CanvasToolMode.text));
      await tester.pump();
      await tester.pump();

      // Tap empty canvas, type, then finish by tapping elsewhere.
      await tester.tapAt(const Offset(120, 260));
      await tester.pump(const Duration(milliseconds: 350));
      final textEditorFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Type text',
      );
      expect(textEditorFinder, findsOneWidget);
      await tester.enterText(textEditorFinder, 'Typed on canvas');
      await tester.pump();

      await tester.tapAt(const Offset(120, 900));
      await tester.pumpAndSettle();

      final text = bloc.state.elements.whereType<TextElement>().single;
      expect(text.text, 'Typed on canvas');
      // The tap that dismissed the editor must not clear the selection, or the
      // user cannot style the text they just wrote.
      expect(bloc.state.selectedShapeId, text.id);
      expect(bloc.state.selectedIds, {text.id});
      expect(bloc.state.currentToolMode, CanvasToolMode.select);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Edit'), findsOneWidget);

      // Clicking elsewhere afterwards still deselects as usual (wait past the
      // 500ms post-commit wall-clock guard in CanvasScreen).
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 550)),
      );
      await tester.tapAt(const Offset(120, 1100));
      await tester.pumpAndSettle();
      expect(bloc.state.selectedShapeId, isNull);
      expect(find.byTooltip('Edit'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      bloc.close();
      await tester.pump();
    },
  );
}
