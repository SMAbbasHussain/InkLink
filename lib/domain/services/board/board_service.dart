import '../../../core/services/cloud_functions_service.dart';
import '../../models/board.dart';
import '../../repositories/board/board_repository.dart';

abstract class BoardService {
  Future<void> startBoardsSync();
  Future<void> stopBoardsSync();
  Stream<List<Board>> getOwnedBoards();
  Stream<List<Board>> getJoinedBoards();
  Future<String> createBoard({
    String? title,
    List<String> invitedUserIds,
    int inviteExpiryHours,
  });
  Future<void> joinBoard(String boardId);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> deleteBoard(String boardId);
}

class BoardServiceImpl implements BoardService {
  final BoardRepository _boardRepository;
  final CloudFunctionsService _cloudFunctionsService;

  BoardServiceImpl({
    required BoardRepository boardRepository,
    required CloudFunctionsService cloudFunctionsService,
  }) : _boardRepository = boardRepository,
       _cloudFunctionsService = cloudFunctionsService;

  @override
  Future<void> startBoardsSync() => _boardRepository.startBoardsSync();

  @override
  Future<void> stopBoardsSync() => _boardRepository.stopBoardsSync();

  @override
  Stream<List<Board>> getOwnedBoards() => _boardRepository.getOwnedBoards();

  @override
  Stream<List<Board>> getJoinedBoards() => _boardRepository.getJoinedBoards();

  @override
  Future<String> createBoard({
    String? title,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  }) async {
    final resolvedTitle = (title == null || title.trim().isEmpty)
        ? 'Untitled Board'
        : title.trim();

    final boardId = await _boardRepository.createNewBoard(
      name: resolvedTitle,
      invitedUserIds: const [],
      inviteExpiryHours: inviteExpiryHours,
    );

    if (invitedUserIds.isNotEmpty) {
      try {
        await _cloudFunctionsService.httpsCallable('sendBoardInvite').call({
          'boardId': boardId,
          'boardTitle': resolvedTitle,
          'invitedUserIds': invitedUserIds,
          'inviteExpiryHours': inviteExpiryHours,
        });
      } catch (_) {
        // Board creation succeeds even if invite delivery fails.
      }
    }

    return boardId;
  }

  @override
  Future<void> joinBoard(String boardId) {
    return _boardRepository.joinBoard(boardId.trim());
  }

  @override
  Future<void> renameBoard(String boardId, String newName) {
    return _boardRepository.renameBoard(boardId, newName);
  }

  @override
  Future<void> deleteBoard(String boardId) {
    return _cloudFunctionsService
        .httpsCallable('deleteBoard')
        .call({'boardId': boardId.trim()})
        .then((_) {
          return _boardRepository.deleteBoard(boardId);
        });
  }
}
