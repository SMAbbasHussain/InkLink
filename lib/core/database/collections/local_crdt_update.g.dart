// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_crdt_update.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalCrdtUpdateCollection on Isar {
  IsarCollection<LocalCrdtUpdate> get localCrdtUpdates => this.collection();
}

const LocalCrdtUpdateSchema = CollectionSchema(
  name: r'LocalCrdtUpdate',
  id: -702672807571368826,
  properties: {
    r'appliedAt': PropertySchema(
      id: 0,
      name: r'appliedAt',
      type: IsarType.dateTime,
    ),
    r'boardId': PropertySchema(
      id: 1,
      name: r'boardId',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(
      id: 2,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'payloadBase64': PropertySchema(
      id: 3,
      name: r'payloadBase64',
      type: IsarType.string,
    ),
    r'sourceClientId': PropertySchema(
      id: 4,
      name: r'sourceClientId',
      type: IsarType.string,
    ),
    r'updateId': PropertySchema(
      id: 5,
      name: r'updateId',
      type: IsarType.string,
    )
  },
  estimateSize: _localCrdtUpdateEstimateSize,
  serialize: _localCrdtUpdateSerialize,
  deserialize: _localCrdtUpdateDeserialize,
  deserializeProp: _localCrdtUpdateDeserializeProp,
  idName: r'id',
  indexes: {
    r'updateId': IndexSchema(
      id: -2230594592940935197,
      name: r'updateId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'updateId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'boardId': IndexSchema(
      id: 8343624544803511651,
      name: r'boardId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'boardId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _localCrdtUpdateGetId,
  getLinks: _localCrdtUpdateGetLinks,
  attach: _localCrdtUpdateAttach,
  version: '3.1.0+1',
);

int _localCrdtUpdateEstimateSize(
  LocalCrdtUpdate object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.boardId.length * 3;
  bytesCount += 3 + object.payloadBase64.length * 3;
  bytesCount += 3 + object.sourceClientId.length * 3;
  bytesCount += 3 + object.updateId.length * 3;
  return bytesCount;
}

void _localCrdtUpdateSerialize(
  LocalCrdtUpdate object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.appliedAt);
  writer.writeString(offsets[1], object.boardId);
  writer.writeBool(offsets[2], object.isSynced);
  writer.writeString(offsets[3], object.payloadBase64);
  writer.writeString(offsets[4], object.sourceClientId);
  writer.writeString(offsets[5], object.updateId);
}

LocalCrdtUpdate _localCrdtUpdateDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalCrdtUpdate();
  object.appliedAt = reader.readDateTime(offsets[0]);
  object.boardId = reader.readString(offsets[1]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[2]);
  object.payloadBase64 = reader.readString(offsets[3]);
  object.sourceClientId = reader.readString(offsets[4]);
  object.updateId = reader.readString(offsets[5]);
  return object;
}

P _localCrdtUpdateDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localCrdtUpdateGetId(LocalCrdtUpdate object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localCrdtUpdateGetLinks(LocalCrdtUpdate object) {
  return [];
}

void _localCrdtUpdateAttach(
    IsarCollection<dynamic> col, Id id, LocalCrdtUpdate object) {
  object.id = id;
}

extension LocalCrdtUpdateByIndex on IsarCollection<LocalCrdtUpdate> {
  Future<LocalCrdtUpdate?> getByUpdateId(String updateId) {
    return getByIndex(r'updateId', [updateId]);
  }

  LocalCrdtUpdate? getByUpdateIdSync(String updateId) {
    return getByIndexSync(r'updateId', [updateId]);
  }

  Future<bool> deleteByUpdateId(String updateId) {
    return deleteByIndex(r'updateId', [updateId]);
  }

  bool deleteByUpdateIdSync(String updateId) {
    return deleteByIndexSync(r'updateId', [updateId]);
  }

  Future<List<LocalCrdtUpdate?>> getAllByUpdateId(List<String> updateIdValues) {
    final values = updateIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'updateId', values);
  }

  List<LocalCrdtUpdate?> getAllByUpdateIdSync(List<String> updateIdValues) {
    final values = updateIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'updateId', values);
  }

  Future<int> deleteAllByUpdateId(List<String> updateIdValues) {
    final values = updateIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'updateId', values);
  }

  int deleteAllByUpdateIdSync(List<String> updateIdValues) {
    final values = updateIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'updateId', values);
  }

  Future<Id> putByUpdateId(LocalCrdtUpdate object) {
    return putByIndex(r'updateId', object);
  }

  Id putByUpdateIdSync(LocalCrdtUpdate object, {bool saveLinks = true}) {
    return putByIndexSync(r'updateId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUpdateId(List<LocalCrdtUpdate> objects) {
    return putAllByIndex(r'updateId', objects);
  }

  List<Id> putAllByUpdateIdSync(List<LocalCrdtUpdate> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'updateId', objects, saveLinks: saveLinks);
  }
}

