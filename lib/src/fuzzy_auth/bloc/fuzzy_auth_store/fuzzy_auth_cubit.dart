import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'fuzzy_auth_state.dart';

class FuzzyAuthStore extends Cubit<FuzzyAuthState> {
  FuzzyAuthStore({
    required this.chatAuthRepository,
    required this.biometricAuthRepository,
    required this.cryptoStoreKeyRepository,
    required this.cryptoCoreService,
    required this.appLockThrottleRepository,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(
          const FuzzyAuthState.initial(),
        );

  final ChatAuthRepository chatAuthRepository;
  final BiometricAuthRepository biometricAuthRepository;
  final CryptoStoreKeyRepository cryptoStoreKeyRepository;
  final CryptoCoreService cryptoCoreService;
  final AppLockThrottleRepository appLockThrottleRepository;
  final DateTime Function() _now;

  /// When the current wait ends, measured on [_now]; null when none runs.
  DateTime? _waitEndsAt;
  Timer? _waitTicker;

  /// Set while a password or biometric attempt runs: a second submit (a
  /// double tap, Enter pressed twice) is ignored instead of racing the first
  /// for the wrong-password count.
  bool _attemptRunning = false;

  /// The store is open whenever the status is `noAuthRequired` or
  /// `authenticated`, and closed on [lock]. Whether the lock is enabled is
  /// read from the store-key blob, not the preference
  /// ([ChatAuthRepository.isChatAuthEnabled]).
  Future<void> checkAuthStatus() async {
    final ensureRes = await cryptoStoreKeyRepository.ensureStoreKey('');
    if (ensureRes is CryptoCoreFailure) {
      logger.e('Store key could not be created: ${ensureRes.type}');
    }

    final enabled = await chatAuthRepository.isChatAuthEnabled();
    final biometricReset = enabled &&
        await biometricAuthRepository.discardOutdatedCopy(BiometricScope.chat);
    final biometricEnabled =
        enabled && await biometricAuthRepository.isEnabled(BiometricScope.chat);
    if (enabled) {
      final throttle = await appLockThrottleRepository.read();
      emit(
        state.copyWith(
          status: AuthStateStatus.locked,
          biometricEnabled: biometricEnabled,
          biometricReset: biometricReset,
          lockoutRemaining: _startWait(throttle.remainingAt(_now())),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStateStatus.noAuthRequired,
          biometricEnabled: false,
        ),
      );
    }
  }

  /// A cancelled prompt or a locked-out sensor leaves biometric unlock on;
  /// only a copy that is gone turns it off.
  Future<void> unlockWithBiometrics() async {
    if (_attemptRunning) return;
    _attemptRunning = true;
    try {
      emit(state.copyWith(status: AuthStateStatus.unlocking));
      final read =
          await biometricAuthRepository.readPassword(BiometricScope.chat);
      switch (read) {
        case BiometricPassword(:final password):
          // A biometric prompt is a second factor: it may end a running wait.
          await _verify(password);
        case BiometricCopyGone():
          logger.w('Biometric copy is gone (new enrolment or never stored)');
          await _handleBiometricInvalidation();
        case BiometricNotRead():
          emit(state.copyWith(status: AuthStateStatus.locked));
      }
    } finally {
      _attemptRunning = false;
    }
  }

  Future<void> _handleBiometricInvalidation() async {
    await biometricAuthRepository.disable(BiometricScope.chat);
    emit(
      state.copyWith(
        status: AuthStateStatus.locked,
        biometricEnabled: false,
        biometricInvalidated: true,
      ),
    );
  }

  /// Refused without trying the password while a wait runs (security review
  /// 2026-10-22, item 6): after [AppLockThrottleData.freeAttempts] wrong
  /// passwords in a row each further one starts a growing wait, kept across
  /// restarts. Ignored while another attempt runs.
  Future<void> unlock(String password) async {
    if (_attemptRunning) return;
    _attemptRunning = true;
    try {
      final throttle = await appLockThrottleRepository.read();
      final remaining = throttle.remainingAt(_now());
      if (remaining > Duration.zero) {
        emit(
          state.copyWith(
            status: AuthStateStatus.locked,
            lockoutRemaining: _startWait(remaining),
          ),
        );
        return;
      }
      await _verify(password);
    } finally {
      _attemptRunning = false;
    }
  }

  Future<void> _verify(String password) async {
    emit(state.copyWith(status: AuthStateStatus.unlocking));

    final isValid = await chatAuthRepository.verifyPassword(password);

    if (isValid) {
      await appLockThrottleRepository.clear();
      emit(
        state.copyWith(
          status: AuthStateStatus.authenticated,
          authData: AuthData(password: password),
          lockoutRemaining: _startWait(Duration.zero),
        ),
      );
    } else {
      // The count as saved now, not as read before the check: anything
      // recorded meanwhile is kept, and this failure is added on top.
      final before = await appLockThrottleRepository.read();
      final after = before.afterFailure(_now());
      // Saved before the result is shown, so closing the app on a wrong
      // password still counts it.
      await appLockThrottleRepository.save(after);
      emit(
        state.copyWith(
          status: AuthStateStatus.locked,
          verificationFailed: true,
          lockoutRemaining: _startWait(after.remainingAt(_now())),
        ),
      );
    }
  }

  /// Starts (or with [remaining] zero, stops) the one-second countdown that
  /// keeps [FuzzyAuthState.lockoutRemaining] current; returns [remaining].
  Duration _startWait(Duration remaining) {
    _waitTicker?.cancel();
    _waitTicker = null;
    if (remaining <= Duration.zero) {
      _waitEndsAt = null;
      return Duration.zero;
    }
    _waitEndsAt = _now().add(remaining);
    _waitTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final endsAt = _waitEndsAt;
      var left = endsAt == null ? Duration.zero : endsAt.difference(_now());
      if (left <= Duration.zero) {
        left = Duration.zero;
        _waitTicker?.cancel();
        _waitTicker = null;
        _waitEndsAt = null;
      }
      if (!isClosed) emit(state.copyWith(lockoutRemaining: left));
    });
    return remaining;
  }

  @override
  Future<void> close() {
    _waitTicker?.cancel();
    return super.close();
  }

  Future<void> authenticate(AuthData authData) async {
    emit(
      state.copyWith(
        status: AuthStateStatus.authenticated,
        authData: authData,
      ),
    );
  }

  Future<void> lock() async {
    await cryptoCoreService.close();
    emit(
      state.copyWith(
        status: AuthStateStatus.locked,
        authData: const AuthData(password: ''),
      ),
    );
  }

  Future<void> onPasswordSetup(String password) async {
    emit(
      state.copyWith(
        status: AuthStateStatus.authenticated,
        authData: AuthData(password: password),
      ),
    );
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final success = await chatAuthRepository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (success) {
      await biometricAuthRepository.disable(BiometricScope.chat);
      emit(
        state.copyWith(
          authData: AuthData(password: newPassword),
          biometricEnabled: false,
        ),
      );
    }

    return success;
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    emit(state.copyWith(biometricEnabled: enabled));
  }
}
