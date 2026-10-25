import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockChatAuthRepository extends Mock implements ChatAuthRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

/// The master password's settings. A changed password must reach the
/// vault's "good" bar (security review 2026-10-22, item 6); the password
/// cannot be switched off; a new recovery key replaces the old one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const weak = 'a';
  const fair = 'abcdefgh';
  const good = 'Blue-Kettle-42';
  final recoveryWrap = Uint8List.fromList([1, 2, 3]);

  late MockChatAuthRepository chatAuthRepository;
  late MockFuzzyAuthStore store;
  late MockBiometricAuthRepository biometricRepository;

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(Uint8List(0));
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
          (_) async => CryptoCoreSuccess(
            CryptoCoreRecoveryKey(
              recoveryKey: 'AAAA-BBBB',
              recoveryWrap: recoveryWrap,
            ),
          ),
        );
        when(() => chatAuthRepository.saveRecoveryWrap(any()))
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
        verify(() => chatAuthRepository.saveRecoveryWrap(recoveryWrap))
            .called(1);
      },
    );

    blocTest<FuzzyUserAuthPreferencesCubit, FuzzyUserAuthPreferencesState>(
      'skipping keeps no recovery key',
      setUp: () {
        when(() => chatAuthRepository.newRecoveryKey(good)).thenAnswer(
          (_) async => CryptoCoreSuccess(
            CryptoCoreRecoveryKey(
              recoveryKey: 'AAAA-BBBB',
              recoveryWrap: recoveryWrap,
            ),
          ),
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
        verifyNever(() => chatAuthRepository.saveRecoveryWrap(any()));
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
