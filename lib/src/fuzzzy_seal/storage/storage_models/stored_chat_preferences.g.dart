// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_chat_preferences.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStoredChatPreferencesCollection on Isar {
  IsarCollection<StoredChatPreferences> get storedChatPreferences =>
      this.collection();
}

const StoredChatPreferencesSchema = CollectionSchema(
  name: r'StoredChatPreferences',
  id: -7061712216966606075,
  properties: {
    r'lastUpdated': PropertySchema(
      id: 0,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'showTimestamps': PropertySchema(
      id: 1,
      name: r'showTimestamps',
      type: IsarType.bool,
    ),
    r'theme': PropertySchema(
      id: 2,
      name: r'theme',
      type: IsarType.string,
    )
  },
  estimateSize: _storedChatPreferencesEstimateSize,
  serialize: _storedChatPreferencesSerialize,
  deserialize: _storedChatPreferencesDeserialize,
  deserializeProp: _storedChatPreferencesDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _storedChatPreferencesGetId,
  getLinks: _storedChatPreferencesGetLinks,
  attach: _storedChatPreferencesAttach,
  version: '3.1.0+1',
);

int _storedChatPreferencesEstimateSize(
  StoredChatPreferences object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.theme;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _storedChatPreferencesSerialize(
  StoredChatPreferences object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.lastUpdated);
  writer.writeBool(offsets[1], object.showTimestamps);
  writer.writeString(offsets[2], object.theme);
}

StoredChatPreferences _storedChatPreferencesDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoredChatPreferences();
  object.id = id;
  object.lastUpdated = reader.readDateTime(offsets[0]);
  object.showTimestamps = reader.readBool(offsets[1]);
  object.theme = reader.readStringOrNull(offsets[2]);
  return object;
}

P _storedChatPreferencesDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _storedChatPreferencesGetId(StoredChatPreferences object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storedChatPreferencesGetLinks(
    StoredChatPreferences object) {
  return [];
}

void _storedChatPreferencesAttach(
    IsarCollection<dynamic> col, Id id, StoredChatPreferences object) {
  object.id = id;
}

extension StoredChatPreferencesQueryWhereSort
    on QueryBuilder<StoredChatPreferences, StoredChatPreferences, QWhere> {
  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StoredChatPreferencesQueryWhere on QueryBuilder<StoredChatPreferences,
    StoredChatPreferences, QWhereClause> {
  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterWhereClause>
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

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterWhereClause>
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

extension StoredChatPreferencesQueryFilter on QueryBuilder<
    StoredChatPreferences, StoredChatPreferences, QFilterCondition> {
  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
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

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
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

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
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

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> lastUpdatedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> lastUpdatedGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> lastUpdatedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> lastUpdatedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdated',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> showTimestampsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'showTimestamps',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'theme',
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'theme',
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'theme',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
          QAfterFilterCondition>
      themeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'theme',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
          QAfterFilterCondition>
      themeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'theme',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'theme',
        value: '',
      ));
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences,
      QAfterFilterCondition> themeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'theme',
        value: '',
      ));
    });
  }
}

extension StoredChatPreferencesQueryObject on QueryBuilder<
    StoredChatPreferences, StoredChatPreferences, QFilterCondition> {}

extension StoredChatPreferencesQueryLinks on QueryBuilder<StoredChatPreferences,
    StoredChatPreferences, QFilterCondition> {}

extension StoredChatPreferencesQuerySortBy
    on QueryBuilder<StoredChatPreferences, StoredChatPreferences, QSortBy> {
  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      sortByShowTimestamps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showTimestamps', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      sortByShowTimestampsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showTimestamps', Sort.desc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      sortByTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      sortByThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.desc);
    });
  }
}

extension StoredChatPreferencesQuerySortThenBy
    on QueryBuilder<StoredChatPreferences, StoredChatPreferences, QSortThenBy> {
  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByShowTimestamps() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showTimestamps', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByShowTimestampsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showTimestamps', Sort.desc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.asc);
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QAfterSortBy>
      thenByThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'theme', Sort.desc);
    });
  }
}

extension StoredChatPreferencesQueryWhereDistinct
    on QueryBuilder<StoredChatPreferences, StoredChatPreferences, QDistinct> {
  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QDistinct>
      distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QDistinct>
      distinctByShowTimestamps() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'showTimestamps');
    });
  }

  QueryBuilder<StoredChatPreferences, StoredChatPreferences, QDistinct>
      distinctByTheme({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'theme', caseSensitive: caseSensitive);
    });
  }
}

extension StoredChatPreferencesQueryProperty on QueryBuilder<
    StoredChatPreferences, StoredChatPreferences, QQueryProperty> {
  QueryBuilder<StoredChatPreferences, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoredChatPreferences, DateTime, QQueryOperations>
      lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<StoredChatPreferences, bool, QQueryOperations>
      showTimestampsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'showTimestamps');
    });
  }

  QueryBuilder<StoredChatPreferences, String?, QQueryOperations>
      themeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'theme');
    });
  }
}
