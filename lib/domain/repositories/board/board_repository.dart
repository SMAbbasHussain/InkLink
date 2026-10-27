import '../../models/board.dart';
import 'dart:typed_data';

abstract class BoardRepository {
  String? get currentUserId;
  // Returns the number of boards owned by the user.
  Future<int> countBoardsForUser(String userId);

  Future<void> startBoardsSync();
  Future<void> stopBoardsSync();
  Future<void> activateBoard(String boardId);
  Future<void> deactivateBoard();

  Stream<List<Board>> getOwnedBoards();
  Stream<List<Board>> getJoinedBoards();
  Stream<Board?> getBoardById(String boardId);
  Stream<List<BoardMember>> getBoardMembers(String boardId);

  Future<String> createNewBoard({
    String name = 'Untitled Board',
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    required List<String> tags,
    bool allowMembersToCopy = false,
    List<String> invitedUserIds = const [],
    int inviteExpiryHours = 72,
  });
  Future<void> joinBoard(String boardId);
  Future<void> ensureBoardCached(String boardId);
  Future<void> removeBoardSync(String boardId);
  Future<void> renameBoard(String boardId, String newName);
  Future<void> deleteBoard(String boardId);
  Future<void> archiveBoard(String boardId);
  Future<void> unarchiveBoard(String boardId);
  Future<String> duplicateBoard(String boardId, {String? customTitle});
  Future<void> updateBoardTags(String boardId, List<String> tags);
  Future<void> updateBoardSettings({
    required String boardId,
    required String visibility,
    required String privateJoinPolicy,
    required String whoCanInvite,
    required String defaultLinkJoinRole,
    bool? allowMembersToCopy,
  });
  Future<void> saveBoardPreview(String boardId, Uint8List pngBytes);
  Stream<String?> watchBoardPreview(String boardId);

  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  });

  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  });
}
