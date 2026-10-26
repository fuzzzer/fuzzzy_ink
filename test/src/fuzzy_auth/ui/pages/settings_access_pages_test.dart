import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/access_harness.dart';

/// Settings → Master password, Recovery key and My safe → Opens with
/// (prototype `set-pw`, `set-rec`, `set-safepw`): all private screens.
void main() {
  late AccessHarness harness;
  final l10n = FuzzzyInkLocalizationsEn();
  const strong = 'quiet lantern river 58!';
  const ownSafe = VaultAuthState(
    authState: VaultAuthEnum.locked,
    usesOwnPassword: true,
  );
  const masterSafe = VaultAuthState(authState: VaultAuthEnum.locked);

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(
      PendingRecoveryKey(
        recoveryKey: 'k',
        recoveryWrap: Uint8List(0),
        recoveryLock: Uint8List(0),
      ),
    );
  });

  setUp(() => harness = AccessHarness());
  tearDown(() => harness.tearDown());

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    VaultAuthState vaultState = masterSafe,
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    await harness.setUp(
      auth: const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.authenticated),
      vaultState: vaultState,
    );
    when(() => harness.biometrics.disable(any())).thenAnswer((_) async {});
    when(
      () =>
          harness.authStore.setBiometricEnabled(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async {});
    when(() => harness.vault.onMasterPasswordChanged())
        .thenAnswer((_) async {});
    when(() => harness.vault.refreshRecovery()).thenAnswer((_) async {});
    await harness.pump(
      tester,
      page,
      private: true,
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
      surface: const Size(390, 844),
    );
    await tester.pumpAndSettle();
  }

  group('Change master password', () {
    Future<void> fill(WidgetTester tester, String current) async {
      await tester.enterText(kitField('changePassword.current'), current);
      await tester.enterText(kitField('changePassword.password'), strong);
      await tester.enterText(kitField('changePassword.confirm'), strong);
      await tester.pump();
    }

    testWidgets('a wrong current password turns its field red', (tester) async {
      await pumpPage(tester, const ChangeMasterPasswordPage());
      expect(find.text(l10n.accessRecoveryKeepsWorking), findsOneWidget);
      when(
        () => harness.chatAuth.changePassword(
          oldPassword: 'old',
          newPassword: strong,
        ),
      ).thenAnswer(
        (_) async =>
            const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
      );
      await fill(tester, 'old');
      await tester.tap(find.byKey(const Key('btn.changePassword.submit')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accessWrongPassword), findsOneWidget);
    });

    testWidgets('changed: My safe hears of it, and the screen closes',
        (tester) async {
      await pumpPage(tester, const ChangeMasterPasswordPage());
      when(
        () => harness.chatAuth.changePassword(
          oldPassword: 'old',
          newPassword: strong,
        ),
      ).thenAnswer((_) async => const CryptoCoreSuccess(null));
      expect(kitButton(tester, 'changePassword.submit').onPressed, isNull);
      await fill(tester, 'old');
      await tester.tap(find.byKey(const Key('btn.changePassword.submit')));
      await tester.pump();
      await tester.pump();
      verify(() => harness.vault.onMasterPasswordChanged()).called(1);
      expect(find.text(l10n.accessMasterPasswordChanged), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('New recovery key', () {
    PendingRecoveryKey pending() => PendingRecoveryKey(
          recoveryKey: 'AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ',
          recoveryWrap: Uint8List(1),
          recoveryLock: Uint8List(1),
        );

    testWidgets(
        'My safe with its own password: its password is asked too (owner, '
        '2026-10-26), and a wrong one is shown on its field', (tester) async {
      await pumpPage(
        tester,
        NewRecoveryKeyPage(export: FakeRecoveryKeyExport()),
        vaultState: ownSafe,
      );
      expect(find.text(l10n.accessSafePasswordToo), findsOneWidget);
      expect(find.text(l10n.accessNoPasswordNoKey), findsOneWidget);

      await tester.enterText(kitField('newKey.password'), 'pw');
      await tester.pump();
      expect(kitButton(tester, 'newKey.make').onPressed, isNull);

      // Without a readable safe the cubit refuses before anything changes.
      when(() => harness.vaultRepository.getMetadata()).thenAnswer(
        (_) async => const VaultFailure(VaultFailureType.vaultNotInitialized),
      );
      when(
        () => harness.chatAuth.newRecoveryKey(
          any(),
          sealVault: any(named: 'sealVault'),
        ),
      ).thenAnswer(
        (_) async =>
            const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
      );
      await tester.enterText(kitField('newKey.safePassword'), 'safe');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn.newKey.make')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accessWrongPassword), findsOneWidget);
    });

    testWidgets('the new key, then "I\'ve kept it safe" after a save',
        (tester) async {
      final export = FakeRecoveryKeyExport();
      await pumpPage(tester, NewRecoveryKeyPage(export: export));
      when(() => harness.vaultRepository.getMetadata()).thenAnswer(
        (_) async => const VaultFailure(VaultFailureType.vaultNotInitialized),
      );
      when(
        () => harness.chatAuth.newRecoveryKey(
          'pw',
          sealVault: any(named: 'sealVault'),
        ),
      ).thenAnswer((_) async => CryptoCoreSuccess(pending()));
      when(() => harness.chatAuth.saveRecovery(any()))
          .thenAnswer((_) async => const CryptoCoreSuccess(null));

      await tester.enterText(kitField('newKey.password'), 'pw');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn.newKey.make')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accessYourNewKey), findsOneWidget);
      expect(find.text('AAAQ EAYE AUDA OCAJ'), findsOneWidget);
      expect(
        SensitiveScreen.isIn(tester.element(find.text('AAAQ EAYE AUDA OCAJ'))),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('btn.recoveryKey.save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn.recoveryKey.kept')));
      await tester.pump();
      await tester.pump();
      verify(() => harness.chatAuth.saveRecovery(any())).called(1);
      verify(() => harness.vault.refreshRecovery()).called(2);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('My safe opens with', () {
    testWidgets('own password: Good twice and the master password to confirm',
        (tester) async {
      await pumpPage(tester, const SafeOpensWithPage());
      expect(find.text(l10n.accessSimplestRecommended), findsOneWidget);
      expect(find.byKey(const Key('btn.safeOpensWith.save')), findsNothing);

      await tester.tap(find.byKey(const Key('tile.safeOpensWith.own')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.vaultOwnPasswordRecoveryNote), findsOneWidget);
      expect(kitButton(tester, 'safeOpensWith.save').onPressed, isNull);

      when(
        () => harness.vault.useOwnPassword(
          masterPassword: 'master',
          newPassword: strong,
        ),
      ).thenAnswer((_) async => VaultFailureType.incorrectMasterPassword);
      await tester.enterText(kitField('safeOpensWith.new.password'), strong);
      await tester.enterText(kitField('safeOpensWith.new.confirm'), strong);
      await tester.enterText(
        kitField('safeOpensWith.masterPassword'),
        'master',
      );
      await tester.pump();
      await tester
          .ensureVisible(find.byKey(const Key('btn.safeOpensWith.save')));
      await tester.tap(find.byKey(const Key('btn.safeOpensWith.save')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accessWrongPassword), findsOneWidget);
    });

    testWidgets('back to the master password asks for the safe password',
        (tester) async {
      await pumpPage(tester, const SafeOpensWithPage(), vaultState: ownSafe);
      await tester.tap(find.byKey(const Key('tile.safeOpensWith.master')));
      await tester.pumpAndSettle();
      expect(kitField('safeOpensWith.safePassword'), findsOneWidget);
      expect(find.text(l10n.accessUseMasterPassword), findsOneWidget);
    });

    testWidgets('no safe yet: it says how to make one', (tester) async {
      await pumpPage(
        tester,
        const SafeOpensWithPage(),
        vaultState: const VaultAuthState(authState: VaultAuthEnum.noVault),
      );
      expect(find.text(l10n.accessSafeNotMadeYet), findsOneWidget);
    });
  });

  forEveryLook('the three screens fit', (
    tester,
    skin,
    reduceMotion,
    textScale,
  ) async {
    for (final page in <Widget>[
      const ChangeMasterPasswordPage(),
      NewRecoveryKeyPage(export: FakeRecoveryKeyExport()),
      const SafeOpensWithPage(),
    ]) {
      await pumpPage(
        tester,
        page,
        vaultState: ownSafe,
        skin: skin,
        reduceMotion: reduceMotion,
        textScale: textScale,
      );
      expect(tester.takeException(), isNull, reason: '$page');
      await harness.tearDown();
    }
    await harness.setUp();
  });

  testWidgets('the screens read the app cubits they are given', (tester) async {
    await pumpPage(tester, const SafeOpensWithPage(), vaultState: ownSafe);
    final context = tester.element(find.byType(SafeOpensWithPage));
    expect(context.read<VaultAuthCubit>(), harness.vault);
  });
}
