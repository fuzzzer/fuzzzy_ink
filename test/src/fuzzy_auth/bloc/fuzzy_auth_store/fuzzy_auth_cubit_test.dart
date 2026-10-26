import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

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

void main() {
  late MockChatAuthRepository mockChatAuth;
  late MockAppResetRepository mockReset;
  late MockCryptoCoreService mockService;
  late MockBiometricAuthRepository mockBiometricRepo;
  late MockAppLockThrottleRepository mockThrottleRepo;

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
    registerFallbackValue(AppLockThrottleData.none);
  });

  setUp(() {
    mockChatAuth = MockChatAuthRepository();
    mockReset = MockAppResetRepository();
    mockService = MockCryptoCoreService();
    mockBiometricRepo = MockBiometricAuthRepository();
    mockThrottleRepo = MockAppLockThrottleRepository();

    when(() => mockThrottleRepo.read())
        .thenAnswer((_) async => AppLockThrottleData.none);
    when(() => mockThrottleRepo.save(any())).thenAnswer((_) async {});
    when(() => mockThrottleRepo.clear()).thenAnswer((_) async {});
    when(() => mockBiometricRepo.discardOutdatedCopy(any()))
        .thenAnswer((_) async => false);
    when(() => mockBiometricRepo.isEnabled(any()))
        .thenAnswer((_) async => false);
    when(() => mockBiometricRepo.disable(any())).thenAnswer((_) async {});
    when(() => mockService.close())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(() => mockChatAuth.status()).thenAnswer(
      (_) async => const CryptoCoreSuccess(MasterKeyStatus.ready),
    );
    when(() => mockChatAuth.hasLegacyData())
        .thenAnswer((_) async => const CryptoCoreSuccess(false));
  });

  FuzzyAuthStore buildStore() => FuzzyAuthStore(
        chatAuthRepository: mockChatAuth,
        biometricAuthRepository: mockBiometricRepo,
        cryptoCoreService: mockService,
        appLockThrottleRepository: mockThrottleRepo,
        appResetRepository: mockReset,
      );

  // -----------------------------------------------------------------------
  // unlock: the master password opens the store and is never kept
  // -----------------------------------------------------------------------
  group('unlock', () {
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'emits [unlocking, authenticated] when the repository opens the store',
      setUp: () {
        when(() => mockChatAuth.unlock('pw'))
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
      },
      build: buildStore,
      seed: () => const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.locked),
      act: (store) => store.unlock('pw'),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.unlocking),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.authenticated),
      ],
      verify: (_) {
        verify(() => mockChatAuth.unlock('pw')).called(1);
        verify(() => mockThrottleRepo.clear()).called(1);
      },
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'emits [unlocking, locked + verificationFailed] on wrongPassword',
      setUp: () {
        when(() => mockChatAuth.unlock('bad')).thenAnswer(
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
            .having((s) => s.verificationFailed, 'verificationFailed', true),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a secure storage that fails during the unlock fails closed',
      setUp: () {
        when(() => mockChatAuth.unlock('pw')).thenAnswer(
          (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
        );
      },
      build: buildStore,
      act: (store) => store.unlock('pw'),
      skip: 1,
      expect: () => [
        isA<FuzzyAuthState>().having(
          (s) => s.status,
          'status',
          AuthStateStatus.storageUnavailable,
        ),
      ],
      verify: (_) => verifyNever(() => mockThrottleRepo.save(any())),
    );
  });

  // -----------------------------------------------------------------------
  // checkAuthStatus: there is no state without a password, and a secure
  // storage error never opens the app
  // -----------------------------------------------------------------------
  group('checkAuthStatus', () {
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a master password exists → locked, the store is not opened',
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.status.hasAccess, 'hasAccess', isFalse),
      ],
      verify: (_) => verifyNever(() => mockChatAuth.unlock(any())),
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'no master password yet → setupRequired, no access',
      setUp: () {
        when(() => mockChatAuth.status()).thenAnswer(
          (_) async => const CryptoCoreSuccess(MasterKeyStatus.notSetUp),
        );
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.setupRequired)
            .having((s) => s.previousDataFound, 'previousDataFound', isFalse)
            .having((s) => s.status.hasAccess, 'hasAccess', isFalse),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'an install from before the master password → setupRequired with the '
      'fresh-start notice',
      setUp: () {
        when(() => mockChatAuth.status()).thenAnswer(
          (_) async => const CryptoCoreSuccess(MasterKeyStatus.notSetUp),
        );
        when(() => mockChatAuth.hasLegacyData())
            .thenAnswer((_) async => const CryptoCoreSuccess(true));
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.setupRequired)
            .having((s) => s.previousDataFound, 'previousDataFound', isTrue),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a secure storage error at launch fails closed: storageUnavailable, '
      'the store is closed, never the chat list (security review '
      '2026-10-22)',
      setUp: () {
        when(() => mockChatAuth.status()).thenAnswer(
          (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
        );
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having(
              (s) => s.status,
              'status',
              AuthStateStatus.storageUnavailable,
            )
            .having((s) => s.status.hasAccess, 'hasAccess', isFalse),
      ],
      verify: (_) => verify(() => mockService.close()).called(1),
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'an outdated biometric copy is dropped: locked, biometrics off and the '
      'one-time notice',
      setUp: () {
        when(() => mockBiometricRepo.discardOutdatedCopy(BiometricScope.chat))
            .thenAnswer((_) async => true);
      },
      build: buildStore,
      act: (store) => store.checkAuthStatus(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.biometricEnabled, 'biometricEnabled', isFalse)
            .having((s) => s.biometricReset, 'biometricReset', isTrue),
      ],
    );
  });

  // -----------------------------------------------------------------------
  // lock, first run, recovery and erase
  // -----------------------------------------------------------------------
  group('lock', () {
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'closes the store and emits locked',
      build: buildStore,
      seed: () => const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.authenticated),
      act: (store) => store.lock(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.lockedByUser, 'lockedByUser', isFalse),
      ],
      verify: (_) => verify(() => mockService.close()).called(1),
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      "Lock now is marked as the person's own lock until the next unlock",
      setUp: () => when(() => mockChatAuth.unlock('pw'))
          .thenAnswer((_) async => const CryptoCoreSuccess(null)),
      build: buildStore,
      seed: () => const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.authenticated),
      act: (store) async {
        await store.lock(byUser: true);
        await store.unlock('pw');
      },
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.locked)
            .having((s) => s.lockedByUser, 'lockedByUser', isTrue),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.unlocking)
            .having((s) => s.lockedByUser, 'lockedByUser', isTrue),
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.authenticated)
            .having((s) => s.lockedByUser, 'lockedByUser', isFalse),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'the first run keeps its state; the store is closed anyway',
      build: buildStore,
      seed: () => const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.setupRequired),
      act: (store) => store.lock(),
      expect: () => <FuzzyAuthState>[],
      verify: (_) => verify(() => mockService.close()).called(1),
    );
  });

  group('first run, recovery and erase', () {
    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a finished first run opens the app',
      build: buildStore,
      seed: () => const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.setupRequired),
      act: (store) => store.onSetUpComplete(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.authenticated),
      ],
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'a recovery opens the app, drops every biometric copy of the old '
      'password and clears the wrong-password count',
      build: buildStore,
      seed: () => const FuzzyAuthState.initial().copyWith(
        status: AuthStateStatus.locked,
        biometricEnabled: true,
      ),
      act: (store) => store.onRecovered(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.authenticated)
            .having((s) => s.biometricEnabled, 'biometricEnabled', isFalse),
      ],
      verify: (_) {
        verify(() => mockBiometricRepo.disable(BiometricScope.chat)).called(1);
        verify(() => mockBiometricRepo.disable(BiometricScope.vault)).called(1);
        verify(() => mockThrottleRepo.clear()).called(1);
      },
    );

    blocTest<FuzzyAuthStore, FuzzyAuthState>(
      'erasing everything leads back to the first run',
      setUp: () {
        when(() => mockReset.eraseEverything())
            .thenAnswer((_) async => const CryptoCoreSuccess(null));
        when(() => mockChatAuth.status()).thenAnswer(
          (_) async => const CryptoCoreSuccess(MasterKeyStatus.notSetUp),
        );
      },
      build: buildStore,
      seed: () => const FuzzyAuthState.initial()
          .copyWith(status: AuthStateStatus.locked),
      act: (store) => store.eraseEverything(),
      expect: () => [
        isA<FuzzyAuthState>()
            .having((s) => s.status, 'status', AuthStateStatus.setupRequired),
      ],
      verify: (_) => verify(() => mockReset.eraseEverything()).called(1),
    );
  });

  // -----------------------------------------------------------------------
  // Wrong-password waits (security review 2026-10-22, item 6)
  // -----------------------------------------------------------------------
  group('wrong-password waits', () {
    final start = DateTime(2026, 10, 22, 12);
    late AppLockThrottleRepository throttleRepo;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      throttleRepo = AppLockThrottleRepository(
        localDataSource: AppLockThrottleLocalDataSource(),
      );
      when(() => mockChatAuth.unlock('bad')).thenAnswer(
        (_) async =>
            const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
      );
      when(() => mockChatAuth.unlock('pw'))
          .thenAnswer((_) async => const CryptoCoreSuccess(null));
    });

    FuzzyAuthStore buildTimedStore(FakeAsync async) => FuzzyAuthStore(
          chatAuthRepository: mockChatAuth,
          biometricAuthRepository: mockBiometricRepo,
          cryptoCoreService: mockService,
          appLockThrottleRepository: throttleRepo,
          appResetRepository: mockReset,
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
        verifyNever(() => mockChatAuth.unlock('pw'));

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

        when(() => mockChatAuth.status()).thenAnswer(
          (_) async => const CryptoCoreSuccess(MasterKeyStatus.ready),
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
        verifyNever(() => mockChatAuth.unlock('pw'));

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
      when(() => mockChatAuth.unlock('bad')).thenAnswer((_) {
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
        when(() => mockChatAuth.unlock('a'))
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
