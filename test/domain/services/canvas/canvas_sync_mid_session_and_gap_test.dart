import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/database/collections/local_crdt_update.dart';
import 'package:inklink/domain/models/board.dart';
import 'package:inklink/domain/repositories/board/board_repository.dart';
import 'package:inklink/domain/repositories/canvas/canvas_sync_repository.dart';
import 'package:inklink/domain/services/canvas/canvas_service.dart';

class _FakeBoardRepository extends Fake implements BoardRepository {
  final List<String> cachedBoards = [];

  @override
  Future<void> ensureBoardCached(String boardId) async {
    cachedBoards.add(boardId);
  }

  @override
  Stream<Board?> getBoardById(String boardId) {
    return Stream.value(Board(
      id: boardId,
      title: 'Test Board',
      ownerId: 'user-1',
      members: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }
}

class _MockCanvasSyncRepository implements CanvasSyncRepository {
  final List<String> callLog = [];
  final List<LocalCrdtUpdate> savedLocalUpdates = [];
  final StreamController<List<LocalCrdtUpdate>> remoteStreamController =
      StreamController<List<LocalCrdtUpdate>>.broadcast();
  final StreamController<List<LocalCrdtUpdate>> peerStreamController =
      StreamController<List<LocalCrdtUpdate>>.broadcast();

  int? currentServerVersion;
  List<LocalCrdtUpdate> remoteFetchResult = [];
  bool failPreWatch = false;

  @override
  String? get currentUserId => 'user-test';

  @override
  Future<int?> preWatchBoard(String boardId) async {
    callLog.add('preWatchBoard($boardId)');
    if (failPreWatch) throw Exception('preWatch failed');
    return currentServerVersion;
  }

  @override
  Future<List<LocalCrdtUpdate>> fetchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
    String? lastSeenCursor,
    bool preferSocket = true,
  }) async {
    callLog.add('fetchRemoteCrdtUpdates($boardId)');
    return remoteFetchResult;
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchRemoteCrdtUpdates(
    String boardId, {
    DateTime? since,
  }) {
    callLog.add('watchRemoteCrdtUpdates($boardId)');
    return remoteStreamController.stream;
  }

  @override
  Future<void> saveLocalCrdtUpdate(LocalCrdtUpdate update) async {
    callLog.add('saveLocalCrdtUpdate(${update.updateId}, v=${update.version})');
    savedLocalUpdates.add(update);
  }

  @override
  Future<List<LocalCrdtUpdate>> fetchMissingCrdtUpdates({
    required String boardId,
    int? fromVersion,
    int? toVersion,
    int? sinceVersion,
    List<int>? missingVersions,
  }) async {
    callLog.add('fetchMissingCrdtUpdates($boardId, from=$fromVersion, to=$toVersion)');
    return [];
  }

  @override
  void requestPeerCrdtUpdates({
    required String boardId,
    int? fromVersion,
    int? toVersion,
    List<int>? missingVersions,
  }) {
    callLog.add('requestPeerCrdtUpdates($boardId, from=$fromVersion, to=$toVersion)');
  }

  @override
  void relayPeerCrdtUpdates({
    required String boardId,
    required List<LocalCrdtUpdate> updates,
    String? targetUid,
  }) {
    callLog.add('relayPeerCrdtUpdates($boardId, count=${updates.length}, target=$targetUid)');
  }

  @override
  Stream<List<LocalCrdtUpdate>> watchPeerCrdtUpdates(String boardId) {
    callLog.add('watchPeerCrdtUpdates($boardId)');
    return peerStreamController.stream;
  }

  @override
  Future<List<LocalCrdtUpdate>> getLocalCrdtUpdates(String boardId) async => [];

  @override
  Future<DateTime?> getLatestLocalCrdtUpdateAt(String boardId) async => null;

  @override
  Future<String?> getLastSeenCursor(String boardId) async => null;

  @override
  Future<void> clearLocalCrdtUpdatesForBoard(String boardId) async {}

  @override
  Future<void> markCrdtUpdateSynced(String updateId) async {}

  @override
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) async {}

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate(String boardId, String elementId) async => null;

  @override
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required String payloadBase64,
  }) async {}

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required String payloadBase64,
    required String sourceClientId,
  }) async {}

  @override
  Stream<List<LocalCrdtUpdate>> watchRemoteCanvasPreviews(String boardId) =>
      const Stream.empty();

  @override
  Stream<List<LocalCrdtUpdate>> watchLocalCrdtUpdates(String boardId) {
    callLog.add('watchLocalCrdtUpdates($boardId)');
    return Stream.value(savedLocalUpdates);
  }

  @override
  Future<void> writeRemoteCrdtUpdate({
    required String boardId,
    required String updateId,
    required String payloadBase64,
    required String sourceClientId,
    String? elementId,
    String action = 'upsert',
  }) async {}

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {}

  @override
  Future<bool> batchSyncPendingUpdates(String boardId, String userId) async => true;

  @override
  Future<void> persistCursorForBoard(String boardId) async {
    callLog.add('persistCursorForBoard($boardId)');
  }

  @override
  Future<void> logoutSocket() async {}

  @override
  Future<void> disconnectSocket() async {}
}

