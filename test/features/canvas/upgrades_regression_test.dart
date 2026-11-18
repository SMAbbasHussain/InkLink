import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/canvas/board_template.dart';
import 'package:inklink/domain/models/canvas/canvas_board_settings.dart';
import 'package:inklink/domain/models/canvas/canvas_export_options.dart';
import 'package:inklink/domain/models/history/undo_request.dart';
import 'package:inklink/domain/services/board/board_service.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';
import 'package:inklink/domain/services/profile/profile_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/geometry/canvas_element_geometry.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';
import 'package:inklink/domain/models/canvas/canvas_toolbar_action.dart';
import 'package:inklink/features/canvas/view/trays/canvas_actions_tray.dart';
import 'package:inklink/features/canvas/view/widgets/template_gallery_sheet.dart';
import 'package:inklink/features/canvas/view/widgets/undo_request_sheet.dart';
import 'package:inklink/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

class _FakeCanvasService extends Fake implements CanvasService {
  final writes = StreamController<Uint8List>.broadcast(sync: true);

  @override
  String? get currentClientId => 'author';
  @override
  Stream<Board?> watchBoardById(String id) => const Stream.empty();
  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String id) =>
      const Stream.empty();
  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String id) =>
      const Stream.empty();
  @override
  Future<void> stopCrdtRemoteSync(String id) async {}
  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) async {}
  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) async {
    writes.add(payload);
  }
}

class _FakeBoardService extends Fake implements BoardService {
  @override
  Future<void> startBoardsSync() async {}

  @override
  Stream<List<Board>> getOwnedBoards() => Stream.value(const []);

  @override
  Stream<List<Board>> getJoinedBoards() => Stream.value(const []);

  @override
  Future<void> stopBoardsSync() async {}

  @override
  Future<CreateBoardResult> createBoard({
    String? title,
    required String visibility,
    required String privateJoinPolicy,
    String whoCanInvite = Board.inviteOwnerOnly,
    String defaultLinkJoinRole = Board.roleViewer,
    String inviteTargetRole = Board.roleViewer,
    List<String> tags = const [],
    bool allowMembersToCopy = false,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) async {
    return const CreateBoardResult(boardId: 'new-board-1');
  }
}

class _FakeProfileService extends Fake implements ProfileService {}

Future<CanvasState> _until(CanvasBloc bloc, bool Function(CanvasState) test) =>
    bloc.stream.firstWhere(test).timeout(const Duration(seconds: 3));

void main() {
  group('F-10 Separate stroke color + flipH/flipV', () {
    test('Given shape with independent outline and flips, When updated & exported to SVG, Then label stays unmirrored while shape flips', () async {
      final bloc = CanvasBloc();
      addTearDown(bloc.close);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);

      bloc.add(const CanvasAddShape(CanvasShapeType.arrow, Offset(120, 120)));
      await _until(bloc, (s) => s.selectedShapeId != null);

      bloc.add(
        const CanvasUpdateSelectedShapeStrokeColor(Color(0xFFDC2626)),
      );
      await _until(
        bloc,
        (s) =>
            (s.elements.single as ShapeElement).strokeColor ==
            const Color(0xFFDC2626),
      );

      bloc.add(const CanvasFlipSelectedShape(horizontal: true));
      await _until(bloc, (s) => (s.elements.single as ShapeElement).flipH);
      bloc.add(const CanvasUpdateSelectedShapeLabel(label: 'Next'));
      await _until(
        bloc,
        (s) => (s.elements.single as ShapeElement).label == 'Next',
      );

      final shape = bloc.state.elements.single as ShapeElement;
      final svg = const BoardExportServiceImpl().renderToSvg('Flipped', [shape]);
      expect(svg, contains('scale(-1 1)'));
      expect(svg.toLowerCase(), contains('#dc2626'));
      expect(svg, contains('>Next</text>'));
    });
  });

