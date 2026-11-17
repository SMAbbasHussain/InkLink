import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/history/board_activity_block.dart';
import 'package:inklink/domain/models/history/board_operation.dart';
import 'package:inklink/domain/models/history/revert_plan.dart';
import 'package:inklink/domain/models/history/undo_request.dart';
import 'package:inklink/domain/models/history/user_timeline.dart';
import 'package:inklink/domain/services/history/board_history_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// Records history calls and returns canned server responses so the workflow
/// rules (D2/D3/D5/D8) can be asserted without a socket or Firestore.
class _FakeHistoryService extends BoardHistoryService {
  int previewCalls = 0;
  int planCalls = 0;
  int applyCalls = 0;
  int undoOwnCalls = 0;
  int resolveCalls = 0;
  String? lastResolvedStatus;
  int? lastResolvedAppliedVersion;
  String? lastPlanMode;
  int? lastPlanTargetVersion;
  String? lastPlanRequestId;
  UndoRequestArea? lastPlanArea;
  List<String>? lastPlanElementIds;
  List<String>? lastUndoUpdateIds;
  String? lastTimelineTargetUid;
  UndoRequestScopeMode? lastTimelineScopeMode;
  UndoRequestArea? lastTimelineArea;
  List<String>? lastTimelineElementIds;
  int? lastTimelineAfterVersion;
  UserTimeline? timeline;
  int? lastSubmittedTargetVersion;
  UndoRequestScopeMode? lastSubmittedScopeMode;
  UndoRequestArea? lastSubmittedArea;
  List<String>? lastSubmittedElementIds;

  HistoryPreview? preview;
  BoardActivityBlock? liveTail;
  RevertPlan plan = const RevertPlan(
    planId: 'plan_1',
    mode: 'restore',
    baseVersion: 10,
    items: [
      RevertPlanItem(elementId: 'e-1', kind: 'delete'),
    ],
  );
  RevertResult result = const RevertResult(
    appliedVersion: 11,
    reverted: ['e-1'],
  );
  Object? undoOwnError;

  @override
  Future<HistoryPreview> previewVersion(String boardId, int version) async {
    previewCalls++;
    return preview ??
        HistoryPreview(
          version: version,
          stateUpdateBytes: Uint8List(0),
          elementCount: 0,
        );
  }

  @override
  Future<UserTimeline> getUserTimeline(
    String boardId,
    String targetUid, {
    DateTime? fromTime,
    DateTime? toTime,
    int? beforeVersion,
    List<String>? elementIds,
    UndoRequestArea? area,
    UndoRequestScopeMode? scopeMode,
    int? afterVersion,
    int limit = 100,
  }) async {
    lastTimelineTargetUid = targetUid;
    lastTimelineScopeMode = scopeMode;
    lastTimelineArea = area;
    lastTimelineElementIds = elementIds;
    lastTimelineAfterVersion = afterVersion;
    if (timeline != null) return timeline!;
    throw UnimplementedError();
  }

  @override
  Future<RevertPlan> planRevert(
    String boardId, {
    required String mode,
    int? targetVersion,
    String? targetUid,
    DateTime? fromTime,
    DateTime? toTime,
    List<String>? elementIds,
    UndoRequestArea? area,
    UndoRequestScopeMode? scopeMode,
    List<int>? opVersions,
    int? afterVersion,
    String? requestId,
  }) async {
    planCalls++;
    lastPlanMode = mode;
    lastPlanTargetVersion = targetVersion;
    lastPlanRequestId = requestId;
    lastPlanArea = area;
    lastPlanElementIds = elementIds;
    return plan;
  }

  @override
  Future<RevertResult> applyRevert(
    String boardId, {
    required String planId,
    required Map<String, String> decisions,
    String? requestId,
  }) async {
    applyCalls++;
    return result;
  }

  @override
  Future<RevertResult> undoOwn(String boardId, {List<String>? updateIds}) async {
    undoOwnCalls++;
    lastUndoUpdateIds = updateIds;
    if (undoOwnError != null) throw undoOwnError!;
    return result;
  }

  @override
  Future<void> resolveUndoRequest({
    required String boardId,
    required String requestId,
    required String status,
    String? note,
    int? appliedVersion,
  }) async {
    resolveCalls++;
    lastResolvedStatus = status;
    lastResolvedAppliedVersion = appliedVersion;
  }

  @override
  Future<BoardActivityBlock?> getLiveTail(String boardId) async => liveTail;

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
  Future<String> submitUndoRequest({
    required String boardId,
    required List<String> elementIds,
    required String reason,
    required int targetVersion,
    UndoRequestScopeMode scopeMode = UndoRequestScopeMode.myChanges,
    UndoRequestArea? area,
    DateTime? fromTime,
    DateTime? toTime,
  }) async {
    lastSubmittedTargetVersion = targetVersion;
    lastSubmittedScopeMode = scopeMode;
    lastSubmittedArea = area;
    lastSubmittedElementIds = elementIds;
    return 'req-submitted';
  }

