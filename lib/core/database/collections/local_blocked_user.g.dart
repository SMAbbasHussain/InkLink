// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_blocked_user.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalBlockedUserCollection on Isar {
  IsarCollection<LocalBlockedUser> get localBlockedUsers => this.collection();
}

const LocalBlockedUserSchema = CollectionSchema(
  name: r'LocalBlockedUser',
  id: -4643686899858778311,
  properties: {
    r'blockedUid': PropertySchema(
      id: 0,
      name: r'blockedUid',
      type: IsarType.string,
    ),
    r'blockerUid': PropertySchema(
      id: 1,
      name: r'blockerUid',
      type: IsarType.string,
    ),
    r'cachedAt': PropertySchema(
      id: 2,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'displayName': PropertySchema(
      id: 3,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'lastSource': PropertySchema(
      id: 4,
      name: r'lastSource',
      type: IsarType.string,
    ),
    r'photoURL': PropertySchema(
      id: 5,
      name: r'photoURL',
      type: IsarType.string,
    ),
  },

  estimateSize: _localBlockedUserEstimateSize,
  serialize: _localBlockedUserSerialize,
  deserialize: _localBlockedUserDeserialize,
  deserializeProp: _localBlockedUserDeserializeProp,
  idName: r'id',
  indexes: {
    r'blockedUid': IndexSchema(
      id: -1874856640962865745,
      name: r'blockedUid',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'blockedUid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localBlockedUserGetId,
  getLinks: _localBlockedUserGetLinks,
  attach: _localBlockedUserAttach,
  version: '3.3.2',
);

int _localBlockedUserEstimateSize(
  LocalBlockedUser object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.blockedUid.length * 3;
  bytesCount += 3 + object.blockerUid.length * 3;
  bytesCount += 3 + object.displayName.length * 3;
  {
    final value = object.lastSource;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.photoURL;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _localBlockedUserSerialize(
  LocalBlockedUser object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.blockedUid);
  writer.writeString(offsets[1], object.blockerUid);
  writer.writeDateTime(offsets[2], object.cachedAt);
  writer.writeString(offsets[3], object.displayName);
  writer.writeString(offsets[4], object.lastSource);
  writer.writeString(offsets[5], object.photoURL);
}

LocalBlockedUser _localBlockedUserDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalBlockedUser(
    blockedUid: reader.readString(offsets[0]),
    blockerUid: reader.readString(offsets[1]),
    displayName: reader.readString(offsets[3]),
    id: id,
    lastSource: reader.readStringOrNull(offsets[4]),
    photoURL: reader.readStringOrNull(offsets[5]),
  );
  object.cachedAt = reader.readDateTime(offsets[2]);
  return object;
}

P _localBlockedUserDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localBlockedUserGetId(LocalBlockedUser object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _localBlockedUserGetLinks(LocalBlockedUser object) {
  return [];
}

void _localBlockedUserAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalBlockedUser object,
) {
  object.id = id;
}

extension LocalBlockedUserByIndex on IsarCollection<LocalBlockedUser> {
  Future<LocalBlockedUser?> getByBlockedUid(String blockedUid) {
    return getByIndex(r'blockedUid', [blockedUid]);
  }

  LocalBlockedUser? getByBlockedUidSync(String blockedUid) {
    return getByIndexSync(r'blockedUid', [blockedUid]);
  }

  Future<bool> deleteByBlockedUid(String blockedUid) {
    return deleteByIndex(r'blockedUid', [blockedUid]);
  }

  bool deleteByBlockedUidSync(String blockedUid) {
    return deleteByIndexSync(r'blockedUid', [blockedUid]);
  }

  Future<List<LocalBlockedUser?>> getAllByBlockedUid(
    List<String> blockedUidValues,
  ) {
    final values = blockedUidValues.map((e) => [e]).toList();
    return getAllByIndex(r'blockedUid', values);
  }

  List<LocalBlockedUser?> getAllByBlockedUidSync(
    List<String> blockedUidValues,
  ) {
    final values = blockedUidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'blockedUid', values);
  }

  Future<int> deleteAllByBlockedUid(List<String> blockedUidValues) {
    final values = blockedUidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'blockedUid', values);
  }

  int deleteAllByBlockedUidSync(List<String> blockedUidValues) {
    final values = blockedUidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'blockedUid', values);
  }

  Future<Id> putByBlockedUid(LocalBlockedUser object) {
    return putByIndex(r'blockedUid', object);
  }

  Id putByBlockedUidSync(LocalBlockedUser object, {bool saveLinks = true}) {
    return putByIndexSync(r'blockedUid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByBlockedUid(List<LocalBlockedUser> objects) {
    return putAllByIndex(r'blockedUid', objects);
  }

  List<Id> putAllByBlockedUidSync(
    List<LocalBlockedUser> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'blockedUid', objects, saveLinks: saveLinks);
  }
}

extension LocalBlockedUserQueryWhereSort
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QWhere> {
  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalBlockedUserQueryWhere
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QWhereClause> {
  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause>
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

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause>
  blockedUidEqualTo(String blockedUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'blockedUid', value: [blockedUid]),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterWhereClause>
  blockedUidNotEqualTo(String blockedUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockedUid',
                lower: [],
                upper: [blockedUid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockedUid',
                lower: [blockedUid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockedUid',
                lower: [blockedUid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'blockedUid',
                lower: [],
                upper: [blockedUid],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LocalBlockedUserQueryFilter
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QFilterCondition> {
  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'blockedUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'blockedUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'blockedUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'blockedUid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'blockedUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'blockedUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'blockedUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'blockedUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'blockedUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockedUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'blockedUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'blockerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'blockerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'blockerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'blockerUid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'blockerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'blockerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'blockerUid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'blockerUid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'blockerUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  blockerUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'blockerUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  cachedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  cachedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cachedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  cachedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cachedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'displayName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'displayName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  idGreaterThan(Id? value, {bool include = false}) {
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

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  idLessThan(Id? value, {bool include = false}) {
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

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  idBetween(
    Id? lower,
    Id? upper, {
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

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSource'),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSource'),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSource',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastSource',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSource', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  lastSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastSource', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'photoURL'),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'photoURL'),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'photoURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'photoURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'photoURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'photoURL',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'photoURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'photoURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'photoURL',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'photoURL',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'photoURL', value: ''),
      );
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterFilterCondition>
  photoURLIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'photoURL', value: ''),
      );
    });
  }
}

extension LocalBlockedUserQueryObject
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QFilterCondition> {}

extension LocalBlockedUserQueryLinks
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QFilterCondition> {}

extension LocalBlockedUserQuerySortBy
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QSortBy> {
  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByBlockedUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockedUid', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByBlockedUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockedUid', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByBlockerUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerUid', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByBlockerUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerUid', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByLastSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByLastSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByPhotoURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  sortByPhotoURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.desc);
    });
  }
}

