import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockUserAuthPreferencesRepository extends Mock
    implements UserAuthPreferencesRepository {}

class MockCryptoStoreKeyRepository extends Mock
    implements CryptoStoreKeyRepository {}

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

/// The real router's top-level `redirect` against a real [FuzzyAuthStore]
/// walking the boot sequence (T-0329): protected routes are gated while the
/// store is still opening (`initial`), exactly as when it is `locked`.
void main() {
  late MockUserAuthPreferencesRepository mockPrefsRepo;
  late MockCryptoStoreKeyRepository mockStoreKeyRepo;
  late MockCryptoCoreService mockService;
  late FuzzyAuthStore store;
  late GoRouter router;

  final wrapped = Uint8List.fromList(List.filled(103, 0x10));

  setUpAll(() async {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(BiometricScope.chat);

    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    sl.safeRegisterSingleton<PreferencesService>(
      PreferencesService(await SharedPreferences.getInstance()),
    );

    mockPrefsRepo = MockUserAuthPreferencesRepository();
    mockStoreKeyRepo = MockCryptoStoreKeyRepository();
    mockService = MockCryptoCoreService();
    when(() => mockStoreKeyRepo.ensureStoreKey(''))
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => mockStoreKeyRepo.read())
        .thenAnswer((_) async => CryptoCoreSuccess(wrapped));
    when(() => mockPrefsRepo.getUserAuthPreferences())
        .thenAnswer((_) async => null);
    when(() => mockService.openStore(wrapped: wrapped, password: ''))
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => mockService.close())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));

    store = FuzzyAuthStore(
      chatAuthRepository: ChatAuthRepository(
        userAuthPreferencesRepository: mockPrefsRepo,
        cryptoStoreKeyRepository: mockStoreKeyRepo,
        cryptoCoreService: mockService,
      ),
      biometricAuthRepository: MockBiometricAuthRepository(),
      cryptoStoreKeyRepository: mockStoreKeyRepo,
      cryptoCoreService: mockService,
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
      'initial gates every protected route to the unlock page; '
      'unprotected routes stay', (tester) async {
    expect(store.state.status, AuthStateStatus.initial);

    expect(await redirectFor(tester, AppRouter.home), AppRouter.chatUnlock);
    expect(
      await redirectFor(tester, AppRouter.chatConnected),
      AppRouter.chatUnlock,
    );
    expect(
      await redirectFor(tester, AppRouter.vaultHome),
      AppRouter.chatUnlock,
    );
    expect(await redirectFor(tester, AppRouter.settings), isNull);
    expect(await redirectFor(tester, AppRouter.aboutEncryption), isNull);
    expect(await redirectFor(tester, AppRouter.chatUnlock), isNull);
  });

  testWidgets(
      'once the store is open nothing is gated and the unlock page '
      'bounces home', (tester) async {
    await store.checkAuthStatus();
    expect(store.state.status, AuthStateStatus.noAuthRequired);

    expect(await redirectFor(tester, AppRouter.home), isNull);
    expect(await redirectFor(tester, AppRouter.chatConnected), isNull);
    expect(await redirectFor(tester, AppRouter.chatUnlock), AppRouter.home);
  });

  testWidgets('locking gates again', (tester) async {
    await store.lock();
    expect(store.state.status, AuthStateStatus.locked);

    expect(await redirectFor(tester, AppRouter.home), AppRouter.chatUnlock);
    expect(await redirectFor(tester, AppRouter.chatUnlock), isNull);
  });
}
