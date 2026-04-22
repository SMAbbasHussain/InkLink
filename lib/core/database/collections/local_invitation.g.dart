// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_invitation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalInvitationCollection on Isar {
  IsarCollection<LocalInvitation> get localInvitations => this.collection();
}

const LocalInvitationSchema = CollectionSchema(
  name: r'LocalInvitation',
  id: 7748707148538851085,
  properties: {
    r'acceptedAt': PropertySchema(
      id: 0,
      name: r'acceptedAt',
      type: IsarType.dateTime,
    ),
    r'boardId': PropertySchema(id: 1, name: r'boardId', type: IsarType.string),
    r'boardTitle': PropertySchema(
      id: 2,
      name: r'boardTitle',
      type: IsarType.string,
    ),
    r'cachedAt': PropertySchema(
      id: 3,
      name: r'cachedAt',
      type: IsarType.dateTime,
    ),
    r'expiresAt': PropertySchema(
      id: 4,
      name: r'expiresAt',
      type: IsarType.dateTime,
    ),
    r'fromUid': PropertySchema(id: 5, name: r'fromUid', type: IsarType.string),
    r'inviteExpiryHours': PropertySchema(
      id: 6,
      name: r'inviteExpiryHours',
      type: IsarType.long,
    ),
    r'inviteId': PropertySchema(
      id: 7,
      name: r'inviteId',
      type: IsarType.string,
    ),
    r'inviterRoleSnapshot': PropertySchema(
      id: 8,
      name: r'inviterRoleSnapshot',
      type: IsarType.string,
    ),
    r'rejectedAt': PropertySchema(
      id: 9,
      name: r'rejectedAt',
      type: IsarType.dateTime,
    ),
    r'resolvedAt': PropertySchema(
      id: 10,
      name: r'resolvedAt',
      type: IsarType.dateTime,
    ),
    r'senderName': PropertySchema(
      id: 11,
      name: r'senderName',
      type: IsarType.string,
    ),
    r'senderPic': PropertySchema(
      id: 12,
      name: r'senderPic',
      type: IsarType.string,
    ),
    r'status': PropertySchema(id: 13, name: r'status', type: IsarType.string),
    r'targetRole': PropertySchema(
      id: 14,
      name: r'targetRole',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 15,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'toUid': PropertySchema(id: 16, name: r'toUid', type: IsarType.string),
  },

  estimateSize: _localInvitationEstimateSize,
  serialize: _localInvitationSerialize,
  deserialize: _localInvitationDeserialize,
  deserializeProp: _localInvitationDeserializeProp,
  idName: r'id',
  indexes: {
    r'inviteId': IndexSchema(
      id: -7055495878054980758,
      name: r'inviteId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'inviteId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
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

  getId: _localInvitationGetId,
  getLinks: _localInvitationGetLinks,
  attach: _localInvitationAttach,
  version: '3.3.2',
);

int _localInvitationEstimateSize(
  LocalInvitation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.boardId.length * 3;
  bytesCount += 3 + object.boardTitle.length * 3;
  bytesCount += 3 + object.fromUid.length * 3;
  bytesCount += 3 + object.inviteId.length * 3;
  {
    final value = object.inviterRoleSnapshot;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.senderName.length * 3;
  {
    final value = object.senderPic;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  bytesCount += 3 + object.targetRole.length * 3;
  bytesCount += 3 + object.toUid.length * 3;
  return bytesCount;
}

void _localInvitationSerialize(
  LocalInvitation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.acceptedAt);
  writer.writeString(offsets[1], object.boardId);
  writer.writeString(offsets[2], object.boardTitle);
  writer.writeDateTime(offsets[3], object.cachedAt);
  writer.writeDateTime(offsets[4], object.expiresAt);
  writer.writeString(offsets[5], object.fromUid);
  writer.writeLong(offsets[6], object.inviteExpiryHours);
  writer.writeString(offsets[7], object.inviteId);
  writer.writeString(offsets[8], object.inviterRoleSnapshot);
  writer.writeDateTime(offsets[9], object.rejectedAt);
  writer.writeDateTime(offsets[10], object.resolvedAt);
  writer.writeString(offsets[11], object.senderName);
  writer.writeString(offsets[12], object.senderPic);
  writer.writeString(offsets[13], object.status);
  writer.writeString(offsets[14], object.targetRole);
  writer.writeDateTime(offsets[15], object.timestamp);
  writer.writeString(offsets[16], object.toUid);
}

LocalInvitation _localInvitationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalInvitation();
  object.acceptedAt = reader.readDateTimeOrNull(offsets[0]);
  object.boardId = reader.readString(offsets[1]);
  object.boardTitle = reader.readString(offsets[2]);
  object.cachedAt = reader.readDateTime(offsets[3]);
  object.expiresAt = reader.readDateTimeOrNull(offsets[4]);
  object.fromUid = reader.readString(offsets[5]);
  object.id = id;
  object.inviteExpiryHours = reader.readLongOrNull(offsets[6]);
  object.inviteId = reader.readString(offsets[7]);
  object.inviterRoleSnapshot = reader.readStringOrNull(offsets[8]);
  object.rejectedAt = reader.readDateTimeOrNull(offsets[9]);
  object.resolvedAt = reader.readDateTimeOrNull(offsets[10]);
  object.senderName = reader.readString(offsets[11]);
  object.senderPic = reader.readStringOrNull(offsets[12]);
  object.status = reader.readString(offsets[13]);
  object.targetRole = reader.readString(offsets[14]);
  object.timestamp = reader.readDateTime(offsets[15]);
  object.toUid = reader.readString(offsets[16]);
  return object;
}

P _localInvitationDeserializeProp<P>(
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
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readDateTime(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localInvitationGetId(LocalInvitation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localInvitationGetLinks(LocalInvitation object) {
  return [];
}

void _localInvitationAttach(
  IsarCollection<dynamic> col,
  Id id,
  LocalInvitation object,
) {
  object.id = id;
}

extension LocalInvitationByIndex on IsarCollection<LocalInvitation> {
  Future<LocalInvitation?> getByInviteId(String inviteId) {
    return getByIndex(r'inviteId', [inviteId]);
  }

  LocalInvitation? getByInviteIdSync(String inviteId) {
    return getByIndexSync(r'inviteId', [inviteId]);
  }

  Future<bool> deleteByInviteId(String inviteId) {
    return deleteByIndex(r'inviteId', [inviteId]);
  }

  bool deleteByInviteIdSync(String inviteId) {
    return deleteByIndexSync(r'inviteId', [inviteId]);
  }

  Future<List<LocalInvitation?>> getAllByInviteId(List<String> inviteIdValues) {
    final values = inviteIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'inviteId', values);
  }

  List<LocalInvitation?> getAllByInviteIdSync(List<String> inviteIdValues) {
    final values = inviteIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'inviteId', values);
  }

  Future<int> deleteAllByInviteId(List<String> inviteIdValues) {
    final values = inviteIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'inviteId', values);
  }

  int deleteAllByInviteIdSync(List<String> inviteIdValues) {
    final values = inviteIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'inviteId', values);
  }

  Future<Id> putByInviteId(LocalInvitation object) {
    return putByIndex(r'inviteId', object);
  }

  Id putByInviteIdSync(LocalInvitation object, {bool saveLinks = true}) {
    return putByIndexSync(r'inviteId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByInviteId(List<LocalInvitation> objects) {
    return putAllByIndex(r'inviteId', objects);
  }

  List<Id> putAllByInviteIdSync(
    List<LocalInvitation> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'inviteId', objects, saveLinks: saveLinks);
  }
}

extension LocalInvitationQueryWhereSort
    on QueryBuilder<LocalInvitation, LocalInvitation, QWhere> {
  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension LocalInvitationQueryWhere
    on QueryBuilder<LocalInvitation, LocalInvitation, QWhereClause> {
  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause> idBetween(
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  inviteIdEqualTo(String inviteId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'inviteId', value: [inviteId]),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  inviteIdNotEqualTo(String inviteId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inviteId',
                lower: [],
                upper: [inviteId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inviteId',
                lower: [inviteId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inviteId',
                lower: [inviteId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'inviteId',
                lower: [],
                upper: [inviteId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  boardIdEqualTo(String boardId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'boardId', value: [boardId]),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  fromUidEqualTo(String fromUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'fromUid', value: [fromUid]),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  toUidEqualTo(String toUid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'toUid', value: [toUid]),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  statusEqualTo(String status) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'status', value: [status]),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
  timestampEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'timestamp', value: [timestamp]),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterWhereClause>
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

extension LocalInvitationQueryFilter
    on QueryBuilder<LocalInvitation, LocalInvitation, QFilterCondition> {
  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  acceptedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'acceptedAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  acceptedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'acceptedAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  acceptedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'acceptedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardId', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'boardId', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'boardTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'boardTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'boardTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'boardTitle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'boardTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'boardTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'boardTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'boardTitle',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'boardTitle', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  boardTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'boardTitle', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  cachedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cachedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  expiresAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'expiresAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  expiresAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'expiresAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  expiresAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'expiresAt', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  expiresAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'expiresAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  expiresAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'expiresAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  expiresAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'expiresAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  fromUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fromUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  fromUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fromUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteExpiryHoursIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'inviteExpiryHours'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteExpiryHoursIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'inviteExpiryHours'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteExpiryHoursEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inviteExpiryHours', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteExpiryHoursGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'inviteExpiryHours',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteExpiryHoursLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'inviteExpiryHours',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteExpiryHoursBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'inviteExpiryHours',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inviteId', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'inviteId', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'inviterRoleSnapshot'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'inviterRoleSnapshot'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'inviterRoleSnapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'inviterRoleSnapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'inviterRoleSnapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'inviterRoleSnapshot',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'inviterRoleSnapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'inviterRoleSnapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'inviterRoleSnapshot',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'inviterRoleSnapshot',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inviterRoleSnapshot', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  inviterRoleSnapshotIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'inviterRoleSnapshot',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  rejectedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rejectedAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  rejectedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rejectedAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  rejectedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rejectedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  resolvedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'resolvedAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  resolvedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'resolvedAt'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  resolvedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'resolvedAt', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  resolvedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'resolvedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  resolvedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'resolvedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  resolvedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'resolvedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  senderNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'senderName', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  senderNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'senderName', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  senderPicIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'senderPic'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  senderPicIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'senderPic'),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  senderPicIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'senderPic', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  senderPicIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'senderPic', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'targetRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'targetRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'targetRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'targetRole',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'targetRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'targetRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'targetRole',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'targetRole',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'targetRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  targetRoleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'targetRole', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'timestamp', value: value),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
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

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  toUidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'toUid', value: ''),
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterFilterCondition>
  toUidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'toUid', value: ''),
      );
    });
  }
}