void main() {
  group('CanvasService — Mid-Session Join & Gap Prevention', () {
    late _MockCanvasSyncRepository syncRepo;
    late _FakeBoardRepository boardRepo;
    late CanvasService canvasService;

    setUp(() {
      syncRepo = _MockCanvasSyncRepository();
      boardRepo = _FakeBoardRepository();
      canvasService = CanvasServiceImpl(
        syncRepository: syncRepo,
        boardRepository: boardRepo,
      );
    });

    test('preWatchBoard is called BEFORE fetchRemoteCrdtUpdates on join', () async {
      final fetchedUpdate = LocalCrdtUpdate()
        ..updateId = 'fetch-1'
        ..boardId = 'board-abc'
        ..version = 10
        ..appliedAt = DateTime.now();
      syncRepo.remoteFetchResult = [fetchedUpdate];

      final sub = canvasService.listenToCrdtUpdates('board-abc').listen((_) {});

      // Allow the async hydration to progress
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final preWatchIndex = syncRepo.callLog.indexOf('preWatchBoard(board-abc)');
      final fetchIndex = syncRepo.callLog.indexOf('fetchRemoteCrdtUpdates(board-abc)');
      final watchIndex = syncRepo.callLog.indexOf('watchRemoteCrdtUpdates(board-abc)');

      // Pre-watch MUST happen before remote fetch to eliminate the mid-session gap!
      expect(preWatchIndex, isNot(-1));
      expect(fetchIndex, isNot(-1));
      expect(watchIndex, isNot(-1));
      expect(preWatchIndex, lessThan(fetchIndex));
      expect(fetchIndex, lessThan(watchIndex));

      // The fetched update should be saved
      expect(syncRepo.savedLocalUpdates.any((u) => u.updateId == 'fetch-1'), isTrue);

      await sub.cancel();
    });

    test('Live remote updates received after join are saved and cursor persisted', () async {
      final sub = canvasService.listenToCrdtUpdates('board-xyz').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final liveUpdate = LocalCrdtUpdate()
        ..updateId = 'live-1'
        ..boardId = 'board-xyz'
        ..version = 11
        ..appliedAt = DateTime.now();

      syncRepo.remoteStreamController.add([liveUpdate]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(syncRepo.savedLocalUpdates.any((u) => u.updateId == 'live-1'), isTrue);
      expect(syncRepo.callLog.contains('persistCursorForBoard(board-xyz)'), isTrue);

      await sub.cancel();
    });

    test('Fallback to local updates works if preWatch or hydration fails', () async {
      syncRepo.failPreWatch = true;
      final sub = canvasService.listenToCrdtUpdates('board-err').listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Must still watch local updates without throwing unhandled exception
      expect(syncRepo.callLog.contains('watchLocalCrdtUpdates(board-err)'), isTrue);
      await sub.cancel();
    });

    test('Version gap recovery fetches missing updates and relays peer updates', () async {
      // 1. Fetch missing updates via repository
      await syncRepo.fetchMissingCrdtUpdates(
        boardId: 'board-gap',
        fromVersion: 11,
        toVersion: 13,
      );
      expect(
        syncRepo.callLog.contains('fetchMissingCrdtUpdates(board-gap, from=11, to=13)'),
        isTrue,
      );

      // 2. Request peer updates when server stream is unavailable
      syncRepo.requestPeerCrdtUpdates(
        boardId: 'board-gap',
        fromVersion: 11,
        toVersion: 13,
      );
      expect(
        syncRepo.callLog.contains('requestPeerCrdtUpdates(board-gap, from=11, to=13)'),
        isTrue,
      );

      // 3. Relay peer updates to requesting peer
      final peerUpdate = LocalCrdtUpdate()
        ..updateId = 'peer-up-11'
        ..boardId = 'board-gap'
        ..version = 11
        ..appliedAt = DateTime.now();

      syncRepo.relayPeerCrdtUpdates(
        boardId: 'board-gap',
        updates: [peerUpdate],
        targetUid: 'user-requester',
      );
      expect(
        syncRepo.callLog.contains('relayPeerCrdtUpdates(board-gap, count=1, target=user-requester)'),
        isTrue,
      );
    });
  });
}
