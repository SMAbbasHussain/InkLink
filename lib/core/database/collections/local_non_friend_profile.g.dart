// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_non_friend_profile.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalNonFriendProfileCollection on Isar {
  IsarCollection<LocalNonFriendProfile> get localNonFriendProfiles =>
      this.collection();
}

const LocalNonFriendProfileSchema = CollectionSchema(
  name: r'LocalNonFriendProfile',
  id: -5721904467693556260,
  properties: {
    r'bio': PropertySchema(id: 0, name: r'bio', type: IsarType.string),
    r'boardCount': PropertySchema(
      id: 1,
      name: r'boardCount',
      type: IsarType.long,
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
    r'email': PropertySchema(id: 4, name: r'email', type: IsarType.string),
    r'friendCount': PropertySchema(
      id: 5,
      name: r'friendCount',
      type: IsarType.long,
    ),
    r'lastSeenAt': PropertySchema(
      id: 6,
      name: r'lastSeenAt',
      type: IsarType.dateTime,
    ),
    r'lastSource': PropertySchema(
      id: 7,
      name: r'lastSource',
      type: IsarType.string,
    ),
    r'photoURL': PropertySchema(
      id: 8,
      name: r'photoURL',
      type: IsarType.string,
    ),
    r'uid': PropertySchema(id: 9, name: r'uid', type: IsarType.string),
  },

  estimateSize: _localNonFriendProfileEstimateSize,
  serialize: _localNonFriendProfileSerialize,
  deserialize: _localNonFriendProfileDeserialize,
  deserializeProp: _localNonFriendProfileDeserializeProp,
  idName: r'id',
  indexes: {
    r'uid': IndexSchema(
      id: 8193695471701937315,
      name: r'uid',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'uid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localNonFriendProfileGetId,
  getLinks: _localNonFriendProfileGetLinks,
  attach: _localNonFriendProfileAttach,
  version: '3.3.2',
);

int _localNonFriendProfileEstimateSize(
  LocalNonFriendProfile object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.bio;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.displayName.length * 3;
  {
    final value = object.email;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
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
  bytesCount += 3 + object.uid.length * 3;
  return bytesCount;
}

void _localNonFriendProfileSerialize(
  LocalNonFriendProfile object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.bio);
  writer.writeLong(offsets[1], object.boardCount);
  writer.writeDateTime(offsets[2], object.cachedAt);
  writer.writeString(offsets[3], object.displayName);
  writer.writeString(offsets[4], object.email);
  writer.writeLong(offsets[5], object.friendCount);
  writer.writeDateTime(offsets[6], object.lastSeenAt);
  writer.writeString(offsets[7], object.lastSource);
  writer.writeString(offsets[8], object.photoURL);
  writer.writeString(offsets[9], object.uid);
}

LocalNonFriendProfile _localNonFriendProfileDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalNonFriendProfile(
    bio: reader.readStringOrNull(offsets[0]),
    boardCount: reader.readLongOrNull(offsets[1]) ?? 0,
    displayName: reader.readString(offsets[3]),
    email: reader.readStringOrNull(offsets[4]),
    friendCount: reader.readLongOrNull(offsets[5]) ?? 0,
    id: id,
    lastSeenAt: reader.readDateTimeOrNull(offsets[6]),
    lastSource: reader.readStringOrNull(offsets[7]),
    photoURL: reader.readStringOrNull(offsets[8]),
    uid: reader.readString(offsets[9]),
  );
  object.cachedAt = reader.readDateTime(offsets[2]);
  return object;
}

P _localNonFriendProfileDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localNonFriendProfileGetId(LocalNonFriendProfile object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _localNonFriendProfileGetLinks(
  LocalNonFriendProfile object,
) {
  return [];
}

void _localNonFriendProfileAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalNonFriendProfile object,
) {
  object.id = id;
}

extension LocalNonFriendProfileByIndex
    on IsarCollection<LocalNonFriendProfile> {
  Future<LocalNonFriendProfile?> getByUid(String uid) {
    return getByIndex(r'uid', [uid]);
  }

  LocalNonFriendProfile? getByUidSync(String uid) {
    return getByIndexSync(r'uid', [uid]);
  }

  Future<bool> deleteByUid(String uid) {
    return deleteByIndex(r'uid', [uid]);
  }

  bool deleteByUidSync(String uid) {
    return deleteByIndexSync(r'uid', [uid]);
  }

  Future<List<LocalNonFriendProfile?>> getAllByUid(List<String> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uid', values);
  }

  List<LocalNonFriendProfile?> getAllByUidSync(List<String> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'uid', values);
  }

  Future<int> deleteAllByUid(List<String> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'uid', values);
  }

  int deleteAllByUidSync(List<String> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'uid', values);
  }

  Future<Id> putByUid(LocalNonFriendProfile object) {
    return putByIndex(r'uid', object);
  }

  Id putByUidSync(LocalNonFriendProfile object, {bool saveLinks = true}) {
    return putByIndexSync(r'uid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUid(List<LocalNonFriendProfile> objects) {
    return putAllByIndex(r'uid', objects);
  }

  List<Id> putAllByUidSync(
    List<LocalNonFriendProfile> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'uid', objects, saveLinks: saveLinks);
  }
}

