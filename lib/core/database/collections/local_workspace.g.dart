// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_workspace.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalWorkspaceCollection on Isar {
  IsarCollection<LocalWorkspace> get localWorkspaces => this.collection();
}

const LocalWorkspaceSchema = CollectionSchema(
  name: r'LocalWorkspace',
  id: 2637784876683062536,
  properties: {
    r'boardCount': PropertySchema(
      id: 0,
      name: r'boardCount',
      type: IsarType.long,
    ),
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
    r'description': PropertySchema(
      id: 3,
      name: r'description',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(id: 4, name: r'isSynced', type: IsarType.bool),
    r'memberCount': PropertySchema(
      id: 5,
      name: r'memberCount',
      type: IsarType.long,
    ),
    r'name': PropertySchema(id: 6, name: r'name', type: IsarType.string),
    r'ownerId': PropertySchema(id: 7, name: r'ownerId', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'workspaceId': PropertySchema(
      id: 9,
      name: r'workspaceId',
      type: IsarType.string,
    ),
  },

  estimateSize: _localWorkspaceEstimateSize,
  serialize: _localWorkspaceSerialize,
  deserialize: _localWorkspaceDeserialize,
  deserializeProp: _localWorkspaceDeserializeProp,
  idName: r'id',
  indexes: {
    r'currentUserRole': IndexSchema(
      id: -4775320352055603020,
      name: r'currentUserRole',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'currentUserRole',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'isSynced': IndexSchema(
      id: -39763503327887510,
      name: r'isSynced',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isSynced',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localWorkspaceGetId,
  getLinks: _localWorkspaceGetLinks,
  attach: _localWorkspaceAttach,
  version: '3.3.2',
);

int _localWorkspaceEstimateSize(
  LocalWorkspace object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.currentUserRole.length * 3;
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.ownerId.length * 3;
  bytesCount += 3 + object.workspaceId.length * 3;
  return bytesCount;
}

void _localWorkspaceSerialize(
  LocalWorkspace object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.boardCount);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.currentUserRole);
  writer.writeString(offsets[3], object.description);
  writer.writeBool(offsets[4], object.isSynced);
  writer.writeLong(offsets[5], object.memberCount);
  writer.writeString(offsets[6], object.name);
  writer.writeString(offsets[7], object.ownerId);
  writer.writeDateTime(offsets[8], object.updatedAt);
  writer.writeString(offsets[9], object.workspaceId);
}

LocalWorkspace _localWorkspaceDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalWorkspace();
  object.boardCount = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.currentUserRole = reader.readString(offsets[2]);
  object.description = reader.readString(offsets[3]);
  object.id = id;
  object.isSynced = reader.readBool(offsets[4]);
  object.memberCount = reader.readLong(offsets[5]);
  object.name = reader.readString(offsets[6]);
  object.ownerId = reader.readString(offsets[7]);
  object.updatedAt = reader.readDateTime(offsets[8]);
  object.workspaceId = reader.readString(offsets[9]);
  return object;
}

P _localWorkspaceDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localWorkspaceGetId(LocalWorkspace object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localWorkspaceGetLinks(LocalWorkspace object) {
  return [];
}

void _localWorkspaceAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalWorkspace object,
) {
  object.id = id;
}

extension LocalWorkspaceQueryWhereSort
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QWhere> {
  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhere> anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }
}

extension LocalWorkspaceQueryWhere
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QWhereClause> {
  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause>
  currentUserRoleEqualTo(String currentUserRole) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'currentUserRole',
          value: [currentUserRole],
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause>
  currentUserRoleNotEqualTo(String currentUserRole) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'currentUserRole',
                lower: [],
                upper: [currentUserRole],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'currentUserRole',
                lower: [currentUserRole],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'currentUserRole',
                lower: [currentUserRole],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'currentUserRole',
                lower: [],
                upper: [currentUserRole],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause>
  isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isSynced', value: [isSynced]),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterWhereClause>
  isSyncedNotEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [],
                upper: [isSynced],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [isSynced],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [isSynced],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [],
                upper: [isSynced],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LocalWorkspaceQueryFilter
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QFilterCondition> {
  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  boardCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardCount', value: value),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  boardCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'boardCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  boardCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'boardCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  boardCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'boardCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  createdAtBetween(
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  currentUserRoleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'currentUserRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  currentUserRoleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'currentUserRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'description',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'description',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition> idBetween(
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  memberCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'memberCount', value: value),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  memberCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'memberCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  memberCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'memberCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  memberCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'memberCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdLessThan(
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdBetween(
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerId', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  ownerIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerId', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  updatedAtBetween(
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

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'workspaceId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'workspaceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'workspaceId', value: ''),
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterFilterCondition>
  workspaceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'workspaceId', value: ''),
      );
    });
  }
}

