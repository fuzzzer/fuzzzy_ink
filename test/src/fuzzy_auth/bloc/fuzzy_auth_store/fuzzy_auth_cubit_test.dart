import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:mocktail/mocktail.dart';

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

void main() {
  late MockUserAuthPreferencesRepository mockPrefsRepo;
  late MockCryptoStoreKeyRepository mockStoreKeyRepo;
  late MockCryptoCoreService mockService;
  late MockBiometricAuthRepository mockBiometricRepo;
  late ChatAuthRepository chatAuthRepository;

  final wrapped = Uint8List.fromList(List.filled(103, 0x10));

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      UserAuthPreferences(isAuthenticationOnceEnabled: false),
    );
    registerFallbackValue(BiometricScope.chat);
  });

  setUp(() {
    mockPrefsRepo = MockUserAuthPreferencesRepository();
    mockStoreKeyRepo = MockCryptoStoreKeyRepository();
    mockService = MockCryptoCoreService();
    mockBiometricRepo = MockBiometricAuthRepository();

    when(() => mockStoreKeyRepo.read())
        .thenAnswer((_) async => CryptoCoreSuccess(wrapped));
    when(() => mockService.close())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));

    chatAuthRepository = ChatAuthRepository(
      userAuthPreferencesRepository: mockPrefsRepo,
      cryptoStoreKeyRepository: mockStoreKeyRepo,
      cryptoCoreService: mockService,
    );
  });

  FuzzyAuthStore buildStore() => FuzzyAuthStore(
        chatAuthRepository: chatAuthRepository,
        biometricAuthRepository: mockBiometricRepo,
        cryptoStoreKeyRepository: mockStoreKeyRepo,
        cryptoCoreService: mockService,
      );

  // -----------------------------------------------------------------------
  // unlock
  // -----------------------------------------------------------------------
  group('unlock', () {
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'emits [unlocking, authenticated] when the service opens the store',
      setUp: () {
        when(() => mockService.openStore(wrapped: wrapped, password: 'pw'))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      act: (store) => store.unlock('pw'),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.unlocking),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.authenticated)
            .having((s) => s.authData.password, 'password', 'pw')
            .having((s) => s.verificationFailed, 'verificationFailed', false),
      ],
      verify: (_) {
        verify(() => mockService.openStore(wrapped: wrapped, password: 'pw'))
            .called(1);
      },
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'emits [unlocking, locked + verificationFailed] on wrongPassword',
      setUp: () {
        when(() => mockService.openStore(wrapped: wrapped, password: 'bad'))
            .thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
      },
      build: buildStore,
      act: (store) => store.unlock('bad'),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.unlocking),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.verificationFailed, 'verificationFailed', true)
            .having((s) => s.authData.password, 'password', ''),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'never calls the service when no store key exists',
      setUp: () {
        when(() => mockStoreKeyRepo.read())
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      act: (store) => store.unlock('pw'),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.unlocking),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.verificationFailed, 'verificationFailed', true),
      ],
      verify: (_) {
        verifyNever(
          () => mockService.openStore(
            wrapped: any(named: 'wrapped'),
            password: any(named: 'password'),
          ),
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // checkAuthStatus
  // -----------------------------------------------------------------------
  group('checkAuthStatus', () {
    setUp(() {
      when(() => mockStoreKeyRepo.ensureStoreKey(''))
          .thenAnswer((_) async => const CryptoCoreSuccess(null));
      when(() => mockPrefsRepo.updateUserAuthPreferences(any()))
          .thenAnswer((_) async {});
    });

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'with the lock disabled ensures the store key and opens the store '
      'under the empty password',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences())
            .thenAnswer((_) async => null);
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.noAuthRequired)
            .having((s) => s.biometricEnabled, 'biometricEnabled', false),
      ],
      verify: (_) {
        verifyInOrder([
          () => mockStoreKeyRepo.ensureStoreKey(''),
          () => mockService.openStore(wrapped: wrapped, password: ''),
        ]);
        verifyNever(() => mockPrefsRepo.updateUserAuthPreferences(any()));
      },
    );

    // T-0329: the boot window is `initial` — no access until the store is
    // open, then exactly one transition to an access-bearing status.
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'boots without access and gains it only once the store is open',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences())
            .thenAnswer((_) async => null);
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      act: (store) {
        expect(store.state.status, AuthStateStatus.initial);
        expect(store.state.status.hasAccess, isFalse);
        return store.checkAuthStatus();
      },
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.noAuthRequired)
            .having((s) => s.status.hasAccess, 'hasAccess', true),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'with the lock disabled still reaches noAuthRequired when secure '
      'storage fails',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences())
            .thenAnswer((_) async => null);
        when(() => mockStoreKeyRepo.ensureStoreKey('')).thenAnswer(
          (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
        );
        when(() => mockStoreKeyRepo.read()).thenAnswer(
          (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
        );
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.noAuthRequired),
      ],
      verify: (_) {
        verifyNever(
          () => mockService.openStore(
            wrapped: any(named: 'wrapped'),
            password: any(named: 'password'),
          ),
        );
        verifyNever(() => mockPrefsRepo.updateUserAuthPreferences(any()));
      },
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'with the lock enabled emits locked once the blob refuses the empty '
      'password',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences()).thenAnswer(
          (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
        );
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
        when(() => mockBiometricRepo.isEnabled(BiometricScope.chat))
            .thenAnswer((_) async => true);
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.biometricEnabled, 'biometricEnabled', true),
      ],
      verify: (_) {
        verify(() => mockService.openStore(wrapped: wrapped, password: ''))
            .called(1);
        verifyNever(() => mockPrefsRepo.updateUserAuthPreferences(any()));
      },
    );

    // The blob is the truth, the preference a cache (F2-6 review R1): each
    // inconsistent state is what a kill between the two writes of
    // enable / disable leaves behind.
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'preference disabled but blob under a password → locked and the '
      'preference is repaired (kill after the enable rewrap)',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences())
            .thenAnswer((_) async => null);
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
        when(() => mockBiometricRepo.isEnabled(BiometricScope.chat))
            .thenAnswer((_) async => false);
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked),
      ],
      verify: (_) {
        final repaired = verify(
          () => mockPrefsRepo.updateUserAuthPreferences(captureAny()),
        ).captured.single as UserAuthPreferences;
        expect(repaired.isAuthenticationOnceEnabled, isTrue);
      },
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'preference enabled but blob opens without a password → noAuthRequired '
      'and the preference is repaired (kill after the disable rewrap)',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences()).thenAnswer(
          (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
        );
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.noAuthRequired)
            .having((s) => s.biometricEnabled, 'biometricEnabled', false),
      ],
      verify: (_) {
        final repaired = verify(
          () => mockPrefsRepo.updateUserAuthPreferences(captureAny()),
        ).captured.single as UserAuthPreferences;
        expect(repaired.isAuthenticationOnceEnabled, isFalse);
        verifyNever(() => mockBiometricRepo.isEnabled(any()));
      },
    );
  });

  // -----------------------------------------------------------------------
  // lock
  // -----------------------------------------------------------------------
  group('lock', () {
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'closes the store and emits locked with an empty password',
      setUp: () {
        when(() => mockService.openStore(wrapped: wrapped, password: 'pw'))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      act: (store) async {
        await store.unlock('pw');
        await store.lock();
      },
      skip: 2,
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.authData.password, 'password', ''),
      ],
      verify: (_) {
        verify(() => mockService.close()).called(1);
      },
    );
  });
}