extension LocalNonFriendProfileQueryWhereSort
    on QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QWhere> {
  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalNonFriendProfileQueryWhere
    on
        QueryBuilder<
          LocalNonFriendProfile,
          LocalNonFriendProfile,
          QWhereClause
        > {
  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
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

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
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

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
  uidEqualTo(String uid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [uid]),
      );
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterWhereClause>
  uidNotEqualTo(String uid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [],
                upper: [uid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [uid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [uid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'uid',
                lower: [],
                upper: [uid],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension LocalNonFriendProfileQueryFilter
    on
        QueryBuilder<
          LocalNonFriendProfile,
          LocalNonFriendProfile,
          QFilterCondition
        > {
  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bio'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bio'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'bio',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bio',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bio',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bio',
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
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'bio',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'bio',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'bio',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'bio',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bio', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  bioIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'bio', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  boardCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardCount', value: value),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'email'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'email'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'email',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'email',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'email',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'email',
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
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'email',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'email',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'email',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'email',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'email', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  emailIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'email', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  friendCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'friendCount', value: value),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  friendCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'friendCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  friendCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'friendCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  friendCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'friendCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSeenAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSeenAt'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSeenAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSeenAt'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSeenAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSeenAt', value: value),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSeenAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSeenAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSeenAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSeenAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSeenAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSeenAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSource'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSource'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSource', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  lastSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastSource', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  photoURLIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'photoURL'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  photoURLIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'photoURL'),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  photoURLIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'photoURL', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  photoURLIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'photoURL', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'uid',
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
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'uid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'uid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<
    LocalNonFriendProfile,
    LocalNonFriendProfile,
    QAfterFilterCondition
  >
  uidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'uid', value: ''),
      );
    });
  }
}

extension LocalNonFriendProfileQueryObject
    on
        QueryBuilder<
          LocalNonFriendProfile,
          LocalNonFriendProfile,
          QFilterCondition
        > {}

extension LocalNonFriendProfileQueryLinks
    on
        QueryBuilder<
          LocalNonFriendProfile,
          LocalNonFriendProfile,
          QFilterCondition
        > {}

extension LocalNonFriendProfileQuerySortBy
    on QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QSortBy> {
  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByBio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByBioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByBoardCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByEmail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByEmailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByFriendCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByFriendCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByLastSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByLastSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByPhotoURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByPhotoURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  sortByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }
}

extension LocalNonFriendProfileQuerySortThenBy
    on QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QSortThenBy> {
  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByBio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByBioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByBoardCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByEmail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByEmailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByFriendCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByFriendCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByLastSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByLastSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByPhotoURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByPhotoURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.desc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QAfterSortBy>
  thenByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }
}

extension LocalNonFriendProfileQueryWhereDistinct
    on QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct> {
  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByBio({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bio', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardCount');
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByEmail({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'email', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByFriendCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'friendCount');
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeenAt');
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByLastSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSource', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByPhotoURL({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoURL', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalNonFriendProfile, LocalNonFriendProfile, QDistinct>
  distinctByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uid', caseSensitive: caseSensitive);
    });
  }
}

extension LocalNonFriendProfileQueryProperty
    on
        QueryBuilder<
          LocalNonFriendProfile,
          LocalNonFriendProfile,
          QQueryProperty
        > {
  QueryBuilder<LocalNonFriendProfile, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalNonFriendProfile, String?, QQueryOperations> bioProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bio');
    });
  }

  QueryBuilder<LocalNonFriendProfile, int, QQueryOperations>
  boardCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardCount');
    });
  }

  QueryBuilder<LocalNonFriendProfile, DateTime, QQueryOperations>
  cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<LocalNonFriendProfile, String, QQueryOperations>
  displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<LocalNonFriendProfile, String?, QQueryOperations>
  emailProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'email');
    });
  }

  QueryBuilder<LocalNonFriendProfile, int, QQueryOperations>
  friendCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'friendCount');
    });
  }

  QueryBuilder<LocalNonFriendProfile, DateTime?, QQueryOperations>
  lastSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeenAt');
    });
  }

  QueryBuilder<LocalNonFriendProfile, String?, QQueryOperations>
  lastSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSource');
    });
  }

  QueryBuilder<LocalNonFriendProfile, String?, QQueryOperations>
  photoURLProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoURL');
    });
  }

  QueryBuilder<LocalNonFriendProfile, String, QQueryOperations> uidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uid');
    });
  }
}
