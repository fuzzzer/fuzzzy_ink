// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_chat_general_data.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStoredChatGeneralDataCollection on Isar {
  IsarCollection<StoredChatGeneralData> get storedChatGeneralDatas =>
      this.collection();
}

const StoredChatGeneralDataSchema = CollectionSchema(
  name: r'StoredChatGeneralData',
  id: 1591319642795052830,
  properties: {
    r'chatId': PropertySchema(
      id: 0,
      name: r'chatId',
      type: IsarType.string,
    ),
    r'chatName': PropertySchema(
      id: 1,
      name: r'chatName',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'didAcceptInvitation': PropertySchema(
      id: 3,
      name: r'didAcceptInvitation',
      type: IsarType.bool,
    ),
    r'setupStatus': PropertySchema(
      id: 4,
      name: r'setupStatus',
      type: IsarType.byte,
      enumMap: _StoredChatGeneralDatasetupStatusEnumValueMap,
    )
  },
  estimateSize: _storedChatGeneralDataEstimateSize,
  serialize: _storedChatGeneralDataSerialize,
  deserialize: _storedChatGeneralDataDeserialize,
  deserializeProp: _storedChatGeneralDataDeserializeProp,
  idName: r'id',
  indexes: {
    r'chatId': IndexSchema(
      id: 1909629659142158609,
      name: r'chatId',
      unique: true,
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
  getId: _storedChatGeneralDataGetId,
  getLinks: _storedChatGeneralDataGetLinks,
  attach: _storedChatGeneralDataAttach,
  version: '3.1.0+1',
);

int _storedChatGeneralDataEstimateSize(
  StoredChatGeneralData object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.chatId.length * 3;
  bytesCount += 3 + object.chatName.length * 3;
  return bytesCount;
}

void _storedChatGeneralDataSerialize(
  StoredChatGeneralData object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.chatId);
  writer.writeString(offsets[1], object.chatName);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeBool(offsets[3], object.didAcceptInvitation);
  writer.writeByte(offsets[4], object.setupStatus.index);
}

StoredChatGeneralData _storedChatGeneralDataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoredChatGeneralData();
  object.chatId = reader.readString(offsets[0]);
  object.chatName = reader.readString(offsets[1]);
  object.createdAt = reader.readDateTime(offsets[2]);
  object.didAcceptInvitation = reader.readBool(offsets[3]);
  object.id = id;
  object.setupStatus = _StoredChatGeneralDatasetupStatusValueEnumMap[
          reader.readByteOrNull(offsets[4])] ??
      ChatSetupStatus.connected;
  return object;
}

P _storedChatGeneralDataDeserializeProp<P>(
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
      return (reader.readBool(offset)) as P;
    case 4:
      return (_StoredChatGeneralDatasetupStatusValueEnumMap[
              reader.readByteOrNull(offset)] ??
          ChatSetupStatus.connected) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _StoredChatGeneralDatasetupStatusEnumValueMap = {
  'connected': 0,
  'invited': 1,
};
const _StoredChatGeneralDatasetupStatusValueEnumMap = {
  0: ChatSetupStatus.connected,
  1: ChatSetupStatus.invited,
};

Id _storedChatGeneralDataGetId(StoredChatGeneralData object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storedChatGeneralDataGetLinks(
    StoredChatGeneralData object) {
  return [];
}

void _storedChatGeneralDataAttach(
    IsarCollection<dynamic> col, Id id, StoredChatGeneralData object) {
  object.id = id;
}

extension StoredChatGeneralDataByIndex
    on IsarCollection<StoredChatGeneralData> {
  Future<StoredChatGeneralData?> getByChatId(String chatId) {
    return getByIndex(r'chatId', [chatId]);
  }

  StoredChatGeneralData? getByChatIdSync(String chatId) {
    return getByIndexSync(r'chatId', [chatId]);
  }

  Future<bool> deleteByChatId(String chatId) {
    return deleteByIndex(r'chatId', [chatId]);
  }

  bool deleteByChatIdSync(String chatId) {
    return deleteByIndexSync(r'chatId', [chatId]);
  }

  Future<List<StoredChatGeneralData?>> getAllByChatId(
      List<String> chatIdValues) {
    final values = chatIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'chatId', values);
  }

  List<StoredChatGeneralData?> getAllByChatIdSync(List<String> chatIdValues) {
    final values = chatIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'chatId', values);
  }

  Future<int> deleteAllByChatId(List<String> chatIdValues) {
    final values = chatIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'chatId', values);
  }

  int deleteAllByChatIdSync(List<String> chatIdValues) {
    final values = chatIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'chatId', values);
  }

  Future<Id> putByChatId(StoredChatGeneralData object) {
    return putByIndex(r'chatId', object);
  }

  Id putByChatIdSync(StoredChatGeneralData object, {bool saveLinks = true}) {
    return putByIndexSync(r'chatId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByChatId(List<StoredChatGeneralData> objects) {
    return putAllByIndex(r'chatId', objects);
  }

  List<Id> putAllByChatIdSync(List<StoredChatGeneralData> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'chatId', objects, saveLinks: saveLinks);
  }
}

