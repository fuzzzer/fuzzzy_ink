import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'fuzzy_auth_state.dart';

class FuzzyAuthStore extends Cubit<FuzzyAuthState> {
  FuzzyAuthStore({
    required this.chatAuthRepository,
    required this.biometricAuthRepository,
    required this.cryptoCoreService,
    required this.appLockThrottleRepository,
    required this.appResetRepository,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(
          const FuzzyAuthState.initial(),
        );

  final ChatAuthRepository chatAuthRepository;
  final BiometricAuthRepository biometricAuthRepository;
  final CryptoCoreService cryptoCoreService;
  final AppLockThrottleRepository appLockThrottleRepository;
  final AppResetRepository appResetRepository;
  final DateTime Function() _now;

  /// When the current wait ends, measured on [_now]; null when none runs.
  DateTime? _waitEndsAt;
  Timer? _waitTicker;

  /// Set while a password or biometric attempt runs: a second submit (a
  /// double tap, Enter pressed twice) is ignored instead of racing the first
  /// for the wrong-password count.
  bool _attemptRunning = false;

  /// Reads where the master password stands. The store opens only on an
  /// unlock: there is no state without a password. A secure storage that
  /// cannot be read fails closed (`storageUnavailable`), never open.
  Future<void> checkAuthStatus() async {
    final biometricKind = await biometricAuthRepository.biometricKind();
    final statusRes = await chatAuthRepository.status();
    if (statusRes is CryptoCoreFailure<MasterKeyStatus>) {
      logger.e('Secure storage unreadable at launch: ${statusRes.type}');
      await cryptoCoreService.close();
      emit(
        state.copyWith(
          status: AuthStateStatus.storageUnavailable,
          biometricKind: biometricKind,
        ),
      );
      return;
    }
    switch ((statusRes as CryptoCoreSuccess<MasterKeyStatus>).data) {
      case MasterKeyStatus.notSetUp:
        final legacyRes = await chatAuthRepository.hasLegacyData();
        emit(
          state.copyWith(
            status: AuthStateStatus.setupRequired,
            biometricEnabled: false,
            biometricKind: biometricKind,
            previousDataFound:
                legacyRes is CryptoCoreSuccess<bool> && legacyRes.data,
          ),
        );
      case MasterKeyStatus.ready:
        final biometricReset = await biometricAuthRepository
            .discardOutdatedCopy(BiometricScope.chat);
        final biometricEnabled =
            await biometricAuthRepository.isEnabled(BiometricScope.chat);
        final throttle = await appLockThrottleRepository.read();
        emit(
          state.copyWith(
            status: AuthStateStatus.locked,
            biometricEnabled: biometricEnabled,
            biometricReset: biometricReset,
            biometricKind: biometricKind,
            lockoutRemaining: _startWait(throttle.remainingAt(_now())),
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

  /// The password itself is never kept: on success only the open store
  /// handle in the core remains.
  Future<void> _verify(String password) async {
    emit(state.copyWith(status: AuthStateStatus.unlocking));

    final unlockRes = await chatAuthRepository.unlock(password);

    if (unlockRes is CryptoCoreSuccess<void>) {
      await appLockThrottleRepository.clear();
      emit(
        state.copyWith(
          status: AuthStateStatus.authenticated,
          lockoutRemaining: _startWait(Duration.zero),
          lockedByUser: false,
        ),
      );
    } else if ((unlockRes as CryptoCoreFailure<void>).type ==
        CryptoCoreFailureType.io) {
      emit(state.copyWith(status: AuthStateStatus.storageUnavailable));
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

  /// Closes the store (its key is wiped in the core) and asks for the
  /// master password again. Only an unlocked app locks; the first run and a
  /// failed storage keep their own state. [byUser] is Lock now: the lock
  /// screen then waits for the person instead of prompting for a
  /// fingerprint or face by itself.
  Future<void> lock({bool byUser = false}) async {
    await cryptoCoreService.close();
    if (!state.status.isAuthenticated) return;
    emit(state.copyWith(status: AuthStateStatus.locked, lockedByUser: byUser));
  }

  /// The first run finished (master password set, recovery key saved or
  /// skipped): the store it opened is the session's.
  void onSetUpComplete() {
    emit(
      state.copyWith(
        status: AuthStateStatus.authenticated,
        biometricEnabled: false,
        previousDataFound: false,
      ),
    );
  }

  /// A recovery key set a new master password and opened the store. Every
  /// biometric copy holds the old password, so they are dropped, and the
  /// wrong-password count starts again.
  Future<void> onRecovered() async {
    for (final scope in BiometricScope.values) {
      await biometricAuthRepository.disable(scope);
    }
    await appLockThrottleRepository.clear();
    emit(
      state.copyWith(
        status: AuthStateStatus.authenticated,
        biometricEnabled: false,
        lockoutRemaining: _startWait(Duration.zero),
      ),
    );
  }

  /// "Erase everything and start over": keys, chats, history, vault and
  /// settings go; the app then asks for a new master password.
  Future<CryptoCoreResponse<void>> eraseEverything() async {
    final eraseRes = await appResetRepository.eraseEverything();
    _startWait(Duration.zero);
    await checkAuthStatus();
    return eraseRes;
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    emit(state.copyWith(biometricEnabled: enabled));
  }
}
