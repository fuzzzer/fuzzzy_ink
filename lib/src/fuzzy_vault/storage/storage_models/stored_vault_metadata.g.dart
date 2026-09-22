// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_vault_metadata.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStoredVaultMetadataCollection on Isar {
  IsarCollection<StoredVaultMetadata> get storedVaultMetadatas =>
      this.collection();
}

const StoredVaultMetadataSchema = CollectionSchema(
  name: r'StoredVaultMetadata',
  id: 8614133422869781340,
  properties: {
    r'autoLockMinutes': PropertySchema(
      id: 0,
      name: r'autoLockMinutes',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'customDirectoryPath': PropertySchema(
      id: 2,
      name: r'customDirectoryPath',
      type: IsarType.string,
    ),
    r'lastUnlockedAt': PropertySchema(
      id: 3,
      name: r'lastUnlockedAt',
      type: IsarType.dateTime,
    ),
    r'vaultId': PropertySchema(
      id: 4,
      name: r'vaultId',
      type: IsarType.string,
    ),
    r'verificationTokenBase64': PropertySchema(
      id: 5,
      name: r'verificationTokenBase64',
      type: IsarType.string,
    )
  },
  estimateSize: _storedVaultMetadataEstimateSize,
  serialize: _storedVaultMetadataSerialize,
  deserialize: _storedVaultMetadataDeserialize,
  deserializeProp: _storedVaultMetadataDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _storedVaultMetadataGetId,
  getLinks: _storedVaultMetadataGetLinks,
  attach: _storedVaultMetadataAttach,
  version: '3.1.0+1',
);

int _storedVaultMetadataEstimateSize(
  StoredVaultMetadata object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.customDirectoryPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.vaultId.length * 3;
  bytesCount += 3 + object.verificationTokenBase64.length * 3;
  return bytesCount;
}

void _storedVaultMetadataSerialize(
  StoredVaultMetadata object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.autoLockMinutes);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.customDirectoryPath);
  writer.writeDateTime(offsets[3], object.lastUnlockedAt);
  writer.writeString(offsets[4], object.vaultId);
  writer.writeString(offsets[5], object.verificationTokenBase64);
}

StoredVaultMetadata _storedVaultMetadataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoredVaultMetadata();
  object.autoLockMinutes = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.customDirectoryPath = reader.readStringOrNull(offsets[2]);
  object.id = id;
  object.lastUnlockedAt = reader.readDateTime(offsets[3]);
  object.vaultId = reader.readString(offsets[4]);
  object.verificationTokenBase64 = reader.readString(offsets[5]);
  return object;
}

P _storedVaultMetadataDeserializeProp<P>(
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
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _storedVaultMetadataGetId(StoredVaultMetadata object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storedVaultMetadataGetLinks(
    StoredVaultMetadata object) {
  return [];
}

void _storedVaultMetadataAttach(
    IsarCollection<dynamic> col, Id id, StoredVaultMetadata object) {
  object.id = id;
}

extension StoredVaultMetadataQueryWhereSort
    on QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QWhere> {
  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StoredVaultMetadataQueryWhere
    on QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QWhereClause> {
  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterWhereClause>
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterWhereClause>
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
}

extension StoredVaultMetadataQueryFilter on QueryBuilder<StoredVaultMetadata,
    StoredVaultMetadata, QFilterCondition> {
  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      autoLockMinutesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoLockMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      autoLockMinutesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'autoLockMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      autoLockMinutesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'autoLockMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      autoLockMinutesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'autoLockMinutes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      createdAtGreaterThan(
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      createdAtLessThan(
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      createdAtBetween(
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'customDirectoryPath',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'customDirectoryPath',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customDirectoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customDirectoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customDirectoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customDirectoryPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'customDirectoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'customDirectoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'customDirectoryPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'customDirectoryPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customDirectoryPath',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      customDirectoryPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'customDirectoryPath',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
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

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      lastUnlockedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUnlockedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      lastUnlockedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUnlockedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      lastUnlockedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUnlockedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      lastUnlockedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUnlockedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'vaultId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'vaultId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'vaultId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'vaultId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      vaultIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'vaultId',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64EqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'verificationTokenBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64GreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'verificationTokenBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64LessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'verificationTokenBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64Between(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'verificationTokenBase64',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'verificationTokenBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'verificationTokenBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64Contains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'verificationTokenBase64',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64Matches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'verificationTokenBase64',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'verificationTokenBase64',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterFilterCondition>
      verificationTokenBase64IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'verificationTokenBase64',
        value: '',
      ));
    });
  }
}

extension StoredVaultMetadataQueryObject on QueryBuilder<StoredVaultMetadata,
    StoredVaultMetadata, QFilterCondition> {}

extension StoredVaultMetadataQueryLinks on QueryBuilder<StoredVaultMetadata,
    StoredVaultMetadata, QFilterCondition> {}

extension StoredVaultMetadataQuerySortBy
    on QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QSortBy> {
  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByAutoLockMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLockMinutes', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByAutoLockMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLockMinutes', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByCustomDirectoryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDirectoryPath', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByCustomDirectoryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDirectoryPath', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByLastUnlockedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUnlockedAt', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByLastUnlockedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUnlockedAt', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByVaultId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByVaultIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByVerificationTokenBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verificationTokenBase64', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      sortByVerificationTokenBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verificationTokenBase64', Sort.desc);
    });
  }
}

extension StoredVaultMetadataQuerySortThenBy
    on QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QSortThenBy> {
  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByAutoLockMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLockMinutes', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByAutoLockMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoLockMinutes', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByCustomDirectoryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDirectoryPath', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByCustomDirectoryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customDirectoryPath', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByLastUnlockedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUnlockedAt', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByLastUnlockedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUnlockedAt', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByVaultId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByVaultIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'vaultId', Sort.desc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByVerificationTokenBase64() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verificationTokenBase64', Sort.asc);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QAfterSortBy>
      thenByVerificationTokenBase64Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'verificationTokenBase64', Sort.desc);
    });
  }
}

extension StoredVaultMetadataQueryWhereDistinct
    on QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct> {
  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct>
      distinctByAutoLockMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoLockMinutes');
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct>
      distinctByCustomDirectoryPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customDirectoryPath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct>
      distinctByLastUnlockedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUnlockedAt');
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct>
      distinctByVaultId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'vaultId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QDistinct>
      distinctByVerificationTokenBase64({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'verificationTokenBase64',
          caseSensitive: caseSensitive);
    });
  }
}

extension StoredVaultMetadataQueryProperty
    on QueryBuilder<StoredVaultMetadata, StoredVaultMetadata, QQueryProperty> {
  QueryBuilder<StoredVaultMetadata, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoredVaultMetadata, int, QQueryOperations>
      autoLockMinutesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoLockMinutes');
    });
  }

  QueryBuilder<StoredVaultMetadata, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<StoredVaultMetadata, String?, QQueryOperations>
      customDirectoryPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customDirectoryPath');
    });
  }

  QueryBuilder<StoredVaultMetadata, DateTime, QQueryOperations>
      lastUnlockedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUnlockedAt');
    });
  }

  QueryBuilder<StoredVaultMetadata, String, QQueryOperations>
      vaultIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'vaultId');
    });
  }

  QueryBuilder<StoredVaultMetadata, String, QQueryOperations>
      verificationTokenBase64Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'verificationTokenBase64');
    });
  }
}