  @override
  void dispose() {}
}

Future<void> _settle([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void _setRole(CanvasBloc bloc, String role) {
  bloc.add(CanvasBoardTitleUpdated(null, currentUserRole: role));
}

void main() {
  late _FakeHistoryService history;

  CanvasBloc buildBloc() {
    history = _FakeHistoryService();
    return CanvasBloc(
      historyService: history,
      boardId: 'board-1',
      currentUserId: 'owner-1',
    );
  }

  group('owner-only history access (D3)', () {
    test('owner previews a past version read-only', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      final source = await CanvasCrdtAdapter.create();
      history.preview = HistoryPreview(
        version: 5,
        stateUpdateBytes: source.upsertElement('e-1', {
          'type': 'stroke',
          'z': 1,
          'color': 0xFF000000,
          'strokeWidth': 3.0,
          'opacity': 1.0,
          'brushType': 'solid',
          'points': [
            {'x': 0.0, 'y': 0.0},
            {'x': 5.0, 'y': 5.0},
          ],
        }),
        elementCount: 1,
      );

      bloc.add(const CanvasHistoryPreviewRequested(5));
      await _settle(80);

      expect(history.previewCalls, 1);
      expect(bloc.state.isViewingHistory, isTrue);
      expect(bloc.state.historyPreviewVersion, 5);
      expect(bloc.state.historyPreviewElements.length, 1);
      expect(bloc.state.historyPreviewElements.single.id, 'e-1');

      await bloc.close();
    });

    test('a member cannot open history', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();

      bloc.add(const CanvasHistoryPreviewRequested(5));
      await _settle(80);

      expect(history.previewCalls, 0);
      expect(bloc.state.isViewingHistory, isFalse);
      expect(bloc.state.error, isNotNull);
      expect(bloc.state.error!.toLowerCase(), contains('owner'));

      await bloc.close();
    });

    test('a member cannot plan a revert of another user', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();

      bloc.add(const CanvasHistoryRevertUserRequested('member-2'));
      await _settle(60);

      expect(history.planCalls, 0);
      expect(bloc.state.error, isNotNull);

      await bloc.close();
    });

    test('undo requests are only tracked for the owner', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();

      bloc.add(
        const CanvasUndoRequestsUpdated([
          UndoRequest(
            requestId: 'r',
            boardId: 'board-1',
            requesterUid: 'member-2',
          ),
        ]),
      );
      await _settle();
      expect(bloc.state.undoRequests, isEmpty);

      _setRole(bloc, Board.roleOwner);
      await _settle();
      bloc.add(
        const CanvasUndoRequestsUpdated([
          UndoRequest(
            requestId: 'r',
            boardId: 'board-1',
            requesterUid: 'member-2',
          ),
        ]),
      );
      await _settle();
      expect(bloc.state.undoRequests.length, 1);

      await bloc.close();
    });
  });

  group('preview mode', () {
    test('leaving preview restores the live board', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      bloc.add(const CanvasHistoryPreviewRequested(3));
      await _settle(60);
      expect(bloc.state.isViewingHistory, isTrue);

      bloc.add(const CanvasHistoryPreviewExited());
      await _settle();
      expect(bloc.state.isViewingHistory, isFalse);
      expect(bloc.state.historyPreviewElements, isEmpty);
      expect(bloc.state.historyPreviewVersion, isNull);

      await bloc.close();
    });

    test('edits are rejected while previewing history', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      bloc.add(const CanvasHistoryPreviewRequested(3));
      await _settle(60);

      bloc.add(const CanvasAddShape(CanvasShapeType.square, Offset(10, 10)));
      await _settle();

      expect(bloc.state.elements, isEmpty);
      expect(bloc.state.error, contains('viewing history'));

      await bloc.close();
    });
  });

  group('revert to a previous version', () {
    test('restore request builds a restore plan for that version', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      bloc.add(const CanvasHistoryRestoreRequested(7));
      await _settle(60);

      expect(history.planCalls, 1);
      expect(history.lastPlanMode, 'restore');
      expect(history.lastPlanTargetVersion, 7);
      expect(bloc.state.activeRevertPlan, isNotNull);

      await bloc.close();
    });

    test('applying a plan clears preview mode and reports the result', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      bloc.add(const CanvasHistoryPreviewRequested(4));
      await _settle(60);
      bloc.add(const CanvasHistoryRestoreRequested(4));
      await _settle(60);

      bloc.add(
        const CanvasHistoryApplyRevert(
          planId: 'plan_1',
          decisions: {'e-1': 'revert'},
        ),
      );
      await _settle(80);

      expect(history.applyCalls, 1);
      expect(bloc.state.activeRevertPlan, isNull);
      expect(bloc.state.isViewingHistory, isFalse);
      expect(bloc.state.infoMessage, contains('Reverted'));
      expect(history.resolveCalls, 0, reason: 'no undo request involved');

      await bloc.close();
    });

    test('applying an undo request resolves it as approved', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      bloc.add(const CanvasHistoryUndoRequestReviewRequested('req-1'));
      await _settle(60);
      expect(history.lastPlanRequestId, 'req-1');

      bloc.add(
        const CanvasHistoryApplyRevert(
          planId: 'plan_1',
          decisions: {'e-1': 'revert'},
          requestId: 'req-1',
        ),
      );
      await _settle(80);

      expect(history.resolveCalls, 1);
      expect(history.lastResolvedStatus, 'approved');
      expect(history.lastResolvedAppliedVersion, 11);

      await bloc.close();
    });
  });

  group('member undo of their own edits (D2)', () {
    test('server-side undo reports how many edits were reverted', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();

      bloc.add(const CanvasHistoryUndoOwn());
      await _settle(80);

      expect(history.undoOwnCalls, 1);
      expect(bloc.state.infoMessage, contains('1'));

      await bloc.close();
    });

    test('nothing to undo explains the 15-minute window', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();
      history.undoOwnError = const HistoryServiceException('nothing_to_undo');

      bloc.add(const CanvasHistoryUndoOwn());
      await _settle(80);

      expect(bloc.state.error, contains('15 minutes'));

      await bloc.close();
    });

    test('a member applying a revert plan is refused', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();

      bloc.add(
        const CanvasHistoryApplyRevert(
          planId: 'plan_1',
          decisions: {'e-1': 'revert'},
        ),
      );
      await _settle(60);

      expect(history.applyCalls, 0);
      expect(bloc.state.error, isNotNull);

      await bloc.close();
    });
  });

  group('live tail activity feed sync', () {
    test('prepends live tail block above archived blocks and deduplicates once archived', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      const archived1 = BoardActivityBlock(
        blockId: 'block_000001_000100',
        fromVersion: 1,
        toVersion: 100,
        operationCount: 100,
      );
      const tail = BoardActivityBlock(
        blockId: 'live_tail',
        fromVersion: 101,
        toVersion: 112,
        operationCount: 12,
      );
      history.liveTail = tail;

      bloc.add(const CanvasHistoryFeedUpdated([archived1]));
      await _settle(80);

      expect(bloc.state.activityBlocks.map((b) => b.blockId).toList(), [
        'live_tail',
        'block_000001_000100',
      ]);

      // Simulate snapshot sealing v101..v200 and clearing the live tail in Redis.
      const archived2 = BoardActivityBlock(
        blockId: 'block_000101_000200',
        fromVersion: 101,
        toVersion: 200,
        operationCount: 100,
      );
      history.liveTail = null;
      bloc.add(const CanvasHistoryFeedUpdated([archived2, archived1]));
      await _settle(80);

      expect(bloc.state.activityBlocks.map((b) => b.blockId).toList(), [
        'block_000101_000200',
        'block_000001_000100',
      ]);

      // Also verify even before getLiveTail returns null, a live_tail whose
      // toVersion <= highestArchived is deduplicated immediately.
      history.liveTail = tail; // stale tail v112 <= archived2.toVersion (200)
      bloc.add(const CanvasHistoryFeedRequested());
      await _settle(80);

      expect(bloc.state.activityBlocks.map((b) => b.blockId).toList(), [
        'block_000101_000200',
        'block_000001_000100',
      ]);

      await bloc.close();
    });
  });

  group('area history and undo request slider flows', () {
    test('owner can scrub history of a selected area and revert only that area', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleOwner);
      await _settle();

      final baseAdapter = await CanvasCrdtAdapter.create();
      final step1Bytes = baseAdapter.upsertElement('in-1', {
        'type': 'shape',
        'shapeType': 'square',
        'cx': 40.0,
        'cy': 40.0,
        'size': 30.0,
        'strokeWidth': 2.0,
        'color': 0xFF000000,
      });
      final step2Bytes = baseAdapter.upsertElement('in-1', {
        'type': 'shape',
        'shapeType': 'square',
        'cx': 50.0,
        'cy': 50.0,
        'size': 30.0,
        'strokeWidth': 2.0,
        'color': 0xFFFF0000,
      });

      history.timeline = UserTimeline(
        ops: const [
          BoardOperation(version: 2, summary: 'Added square in-1'),
          BoardOperation(version: 4, summary: 'Moved square in-1'),
        ],
        baseVersion: 1,
        baseStateBytes: Uint8List(0),
        steps: [
          TimelineStep(version: 2, deltaBytes: step1Bytes),
          TimelineStep(version: 4, deltaBytes: step2Bytes),
        ],
      );

      const area = UndoRequestArea(left: 0, top: 0, width: 100, height: 100);
      bloc.add(
        const CanvasHistoryAreaScrubRequested(
          area: area,
          elementIds: ['in-1'],
        ),
      );
      await _settle(120);

      expect(bloc.state.isViewingHistory, isTrue);
      expect(bloc.state.historyScrub, isNotNull);
      expect(bloc.state.historyScrub!.area, area);
      expect(bloc.state.historyScrub!.scopeMode, UndoRequestScopeMode.areaState);
      expect(bloc.state.historyScrub!.stops.length, 3);
      expect(bloc.state.historyScrub!.stepDiffs.length, 3);
      expect(bloc.state.historyScrub!.diffAt(0)!.totalChanges, greaterThan(0));

      // Scrub back to stop 1 (version 2)
      bloc.add(const CanvasHistoryScrubMoved(1));
      await _settle(80);
      expect(bloc.state.historyScrubIndex, 1);

      // Revert only that area to version 2
      bloc.add(
        const CanvasHistoryRestoreRequested(
          2,
          elementIds: ['in-1'],
          area: area,
        ),
      );
      await _settle(80);

      expect(history.lastPlanMode, 'restore');
      expect(history.lastPlanTargetVersion, 2);
      expect(history.lastPlanArea, area);
      expect(history.lastPlanElementIds, ['in-1']);

      await bloc.close();
    });

    test('member can request whole area state on slider and owner can scrub between requested and current state', () async {
      final bloc = buildBloc();
      _setRole(bloc, Board.roleEditor);
      await _settle();

      final baseAdapter = await CanvasCrdtAdapter.create();
      final step1Bytes = baseAdapter.upsertElement('e-1', {
        'type': 'shape',
        'shapeType': 'square',
        'cx': 40.0,
        'cy': 40.0,
        'size': 30.0,
        'strokeWidth': 2.0,
        'color': 0xFF000000,
      });

      history.timeline = UserTimeline(
        ops: const [
          BoardOperation(version: 3, summary: 'Added square e-1'),
        ],
        baseVersion: 2,
        baseStateBytes: Uint8List(0),
        steps: [
          TimelineStep(version: 3, deltaBytes: step1Bytes),
        ],
      );

      const area = UndoRequestArea(left: 0, top: 0, width: 120, height: 120);
      bloc.add(
        const CanvasUndoRequestDraftStarted(
          preselectedIds: ['e-1'],
          area: area,
          scopeMode: UndoRequestScopeMode.areaState,
        ),
      );
      await _settle();
      expect(
        bloc.state.undoRequestDraft?.scopeMode,
        UndoRequestScopeMode.areaState,
      );

      bloc.add(const CanvasUndoRequestPreviewRequested());
      await _settle(120);

      expect(bloc.state.isViewingHistory, isTrue);
      expect(bloc.state.historyScrub, isNotNull);
      expect(bloc.state.historyScrubIndex, 0);
      expect(bloc.state.historyScrub!.diffAt(0)!.addedCount, 1);

      bloc.add(const CanvasUndoRequestSubmitRequested('restore whole section'));
      await _settle(80);

      expect(history.lastSubmittedTargetVersion, 2);
      expect(history.lastSubmittedScopeMode, UndoRequestScopeMode.areaState);
      expect(history.lastSubmittedArea, area);

      // Now switch to owner and open evidence of the request:
      _setRole(bloc, Board.roleOwner);
      await _settle();
      bloc.add(
        const CanvasUndoRequestsUpdated([
          UndoRequest(
            requestId: 'req-area',
            boardId: 'board-1',
            requesterUid: 'member-1',
            requesterName: 'Alice',
            targetElementIds: ['e-1'],
            targetVersion: 2,
            scopeMode: UndoRequestScopeMode.areaState,
            area: area,
            reason: 'restore whole section',
          ),
        ]),
      );
      await _settle();

      bloc.add(const CanvasHistoryRequestEvidenceRequested('req-area'));
      await _settle(120);

      expect(bloc.state.isViewingHistory, isTrue);
      expect(bloc.state.historyPreviewRequestId, 'req-area');
      expect(bloc.state.historyScrub, isNotNull);
      expect(bloc.state.historyScrubIndex, 0, reason: 'starts on requested state');

      // Owner toggles to Current state (jumps slider to lastIndex):
      bloc.add(const CanvasHistoryEvidenceViewToggled(false));
      await _settle(80);
      expect(bloc.state.historyScrubIndex, bloc.state.historyScrub!.lastIndex);

      // Owner toggles back to Requested state (jumps slider to 0):
      bloc.add(const CanvasHistoryEvidenceViewToggled(true));
      await _settle(80);
      expect(bloc.state.historyScrubIndex, 0);

      await bloc.close();
    });
  });
}
