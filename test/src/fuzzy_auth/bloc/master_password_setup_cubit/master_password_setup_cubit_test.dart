import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockChatAuthRepository extends Mock implements ChatAuthRepository {}

class MockAppResetRepository extends Mock implements AppResetRepository {}

class MockFuzzyAuthStore extends Mock implements FuzzyAuthStore {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

/// The first run's order: password, recovery key, the fingerprint step
/// where strong biometrics exist, "You're ready"; the app opens only at the
/// end, with the fingerprint shortcut on if it was turned on.
void main() {
  late MockChatAuthRepository chatAuth;
  late MockAppResetRepository reset;
  late MockFuzzyAuthStore store;
  late MockBiometricAuthRepository biometrics;
  const strong = 'quiet lantern river 58!';

  final pending = CryptoCoreMasterKeySetup(
    passwordWrap: Uint8List(1),
    storeWrap: Uint8List(1),
    recoveryWrap: Uint8List(1),
    recoveryLock: Uint8List(1),
    recoveryKey: 'AAAA-BBBB',
  );

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(pending);
    registerFallbackValue(
      PendingRecoveryKey(
        recoveryKey: 'k',
        recoveryWrap: Uint8List(0),
        recoveryLock: Uint8List(0),
      ),
    );
  });

  setUp(() {
    chatAuth = MockChatAuthRepository();
    reset = MockAppResetRepository();
    store = MockFuzzyAuthStore();
    biometrics = MockBiometricAuthRepository();
    when(() => reset.eraseEverything())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => chatAuth.prepareSetUp(any()))
        .thenAnswer((_) async => CryptoCoreSuccess(pending));
    when(
      () => chatAuth.completeSetUp(
        any(),
        keepRecovery: any(named: 'keepRecovery'),
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => store.onSetUpComplete()).thenReturn(null);
    when(() => store.setBiometricEnabled(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  MasterPasswordSetupCubit build({
    bool canUseBiometrics = true,
    PreferencesService? preferences,
  }) {
    when(() => biometrics.canUseBiometrics())
        .thenAnswer((_) async => canUseBiometrics);
    return MasterPasswordSetupCubit(
      chatAuthRepository: chatAuth,
      appResetRepository: reset,
      fuzzyAuthStore: store,
      passwordStrengthService: PasswordStrengthService(),
      biometricAuthRepository: biometrics,
      preferencesService: preferences,
    );
  }

  test('password, key, fingerprint, ready; the app opens with it on', () async {
    when(() => biometrics.enable(BiometricScope.chat, strong))
        .thenAnswer((_) async => BiometricEnableResult.enabled);
    final cubit = build();
    await cubit.checkQuickUnlock();
    expect(cubit.state.totalSteps, 3);

    await cubit.create(strong);
    expect(cubit.state.step, MasterPasswordSetupStep.recoveryKey);
    expect(cubit.state.recoveryKey, 'AAAA-BBBB');
    verifyNever(
      () => chatAuth.completeSetUp(
        any(),
        keepRecovery: any(named: 'keepRecovery'),
      ),
    );

    await cubit.confirmRecoveryKeySaved();
    verify(() => chatAuth.completeSetUp(pending, keepRecovery: true))
        .called(1);
    expect(cubit.state.step, MasterPasswordSetupStep.quickUnlock);
    expect(cubit.state.recoveryKey, isNull, reason: 'shown once, then gone');
    verifyNever(() => store.onSetUpComplete());

    await cubit.enableQuickUnlock(strong);
    expect(cubit.state.step, MasterPasswordSetupStep.ready);
    verifyNever(() => store.onSetUpComplete());

    await cubit.finish();
    expect(cubit.state.step, MasterPasswordSetupStep.done);
    verify(() => store.onSetUpComplete()).called(1);
    verify(() => store.setBiometricEnabled(enabled: true)).called(1);
    await cubit.close();
  });

  test('no strong biometrics: the key step leads straight to ready', () async {
    final cubit = build(canUseBiometrics: false);
    await cubit.checkQuickUnlock();
    expect(cubit.state.totalSteps, 2);
    await cubit.create(strong);
    await cubit.skipRecoveryKey();
    expect(cubit.state.step, MasterPasswordSetupStep.ready);
    verify(() => chatAuth.completeSetUp(pending, keepRecovery: false))
        .called(1);

    await cubit.finish();
    verify(() => store.onSetUpComplete()).called(1);
    verifyNever(() => store.setBiometricEnabled(enabled: true));
    await cubit.close();
  });

  blocTest<MasterPasswordSetupCubit, MasterPasswordSetupState>(
    'a refused fingerprint stays on its step and says why',
    setUp: () => when(() => biometrics.enable(any(), any()))
        .thenAnswer((_) async => BiometricEnableResult.notStrongEnough),
    build: build,
    seed: () => const MasterPasswordSetupState(
      step: MasterPasswordSetupStep.quickUnlock,
      quickUnlockAvailable: true,
    ),
    act: (cubit) => cubit.enableQuickUnlock(strong),
    skip: 1,
    expect: () => [
      isA<MasterPasswordSetupState>()
          .having((s) => s.step, 'step', MasterPasswordSetupStep.quickUnlock)
          .having(
            (s) => s.quickUnlockResult,
            'result',
            BiometricEnableResult.notStrongEnough,
          ),
    ],
  );

  blocTest<MasterPasswordSetupCubit, MasterPasswordSetupState>(
    '"Not now" goes on to ready',
    build: build,
    seed: () => const MasterPasswordSetupState(
      step: MasterPasswordSetupStep.quickUnlock,
      quickUnlockAvailable: true,
    ),
    act: (cubit) => cubit.skipQuickUnlock(),
    expect: () => [
      isA<MasterPasswordSetupState>()
          .having((s) => s.step, 'step', MasterPasswordSetupStep.ready),
    ],
  );

  test('a weak password never reaches the core', () async {
    final cubit = build();
    await cubit.create('abc');
    expect(cubit.state.tooWeak, isTrue);
    verifyNever(() => chatAuth.prepareSetUp(any()));
    await cubit.close();
  });

  test(
      'nothing is kept before the key step ends: a run closed there leaves '
      'a mark, and the next run says its key never worked', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences =
        PreferencesService(await SharedPreferences.getInstance());

    final first = build(preferences: preferences);
    expect(first.state.interruptedBefore, isFalse);
    await first.create(strong);
    expect(first.state.step, MasterPasswordSetupStep.recoveryKey);
    verifyNever(
      () => chatAuth.completeSetUp(
        any(),
        keepRecovery: any(named: 'keepRecovery'),
      ),
    );
    expect(preferences.firstRunPending, isTrue);
    // The app is closed here.
    await first.close();

    final second = build(preferences: preferences);
    expect(second.state.interruptedBefore, isTrue);
    await second.create(strong);
    await second.confirmRecoveryKeySaved();
    expect(preferences.firstRunPending, isFalse);
    await second.close();
  });

  test('a failed save stays on the key step, with the key, to try again',
      () async {
    when(
      () => chatAuth.completeSetUp(
        any(),
        keepRecovery: any(named: 'keepRecovery'),
      ),
    ).thenAnswer(
      (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
    );
    final cubit = build();
    await cubit.create(strong);
    await cubit.confirmRecoveryKeySaved();
    expect(cubit.state.step, MasterPasswordSetupStep.recoveryKey);
    expect(cubit.state.status, StateStatus.failed);
    expect(cubit.state.recoveryKey, 'AAAA-BBBB');
    await cubit.close();
  });
}
