import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../models/canvas/crdt_update.dart';
import '../../models/board.dart';
import '../../repositories/board/board_repository.dart';
import '../../repositories/canvas/canvas_sync_repository.dart';

abstract class CanvasService {
  bool get canSync;
  String? get currentClientId;
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes);
  Future<void> ensureBoardCached(String boardId);
  Stream<Board?> watchBoardById(String boardId);
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId);
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId);
  Future<void> stopCrdtRemoteSync(String boardId);

  /// Re-send local updates that are still marked unsynced. Returns true when
  /// every pending update was acknowledged.
  Future<bool> retryPendingSync(String boardId);

  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  });
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  });
  void setBoardSingleUserStatus(bool isSingleUser);
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted);
  Future<LocalCrdtUpdate?> getElementCrdtUpdate({
    required String boardId,
    required String elementId,
  });
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required Uint8List payload,
  });
}

class CanvasServiceImpl implements CanvasService {
  final BoardRepository _boardRepository;
  final CanvasSyncRepository _syncRepository;
  final Map<String, StreamSubscription<List<LocalCrdtUpdate>>> _remoteSubs = {};
  final Map<String, Future<void>> _hydrationInFlight = {};

  CanvasServiceImpl({
    required this._boardRepository,
    required this._syncRepository,
  });

  @override
  bool get canSync => _syncRepository.currentUserId != null;

  @override
  String? get currentClientId => _syncRepository.currentUserId;

  @override
  void setBoardSingleUserStatus(bool isSingleUser) {
    _syncRepository.setBoardSingleUserStatus(isSingleUser);
  }