  group('F-14 Frame clipping & delete-with-contents', () {
    test('Given frame with clipContents & children, When exported or deleted with contents, Then clipping & batch delete apply', () async {
      final adapter = await CanvasDocAdapterFactory.create();
      const frame = FrameElement(
        id: 'fr1',
        z: 0,
        center: Offset(200, 200),
        width: 240,
        height: 180,
        title: 'Clip Box',
        clipContents: true,
      );
      const inside = StickyNoteElement(
        id: 'in1',
        z: 1,
        center: Offset(200, 200),
        width: 80,
        height: 80,
        text: 'Inside note',
      );
      const outside = StickyNoteElement(
        id: 'out1',
        z: 2,
        center: Offset(700, 700),
        width: 80,
        height: 80,
        text: 'Outside note',
      );
      adapter.applyBatch([
        (id: frame.id, payload: frame.toMap()),
        (id: inside.id, payload: inside.toMap()),
        (id: outside.id, payload: outside.toMap()),
      ], origin: 'remote');

      expect(enclosingClipFrame(inside, [frame])?.id, 'fr1');
      expect(enclosingClipFrame(outside, [frame]), isNull);

      final svg = const BoardExportServiceImpl().renderToSvg(
        'Clipped',
        const [frame, inside, outside],
      );
      expect(svg, contains('<clipPath id="frameclip_'));
      expect(svg, contains('clip-path="url(#frameclip_'));

      final service = _FakeCanvasService();
      final bloc = CanvasBloc(
        crdtAdapter: adapter,
        canvasService: service,
        boardId: 'b',
      );
      addTearDown(() async {
        await bloc.close();
        await service.writes.close();
      });
      bloc.add(const CanvasInitializeCrdt('b'));
      await _until(bloc, (s) => !s.isLoading && s.elements.length == 3);
      bloc.add(
        const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleEditor),
      );
      await _until(bloc, (s) => s.canEdit);

      // Delete frame & contents in one batch
      bloc.add(const CanvasDeleteFrame('fr1', deleteContents: true));
      await _until(bloc, (s) => s.elements.length == 1);
      expect(bloc.state.elements.single.id, 'out1');

      // Single undo restores both frame & contained note
      bloc.add(const CanvasUndo());
      await _until(bloc, (s) => s.elements.length == 3);
    });
  });

  group('F-19 / F-22 Page export scope & background pattern', () {
    test('Given page bounds & pattern, When buildExportPlan & renderToSvg run, Then exact page pixel dimensions and pattern toggle apply', () {
      const service = BoardExportServiceImpl();
      const settings = CanvasBoardSettings(
        backgroundPattern: CanvasBackgroundPattern.dots,
        patternSpacing: 24,
        pageWidth: 800,
        pageHeight: 600,
        pageBoundsEnabled: true,
      );
      const note = StickyNoteElement(
        id: 'n1',
        z: 0,
        center: Offset(100, 50),
        text: 'Hello',
      );

      final plan = service.buildExportPlan(
        elements: const [note],
        options: const CanvasExportOptions(
          scope: CanvasExportScope.page,
          scale: 2,
          includePattern: true,
        ),
        settings: settings,
      );
      expect(plan.widthPixels, 1600);
      expect(plan.heightPixels, 1200);

      final svgWithPat = service.renderToSvg(
        'Pat',
        const [note],
        settings: settings,
        includePattern: true,
      );
      final svgNoPat = service.renderToSvg(
        'NoPat',
        const [note],
        settings: settings,
        includePattern: false,
      );
      expect(svgWithPat, contains('id="boardPattern"'));
      expect(svgNoPat, isNot(contains('id="boardPattern"')));
    });
  });

  group('F-15 & F-16 & History/Undo UI widgets', () {
    testWidgets('TemplateGallerySheet shows category filter chips and filters list', (tester) async {
      const templates = [
        BoardTemplate(
          id: 'i1',
          name: 'Idea Map',
          description: 'Brainstorming',
          category: 'Ideas',
        ),
        BoardTemplate(
          id: 'd1',
          name: 'Flowchart',
          description: 'Process diagram',
          category: 'Diagram',
        ),
      ];
      BoardTemplate? chosen;

      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: TemplateGallerySheet(
              templates: templates,
              onSelected: (t) => chosen = t,
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);
      expect(find.text('Diagram'), findsOneWidget);

      await tester.tap(find.text('Diagram'));
      await tester.pumpAndSettle();

      expect(find.text('Flowchart'), findsOneWidget);
      expect(find.text('Idea Map'), findsNothing);

      await tester.tap(find.text('Flowchart'));
      await tester.pump();
      expect(chosen?.id, 'd1');
    });

    testWidgets('CanvasActionsTray shows Table button for editors and invokes callback', (tester) async {
      CanvasToolbarAction? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                CanvasActionsTray(
                  isOpen: true,
                  canEdit: true,
                  onActionSelected: (action) => tapped = action,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Table'), findsOneWidget);
      await tester.tap(find.text('Table'));
      await tester.pump();
      expect(tapped, CanvasToolbarAction.table);
    });

    testWidgets('UndoRequestSendSheet displays scope mode & diff summary cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: InkTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showUndoRequestSendSheet(
                    context,
                    targetVersion: 12,
                    stopLabel: 'Before edits (v12)',
                    elementCount: 2,
                    canSend: true,
                    scopeMode: UndoRequestScopeMode.areaState,
                    diffSummary: '+1 added · 1 modified',
                    onSubmit: (_) {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Restore to version 12'), findsOneWidget);
      expect(
        find.text('Scope: ${UndoRequestScopeMode.areaState.label}'),
        findsOneWidget,
      );
      expect(find.text('+1 added · 1 modified'), findsOneWidget);
    });

    test('UndoRequest & UndoRequestArea preserve scopeMode & area bounds', () {
      const bounds = UndoRequestArea(left: -10, top: 20, width: 100, height: 100);
      final req = UndoRequest(
        requestId: 'r1',
        boardId: 'b1',
        requesterUid: 'u2',
        requesterName: 'Bob',
        targetElementIds: const ['e1'],
        targetVersion: 5,
        reason: 'oops',
        status: 'pending',
        createdAt: DateTime(2026, 11, 17),
        scopeMode: UndoRequestScopeMode.areaState,
        area: bounds,
      );
      final roundTripped = UndoRequest.fromMap(req.requestId, req.toMap());
      expect(roundTripped.scopeMode, UndoRequestScopeMode.areaState);
      expect(roundTripped.area, bounds);
    });

    test('DashboardBloc forwards initialTemplateId on board creation and consumes it', () async {
      final dashboardBloc = DashboardBloc(
        boardService: _FakeBoardService(),
        profileService: _FakeProfileService(),
      );
      addTearDown(dashboardBloc.close);

      dashboardBloc.add(LoadDashboardRequested());
      await dashboardBloc.stream.firstWhere((s) => s is DashboardLoaded);

      dashboardBloc.add(
        DashboardCreateBoardRequested(
          title: 'Brainstorm Board',
          visibility: Board.visibilityPrivate,
          privateJoinPolicy: Board.policyOwnerOnlyInvite,
          initialTemplateId: 'brainstorm',
        ),
      );
      final createdState = await dashboardBloc.stream.firstWhere(
        (s) => s is DashboardLoaded && s.createdBoardId != null,
      ) as DashboardLoaded;
      expect(createdState.createdBoardId, 'new-board-1');
      expect(createdState.pendingTemplateId, 'brainstorm');

      dashboardBloc.add(DashboardConsumeEffects());
      final consumed = await dashboardBloc.stream.firstWhere(
        (s) => s is DashboardLoaded && s.createdBoardId == null,
      ) as DashboardLoaded;
      expect(consumed.pendingTemplateId, isNull);
    });
  });
}
