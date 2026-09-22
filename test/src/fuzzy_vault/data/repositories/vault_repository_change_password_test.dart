import 'dart:convert';

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _metadata = VaultMetadata(
  vaultId: 'vault-1',
  verificationToken: 'b2xk',
  createdAt: DateTime(2026),
  lastUnlockedAt: DateTime(2026, 2),
  autoLockMinutes: 5,
);

Map<String, dynamic> _metaJson(VaultMetadata metadata) => {
      'vaultId': metadata.vaultId,
      'verificationToken': metadata.verificationToken,
      'createdAt': metadata.createdAt.toIso8601String(),
      'lastUnlockedAt': metadata.lastUnlockedAt.toIso8601String(),
      'autoLockMinutes': metadata.autoLockMinutes,
      'customDirectoryPath': metadata.customDirectoryPath,
    };

void main() {
  late MockVaultItemLocalDataSource mockItemDS;
  late MockVaultGroupLocalDataSource mockGroupDS;
  late MockVaultFileDataSource mockFileDS;
  late MockVaultCryptoRepository mockCryptoRepo;
  late VaultRepository repository;

  setUpAll(() {
    registerFallbackValue(_metadata);
  });

  setUp(() {
    mockItemDS = MockVaultItemLocalDataSource();
    mockGroupDS = MockVaultGroupLocalDataSource();
    mockFileDS = MockVaultFileDataSource();
    mockCryptoRepo = MockVaultCryptoRepository();

    when(() => mockFileDS.readMeta())
        .thenAnswer((_) async => utf8.encode(jsonEncode(_metaJson(_metadata))));
    when(() => mockFileDS.writeMetaAtomic(any())).thenAnswer((_) async {});

    repository = VaultRepository(
      itemDataSource: mockItemDS,
      groupDataSource: mockGroupDS,
      fileDataSource: mockFileDS,
      cryptoRepository: mockCryptoRepo,
    );
  });

  group('changeMasterPassword', () {
    test('rewraps the metadata and writes it; no item is read or rewritten',
        () async {
      final rewrapped = _metadata.copyWith(verificationToken: 'bmV3');
      when(() => mockCryptoRepo.rewrap('old', 'new', any()))
          .thenAnswer((_) async => VaultSuccess(rewrapped));

      final result = await repository.changeMasterPassword('old', 'new');

      expect(result, isA<VaultSuccess<void>>());
      final written = verify(() => mockFileDS.writeMetaAtomic(captureAny()))
          .captured
          .single as List<int>;
      expect(
        jsonDecode(utf8.decode(written)),
        _metaJson(rewrapped),
        reason: 'only the wrapped blob changes; the json has no masterSalt',
      );
      verifyNever(() => mockItemDS.getAllItems());
      verifyNever(() => mockFileDS.readItem(any()));
      verifyNever(() => mockFileDS.writeItemAtomic(any(), any()));
    });

    test('a wrong current password changes nothing', () async {
      when(() => mockCryptoRepo.rewrap('wrong', 'new', any())).thenAnswer(
        (_) async =>
            const VaultFailure(VaultFailureType.incorrectMasterPassword),
      );

      final result = await repository.changeMasterPassword('wrong', 'new');

      expect(
        (result as VaultFailure).type,
        VaultFailureType.incorrectMasterPassword,
      );
      verifyNever(() => mockFileDS.writeMetaAtomic(any()));
    });

    test('no vault → vaultNotInitialized, the core is never called', () async {
      when(() => mockFileDS.readMeta()).thenAnswer((_) async => null);

      final result = await repository.changeMasterPassword('old', 'new');

      expect(
        (result as VaultFailure).type,
        VaultFailureType.vaultNotInitialized,
      );
      verifyNever(() => mockCryptoRepo.rewrap(any(), any(), any()));
    });
  });

  group('getMetadata', () {
    test('reads the wrapped blob as verificationToken', () async {
      final result = await repository.getMetadata();

      final metadata = (result as VaultSuccess<VaultMetadata>).data;
      expect(metadata.verificationToken, 'b2xk');
      expect(metadata.vaultId, 'vault-1');
    });
  });
}
