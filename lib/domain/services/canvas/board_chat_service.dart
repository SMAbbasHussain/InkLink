import '../../../features/canvas/models/board_chat_message.dart';

abstract class BoardChatService {
  Stream<BoardChatMessage> watchChatMessages(String boardId);
  Future<List<BoardChatMessage>> getChatHistory(String boardId, {int limit = 50});
  Future<BoardChatMessage> sendMessage({
    required String boardId,
    required String text,
  });
  Future<void> connect(String boardId);
  Future<void> dispose();
}