extension LocalInvitationQueryObject
    on QueryBuilder<LocalInvitation, LocalInvitation, QFilterCondition> {}

extension LocalInvitationQueryLinks
    on QueryBuilder<LocalInvitation, LocalInvitation, QFilterCondition> {}

extension LocalInvitationQuerySortBy
    on QueryBuilder<LocalInvitation, LocalInvitation, QSortBy> {
  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> sortByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByBoardTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardTitle', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByBoardTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardTitle', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> sortByFromUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByFromUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByInviteExpiryHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteExpiryHours', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByInviteExpiryHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteExpiryHours', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByInviteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByInviteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByInviterRoleSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviterRoleSnapshot', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByInviterRoleSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviterRoleSnapshot', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByRejectedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByRejectedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortBySenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortBySenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortBySenderPic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortBySenderPicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByTargetRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRole', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByTargetRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRole', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> sortByToUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  sortByToUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.desc);
    });
  }
}

extension LocalInvitationQuerySortThenBy
    on QueryBuilder<LocalInvitation, LocalInvitation, QSortThenBy> {
  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByAcceptedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acceptedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> thenByBoardId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByBoardIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardId', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByBoardTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardTitle', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByBoardTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'boardTitle', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> thenByFromUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByFromUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUid', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByInviteExpiryHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteExpiryHours', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByInviteExpiryHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteExpiryHours', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByInviteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByInviteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviteId', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByInviterRoleSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviterRoleSnapshot', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByInviterRoleSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inviterRoleSnapshot', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByRejectedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByRejectedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rejectedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByResolvedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resolvedAt', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenBySenderName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenBySenderNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderName', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenBySenderPic() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenBySenderPicDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'senderPic', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByTargetRole() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRole', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByTargetRoleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetRole', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy> thenByToUid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.asc);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QAfterSortBy>
  thenByToUidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUid', Sort.desc);
    });
  }
}

