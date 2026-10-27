import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockVaultRepository extends Mock implements VaultRepository {}

class MockVaultKey extends Mock implements VaultKey {}

VaultItemMetadata _meta(String id) => VaultItemMetadata(
      id: id,
      title: id,
      type: VaultItemType.password,
      groupId: VaultGroupData.generalGroupId,
      tags: const [],
      isFavorite: false,
      hasCustomPassword: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      contentVersion: 1,
    );

/// The rows' labels (usernames, file names) leave memory when the safe locks
/// (security review 2026-10-26).
void main() {
  late MockVaultRepository repository;
  late StreamController<VaultDataUpdated> updates;
  final key = MockVaultKey();
  final items = [_meta('bank')];

  setUpAll(() => registerFallbackValue(MockVaultKey()));

  setUp(() {
    repository = MockVaultRepository();
    updates = StreamController<VaultDataUpdated>.broadcast();
    when(() => repository.vaultDataUpdates).thenAnswer((_) => updates.stream);
    when(() => repository.getAllItems())
        .thenAnswer((_) async => VaultSuccess(items));
  });

  tearDown(() => updates.close());

  test('locking forgets the labels and the key', () async {
    when(() => repository.readLabels(any(), key))
        .thenAnswer((_) async => {'bank': 'tamar@mail.ge'});
    final cubit = VaultItemsCubit(vaultRepository: repository);
    addTearDown(cubit.close);

    await cubit.loadItems(key: key);
    expect(cubit.state.labels, {'bank': 'tamar@mail.ge'});

    cubit.forgetLabels();
    expect(cubit.state.labels, isEmpty);
    expect(cubit.state.items, items, reason: 'titles are not vault content');

    // A later reload (a change signal while locked) opens nothing.
    await cubit.loadItems();
    expect(cubit.state.labels, isEmpty);
    verify(() => repository.readLabels(any(), any())).called(1);
  });

  test('labels still being opened when the safe locks are dropped', () async {
    final reading = Completer<Map<String, String>>();
    when(() => repository.readLabels(any(), key))
        .thenAnswer((_) => reading.future);
    final cubit = VaultItemsCubit(vaultRepository: repository);
    addTearDown(cubit.close);

    final loading = cubit.loadItems(key: key);
    await pumpEventQueue();
    cubit.forgetLabels();
    reading.complete({'bank': 'tamar@mail.ge'});
    await loading;

    expect(cubit.state.labels, isEmpty);
  });
}
