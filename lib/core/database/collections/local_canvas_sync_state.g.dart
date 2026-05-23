// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_canvas_sync_state.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalCanvasSyncStateCollection on Isar {
  IsarCollection<LocalCanvasSyncState> get localCanvasSyncStates =>
      this.collection();
}

const LocalCanvasSyncStateSchema = CollectionSchema(
  name: r'LocalCanvasSyncState',
  id: -4320614062720103140,
  properties: {
    r'boardId': PropertySchema(id: 0, name: r'boardId', type: IsarType.string),
    r'lastAppliedVersion': PropertySchema(
      id: 1,
      name: r'lastAppliedVersion',
      type: IsarType.long,
    ),
    r'lastSnapshotAt': PropertySchema(
      id: 2,
      name: r'lastSnapshotAt',
      type: IsarType.dateTime,
    ),
    r'lastSnapshotVersion': PropertySchema(
      id: 3,
      name: r'lastSnapshotVersion',
      type: IsarType.long,
    ),
    r'lastSyncedAppliedAt': PropertySchema(
      id: 4,
      name: r'lastSyncedAppliedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _localCanvasSyncStateEstimateSize,
  serialize: _localCanvasSyncStateSerialize,
  deserialize: _localCanvasSyncStateDeserialize,
  deserializeProp: _localCanvasSyncStateDeserializeProp,
  idName: r'id',
  indexes: {
    r'boardId': IndexSchema(
      id: 8343624544803511651,
      name: r'boardId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'boardId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localCanvasSyncStateGetId,
  getLinks: _localCanvasSyncStateGetLinks,
  attach: _localCanvasSyncStateAttach,
  version: '3.3.2',
);

int _localCanvasSyncStateEstimateSize(
  LocalCanvasSyncState object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.boardId.length * 3;
  return bytesCount;
}

void _localCanvasSyncStateSerialize(
  LocalCanvasSyncState object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.boardId);
  writer.writeLong(offsets[1], object.lastAppliedVersion);
  writer.writeDateTime(offsets[2], object.lastSnapshotAt);
  writer.writeLong(offsets[3], object.lastSnapshotVersion);
  writer.writeDateTime(offsets[4], object.lastSyncedAppliedAt);
}

LocalCanvasSyncState _localCanvasSyncStateDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalCanvasSyncState();
  object.boardId = reader.readString(offsets[0]);
  object.id = id;
  object.lastAppliedVersion = reader.readLong(offsets[1]);
  object.lastSnapshotAt = reader.readDateTimeOrNull(offsets[2]);
  object.lastSnapshotVersion = reader.readLong(offsets[3]);
  object.lastSyncedAppliedAt = reader.readDateTimeOrNull(offsets[4]);
  return object;
}

P _localCanvasSyncStateDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localCanvasSyncStateGetId(LocalCanvasSyncState object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localCanvasSyncStateGetLinks(
  LocalCanvasSyncState object,
) {
  return [];
}

void _localCanvasSyncStateAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalCanvasSyncState object,
) {
  object.id = id;
}

extension LocalCanvasSyncStateByIndex on IsarCollection<LocalCanvasSyncState> {
  Future<LocalCanvasSyncState?> getByBoardId(String boardId) {
    return getByIndex(r'boardId', [boardId]);
  }

  LocalCanvasSyncState? getByBoardIdSync(String boardId) {
    return getByIndexSync(r'boardId', [boardId]);
  }

  Future<bool> deleteByBoardId(String boardId) {
    return deleteByIndex(r'boardId', [boardId]);
  }

  bool deleteByBoardIdSync(String boardId) {
    return deleteByIndexSync(r'boardId', [boardId]);
  }

  Future<List<LocalCanvasSyncState?>> getAllByBoardId(
    List<String> boardIdValues,
  ) {
    final values = boardIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'boardId', values);
  }

  List<LocalCanvasSyncState?> getAllByBoardIdSync(List<String> boardIdValues) {
    final values = boardIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'boardId', values);
  }

  Future<int> deleteAllByBoardId(List<String> boardIdValues) {
    final values = boardIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'boardId', values);
  }

  int deleteAllByBoardIdSync(List<String> boardIdValues) {
    final values = boardIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'boardId', values);
  }

  Future<Id> putByBoardId(LocalCanvasSyncState object) {
    return putByIndex(r'boardId', object);
  }

  Id putByBoardIdSync(LocalCanvasSyncState object, {bool saveLinks = true}) {
    return putByIndexSync(r'boardId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBoardId(List<LocalCanvasSyncState> objects) {
    return putAllByIndex(r'boardId', objects);
  }

  List<Id> putAllByBoardIdSync(
    List<LocalCanvasSyncState> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'boardId', objects, saveLinks: saveLinks);
  }
}