extension LocalInvitationQueryWhereDistinct
    on QueryBuilder<LocalInvitation, LocalInvitation, QDistinct> {
  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByAcceptedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acceptedAt');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct> distinctByBoardId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByBoardTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'boardTitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct> distinctByFromUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromUid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByInviteExpiryHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inviteExpiryHours');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct> distinctByInviteId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'inviteId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByInviterRoleSnapshot({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'inviterRoleSnapshot',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByRejectedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rejectedAt');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByResolvedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resolvedAt');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctBySenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctBySenderPic({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'senderPic', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByTargetRole({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetRole', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct>
  distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<LocalInvitation, LocalInvitation, QDistinct> distinctByToUid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toUid', caseSensitive: caseSensitive);
    });
  }
}

extension LocalInvitationQueryProperty
    on QueryBuilder<LocalInvitation, LocalInvitation, QQueryProperty> {
  QueryBuilder<LocalInvitation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalInvitation, DateTime?, QQueryOperations>
  acceptedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acceptedAt');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> boardIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardId');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> boardTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boardTitle');
    });
  }

  QueryBuilder<LocalInvitation, DateTime, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<LocalInvitation, DateTime?, QQueryOperations>
  expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> fromUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromUid');
    });
  }

  QueryBuilder<LocalInvitation, int?, QQueryOperations>
  inviteExpiryHoursProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inviteExpiryHours');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> inviteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inviteId');
    });
  }

  QueryBuilder<LocalInvitation, String?, QQueryOperations>
  inviterRoleSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inviterRoleSnapshot');
    });
  }

  QueryBuilder<LocalInvitation, DateTime?, QQueryOperations>
  rejectedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rejectedAt');
    });
  }

  QueryBuilder<LocalInvitation, DateTime?, QQueryOperations>
  resolvedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resolvedAt');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> senderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderName');
    });
  }

  QueryBuilder<LocalInvitation, String?, QQueryOperations> senderPicProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'senderPic');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> targetRoleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetRole');
    });
  }

  QueryBuilder<LocalInvitation, DateTime, QQueryOperations>
  timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<LocalInvitation, String, QQueryOperations> toUidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toUid');
    });
  }
}
