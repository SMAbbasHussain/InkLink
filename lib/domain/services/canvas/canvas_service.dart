import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/database/collections/local_crdt_update.dart';
import '../../models/board.dart';
import '../../repositories/board/board_repository.dart';
import '../../repositories/canvas/canvas_sync_repository.dart';

abstract class CanvasService {
  bool get canSync;
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes);
  Future<void> ensureBoardCached(String boardId);
  Stream<Board?> watchBoardById(String boardId);
  Stream<List<LocalCrdtUpdate>> listenToCrdtUpdates(String boardId);
  Future<void> stopCrdtRemoteSync(String boardId);
  Future<void> pushCrdtUpdate({
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

    _hydrateAndStartRemoteSync(boardId, userId);
    _syncPendingLocalUpdates(boardId, userId);
    return _syncRepository.watchLocalCrdtUpdates(boardId);
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
  }) {
    final userId = _syncRepository.currentUserId;
    final payloadBase64 = base64Encode(payload);

    return _syncRepository
        .saveLocalCrdtUpdate(
          LocalCrdtUpdate()
            ..updateId = updateId
            ..boardId = boardId
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
            );
            await _syncRepository.markCrdtUpdateSynced(updateId);
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

  Future<void> _hydrateAndStartRemoteSync(String boardId, String userId) async {
    if (_remoteSubs.containsKey(boardId)) return;

    await _boardRepository.ensureBoardCached(boardId);

    final remoteUpdates = await _syncRepository.fetchRemoteCrdtUpdates(boardId);
    if (remoteUpdates.isNotEmpty) {
      await _syncRepository.saveLocalCrdtUpdate(remoteUpdates.first).then((
        _,
      ) async {
        for (final update in remoteUpdates.skip(1)) {
          await _syncRepository.saveLocalCrdtUpdate(update);
        }
      });
    }

    final remoteSub = _syncRepository.watchRemoteCrdtUpdates(boardId).listen((
      updates,
    ) async {
      for (final update in updates) {
        await _syncRepository.saveLocalCrdtUpdate(update);
      }
      await _syncPendingLocalUpdates(boardId, userId);
    }, onError: (_) {});
    _remoteSubs[boardId] = remoteSub;
  }

  Future<void> _syncPendingLocalUpdates(String boardId, String userId) async {
    final pending = await _syncRepository.getLocalCrdtUpdates(boardId);
    for (final local in pending) {
      if (local.isSynced) continue;
      try {
        await _syncRepository.writeRemoteCrdtUpdate(
          boardId: boardId,
          updateId: local.updateId,
          payloadBase64: local.payloadBase64,
          sourceClientId: userId,
        );
        await _syncRepository.markCrdtUpdateSynced(local.updateId);
      } catch (error) {
        if (_isPermissionDenied(error)) {
          await stopCrdtRemoteSync(boardId);
          return;
        }
        rethrow;
      }
    }
  }

  bool _isPermissionDenied(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('missing or insufficient permissions');
  }
}
