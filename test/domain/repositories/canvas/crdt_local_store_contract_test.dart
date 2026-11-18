import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_canvas_sync_state.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository_impl.dart';
import 'package:inklink/domain/repositories/canvas/crdt_local_store.dart';

import 'crdt_store_test_support.dart';

/// The same contract for the phone store (Isar) and the web store (memory),
/// both directly and through the real canvas sync repository.
void main() {
  final isarLib = resolveBundledIsarLibraryPath();

  group('MemoryCrdtLocalStore', () => _contract(memoryStoreFactory));
  group(
    'IsarCrdtLocalStore',
    skip: isarLib == null
        ? 'Native Isar library not found in pub cache on this host'
        : false,
    () {
      _contract(() => isarStoreFactory(isarLib!));

      test('keeps the sync state row the same as before', () async {
        final h = await isarStoreFactory(isarLib!);
        addTearDown(h.dispose);
        final at = DateTime.utc(2026, 3, 1, 10);
        await h.store.saveUpdateAndSyncedAt(crdtUpdate('u1', appliedAt: at));
        await h.store.saveLastSeenCursor('board-1', '0-0:7');
        final state = await h.isar!.localCanvasSyncStates.getByBoardId(
          'board-1',
        );
        expect(state!.lastSeenCursor, '0-0:7');
        expect(state.lastSyncedAppliedAt!.isAtSameMomentAs(at), isTrue);

        final later = at.add(const Duration(hours: 1));
        await h.store.saveLastSyncedAppliedAt('board-1', later);
        final after = await h.isar!.localCanvasSyncStates.getByBoardId(
          'board-1',
        );
        expect(after!.lastSeenCursor, '0-0:7');
        expect(after.lastSyncedAppliedAt!.isAtSameMomentAs(later), isTrue);
      });
    },
  );
}