extension LocalCrdtUpdateQueryWhereSort
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QWhere> {
  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalCrdtUpdateQueryWhere
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QWhereClause> {
  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause>
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

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause>
      updateIdEqualTo(String updateId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updateId',
        value: [updateId],
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause>
      updateIdNotEqualTo(String updateId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updateId',
              lower: [],
              upper: [updateId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updateId',
              lower: [updateId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updateId',
              lower: [updateId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updateId',
              lower: [],
              upper: [updateId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause>
      boardIdEqualTo(String boardId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'boardId',
        value: [boardId],
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterWhereClause>
      boardIdNotEqualTo(String boardId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'boardId',
              lower: [],
              upper: [boardId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'boardId',
              lower: [boardId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'boardId',
              lower: [boardId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'boardId',
              lower: [],
              upper: [boardId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension LocalCrdtUpdateQueryFilter
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QFilterCondition> {
  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      appliedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      appliedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      appliedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appliedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      appliedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appliedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'boardId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'boardId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'boardId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'boardId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'boardId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'boardId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'boardId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'boardId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'boardId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      boardIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'boardId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64EqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64GreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'payloadBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64LessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'payloadBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64Between(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'payloadBase64',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'payloadBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'payloadBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64Contains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payloadBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64Matches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payloadBase64',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      payloadBase64IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payloadBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceClientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceClientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceClientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceClientId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceClientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceClientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceClientId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceClientId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceClientId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      sourceClientIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceClientId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updateId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'updateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'updateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'updateId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'updateId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updateId',
        value: '',
      ));
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterFilterCondition>
      updateIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'updateId',
        value: '',
      ));
    });
  }
}

extension LocalCrdtUpdateQueryObject
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QFilterCondition> {}

extension LocalCrdtUpdateQueryLinks
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QFilterCondition> {}

extension LocalCrdtUpdateQuerySortBy
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QSortBy> {
  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy> sortByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByPayloadBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadBase64', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByPayloadBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadBase64', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortBySourceClientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceClientId', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortBySourceClientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceClientId', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByUpdateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updateId', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      sortByUpdateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updateId', Sort.desc);
    });
  }
}

extension LocalCrdtUpdateQuerySortThenBy
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QSortThenBy> {
  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByAppliedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appliedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy> thenByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByPayloadBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadBase64', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByPayloadBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadBase64', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenBySourceClientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceClientId', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenBySourceClientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceClientId', Sort.desc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByUpdateId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updateId', Sort.asc);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QAfterSortBy>
      thenByUpdateIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updateId', Sort.desc);
    });
  }
}

extension LocalCrdtUpdateQueryWhereDistinct
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct> {
  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct>
      distinctByAppliedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appliedAt');
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct> distinctByBoardId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct>
      distinctByPayloadBase64({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadBase64',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct>
      distinctBySourceClientId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceClientId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QDistinct> distinctByUpdateId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updateId', caseSensitive: caseSensitive);
    });
  }
}

extension LocalCrdtUpdateQueryProperty
    on QueryBuilder<LocalCrdtUpdate, LocalCrdtUpdate, QQueryProperty> {
  QueryBuilder<LocalCrdtUpdate, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalCrdtUpdate, DateTime, QQueryOperations>
      appliedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appliedAt');
    });
  }

  QueryBuilder<LocalCrdtUpdate, String, QQueryOperations> boardIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardId');
    });
  }

  QueryBuilder<LocalCrdtUpdate, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalCrdtUpdate, String, QQueryOperations>
      payloadBase64Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadBase64');
    });
  }

  QueryBuilder<LocalCrdtUpdate, String, QQueryOperations>
      sourceClientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceClientId');
    });
  }

  QueryBuilder<LocalCrdtUpdate, String, QQueryOperations> updateIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updateId');
    });
  }
}
