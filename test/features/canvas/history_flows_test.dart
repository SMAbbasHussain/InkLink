import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/crdt/canvas_crdt_adapter.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/models/history/board_operation.dart';
import 'package:inklink/domain/models/history/revert_plan.dart';
import 'package:inklink/domain/models/history/undo_request.dart';
import 'package:inklink/domain/services/history/board_history_service.dart';
import 'package:inklink/features/canvas/bloc/canvas_bloc.dart';
import 'package:inklink/features/canvas/view/trays/canvas_shape_type.dart';

/// Records history calls and returns canned server responses so the workflow
/// rules (D2/D3/D5/D8) can be asserted without a socket or Firestore.
class _FakeHistoryService implements BoardHistoryService {
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
  List<String>? lastUndoUpdateIds;

  HistoryPreview? preview;
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
    lastPlanMode = mode;
    lastPlanTargetVersion = targetVersion;
    lastPlanRequestId = requestId;
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
    DateTime? fromTime,
    DateTime? toTime,
  }) => throw UnimplementedError();

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
}
