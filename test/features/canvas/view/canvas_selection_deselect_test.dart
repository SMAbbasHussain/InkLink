import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService implements NotificationService {
  final controller =
      StreamController<List<Map<String, dynamic>>>.broadcast(sync: true);

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() => controller.stream;

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

Future<void> _pumpCanvas(
  WidgetTester tester,
  CanvasBloc bloc,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  final notificationService = _FakeNotificationService();
  final notificationsBloc = NotificationsBloc(
    notificationService: notificationService,
    notificationPreferences: NotificationPreferences(prefs: prefs!),
  );
  addTearDown(() async {
    await notificationsBloc.close();
    await notificationService.controller.close();
  });

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<CanvasBloc>.value(value: bloc),
        BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
      ],
      child: MaterialApp(
        theme: InkTheme.light(),
        home: const CanvasScreen(boardId: 'board-1'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<CanvasBloc> _seededBloc(WidgetTester tester) async {
  final bloc = CanvasBloc();
  addTearDown(() => bloc.close());

  bloc.add(
    const CanvasBoardTitleUpdated(
      'Test',
      currentUserRole: Board.roleEditor,
    ),
  );
  bloc.add(
    const CanvasAddShape(CanvasShapeType.rectangle, Offset(100, 300)),
  );
  bloc.add(
    const CanvasAddShape(CanvasShapeType.rectangle, Offset(300, 300)),
  );
  bloc.add(
    const CanvasAddShape(CanvasShapeType.rectangle, Offset(500, 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return bloc;
}

void main() {
  testWidgets(
    'clicking outside multi-selection deselects while clicking inside keeps it',
    (tester) async {
      final bloc = await _seededBloc(tester);
      final s1 = bloc.state.elements[0];
      final s2 = bloc.state.elements[1];
      final s3 = bloc.state.elements[2];

      bloc.add(const CanvasSetToolMode(CanvasToolMode.select));
      bloc.add(CanvasSelectElements({s1.id, s2.id}));
      await tester.pump();

      await _pumpCanvas(tester, bloc);

      // Middle shape s2 (selected) sits at screen center (400, 300).
      // Single tapping a selected item keeps the multi-selection.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.state.selectedIds, {s1.id, s2.id});

      // Single tapping clear board (no element) deselects all selected items.
      await tester.tapAt(const Offset(400, 140));
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.state.selectedIds, isEmpty);
      expect(bloc.state.selectedShapeId, isNull);

      // Select {s1, s3} and single tap the unselected middle shape s2.
      bloc.add(CanvasSelectElements({s1.id, s3.id}));
      await tester.pump();
      await tester.pump();

      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(bloc.state.selectedIds, isEmpty);
      expect(bloc.state.selectedShapeId, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'double tapping clear board in select mode deselects all selected items',
    (tester) async {
      final bloc = await _seededBloc(tester);
      final s1 = bloc.state.elements[0];
      final s2 = bloc.state.elements[1];
      final s3 = bloc.state.elements[2];

      bloc.add(const CanvasSetToolMode(CanvasToolMode.select));
      bloc.add(CanvasSelectElements({s1.id, s3.id}));
      await tester.pump();

      await _pumpCanvas(tester, bloc);

      // Double tap on clear board (top-center empty space) deselects all.
      await tester.tapAt(const Offset(400, 140));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(400, 140));
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.state.selectedIds, isEmpty);
      expect(bloc.state.selectedShapeId, isNull);

      // Double tapping an element still selects it cleanly.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.state.selectedIds, {s2.id});
      expect(bloc.state.selectedShapeId, s2.id);

      // Double tap clear board also deselects a single selected item.
      await tester.tapAt(const Offset(400, 140));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(const Offset(400, 140));
      await tester.pump(const Duration(milliseconds: 350));
      expect(bloc.state.selectedIds, isEmpty);
      expect(bloc.state.selectedShapeId, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