extension LocalBlockedUserQuerySortThenBy
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QSortThenBy> {
  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByBlockedUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockedUid', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByBlockedUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockedUid', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByBlockerUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerUid', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByBlockerUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'blockerUid', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByLastSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByLastSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.desc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByPhotoURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.asc);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QAfterSortBy>
  thenByPhotoURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.desc);
    });
  }
}

extension LocalBlockedUserQueryWhereDistinct
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct> {
  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct>
  distinctByBlockedUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'blockedUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct>
  distinctByBlockerUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'blockerUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct>
  distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct>
  distinctByDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct>
  distinctByLastSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSource', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalBlockedUser, LocalBlockedUser, QDistinct>
  distinctByPhotoURL({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoURL', caseSensitive: caseSensitive);
    });
  }
}

extension LocalBlockedUserQueryProperty
    on QueryBuilder<LocalBlockedUser, LocalBlockedUser, QQueryProperty> {
  QueryBuilder<LocalBlockedUser, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalBlockedUser, String, QQueryOperations>
  blockedUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'blockedUid');
    });
  }

  QueryBuilder<LocalBlockedUser, String, QQueryOperations>
  blockerUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'blockerUid');
    });
  }

  QueryBuilder<LocalBlockedUser, DateTime, QQueryOperations>
  cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<LocalBlockedUser, String, QQueryOperations>
  displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<LocalBlockedUser, String?, QQueryOperations>
  lastSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSource');
    });
  }

  QueryBuilder<LocalBlockedUser, String?, QQueryOperations> photoURLProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoURL');
    });
  }
}
