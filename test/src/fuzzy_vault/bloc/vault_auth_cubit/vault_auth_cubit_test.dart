import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockVaultCryptoRepository extends Mock implements VaultCryptoRepository {}

class MockVaultRepository extends Mock implements VaultRepository {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

class MockVaultKey extends Mock implements VaultKey {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _metadata = VaultMetadata(
  vaultId: 'vault-1',
  verificationToken: 'd3JhcHBlZA==',
  createdAt: DateTime(2026),
  lastUnlockedAt: DateTime(2026),
  autoLockMinutes: 0,
);

void main() {
  late MockVaultCryptoRepository mockCryptoRepo;
  late MockVaultRepository mockVaultRepo;
  late MockBiometricAuthRepository mockBiometricRepo;
  late MockVaultKey key;

  setUpAll(() {
    registerFallbackValue(_metadata);
    registerFallbackValue(BiometricScope.vault);
  });

  setUp(() {
    mockCryptoRepo = MockVaultCryptoRepository();
    mockVaultRepo = MockVaultRepository();
    mockBiometricRepo = MockBiometricAuthRepository();
    key = MockVaultKey();

    when(() => key.close()).thenAnswer((_) async {});
    when(() => key.dispose()).thenReturn(null);
    when(() => mockVaultRepo.getMetadata())
        .thenAnswer((_) async => VaultSuccess(_metadata));
    when(() => mockVaultRepo.saveMetadata(any()))
        .thenAnswer((_) async => const VaultSuccess(null));
  });

  VaultAuthCubit buildCubit() => VaultAuthCubit(
        cryptoRepository: mockCryptoRepo,
        vaultRepository: mockVaultRepo,
        biometricAuthRepository: mockBiometricRepo,
      );

  // -----------------------------------------------------------------------
  // createVault
  // -----------------------------------------------------------------------
  group('createVault', () {
    blocTest<VaultAuthCubit, VaultAuthState>(
      'initializes, saves the metadata, unlocks and carries the handle',
      setUp: () {
        when(() => mockCryptoRepo.initializeVault('pw'))
            .thenAnswer((_) async => VaultSuccess(_metadata));
        when(() => mockCryptoRepo.unlock('pw', _metadata))
            .thenAnswer((_) async => VaultSuccess(key));
      },
      build: buildCubit,
      act: (cubit) => cubit.createVault('pw'),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.authState, 'authState', VaultAuthEnum.unlocked)
            .having((s) => s.masterKey, 'masterKey', same(key)),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockCryptoRepo.initializeVault('pw'),
          () => mockVaultRepo.saveMetadata(_metadata),
          () => mockCryptoRepo.unlock('pw', _metadata),
        ]);
        verifyNever(() => key.close());
      },
    );

    blocTest<VaultAuthCubit, VaultAuthState>(
      'a weak password fails before anything is saved',
      setUp: () {
        when(() => mockCryptoRepo.initializeVault('weak')).thenAnswer(
          (_) async => const VaultFailure(VaultFailureType.weakPassword),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.createVault('weak'),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having(
              (s) => s.failureType,
              'failureType',
              VaultFailureType.weakPassword,
            )
            .having((s) => s.masterKey, 'masterKey', isNull),
      ],
      verify: (_) {
        verifyNever(() => mockVaultRepo.saveMetadata(any()));
        verifyNever(() => mockCryptoRepo.unlock(any(), any()));
      },
    );
  });

  // -----------------------------------------------------------------------
  // unlock
  // -----------------------------------------------------------------------
  group('unlock', () {
    blocTest<VaultAuthCubit, VaultAuthState>(
      'emits [unlocking, unlocked] with the handle from the repository',
      setUp: () {
        when(() => mockCryptoRepo.unlock('pw', _metadata))
            .thenAnswer((_) async => VaultSuccess(key));
      },
      build: buildCubit,
      act: (cubit) => cubit.unlock('pw'),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.loading)
            .having((s) => s.authState, 'authState', VaultAuthEnum.unlocking),
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.authState, 'authState', VaultAuthEnum.unlocked)
            .having((s) => s.masterKey, 'masterKey', same(key)),
      ],
      verify: (_) {
        verify(() => mockVaultRepo.saveMetadata(any())).called(1);
      },
    );

    blocTest<VaultAuthCubit, VaultAuthState>(
      'a wrong password stays locked with incorrectMasterPassword',
      setUp: () {
        when(() => mockCryptoRepo.unlock('nope', _metadata)).thenAnswer(
          (_) async =>
              const VaultFailure(VaultFailureType.incorrectMasterPassword),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.unlock('nope'),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.authState, 'authState', VaultAuthEnum.unlocking),
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.failed)
            .having((s) => s.authState, 'authState', VaultAuthEnum.locked)
            .having(
              (s) => s.failureType,
              'failureType',
              VaultFailureType.incorrectMasterPassword,
            )
            .having((s) => s.masterKey, 'masterKey', isNull),
      ],
      verify: (_) {
        verifyNever(() => mockVaultRepo.saveMetadata(any()));
      },
    );
  });

  // -----------------------------------------------------------------------
  // lock
  // -----------------------------------------------------------------------
  group('lock', () {
    blocTest<VaultAuthCubit, VaultAuthState>(
      'closes and disposes the handle, then emits locked without a key',
      setUp: () {
        when(() => mockCryptoRepo.unlock('pw', _metadata))
            .thenAnswer((_) async => VaultSuccess(key));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.unlock('pw');
        await cubit.lock();
      },
      skip: 2,
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.success)
            .having((s) => s.authState, 'authState', VaultAuthEnum.locked)
            .having((s) => s.masterKey, 'masterKey', isNull),
      ],
      verify: (_) {
        verifyInOrder([
          key.close,
          key.dispose,
        ]);
      },
    );

    blocTest<VaultAuthCubit, VaultAuthState>(
      'locking without a key touches no handle',
      build: buildCubit,
      act: (cubit) => cubit.lock(),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.authState, 'authState', VaultAuthEnum.locked)
            .having((s) => s.masterKey, 'masterKey', isNull),
      ],
      verify: (_) {
        verifyNever(() => key.close());
      },
    );
  });

  // -----------------------------------------------------------------------
  // enableBiometric
  // -----------------------------------------------------------------------
  group('enableBiometric', () {
    test('verifies by unlocking and drops that handle', () async {
      final verifyKey = MockVaultKey();
      when(verifyKey.close).thenAnswer((_) async {});
      when(verifyKey.dispose).thenReturn(null);
      when(() => mockCryptoRepo.unlock('pw', _metadata))
          .thenAnswer((_) async => VaultSuccess(verifyKey));
      when(() => mockBiometricRepo.enable(BiometricScope.vault, 'pw'))
          .thenAnswer((_) async {});

      final cubit = buildCubit();
      expect(await cubit.enableBiometric('pw'), isTrue);
      expect(cubit.state.biometricEnabled, isTrue);
      expect(cubit.state.masterKey, isNull);
      verifyInOrder([
        verifyKey.close,
        verifyKey.dispose,
        () => mockBiometricRepo.enable(BiometricScope.vault, 'pw'),
      ]);
      await cubit.close();
    });

    test('a wrong password enables nothing', () async {
      when(() => mockCryptoRepo.unlock('nope', _metadata)).thenAnswer(
        (_) async =>
            const VaultFailure(VaultFailureType.incorrectMasterPassword),
      );

      final cubit = buildCubit();
      expect(await cubit.enableBiometric('nope'), isFalse);
      verifyNever(() => mockBiometricRepo.enable(any(), any()));
      await cubit.close();
    });
  });
}
