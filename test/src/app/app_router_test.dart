import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockChatAuthRepository extends Mock implements ChatAuthRepository {}

class MockAppResetRepository extends Mock implements AppResetRepository {}

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

class MockAppLockThrottleRepository extends Mock
    implements AppLockThrottleRepository {}

/// The real router's top-level `redirect` against a real [FuzzyAuthStore]
/// walking the boot sequence (T-0329): protected routes are gated while the
/// secure storage is still read (`initial`), exactly as when it is `locked`.
/// There is no state without a master password: the first run, a storage
/// error and the lock all gate everything but their own pages.
void main() {
  late MockChatAuthRepository mockChatAuth;
  late MockCryptoCoreService mockService;
  late MockBiometricAuthRepository mockBiometric;
  late MockAppLockThrottleRepository mockThrottle;
  late FuzzyAuthStore store;
  late GoRouter router;

  setUpAll(() async {
    registerFallbackValue(BiometricScope.chat);

    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    sl.safeRegisterSingleton<PreferencesService>(
      PreferencesService(await SharedPreferences.getInstance()),
    );

    mockChatAuth = MockChatAuthRepository();
    mockService = MockCryptoCoreService();
    mockBiometric = MockBiometricAuthRepository();
    mockThrottle = MockAppLockThrottleRepository();
    when(() => mockService.close())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => mockChatAuth.hasLegacyData())
        .thenAnswer((_) async => const CryptoCoreSuccess(false));
    when(() => mockChatAuth.unlock('pw'))
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => mockBiometric.discardOutdatedCopy(any()))
        .thenAnswer((_) async => false);
    when(() => mockBiometric.isEnabled(any())).thenAnswer((_) async => false);
    when(() => mockBiometric.biometricKind())
        .thenAnswer((_) async => BiometricKind.other);
    when(() => mockThrottle.read())
        .thenAnswer((_) async => AppLockThrottleData.none);
    when(() => mockThrottle.clear()).thenAnswer((_) async {});

    store = FuzzyAuthStore(
      chatAuthRepository: mockChatAuth,
      biometricAuthRepository: mockBiometric,
      cryptoCoreService: mockService,
      appLockThrottleRepository: mockThrottle,
      appResetRepository: MockAppResetRepository(),
    );
    sl.safeRegisterSingleton<FuzzyAuthStore>(store);

    router = AppRouter.router(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
    );
  });

  Future<String?> redirectFor(WidgetTester tester, String location) async {
    await tester.pumpWidget(const Placeholder());
    final context = tester.element(find.byType(Placeholder));
    return router.configuration.topRedirect(
      context,
      GoRouterState(
        router.configuration,
        uri: Uri.parse(location),
        matchedLocation: location,
        fullPath: location,
        pathParameters: const {},
        pageKey: ValueKey(location),
      ),
    );
  }

  testWidgets(
      'initial gates every protected route to the unlock page, settings and '
      'Basics included; only the unlock, setup, recovery and about pages stay',
      (tester) async {
    expect(store.state.status, AuthStateStatus.initial);

    for (final location in [
      AppRouter.home,
      AppRouter.person,
      AppRouter.vaultHome,
      AppRouter.settings,
      AppRouter.settingsMasterPassword,
      AppRouter.settingsRecoveryKey,
      AppRouter.settingsSafePassword,
      AppRouter.settingsHowItWorks,
      AppRouter.settingsLegal,
      AppRouter.basics,
    ]) {
      expect(await redirectFor(tester, location), AppRouter.chatUnlock);
    }
    expect(await redirectFor(tester, AppRouter.aboutEncryption), isNull);
    expect(await redirectFor(tester, AppRouter.chatUnlock), isNull);
    expect(await redirectFor(tester, AppRouter.recover), isNull);
    expect(await redirectFor(tester, AppRouter.setup), AppRouter.chatUnlock);
  });

  testWidgets('no master password yet: every route leads to the first run',
      (tester) async {
    when(() => mockChatAuth.status()).thenAnswer(
      (_) async => const CryptoCoreSuccess(MasterKeyStatus.notSetUp),
    );
    await store.checkAuthStatus();
    expect(store.state.status, AuthStateStatus.setupRequired);

    expect(await redirectFor(tester, AppRouter.home), AppRouter.setup);
    expect(await redirectFor(tester, AppRouter.chatUnlock), AppRouter.setup);
    expect(await redirectFor(tester, AppRouter.basics), AppRouter.setup);
    expect(await redirectFor(tester, AppRouter.setup), isNull);
  });

  testWidgets(
      'a new install: the welcome is final while unseen (no loop through the '
      'first run), and once seen it hands over to the first run',
      (tester) async {
    final preferences = sl.get<PreferencesService>();
    await preferences.setHasSeenOnboarding(false);
    expect(store.state.status, AuthStateStatus.setupRequired);

    expect(await redirectFor(tester, AppRouter.onboarding), isNull);
    expect(await redirectFor(tester, AppRouter.home), AppRouter.onboarding);
    expect(await redirectFor(tester, AppRouter.setup), AppRouter.onboarding);
    expect(
      await redirectFor(tester, AppRouter.chatUnlock),
      AppRouter.onboarding,
    );

    // Next on "How it works", or the boot check landing meanwhile.
    await preferences.setHasSeenOnboarding(true);
    expect(await redirectFor(tester, AppRouter.setup), isNull);
    expect(await redirectFor(tester, AppRouter.onboarding), AppRouter.home);
    expect(await redirectFor(tester, AppRouter.home), AppRouter.setup);
  });

  testWidgets('a secure storage error fails closed', (tester) async {
    when(() => mockChatAuth.status()).thenAnswer(
      (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
    );
    await store.checkAuthStatus();
    expect(store.state.status, AuthStateStatus.storageUnavailable);

    expect(await redirectFor(tester, AppRouter.home), AppRouter.chatUnlock);
    expect(await redirectFor(tester, AppRouter.chatUnlock), isNull);
  });

  testWidgets(
      'once the master password opened the store nothing is gated and the '
      'unlock, recovery and setup pages bounce home', (tester) async {
    when(() => mockChatAuth.status()).thenAnswer(
      (_) async => const CryptoCoreSuccess(MasterKeyStatus.ready),
    );
    await store.checkAuthStatus();
    expect(store.state.status, AuthStateStatus.locked);
    await store.unlock('pw');
    expect(store.state.status, AuthStateStatus.authenticated);

    expect(await redirectFor(tester, AppRouter.home), isNull);
    expect(await redirectFor(tester, AppRouter.person), isNull);
    expect(await redirectFor(tester, AppRouter.chatUnlock), AppRouter.home);
    expect(await redirectFor(tester, AppRouter.recover), AppRouter.home);
    expect(await redirectFor(tester, AppRouter.setup), AppRouter.home);
  });

  testWidgets('locking gates again', (tester) async {
    await store.lock();
    expect(store.state.status, AuthStateStatus.locked);

    expect(await redirectFor(tester, AppRouter.home), AppRouter.chatUnlock);
    expect(await redirectFor(tester, AppRouter.chatUnlock), isNull);
  });

  testWidgets(
      'the access screens that show a password or a key are private: '
      'unlock, recovery, and the three Settings screens; the first run wraps '
      'its own password and key steps', (tester) async {
    await tester.pumpWidget(const Placeholder());
    final context = tester.element(find.byType(Placeholder));
    Widget built(String path) {
      final route = router.configuration.routes
          .whereType<GoRoute>()
          .firstWhere((route) => route.path == path);
      return route.builder!(
        context,
        GoRouterState(
          router.configuration,
          uri: Uri.parse(path),
          matchedLocation: path,
          fullPath: path,
          pathParameters: const {},
          pageKey: ValueKey(path),
        ),
      );
    }

    for (final path in [
      AppRouter.chatUnlock,
      AppRouter.recover,
      AppRouter.settingsMasterPassword,
      AppRouter.settingsRecoveryKey,
      AppRouter.settingsSafePassword,
    ]) {
      expect(built(path), isA<SensitiveScreen>(), reason: path);
    }
    expect(built(AppRouter.setup), isA<MasterPasswordSetupPage>());
    for (final path in [
      AppRouter.settingsHowItWorks,
      AppRouter.settingsLegal,
    ]) {
      expect(built(path), isNot(isA<SensitiveScreen>()), reason: path);
    }
  });
}
