import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'redesign_harness.dart';

export 'redesign_harness.dart';

class MockFuzzyAuthStore extends MockCubit<FuzzyAuthState>
    implements FuzzyAuthStore {}

class MockVaultAuthCubit extends MockCubit<VaultAuthState>
    implements VaultAuthCubit {}

class MockAutoLockSettingsRepository extends Mock
    implements AutoLockSettingsRepository {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

class MockChatAuthRepository extends Mock implements ChatAuthRepository {}

class MockVaultRepository extends Mock implements VaultRepository {}

/// Records Print and Save as file instead of handing anything over.
class FakeRecoveryKeyExport extends RecoveryKeyExport {
  FakeRecoveryKeyExport({this.saveAnswer = true, this.printable = true});

  bool saveAnswer;
  final bool printable;
  final saved = <String>[];
  int prints = 0;

  @override
  bool get canPrint => printable;

  @override
  Future<bool> saveAsFile(
    BuildContext context, {
    required String text,
    required String dialogTitle,
  }) async {
    saved.add(text);
    return saveAnswer;
  }

  @override
  Future<bool> printSheet(
    BuildContext context, {
    required GlobalKey sheetKey,
  }) async {
    prints++;
    return true;
  }
}

/// Where an access screen may send the person; each shows `route:<path>`.
const accessDestinations = [
  AppRouter.home,
  AppRouter.settings,
  AppRouter.onboarding,
  AppRouter.setup,
  AppRouter.chatUnlock,
  AppRouter.recover,
  AppRouter.aboutEncryption,
  AppRouter.settingsMasterPassword,
  AppRouter.settingsRecoveryKey,
  AppRouter.settingsSafePassword,
  AppRouter.settingsHowItWorks,
  AppRouter.settingsLegal,
];

/// The mocks and cubits an access screen reads, ready for a test to stub.
class AccessHarness {
  AccessHarness() {
    authStore = MockFuzzyAuthStore();
    vault = MockVaultAuthCubit();
    autoLockRepository = MockAutoLockSettingsRepository();
    biometrics = MockBiometricAuthRepository();
    chatAuth = MockChatAuthRepository();
    vaultRepository = MockVaultRepository();
  }

  late final MockFuzzyAuthStore authStore;
  late final MockVaultAuthCubit vault;
  late final MockAutoLockSettingsRepository autoLockRepository;
  late final MockBiometricAuthRepository biometrics;
  late final MockChatAuthRepository chatAuth;
  late final MockVaultRepository vaultRepository;
  late AutoLockCubit autoLock;

  /// The locked state the lock screen starts from.
  static final locked =
      const FuzzyAuthState.initial().copyWith(status: AuthStateStatus.locked);

  /// Registers the services the access screens take from the locator; the
  /// test's tearDown calls [tearDown].
  Future<void> setUp({
    FuzzyAuthState? auth,
    Stream<FuzzyAuthState> authChanges = const Stream.empty(),
    VaultAuthState vaultState = const VaultAuthState(),
    Map<String, Object> preferences = const {},
    bool canUseBiometrics = true,
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    sl
      ..safeRegisterSingleton<PreferencesService>(
        PreferencesService(await SharedPreferences.getInstance()),
      )
      ..safeRegisterSingleton<PasswordStrengthService>(
        PasswordStrengthService(),
      )
      ..safeRegisterSingleton<BiometricAuthRepository>(biometrics)
      ..safeRegisterSingleton<ChatAuthRepository>(chatAuth)
      ..safeRegisterSingleton<VaultRepository>(vaultRepository);
    whenListen(authStore, authChanges, initialState: auth ?? locked);
    whenListen(
      vault,
      const Stream<VaultAuthState>.empty(),
      initialState: vaultState,
    );
    when(() => biometrics.canUseBiometrics())
        .thenAnswer((_) async => canUseBiometrics);
    when(() => chatAuth.hasRecoveryKey())
        .thenAnswer((_) async => const CryptoCoreSuccess(true));
    when(() => autoLockRepository.read())
        .thenAnswer((_) async => AutoLockSettings.standard);
    autoLock = AutoLockCubit(repository: autoLockRepository);
  }

  Future<void> tearDown() async {
    await autoLock.close();
    for (final unregister in [
      sl.unregister<PreferencesService>,
      sl.unregister<PasswordStrengthService>,
      sl.unregister<BiometricAuthRepository>,
      sl.unregister<ChatAuthRepository>,
      sl.unregister<VaultRepository>,
    ]) {
      await unregister();
    }
    vaultPasswordCopySetting.value = true;
  }

  /// Hosts [page] the way the app does — the kit theme in [skin], both
  /// languages, the phone's reduce-motion setting and text size, the app's
  /// cubits above the navigator — at `/page` of a router whose other places
  /// ([accessDestinations]) show `route:<path>`. [private] puts the page
  /// below a [SensitiveScreen], as its route does.
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    FuzzzySkin skin = FuzzzySkin.night,
    bool reduceMotion = false,
    bool castOn = false,
    bool private = false,
    double textScale = 1,
    Locale locale = const Locale('en'),
    Size? surface,
  }) async {
    final preferences = sl.get<PreferencesService>();
    await preferences.setFuzzzyCastEnabled(castOn);
    if (surface != null) {
      tester.view.physicalSize = surface * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
    }
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/page',
      routes: [
        GoRoute(
          path: '/page',
          builder: (_, __) => private ? SensitiveScreen(child: page) : page,
        ),
        for (final path in accessDestinations)
          GoRoute(
            path: path,
            builder: (_, __) => Scaffold(body: Text('route:$path')),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FuzzyAuthStore>.value(value: authStore),
          BlocProvider<VaultAuthCubit>.value(value: vault),
          BlocProvider<AutoLockCubit>.value(value: autoLock),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocalizationCubit()),
          BlocProvider(
            create: (_) =>
                FuzzzyCastSettingsCubit(preferencesService: preferences),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: FuzzzyTheme.build(inkPack, skin),
          locale: locale,
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: app!,
          ),
        ),
      ),
    );
    await tester.pump();
  }
}

/// Every look the redesign ships, with reduced motion off and on, at the
/// normal and the largest text size: [body] runs once per combination.
void forEveryLook(
  String description,
  Future<void> Function(
    WidgetTester tester,
    FuzzzySkin skin,
    // A matrix of looks, read in this order by every caller.
    // ignore: avoid_positional_boolean_parameters
    bool reduceMotion,
    double textScale,
  ) body,
) {
  for (final skin in redesignSkins) {
    for (final (reduceMotion, textScale) in [(false, 1.0), (true, 2.0)]) {
      testWidgets(
          '$description (${skin.name}, reduce motion $reduceMotion, '
          'text x$textScale)', (tester) async {
        await body(tester, skin, reduceMotion, textScale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// The kit button whose `qaId` is [qaId] (its key sits on an inner widget).
FuzzzyButton kitButton(WidgetTester tester, String qaId) =>
    tester.widget<FuzzzyButton>(
      find
          .ancestor(
            of: find.byKey(Key('btn.$qaId')),
            matching: find.byType(FuzzzyButton),
          )
          .first,
    );

/// The editable text inside the kit field whose `qaId` is [qaId].
Finder kitField(String qaId) => find.descendant(
      of: find.byKey(Key('field.$qaId')),
      matching: find.byType(EditableText),
    );
