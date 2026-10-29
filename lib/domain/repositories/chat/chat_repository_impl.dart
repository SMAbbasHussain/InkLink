import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import 'chat_repository.dart';

/// Firestore-backed chat data source. Owns all database specifics
/// (field values, snapshot types, timestamp conversion) behind the
/// [ChatRepository] abstraction.
class ChatRepositoryImpl implements ChatRepository {
  final FirestoreService _firestoreService;

  ChatRepositoryImpl({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  FirebaseFirestore get _firestore => _firestoreService.getInstance();

  @override
  Stream<List<ChatDoc>> watchChatsForUser(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              ChatDoc(id: doc.id, data: _normalize(doc.data())),
          ],
        );
  }

  @override
  Stream<List<ChatDocChange>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => [
            for (final change in snapshot.docChanges)
              ChatDocChange(
                type: switch (change.type) {
                  DocumentChangeType.added => ChatDocChangeType.added,
                  DocumentChangeType.modified => ChatDocChangeType.modified,
                  DocumentChangeType.removed => ChatDocChangeType.removed,
                },
                doc: change.doc.data() == null
                    ? null
                    : ChatDoc(
                        id: change.doc.id,
                        data: _normalize(change.doc.data()!),
                      ),
              ),
          ],
        );
  }

  @override
  Future<void> mergeChat(String chatId, Map<String, dynamic> data) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .set(_materialize(data), SetOptions(merge: true));
  }

  @override
  Future<void> setChat(String chatId, Map<String, dynamic> data) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .set(_materialize(data));
  }

  @override
  Future<void> setMessage(
    String chatId,
    String messageId,
    Map<String, dynamic> data,
  ) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(_materialize(data));
  }

  @override
  Future<void> updateChat(String chatId, Map<String, dynamic> updates) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .update(_materialize(updates));
  }

  @override
  Future<void> updateMessage(
    String chatId,
    String messageId,
    Map<String, dynamic> updates,
  ) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update(_materialize(updates));
  }

  @override
  Future<void> deleteChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).delete();
  }

  /// Replaces write placeholders with database field values.
  Map<String, dynamic> _materialize(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (identical(value, chatServerTimestamp)) {
        return MapEntry(key, FieldValue.serverTimestamp());
      }
      if (value is ChatArrayOp) {
        return MapEntry(
          key,
          value.union
              ? FieldValue.arrayUnion(value.values)
              : FieldValue.arrayRemove(value.values),
        );
      }
      return MapEntry(key, value);
    });
  }

  /// Converts database-native values (e.g. timestamps) into plain Dart types.
  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _normalizeValue(v)));
    }
    if (value is List) return value.map(_normalizeValue).toList();
    return value;
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _normalizeValue(v)));
  }
}
