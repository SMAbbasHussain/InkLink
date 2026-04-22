// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_board.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalBoardCollection on Isar {
  IsarCollection<LocalBoard> get localBoards => this.collection();
}

const LocalBoardSchema = CollectionSchema(
  name: r'LocalBoard',
  id: 7827830612906253906,
  properties: {
    r'boardId': PropertySchema(id: 0, name: r'boardId', type: IsarType.string),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'currentUserRole': PropertySchema(
      id: 2,
      name: r'currentUserRole',
      type: IsarType.string,
    ),
    r'defaultLinkJoinRole': PropertySchema(
      id: 3,
      name: r'defaultLinkJoinRole',
      type: IsarType.string,
    ),
    r'engine': PropertySchema(id: 4, name: r'engine', type: IsarType.string),
    r'isSynced': PropertySchema(id: 5, name: r'isSynced', type: IsarType.bool),
    r'joinViaCodeEnabled': PropertySchema(
      id: 6,
      name: r'joinViaCodeEnabled',
      type: IsarType.bool,
    ),
    r'members': PropertySchema(
      id: 7,
      name: r'members',
      type: IsarType.stringList,
    ),
    r'ownerId': PropertySchema(id: 8, name: r'ownerId', type: IsarType.string),
    r'previewPath': PropertySchema(
      id: 9,
      name: r'previewPath',
      type: IsarType.string,
    ),
    r'privateJoinPolicy': PropertySchema(
      id: 10,
      name: r'privateJoinPolicy',
      type: IsarType.string,
    ),
    r'tags': PropertySchema(id: 11, name: r'tags', type: IsarType.stringList),
    r'title': PropertySchema(id: 12, name: r'title', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 13,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'visibility': PropertySchema(
      id: 14,
      name: r'visibility',
      type: IsarType.string,
    ),
    r'whoCanInvite': PropertySchema(
      id: 15,
      name: r'whoCanInvite',
      type: IsarType.string,
    ),
  },

  estimateSize: _localBoardEstimateSize,
  serialize: _localBoardSerialize,
  deserialize: _localBoardDeserialize,
  deserializeProp: _localBoardDeserializeProp,
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

  getId: _localBoardGetId,
  getLinks: _localBoardGetLinks,
  attach: _localBoardAttach,
  version: '3.3.2',
);

int _localBoardEstimateSize(
  LocalBoard object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.boardId.length * 3;
  bytesCount += 3 + object.currentUserRole.length * 3;
  bytesCount += 3 + object.defaultLinkJoinRole.length * 3;
  bytesCount += 3 + object.engine.length * 3;
  bytesCount += 3 + object.members.length * 3;
  {
    for (var i = 0; i < object.members.length; i++) {
      final value = object.members[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerId.length * 3;
  {
    final value = object.previewPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.privateJoinPolicy.length * 3;
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.visibility.length * 3;
  bytesCount += 3 + object.whoCanInvite.length * 3;
  return bytesCount;
}

void _localBoardSerialize(
  LocalBoard object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.boardId);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.currentUserRole);
  writer.writeString(offsets[3], object.defaultLinkJoinRole);
  writer.writeString(offsets[4], object.engine);
  writer.writeBool(offsets[5], object.isSynced);
  writer.writeBool(offsets[6], object.joinViaCodeEnabled);
  writer.writeStringList(offsets[7], object.members);
  writer.writeString(offsets[8], object.ownerId);
  writer.writeString(offsets[9], object.previewPath);
  writer.writeString(offsets[10], object.privateJoinPolicy);
  writer.writeStringList(offsets[11], object.tags);
  writer.writeString(offsets[12], object.title);
  writer.writeDateTime(offsets[13], object.updatedAt);
  writer.writeString(offsets[14], object.visibility);
  writer.writeString(offsets[15], object.whoCanInvite);
}

LocalBoard _localBoardDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalBoard();
  object.boardId = reader.readString(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.currentUserRole = reader.readString(offsets[2]);
  object.defaultLinkJoinRole = reader.readString(offsets[3]);
  object.engine = reader.readString(offsets[4]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[5]);
  object.joinViaCodeEnabled = reader.readBool(offsets[6]);
  object.members = reader.readStringList(offsets[7]) ?? [];
  object.ownerId = reader.readString(offsets[8]);
  object.previewPath = reader.readStringOrNull(offsets[9]);
  object.privateJoinPolicy = reader.readString(offsets[10]);
  object.tags = reader.readStringList(offsets[11]) ?? [];
  object.title = reader.readString(offsets[12]);
  object.updatedAt = reader.readDateTime(offsets[13]);
  object.visibility = reader.readString(offsets[14]);
  object.whoCanInvite = reader.readString(offsets[15]);
  return object;
}

P _localBoardDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readStringList(offset) ?? []) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readStringList(offset) ?? []) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readDateTime(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localBoardGetId(LocalBoard object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localBoardGetLinks(LocalBoard object) {
  return [];
}

void _localBoardAttach(IsarCollection<dynamic> col, Id id, LocalBoard object) {
  object.id = id;
}

extension LocalBoardByIndex on IsarCollection<LocalBoard> {
  Future<LocalBoard?> getByBoardId(String boardId) {
    return getByIndex(r'boardId', [boardId]);
  }

  LocalBoard? getByBoardIdSync(String boardId) {
    return getByIndexSync(r'boardId', [boardId]);
  }

  Future<bool> deleteByBoardId(String boardId) {
    return deleteByIndex(r'boardId', [boardId]);
  }

  bool deleteByBoardIdSync(String boardId) {
    return deleteByIndexSync(r'boardId', [boardId]);
  }

  Future<List<LocalBoard?>> getAllByBoardId(List<String> boardIdValues) {
    final values = boardIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'boardId', values);
  }

  List<LocalBoard?> getAllByBoardIdSync(List<String> boardIdValues) {
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

  Future<Id> putByBoardId(LocalBoard object) {
    return putByIndex(r'boardId', object);
  }

  Id putByBoardIdSync(LocalBoard object, {bool saveLinks = true}) {
    return putByIndexSync(r'boardId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBoardId(List<LocalBoard> objects) {
    return putAllByIndex(r'boardId', objects);
  }

  List<Id> putAllByBoardIdSync(
    List<LocalBoard> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'boardId', objects, saveLinks: saveLinks);
  }
}

extension LocalBoardQueryWhereSort
    on QueryBuilder<LocalBoard, LocalBoard, QWhere> {
  QueryBuilder<LocalBoard, LocalBoard, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalBoardQueryWhere
    on QueryBuilder<LocalBoard, LocalBoard, QWhereClause> {
  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> boardIdEqualTo(
    String boardId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'boardId', value: [boardId]),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterWhereClause> boardIdNotEqualTo(
    String boardId,
  ) {
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

extension LocalBoardQueryFilter
    on QueryBuilder<LocalBoard, LocalBoard, QFilterCondition> {
  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdLessThan(
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdBetween(
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> boardIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardId', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  boardIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'boardId', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'currentUserRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'currentUserRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'currentUserRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'currentUserRole',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'currentUserRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'currentUserRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'currentUserRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'currentUserRole',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'currentUserRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  currentUserRoleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'currentUserRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'defaultLinkJoinRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'defaultLinkJoinRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'defaultLinkJoinRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'defaultLinkJoinRole',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'defaultLinkJoinRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'defaultLinkJoinRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'defaultLinkJoinRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'defaultLinkJoinRole',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'defaultLinkJoinRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  defaultLinkJoinRoleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'defaultLinkJoinRole',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'engine',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'engine',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'engine',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'engine',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'engine',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'engine',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'engine',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'engine',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> engineIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'engine', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  engineIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'engine', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> idBetween(
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

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> isSyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  joinViaCodeEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'joinViaCodeEnabled', value: value),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'members',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'members',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'members',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'members',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'members',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'members',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'members',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'members',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'members', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'members', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'members', length, true, length, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> membersIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'members', 0, true, 0, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'members', 0, false, 999999, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'members', 0, true, length, include);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'members', length, include, 999999, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  membersLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'members',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  ownerIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> ownerIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerId', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  ownerIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerId', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'previewPath'),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'previewPath'),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'previewPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'previewPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'previewPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'previewPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'previewPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'previewPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'previewPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'previewPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'previewPath', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  previewPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'previewPath', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'privateJoinPolicy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'privateJoinPolicy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'privateJoinPolicy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'privateJoinPolicy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'privateJoinPolicy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'privateJoinPolicy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'privateJoinPolicy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'privateJoinPolicy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'privateJoinPolicy', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  privateJoinPolicyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'privateJoinPolicy', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tags',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tags',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tags',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tags', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tags', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> tagsLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', length, true, length, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, true, 0, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, false, 999999, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', 0, true, length, include);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  tagsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'tags', length, include, 999999, true);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> visibilityEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'visibility',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'visibility',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'visibility',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> visibilityBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'visibility',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'visibility',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'visibility',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'visibility',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition> visibilityMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'visibility',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'visibility', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  visibilityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'visibility', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'whoCanInvite',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'whoCanInvite',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'whoCanInvite',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'whoCanInvite',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'whoCanInvite',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'whoCanInvite',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'whoCanInvite',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'whoCanInvite',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'whoCanInvite', value: ''),
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterFilterCondition>
  whoCanInviteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'whoCanInvite', value: ''),
      );
    });
  }
}

