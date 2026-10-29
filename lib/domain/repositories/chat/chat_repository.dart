/// Neutral document abstraction so domain services can consume chat data
/// without importing a database SDK.
class ChatDoc {
  final String id;
  final Map<String, dynamic> data;

  const ChatDoc({required this.id, required this.data});
}

enum ChatDocChangeType { added, modified, removed }

class ChatDocChange {
  final ChatDocChangeType type;

  /// Null when the underlying document carries no data.
  final ChatDoc? doc;

  const ChatDocChange({required this.type, this.doc});
}

/// Placeholder a repository replaces with a server-generated timestamp on
/// write, keeping services free of database field-value types.
const Object chatServerTimestamp = _ChatServerTimestamp();

class _ChatServerTimestamp {
  const _ChatServerTimestamp();
}

/// Placeholder a repository turns into an array-union / array-remove mutation
/// on write.
class ChatArrayOp {
  final bool union;
  final List<Object?> values;

  const ChatArrayOp.union(this.values) : union = true;
  const ChatArrayOp.remove(this.values) : union = false;
}

abstract class ChatRepository {
  /// Chats whose participants include [userId], as a live stream.
  Stream<List<ChatDoc>> watchChatsForUser(String userId);

  /// Live ordered (oldest first) message changes inside [chatId].
  Stream<List<ChatDocChange>> watchMessages(String chatId);

  /// Creates or merges a chat document.
  Future<void> mergeChat(String chatId, Map<String, dynamic> data);

  /// Creates or overwrites a chat document.
  Future<void> setChat(String chatId, Map<String, dynamic> data);

  /// Creates or overwrites a message document inside [chatId].
  Future<void> setMessage(
    String chatId,
    String messageId,
    Map<String, dynamic> data,
  );

  /// Applies field updates to a chat document.
  Future<void> updateChat(String chatId, Map<String, dynamic> updates);

  /// Applies field updates to a message document inside [chatId].
  Future<void> updateMessage(
    String chatId,
    String messageId,
    Map<String, dynamic> updates,
  );

  /// Deletes a chat document.
  Future<void> deleteChat(String chatId);
}
