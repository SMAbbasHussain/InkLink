// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_friend_profile.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalFriendProfileCollection on Isar {
  IsarCollection<LocalFriendProfile> get localFriendProfiles =>
      this.collection();
}

const LocalFriendProfileSchema = CollectionSchema(
  name: r'LocalFriendProfile',
  id: -8315537306731977030,
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

  estimateSize: _localFriendProfileEstimateSize,
  serialize: _localFriendProfileSerialize,
  deserialize: _localFriendProfileDeserialize,
  deserializeProp: _localFriendProfileDeserializeProp,
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

  getId: _localFriendProfileGetId,
  getLinks: _localFriendProfileGetLinks,
  attach: _localFriendProfileAttach,
  version: '3.3.2',
);

int _localFriendProfileEstimateSize(
  LocalFriendProfile object,
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

void _localFriendProfileSerialize(
  LocalFriendProfile object,
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

LocalFriendProfile _localFriendProfileDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalFriendProfile(
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

P _localFriendProfileDeserializeProp<P>(
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

Id _localFriendProfileGetId(LocalFriendProfile object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _localFriendProfileGetLinks(
  LocalFriendProfile object,
) {
  return [];
}

void _localFriendProfileAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalFriendProfile object,
) {
  object.id = id;
}

extension LocalFriendProfileByIndex on IsarCollection<LocalFriendProfile> {
  Future<LocalFriendProfile?> getByUid(String uid) {
    return getByIndex(r'uid', [uid]);
  }

  LocalFriendProfile? getByUidSync(String uid) {
    return getByIndexSync(r'uid', [uid]);
  }

  Future<bool> deleteByUid(String uid) {
    return deleteByIndex(r'uid', [uid]);
  }

  bool deleteByUidSync(String uid) {
    return deleteByIndexSync(r'uid', [uid]);
  }

  Future<List<LocalFriendProfile?>> getAllByUid(List<String> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndex(r'uid', values);
  }

  List<LocalFriendProfile?> getAllByUidSync(List<String> uidValues) {
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

  Future<Id> putByUid(LocalFriendProfile object) {
    return putByIndex(r'uid', object);
  }

  Id putByUidSync(LocalFriendProfile object, {bool saveLinks = true}) {
    return putByIndexSync(r'uid', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUid(List<LocalFriendProfile> objects) {
    return putAllByIndex(r'uid', objects);
  }

  List<Id> putAllByUidSync(
    List<LocalFriendProfile> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'uid', objects, saveLinks: saveLinks);
  }
}

extension LocalFriendProfileQueryWhereSort
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QWhere> {
  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalFriendProfileQueryWhere
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QWhereClause> {
  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
  uidEqualTo(String uid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'uid', value: [uid]),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterWhereClause>
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

extension LocalFriendProfileQueryFilter
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QFilterCondition> {
  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  bioIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bio'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  bioIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bio'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  bioIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bio', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  bioIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'bio', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  boardCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardCount', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  emailIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'email'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  emailIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'email'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  emailIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'email', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  emailIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'email', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  friendCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'friendCount', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  idEqualTo(Id? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSeenAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSeenAt'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSeenAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSeenAt'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSeenAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSeenAt', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSource'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSource'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSource', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  lastSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastSource', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  photoURLIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'photoURL'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  photoURLIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'photoURL'),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  photoURLIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'photoURL', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  photoURLIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'photoURL', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  uidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'uid', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterFilterCondition>
  uidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'uid', value: ''),
      );
    });
  }
}

extension LocalFriendProfileQueryObject
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QFilterCondition> {}

extension LocalFriendProfileQueryLinks
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QFilterCondition> {}

extension LocalFriendProfileQuerySortBy
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QSortBy> {
  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByBio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByBioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByBoardCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByEmail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByEmailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByFriendCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByFriendCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByLastSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByLastSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByPhotoURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByPhotoURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  sortByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }
}

extension LocalFriendProfileQuerySortThenBy
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QSortThenBy> {
  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByBio() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByBioDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bio', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByBoardCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardCount', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByEmail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByEmailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'email', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByFriendCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByFriendCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'friendCount', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByLastSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByLastSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSource', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByPhotoURL() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByPhotoURLDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoURL', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QAfterSortBy>
  thenByUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uid', Sort.desc);
    });
  }
}

extension LocalFriendProfileQueryWhereDistinct
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct> {
  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByBio({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bio', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByBoardCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardCount');
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByEmail({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'email', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByFriendCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'friendCount');
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeenAt');
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByLastSource({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSource', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByPhotoURL({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoURL', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendProfile, LocalFriendProfile, QDistinct>
  distinctByUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uid', caseSensitive: caseSensitive);
    });
  }
}

extension LocalFriendProfileQueryProperty
    on QueryBuilder<LocalFriendProfile, LocalFriendProfile, QQueryProperty> {
  QueryBuilder<LocalFriendProfile, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalFriendProfile, String?, QQueryOperations> bioProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bio');
    });
  }

  QueryBuilder<LocalFriendProfile, int, QQueryOperations> boardCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardCount');
    });
  }

  QueryBuilder<LocalFriendProfile, DateTime, QQueryOperations>
  cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<LocalFriendProfile, String, QQueryOperations>
  displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<LocalFriendProfile, String?, QQueryOperations> emailProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'email');
    });
  }

  QueryBuilder<LocalFriendProfile, int, QQueryOperations>
  friendCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'friendCount');
    });
  }

  QueryBuilder<LocalFriendProfile, DateTime?, QQueryOperations>
  lastSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeenAt');
    });
  }

  QueryBuilder<LocalFriendProfile, String?, QQueryOperations>
  lastSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSource');
    });
  }

  QueryBuilder<LocalFriendProfile, String?, QQueryOperations>
  photoURLProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoURL');
    });
  }

  QueryBuilder<LocalFriendProfile, String, QQueryOperations> uidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uid');
    });
  }
}
