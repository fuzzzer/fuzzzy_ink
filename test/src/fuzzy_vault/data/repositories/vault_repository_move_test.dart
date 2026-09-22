import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockVaultItemLocalDataSource extends Mock
    implements VaultItemLocalDataSource {}

class MockVaultGroupLocalDataSource extends Mock
    implements VaultGroupLocalDataSource {}

class MockVaultFileDataSource extends Mock implements VaultFileDataSource {}

class MockVaultCryptoRepository extends Mock implements VaultCryptoRepository {}

class FakeStoredVaultItem extends Fake implements StoredVaultItem {
  @override
  String itemId;
  @override
  String title;
  @override
  String groupId;
  @override
  VaultItemType type;
  @override
  List<String> tags;
  @override
  bool isFavorite;
  @override
  bool hasCustomPassword;
  @override
  DateTime createdAt;
  @override
  DateTime updatedAt;
  @override
  int contentVersion;

  FakeStoredVaultItem({
    required this.itemId,
    this.title = 'Test',
    this.groupId = 'general',
    this.type = VaultItemType.password,
    this.tags = const [],
    this.isFavorite = false,
    this.hasCustomPassword = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.contentVersion = 1,
  })  : createdAt = createdAt ?? DateTime(2026),
        updatedAt = updatedAt ?? DateTime(2026);
}

void main() {
  late MockVaultItemLocalDataSource mockItemDS;
  late MockVaultGroupLocalDataSource mockGroupDS;
  late MockVaultFileDataSource mockFileDS;
  late MockVaultCryptoRepository mockCryptoRepo;
  late VaultRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeStoredVaultItem(itemId: 'fallback'));
  });

  setUp(() {
    mockItemDS = MockVaultItemLocalDataSource();
    mockGroupDS = MockVaultGroupLocalDataSource();
    mockFileDS = MockVaultFileDataSource();
    mockCryptoRepo = MockVaultCryptoRepository();

    repository = VaultRepository(
      itemDataSource: mockItemDS,
      groupDataSource: mockGroupDS,
      fileDataSource: mockFileDS,
      cryptoRepository: mockCryptoRepo,
    );
  });

  group('moveItemToGroup', () {
    test('returns VaultSuccess when item exists and move succeeds', () async {
      final storedItem = FakeStoredVaultItem(
        itemId: 'item-1',
      );

      when(() => mockItemDS.getItem('item-1'))
          .thenAnswer((_) async => storedItem);
      when(() => mockItemDS.saveItem(storedItem)).thenAnswer((_) async {});

      final result = await repository.moveItemToGroup('item-1', 'work');

      expect(result, isA<VaultSuccess<VaultItemMetadata>>());
      final metadata = (result as VaultSuccess<VaultItemMetadata>).data;
      expect(metadata.id, 'item-1');
      expect(metadata.groupId, 'work');

      // Verify the stored item was mutated correctly before save
      expect(storedItem.groupId, 'work');
      verify(() => mockItemDS.saveItem(storedItem)).called(1);
    });

    test('returns VaultFailure(itemNotFound) when item does not exist',
        () async {
      when(() => mockItemDS.getItem('nonexistent'))
          .thenAnswer((_) async => null);

      final result = await repository.moveItemToGroup('nonexistent', 'work');

      expect(result, isA<VaultFailure<VaultItemMetadata>>());
      expect(
        (result as VaultFailure).type,
        VaultFailureType.itemNotFound,
      );

      verifyNever(() => mockItemDS.saveItem(any()));
    });

    test('returns VaultFailure(storageWriteError) when saveItem throws',
        () async {
      final storedItem = FakeStoredVaultItem(
        itemId: 'item-1',
      );

      when(() => mockItemDS.getItem('item-1'))
          .thenAnswer((_) async => storedItem);
      when(() => mockItemDS.saveItem(storedItem))
          .thenThrow(Exception('disk full'));

      final result = await repository.moveItemToGroup('item-1', 'work');

      expect(result, isA<VaultFailure<VaultItemMetadata>>());
      expect(
        (result as VaultFailure).type,
        VaultFailureType.storageWriteError,
      );
    });

    test('updates the updatedAt timestamp', () async {
      final originalDate = DateTime(2025);
      final storedItem = FakeStoredVaultItem(
        itemId: 'item-1',
        updatedAt: originalDate,
      );

      when(() => mockItemDS.getItem('item-1'))
          .thenAnswer((_) async => storedItem);
      when(() => mockItemDS.saveItem(storedItem)).thenAnswer((_) async {});

      await repository.moveItemToGroup('item-1', 'work');

      // updatedAt should have been changed from the original
      expect(storedItem.updatedAt, isNot(equals(originalDate)));
      expect(
        storedItem.updatedAt.isAfter(originalDate),
        isTrue,
        reason: 'updatedAt should be set to a time after the original',
      );
    });

    test('does not modify item fields other than groupId and updatedAt',
        () async {
      final storedItem = FakeStoredVaultItem(
        itemId: 'item-1',
        title: 'My Secret',
        isFavorite: true,
        contentVersion: 5,
      );

      when(() => mockItemDS.getItem('item-1'))
          .thenAnswer((_) async => storedItem);
      when(() => mockItemDS.saveItem(storedItem)).thenAnswer((_) async {});

      await repository.moveItemToGroup('item-1', 'finance');

      expect(storedItem.title, 'My Secret');
      expect(storedItem.type, VaultItemType.password);
      expect(storedItem.isFavorite, true);
      expect(storedItem.contentVersion, 5);
      expect(storedItem.groupId, 'finance');
    });
  });
}