extension LocalWorkspaceQueryObject
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QFilterCondition> {}

extension LocalWorkspaceQueryLinks
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QFilterCondition> {}

extension LocalWorkspaceQuerySortBy
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QSortBy> {
  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByBoardCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByCurrentUserRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByCurrentUserRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByMemberCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByMemberCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> sortByOwnerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByOwnerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  sortByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension LocalWorkspaceQuerySortThenBy
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QSortThenBy> {
  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByBoardCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByCurrentUserRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByCurrentUserRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentUserRole', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByMemberCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByMemberCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'memberCount', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByOwnerId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByOwnerIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerId', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QAfterSortBy>
  thenByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension LocalWorkspaceQueryWhereDistinct
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct> {
  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardCount');
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByCurrentUserRole({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'currentUserRole',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByMemberCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'memberCount');
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct> distinctByOwnerId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<LocalWorkspace, LocalWorkspace, QDistinct>
  distinctByWorkspaceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workspaceId', caseSensitive: caseSensitive);
    });
  }
}

extension LocalWorkspaceQueryProperty
    on QueryBuilder<LocalWorkspace, LocalWorkspace, QQueryProperty> {
  QueryBuilder<LocalWorkspace, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalWorkspace, int, QQueryOperations> boardCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardCount');
    });
  }

  QueryBuilder<LocalWorkspace, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<LocalWorkspace, String, QQueryOperations>
  currentUserRoleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentUserRole');
    });
  }

  QueryBuilder<LocalWorkspace, String, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<LocalWorkspace, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalWorkspace, int, QQueryOperations> memberCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'memberCount');
    });
  }

  QueryBuilder<LocalWorkspace, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<LocalWorkspace, String, QQueryOperations> ownerIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerId');
    });
  }

  QueryBuilder<LocalWorkspace, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<LocalWorkspace, String, QQueryOperations> workspaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workspaceId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalWorkspaceInviteCollection on Isar {
  IsarCollection<LocalWorkspaceInvite> get localWorkspaceInvites =>
      this.collection();
}

const LocalWorkspaceInviteSchema = CollectionSchema(
  name: r'LocalWorkspaceInvite',
  id: 2809880128108292120,
  properties: {
    r'acceptedAt': PropertySchema(
      id: 0,
      name: r'acceptedAt',
      type: IsarType.dateTime,
    ),
    r'fromUid': PropertySchema(id: 1, name: r'fromUid', type: IsarType.string),
    r'inviteId': PropertySchema(
      id: 2,
      name: r'inviteId',
      type: IsarType.string,
    ),
    r'isSynced': PropertySchema(id: 3, name: r'isSynced', type: IsarType.bool),
    r'rejectedAt': PropertySchema(
      id: 4,
      name: r'rejectedAt',
      type: IsarType.dateTime,
    ),
    r'status': PropertySchema(id: 5, name: r'status', type: IsarType.string),
    r'timestamp': PropertySchema(
      id: 6,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'toUid': PropertySchema(id: 7, name: r'toUid', type: IsarType.string),
    r'workspaceId': PropertySchema(
      id: 8,
      name: r'workspaceId',
      type: IsarType.string,
    ),
  },

  estimateSize: _localWorkspaceInviteEstimateSize,
  serialize: _localWorkspaceInviteSerialize,
  deserialize: _localWorkspaceInviteDeserialize,
  deserializeProp: _localWorkspaceInviteDeserializeProp,
  idName: r'id',
  indexes: {
    r'isSynced': IndexSchema(
      id: -39763503327887510,
      name: r'isSynced',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isSynced',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localWorkspaceInviteGetId,
  getLinks: _localWorkspaceInviteGetLinks,
  attach: _localWorkspaceInviteAttach,
  version: '3.3.2',
);

int _localWorkspaceInviteEstimateSize(
  LocalWorkspaceInvite object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.fromUid.length * 3;
  bytesCount += 3 + object.inviteId.length * 3;
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.toUid.length * 3;
  bytesCount += 3 + object.workspaceId.length * 3;
  return bytesCount;
}

void _localWorkspaceInviteSerialize(
  LocalWorkspaceInvite object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acceptedAt);
  writer.writeString(offsets[1], object.fromUid);
  writer.writeString(offsets[2], object.inviteId);
  writer.writeBool(offsets[3], object.isSynced);
  writer.writeDateTime(offsets[4], object.rejectedAt);
  writer.writeString(offsets[5], object.status);
  writer.writeDateTime(offsets[6], object.timestamp);
  writer.writeString(offsets[7], object.toUid);
  writer.writeString(offsets[8], object.workspaceId);
}

LocalWorkspaceInvite _localWorkspaceInviteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalWorkspaceInvite();
  object.acceptedAt = reader.readDateTimeOrNull(offsets[0]);
  object.fromUid = reader.readString(offsets[1]);
  object.id = id;
  object.inviteId = reader.readString(offsets[2]);
  object.isSynced = reader.readBool(offsets[3]);
  object.rejectedAt = reader.readDateTimeOrNull(offsets[4]);
  object.status = reader.readString(offsets[5]);
  object.timestamp = reader.readDateTime(offsets[6]);
  object.toUid = reader.readString(offsets[7]);
  object.workspaceId = reader.readString(offsets[8]);
  return object;
}

P _localWorkspaceInviteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localWorkspaceInviteGetId(LocalWorkspaceInvite object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localWorkspaceInviteGetLinks(
  LocalWorkspaceInvite object,
) {
  return [];
}

void _localWorkspaceInviteAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalWorkspaceInvite object,
) {
  object.id = id;
}

extension LocalWorkspaceInviteQueryWhereSort
    on QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QWhere> {
  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhere>
  anyIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isSynced'),
      );
    });
  }
}

