// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_message_data.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStoredMessageDataCollection on Isar {
  IsarCollection<StoredMessageData> get storedMessageDatas => this.collection();
}

const StoredMessageDataSchema = CollectionSchema(
  name: r'StoredMessageData',
  id: 61036243108229442,
  properties: {
    r'chatId': PropertySchema(
      id: 0,
      name: r'chatId',
      type: IsarType.string,
    ),
    r'encryptedMessage': PropertySchema(
      id: 1,
      name: r'encryptedMessage',
      type: IsarType.string,
    ),
    r'isSent': PropertySchema(
      id: 2,
      name: r'isSent',
      type: IsarType.bool,
    ),
    r'messageType': PropertySchema(
      id: 3,
      name: r'messageType',
      type: IsarType.string,
    ),
    r'sealedPlaintext': PropertySchema(
      id: 4,
      name: r'sealedPlaintext',
      type: IsarType.string,
    ),
    r'sentAt': PropertySchema(
      id: 5,
      name: r'sentAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _storedMessageDataEstimateSize,
  serialize: _storedMessageDataSerialize,
  deserialize: _storedMessageDataDeserialize,
  deserializeProp: _storedMessageDataDeserializeProp,
  idName: r'id',
  indexes: {
    r'chatId': IndexSchema(
      id: 1909629659142158609,
      name: r'chatId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'chatId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _storedMessageDataGetId,
  getLinks: _storedMessageDataGetLinks,
  attach: _storedMessageDataAttach,
  version: '3.1.0+1',
);

int _storedMessageDataEstimateSize(
  StoredMessageData object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.chatId.length * 3;
  bytesCount += 3 + object.encryptedMessage.length * 3;
  bytesCount += 3 + object.messageType.length * 3;
  {
    final value = object.sealedPlaintext;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _storedMessageDataSerialize(
  StoredMessageData object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.chatId);
  writer.writeString(offsets[1], object.encryptedMessage);
  writer.writeBool(offsets[2], object.isSent);
  writer.writeString(offsets[3], object.messageType);
  writer.writeString(offsets[4], object.sealedPlaintext);
  writer.writeDateTime(offsets[5], object.sentAt);
}

StoredMessageData _storedMessageDataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoredMessageData();
  object.chatId = reader.readString(offsets[0]);
  object.encryptedMessage = reader.readString(offsets[1]);
  object.id = id;
  object.isSent = reader.readBool(offsets[2]);
  object.messageType = reader.readString(offsets[3]);
  object.sealedPlaintext = reader.readStringOrNull(offsets[4]);
  object.sentAt = reader.readDateTime(offsets[5]);
  return object;
}

P _storedMessageDataDeserializeProp<P>(
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
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _storedMessageDataGetId(StoredMessageData object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storedMessageDataGetLinks(
    StoredMessageData object) {
  return [];
}

void _storedMessageDataAttach(
    IsarCollection<dynamic> col, Id id, StoredMessageData object) {
  object.id = id;
}

extension StoredMessageDataQueryWhereSort
    on QueryBuilder<StoredMessageData, StoredMessageData, QWhere> {
  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StoredMessageDataQueryWhere
    on QueryBuilder<StoredMessageData, StoredMessageData, QWhereClause> {
  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
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

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
      chatIdEqualTo(String chatId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chatId',
        value: [chatId],
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterWhereClause>
      chatIdNotEqualTo(String chatId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chatId',
              lower: [],
              upper: [chatId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chatId',
              lower: [chatId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chatId',
              lower: [chatId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'chatId',
              lower: [],
              upper: [chatId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension StoredMessageDataQueryFilter
    on QueryBuilder<StoredMessageData, StoredMessageData, QFilterCondition> {
  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chatId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chatId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      chatIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chatId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'encryptedMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'encryptedMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'encryptedMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'encryptedMessage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'encryptedMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'encryptedMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'encryptedMessage',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'encryptedMessage',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'encryptedMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      encryptedMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'encryptedMessage',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
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

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
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

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
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

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      isSentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSent',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'messageType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'messageType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'messageType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'messageType',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      messageTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'messageType',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sealedPlaintext',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sealedPlaintext',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sealedPlaintext',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sealedPlaintext',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sealedPlaintext',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sealedPlaintext',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sealedPlaintext',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sealedPlaintext',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sealedPlaintext',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sealedPlaintext',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sealedPlaintext',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sealedPlaintextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sealedPlaintext',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sentAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sentAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sentAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sentAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sentAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterFilterCondition>
      sentAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sentAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StoredMessageDataQueryObject
    on QueryBuilder<StoredMessageData, StoredMessageData, QFilterCondition> {}

extension StoredMessageDataQueryLinks
    on QueryBuilder<StoredMessageData, StoredMessageData, QFilterCondition> {}

extension StoredMessageDataQuerySortBy
    on QueryBuilder<StoredMessageData, StoredMessageData, QSortBy> {
  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByChatId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByChatIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByEncryptedMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedMessage', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByEncryptedMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedMessage', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByIsSent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByIsSentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortByMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortBySealedPlaintext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sealedPlaintext', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortBySealedPlaintextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sealedPlaintext', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortBySentAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentAt', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      sortBySentAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentAt', Sort.desc);
    });
  }
}

extension StoredMessageDataQuerySortThenBy
    on QueryBuilder<StoredMessageData, StoredMessageData, QSortThenBy> {
  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByChatId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByChatIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByEncryptedMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedMessage', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByEncryptedMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'encryptedMessage', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByIsSent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByIsSentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSent', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByMessageType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenByMessageTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'messageType', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenBySealedPlaintext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sealedPlaintext', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenBySealedPlaintextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sealedPlaintext', Sort.desc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenBySentAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentAt', Sort.asc);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QAfterSortBy>
      thenBySentAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentAt', Sort.desc);
    });
  }
}

extension StoredMessageDataQueryWhereDistinct
    on QueryBuilder<StoredMessageData, StoredMessageData, QDistinct> {
  QueryBuilder<StoredMessageData, StoredMessageData, QDistinct>
      distinctByChatId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chatId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QDistinct>
      distinctByEncryptedMessage({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'encryptedMessage',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QDistinct>
      distinctByIsSent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSent');
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QDistinct>
      distinctByMessageType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'messageType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QDistinct>
      distinctBySealedPlaintext({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sealedPlaintext',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredMessageData, StoredMessageData, QDistinct>
      distinctBySentAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sentAt');
    });
  }
}

extension StoredMessageDataQueryProperty
    on QueryBuilder<StoredMessageData, StoredMessageData, QQueryProperty> {
  QueryBuilder<StoredMessageData, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoredMessageData, String, QQueryOperations> chatIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chatId');
    });
  }

  QueryBuilder<StoredMessageData, String, QQueryOperations>
      encryptedMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'encryptedMessage');
    });
  }

  QueryBuilder<StoredMessageData, bool, QQueryOperations> isSentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSent');
    });
  }

  QueryBuilder<StoredMessageData, String, QQueryOperations>
      messageTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'messageType');
    });
  }

  QueryBuilder<StoredMessageData, String?, QQueryOperations>
      sealedPlaintextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sealedPlaintext');
    });
  }

  QueryBuilder<StoredMessageData, DateTime, QQueryOperations> sentAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sentAt');
    });
  }
}