extension LocalCanvasSyncStateQueryWhereSort
    on QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QWhere> {
  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalCanvasSyncStateQueryWhere
    on QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QWhereClause> {
  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  boardIdEqualTo(String boardId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'boardId', value: [boardId]),
      );
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterWhereClause>
  boardIdNotEqualTo(String boardId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'boardId',
                lower: [],
                upper: [boardId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'boardId',
                lower: [boardId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'boardId',
                lower: [boardId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'boardId',
                lower: [],
                upper: [boardId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LocalCanvasSyncStateQueryFilter
    on
        QueryBuilder<
          LocalCanvasSyncState,
          LocalCanvasSyncState,
          QFilterCondition
        > {
  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'boardId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'boardId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'boardId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'boardId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'boardId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'boardId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'boardId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'boardId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardId', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  boardIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'boardId', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastAppliedVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastAppliedVersion', value: value),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastAppliedVersionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastAppliedVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastAppliedVersionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastAppliedVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastAppliedVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastAppliedVersion',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSnapshotAt'),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSnapshotAt'),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSnapshotAt', value: value),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSnapshotAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSnapshotAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSnapshotAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSnapshotVersion', value: value),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotVersionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSnapshotVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotVersionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSnapshotVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSnapshotVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSnapshotVersion',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSyncedAppliedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSyncedAppliedAt'),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSyncedAppliedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSyncedAppliedAt'),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSyncedAppliedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncedAppliedAt', value: value),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSyncedAppliedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncedAppliedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSyncedAppliedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncedAppliedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalCanvasSyncState,
    LocalCanvasSyncState,
    QAfterFilterCondition
  >
  lastSyncedAppliedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncedAppliedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension LocalCanvasSyncStateQueryObject
    on
        QueryBuilder<
          LocalCanvasSyncState,
          LocalCanvasSyncState,
          QFilterCondition
        > {}

extension LocalCanvasSyncStateQueryLinks
    on
        QueryBuilder<
          LocalCanvasSyncState,
          LocalCanvasSyncState,
          QFilterCondition
        > {}

extension LocalCanvasSyncStateQuerySortBy
    on QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QSortBy> {
  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastAppliedVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedVersion', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastAppliedVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedVersion', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastSnapshotAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotAt', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastSnapshotAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotAt', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastSnapshotVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotVersion', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastSnapshotVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotVersion', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastSyncedAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAppliedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  sortByLastSyncedAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAppliedAt', Sort.desc);
    });
  }
}

extension LocalCanvasSyncStateQuerySortThenBy
    on QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QSortThenBy> {
  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastAppliedVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedVersion', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastAppliedVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastAppliedVersion', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastSnapshotAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotAt', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastSnapshotAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotAt', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastSnapshotVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotVersion', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastSnapshotVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSnapshotVersion', Sort.desc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastSyncedAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAppliedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QAfterSortBy>
  thenByLastSyncedAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAppliedAt', Sort.desc);
    });
  }
}

extension LocalCanvasSyncStateQueryWhereDistinct
    on QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QDistinct> {
  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QDistinct>
  distinctByBoardId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QDistinct>
  distinctByLastAppliedVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastAppliedVersion');
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QDistinct>
  distinctByLastSnapshotAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSnapshotAt');
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QDistinct>
  distinctByLastSnapshotVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSnapshotVersion');
    });
  }

  QueryBuilder<LocalCanvasSyncState, LocalCanvasSyncState, QDistinct>
  distinctByLastSyncedAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncedAppliedAt');
    });
  }
}

extension LocalCanvasSyncStateQueryProperty
    on
        QueryBuilder<
          LocalCanvasSyncState,
          LocalCanvasSyncState,
          QQueryProperty
        > {
  QueryBuilder<LocalCanvasSyncState, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalCanvasSyncState, String, QQueryOperations>
  boardIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardId');
    });
  }

  QueryBuilder<LocalCanvasSyncState, int, QQueryOperations>
  lastAppliedVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastAppliedVersion');
    });
  }

  QueryBuilder<LocalCanvasSyncState, DateTime?, QQueryOperations>
  lastSnapshotAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSnapshotAt');
    });
  }

  QueryBuilder<LocalCanvasSyncState, int, QQueryOperations>
  lastSnapshotVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSnapshotVersion');
    });
  }

  QueryBuilder<LocalCanvasSyncState, DateTime?, QQueryOperations>
  lastSyncedAppliedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncedAppliedAt');
    });
  }
}
