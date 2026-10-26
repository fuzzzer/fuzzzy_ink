import 'dart:convert';
import 'dart:typed_data';

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

class MockAppLockThrottleRepository extends Mock
    implements AppLockThrottleRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _metadata = VaultMetadata(
  vaultId: 'vault-1',
  verificationToken: 'd3JhcHBlZA==',
  createdAt: DateTime(2026),
  lastUnlockedAt: DateTime(2026),
);

void main() {
  late MockVaultCryptoRepository mockCryptoRepo;
  late MockVaultRepository mockVaultRepo;
  late MockBiometricAuthRepository mockBiometricRepo;
  late MockVaultKey key;
  late MockAppLockThrottleRepository mockThrottle;
  var throttle = AppLockThrottleData.none;

  setUpAll(() {
    registerFallbackValue(_metadata);
    registerFallbackValue(BiometricScope.vault);
    registerFallbackValue(AppLockThrottleData.none);
  });

  setUp(() {
    mockCryptoRepo = MockVaultCryptoRepository();
    mockVaultRepo = MockVaultRepository();
    mockBiometricRepo = MockBiometricAuthRepository();
    key = MockVaultKey();
    mockThrottle = MockAppLockThrottleRepository();
    throttle = AppLockThrottleData.none;
    when(() => mockThrottle.read()).thenAnswer((_) async => throttle);
    when(() => mockThrottle.save(any())).thenAnswer((invocation) async {
      throttle = invocation.positionalArguments.first as AppLockThrottleData;
    });
    when(() => mockThrottle.clear()).thenAnswer((_) async {
      throttle = AppLockThrottleData.none;
    });

    when(() => key.close()).thenAnswer((_) async {});
    when(() => key.dispose()).thenReturn(null);
    when(() => mockVaultRepo.getMetadata())
        .thenAnswer((_) async => VaultSuccess(_metadata));
    when(() => mockVaultRepo.saveMetadata(any()))
        .thenAnswer((_) async => const VaultSuccess(null));
    when(() => mockCryptoRepo.hasRecoveryKey()).thenAnswer((_) async => true);
    when(() => mockCryptoRepo.hasRecoveryCopy()).thenAnswer((_) async => true);
    when(() => mockCryptoRepo.dropRecoveryCopy())
        .thenAnswer((_) async => const VaultSuccess(null));
  });

  VaultAuthCubit buildCubit() => VaultAuthCubit(
        cryptoRepository: mockCryptoRepo,
        vaultRepository: mockVaultRepo,
        biometricAuthRepository: mockBiometricRepo,
        appLockThrottleRepository: mockThrottle,
      );

  // -----------------------------------------------------------------------
  // checkVaultStatus: an unfinished move never offers a new vault
  // -----------------------------------------------------------------------
  group('checkVaultStatus', () {
    blocTest<VaultAuthCubit, VaultAuthState>(
      'an unfinished move says so instead of offering to create a vault',
      setUp: () {
        when(() => mockVaultRepo.getMetadata()).thenAnswer(
          (_) async => const VaultFailure(VaultFailureType.vaultMoveUnfinished),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.checkVaultStatus(),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<VaultAuthState>()
            .having(
              (s) => s.authState,
              'authState',
              VaultAuthEnum.moveUnfinished,
            )
            .having((s) => s.biometricEnabled, 'biometricEnabled', isFalse),
      ],
      verify: (_) {
        verifyNever(() => mockBiometricRepo.isEnabled(any()));
      },
    );

    blocTest<VaultAuthCubit, VaultAuthState>(
      'no vault anywhere still offers to create one',
      setUp: () {
        when(() => mockVaultRepo.getMetadata()).thenAnswer(
          (_) async => const VaultFailure(VaultFailureType.vaultNotInitialized),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.checkVaultStatus(),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.status, 'status', StateStatus.loading),
        isA<VaultAuthState>()
            .having((s) => s.authState, 'authState', VaultAuthEnum.noVault),
      ],
    );
  });

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
      seed: () => const VaultAuthState(authState: VaultAuthEnum.locked),
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
  // The whole app locks the vault too; a vault that does not exist stays so
  // -----------------------------------------------------------------------
  group('lock without a vault', () {
    blocTest<VaultAuthCubit, VaultAuthState>(
      'keeps noVault, so the create page still shows after an app lock',
      build: buildCubit,
      seed: () => const VaultAuthState(authState: VaultAuthEnum.noVault),
      act: (cubit) => cubit.lock(),
      expect: () => [
        isA<VaultAuthState>()
            .having((s) => s.authState, 'authState', VaultAuthEnum.noVault),
      ],
    );
  });

  // -----------------------------------------------------------------------
  // The master password opens the vault by default; a vault under the master
  // key shares the app lock's wrong-password wait
  // -----------------------------------------------------------------------
  group('master password', () {
    test('the vault auto-lock is a constant, not a vault.meta value', () {
      expect(VaultAuthCubit.autoLockAfter, const Duration(minutes: 5));
    });

    test('a wrong master password counts toward the app lock wait', () async {
      when(() => mockCryptoRepo.unlock('nope', _metadata)).thenAnswer(
        (_) async =>
            const VaultFailure(VaultFailureType.incorrectMasterPassword),
      );
      final cubit = buildCubit();
      await cubit.unlock('nope');
      expect(throttle.failedAttempts, 1);
      await cubit.close();
    });

    test('a running wait refuses the attempt without trying it', () async {
      throttle = AppLockThrottleData(
        failedAttempts: 9,
        lockedUntil: DateTime.now().add(const Duration(minutes: 5)),
      );
      final cubit = buildCubit();
      await cubit.unlock('pw');
      expect(cubit.state.failureType, VaultFailureType.tooManyAttempts);
      verifyNever(() => mockCryptoRepo.unlock(any(), any()));
      await cubit.close();
    });

    test('the right master password clears the count', () async {
      throttle = const AppLockThrottleData(failedAttempts: 2);
      when(() => mockCryptoRepo.unlock('pw', _metadata))
          .thenAnswer((_) async => VaultSuccess(key));
      final cubit = buildCubit();
      await cubit.unlock('pw');
      expect(cubit.state.authState, VaultAuthEnum.unlocked);
      expect(throttle.failedAttempts, 0);
      await cubit.close();
    });

    test('a first open with a wrong master password counts too', () async {
      when(() => mockCryptoRepo.initializeVault('nope')).thenAnswer(
        (_) async =>
            const VaultFailure(VaultFailureType.incorrectMasterPassword),
      );
      final cubit = buildCubit();
      await cubit.createVault('nope');
      expect(throttle.failedAttempts, 1);
      expect(
        cubit.state.failureType,
        VaultFailureType.incorrectMasterPassword,
      );
      await cubit.close();
    });

    test('a running wait refuses a first open without trying it', () async {
      throttle = AppLockThrottleData(
        failedAttempts: 5,
        lockedUntil: DateTime.now().add(const Duration(seconds: 30)),
      );
      final cubit = buildCubit();
      await cubit.createVault('pw');
      expect(cubit.state.failureType, VaultFailureType.tooManyAttempts);
      verifyNever(() => mockCryptoRepo.initializeVault(any()));
      await cubit.close();
    });

    test('the wait left is read from the shared count', () async {
      final now = DateTime(2026, 10, 26, 12);
      throttle = AppLockThrottleData(
        failedAttempts: 5,
        lockedUntil: now.add(const Duration(seconds: 30)),
      );
      final cubit = VaultAuthCubit(
        cryptoRepository: mockCryptoRepo,
        vaultRepository: mockVaultRepo,
        biometricAuthRepository: mockBiometricRepo,
        appLockThrottleRepository: mockThrottle,
        now: () => now.add(const Duration(seconds: 12)),
      );
      expect(await cubit.lockoutRemaining(), const Duration(seconds: 18));
      cubit.emit(const VaultAuthState(usesOwnPassword: true));
      expect(await cubit.lockoutRemaining(), Duration.zero);
      await cubit.close();
    });

    test('a vault with its own password is outside the app lock count',
        () async {
      when(() => mockCryptoRepo.unlock('nope', _metadata)).thenAnswer(
        (_) async =>
            const VaultFailure(VaultFailureType.incorrectMasterPassword),
      );
      final cubit = buildCubit()
        ..emit(const VaultAuthState(usesOwnPassword: true));
      await cubit.unlock('nope');
      verifyNever(() => mockThrottle.save(any()));
      await cubit.close();
    });

    test(
        'switching to an own password moves the vault to the new key, ends '
        'the old recovery key, locks the vault and hands back the new one '
        '(security review 2026-10-26)', () async {
      final previous = MockVaultKey();
      final next = MockVaultKey();
      for (final k in [previous, next]) {
        when(k.close).thenAnswer((_) async {});
        when(k.dispose).thenReturn(null);
      }
      final changed = CryptoCoreVaultOwnPassword(
        previous: previous,
        key: next,
        wrapped: Uint8List.fromList([1, 2, 3]),
        recovery: CryptoCoreRecoveryKey(
          recoveryKey: 'AAAA-BBBB',
          recoveryWrap: Uint8List.fromList([4]),
          recoveryLock: Uint8List.fromList([5]),
        ),
        vaultRecovery: Uint8List.fromList([6]),
      );
      when(
        () => mockCryptoRepo.useOwnPassword(
          masterPassword: 'master',
          newPassword: 'Vault-Only-9',
          metadata: _metadata,
        ),
      ).thenAnswer((_) async => VaultSuccess(changed));
      VaultMetadata? moved;
      when(
        () => mockVaultRepo.rekey(
          previous: previous,
          key: next,
          metadata: any(named: 'metadata'),
          beforeCommit: any(named: 'beforeCommit'),
        ),
      ).thenAnswer((invocation) async {
        moved = invocation.namedArguments[#metadata] as VaultMetadata;
        final beforeCommit = invocation.namedArguments[#beforeCommit]
            as Future<VaultFailureType?> Function()?;
        expect(await beforeCommit!(), isNull);
        return const VaultSuccess(null);
      });
      when(() => mockCryptoRepo.endRecoveryKey())
          .thenAnswer((_) async => const VaultSuccess(null));
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});

      final cubit = buildCubit()
        ..emit(
          VaultAuthState(authState: VaultAuthEnum.unlocked, masterKey: key),
        );
      final result = await cubit.useOwnPassword(
        masterPassword: 'master',
        newPassword: 'Vault-Only-9',
      );

      expect(result.failure, isNull);
      expect(result.recovery?.recoveryKey, 'AAAA-BBBB');
      expect(result.recovery?.vaultRecovery, [6]);
      expect(moved?.verificationToken, base64Encode([1, 2, 3]));
      expect(moved?.vaultId, _metadata.vaultId);
      expect(cubit.state.usesOwnPassword, isTrue);
      expect(cubit.state.authState, VaultAuthEnum.locked);
      expect(cubit.state.recoverable, isFalse, reason: 'until it is kept');
      verify(key.close).called(1);
      verify(previous.close).called(1);
      verify(next.close).called(1);
      verify(() => mockCryptoRepo.dropRecoveryCopy()).called(1);
      verify(() => mockCryptoRepo.endRecoveryKey()).called(1);
      verify(() => mockBiometricRepo.disable(BiometricScope.vault)).called(1);
      verifyNever(() => mockVaultRepo.saveMetadata(any()));

      final pending = result.recovery!;
      when(() => mockCryptoRepo.keepRecoveryKey(pending))
          .thenAnswer((_) async => const VaultSuccess(null));
      expect(await cubit.keepRecoveryKey(pending), isNull);
      expect(cubit.state.recoverable, isTrue);
      await cubit.close();
    });

    test('a failed move keeps the old vault and shows no recovery key',
        () async {
      final previous = MockVaultKey();
      final next = MockVaultKey();
      for (final k in [previous, next]) {
        when(k.close).thenAnswer((_) async {});
        when(k.dispose).thenReturn(null);
      }
      when(
        () => mockCryptoRepo.useOwnPassword(
          masterPassword: 'master',
          newPassword: 'Vault-Only-9',
          metadata: _metadata,
        ),
      ).thenAnswer(
        (_) async => VaultSuccess(
          CryptoCoreVaultOwnPassword(
            previous: previous,
            key: next,
            wrapped: Uint8List(1),
            recovery: CryptoCoreRecoveryKey(
              recoveryKey: 'K',
              recoveryWrap: Uint8List(1),
              recoveryLock: Uint8List(1),
            ),
            vaultRecovery: Uint8List(1),
          ),
        ),
      );
      when(
        () => mockVaultRepo.rekey(
          previous: previous,
          key: next,
          metadata: any(named: 'metadata'),
          beforeCommit: any(named: 'beforeCommit'),
        ),
      ).thenAnswer(
        (_) async => const VaultFailure(VaultFailureType.storageWriteError),
      );
      final cubit = buildCubit();
      final result = await cubit.useOwnPassword(
        masterPassword: 'master',
        newPassword: 'Vault-Only-9',
      );
      expect(result.failure, VaultFailureType.storageWriteError);
      expect(result.recovery, isNull);
      expect(cubit.state.usesOwnPassword, isFalse);
      verify(previous.close).called(1);
      verify(next.close).called(1);
      verifyNever(() => mockCryptoRepo.endRecoveryKey());
      await cubit.close();
    });

    test('switching back to the master password drops the recovery copy',
        () async {
      when(
        () => mockCryptoRepo.useMasterPassword(
          vaultPassword: 'Vault-Only-9',
          masterPassword: 'master',
          metadata: _metadata,
        ),
      ).thenAnswer((_) async => VaultSuccess(_metadata));
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});

      final cubit = buildCubit()
        ..emit(const VaultAuthState(usesOwnPassword: true, recoverable: true));
      expect(
        await cubit.useMasterPassword(
          vaultPassword: 'Vault-Only-9',
          masterPassword: 'master',
        ),
        isNull,
      );
      expect(cubit.state.usesOwnPassword, isFalse);
      expect(cubit.state.recoverable, isFalse);
      verify(() => mockCryptoRepo.dropRecoveryCopy()).called(1);
      await cubit.close();
    });

    test('a wrong master password changes nothing', () async {
      when(
        () => mockCryptoRepo.useOwnPassword(
          masterPassword: 'nope',
          newPassword: 'Vault-Only-9',
          metadata: _metadata,
        ),
      ).thenAnswer(
        (_) async =>
            const VaultFailure(VaultFailureType.incorrectMasterPassword),
      );
      final cubit = buildCubit();
      expect(
        (await cubit.useOwnPassword(
          masterPassword: 'nope',
          newPassword: 'Vault-Only-9',
        ))
            .failure,
        VaultFailureType.incorrectMasterPassword,
      );
      verifyNever(() => mockVaultRepo.saveMetadata(any()));
      expect(cubit.state.usesOwnPassword, isFalse);
      await cubit.close();
    });

    test(
        'a master password change drops the vault biometric copy only when '
        'the master password opens the vault', () async {
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});
      final masterVault = buildCubit();
      await masterVault.onMasterPasswordChanged();
      verify(() => mockBiometricRepo.disable(BiometricScope.vault)).called(1);

      final ownVault = buildCubit()
        ..emit(const VaultAuthState(usesOwnPassword: true));
      await ownVault.onMasterPasswordChanged();
      verifyNever(() => mockBiometricRepo.disable(any()));
      await masterVault.close();
      await ownVault.close();
    });
  });

  // -----------------------------------------------------------------------
  // the recovery key opens a vault with its own password
  // -----------------------------------------------------------------------
  group('recover', () {
    final renewed = VaultMetadata(
      vaultId: 'vault-1',
      verificationToken: 'bmV3',
      createdAt: DateTime(2026),
      lastUnlockedAt: DateTime(2026),
    );

    test(
        'with a new password: the vault opens, keeps its own password and '
        'its recovery copy; the biometric copy goes', () async {
      when(
        () => mockCryptoRepo.recover(
          recoveryKey: 'KEY',
          newPassword: 'Fresh-Vault-9',
          metadata: _metadata,
        ),
      ).thenAnswer(
        (_) async => VaultSuccess((key: key, metadata: renewed)),
      );
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});

      final cubit = buildCubit()
        ..emit(
          const VaultAuthState(
            authState: VaultAuthEnum.locked,
            usesOwnPassword: true,
            recoverable: true,
            biometricEnabled: true,
          ),
        );
      expect(
        await cubit.recover(recoveryKey: 'KEY', newPassword: 'Fresh-Vault-9'),
        isNull,
      );
      expect(cubit.state.authState, VaultAuthEnum.unlocked);
      expect(cubit.state.masterKey, same(key));
      expect(cubit.state.usesOwnPassword, isTrue);
      expect(cubit.state.recoverable, isTrue);
      expect(cubit.state.biometricEnabled, isFalse);
      final saved = verify(() => mockVaultRepo.saveMetadata(captureAny()))
          .captured
          .single as VaultMetadata;
      expect(saved.verificationToken, 'bmV3');
      verify(() => mockBiometricRepo.disable(BiometricScope.vault)).called(1);
      verifyNever(() => mockCryptoRepo.dropRecoveryCopy());
      await cubit.close();
    });

    test('without a new password: the master password opens it from now on',
        () async {
      when(
        () => mockCryptoRepo.recover(
          recoveryKey: 'KEY',
          metadata: _metadata,
        ),
      ).thenAnswer(
        (_) async => VaultSuccess((key: key, metadata: renewed)),
      );
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});

      final cubit = buildCubit()
        ..emit(
          const VaultAuthState(
            authState: VaultAuthEnum.locked,
            usesOwnPassword: true,
            recoverable: true,
          ),
        );
      expect(await cubit.recover(recoveryKey: 'KEY'), isNull);
      expect(cubit.state.authState, VaultAuthEnum.unlocked);
      expect(cubit.state.usesOwnPassword, isFalse);
      expect(cubit.state.recoverable, isFalse);
      verify(() => mockCryptoRepo.dropRecoveryCopy()).called(1);
      await cubit.close();
    });

    test('a wrong key changes nothing and stays locked', () async {
      when(
        () => mockCryptoRepo.recover(
          recoveryKey: any(named: 'recoveryKey'),
          newPassword: any(named: 'newPassword'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer(
        (_) async => const VaultFailure(VaultFailureType.recoveryKeyWrong),
      );
      final cubit = buildCubit()
        ..emit(
          const VaultAuthState(
            authState: VaultAuthEnum.locked,
            usesOwnPassword: true,
            recoverable: true,
          ),
        );
      expect(
        await cubit.recover(recoveryKey: 'OTHER', newPassword: 'Fresh-Vault-9'),
        VaultFailureType.recoveryKeyWrong,
      );
      expect(cubit.state.authState, VaultAuthEnum.locked);
      verifyNever(() => mockVaultRepo.saveMetadata(any()));
      await cubit.close();
    });

    test('refreshRecovery follows a new or skipped recovery key', () async {
      final cubit = buildCubit()
        ..emit(const VaultAuthState(usesOwnPassword: true));
      await cubit.refreshRecovery();
      expect(cubit.state.recoveryKeyKept, isTrue);
      expect(cubit.state.recoverable, isTrue);

      when(() => mockCryptoRepo.hasRecoveryKey())
          .thenAnswer((_) async => false);
      when(() => mockCryptoRepo.hasRecoveryCopy())
          .thenAnswer((_) async => false);
      await cubit.refreshRecovery();
      expect(cubit.state.recoveryKeyKept, isFalse);
      expect(cubit.state.recoverable, isFalse);
      await cubit.close();
    });
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
          .thenAnswer((_) async => BiometricEnableResult.enabled);

      final cubit = buildCubit();
      expect(
        await cubit.enableBiometric('pw'),
        BiometricEnableResult.enabled,
      );
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
      expect(
        await cubit.enableBiometric('nope'),
        BiometricEnableResult.wrongPassword,
      );
      verifyNever(() => mockBiometricRepo.enable(any(), any()));
      await cubit.close();
    });
  });

  // -----------------------------------------------------------------------
  // Biometrics: a cancel keeps the setting; weak biometrics enable nothing
  // (security review 2026-10-22, item 2 follow-up)
  // -----------------------------------------------------------------------
  group('biometric outcomes', () {
    setUp(() {
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});
    });

    test('a cancelled prompt keeps vault biometrics on', () async {
      when(() => mockBiometricRepo.readPassword(BiometricScope.vault))
          .thenAnswer((_) async => const BiometricNotRead());
      final cubit = buildCubit()
        ..emit(const VaultAuthState().copyWith(biometricEnabled: true));

      await cubit.unlockWithBiometrics();

      expect(cubit.state.authState, VaultAuthEnum.locked);
      expect(cubit.state.biometricEnabled, isTrue);
      expect(cubit.state.biometricInvalidated, isFalse);
      verifyNever(() => mockBiometricRepo.disable(any()));
      await cubit.close();
    });

    test('a copy that is gone turns vault biometrics off', () async {
      when(() => mockBiometricRepo.readPassword(BiometricScope.vault))
          .thenAnswer((_) async => const BiometricCopyGone());
      final cubit = buildCubit()
        ..emit(const VaultAuthState().copyWith(biometricEnabled: true));

      await cubit.unlockWithBiometrics();

      expect(cubit.state.biometricEnabled, isFalse);
      expect(cubit.state.biometricInvalidated, isTrue);
      verify(() => mockBiometricRepo.disable(BiometricScope.vault)).called(1);
      await cubit.close();
    });

    test('weak biometrics: the result says so and nothing is enabled',
        () async {
      final verifyKey = MockVaultKey();
      when(verifyKey.close).thenAnswer((_) async {});
      when(verifyKey.dispose).thenReturn(null);
      when(() => mockCryptoRepo.unlock('pw', _metadata))
          .thenAnswer((_) async => VaultSuccess(verifyKey));
      when(() => mockBiometricRepo.enable(BiometricScope.vault, 'pw'))
          .thenAnswer((_) async => BiometricEnableResult.notStrongEnough);

      final cubit = buildCubit();
      expect(
        await cubit.enableBiometric('pw'),
        BiometricEnableResult.notStrongEnough,
      );
      expect(cubit.state.biometricEnabled, isFalse);
      await cubit.close();
    });
  });
}