void _contract(StoreFactory factory) {
  late StoreHandle h;
  late CrdtLocalStore store;

  setUp(() async {
    h = await factory();
    store = h.store;
  });
  tearDown(() => h.dispose());

  DateTime t(int minute) => DateTime.utc(2026, 1, 1, 12, minute);
  List<String> ids(List list) => [for (final u in list) u.updateId as String];

  test('put and get keep every field', () async {
    final u =
        crdtUpdate(
            'u1',
            elementId: 'el-1',
            appliedAt: t(5),
            version: 3,
            isSynced: true,
            isDeleted: true,
            payloadBase64: 'cGF5bG9hZA==',
          )
          ..action = 'delete'
          ..affectedElementIds = ['a', 'b'];
    await store.putUpdate(u);
    final got = await store.getByUpdateId('u1');
    expect(got, isNotNull);
    expect(got!.updateId, 'u1');
    expect(got.boardId, 'board-1');
    expect(got.elementId, 'el-1');
    expect(got.action, 'delete');
    expect(got.affectedElementIds, ['a', 'b']);
    expect(got.payloadBase64, 'cGF5bG9hZA==');
    expect(got.sourceClientId, 'client-1');
    expect(got.appliedAt.isAtSameMomentAs(t(5)), isTrue);
    expect(got.version, 3);
    expect(got.isSynced, isTrue);
    expect(got.isDeleted, isTrue);
    expect(await store.getByUpdateId('missing'), isNull);
  });

  test('a read result changes nothing until it is put back', () async {
    await store.putUpdate(crdtUpdate('u1'));
    final got = await store.getByUpdateId('u1');
    got!.isSynced = true;
    expect((await store.getByUpdateId('u1'))!.isSynced, isFalse);
    await store.putUpdate(got);
    expect((await store.getByUpdateId('u1'))!.isSynced, isTrue);
  });

  test('a put replaces the update with the same updateId', () async {
    await store.putUpdate(crdtUpdate('u1', payloadBase64: 'AA=='));
    await store.putUpdate(crdtUpdate('u1', payloadBase64: 'BB=='));
    final all = await store.updatesForBoard('board-1');
    expect(all, hasLength(1));
    expect(all.single.payloadBase64, 'BB==');
  });

  test('queries only see the asked board, in the right order', () async {
    await store.putUpdate(crdtUpdate('b', appliedAt: t(2), version: 9));
    await store.putUpdate(
      crdtUpdate('a', appliedAt: t(1), version: 4, isSynced: true),
    );
    await store.putUpdate(crdtUpdate('c', appliedAt: t(3), version: 1));
    await store.putUpdate(
      crdtUpdate('other', boardId: 'board-2', appliedAt: t(9), version: 99),
    );

    expect(ids(await store.updatesForBoard('board-1'))..sort(), [
      'a',
      'b',
      'c',
    ]);
    expect(ids(await store.updatesForBoardNewestFirst('board-1')), [
      'c',
      'b',
      'a',
    ]);
    expect((await store.latestUpdate('board-1'))!.updateId, 'c');
    expect((await store.latestSyncedUpdate('board-1'))!.updateId, 'a');
    expect((await store.highestVersionUpdate('board-1'))!.updateId, 'b');
    expect(ids(await store.unsyncedUpdatesOldestFirst('board-1')), ['b', 'c']);
    expect(await store.latestUpdate('empty'), isNull);
    expect(await store.latestSyncedUpdate('empty'), isNull);
    expect(await store.highestVersionUpdate('empty'), isNull);
  });

  test('deleting old synced updates keeps the rest', () async {
    await store.putUpdate(
      crdtUpdate('old-synced', appliedAt: t(1), isSynced: true),
    );
    await store.putUpdate(crdtUpdate('old-unsynced', appliedAt: t(1)));
    await store.putUpdate(
      crdtUpdate('new-synced', appliedAt: t(30), isSynced: true),
    );
    await store.putUpdate(
      crdtUpdate(
        'other-board',
        boardId: 'board-2',
        appliedAt: t(1),
        isSynced: true,
      ),
    );
    await store.deleteSyncedUpdatesAppliedBefore('board-1', t(10));
    expect(ids(await store.updatesForBoard('board-1'))..sort(), [
      'new-synced',
      'old-unsynced',
    ]);
    expect(await store.updatesForBoard('board-2'), hasLength(1));
  });

  test('deleting a board removes only that board', () async {
    await store.putUpdate(crdtUpdate('a'));
    await store.putUpdate(crdtUpdate('b', boardId: 'board-2'));
    await store.deleteUpdatesForBoard('board-1');
    expect(await store.updatesForBoard('board-1'), isEmpty);
    expect(await store.updatesForBoard('board-2'), hasLength(1));
  });

  test('cursor round-trips per board', () async {
    expect(await store.getLastSeenCursor('board-1'), isNull);
    await store.saveLastSeenCursor('board-1', '0-0:3');
    await store.saveLastSeenCursor('board-2', '0-0:8');
    expect(await store.getLastSeenCursor('board-1'), '0-0:3');
    await store.saveLastSeenCursor('board-1', '0-0:4');
    expect(await store.getLastSeenCursor('board-1'), '0-0:4');
    expect(await store.getLastSeenCursor('board-2'), '0-0:8');
  });

  test('watch emits now and after changes, oldest first', () async {
    final seen = <List<String>>[];
    final sub = store
        .watchUpdatesForBoard('board-1')
        .listen((list) => seen.add(ids(list)));
    await _waitFor(() => seen.isNotEmpty);
    expect(seen.last, isEmpty);

    await store.putUpdate(crdtUpdate('b', appliedAt: t(2)));
    await store.putUpdate(crdtUpdate('a', appliedAt: t(1)));
    await store.putUpdate(crdtUpdate('x', boardId: 'board-2'));
    await _waitFor(() => seen.last.length == 2);
    expect(seen.last, ['a', 'b']);
    await sub.cancel();
  });

  group('through FirestoreCanvasSyncRepository (signed out)', () {
    late FirestoreCanvasSyncRepository repo;
    setUp(() {
      repo = FirestoreCanvasSyncRepository(
        authService: SignedOutAuthService(),
        store: store,
      );
    });

    test('save, mark synced and deleted, element lookup', () async {
      await repo.saveLocalCrdtUpdate(
        crdtUpdate('u1', elementId: 'el', appliedAt: t(1)),
      );
      await repo.saveLocalCrdtUpdate(
        crdtUpdate('u2', elementId: 'el', appliedAt: t(2)),
      );
      expect(
        (await repo.getElementCrdtUpdate('board-1', 'el'))!.updateId,
        'u2',
      );

      await repo.markCrdtUpdateDeleted('u2', true);
      expect(
        (await repo.getElementCrdtUpdate('board-1', 'el'))!.updateId,
        'u1',
      );
      expect(await repo.getLatestLocalCrdtUpdateAt('board-1'), isNull);

      await repo.markCrdtUpdateSynced('u1');
      final latest = await repo.getLatestLocalCrdtUpdateAt('board-1');
      expect(latest!.isAtSameMomentAs(t(1)), isTrue);
      expect(await repo.getLocalCrdtUpdates('board-1'), hasLength(2));

      // Unknown ids are ignored, as before.
      await repo.markCrdtUpdateSynced('nope');
      await repo.markCrdtUpdateDeleted('nope', true);
    });

    test('an in-place payload edit is stored and marked for re-sync', () async {
      await repo.saveLocalCrdtUpdate(crdtUpdate('u1', isSynced: true));
      await repo.updateCrdtUpdatePayload(
        boardId: 'board-1',
        updateId: 'u1',
        payloadBase64: 'TkVX',
      );
      final got = (await repo.getLocalCrdtUpdates('board-1')).single;
      expect(got.payloadBase64, 'TkVX');
      expect(got.isSynced, isFalse);
    });

    test('cursor is saved from the newest versioned update', () async {
      expect(await repo.getLastSeenCursor('board-1'), isNull);
      await repo.saveLocalCrdtUpdate(
        crdtUpdate('u1', appliedAt: t(1), version: 5),
      );
      await repo.saveLocalCrdtUpdate(
        crdtUpdate('u2', appliedAt: t(2), version: 6),
      );
      await repo.persistCursorForBoard('board-1');
      expect(await repo.getLastSeenCursor('board-1'), '0-0:6');
    });

    test('local watch and clearing a board', () async {
      final lengths = <int>[];
      final sub = repo
          .watchLocalCrdtUpdates('board-1')
          .listen((l) => lengths.add(l.length));
      // Wait for the first result: Isar starts watching only after it.
      await _waitFor(() => lengths.isNotEmpty, () => 'no first result');
      await repo.saveLocalCrdtUpdate(crdtUpdate('u1'));
      await _waitFor(() => lengths.last == 1, () => 'after save: $lengths');
      await repo.clearLocalCrdtUpdatesForBoard('board-1');
      await _waitFor(() => lengths.last == 0, () => 'after clear: $lengths');
      await sub.cancel();
    });
  });
}

Future<void> _waitFor(bool Function() done, [String Function()? why]) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    done(),
    isTrue,
    reason: why?.call() ?? 'condition not reached in time',
  );
}
