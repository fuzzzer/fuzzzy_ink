// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_user_auth_preferences.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetStoredUserAuthPreferencesCollection on Isar {
  IsarCollection<StoredUserAuthPreferences> get storedUserAuthPreferences =>
      this.collection();
}

const StoredUserAuthPreferencesSchema = CollectionSchema(
  name: r'StoredUserAuthPreferences',
  id: 356859451092925861,
  properties: {
    r'isAuthenticationOnceEnabled': PropertySchema(
      id: 0,
      name: r'isAuthenticationOnceEnabled',
      type: IsarType.bool,
    ),
    r'lastUpdated': PropertySchema(
      id: 1,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _storedUserAuthPreferencesEstimateSize,
  serialize: _storedUserAuthPreferencesSerialize,
  deserialize: _storedUserAuthPreferencesDeserialize,
  deserializeProp: _storedUserAuthPreferencesDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _storedUserAuthPreferencesGetId,
  getLinks: _storedUserAuthPreferencesGetLinks,
  attach: _storedUserAuthPreferencesAttach,
  version: '3.4.1',
);

int _storedUserAuthPreferencesEstimateSize(
  StoredUserAuthPreferences object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _storedUserAuthPreferencesSerialize(
  StoredUserAuthPreferences object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.isAuthenticationOnceEnabled);
  writer.writeDateTime(offsets[1], object.lastUpdated);
}

StoredUserAuthPreferences _storedUserAuthPreferencesDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StoredUserAuthPreferences();
  object.isAuthenticationOnceEnabled = reader.readBool(offsets[0]);
  object.lastUpdated = reader.readDateTime(offsets[1]);
  return object;
}

P _storedUserAuthPreferencesDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _storedUserAuthPreferencesGetId(StoredUserAuthPreferences object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _storedUserAuthPreferencesGetLinks(
    StoredUserAuthPreferences object) {
  return [];
}

void _storedUserAuthPreferencesAttach(
    IsarCollection<dynamic> col, Id id, StoredUserAuthPreferences object) {}

extension StoredUserAuthPreferencesQueryWhereSort on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QWhere> {
  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StoredUserAuthPreferencesQueryWhere on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QWhereClause> {
  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterWhereClause> idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterWhereClause> idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterWhereClause> idBetween(
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

extension StoredUserAuthPreferencesQueryFilter on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QFilterCondition> {
  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
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

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
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

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
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

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterFilterCondition> isAuthenticationOnceEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAuthenticationOnceEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterFilterCondition> lastUpdatedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
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

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
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

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
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
}

extension StoredUserAuthPreferencesQueryObject on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QFilterCondition> {}

extension StoredUserAuthPreferencesQueryLinks on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QFilterCondition> {}

extension StoredUserAuthPreferencesQuerySortBy on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QSortBy> {
  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> sortByIsAuthenticationOnceEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAuthenticationOnceEnabled', Sort.asc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> sortByIsAuthenticationOnceEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAuthenticationOnceEnabled', Sort.desc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }
}

extension StoredUserAuthPreferencesQuerySortThenBy on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QSortThenBy> {
  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> thenByIsAuthenticationOnceEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAuthenticationOnceEnabled', Sort.asc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> thenByIsAuthenticationOnceEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAuthenticationOnceEnabled', Sort.desc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences,
      QAfterSortBy> thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }
}

extension StoredUserAuthPreferencesQueryWhereDistinct on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QDistinct> {
  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences, QDistinct>
      distinctByIsAuthenticationOnceEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAuthenticationOnceEnabled');
    });
  }

  QueryBuilder<StoredUserAuthPreferences, StoredUserAuthPreferences, QDistinct>
      distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }
}

extension StoredUserAuthPreferencesQueryProperty on QueryBuilder<
    StoredUserAuthPreferences, StoredUserAuthPreferences, QQueryProperty> {
  QueryBuilder<StoredUserAuthPreferences, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StoredUserAuthPreferences, bool, QQueryOperations>
      isAuthenticationOnceEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAuthenticationOnceEnabled');
    });
  }

  QueryBuilder<StoredUserAuthPreferences, DateTime, QQueryOperations>
      lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }
}
