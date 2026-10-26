import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/access_harness.dart';

class MockSetupCubit extends MockCubit<MasterPasswordSetupState>
    implements MasterPasswordSetupCubit {}

/// The first run after the welcome (prototype `ob-password`, `ob-recovery`,
/// `ob-bio`, `ob-ready`).
void main() {
  late AccessHarness harness;
  late MockSetupCubit cubit;
  late FakeRecoveryKeyExport export;
  final l10n = FuzzzyInkLocalizationsEn();
  const recoveryKey = 'AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ';
  const strong = 'quiet lantern river 58!';

  const passwordStep = MasterPasswordSetupState(
    quickUnlockAvailable: true,
  );
  final keyStep = MasterPasswordSetupState(
    step: MasterPasswordSetupStep.recoveryKey,
    status: StateStatus.success,
    recoveryKey: recoveryKey,
    recoveryWrap: Uint8List(1),
    recoveryLock: Uint8List(1),
    quickUnlockAvailable: true,
  );
  const bioStep = MasterPasswordSetupState(
    step: MasterPasswordSetupStep.quickUnlock,
    status: StateStatus.success,
    quickUnlockAvailable: true,
  );
  const readyStep = MasterPasswordSetupState(
    step: MasterPasswordSetupStep.ready,
    status: StateStatus.success,
  );

  setUp(() async {
    harness = AccessHarness();
    await harness.setUp(
      auth: const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.setupRequired),
    );
    cubit = MockSetupCubit();
    export = FakeRecoveryKeyExport();
    when(() => cubit.create(any())).thenAnswer((_) async {});
    when(() => cubit.confirmRecoveryKeySaved()).thenAnswer((_) async {});
    when(() => cubit.skipRecoveryKey()).thenAnswer((_) async {});
    when(() => cubit.enableQuickUnlock(any())).thenAnswer((_) async {});
    when(() => cubit.skipQuickUnlock()).thenReturn(null);
    when(() => cubit.finish()).thenAnswer((_) async {});
  });

  tearDown(() => harness.tearDown());

  Future<void> pumpStep(
    WidgetTester tester,
    MasterPasswordSetupState state, {
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    double textScale = 1,
    bool castOn = false,
  }) async {
    whenListen(
      cubit,
      const Stream<MasterPasswordSetupState>.empty(),
      initialState: state,
    );
    await harness.pump(
      tester,
      BlocProvider<MasterPasswordSetupCubit>.value(
        value: cubit,
        child: MasterPasswordSetupView(export: export),
      ),
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
      castOn: castOn,
      surface: const Size(390, 844),
    );
  }

  FuzzzyButton button(WidgetTester tester, String qaId) =>
      kitButton(tester, qaId);

  group('master password (step 1)', () {
    testWidgets('is private, and Continue needs Good, a match and the tick',
        (tester) async {
      await pumpStep(tester, passwordStep);
      expect(
        find.text(
          l10n
              .stepsProgressWithLabel(1, 3, l10n.accessStepPassword)
              .toUpperCase(),
        ),
        findsOneWidget,
      );
      expect(
        SensitiveScreen.isIn(
          tester.element(find.text(l10n.accessMakeMasterPassword)),
        ),
        isTrue,
      );
      expect(button(tester, 'setup.create').onPressed, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('field.setup.password')),
          matching: find.byType(EditableText),
        ),
        strong,
      );
      await tester.pump();
      expect(find.text(l10n.accessStrengthStrong), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('field.setup.confirm')),
          matching: find.byType(EditableText),
        ),
        'something else',
      );
      await tester.pump();
      expect(find.text(l10n.accessPasswordsDontMatch), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('field.setup.confirm')),
          matching: find.byType(EditableText),
        ),
        strong,
      );
      await tester.pump();
      expect(button(tester, 'setup.create').onPressed, isNull);

      await tester
          .ensureVisible(find.byKey(const Key('check.setup.understand')));
      await tester.tap(find.byKey(const Key('check.setup.understand')));
      await tester.pump();
      expect(button(tester, 'setup.create').onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('btn.setup.create')));
      verify(() => cubit.create(strong)).called(1);
    });

    testWidgets('the no-reset warning explains itself behind "Why?"',
        (tester) async {
      await pumpStep(tester, passwordStep);
      expect(find.textContaining(l10n.accessNoResetLine), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('why.noReset')));
      await tester.tap(find.byKey(const Key('why.noReset')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.infoNoResetLine2), findsOneWidget);
    });

    testWidgets('an earlier install is explained (its data is wiped)',
        (tester) async {
      whenListen(
        harness.authStore,
        const Stream<FuzzyAuthState>.empty(),
        initialState: const FuzzyAuthState.initial().copyWith(
          status: AuthStateStatus.setupRequired,
          previousDataFound: true,
        ),
      );
      await pumpStep(tester, passwordStep);
      expect(find.text(l10n.masterPasswordPreviousData), findsOneWidget);
    });

    testWidgets(
        'a first run closed on the key step says its key never worked '
        '(and a new one comes)', (tester) async {
      await pumpStep(
        tester,
        const MasterPasswordSetupState(interruptedBefore: true),
      );
      expect(find.text(l10n.accessSetupInterrupted), findsOneWidget);
    });

    testWidgets('without strong biometrics the steps count to two',
        (tester) async {
      await pumpStep(tester, const MasterPasswordSetupState());
      expect(
        find.text(
          l10n
              .stepsProgressWithLabel(1, 2, l10n.accessStepPassword)
              .toUpperCase(),
        ),
        findsOneWidget,
      );
    });
  });

  group('recovery key (step 2)', () {
    testWidgets('is private and shows the key as text that cannot be selected',
        (tester) async {
      await pumpStep(tester, keyStep);
      expect(find.text('AAAQ EAYE AUDA OCAJ'), findsOneWidget);
      expect(find.text('BIFQ YDIO B4IB CEQZ'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(SelectionArea), findsNothing);
      expect(
        SensitiveScreen.isIn(tester.element(find.text('AAAQ EAYE AUDA OCAJ'))),
        isTrue,
      );
    });

    testWidgets('"I\'ve kept it safe" turns on only after a save',
        (tester) async {
      await pumpStep(tester, keyStep);
      expect(button(tester, 'recoveryKey.kept').onPressed, isNull);

      await tester.tap(find.byKey(const Key('btn.recoveryKey.save')));
      await tester.pumpAndSettle();
      expect(export.saved.single, contains(recoveryKey));
      expect(find.text(l10n.accessSaved), findsOneWidget);
      expect(button(tester, 'recoveryKey.kept').onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('btn.recoveryKey.kept')));
      verify(() => cubit.confirmRecoveryKeySaved()).called(1);
    });

    testWidgets('a backed-out save keeps "I\'ve kept it safe" off',
        (tester) async {
      export.saveAnswer = false;
      await pumpStep(tester, keyStep);
      await tester.tap(find.byKey(const Key('btn.recoveryKey.save')));
      await tester.pumpAndSettle();
      expect(button(tester, 'recoveryKey.kept').onPressed, isNull);
    });

    testWidgets('Print shows the one-page sheet, then hands it over',
        (tester) async {
      await pumpStep(tester, keyStep);
      await tester.tap(find.byKey(const Key('btn.recoveryKey.print')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_key.print_sheet')), findsOneWidget);
      expect(find.text('1. ${l10n.accessPrintLine1}'), findsOneWidget);
      expect(find.text('2. ${l10n.accessPrintLine2}'), findsOneWidget);
      expect(find.text('3. ${l10n.accessPrintLine3}'), findsOneWidget);
      expect(
        SensitiveScreen.isIn(
          tester.element(find.byKey(const Key('recovery_key.print_sheet'))),
        ),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('btn.printPreview.print')));
      await tester.pumpAndSettle();
      expect(export.prints, 1);
      expect(find.text(l10n.confirmHandedOver), findsOneWidget);
      expect(button(tester, 'recoveryKey.kept').onPressed, isNotNull);
    });

    testWidgets('no Print where the system cannot share files', (tester) async {
      export = FakeRecoveryKeyExport(printable: false);
      await pumpStep(tester, keyStep);
      expect(find.byKey(const Key('btn.recoveryKey.print')), findsNothing);
      expect(find.byKey(const Key('btn.recoveryKey.save')), findsOneWidget);
    });

    testWidgets('skipping asks first: Keep it now, or Skip anyway',
        (tester) async {
      await pumpStep(tester, keyStep);
      await tester.tap(find.text(l10n.accessSkipForNow));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accessSkipKeyMessage), findsOneWidget);

      await tester.tap(find.text(l10n.accessSkipKeyKeep));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.skipRecoveryKey());

      await tester.tap(find.text(l10n.accessSkipForNow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accessSkipKeyAnyway));
      await tester.pumpAndSettle();
      verify(() => cubit.skipRecoveryKey()).called(1);
    });
  });

  group('quick unlock (step 3)', () {
    testWidgets('is not private; the buttons turn it on or skip it',
        (tester) async {
      await pumpStep(tester, bioStep);
      expect(find.text(l10n.accessBioTitle('other')), findsOneWidget);
      expect(find.text(l10n.accessBioTip), findsOneWidget);
      expect(
        SensitiveScreen.isIn(
          tester.element(find.text(l10n.accessBioTitle('other'))),
        ),
        isFalse,
      );

      await tester.tap(find.byKey(const Key('btn.setup.useBio')));
      await tester.pump();
      verify(() => cubit.enableQuickUnlock(any())).called(1);

      await tester.tap(find.byKey(const Key('btn.setup.notNow')));
      verify(() => cubit.skipQuickUnlock()).called(1);
    });

    for (final (kind, title, button) in [
      (BiometricKind.faceId, 'Unlock with Face ID?', 'Use Face ID'),
      (BiometricKind.touchId, 'Unlock with Touch ID?', 'Use Touch ID'),
      (
        BiometricKind.fingerprint,
        'Unlock with your fingerprint?',
        'Use fingerprint',
      ),
      (BiometricKind.face, 'Unlock with your face?', 'Use face unlock'),
    ]) {
      testWidgets(
          "names the device's own quick unlock: $kind "
          '(final regression 2026-10-26)', (tester) async {
        whenListen(
          harness.authStore,
          const Stream<FuzzyAuthState>.empty(),
          initialState: const FuzzyAuthState.initial().copyWith(
            status: AuthStateStatus.setupRequired,
            biometricKind: kind,
          ),
        );
        await pumpStep(tester, bioStep);
        expect(find.text(title), findsOneWidget);
        expect(find.text(button), findsOneWidget);
        if (kind != BiometricKind.fingerprint) {
          expect(find.textContaining('fingerprint'), findsNothing);
        }
      });
    }

    testWidgets('a refusal says why', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          bioStep.copyWith(
            status: StateStatus.failed,
            quickUnlockResult: BiometricEnableResult.notStrongEnough,
          ),
        ),
        initialState: bioStep,
      );
      await harness.pump(
        tester,
        BlocProvider<MasterPasswordSetupCubit>.value(
          value: cubit,
          child: MasterPasswordSetupView(export: export),
        ),
      );
      await tester.pump();
      expect(find.text(l10n.biometricNotStrongEnough), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group("you're ready", () {
    testWidgets(
        'the check draws while Fuzzzy Cast is off; the card turns it on',
        (tester) async {
      await pumpStep(tester, readyStep);
      await tester.pumpAndSettle();
      expect(find.text(l10n.accessReadyTitle), findsOneWidget);
      expect(find.byKey(const Key('hero.setup.ready')), findsOneWidget);
      expect(
        SensitiveScreen.isIn(tester.element(find.text(l10n.accessReadyTitle))),
        isFalse,
      );

      await tester.tap(find.byKey(const Key('toggle.setup.fuzzzyCast')));
      await tester.pump();
      expect(sl.get<PreferencesService>().fuzzzyCastEnabled, isTrue);
      expect(find.byKey(const Key('hero.setup.ready')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('"Look around first" finishes and opens Home', (tester) async {
      await pumpStep(tester, readyStep);
      await tester.tap(find.text(l10n.accessLookAround));
      await tester.pumpAndSettle();
      verify(() => cubit.finish()).called(1);
      expect(find.text('route:${AppRouter.home}'), findsOneWidget);
    });
  });

  forEveryLook('every step fits',
      (tester, skin, reduceMotion, textScale) async {
    for (final state in [passwordStep, keyStep, bioStep, readyStep]) {
      await pumpStep(
        tester,
        state,
        skin: skin,
        reduceMotion: reduceMotion,
        textScale: textScale,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: '${state.step}');
    }
  });
}
