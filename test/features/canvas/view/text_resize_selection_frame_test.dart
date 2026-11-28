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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoNotifications implements NotificationService {
  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() =>
      Stream.value(const []);

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

/// Regression: resizing a selected text element must move/resize its selection
/// frame with the text box, not leave the frame at the old size until the
/// element is reselected.
void main() {
  testWidgets('the selection frame follows a text resize', (tester) async {
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

    canvas.add(const CanvasBoardTitleUpdated('Board', currentUserRole: 'owner'));
    canvas.add(
      const CanvasAddText(
        topLeft: Offset(200, 200),
        text: 'a fairly long line of text that wraps when narrowed',
        color: Colors.black,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final text = canvas.state.elements.whereType<TextElement>().single;

    canvas.add(const CanvasSetToolMode(CanvasToolMode.select));
    canvas.add(CanvasSelectShape(text.id));
    await tester.pump(const Duration(milliseconds: 300));

    final handle = find.byIcon(LucideIcons.maximize2);
    expect(handle, findsOneWidget, reason: 'the resize handle is on screen');
    final beforeHandle = tester.getCenter(handle);
    final beforeWidth = text.width;

    // Drag the bottom-right resize handle to the right.
    await tester.drag(handle, const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 400));

    final resized = canvas.state.elements.whereType<TextElement>().single;
    expect(
      resized.width,
      greaterThan(beforeWidth),
      reason: 'the drag should widen the text box',
    );

    final afterHandle = tester.getCenter(handle);
    // The frame is anchored at the text's top-left, so its bottom-right corner
    // (where the handle lives) must travel right with the new width.
    expect(
      afterHandle.dx,
      greaterThan(beforeHandle.dx + 20),
      reason: 'the selection frame must follow the resized text box',
    );

    // Unmounting closes the canvas bloc (the screen does it in dispose).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
