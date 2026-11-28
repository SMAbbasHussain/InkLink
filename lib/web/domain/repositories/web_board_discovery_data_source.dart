import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_service.dart';
import '../../../domain/models/board.dart';

/// Public-board discovery and tag-recommendation queries for [WebBoardRepository].
class WebBoardDiscoveryDataSource {
  final FirestoreService _db;

  WebBoardDiscoveryDataSource({required FirestoreService firestoreService})
    : _db = firestoreService;

  Future<PublicBoardsPage> getPublicBoards({
    String? tag,
    PublicBoardSort sort = PublicBoardSort.recent,
    dynamic lastDocCursor,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(FirestorePaths.boards)
        .where(FirestorePaths.visibility, isEqualTo: Board.visibilityPublic);

    final normalizedTag = tag?.trim().toLowerCase();
    if (normalizedTag != null && normalizedTag.isNotEmpty) {
      query = query.where(FirestorePaths.tags, arrayContains: normalizedTag);
    }

    if (sort == PublicBoardSort.popular) {
      query = query
          .orderBy('membersCount', descending: true)
          .orderBy(FirestorePaths.createdAt, descending: true);
    } else {
      query = query.orderBy(FirestorePaths.createdAt, descending: true);
    }

    if (lastDocCursor is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(lastDocCursor);
    }

    final snapshot = await query.limit(limit).get();
    final boards = snapshot.docs
        .map((doc) => Board.fromMap(doc.data(), doc.id))
        .where((b) => !b.isArchived)
        .toList();

    return PublicBoardsPage(
      boards: boards,
      lastDocCursor: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  Future<List<Board>> getRecommendedPublicBoards({
    required List<String> preferredTags,
    int limit = 10,
  }) async {
    final cleaned = preferredTags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .take(10)
        .toList();
    if (cleaned.isEmpty) {
      return (await getPublicBoards(limit: limit)).boards;
    }
    try {
      final snapshot = await _db
          .collection(FirestorePaths.boards)
          .where(FirestorePaths.visibility, isEqualTo: Board.visibilityPublic)
          .where(FirestorePaths.tags, arrayContainsAny: cleaned)
          .limit(limit * 2)
          .get();
      final boards = snapshot.docs
          .map((doc) => Board.fromMap(doc.data(), doc.id))
          .where((b) => !b.isArchived)
          .toList();
      final preferred = preferredTags
          .map((t) => t.trim().toLowerCase())
          .toSet();
      boards.sort((a, b) {
        final aMatches = a.tags
            .where((t) => preferred.contains(t.toLowerCase()))
            .length;
        final bMatches = b.tags
            .where((t) => preferred.contains(t.toLowerCase()))
            .length;
        if (bMatches != aMatches) return bMatches.compareTo(aMatches);
        return b.membersCount.compareTo(a.membersCount);
      });
      return boards.take(limit).toList();
    } catch (_) {
      return (await getPublicBoards(limit: limit)).boards;
    }
  }
}
