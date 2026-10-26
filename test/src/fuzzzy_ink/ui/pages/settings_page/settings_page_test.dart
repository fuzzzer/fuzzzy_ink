import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../../helpers/access_harness.dart';

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

/// The Settings tab (prototype `settings`, sheets `autolock`, `look`,
/// `lang`).
void main() {
  late AccessHarness harness;
  final l10n = FuzzzyInkLocalizationsEn();

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(AutoLockSettings.standard);
  });

  setUp(() {
    harness = AccessHarness();
    sl
      ..safeRegisterSingleton<CryptoCoreService>(MockCryptoCoreService())
      ..safeRegisterSingleton<PackageInfo>(
        PackageInfo(
          appName: 'Fuzzzy Ink',
          packageName: 'com.fuzzzycore.ink',
          version: '1.1.0',
          buildNumber: '2',
        ),
      );
  });

  tearDown(() async {
    await harness.tearDown();
    await sl.unregister<CryptoCoreService>();
    await sl.unregister<PackageInfo>();
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    FuzzyAuthState? auth,
    VaultAuthState vaultState = const VaultAuthState(),
    bool canUseBiometrics = true,
    bool castOn = false,
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    await harness.setUp(
      auth: auth ??
          const FuzzyAuthState.initial()
              .copyWith(status: AuthStateStatus.authenticated),
      vaultState: vaultState,
      canUseBiometrics: canUseBiometrics,
    );
    await harness.pump(
      tester,
      const SettingsPage(),
      castOn: castOn,
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
      surface: const Size(540, 2400),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String qaId) async {
    await tester.ensureVisible(find.byKey(Key('tile.$qaId')));
    await tester.tap(find.byKey(Key('tile.$qaId')));
    await tester.pumpAndSettle();
  }

  testWidgets('every section, in the design order, and the version',
      (tester) async {
    await pumpSettings(tester);
    final labels = [
      l10n.accessSettingsKeepingSafe,
      l10n.tabMySafe,
      l10n.fuzzzyCast,
      l10n.settingsLookAndLanguage,
      l10n.accessHelp,
    ].map((label) => label.toUpperCase()).toList();
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, [...tops]..sort());

    for (final row in [
      'masterPassword',
      'recoveryKey',
      'biometric',
      'autoLock',
      'lockNow',
      'safeOpensWith',
      'copyPasswords',
      'fuzzzyCast',
      'look',
      'language',
      'howItWorks',
      'legal',
    ]) {
      expect(find.byKey(Key('tile.settings.$row')), findsOneWidget);
    }
    expect(
      find.text(l10n.accessLockAfter(l10n.accessFiveMinutes)),
      findsOneWidget,
    );
    expect(find.text('Fuzzzy Ink · version 1.1.0 (build 2)'), findsOneWidget);
    // Soft sounds shows only while Fuzzzy Cast is on.
    expect(find.text(l10n.softSounds), findsNothing);
    // Not in staging and production builds (no --flavor here).
    expect(isFileBenchmarkEnabled, isFalse);
    expect(find.byKey(const Key('tile.settings.benchmark')), findsNothing);
  });

  testWidgets('each row leads to its screen', (tester) async {
    for (final (row, route) in [
      ('masterPassword', AppRouter.settingsMasterPassword),
      ('recoveryKey', AppRouter.settingsRecoveryKey),
      ('safeOpensWith', AppRouter.settingsSafePassword),
      ('howItWorks', AppRouter.settingsHowItWorks),
      ('legal', AppRouter.settingsLegal),
    ]) {
      await pumpSettings(tester);
      await tapRow(tester, 'settings.$row');
      expect(find.text('route:$route'), findsOneWidget, reason: row);
      await harness.tearDown();
    }
    await harness.setUp();
  });

  testWidgets('no recovery key kept: the row says so', (tester) async {
    await harness.setUp();
    when(() => harness.chatAuth.hasRecoveryKey())
        .thenAnswer((_) async => const CryptoCoreSuccess(false));
    await harness.pump(
      tester,
      const SettingsPage(),
      surface: const Size(540, 2400),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.accessNoKeyYet), findsOneWidget);
  });

  testWidgets('Lock now locks the whole app', (tester) async {
    await pumpSettings(tester);
    when(() => harness.authStore.lock(byUser: any(named: 'byUser')))
        .thenAnswer((_) async {});
    await tapRow(tester, 'settings.lockNow');
    verify(() => harness.authStore.lock(byUser: true)).called(1);
  });

  testWidgets('Lock the app after: five choices, 5 minutes recommended',
      (tester) async {
    await pumpSettings(tester);
    when(() => harness.autoLockRepository.write(any()))
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    await tapRow(tester, 'settings.autoLock');

    expect(find.text(l10n.accessLockAfterTitle), findsOneWidget);
    expect(
      find.text('${l10n.accessFiveMinutes} · ${l10n.accessRecommended}'),
      findsOneWidget,
    );
    for (final name in [
      l10n.accessRightAway,
      l10n.accessOneMinute,
      l10n.accessFifteenMinutes,
      l10n.accessOneHour,
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text(l10n.accessOneHour));
    await tester.pumpAndSettle();
    verify(
      () => harness.autoLockRepository
          .write(AutoLockSettings.lockAfterChoices.last),
    ).called(1);
    expect(find.text(l10n.accessLockAfter(l10n.accessOneHour)), findsOneWidget);
  });

  testWidgets(
      'Copy passwords is a real switch: kept on the device, and the guard '
      'refuses a My safe password while it is off', (tester) async {
    await pumpSettings(tester);
    expect(find.text(l10n.accessClearsAfter30), findsOneWidget);
    expect(const CopyPolicy().allows(CopyContent.vaultPassword), isTrue);

    await tester
        .ensureVisible(find.byKey(const Key('toggle.settings.copyPasswords')));
    await tester.tap(find.byKey(const Key('toggle.settings.copyPasswords')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.accessOff), findsOneWidget);
    expect(vaultPasswordCopySetting.value, isFalse);
    expect(sl.get<PreferencesService>().vaultPasswordCopy, isFalse);
    expect(const CopyPolicy().allows(CopyContent.vaultPassword), isFalse);
    expect(
      await ClipboardGuard().copy('secret', CopyContent.vaultPassword),
      isFalse,
    );
  });

  testWidgets('fingerprint: not on this device', (tester) async {
    await pumpSettings(tester, canUseBiometrics: false);
    expect(find.text(l10n.accessNotOnThisDevice), findsOneWidget);
    final toggle = tester.widget<FuzzzyToggle>(
      find.ancestor(
        of: find.byKey(const Key('toggle.settings.biometric')),
        matching: find.byType(FuzzzyToggle),
      ),
    );
    expect(toggle.onChanged, isNull);
  });

  testWidgets(
      'fingerprint on: the master password once, then the device; a wrong '
      'one says so in place', (tester) async {
    await pumpSettings(tester);
    when(() => harness.chatAuth.unlock('wrong')).thenAnswer(
      (_) async => const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
    );
    when(() => harness.chatAuth.unlock('pw'))
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => harness.biometrics.enable(BiometricScope.chat, 'pw'))
        .thenAnswer((_) async => BiometricEnableResult.enabled);
    when(
      () =>
          harness.authStore.setBiometricEnabled(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async {});

    await tester.tap(find.byKey(const Key('toggle.settings.biometric')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accessTurnOnBioTitle), findsOneWidget);
    expect(
      SensitiveScreen.isIn(tester.element(kitField('biometric.password'))),
      isTrue,
    );

    await tester.enterText(kitField('biometric.password'), 'wrong');
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn.biometric.submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accessWrongPassword), findsOneWidget);

    await tester.enterText(kitField('biometric.password'), 'pw');
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn.biometric.submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accessTurnOnBioTitle), findsNothing);
    verify(() => harness.biometrics.enable(BiometricScope.chat, 'pw'))
        .called(1);
    verify(() => harness.authStore.setBiometricEnabled(enabled: true))
        .called(1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('My safe with its own password gets its own fingerprint switch',
      (tester) async {
    await pumpSettings(
      tester,
      vaultState: const VaultAuthState(
        authState: VaultAuthEnum.locked,
        usesOwnPassword: true,
      ),
    );
    expect(find.text(l10n.accessItsOwnPassword), findsOneWidget);
    expect(
      find.byKey(const Key('tile.settings.safeBiometric')),
      findsOneWidget,
    );
  });

  testWidgets(
      'Fuzzzy Cast on shows Soft sounds, honestly marked as coming in an '
      'update', (tester) async {
    await pumpSettings(tester, castOn: true);
    expect(find.text(l10n.softSounds), findsOneWidget);
    expect(find.text(l10n.accessSoftSoundsSoon), findsOneWidget);
  });

  forEveryLook('Settings fits', (tester, skin, reduceMotion, textScale) async {
    await pumpSettings(
      tester,
      skin: skin,
      reduceMotion: reduceMotion,
      textScale: textScale,
    );
    expect(find.byKey(const Key('settings.version')), findsOneWidget);
  });
}
