import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_element.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends Fake implements NotificationService {}

/// Seeds a canvas with the Select tool active and no elements.
///
/// This runs outside `testWidgets` on purpose: `pumpEventQueue` waits on
/// timers, which never fire inside the widget tester's fake-async zone.
Future<CanvasBloc> _seedBloc({bool withText = false}) async {
  final bloc = CanvasBloc(currentUserId: 'owner-1', boardId: 'board-1');
  bloc.add(
    const CanvasBoardTitleUpdated(
      'Text editing bar',
      currentUserRole: Board.roleOwner,
    ),
  );
  await pumpEventQueue();
  if (withText) {
    bloc.add(
      CanvasAddText(
        topLeft: const Offset(40, 40),
        text: 'Hello board',
        color: Colors.black,
      ),
    );
    await pumpEventQueue();
  }
  bloc.add(const CanvasSetToolMode(CanvasToolMode.select));
  await pumpEventQueue();
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
  }

  testWidgets(
    'selected text element builds the element editing bar',
    (tester) async {
      final bloc = await _seedBloc(withText: true);
      addTearDown(bloc.close);
      final text = bloc.state.elements.whereType<TextElement>().single;
      expect(bloc.state.currentToolMode, CanvasToolMode.select);
      expect(bloc.state.selectedShapeId, text.id);

      await pumpCanvas(tester, bloc);

      // Before the CanvasElement.fromMap payload fix this build threw
      // "type 'Null' is not a subtype of type 'String' in type cast": the text
      // view-model only carried {'rotation': …} and the bar re-parsed it,
      // reading data['type'] as String.
      expect(tester.takeException(), isNull);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'finishing new text keeps it selected and leaves its editing bar open',
    (tester) async {
      final bloc = await _seedBloc();
      addTearDown(bloc.close);
      expect(bloc.state.elements, isEmpty);

      await pumpCanvas(tester, bloc);
      bloc.add(const CanvasSetToolMode(CanvasToolMode.text));
      await tester.pump();

      // Tap empty canvas, type, then finish by tapping elsewhere.
      await tester.tapAt(const Offset(120, 260));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Typed on canvas');
      await tester.pump();

      await tester.tapAt(const Offset(120, 900));
      await tester.pump();

      final text = bloc.state.elements.whereType<TextElement>().single;
      expect(text.text, 'Typed on canvas');
      // The tap that dismissed the editor must not clear the selection, or the
      // user cannot style the text they just wrote.
      expect(bloc.state.selectedShapeId, text.id);
      expect(bloc.state.selectedIds, {text.id});
      expect(bloc.state.currentToolMode, CanvasToolMode.select);
      expect(tester.takeException(), isNull);
      expect(find.text('Edit'), findsOneWidget);

      // Clicking elsewhere afterwards still deselects as usual.
      await tester.tapAt(const Offset(120, 1100));
      await tester.pump();
      expect(bloc.state.selectedShapeId, isNull);
      expect(find.text('Edit'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