extension LocalBoardQueryObject
    on QueryBuilder<LocalBoard, LocalBoard, QFilterCondition> {}

extension LocalBoardQueryLinks
    on QueryBuilder<LocalBoard, LocalBoard, QFilterCondition> {}

extension LocalBoardQuerySortBy
    on QueryBuilder<LocalBoard, LocalBoard, QSortBy> {
  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByCurrentUserRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  sortByCurrentUserRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  sortByDefaultLinkJoinRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultLinkJoinRole', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  sortByDefaultLinkJoinRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultLinkJoinRole', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByEngine() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engine', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByEngineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engine', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  sortByJoinViaCodeEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinViaCodeEnabled', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  sortByJoinViaCodeEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinViaCodeEnabled', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByOwnerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByOwnerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByPreviewPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previewPath', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByPreviewPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previewPath', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByPrivateJoinPolicy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'privateJoinPolicy', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  sortByPrivateJoinPolicyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'privateJoinPolicy', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByVisibility() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibility', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByVisibilityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibility', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByWhoCanInvite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whoCanInvite', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> sortByWhoCanInviteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whoCanInvite', Sort.desc);
    });
  }
}

extension LocalBoardQuerySortThenBy
    on QueryBuilder<LocalBoard, LocalBoard, QSortThenBy> {
  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByCurrentUserRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  thenByCurrentUserRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  thenByDefaultLinkJoinRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultLinkJoinRole', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  thenByDefaultLinkJoinRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultLinkJoinRole', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByEngine() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engine', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByEngineDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'engine', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  thenByJoinViaCodeEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinViaCodeEnabled', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  thenByJoinViaCodeEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'joinViaCodeEnabled', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByOwnerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByOwnerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByPreviewPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previewPath', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByPreviewPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previewPath', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByPrivateJoinPolicy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'privateJoinPolicy', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy>
  thenByPrivateJoinPolicyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'privateJoinPolicy', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByVisibility() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibility', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByVisibilityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'visibility', Sort.desc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByWhoCanInvite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whoCanInvite', Sort.asc);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QAfterSortBy> thenByWhoCanInviteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whoCanInvite', Sort.desc);
    });
  }
}

