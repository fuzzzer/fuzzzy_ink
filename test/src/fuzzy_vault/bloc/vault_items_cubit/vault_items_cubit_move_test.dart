import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockVaultRepository extends Mock implements VaultRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

VaultItemMetadata _meta({
  String id = 'item-1',
  String groupId = 'general',
  String title = 'Test Item',
  VaultItemType type = VaultItemType.password,
}) {
  final now = DateTime(2026);
  return VaultItemMetadata(
    id: id,
    title: title,
    type: type,
    groupId: groupId,
    tags: const [],
    isFavorite: false,
    hasCustomPassword: false,
    createdAt: now,
    updatedAt: now,
    contentVersion: 1,
  );
}

void main() {
  late MockVaultRepository mockRepo;
  late StreamController<VaultDataUpdated> updatesController;

  setUp(() {
    mockRepo = MockVaultRepository();
    updatesController = StreamController<VaultDataUpdated>.broadcast();

    when(() => mockRepo.vaultDataUpdates)
        .thenAnswer((_) => updatesController.stream);
  });

  tearDown(() {
    updatesController.close();
  });

  VaultItemsCubit buildCubit() => VaultItemsCubit(vaultRepository: mockRepo);

  // -----------------------------------------------------------------------
  // moveItemToGroup
  // -----------------------------------------------------------------------
  group('moveItemToGroup', () {
    final movedMeta = _meta(groupId: 'work');
    final allItems = [movedMeta];

    blocTest<VaultItemsCubit, VaultItemsState>(
      'emits [loading, success] when repository returns VaultSuccess',
      setUp: () {
        when(() => mockRepo.moveItemToGroup('item-1', 'work'))
            .thenAnswer((_) async => VaultSuccess(movedMeta));
        when(() => mockRepo.getAllItems())
            .thenAnswer((_) async => VaultSuccess(allItems));
      },
      build: buildCubit,
      act: (cubit) => cubit.moveItemToGroup('item-1', 'work'),
      expect: () => [
        // 1st emission: loading from moveItemToGroup
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        // 2nd emission: loading from loadItems() called internally
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        // 3rd emission: success with reloaded items
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.items, 'items', allItems),
      ],
      verify: (_) {
        verify(() => mockRepo.moveItemToGroup('item-1', 'work')).called(1);
        verify(() => mockRepo.getAllItems()).called(1);
      },
    );

    blocTest<VaultItemsCubit, VaultItemsState>(
      'emits [loading, failed] when repository returns VaultFailure',
      setUp: () {
        when(() => mockRepo.moveItemToGroup('item-1', 'work')).thenAnswer(
          (_) async => const VaultFailure(VaultFailureType.itemNotFound),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.moveItemToGroup('item-1', 'work'),
      expect: () => [
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failureType,
              'failureType',
              VaultFailureType.itemNotFound,
            ),
      ],
      verify: (_) {
        verify(() => mockRepo.moveItemToGroup('item-1', 'work')).called(1);
        verifyNever(() => mockRepo.getAllItems());
      },
    );

    blocTest<VaultItemsCubit, VaultItemsState>(
      'emits [loading, failed] when repository returns storageWriteError',
      setUp: () {
        when(() => mockRepo.moveItemToGroup('item-1', 'work')).thenAnswer(
          (_) async => const VaultFailure(
            VaultFailureType.storageWriteError,
            message: 'disk full',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.moveItemToGroup('item-1', 'work'),
      expect: () => [
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<VaultItemsState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failureType,
              'failureType',
              VaultFailureType.storageWriteError,
            ),
      ],
    );
  });
}
