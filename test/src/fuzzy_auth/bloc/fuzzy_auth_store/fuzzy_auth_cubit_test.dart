import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
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

class MockAppLockThrottleRepository extends Mock
    implements AppLockThrottleRepository {}

void main() {
  late MockUserAuthPreferencesRepository mockPrefsRepo;
  late MockCryptoStoreKeyRepository mockStoreKeyRepo;
  late MockCryptoCoreService mockService;
  late MockBiometricAuthRepository mockBiometricRepo;
  late MockAppLockThrottleRepository mockThrottleRepo;
  late ChatAuthRepository chatAuthRepository;

  final wrapped = Uint8List.fromList(List.filled(103, 0x10));

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      UserAuthPreferences(isAuthenticationOnceEnabled: false),
    );
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(AppLockThrottleData.none);
  });

  setUp(() {
    mockPrefsRepo = MockUserAuthPreferencesRepository();
    mockStoreKeyRepo = MockCryptoStoreKeyRepository();
    mockService = MockCryptoCoreService();
    mockBiometricRepo = MockBiometricAuthRepository();
    mockThrottleRepo = MockAppLockThrottleRepository();

    when(() => mockThrottleRepo.read())
        .thenAnswer((_) async => AppLockThrottleData.none);
    when(() => mockThrottleRepo.save(any())).thenAnswer((_) async {});
    when(() => mockThrottleRepo.clear()).thenAnswer((_) async {});
    when(() => mockBiometricRepo.discardOutdatedCopy(any()))
        .thenAnswer((_) async => false);
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
        appLockThrottleRepository: mockThrottleRepo,
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

    // Security review 2026-10-22, item 2: an Android copy made under the old
    // key settings is dropped once and the unlock page says so.
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'an outdated biometric copy is dropped: locked, biometrics off and the '
      'one-time notice',
      setUp: () {
        when(() => mockPrefsRepo.getUserAuthPreferences()).thenAnswer(
          (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
        );
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
        when(() => mockBiometricRepo.discardOutdatedCopy(BiometricScope.chat))
            .thenAnswer((_) async => true);
        when(() => mockBiometricRepo.isEnabled(BiometricScope.chat))
            .thenAnswer((_) async => false);
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.biometricEnabled, 'biometricEnabled', false)
            .having((s) => s.biometricReset, 'biometricReset', true),
      ],
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

  // -----------------------------------------------------------------------
  // Wrong-password waits (security review 2026-10-22, item 6). The real
  // repository over the in-memory secure storage, time from fake_async.
  // -----------------------------------------------------------------------
  group('wrong-password waits', () {
    final start = DateTime(2026, 10, 22, 12);
    late AppLockThrottleRepository throttleRepo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      throttleRepo = AppLockThrottleRepository(
        localDataSource: AppLockThrottleLocalDataSource(),
      );
      when(() => mockService.openStore(wrapped: wrapped, password: 'bad'))
          .thenAnswer(
        (_) async =>
            const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
      );
      when(() => mockService.openStore(wrapped: wrapped, password: 'pw'))
          .thenAnswer((_) async => const CryptoCoreSuccess(null));
    });

    FuzzyAuthStore buildTimedStore(FakeAsync async) => FuzzyAuthStore(
          chatAuthRepository: chatAuthRepository,
          biometricAuthRepository: mockBiometricRepo,
          cryptoStoreKeyRepository: mockStoreKeyRepo,
          cryptoCoreService: mockService,
          appLockThrottleRepository: throttleRepo,
          now: () => start.add(async.elapsed),
        );

    void failTimes(FuzzyAuthStore store, FakeAsync async, int times) {
      for (var i = 0; i < times; i++) {
        store.unlock('bad');
        async.flushMicrotasks();
      }
    }

    AppLockThrottleData stored(FakeAsync async) {
      late AppLockThrottleData data;
      throttleRepo.read().then((value) => data = value);
      async.flushMicrotasks();
      return data;
    }

    test('four wrong passwords cost nothing; the fifth starts a 30 s wait', () {
      fakeAsync((async) {
        final store = buildTimedStore(async);

        failTimes(store, async, 4);
        expect(store.state.status, AuthStateStatus.locked);
        expect(store.state.verificationFailed, isTrue);
        expect(store.state.isLockedOut, isFalse);

        failTimes(store, async, 1);
        expect(store.state.lockoutRemaining, const Duration(seconds: 30));
        expect(stored(async).failedAttempts, 5);

        store.close();
        async.flushMicrotasks();
      });
    });

    test(
        'during the wait even the right password is not tried; the wait '
        'counts down, then the password opens and the count is cleared', () {
      fakeAsync((async) {
        final store = buildTimedStore(async);
        failTimes(store, async, 5);

        store.unlock('pw');
        async.flushMicrotasks();
        expect(store.state.status, AuthStateStatus.locked);
        verifyNever(
          () => mockService.openStore(wrapped: wrapped, password: 'pw'),
        );

        async.elapse(const Duration(seconds: 10));
        expect(store.state.lockoutRemaining, const Duration(seconds: 20));

        async.elapse(const Duration(seconds: 20));
        expect(store.state.isLockedOut, isFalse);

        store.unlock('pw');
        async.flushMicrotasks();
        expect(store.state.status, AuthStateStatus.authenticated);
        expect(stored(async), AppLockThrottleData.none);

        store.close();
        async.flushMicrotasks();
      });
    });

    test('the waits grow: one minute after the sixth, two after the seventh',
        () {
      fakeAsync((async) {
        final store = buildTimedStore(async);
        failTimes(store, async, 5);

        async.elapse(const Duration(seconds: 30));
        failTimes(store, async, 1);
        expect(store.state.lockoutRemaining, const Duration(minutes: 1));

        async.elapse(const Duration(minutes: 1));
        failTimes(store, async, 1);
        expect(store.state.lockoutRemaining, const Duration(minutes: 2));

        store.close();
        async.flushMicrotasks();
      });
    });

    test('the wait survives a restart: a new store reads it at boot', () {
      fakeAsync((async) {
        final first = buildTimedStore(async);
        failTimes(first, async, 5);
        first.close();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 12));

        when(() => mockStoreKeyRepo.ensureStoreKey(''))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
        when(() => mockPrefsRepo.getUserAuthPreferences()).thenAnswer(
          (_) async => UserAuthPreferences(isAuthenticationOnceEnabled: true),
        );
        when(() => mockService.openStore(wrapped: wrapped, password: ''))
            .thenAnswer(
          (_) async =>
              const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
        );
        when(() => mockBiometricRepo.isEnabled(BiometricScope.chat))
            .thenAnswer((_) async => false);

        final second = buildTimedStore(async);
        second.checkAuthStatus();
        async.flushMicrotasks();
        expect(second.state.status, AuthStateStatus.locked);
        expect(second.state.lockoutRemaining, const Duration(seconds: 18));

        second.unlock('pw');
        async.flushMicrotasks();
        expect(second.state.status, AuthStateStatus.locked);
        verifyNever(
          () => mockService.openStore(wrapped: wrapped, password: 'pw'),
        );

        second.close();
        async.flushMicrotasks();
      });
    });

    test('a biometric unlock during the wait gets in and clears the count', () {
      fakeAsync((async) {
        when(() => mockBiometricRepo.readPassword(BiometricScope.chat))
            .thenAnswer((_) async => const BiometricPassword('pw'));
        final store = buildTimedStore(async);
        failTimes(store, async, 5);
        expect(store.state.isLockedOut, isTrue);

        store.unlockWithBiometrics();
        async.flushMicrotasks();
        expect(store.state.status, AuthStateStatus.authenticated);
        expect(store.state.isLockedOut, isFalse);
        expect(stored(async), AppLockThrottleData.none);

        store.close();
        async.flushMicrotasks();
      });
    });

    // Security review follow-up: concurrent submits must not share one
    // snapshot of the count. Checks are held open with Completers.
    List<Completer<CryptoCoreResponse<void>>> holdWrongChecks() {
      final checks = <Completer<CryptoCoreResponse<void>>>[];
      when(() => mockService.openStore(wrapped: wrapped, password: 'bad'))
          .thenAnswer((_) {
        final check = Completer<CryptoCoreResponse<void>>();
        checks.add(check);
        return check.future;
      });
      return checks;
    }

    const wrong = CryptoCoreFailure<void>(CryptoCoreFailureType.wrongPassword);

    test(
        'submits while a password is checked are ignored: each password '
        'tried counts once, and the fifth tried starts the wait', () {
      fakeAsync((async) {
        final checks = holdWrongChecks();
        when(() => mockBiometricRepo.readPassword(BiometricScope.chat))
            .thenAnswer((_) async => const BiometricPassword('bad'));
        final store = buildTimedStore(async);

        for (var round = 1; round <= 5; round++) {
          for (var submit = 0; submit < 4; submit++) {
            store.unlock('bad');
          }
          store.unlockWithBiometrics();
          async.flushMicrotasks();
          expect(checks, hasLength(round), reason: 'round $round');
          expect(store.state.status, AuthStateStatus.unlocking);

          checks.last.complete(wrong);
          async.flushMicrotasks();
          expect(stored(async).failedAttempts, round);
        }
        expect(store.state.lockoutRemaining, const Duration(seconds: 30));

        store.close();
        async.flushMicrotasks();
      });
    });

    test(
        'wrong passwords whose checks overlap all count: the count is read '
        'again after each check, so the wait starts at the fifth', () {
      fakeAsync((async) {
        final checks = holdWrongChecks();
        final stores = List.generate(5, (_) => buildTimedStore(async));

        for (final store in stores) {
          store.unlock('bad');
        }
        async.flushMicrotasks();
        expect(checks, hasLength(5));
        expect(stored(async), AppLockThrottleData.none);

        for (var index = 0; index < 5; index++) {
          checks[index].complete(wrong);
          async.flushMicrotasks();
          expect(stored(async).failedAttempts, index + 1);
        }
        expect(stores.last.state.lockoutRemaining, const Duration(seconds: 30));
        for (final store in stores.take(4)) {
          expect(store.state.isLockedOut, isFalse);
        }

        for (final store in stores) {
          store.close();
        }
        async.flushMicrotasks();
      });
    });

    test('an existing one-character password still unlocks', () {
      fakeAsync((async) {
        when(() => mockService.openStore(wrapped: wrapped, password: 'a'))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
        final store = buildTimedStore(async);

        store.unlock('a');
        async.flushMicrotasks();
        expect(store.state.status, AuthStateStatus.authenticated);

        store.close();
        async.flushMicrotasks();
      });
    });
  });

  // -----------------------------------------------------------------------
  // unlockWithBiometrics: only a copy that is gone turns biometrics off
  // -----------------------------------------------------------------------
  group('unlockWithBiometrics', () {
    setUp(() {
      when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});
    });

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a cancelled prompt or a locked-out sensor keeps biometrics on',
      setUp: () {
        when(() => mockBiometricRepo.readPassword(BiometricScope.chat))
            .thenAnswer((_) async => const BiometricNotRead());
      },
      build: buildStore,
      seed: () => const FuzzyAuthState.initial().copyWith(
        status: AuthStateStatus.locked,
        biometricEnabled: true,
      ),
      act: (store) => store.unlockWithBiometrics(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.unlocking),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.biometricEnabled, 'biometricEnabled', true)
            .having((s) => s.biometricInvalidated, 'invalidated', false)
            .having((s) => s.verificationFailed, 'verificationFailed', false),
      ],
      verify: (_) {
        verifyNever(() => mockBiometricRepo.disable(any()));
        verifyNever(() => mockThrottleRepo.save(any()));
      },
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a copy that is gone (new enrolment) turns biometrics off and says so',
      setUp: () {
        when(() => mockBiometricRepo.readPassword(BiometricScope.chat))
            .thenAnswer((_) async => const BiometricCopyGone());
      },
      build: buildStore,
      seed: () => const FuzzyAuthState.initial().copyWith(
        status: AuthStateStatus.locked,
        biometricEnabled: true,
      ),
      act: (store) => store.unlockWithBiometrics(),
      skip: 1,
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.biometricEnabled, 'biometricEnabled', false)
            .having((s) => s.biometricInvalidated, 'invalidated', true),
      ],
      verify: (_) {
        verify(() => mockBiometricRepo.disable(BiometricScope.chat)).called(1);
      },
    );
  });
}
