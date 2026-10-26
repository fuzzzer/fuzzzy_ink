import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/redesign_harness.dart';

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

/// My safe, locked (DESIGN.md section 4.11): what opens it, fingerprint,
/// the password in place, the shared wrong-password wait, the first open
/// that makes the safe, and the recovery key for a safe with its own
/// password (owner, 2026-10-26).
void main() {
  final en = FuzzzyInkLocalizationsEn();
  late MockVaultAuthCubit cubit;

  const locked = VaultAuthState(
    status: StateStatus.success,
    authState: VaultAuthEnum.locked,
  );

  setUp(() {
    sl.safeRegisterSingleton<PasswordStrengthService>(
      PasswordStrengthService(),
    );
    cubit = MockVaultAuthCubit();
    when(() => cubit.lockoutRemaining()).thenAnswer((_) async => Duration.zero);
    when(() => cubit.unlock(any())).thenAnswer((_) async {});
    when(() => cubit.createVault(any())).thenAnswer((_) async {});
    when(() => cubit.unlockWithBiometrics()).thenAnswer((_) async {});
    when(
      () => cubit.recover(
        recoveryKey: any(named: 'recoveryKey'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => null);
  });

  tearDown(() => sl.unregister<PasswordStrengthService>());

  Future<void> pump(
    WidgetTester tester,
    VaultAuthState state, {
    Stream<VaultAuthState> stream = const Stream.empty(),
    FuzzzySkin skin = FuzzzySkin.night,
    Locale locale = const Locale('en'),
    Size? surface,
    double textScale = 1,
  }) async {
    whenListen(cubit, stream, initialState: state);
    await pumpRedesign(
      tester,
      BlocProvider<VaultAuthCubit>.value(
        value: cubit,
        child: const VaultUnlockPage(),
      ),
      skin: skin,
      locale: locale,
      private: true,
      surface: surface,
      textScale: textScale,
    );
    await tester.pump();
  }

  Future<void> typePassword(WidgetTester tester, String password) async {
    await tester.tap(find.byKey(const Key('btn.safe.usePassword')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('field.safe.password')),
      password,
    );
    await tester.pump();
  }

  for (final skin in redesignSkins) {
    testWidgets('opens with the master password, typed in place ($skin)',
        (tester) async {
      await pump(tester, locked, skin: skin);

      expect(find.text(en.safeLockedTitle), findsOneWidget);
      expect(find.text(en.safeOpensWithMaster), findsOneWidget);
      expect(find.byKey(const Key('field.safe.password')), findsNothing);
      expect(find.text(en.safeOpenWithFingerprint), findsNothing);

      await typePassword(tester, 'master pw');
      await tester.tap(find.byKey(const Key('btn.safe.open')));
      await tester.pump();
      verify(() => cubit.unlock('master pw')).called(1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('with fingerprint on, it is the first way and is tried once',
      (tester) async {
    await pump(tester, locked.copyWith(biometricEnabled: true));

    verify(() => cubit.unlockWithBiometrics()).called(1);
    await tester.tap(find.byKey(const Key('btn.safe.fingerprint')));
    await tester.pump();
    verify(() => cubit.unlockWithBiometrics()).called(1);
    expect(find.text(en.safeUseMasterPassword), findsOneWidget);
  });

  testWidgets('a wrong password turns the field red with one short line',
      (tester) async {
    final haptics = recordHaptics(tester);
    final states = StreamController<VaultAuthState>();
    addTearDown(states.close);
    await pump(tester, locked, stream: states.stream);
    await typePassword(tester, 'nope');
    expect(find.text(en.safeWrongPassword), findsNothing);

    states.add(
      locked.copyWith(
        status: StateStatus.failed,
        failureType: VaultFailureType.incorrectMasterPassword,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(en.safeWrongPassword), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    verify(() => cubit.lockoutRemaining()).called(greaterThan(1));

    // Typing again clears the line.
    await tester.enterText(
      find.byKey(const Key('field.safe.password')),
      'nope again',
    );
    await tester.pump();
    expect(find.text(en.safeWrongPassword), findsNothing);
  });

  testWidgets('a running wait reads "Wait 0:30" and counts down for real',
      (tester) async {
    var remaining = const Duration(seconds: 30);
    when(() => cubit.lockoutRemaining()).thenAnswer((_) async => remaining);
    await pump(tester, locked);
    await typePassword(tester, 'master pw');

    expect(find.text(en.safeTooManyTries), findsOneWidget);
    expect(find.text(en.lockoutWaitLeft('0:30')), findsOneWidget);
    expect(find.byKey(const Key('lockout.bar')), findsOneWidget);
    await tester.tap(find.text(en.lockoutWaitLeft('0:30')));
    verifyNever(() => cubit.unlock(any()));

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(en.lockoutWaitLeft('0:29')), findsOneWidget);
    remaining = Duration.zero;
    await tester.pump(const Duration(seconds: 29));
    expect(find.text(en.safeOpenButton), findsOneWidget);
    expect(find.text(en.safeTooManyTries), findsNothing);
  });

  testWidgets('before the safe exists, the first open makes it',
      (tester) async {
    await pump(
      tester,
      const VaultAuthState(
        status: StateStatus.success,
        authState: VaultAuthEnum.noVault,
      ),
    );
    expect(find.text(en.safeOpensWithMaster), findsOneWidget);
    await typePassword(tester, 'master pw');
    await tester.tap(find.byKey(const Key('btn.safe.open')));
    await tester.pump();
    verify(() => cubit.createVault('master pw')).called(1);
    verifyNever(() => cubit.unlock(any()));
  });

  testWidgets(
      'its own password: the recovery key opens it, and the master password '
      'can take over', (tester) async {
    await pump(
      tester,
      locked.copyWith(
        usesOwnPassword: true,
        recoverable: true,
        recoveryKeyKept: true,
      ),
    );
    expect(find.text(en.safeOpensWithOwn), findsOneWidget);
    expect(find.text(en.safeUseSafePassword), findsOneWidget);
    expect(find.text(en.vaultForgotPassword), findsNothing);

    await tester.tap(find.text(en.safeUseRecoveryKey));
    await tester.pump();
    expect(find.text(en.safeRecoveryTitle), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'aaaq-eaye-auda-ocaj-bifq-ydio-b4ib-ceqz',
    );
    await tester.tap(find.text(en.vaultRecoveryUseMasterPassword));
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn.vault.recover.submit')));
    await tester.pump();

    verify(
      () => cubit.recover(
        recoveryKey: 'aaaq-eaye-auda-ocaj-bifq-ydio-b4ib-ceqz',
      ),
    ).called(1);
  });

  testWidgets('its own password and no recovery copy: the password only',
      (tester) async {
    await pump(tester, locked.copyWith(usesOwnPassword: true));
    expect(find.text(en.vaultForgotPassword), findsOneWidget);
    expect(find.text(en.safeUseRecoveryKey), findsNothing);
  });

  testWidgets('Georgian at a small phone and large text: nothing overflows',
      (tester) async {
    await pump(
      tester,
      locked.copyWith(
        biometricEnabled: true,
        usesOwnPassword: true,
        recoverable: true,
      ),
      locale: const Locale('ka'),
      surface: const Size(320, 640),
      textScale: 1.3,
    );
    await tester.tap(find.byKey(const Key('btn.safe.usePassword')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
