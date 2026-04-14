import '../../models/board.dart';
import 'dart:typed_data';

abstract class BoardRepository {
  String? get currentUserId;
  // Returns the number of boards owned by the user.
  Future<int> countBoardsForUser(String userId);

  Future<void> startBoardsSync();
  Future<void> stopBoardsSync();

  Stream<List<Board>> getOwnedBoards();
  Stream<List<Board>> getJoinedBoards();
  Stream<Board?> getBoardById(String boardId);

  Future<String> createNewBoard({
    String name = 'Untitled Board',
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required List<String> tags,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  });
  Future<void> joinBoard(String boardId);
  Future<void> ensureBoardCached(String boardId);
  Future<void> removeBoardSync(String boardId);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> deleteBoard(String boardId);
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes);
  Stream<String?> watchBoardPreview(String boardId);
}
