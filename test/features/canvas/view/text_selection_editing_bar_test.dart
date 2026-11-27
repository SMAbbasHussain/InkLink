import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoNotifications implements NotificationService {
  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() =>
      Stream.value(const []);

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

/// Regression: selecting a text element showed the element editing bar,
/// which parsed the text's screen data back with CanvasElement.fromMap.
/// That data held only 'rotation' (no 'type'), so it threw and the whole
/// canvas went blank (grey in release builds).
void main() {
  testWidgets('selecting a text element shows its editing bar without errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final canvas = CanvasBloc(boardId: 'board-1', currentUserId: 'me-1');
    final notifications = NotificationsBloc(
      notificationService: _NoNotifications(),
      notificationPreferences: NotificationPreferences(prefs: prefs),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: canvas),
            BlocProvider.value(value: notifications),
          ],
          child: const CanvasScreen(boardId: 'board-1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    canvas.add(
      const CanvasBoardTitleUpdated('Board', currentUserRole: 'owner'),
    );
    canvas.add(
      const CanvasAddText(
        topLeft: Offset(200, 200),
        text: 'hello web',
        color: Colors.black,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final text = canvas.state.elements.whereType<TextElement>().single;

    canvas.add(const CanvasSetToolMode(CanvasToolMode.select));
    canvas.add(CanvasSelectShape(text.id));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(canvas.state.selectedShapeId, text.id);
    expect(tester.takeException(), isNull);
    // The text editing bar is on screen.
    expect(find.byTooltip('Close editing options'), findsOneWidget);

    // Unmounting closes the canvas bloc (the screen does it in dispose).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
