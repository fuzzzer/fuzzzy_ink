import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/access_harness.dart';

/// The lock screen (prototype `lockscreen`): wrong password, the wait after
/// too many, fingerprint, a waiting link, the notices, "Forgot your
/// password?" (security review 2026-10-22, items 2 and 6).
void main() {
  late AccessHarness harness;
  final l10n = FuzzzyInkLocalizationsEn();
  final locked = AccessHarness.locked;

  setUp(() async {
    harness = AccessHarness();
  });

  tearDown(() => harness.tearDown());

  Future<void> pumpPage(
    WidgetTester tester,
    FuzzyAuthState state, {
    Stream<FuzzyAuthState> changes = const Stream.empty(),
    ValueNotifier<WaitingArrival?>? pendingLink,
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    await harness.setUp(auth: state, authChanges: changes);
    when(() => harness.authStore.unlock(any())).thenAnswer((_) async {});
    when(() => harness.authStore.unlockWithBiometrics())
        .thenAnswer((_) async {});
    await harness.pump(
      tester,
      ChatUnlockPage(pendingLink: pendingLink ?? ValueNotifier(null)),
      private: true,
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
      surface: const Size(390, 844),
    );
    await tester.pump();
  }

  Finder passwordField() => kitField('unlock.password');

  testWidgets('a private screen: the mark, the title and the password',
      (tester) async {
    await pumpPage(tester, locked);
    expect(find.byKey(const Key('mark.lock')), findsOneWidget);
    expect(find.text(l10n.accessLockedTitle), findsOneWidget);
    expect(
      SensitiveScreen.isIn(tester.element(find.text(l10n.accessLockedTitle))),
      isTrue,
    );
  });

  testWidgets(
      'a running wait: "Too many tries.", the button counts down and the '
      'field waits', (tester) async {
    await pumpPage(
      tester,
      locked.copyWith(lockoutRemaining: const Duration(minutes: 1, seconds: 5)),
    );

    expect(find.text(l10n.accessTooManyTries), findsOneWidget);
    expect(find.text(l10n.lockoutWaitLeft('1:05')), findsOneWidget);
    expect(kitButton(tester, 'unlock.unlock').onPressed, isNull);
    expect(find.byKey(const Key('lockout.bar')), findsOneWidget);
    // The field takes no input while the wait runs.
    expect(
      find.ancestor(of: passwordField(), matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
  });

  testWidgets('with reduced motion the countdown text stays, the bar goes',
      (tester) async {
    await pumpPage(
      tester,
      locked.copyWith(lockoutRemaining: const Duration(seconds: 30)),
      reduceMotion: true,
    );
    expect(find.text(l10n.lockoutWaitLeft('0:30')), findsOneWidget);
    expect(find.byKey(const Key('lockout.bar')), findsNothing);
  });

  testWidgets('Unlock works once a password is typed', (tester) async {
    await pumpPage(tester, locked);
    expect(kitButton(tester, 'unlock.unlock').onPressed, isNull);
    await tester.enterText(passwordField(), 'pw');
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn.unlock.unlock')));
    verify(() => harness.authStore.unlock('pw')).called(1);
  });

  testWidgets('Enter on the keyboard tries nothing while a check runs',
      (tester) async {
    await pumpPage(tester, locked.copyWith(status: AuthStateStatus.unlocking));
    await tester.enterText(passwordField(), 'pw');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    verifyNever(() => harness.authStore.unlock(any()));
  });

  testWidgets('Enter on the keyboard tries the password when idle',
      (tester) async {
    await pumpPage(tester, locked);
    await tester.enterText(passwordField(), 'pw');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    verify(() => harness.authStore.unlock('pw')).called(1);
  });

  testWidgets(
      'a wrong password: red field, one line, one firm buzz, no shake; the '
      'next edit clears it', (tester) async {
    final haptics = recordHaptics(tester);
    final changes = StreamController<FuzzyAuthState>();
    addTearDown(changes.close);
    await pumpPage(tester, locked, changes: changes.stream);
    await tester.enterText(passwordField(), 'wrong');
    await tester.pump();

    changes.add(locked.copyWith(verificationFailed: true));
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.accessWrongPassword), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.heavyImpact']);
    final editable = tester.widget<EditableText>(passwordField());
    expect(editable.controller.selection.start, 0);
    expect(editable.controller.selection.end, 'wrong'.length);

    await tester.enterText(passwordField(), 'x');
    await tester.pump();
    expect(find.text(l10n.accessWrongPassword), findsNothing);
  });

  testWidgets('a link tapped while locked says it is waiting', (tester) async {
    final pending = ValueNotifier<WaitingArrival?>(null);
    await pumpPage(tester, locked, pendingLink: pending);
    expect(find.text(l10n.accessLinkWaiting), findsNothing);
    pending.value = WaitingArrival.link;
    await tester.pump();
    expect(find.text(l10n.accessLinkWaiting), findsOneWidget);
    expect(find.text(l10n.accessFileWaiting), findsNothing);
  });

  testWidgets(
      'a .fuzz file opened while locked says a file is waiting, not a link '
      '(final regression 2026-10-26)', (tester) async {
    final pending = ValueNotifier<WaitingArrival?>(null);
    await pumpPage(tester, locked, pendingLink: pending);
    pending.value = WaitingArrival.file;
    await tester.pump();
    expect(find.text(l10n.accessFileWaiting), findsOneWidget);
    expect(find.text(l10n.accessLinkWaiting), findsNothing);
    pending.value = null;
    await tester.pump();
    expect(find.text(l10n.accessFileWaiting), findsNothing);
  });

  testWidgets('the fingerprint button asks the device', (tester) async {
    await pumpPage(tester, locked.copyWith(biometricEnabled: true));
    // Tried once by itself at the start.
    verify(() => harness.authStore.unlockWithBiometrics()).called(1);
    await tester.tap(find.byKey(const Key('btn.unlock.bio')));
    verify(() => harness.authStore.unlockWithBiometrics()).called(1);
  });

  testWidgets(
      'after Lock now the screen waits for the person: no prompt by itself, '
      'the fingerprint button still works', (tester) async {
    await pumpPage(
      tester,
      locked.copyWith(biometricEnabled: true, lockedByUser: true),
    );
    verifyNever(() => harness.authStore.unlockWithBiometrics());
    await tester.tap(find.byKey(const Key('btn.unlock.bio')));
    verify(() => harness.authStore.unlockWithBiometrics()).called(1);
  });

  testWidgets('a lock made while the app is away prompts on return, not before',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await pumpPage(tester, locked.copyWith(biometricEnabled: true));
    verifyNever(() => harness.authStore.unlockWithBiometrics());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(() => harness.authStore.unlockWithBiometrics()).called(1);
  });

  testWidgets(
      'the one-time notices stay once an update or a new finger '
      'turned the shortcut off', (tester) async {
    await pumpPage(
      tester,
      const FuzzyAuthState.initial(),
      changes: Stream.fromIterable([
        locked.copyWith(biometricReset: true),
        locked.copyWith(biometricInvalidated: true),
      ]),
    );
    await tester.pump();
    expect(find.text(l10n.accessBioReset), findsOneWidget);
    expect(find.text(l10n.accessBioChanged), findsOneWidget);
  });

  testWidgets(
      'a secure storage that cannot be read shows the error and a retry, '
      'never a password field', (tester) async {
    await pumpPage(
      tester,
      const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.storageUnavailable),
    );
    when(() => harness.authStore.checkAuthStatus()).thenAnswer((_) async {});
    expect(find.byKey(const Key('note.unlock.storageUnavailable')), findsOne);
    expect(passwordField(), findsNothing);
    await tester.tap(find.text(l10n.tryAgain));
    verify(() => harness.authStore.checkAuthStatus()).called(1);

    // Keys an earlier build left that this one cannot read: start fresh,
    // after the confirmation.
    when(() => harness.authStore.eraseEverything())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    await tester.tap(find.text(l10n.chatUnlockErase));
    await tester.pumpAndSettle();
    expect(find.text(l10n.eraseMessage), findsOneWidget);
    await tester.tap(find.text(l10n.eraseConfirm));
    await tester.pumpAndSettle();
    verify(() => harness.authStore.eraseEverything()).called(1);
  });

  testWidgets('"Forgot your password?" leads to the recovery key',
      (tester) async {
    await pumpPage(tester, locked);
    await tester.tap(find.text(l10n.accessForgotPassword));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRouter.recover}'), findsOneWidget);
  });

  forEveryLook('the lock screen fits, waiting or not', (
    tester,
    skin,
    reduceMotion,
    textScale,
  ) async {
    await pumpPage(
      tester,
      locked.copyWith(
        biometricEnabled: true,
        lockoutRemaining: const Duration(seconds: 30),
      ),
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
    );
    expect(find.text(l10n.lockoutWaitLeft('0:30')), findsOneWidget);
  });
}
