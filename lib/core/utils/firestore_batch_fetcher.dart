import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';

class BatchFetchResult {
  final Map<String, Map<String, dynamic>> docsById;
  final Set<String> missingIds;

  const BatchFetchResult({required this.docsById, required this.missingIds});
}

class FirestoreBatchFetcher {
  final FirestoreService _firestoreService;

  FirestoreBatchFetcher({required FirestoreService firestoreService})
    : _firestoreService = firestoreService;

  static const int chunkSize = 30;

  Future<BatchFetchResult> fetchDocumentsByIdSet({
    required String collectionPath,
    required List<String> ids,
    bool trackMissingIds = true,
  }) async {
    final docsById = <String, Map<String, dynamic>>{};
    final missingIds = <String>{};
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
            try {
              final doc = await _firestoreService
                  .collection(collectionPath)
                  .doc(id)
                  .get();
              if (doc.exists) {
                docsById[id] = doc.data() ?? const <String, dynamic>{};
              } else {
                missingIds.add(id);
              }
            } catch (e) {
              developer.log(
                'BatchFetch: individual get for $id failed: $e',
                name: 'FirestoreBatchFetcher',
              );
            }
          }
        }
      } catch (e) {
        developer.log(
          'BatchFetch: whereIn failed ($e), falling back to individual gets for chunk',
          name: 'FirestoreBatchFetcher',
        );
        for (final id in chunk) {
          try {
            final doc = await _firestoreService
                .collection(collectionPath)
                .doc(id)
                .get();
            if (doc.exists) {
              docsById[id] = doc.data() ?? const <String, dynamic>{};
            } else if (trackMissingIds) {
              missingIds.add(id);
            }
          } catch (e) {
            developer.log(
              'BatchFetch: individual get for $id failed (fallback): $e',
              name: 'FirestoreBatchFetcher',
            );
          }
        }
      }
    }

    return BatchFetchResult(docsById: docsById, missingIds: missingIds);
  }
}
