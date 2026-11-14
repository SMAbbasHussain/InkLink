import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/domain/models/history/board_activity_block.dart';
import 'package:inklink/domain/models/history/board_operation.dart';
import 'package:inklink/domain/models/history/revert_plan.dart';
import 'package:inklink/domain/models/history/undo_request.dart';

/// Behaviour locked here comes from BOARD_VERSION_HISTORY_AND_AUDIT_LOG_PLAN.md:
/// archived blocks (§5.2), ops (§5.5), undo requests (§8.1) and revert plans
/// (§7.3). The models must tolerate documents written by an older schema, so
/// every optional field is exercised with a missing/null value.
void main() {
  group('BoardOperation', () {
    test('parses an archived op with derived changes', () {
      final op = BoardOperation.fromMap({
        'version': 42,
        'updateId': 'u-1',
        'userId': 'alice',
        'userDisplayName': 'Alice',
        'userPhotoUrl': 'https://x/a.png',
        'elementId': 'e-1',
        'action': 'upsert',
        'changes': [
          {'elementId': 'e-1', 'kind': 'add'},
          {'elementId': 'e-2', 'kind': 'delete'},
        ],
        'payloadBase64': 'AAAA',
        'timestamp': '2026-01-02T03:04:05.000Z',
      });

      expect(op.version, 42);
      expect(op.userId, 'alice');
      expect(op.userDisplayName, 'Alice');
      expect(op.changes.map((c) => c.kind), ['add', 'delete']);
      expect(op.timestamp, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(op.restoredFromVersion, isNull);
    });

    test('falls back to sourceClientId for pre-stamp entries', () {
      final op = BoardOperation.fromMap({
        'version': 1,
        'sourceClientId': 'legacy-uid',
      });
      expect(op.userId, 'legacy-uid');
      expect(op.action, 'upsert');
      expect(op.changes, isEmpty);
      expect(op.userDisplayName, 'InkLink User');
    });

    test('keeps restore provenance', () {
      final op = BoardOperation.fromMap({
        'version': 9,
        'action': 'restore',
        'restoredFromVersion': 3,
      });
      expect(op.action, 'restore');
      expect(op.restoredFromVersion, 3);
    });

    test('round-trips through toMap', () {
      final op = BoardOperation(
        version: 7,
        updateId: 'u',
        userId: 'bob',
        action: 'revert',
        changes: const [ElementChange(elementId: 'e', kind: 'update')],
        timestamp: DateTime.utc(2026, 5, 6),
        restoredFromVersion: 2,
      );
      final again = BoardOperation.fromMap(op.toMap());
      expect(again.version, 7);
      expect(again.action, 'revert');
      expect(again.changes.single.elementId, 'e');
      expect(again.timestamp, op.timestamp);
      expect(again.restoredFromVersion, 2);
    });
  });

  group('BoardActivityBlock', () {
    test('parses summary, contributors and restores', () {
      final block = BoardActivityBlock.fromMap({
        'blockId': 'block_000001_000500',
        'fromVersion': 1,
        'toVersion': 500,
        'operationCount': 499,
        'contributorUids': ['alice', 'bob'],
        'summary': {
          'alice': {
            'name': 'Alice',
            'ops': 300,
            'adds': 10,
            'updates': 280,
            'deletes': 10,
          },
          'bob': {'name': 'Bob', 'ops': 199},
        },
        'r2BlockKey': 'board/block_000001_000500',
        'milestoneVersion': 500,
        'restores': [
          {'byUid': 'alice', 'restoredFromVersion': 12, 'atVersion': 480},
        ],
      });

      expect(block.fromVersion, 1);
      expect(block.toVersion, 500);
      expect(block.contributorUids, ['alice', 'bob']);
      expect(block.summary['alice']!.deletes, 10);
      expect(block.summary['bob']!.adds, 0);
      expect(block.milestoneVersion, 500);
      expect(block.restores.single.restoredFromVersion, 12);
      expect(block.summaryTruncated, isFalse);
    });

    test('accepts Firestore timestamps and ignores junk entries', () {
      final block = BoardActivityBlock.fromMap({
        'blockId': 'b',
        'firstOpAt': _FakeTimestamp(DateTime.utc(2026, 1, 1, 10)),
        'lastOpAt': '2026-01-01T10:05:00.000Z',
        'summary': {'x': 'not-a-map'},
        'contributorUids': ['x', 5, null],
      });

      expect(block.firstOpAt, DateTime.utc(2026, 1, 1, 10));
      expect(block.lastOpAt, DateTime.utc(2026, 1, 1, 10, 5));
      expect(block.summary, isEmpty);
      expect(block.contributorUids, ['x']);
    });

    test('empty map yields safe defaults', () {
      final block = BoardActivityBlock.fromMap(const {});
      expect(block.blockId, '');
      expect(block.fromVersion, 0);
      expect(block.restores, isEmpty);
      expect(block.r2BlockKey, '');
    });
  });

  group('UndoRequest', () {
    test('parses a pending request', () {
      final request = UndoRequest.fromMap('req-1', {
        'requestId': 'req-1',
        'boardId': 'board-1',
        'requesterUid': 'member-1',
        'requesterName': 'Mia',
        'targetElementIds': ['e-1', 'e-2'],
        'reason': 'removed the wrong layer',
        'status': 'pending',
        'createdAt': '2026-02-03T04:05:06.000Z',
        'appliedVersion': null,
      });

      expect(request.isPending, isTrue);
      expect(request.targetElementIds.length, 2);
      expect(request.requesterName, 'Mia');
      expect(request.createdAt, DateTime.utc(2026, 2, 3, 4, 5, 6));
      expect(request.appliedVersion, isNull);
    });

    test('resolved requests are not pending and keep the applied version', () {
      final request = UndoRequest.fromMap('req-2', {
        'status': 'approved',
        'appliedVersion': 1234,
        'resolvedBy': 'owner',
      });
      expect(request.isPending, isFalse);
      expect(request.appliedVersion, 1234);
      expect(request.resolvedBy, 'owner');
    });

    test('unknown status degrades to pending (older clients)', () {
      final request = UndoRequest.fromMap('req-3', {'status': null});
      expect(request.status, 'pending');
      expect(request.appliedVersion, isNull);
    });
  });

  group('RevertPlan', () {
    test('parses items and counts conflicts', () {
      final plan = RevertPlan.fromMap({
        'planId': 'plan_1',
        'mode': 'user',
        'baseVersion': 90,
        'requestId': 'req-1',
        'items': [
          {
            'elementId': 'e-1',
            'kind': 'delete',
            'conflict': false,
            'before': {'type': 'stroke', 'z': 1},
            'after': null,
          },
          {
            'elementId': 'e-2',
            'kind': 'update',
            'conflict': true,
            'before': {'type': 'shape'},
            'after': {'type': 'shape', 'size': 20},
            'lastEditorUid': 'mallory',
          },
        ],
      });

      expect(plan.planId, 'plan_1');
      expect(plan.mode, 'user');
      expect(plan.baseVersion, 90);
      expect(plan.requestId, 'req-1');
      expect(plan.items.length, 2);
      expect(plan.conflictCount, 1);
      expect(plan.items.first.elementType, 'stroke');
      expect(plan.items.first.after, isNull);
      expect(plan.items.last.lastEditorUid, 'mallory');
      expect(plan.items.last.elementType, 'shape');
    });

    test('missing items and unknown mode are tolerated', () {
      final plan = RevertPlan.fromMap({'planId': 'p'});
      expect(plan.items, isEmpty);
      expect(plan.mode, 'user');
      expect(plan.baseVersion, 0);
      expect(plan.conflictCount, 0);
    });
  });
}

/// Mimics a Firestore `Timestamp` (only `toDate()` is used by the models).
class _FakeTimestamp {
  final DateTime _value;
  const _FakeTimestamp(this._value);
  DateTime toDate() => _value;
}
