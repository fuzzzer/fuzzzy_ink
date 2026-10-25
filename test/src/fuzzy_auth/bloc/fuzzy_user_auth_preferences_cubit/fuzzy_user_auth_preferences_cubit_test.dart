import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockChatAuthRepository extends Mock implements ChatAuthRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

class MockVaultRepository extends Mock implements VaultRepository {}

class MockVaultCryptoRepository extends Mock implements VaultCryptoRepository {}

/// The master password's settings. A changed password must reach the
/// vault's "good" bar (security review 2026-10-22, item 6); the password
/// cannot be switched off; a new recovery key replaces the old one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weak = 'a';
  const fair = 'abcdefgh';
  const good = 'Blue-Kettle-42';
  final recoveryWrap = Uint8List.fromList([1, 2, 3]);
  final recoveryLock = Uint8List.fromList([4, 5, 6]);
  final pending = PendingRecoveryKey(
    recoveryKey: 'AAAA-BBBB',
    recoveryWrap: recoveryWrap,
    recoveryLock: recoveryLock,
  );

  late MockChatAuthRepository chatAuthRepository;
  late MockFuzzyAuthStore store;
  late MockBiometricAuthRepository biometricRepository;

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(pending);
  });

  setUp(() {
    chatAuthRepository = MockChatAuthRepository();
    store = MockFuzzyAuthStore();
    biometricRepository = MockBiometricAuthRepository();
    when(() => chatAuthRepository.unlock(any()))
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(
      () => chatAuthRepository.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => store.setBiometricEnabled(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
    when(() => biometricRepository.disable(any())).thenAnswer((_) async {});
  });

  FuzzyUserAuthPreferencesCubit buildCubit() => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: chatAuthRepository,
        fuzzyAuthStore: store,
        biometricAuthRepository: biometricRepository,
        passwordStrengthService: PasswordStrengthService(),
      );

  test('"good" and "strong" pass; "weak" and "fair" do not', () {
    final cubit = buildCubit();
    expect(cubit.isStrongEnough(''), isFalse);
    expect(cubit.isStrongEnough(weak), isFalse);
    expect(cubit.isStrongEnough(fair), isFalse);
    expect(cubit.isStrongEnough('password123'), isFalse);
    expect(cubit.isStrongEnough(good), isTrue);
    cubit.close();
  });

  for (final password in [weak, fair]) {
    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'changing to "$password" fails before the old one is even checked',
      build: buildCubit,
      act: (cubit) =>
          cubit.changePassword(oldPassword: 'x', newPassword: password),
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having(
              (s) => s.activationFailure?.message,
              'message',
              FuzzzyInkLocalizationsEn().chatAuthPasswordTooWeak,
            ),
      ],
      verify: (_) {
        verifyNever(
          () => chatAuthRepository.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      },
    );
  }

  blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
    'changing from a weak old password to a good one re-wraps the master key '
    'and drops the biometric copy of the old password',
    build: buildCubit,
    act: (cubit) => cubit.changePassword(oldPassword: weak, newPassword: good),
    expect: () => [
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.loading),
      isA<FuzzyUserAuthPreferencesState>()
          .having((s) => s.activationStatus, 'status', StateStatus.success),
    ],
    verify: (_) {
      verify(
        () => chatAuthRepository.changePassword(
          oldPassword: weak,
          newPassword: good,
        ),
      ).called(1);
      verify(() => biometricRepository.disable(BiometricScope.chat)).called(1);
      verify(() => store.setBiometricEnabled(enabled: false)).called(1);
    },
  );

  blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
    'a wrong current password says so and changes nothing',
    setUp: () {
      when(
        () => chatAuthRepository.changePassword(
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer(
        (_) async =>
            const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
      );
    },
    build: buildCubit,
    act: (cubit) =>
        cubit.changePassword(oldPassword: 'nope', newPassword: good),
    skip: 1,
    expect: () => [
      isA<FuzzyUserAuthPreferencesState>().having(
        (s) => s.activationFailure?.message,
        'message',
        FuzzzyInkLocalizationsEn().chatAuthIncorrectPassword,
      ),
    ],
    verify: (_) => verifyNever(() => biometricRepository.disable(any())),
  );

  group('recovery key', () {
    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'a new key is shown, and kept only once it is confirmed saved',
      setUp: () {
        when(() => chatAuthRepository.newRecoveryKey(good)).thenAnswer(
          (_) async => CryptoCoreSuccess(pending),
        );
        when(() => chatAuthRepository.saveRecovery(any()))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.newRecoveryKey(good);
        await cubit.confirmRecoveryKeySaved();
      },
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.loading),
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.pendingRecoveryKey, 'key', 'AAAA-BBBB')
            .having((s) => s.hasRecoveryKey, 'hasRecoveryKey', isFalse),
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.loading),
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.pendingRecoveryKey, 'key', isNull)
            .having((s) => s.hasRecoveryKey, 'hasRecoveryKey', isTrue),
      ],
      verify: (_) {
        verify(() => chatAuthRepository.saveRecovery(pending)).called(1);
      },
    );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'skipping keeps no recovery key',
      setUp: () {
        when(() => chatAuthRepository.newRecoveryKey(good)).thenAnswer(
          (_) async => CryptoCoreSuccess(pending),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.newRecoveryKey(good);
        cubit.skipRecoveryKey();
      },
      skip: 2,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.pendingRecoveryKey, 'key', isNull)
            .having((s) => s.hasRecoveryKey, 'hasRecoveryKey', isFalse),
      ],
      verify: (_) {
        verifyNever(() => chatAuthRepository.saveRecovery(any()));
      },
    );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'a wrong master password makes no new key',
      setUp: () {
        when(() => chatAuthRepository.newRecoveryKey(any())).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.newRecoveryKey('nope'),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having((s) => s.pendingRecoveryKey, 'key', isNull),
      ],
    );
  });

  group('recovery key and a vault with its own password', () {
    late MockVaultRepository vaultRepository;
    late MockVaultCryptoRepository vaultCrypto;
    final metadata = VaultMetadata(
      vaultId: 'v',
      verificationToken: 'AA==',
      createdAt: DateTime(2026),
      lastUnlockedAt: DateTime(2026),
    );
    final copy = Uint8List.fromList([0x11]);

    setUpAll(() => registerFallbackValue(metadata));

    setUp(() {
      vaultRepository = MockVaultRepository();
      vaultCrypto = MockVaultCryptoRepository();
      when(() => vaultRepository.cryptoRepository).thenReturn(vaultCrypto);
      when(() => vaultRepository.getMetadata())
          .thenAnswer((_) async => VaultSuccess(metadata));
      when(() => vaultCrypto.usesOwnPassword(any()))
          .thenReturn(const VaultSuccess(true));
      // The repository runs the vault's seal with the new key's lock.
      when(
        () => chatAuthRepository.newRecoveryKey(
          any(),
          sealVault: any(named: 'sealVault'),
        ),
      ).thenAnswer((invocation) async {
        final sealVault = invocation.namedArguments[#sealVault]
            as Future<CryptoCoreResponse<Uint8List>> Function(Uint8List)?;
        if (sealVault == null) return CryptoCoreSuccess(pending);
        final sealRes = await sealVault(recoveryLock);
        if (sealRes is CryptoCoreFailure<Uint8List>) {
          return CryptoCoreFailure(sealRes.type);
        }
        return CryptoCoreSuccess(
          PendingRecoveryKey(
            recoveryKey: pending.recoveryKey,
            recoveryWrap: recoveryWrap,
            recoveryLock: recoveryLock,
            vaultRecovery: (sealRes as CryptoCoreSuccess<Uint8List>).data,
          ),
        );
      });
    });

    FuzzyUserAuthPreferencesCubit buildWithVault() =>
        FuzzyUserAuthPreferencesCubit(
          chatAuthRepository: chatAuthRepository,
          fuzzyAuthStore: store,
          biometricAuthRepository: biometricRepository,
          passwordStrengthService: PasswordStrengthService(),
          vaultRepository: vaultRepository,
        );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'without the vault password no new key is made',
      build: buildWithVault,
      act: (cubit) => cubit.newRecoveryKey(good),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having((s) => s.pendingRecoveryKey, 'key', isNull),
      ],
      verify: (_) => verifyNever(
        () => chatAuthRepository.newRecoveryKey(
          any(),
          sealVault: any(named: 'sealVault'),
        ),
      ),
    );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'with the vault password the vault is sealed to the new key',
      setUp: () {
        when(
          () => vaultCrypto.sealForRecovery(
            vaultPassword: 'vault-pw',
            metadata: metadata,
            recoveryLock: recoveryLock,
          ),
        ).thenAnswer((_) async => CryptoCoreSuccess(copy));
      },
      build: buildWithVault,
      act: (cubit) => cubit.newRecoveryKey(good, vaultPassword: 'vault-pw'),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.success)
            .having(
              (s) => s.pendingRecovery?.vaultRecovery,
              'vault copy',
              copy,
            ),
      ],
    );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'a wrong vault password is reported as the vault password',
      setUp: () {
        when(
          () => vaultCrypto.sealForRecovery(
            vaultPassword: any(named: 'vaultPassword'),
            metadata: any(named: 'metadata'),
            recoveryLock: any(named: 'recoveryLock'),
          ),
        ).thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
      },
      build: buildWithVault,
      act: (cubit) => cubit.newRecoveryKey(good, vaultPassword: 'nope'),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having(
              (s) => s.activationFailure?.message,
              'message',
              FuzzzyInkLocalizationsEn().vaultIncorrectPassword,
            ),
      ],
    );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'a vault under the master key needs no vault password',
      setUp: () {
        when(() => vaultCrypto.usesOwnPassword(any()))
            .thenReturn(const VaultSuccess(false));
      },
      build: buildWithVault,
      act: (cubit) => cubit.newRecoveryKey(good),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.success)
            .having((s) => s.pendingRecovery?.vaultRecovery, 'copy', isNull),
      ],
    );
  });

  for (final (result, message) in [
    (
      BiometricEnableResult.notStrongEnough,
      FuzzzyInkLocalizationsEn().biometricNotStrongEnough,
    ),
    (
      BiometricEnableResult.cancelled,
      FuzzzyInkLocalizationsEn().biometricNotTurnedOn,
    ),
    (
      BiometricEnableResult.failed,
      FuzzzyInkLocalizationsEn().biometricNotTurnedOn,
    ),
  ]) {
    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'turning biometrics on that ends "${result.name}" shows a plain message '
      'and leaves them off',
      setUp: () {
        when(() => biometricRepository.enable(BiometricScope.chat, good))
            .thenAnswer((_) async => result);
      },
      build: buildCubit,
      act: (cubit) => cubit.enableBiometric(good),
      skip: 1,
      expect: () => [
        isA<FuzzyUserAuthPreferencesState>()
            .having((s) => s.activationStatus, 'status', StateStatus.failed)
            .having((s) => s.activationFailure?.message, 'message', message),
      ],
      verify: (_) {
        verifyNever(
          () => store.setBiometricEnabled(enabled: any(named: 'enabled')),
        );
      },
    );
  }
}
