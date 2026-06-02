import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../../core/database/collections/local_crdt_update.dart';
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
  Future<void> pushCrdtUpdate({
    required String boardId,
    required String updateId,
    required Uint8List payload,
    String? elementId,
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

  CanvasServiceImpl({
    required BoardRepository boardRepository,
    required CanvasSyncRepository syncRepository,
  }) : _boardRepository = boardRepository,
       _syncRepository = syncRepository;

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
      try {
        await _hydrateAndStartRemoteSync(boardId, userId);
      } catch (error, stackTrace) {
        developer.log(
          'CRDT hydrate failed for board $boardId, falling back to local updates',
          name: 'CanvasService',
          error: error,
          stackTrace: stackTrace,
        );
      }

      // Always surface local updates, even when remote hydration fails.
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
  Future<void> stopCrdtRemoteSync(String boardId) {
    final sub = _remoteSubs.remove(boardId);
    return () async {
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
  }) {
    final userId = _syncRepository.currentUserId;
    final payloadBase64 = base64Encode(payload);

    return _syncRepository
        .saveLocalCrdtUpdate(
          LocalCrdtUpdate()
            ..updateId = updateId
            ..boardId = boardId
            ..elementId = elementId
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

    final localUpdates = await _syncRepository.getLocalCrdtUpdates(boardId);
    final useFirestoreFirst = localUpdates.isEmpty;
    // Only use previously-synced rows to compute the 'since' cursor. If there
    // are no local updates, fetch all remote updates from Firestore.
    final latestLocalUpdateAt = useFirestoreFirst
        ? null
        : await _syncRepository.getLatestLocalCrdtUpdateAt(boardId);
    final lastSeenCursor = await _syncRepository.getLastSeenCursor(boardId);

    final remoteUpdates = await _syncRepository.fetchRemoteCrdtUpdates(
      boardId,
      since: latestLocalUpdateAt,
      lastSeenCursor: lastSeenCursor,
      preferSocket: !useFirestoreFirst,
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
            await _syncPendingLocalUpdates(boardId, userId);
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
    // Delegate batching to repository implementation.
    final success = await _syncRepository.batchSyncPendingUpdates(
      boardId,
      userId,
    );
    if (!success) {
      // If batch fails (e.g., permission denied), stop remote sync.
      await stopCrdtRemoteSync(boardId);
    }
  }

  bool _isPermissionDenied(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('missing or insufficient permissions');
  }
}
