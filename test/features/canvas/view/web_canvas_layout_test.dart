import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/utils/notification_preferences.dart';
import 'package:inklink/domain/services/notification/notification_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/models/canvas_tool_mode.dart';
import 'package:inklink/features/canvas/view/canvas_screen.dart';
import 'package:inklink/features/canvas/view/widgets/sliding_tray.dart';
import 'package:inklink/features/notifications/bloc/notifications_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/repositories/board/board_repository.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository_impl.dart';
import 'package:inklink/domain/repositories/canvas/memory_crdt_local_store.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';

import '../../../domain/repositories/canvas/crdt_store_test_support.dart';

class _NoNotifications implements NotificationService {
  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() =>
      Stream.value(const []);

  @override
  Future<void> deleteNotification(String notificationId) async {}
}

class _BoardRepository implements BoardRepository {
  @override
  Stream<Board?> getBoardById(String boardId) => Stream.value(null);

  @override
  Future<void> ensureBoardCached(String boardId) async {}

  @override
  Future<void> deactivateBoard() async {}

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}

/// The board's desktop-browser layout and its keyboard shortcuts, rendered
/// with the web layout switched on (tests run outside a browser). The same
/// screen with it off is the phone layout.
void main() {
  late CanvasBloc canvas;

  Future<void> pumpCanvas(
    WidgetTester tester, {
    required bool web,
    bool withHistory = false,
  }) async {
    SlidingTray.debugWebLayoutOverride = web;
    addTearDown(() => SlidingTray.debugWebLayoutOverride = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // With history: the real canvas service on the in-memory store, so
    // undo works (it replays the sync history).
    canvas = withHistory
        ? CanvasBloc(
            canvasService: CanvasServiceImpl(
              boardRepository: _BoardRepository(),
              syncRepository: FirestoreCanvasSyncRepository(
                authService: SignedOutAuthService(),
                store: MemoryCrdtLocalStore(),
              ),
            ),
            boardId: 'board-1',
            currentUserId: 'me-1',
          )
        : CanvasBloc(boardId: 'board-1', currentUserId: 'me-1');
    if (withHistory) canvas.add(const CanvasInitializeCrdt('board-1'));
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
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Unmounting closes the canvas bloc (the screen does it in dispose).
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<String> addText(WidgetTester tester) async {
    canvas.add(
      const CanvasAddText(
        topLeft: Offset(300, 300),
        text: 'hello',
        color: Colors.black,
      ),
    );
    await settle(tester);
    return canvas.state.elements.whereType<TextElement>().single.id;
  }

  testWidgets('web layout: corner bars and the tool rail', (tester) async {
    await pumpCanvas(tester, web: true);
    expect(find.byTooltip('Exit canvas'), findsOneWidget);
    expect(find.byTooltip('Export board'), findsOneWidget);
    expect(find.byTooltip('Share board'), findsOneWidget);
    expect(find.byTooltip('Pen'), findsOneWidget); // rail
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('phone layout is unchanged when the web layout is off', (
    tester,
  ) async {
    await pumpCanvas(tester, web: false);
    expect(find.byTooltip('Export board'), findsNothing);
    expect(find.byTooltip('Share board'), findsNothing);
    expect(find.byTooltip('Find on board'), findsOneWidget); // phone top bar
    await finish(tester);
  });

  testWidgets('tool keys switch tools', (tester) async {
    await pumpCanvas(tester, web: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await settle(tester);
    expect(canvas.state.currentToolMode, CanvasToolMode.hand);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await settle(tester);
    expect(canvas.state.currentToolMode, CanvasToolMode.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await settle(tester);
    expect(canvas.state.currentToolMode, CanvasToolMode.eraser);
    await finish(tester);
  });

  testWidgets('Delete removes the selection and Ctrl+Z brings it back', (
    tester,
  ) async {
    await pumpCanvas(tester, web: true, withHistory: true);
    final id = await addText(tester);
    canvas.add(const CanvasSetToolMode(CanvasToolMode.select));
    canvas.add(CanvasSelectShape(id));
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
    expect(canvas.state.elements.whereType<TextElement>(), isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(canvas.state.elements.whereType<TextElement>(), hasLength(1));
    await finish(tester);
  });

  testWidgets('Escape clears the selection, Ctrl+A selects everything', (
    tester,
  ) async {
    await pumpCanvas(tester, web: true);
    final id = await addText(tester);
    canvas.add(const CanvasSetToolMode(CanvasToolMode.select));
    canvas.add(CanvasSelectShape(id));
    await settle(tester);
    expect(canvas.state.selectedShapeId, id);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(canvas.state.selectedShapeId, isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(canvas.state.selectedIds, contains(id));
    await finish(tester);
  });

  testWidgets('shortcuts are off on phones', (tester) async {
    await pumpCanvas(tester, web: false);
    final before = canvas.state.currentToolMode;
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await settle(tester);
    expect(canvas.state.currentToolMode, before);
    await finish(tester);
  });
}