  @override
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes) {
    return _boardRepository.saveBoardPreview(boardId, pngBytes);
  }

  @override
  Future<void> ensureBoardCached(String boardId) {
    return _boardRepository.ensureBoardCached(boardId);
  }

  @override
  Stream<Board?> watchBoardById(String boardId) {
    return _boardRepository.getBoardById(boardId);
  }

  @override
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId) {
    final userId = _syncRepository.currentUserId;
    if (userId == null) {
      return _syncRepository.watchLocalCrdtUpdates(boardId);
    }

    return () async* {
      // Never block locally stored updates behind network hydration: a slow or
      // stalled remote sync used to leave the board empty even though every
      // update was already on the device. Hydrate in the background; the local
      // watch re-emits as remote updates land in the database.
      final hydration = _hydrationInFlight[boardId] ??=
          _hydrateAndStartRemoteSync(boardId, userId)
              .catchError((Object error, StackTrace stackTrace) {
                developer.log(
                  'CRDT hydrate failed for board $boardId, using local updates',
                  name: 'CanvasService',
                  error: error,
                  stackTrace: stackTrace,
                );
              })
              .whenComplete(() => _hydrationInFlight.remove(boardId));
      unawaited(hydration);

      yield* _syncRepository.watchLocalCrdtUpdates(boardId);
    }();
  }

  @override
  Stream<List<LocalCrdtUpdate>> listenToCanvasPreviews(String boardId) {
    final userId = _syncRepository.currentUserId;
    if (userId == null) {
      return const Stream<List<LocalCrdtUpdate>>.empty();
    }

    return _syncRepository.watchRemoteCanvasPreviews(boardId);
  }

  @override
  Future<bool> retryPendingSync(String boardId) async {
    final userId = _syncRepository.currentUserId;
    if (userId == null) return false;
    return _syncRepository.batchSyncPendingUpdates(boardId, userId);
  }

  @override
  Future<void> stopCrdtRemoteSync(String boardId) async {
    final sub = _remoteSubs.remove(boardId);
    return () async {
      try {
        // Persist the cursor before tearing down so the next open can resume.
        await _syncRepository.persistCursorForBoard(boardId);
      } catch (_) {}
      try {
        await sub?.cancel();
      } finally {
        await _boardRepository.deactivateBoard();
      }
    }();
  }

  @override
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
    String action = 'upsert',
  }) {
    final userId = _syncRepository.currentUserId;
    final payloadBase64 = base64Encode(payload);

    return _syncRepository
        .saveLocalCrdtUpdate(
          LocalCrdtUpdate()
            ..updateId = updateId
            ..boardId = boardId
            ..elementId = elementId
            ..action = action
            ..payloadBase64 = payloadBase64
            ..sourceClientId = userId ?? 'anonymous'
            ..appliedAt = DateTime.now()
            ..isSynced = false,
        )
        .then((_) async {
          if (userId == null) return;
          try {
            await _syncRepository.writeRemoteCrdtUpdate(
              boardId: boardId,
              updateId: updateId,
              payloadBase64: payloadBase64,
              sourceClientId: userId,
              elementId: elementId,
              action: action,
            );
            await _syncPendingLocalUpdates(boardId, userId);
          } catch (error) {
            if (_isPermissionDenied(error)) {
              await stopCrdtRemoteSync(boardId);
              return;
            }
            rethrow;
          }
        });
  }

  @override
  Future<void> publishCanvasPreview({
    required String boardId,
    required String previewId,
    required String elementId,
    required Uint8List payload,
  }) {
    final userId = _syncRepository.currentUserId;
    if (userId == null) return Future.value();

    return _syncRepository.publishCanvasPreview(
      boardId: boardId,
      previewId: previewId,
      elementId: elementId,
      payloadBase64: base64Encode(payload),
      sourceClientId: userId,
    );
  }

  @override
  Future<void> markCrdtUpdateDeleted(String updateId, bool isDeleted) {
    return _syncRepository.markCrdtUpdateDeleted(updateId, isDeleted);
  }

  @override
  Future<LocalCrdtUpdate?> getElementCrdtUpdate({
    required String boardId,
    required String elementId,
  }) {
    return _syncRepository.getElementCrdtUpdate(boardId, elementId);
  }

  @override
  Future<void> updateCrdtUpdatePayload({
    required String boardId,
    required String updateId,
    required Uint8List payload,
  }) {
    return _syncRepository.updateCrdtUpdatePayload(
      boardId: boardId,
      updateId: updateId,
      payloadBase64: base64Encode(payload),
    );
  }

  Future<void> _hydrateAndStartRemoteSync(String boardId, String userId) async {
    if (_remoteSubs.containsKey(boardId)) return;

    await _boardRepository.ensureBoardCached(boardId);

    // Pre-join socket room and arm inbound buffering immediately so no live
    // peer updates are dropped while the baseline history fetch is in flight.
    try {
      await _syncRepository.preWatchBoard(boardId);
    } catch (_) {}

    final localUpdates = await _syncRepository.getLocalCrdtUpdates(boardId);
    final hasLocalActiveUpdates = localUpdates.any(
      (u) => !u.isDeleted && u.payloadBase64.isNotEmpty,
    );
    // Only use previously-synced rows to compute the 'since' cursor. If there
    // are no active local updates, ignore any stale cursor and fetch a full
    // snapshot + deltas from the server.
    final latestLocalUpdateAt = !hasLocalActiveUpdates
        ? null
        : await _syncRepository.getLatestLocalCrdtUpdateAt(boardId);
    final lastSeenCursor = hasLocalActiveUpdates
        ? await _syncRepository.getLastSeenCursor(boardId)
        : null;

    final remoteUpdates = await _syncRepository.fetchRemoteCrdtUpdates(
      boardId,
      since: latestLocalUpdateAt,
      lastSeenCursor: lastSeenCursor,
      preferSocket: true,
      ignoreCursor: !hasLocalActiveUpdates,
    );
    if (remoteUpdates.isNotEmpty) {
      for (final update in remoteUpdates) {
        await _syncRepository.saveLocalCrdtUpdate(update);
      }
    }

    final refreshedLatestLocalUpdateAt = await _syncRepository
        .getLatestLocalCrdtUpdateAt(boardId);

    final remoteSub = _syncRepository
        .watchRemoteCrdtUpdates(boardId, since: refreshedLatestLocalUpdateAt)
        .listen(
          (updates) async {
            for (final update in updates) {
              await _syncRepository.saveLocalCrdtUpdate(update);
            }
            // Persist cursor so the next open resumes from the latest update.
            await _syncRepository.persistCursorForBoard(boardId);
          },
          onError: (error, stackTrace) {
            developer.log(
              'Remote CRDT sync error for board $boardId',
              name: 'CanvasService',
              error: error,
              stackTrace: stackTrace,
            );
            if (_isPermissionDenied(error)) {
              unawaited(stopCrdtRemoteSync(boardId));
            }
          },
        );
    _remoteSubs[boardId] = remoteSub;

    await _syncPendingLocalUpdates(boardId, userId);
  }

  Future<void> _syncPendingLocalUpdates(String boardId, String userId) async {
    // Delegate batching to repository implementation; transient failures leave
    // updates queued in Isar for the next retry without tearing down live sync.
    await _syncRepository.batchSyncPendingUpdates(boardId, userId);
  }

  bool _isPermissionDenied(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('missing or insufficient permissions');
  }
}
