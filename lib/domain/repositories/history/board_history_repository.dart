import '../../models/history/board_activity_block.dart';
import '../../models/history/undo_request.dart';

/// Firestore reads for board history. Owner-only (D3): the rules and the
/// socket server both enforce it, so members never see the log.
///
/// R2 blocks are NOT read here — they go through [BoardHistoryService].
abstract class BoardHistoryRepository {
  /// `boards/{boardId}/activity_index`, newest block first.
  Stream<List<BoardActivityBlock>> watchActivityFeed(
    String boardId, {
    int limit = 50,
  });

  /// All undo requests on the board (owner view), newest first.
  Stream<List<UndoRequest>> watchUndoRequests(String boardId);

  /// The signed-in member's own undo requests.
  Stream<List<UndoRequest>> watchMyUndoRequests(String boardId, String uid);
}
