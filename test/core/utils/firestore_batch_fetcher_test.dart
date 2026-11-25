// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inklink/core/services/firestore_service.dart';
import 'package:inklink/core/utils/firestore_batch_fetcher.dart';

class _FakeSnapshotMetadata extends Fake implements SnapshotMetadata {
  @override
  final bool isFromCache;

  _FakeSnapshotMetadata({this.isFromCache = false});
}

class _FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  _FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;
}

class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  @override
  final bool exists;
  final Map<String, dynamic>? _data;
  @override
  final SnapshotMetadata metadata;

  _FakeDocumentSnapshot({
    required this.id,
    required this.exists,
    this._data,
    bool isFromCache = false,
  }) : metadata = _FakeSnapshotMetadata(isFromCache: isFromCache);

  @override
  Map<String, dynamic>? data() => _data;
}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  _FakeQuerySnapshot(this.docs);
}

class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final String _id;
  final _FakeCollectionReference _collection;

  _FakeDocumentReference(this._id, this._collection);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _collection.getDoc(_id);
}

class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  final List<Object?> _whereInIds;
  final _FakeCollectionReference _collection;

  _FakeQuery(this._whereInIds, this._collection);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _collection.getWhereIn(_whereInIds.cast<String>());
}

class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final Map<String, Map<String, dynamic>> docs;
  final Set<String> deniedIds;
  final Set<String> cacheOnlyMissingIds;
  final List<int> whereInChunkSizes = [];

  _FakeCollectionReference({
    required this.docs,
    this.deniedIds = const {},
    this.cacheOnlyMissingIds = const {},
  });

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _FakeDocumentReference(path!, this);

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _FakeQuery(whereIn!.toList(growable: false), this);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getWhereIn(
    List<String> ids,
  ) async {
    whereInChunkSizes.add(ids.length);
    for (final id in ids) {
      if (deniedIds.contains(id) || !docs.containsKey(id)) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        );
      }
    }
    return _FakeQuerySnapshot([
      for (final id in ids) _FakeQueryDocumentSnapshot(id, docs[id]!),
    ]);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(String id) async {
    if (deniedIds.contains(id)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
    }
    final data = docs[id];
    return _FakeDocumentSnapshot(
      id: id,
      exists: data != null,
      data: data,
      isFromCache: cacheOnlyMissingIds.contains(id),
    );
  }
}

class _FakeFirestoreService extends Fake implements FirestoreService {
  final _FakeCollectionReference boardsCollection;

  _FakeFirestoreService(this.boardsCollection);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      boardsCollection;
}

void main() {
  group('FirestoreBatchFetcher', () {
    test(
      'falls back on permission-denied whereIn and tracks missing and denied IDs',
      () async {
        final collection = _FakeCollectionReference(
          docs: {
            'board-1': {'title': 'Valid Board'},
          },
          deniedIds: {'board-denied'},
          cacheOnlyMissingIds: {'board-offline-miss'},
        );
        final fetcher = FirestoreBatchFetcher(
          firestoreService: _FakeFirestoreService(collection),
        );

        final result = await fetcher.fetchDocumentsByIdSet(
          collectionPath: 'boards',
          ids: ['board-1', 'board-missing', 'board-denied', 'board-offline-miss'],
        );

        expect(result.docsById.keys, ['board-1']);
        expect(result.docsById['board-1']?['title'], 'Valid Board');
        expect(result.missingIds, {'board-missing'});
        expect(result.deniedIds, {'board-denied'});
      },
    );

    test('returns docs directly when whereIn succeeds', () async {
      final collection = _FakeCollectionReference(
        docs: {
          'board-1': {'title': 'One'},
          'board-2': {'title': 'Two'},
        },
      );
      final fetcher = FirestoreBatchFetcher(
        firestoreService: _FakeFirestoreService(collection),
      );

      final result = await fetcher.fetchDocumentsByIdSet(
        collectionPath: 'boards',
        ids: ['board-1', 'board-2'],
      );

      expect(result.docsById.keys, containsAll(['board-1', 'board-2']));
      expect(result.missingIds, isEmpty);
      expect(result.deniedIds, isEmpty);
    });

    test('chunks 20 IDs into batches of at most 10 for whereIn', () async {
      final docs = <String, Map<String, dynamic>>{
        for (var i = 0; i < 20; i++) 'board-$i': {'title': 'Board $i'},
      };
      final collection = _FakeCollectionReference(docs: docs);
      final fetcher = FirestoreBatchFetcher(
        firestoreService: _FakeFirestoreService(collection),
      );

      final result = await fetcher.fetchDocumentsByIdSet(
        collectionPath: 'boards',
        ids: docs.keys.toList(growable: false),
      );

      expect(result.docsById.length, 20);
      expect(collection.whereInChunkSizes, [10, 10]);
    });
  });
}
