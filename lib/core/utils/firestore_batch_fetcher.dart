import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';

class BatchFetchResult {
  final Map<String, Map<String, dynamic>> docsById;
  final Set<String> missingIds;
  final Set<String> deniedIds;

  const BatchFetchResult({
    required this.docsById,
    required this.missingIds,
    this.deniedIds = const <String>{},
  });
}

class FirestoreBatchFetcher {
  final FirestoreService _firestoreService;

  FirestoreBatchFetcher({required this._firestoreService});

  /// Kept at 10 (rather than Firestore's 30-element `whereIn` syntax limit) so
  /// security rules that perform a `get()` per candidate document (e.g.
  /// membership checks on `/boards` and `/workspaces`) stay within Firestore's
  /// 10-`get()` per-query limit.
  static const int chunkSize = 10;

  Future<BatchFetchResult> fetchDocumentsByIdSet({
    required String collectionPath,
    required List<String> ids,
    bool trackMissingIds = true,
  }) async {
    final docsById = <String, Map<String, dynamic>>{};
    final missingIds = <String>{};
    final deniedIds = <String>{};
    final uniqueIds = ids.toSet().toList(growable: false);

    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final chunk = uniqueIds.sublist(
        i,
        (i + chunkSize).clamp(0, uniqueIds.length),
      );

      try {
        final snapshot = await _firestoreService
            .collection(collectionPath)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc.data();
        }

        if (trackMissingIds) {
          final foundIds = snapshot.docs.map((doc) => doc.id).toSet();
          final missingChunkIds = chunk
              .where((id) => !foundIds.contains(id))
              .toList(growable: false);

          for (final id in missingChunkIds) {
            await _fetchSingleDoc(
              collectionPath: collectionPath,
              id: id,
              trackMissingIds: trackMissingIds,
              docsById: docsById,
              missingIds: missingIds,
              deniedIds: deniedIds,
            );
          }
        }
      } catch (e) {
        developer.log(
          'BatchFetch: whereIn failed ($e), falling back to individual gets for chunk',
          name: 'FirestoreBatchFetcher',
        );
        for (final id in chunk) {
          await _fetchSingleDoc(
            collectionPath: collectionPath,
            id: id,
            trackMissingIds: trackMissingIds,
            docsById: docsById,
            missingIds: missingIds,
            deniedIds: deniedIds,
          );
        }
      }
    }

    return BatchFetchResult(
      docsById: docsById,
      missingIds: missingIds,
      deniedIds: deniedIds,
    );
  }

  Future<void> _fetchSingleDoc({
    required String collectionPath,
    required String id,
    required bool trackMissingIds,
    required Map<String, Map<String, dynamic>> docsById,
    required Set<String> missingIds,
    required Set<String> deniedIds,
  }) async {
    try {
      final doc = await _firestoreService.collection(collectionPath).doc(id).get();
      if (doc.exists) {
        docsById[id] = doc.data() ?? const <String, dynamic>{};
      } else if (trackMissingIds && !doc.metadata.isFromCache) {
        missingIds.add(id);
      }
    } on FirebaseException catch (e) {
      if (trackMissingIds && e.code == 'permission-denied') {
        deniedIds.add(id);
      }
      developer.log(
        'BatchFetch: individual get for $id failed (${e.code}): $e',
        name: 'FirestoreBatchFetcher',
      );
    } catch (e) {
      developer.log(
        'BatchFetch: individual get for $id failed: $e',
        name: 'FirestoreBatchFetcher',
      );
    }
  }
}