extension LocalWorkspaceInviteQueryWhere
    on QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QWhereClause> {
  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
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

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
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

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
  isSyncedEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'isSynced', value: [isSynced]),
      );
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterWhereClause>
  isSyncedNotEqualTo(bool isSynced) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [],
                upper: [isSynced],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [isSynced],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [isSynced],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isSynced',
                lower: [],
                upper: [isSynced],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LocalWorkspaceInviteQueryFilter
    on
        QueryBuilder<
          LocalWorkspaceInvite,
          LocalWorkspaceInvite,
          QFilterCondition
        > {
  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  acceptedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'acceptedAt'),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  acceptedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'acceptedAt'),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  acceptedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'acceptedAt', value: value),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  acceptedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'acceptedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  acceptedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'acceptedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  acceptedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'acceptedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fromUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fromUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fromUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fromUid',
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'fromUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'fromUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'fromUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'fromUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fromUid', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  fromUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fromUid', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'inviteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'inviteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'inviteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'inviteId',
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'inviteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'inviteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'inviteId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'inviteId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inviteId', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  inviteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'inviteId', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  rejectedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rejectedAt'),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  rejectedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rejectedAt'),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  rejectedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rejectedAt', value: value),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  rejectedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rejectedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  rejectedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rejectedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  rejectedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rejectedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  timestampGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  timestampLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'timestamp',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'timestamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'toUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'toUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'toUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'toUid',
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'toUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'toUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'toUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'toUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'toUid', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  toUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'toUid', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'workspaceId',
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
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'workspaceId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'workspaceId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'workspaceId', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalWorkspaceInvite,
    LocalWorkspaceInvite,
    QAfterFilterCondition
  >
  workspaceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'workspaceId', value: ''),
      );
    });
  }
}

extension LocalWorkspaceInviteQueryObject
    on
        QueryBuilder<
          LocalWorkspaceInvite,
          LocalWorkspaceInvite,
          QFilterCondition
        > {}

extension LocalWorkspaceInviteQueryLinks
    on
        QueryBuilder<
          LocalWorkspaceInvite,
          LocalWorkspaceInvite,
          QFilterCondition
        > {}

extension LocalWorkspaceInviteQuerySortBy
    on QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QSortBy> {
  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByFromUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByFromUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByInviteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByInviteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByRejectedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByRejectedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByToUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByToUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  sortByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension LocalWorkspaceInviteQuerySortThenBy
    on QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QSortThenBy> {
  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByFromUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByFromUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByInviteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByInviteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByRejectedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByRejectedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByToUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByToUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.desc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByWorkspaceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.asc);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QAfterSortBy>
  thenByWorkspaceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'workspaceId', Sort.desc);
    });
  }
}

extension LocalWorkspaceInviteQueryWhereDistinct
    on QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct> {
  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedAt');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByFromUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByInviteId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inviteId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByRejectedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rejectedAt');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByToUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalWorkspaceInvite, LocalWorkspaceInvite, QDistinct>
  distinctByWorkspaceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'workspaceId', caseSensitive: caseSensitive);
    });
  }
}

extension LocalWorkspaceInviteQueryProperty
    on
        QueryBuilder<
          LocalWorkspaceInvite,
          LocalWorkspaceInvite,
          QQueryProperty
        > {
  QueryBuilder<LocalWorkspaceInvite, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, DateTime?, QQueryOperations>
  acceptedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedAt');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, String, QQueryOperations>
  fromUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromUid');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, String, QQueryOperations>
  inviteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inviteId');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, bool, QQueryOperations>
  isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, DateTime?, QQueryOperations>
  rejectedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rejectedAt');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, String, QQueryOperations>
  statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, DateTime, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, String, QQueryOperations> toUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toUid');
    });
  }

  QueryBuilder<LocalWorkspaceInvite, String, QQueryOperations>
  workspaceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'workspaceId');
    });
  }
}