extension LocalBoardQueryWhereDistinct
    on QueryBuilder<LocalBoard, LocalBoard, QDistinct> {
  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByBoardId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByCurrentUserRole({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'currentUserRole',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct>
  distinctByDefaultLinkJoinRole({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'defaultLinkJoinRole',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByEngine({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'engine', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct>
  distinctByJoinViaCodeEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'joinViaCodeEnabled');
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByMembers() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'members');
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByOwnerId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByPreviewPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'previewPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByPrivateJoinPolicy({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'privateJoinPolicy',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByVisibility({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'visibility', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBoard, LocalBoard, QDistinct> distinctByWhoCanInvite({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'whoCanInvite', caseSensitive: caseSensitive);
    });
  }
}

extension LocalBoardQueryProperty
    on QueryBuilder<LocalBoard, LocalBoard, QQueryProperty> {
  QueryBuilder<LocalBoard, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> boardIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardId');
    });
  }

  QueryBuilder<LocalBoard, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> currentUserRoleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentUserRole');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations>
  defaultLinkJoinRoleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultLinkJoinRole');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> engineProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'engine');
    });
  }

  QueryBuilder<LocalBoard, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalBoard, bool, QQueryOperations>
  joinViaCodeEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'joinViaCodeEnabled');
    });
  }

  QueryBuilder<LocalBoard, List<String>, QQueryOperations> membersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'members');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> ownerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerId');
    });
  }

  QueryBuilder<LocalBoard, String?, QQueryOperations> previewPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'previewPath');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations>
  privateJoinPolicyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'privateJoinPolicy');
    });
  }

  QueryBuilder<LocalBoard, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<LocalBoard, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> visibilityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'visibility');
    });
  }

  QueryBuilder<LocalBoard, String, QQueryOperations> whoCanInviteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'whoCanInvite');
    });
  }
}
