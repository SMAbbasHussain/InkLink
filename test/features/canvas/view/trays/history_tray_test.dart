import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/history/board_activity_block.dart';
import 'package:inklink/domain/models/history/board_operation.dart';
import 'package:inklink/domain/models/history/revert_plan.dart';
import 'package:inklink/domain/models/history/undo_request.dart';
import 'package:inklink/domain/services/history/board_history_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/history_tray.dart';
import 'package:inklink/ui/theme/ink_theme.dart';

class _RecordingHistory implements BoardHistoryService {
  int planCalls = 0;
  String? mode;
  int? targetVersion;

  @override
  Future<RevertPlan> planRevert(
    String boardId, {
    required String mode,
    int? targetVersion,
    String? targetUid,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? elementIds,
    String? requestId,
  }) async {
    planCalls++;
    this.mode = mode;
    this.targetVersion = targetVersion;
    return RevertPlan(
      planId: 'p1',
      mode: mode,
      baseVersion: 5,
      items: const [RevertPlanItem(elementId: 'e', kind: 'update')],
    );
  }

  @override
  Future<List<BoardOperation>> getBlock(String boardId, String blockId) =>
      throw UnimplementedError();

  @override
  Future<UserOpsPage> getUserOps(
    String boardId,
    String targetUid, {
    DateTime? fromTime,
    DateTime? toTime,
    int? beforeVersion,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<HistoryPreview> previewVersion(String boardId, int version) =>
      throw UnimplementedError();

  @override
  Future<RevertResult> applyRevert(
    String boardId, {
    required String planId,
    required Map<String, String> decisions,
    String? requestId,
  }) => throw UnimplementedError();

  @override
  Future<RevertResult> undoOwn(String boardId, {List<String>? updateIds}) =>
      throw UnimplementedError();

  @override
  Future<String> submitUndoRequest({
    required String boardId,
    required List<String> elementIds,
    required String reason,
    DateTime? fromTime,
    DateTime? toTime,
  }) => throw UnimplementedError();

  @override
  Future<void> resolveUndoRequest({
    required String boardId,
    required String requestId,
    required String status,
    String? note,
    int? appliedVersion,
  }) async {}

  @override
  void dispose() {}
}

BoardActivityBlock _block({
  required int from,
  required int to,
  required Map<String, ContributorSummary> summary,
  List<RestoreSummary> restores = const [],
}) {
  return BoardActivityBlock(
    blockId: 'block_$from',
    fromVersion: from,
    toVersion: to,
    operationCount: to - from,
    firstOpAt: DateTime(2026, 1, 1, 10),
    lastOpAt: DateTime(2026, 1, 1, 10, 30),
    contributorUids: summary.keys.toList(),
    summary: summary,
    restores: restores,
  );
}

void main() {
  late CanvasBloc bloc;
  late _RecordingHistory history;

  final blocks = [
    _block(
      from: 1,
      to: 10,
      summary: {
        'alice': const ContributorSummary(
          name: 'Alice',
          ops: 10,
          adds: 4,
          updates: 5,
          deletes: 1,
        ),
      },
    ),
    _block(
      from: 11,
      to: 20,
      summary: {
        'bob': const ContributorSummary(
          name: 'Bob',
          ops: 9,
          adds: 2,
          updates: 7,
        ),
      },
      restores: const [
        RestoreSummary(byUid: 'bob', restoredFromVersion: 3, atVersion: 19),
      ],
    ),
  ];

  final request = UndoRequest(
    requestId: 'req-1',
    boardId: 'board-1',
    requesterUid: 'bob',
    requesterName: 'Bob',
    targetElementIds: const ['e-1', 'e-2'],
    reason: 'removed the wrong layer',
    createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
  );

  final state = CanvasState(
    activityBlocks: blocks,
    undoRequests: [request],
  );

  setUp(() {
    history = _RecordingHistory();
    bloc = CanvasBloc(
      historyService: history,
      boardId: 'board-1',
      currentUserId: 'owner-1',
    );
  });

  tearDown(() => bloc.close());

  Future<void> pumpTray(WidgetTester tester) async {
    // Tall viewport so every version row is built (the tray keeps a fixed
    // height and the list only builds what fits).
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: InkTheme.light(),
        home: Scaffold(
          body: Stack(
            children: [
              HistoryTray(
                isOpen: true,
                boardId: 'board-1',
                state: state,
                bloc: bloc,
                historyService: history,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the version summary, blocks and pending requests', (
    tester,
  ) async {
    await pumpTray(tester);

    expect(find.textContaining('Latest v20'), findsOneWidget);
    expect(find.textContaining('2 version(s)'), findsOneWidget);
    expect(find.textContaining('1 request(s)'), findsOneWidget);
    expect(find.text('v1–v10'), findsOneWidget);
    expect(find.textContaining('4 added'), findsOneWidget);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('removed the wrong layer'), findsOneWidget);
    expect(find.text('2 element(s)'), findsOneWidget);

    // The tray is a fixed-height list: later versions need scrolling.
    await tester.scrollUntilVisible(
      find.text('v11–v20'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('v11–v20'), findsOneWidget);
  });

  testWidgets('marks restored blocks and filters to them', (tester) async {
    await pumpTray(tester);

    await tester.tap(find.text('Restores'));
    await tester.pumpAndSettle();

    expect(find.text('v11–v20'), findsOneWidget);
    expect(find.text('restored to v3'), findsOneWidget);
    expect(find.text('v1–v10'), findsNothing);
  });

  testWidgets('the requests filter hides versions', (tester) async {
    await pumpTray(tester);

    await tester.tap(find.textContaining('Requests'));
    await tester.pumpAndSettle();

    expect(find.text('v1–v10'), findsNothing);
    expect(find.text('v11–v20'), findsNothing);
    expect(find.text('removed the wrong layer'), findsOneWidget);
  });

  testWidgets('search narrows versions by contributor name', (tester) async {
    await pumpTray(tester);

    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pumpAndSettle();

    expect(find.text('v1–v10'), findsOneWidget);
    expect(find.text('v11–v20'), findsNothing);
  });

  testWidgets('restoring a version asks for confirmation then plans it', (
    tester,
  ) async {
    await pumpTray(tester);
    bloc.add(const CanvasBoardTitleUpdated(null, currentUserRole: Board.roleOwner));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.ellipsisVertical).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore to this version…'));
    await tester.pumpAndSettle();

    expect(find.text('Restore this version?'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(history.planCalls, 1);
    expect(history.mode, 'restore');
    expect(history.targetVersion, 10);
  });
}
