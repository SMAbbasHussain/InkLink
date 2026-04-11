// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_friend_request.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalFriendRequestCollection on Isar {
  IsarCollection<LocalFriendRequest> get localFriendRequests =>
      this.collection();
}

const LocalFriendRequestSchema = CollectionSchema(
  name: r'LocalFriendRequest',
  id: -3123842728174886972,
  properties: {
    r'cachedAt': PropertySchema(
      id: 0,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'fromUid': PropertySchema(id: 1, name: r'fromUid', type: IsarType.string),
    r'requestId': PropertySchema(
      id: 2,
      name: r'requestId',
      type: IsarType.string,
    ),
    r'senderName': PropertySchema(
      id: 3,
      name: r'senderName',
      type: IsarType.string,
    ),
    r'senderPic': PropertySchema(
      id: 4,
      name: r'senderPic',
      type: IsarType.string,
    ),
    r'status': PropertySchema(id: 5, name: r'status', type: IsarType.string),
    r'timestamp': PropertySchema(
      id: 6,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'toUid': PropertySchema(id: 7, name: r'toUid', type: IsarType.string),
  },

  estimateSize: _localFriendRequestEstimateSize,
  serialize: _localFriendRequestSerialize,
  deserialize: _localFriendRequestDeserialize,
  deserializeProp: _localFriendRequestDeserializeProp,
  idName: r'id',
  indexes: {
    r'requestId': IndexSchema(
      id: 938047444593699237,
      name: r'requestId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'requestId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'fromUid': IndexSchema(
      id: 9035842574508759036,
      name: r'fromUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'fromUid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'toUid': IndexSchema(
      id: 5303491101219305271,
      name: r'toUid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'toUid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localFriendRequestGetId,
  getLinks: _localFriendRequestGetLinks,
  attach: _localFriendRequestAttach,
  version: '3.3.2',
);

int _localFriendRequestEstimateSize(
  LocalFriendRequest object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.fromUid.length * 3;
  bytesCount += 3 + object.requestId.length * 3;
  bytesCount += 3 + object.senderName.length * 3;
  {
    final value = object.senderPic;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.toUid.length * 3;
  return bytesCount;
}

void _localFriendRequestSerialize(
  LocalFriendRequest object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.cachedAt);
  writer.writeString(offsets[1], object.fromUid);
  writer.writeString(offsets[2], object.requestId);
  writer.writeString(offsets[3], object.senderName);
  writer.writeString(offsets[4], object.senderPic);
  writer.writeString(offsets[5], object.status);
  writer.writeDateTime(offsets[6], object.timestamp);
  writer.writeString(offsets[7], object.toUid);
}

LocalFriendRequest _localFriendRequestDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalFriendRequest();
  object.cachedAt = reader.readDateTime(offsets[0]);
  object.fromUid = reader.readString(offsets[1]);
  object.id = id;
  object.requestId = reader.readString(offsets[2]);
  object.senderName = reader.readString(offsets[3]);
  object.senderPic = reader.readStringOrNull(offsets[4]);
  object.status = reader.readString(offsets[5]);
  object.timestamp = reader.readDateTime(offsets[6]);
  object.toUid = reader.readString(offsets[7]);
  return object;
}

P _localFriendRequestDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localFriendRequestGetId(LocalFriendRequest object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localFriendRequestGetLinks(
  LocalFriendRequest object,
) {
  return [];
}

void _localFriendRequestAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalFriendRequest object,
) {
  object.id = id;
}

extension LocalFriendRequestByIndex on IsarCollection<LocalFriendRequest> {
  Future<LocalFriendRequest?> getByRequestId(String requestId) {
    return getByIndex(r'requestId', [requestId]);
  }

  LocalFriendRequest? getByRequestIdSync(String requestId) {
    return getByIndexSync(r'requestId', [requestId]);
  }

  Future<bool> deleteByRequestId(String requestId) {
    return deleteByIndex(r'requestId', [requestId]);
  }

  bool deleteByRequestIdSync(String requestId) {
    return deleteByIndexSync(r'requestId', [requestId]);
  }

  Future<List<LocalFriendRequest?>> getAllByRequestId(
    List<String> requestIdValues,
  ) {
    final values = requestIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'requestId', values);
  }

  List<LocalFriendRequest?> getAllByRequestIdSync(
    List<String> requestIdValues,
  ) {
    final values = requestIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'requestId', values);
  }

  Future<int> deleteAllByRequestId(List<String> requestIdValues) {
    final values = requestIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'requestId', values);
  }

  int deleteAllByRequestIdSync(List<String> requestIdValues) {
    final values = requestIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'requestId', values);
  }

  Future<Id> putByRequestId(LocalFriendRequest object) {
    return putByIndex(r'requestId', object);
  }

  Id putByRequestIdSync(LocalFriendRequest object, {bool saveLinks = true}) {
    return putByIndexSync(r'requestId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByRequestId(List<LocalFriendRequest> objects) {
    return putAllByIndex(r'requestId', objects);
  }

  List<Id> putAllByRequestIdSync(
    List<LocalFriendRequest> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'requestId', objects, saveLinks: saveLinks);
  }
}

extension LocalFriendRequestQueryWhereSort
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QWhere> {
  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhere>
  anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension LocalFriendRequestQueryWhere
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QWhereClause> {
  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  requestIdEqualTo(String requestId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'requestId', value: [requestId]),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  requestIdNotEqualTo(String requestId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestId',
                lower: [],
                upper: [requestId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestId',
                lower: [requestId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestId',
                lower: [requestId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'requestId',
                lower: [],
                upper: [requestId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  fromUidEqualTo(String fromUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'fromUid', value: [fromUid]),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  fromUidNotEqualTo(String fromUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromUid',
                lower: [],
                upper: [fromUid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromUid',
                lower: [fromUid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromUid',
                lower: [fromUid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'fromUid',
                lower: [],
                upper: [fromUid],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  toUidEqualTo(String toUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'toUid', value: [toUid]),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  toUidNotEqualTo(String toUid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toUid',
                lower: [],
                upper: [toUid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toUid',
                lower: [toUid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toUid',
                lower: [toUid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'toUid',
                lower: [],
                upper: [toUid],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  statusEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'status', value: [status]),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  statusNotEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  timestampEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'timestamp', value: [timestamp]),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  timestampNotEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [timestamp],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'timestamp',
                lower: [],
                upper: [timestamp],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  timestampGreaterThan(DateTime timestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [timestamp],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  timestampLessThan(DateTime timestamp, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [],
          upper: [timestamp],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterWhereClause>
  timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'timestamp',
          lower: [lowerTimestamp],
          includeLower: includeLower,
          upper: [upperTimestamp],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension LocalFriendRequestQueryFilter
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QFilterCondition> {
  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  fromUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fromUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  fromUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fromUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'requestId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'requestId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'requestId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'requestId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'requestId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'requestId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'requestId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'requestId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'requestId', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  requestIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'requestId', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'senderName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'senderName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'senderName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'senderName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'senderName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'senderName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'senderName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'senderName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'senderName', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'senderName', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'senderPic'),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'senderPic'),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'senderPic',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'senderPic',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'senderPic',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'senderPic',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'senderPic',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'senderPic',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'senderPic',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'senderPic',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'senderPic', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  senderPicIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'senderPic', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
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

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  toUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'toUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterFilterCondition>
  toUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'toUid', value: ''),
      );
    });
  }
}

extension LocalFriendRequestQueryObject
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QFilterCondition> {}

extension LocalFriendRequestQueryLinks
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QFilterCondition> {}

extension LocalFriendRequestQuerySortBy
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QSortBy> {
  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByFromUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByFromUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByRequestId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestId', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByRequestIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestId', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortBySenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortBySenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortBySenderPic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortBySenderPicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByToUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  sortByToUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.desc);
    });
  }
}

extension LocalFriendRequestQuerySortThenBy
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QSortThenBy> {
  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByFromUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByFromUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByRequestId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestId', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByRequestIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestId', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenBySenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenBySenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenBySenderPic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenBySenderPicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByToUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.asc);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QAfterSortBy>
  thenByToUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.desc);
    });
  }
}

extension LocalFriendRequestQueryWhereDistinct
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct> {
  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctByFromUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctByRequestId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requestId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctBySenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctBySenderPic({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderPic', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<LocalFriendRequest, LocalFriendRequest, QDistinct>
  distinctByToUid({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toUid', caseSensitive: caseSensitive);
    });
  }
}

extension LocalFriendRequestQueryProperty
    on QueryBuilder<LocalFriendRequest, LocalFriendRequest, QQueryProperty> {
  QueryBuilder<LocalFriendRequest, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalFriendRequest, DateTime, QQueryOperations>
  cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<LocalFriendRequest, String, QQueryOperations> fromUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromUid');
    });
  }

  QueryBuilder<LocalFriendRequest, String, QQueryOperations>
  requestIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requestId');
    });
  }

  QueryBuilder<LocalFriendRequest, String, QQueryOperations>
  senderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderName');
    });
  }

  QueryBuilder<LocalFriendRequest, String?, QQueryOperations>
  senderPicProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderPic');
    });
  }

  QueryBuilder<LocalFriendRequest, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<LocalFriendRequest, DateTime, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<LocalFriendRequest, String, QQueryOperations> toUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toUid');
    });
  }
}