extension StoredChatGeneralDataQueryWhereSort
    on QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QWhere> {
  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StoredChatGeneralDataQueryWhere on QueryBuilder<StoredChatGeneralData,
    StoredChatGeneralData, QWhereClause> {
  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
      chatIdEqualTo(String chatId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'chatId',
        value: [chatId],
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterWhereClause>
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

extension StoredChatGeneralDataQueryFilter on QueryBuilder<
    StoredChatGeneralData, StoredChatGeneralData, QFilterCondition> {
  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdEqualTo(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdGreaterThan(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdLessThan(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdBetween(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdStartsWith(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdEndsWith(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
          QAfterFilterCondition>
      chatIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chatId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
          QAfterFilterCondition>
      chatIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chatId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chatId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chatName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chatName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chatName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chatName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chatName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
          QAfterFilterCondition>
      chatNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chatName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
          QAfterFilterCondition>
      chatNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chatName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatName',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> chatNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chatName',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> didAcceptInvitationEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'didAcceptInvitation',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> idLessThan(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> idBetween(
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

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> setupStatusEqualTo(ChatSetupStatus value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'setupStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> setupStatusGreaterThan(
    ChatSetupStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'setupStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> setupStatusLessThan(
    ChatSetupStatus value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'setupStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData,
      QAfterFilterCondition> setupStatusBetween(
    ChatSetupStatus lower,
    ChatSetupStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'setupStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension StoredChatGeneralDataQueryObject on QueryBuilder<
    StoredChatGeneralData, StoredChatGeneralData, QFilterCondition> {}

extension StoredChatGeneralDataQueryLinks on QueryBuilder<StoredChatGeneralData,
    StoredChatGeneralData, QFilterCondition> {}

extension StoredChatGeneralDataQuerySortBy
    on QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QSortBy> {
  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByChatId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByChatIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByChatName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatName', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByChatNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatName', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByDidAcceptInvitation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'didAcceptInvitation', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortByDidAcceptInvitationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'didAcceptInvitation', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortBySetupStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'setupStatus', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      sortBySetupStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'setupStatus', Sort.desc);
    });
  }
}

extension StoredChatGeneralDataQuerySortThenBy
    on QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QSortThenBy> {
  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByChatId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByChatIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatId', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByChatName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatName', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByChatNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatName', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByDidAcceptInvitation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'didAcceptInvitation', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByDidAcceptInvitationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'didAcceptInvitation', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenBySetupStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'setupStatus', Sort.asc);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QAfterSortBy>
      thenBySetupStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'setupStatus', Sort.desc);
    });
  }
}

extension StoredChatGeneralDataQueryWhereDistinct
    on QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QDistinct> {
  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QDistinct>
      distinctByChatId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chatId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QDistinct>
      distinctByChatName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chatName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QDistinct>
      distinctByDidAcceptInvitation() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'didAcceptInvitation');
    });
  }

  QueryBuilder<StoredChatGeneralData, StoredChatGeneralData, QDistinct>
      distinctBySetupStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'setupStatus');
    });
  }
}

extension StoredChatGeneralDataQueryProperty on QueryBuilder<
    StoredChatGeneralData, StoredChatGeneralData, QQueryProperty> {
  QueryBuilder<StoredChatGeneralData, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoredChatGeneralData, String, QQueryOperations>
      chatIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chatId');
    });
  }

  QueryBuilder<StoredChatGeneralData, String, QQueryOperations>
      chatNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chatName');
    });
  }

  QueryBuilder<StoredChatGeneralData, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StoredChatGeneralData, bool, QQueryOperations>
      didAcceptInvitationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'didAcceptInvitation');
    });
  }

  QueryBuilder<StoredChatGeneralData, ChatSetupStatus, QQueryOperations>
      setupStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'setupStatus');
    });
  }
}
