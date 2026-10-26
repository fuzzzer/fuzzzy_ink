import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/access_harness.dart';

class MockRecoveryCubit extends MockCubit<MasterPasswordRecoveryState>
    implements MasterPasswordRecoveryCubit {}

/// "Forgot your password?" (prototype `rec-enter`, `rec-new`): the key,
/// then a new master password; a key that does not match comes back to the
/// key; erase everything stays behind a confirmation.
void main() {
  late AccessHarness harness;
  late MockRecoveryCubit cubit;
  late StreamController<MasterPasswordRecoveryState> changes;
  final l10n = FuzzzyInkLocalizationsEn();
  const key = 'AAAQ EAYE AUDA OCAJ BIFQ YDIO B4IB CEQZ';
  const strong = 'quiet lantern river 58!';

  setUp(() async {
    harness = AccessHarness();
    await harness.setUp();
    cubit = MockRecoveryCubit();
    changes = StreamController();
    whenListen(
      cubit,
      changes.stream,
      initialState: const MasterPasswordRecoveryState(),
    );
    when(
      () => cubit.recover(
        recoveryKey: any(named: 'recoveryKey'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await changes.close();
    await harness.tearDown();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    double textScale = 1,
  }) =>
      harness.pump(
        tester,
        BlocProvider<MasterPasswordRecoveryCubit>.value(
          value: cubit,
          child: const MasterPasswordRecoveryView(),
        ),
        private: true,
        skin: skin,
        reduceMotion: reduceMotion,
        textScale: textScale,
        surface: const Size(390, 844),
      );

  Future<void> typeKeyAndContinue(WidgetTester tester, String text) async {
    await tester.enterText(kitField('recover.keyField'), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn.recover.continue')));
    await tester.pumpAndSettle();
  }

  Future<void> typeNewPassword(WidgetTester tester) async {
    await tester.enterText(kitField('recover.password'), strong);
    await tester.enterText(kitField('recover.confirm'), strong);
    await tester.pump();
  }

  testWidgets('a private screen: the key, its tip and the way out',
      (tester) async {
    await pumpPage(tester);
    expect(find.text(l10n.accessTypeRecoveryKey), findsOneWidget);
    expect(find.text(l10n.accessSpacesDontMatter), findsOneWidget);
    expect(find.text(l10n.accessNoKeyNothing), findsOneWidget);
    expect(
      SensitiveScreen.isIn(
        tester.element(find.text(l10n.accessTypeRecoveryKey)),
      ),
      isTrue,
    );
  });

  testWidgets('a key too short is caught before the new password',
      (tester) async {
    await pumpPage(tester);
    await typeKeyAndContinue(tester, 'AAAQ EAYE');
    expect(find.text(l10n.accessKeyTooShort), findsOneWidget);
    expect(find.text(l10n.accessNewMasterPassword), findsNothing);
  });

  testWidgets('key, then a Good password, then the core checks both',
      (tester) async {
    await pumpPage(tester);
    await typeKeyAndContinue(tester, key);
    expect(find.text(l10n.accessKeyCheckedOnSave), findsOneWidget);
    expect(kitButton(tester, 'recover.submit').onPressed, isNull);

    await typeNewPassword(tester);
    await tester.tap(find.byKey(const Key('btn.recover.submit')));
    verify(() => cubit.recover(recoveryKey: key, newPassword: strong))
        .called(1);
  });

  testWidgets('a key that does not match comes back to the key',
      (tester) async {
    await pumpPage(tester);
    await typeKeyAndContinue(tester, key);
    await typeNewPassword(tester);

    changes.add(
      const MasterPasswordRecoveryState(
        status: StateStatus.failed,
        failureType: CryptoCoreFailureType.corrupt,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.accessKeyDoesntMatch), findsOneWidget);
    expect(find.text(l10n.accessTypeRecoveryKey), findsOneWidget);
  });

  testWidgets('saved: "New master password saved." on the next screen',
      (tester) async {
    await pumpPage(tester);
    changes.add(const MasterPasswordRecoveryState(status: StateStatus.success));
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text(l10n.accessNewPasswordSaved), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('erase everything asks first', (tester) async {
    when(() => harness.authStore.eraseEverything())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    await pumpPage(tester);
    await tester.ensureVisible(find.text(l10n.chatUnlockErase));
    await tester.tap(find.text(l10n.chatUnlockErase));
    await tester.pumpAndSettle();
    expect(find.text(l10n.eraseMessage), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    verifyNever(() => harness.authStore.eraseEverything());

    await tester.tap(find.text(l10n.chatUnlockErase));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.eraseConfirm));
    await tester.pumpAndSettle();
    verify(() => harness.authStore.eraseEverything()).called(1);
  });

  testWidgets('back leads to the lock screen', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('recover.key.back')));
    await tester.pumpAndSettle();
    expect(find.text('route:${AppRouter.chatUnlock}'), findsOneWidget);
  });

  forEveryLook('both steps fit', (tester, skin, reduceMotion, textScale) async {
    await pumpPage(
      tester,
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
    );
    await typeKeyAndContinue(tester, key);
    expect(find.text(l10n.accessKeyCheckedOnSave), findsOneWidget);
  });
}
