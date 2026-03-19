import '../../models/board.dart';

abstract class BoardRepository {
  String? get currentUserId;

  Future<void> startBoardsSync();
  Future<void> stopBoardsSync();

  Stream<List<Board>> getOwnedBoards();
  Stream<List<Board>> getJoinedBoards();
  Stream<Board?> getBoardById(String boardId);

  Future<String> createNewBoard([String name = 'Untitled Board']);
  Future<void> joinBoard(String boardId);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> deleteBoard(String boardId);
}
