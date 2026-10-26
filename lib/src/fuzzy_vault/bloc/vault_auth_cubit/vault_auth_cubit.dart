import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'vault_auth_state.dart';

class VaultAuthCubit extends Cubit<VaultAuthState> {
  VaultAuthCubit({
    required this.cryptoRepository,
    required this.vaultRepository,
    required this.biometricAuthRepository,
    required this.appLockThrottleRepository,
    this.vaultPasswordThrottleRepository,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const VaultAuthState());

  /// The vault locks itself this long after it was opened. A constant of the
  /// app, not a value in `vault.meta`, so editing a file cannot change it
  /// (security review 2026-10-22); the whole app's auto-lock comes on top.
  static const autoLockAfter = Duration(minutes: 5);

  final VaultCryptoRepository cryptoRepository;
  final VaultRepository vaultRepository;
  final BiometricAuthRepository biometricAuthRepository;

  /// The app lock's wrong-password count: a vault under the master key is a
  /// second door to the master password and shares its wait.
  final AppLockThrottleRepository appLockThrottleRepository;

  /// My safe's own password: its own wrong-password count and wait
  /// (security review 2026-10-26). Without it (tests), no wait.
  final VaultPasswordThrottleRepository? vaultPasswordThrottleRepository;
  final DateTime Function() _now;

  /// The count a password for the vault in its current mode goes to: the
  /// master password's, or My safe's own.
  AppLockThrottleRepository? get _countForCurrentMode => state.usesOwnPassword
      ? vaultPasswordThrottleRepository
      : appLockThrottleRepository;

  static Future<Duration> _remaining(
    AppLockThrottleRepository? throttle,
    DateTime now,
  ) async {
    if (throttle == null) return Duration.zero;
    return (await throttle.read()).remainingAt(now);
  }

  static Future<void> _countWrong(
    AppLockThrottleRepository? throttle,
    DateTime now,
  ) async {
    if (throttle == null) return;
    final before = await throttle.read();
    await throttle.save(before.afterFailure(now));
  }

  Timer? _autoLockTimer;

  Future<void> checkVaultStatus() async {
    emit(state.copyWith(status: StateStatus.loading));
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultSuccess) {
      final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
      final ownRes = cryptoRepository.usesOwnPassword(metadata);
      final usesOwn = ownRes is VaultSuccess<bool> && ownRes.data;
      final biometricEnabled =
          await biometricAuthRepository.isEnabled(BiometricScope.vault);
      emit(
        state.copyWith(
          status: StateStatus.success,
          authState: VaultAuthEnum.locked,
          biometricEnabled: biometricEnabled,
          usesOwnPassword: usesOwn,
          recoverable: usesOwn && await cryptoRepository.hasRecoveryCopy(),
          recoveryKeyKept: await cryptoRepository.hasRecoveryKey(),
        ),
      );
    } else if (metaRes is VaultFailure<VaultMetadata> &&
        metaRes.type == VaultFailureType.vaultMoveUnfinished) {
      // Offering "create" here would leave the real vault behind for good.
      emit(
        state.copyWith(
          status: StateStatus.success,
          authState: VaultAuthEnum.moveUnfinished,
          biometricEnabled: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: StateStatus.success,
          authState: VaultAuthEnum.noVault,
          biometricEnabled: false,
          usesOwnPassword: false,
          recoverable: false,
          recoveryKeyKept: await cryptoRepository.hasRecoveryKey(),
        ),
      );
    }
  }

  Future<void> unlockWithBiometrics() async {
    emit(
      state.copyWith(
        status: StateStatus.loading,
        authState: VaultAuthEnum.unlocking,
      ),
    );
    try {
      // A cancel or a locked-out sensor keeps biometric unlock on; only a
      // copy that is gone turns it off.
      final read =
          await biometricAuthRepository.readPassword(BiometricScope.vault);
      switch (read) {
        case BiometricPassword(:final password):
          await unlock(password);
        case BiometricCopyGone():
          logger.w('Vault biometric copy is gone');
          await _handleBiometricInvalidation();
        case BiometricNotRead():
          emit(
            state.copyWith(
              status: StateStatus.success,
              authState: VaultAuthEnum.locked,
            ),
          );
      }
    } catch (e, stack) {
      logger.e('Vault biometric unlock failed', error: e, stackTrace: stack);
      await _handleBiometricInvalidation();
    }
  }

  Future<void> _handleBiometricInvalidation() async {
    await biometricAuthRepository.disable(BiometricScope.vault);
    emit(
      state.copyWith(
        status: StateStatus.success,
        authState: VaultAuthEnum.locked,
        biometricEnabled: false,
        biometricInvalidated: true,
      ),
    );
  }

  Future<BiometricEnableResult> enableBiometric(String currentPassword) async {
    final throttle = _countForCurrentMode;
    if (await _remaining(throttle, _now()) > Duration.zero) {
      return BiometricEnableResult.wrongPassword;
    }
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is! VaultSuccess) return BiometricEnableResult.wrongPassword;

    final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
    final keyRes = await cryptoRepository.unlock(currentPassword, metadata);
    if (keyRes is VaultFailure) {
      if ((keyRes as VaultFailure).type ==
          VaultFailureType.incorrectMasterPassword) {
        await _countWrong(throttle, _now());
      }
      return BiometricEnableResult.wrongPassword;
    }
    await throttle?.clear();
    await _closeKey((keyRes as VaultSuccess<VaultKey>).data);

    final result = await biometricAuthRepository.enable(
      BiometricScope.vault,
      currentPassword,
    );
    if (result == BiometricEnableResult.enabled) {
      emit(state.copyWith(biometricEnabled: true));
    }
    return result;
  }

  Future<void> disableBiometric() async {
    await biometricAuthRepository.disable(BiometricScope.vault);
    emit(state.copyWith(biometricEnabled: false));
  }

  /// The master password changed: a vault it opens loses its biometric
  /// copy, which held the old password.
  Future<void> onMasterPasswordChanged() async {
    if (state.usesOwnPassword) return;
    await disableBiometric();
  }

  /// [password] is the master password: a new vault is always under the
  /// master key (it gets its own password only through [useOwnPassword]).
  /// The typed master password counts toward the app lock's wait, the same
  /// as [unlock].
  Future<void> createVault(String password) async {
    if (await lockoutRemaining() > Duration.zero) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: VaultFailureType.tooManyAttempts,
        ),
      );
      return;
    }
    emit(state.copyWith(status: StateStatus.loading));

    final initRes = await cryptoRepository.initializeVault(password);
    if (initRes is VaultFailure) {
      final type = (initRes as VaultFailure).type;
      if (type == VaultFailureType.incorrectMasterPassword) {
        final before = await appLockThrottleRepository.read();
        await appLockThrottleRepository.save(before.afterFailure(_now()));
      }
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: type,
        ),
      );
      return;
    }
    await appLockThrottleRepository.clear();

    final metadata = (initRes as VaultSuccess<VaultMetadata>).data;
    final saveRes = await vaultRepository.saveMetadata(metadata);

    if (saveRes is VaultFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: saveRes.type,
        ),
      );
      return;
    }

    final keyRes = await cryptoRepository.unlock(password, metadata);
    if (keyRes is VaultFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (keyRes as VaultFailure).type,
        ),
      );
      return;
    }

    final masterKey = (keyRes as VaultSuccess<VaultKey>).data;
    _startAutoLockTimer();

    emit(
      state.copyWith(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: masterKey,
        usesOwnPassword: false,
        recoverable: false,
      ),
    );
  }

  /// The wait left before the vault's password may be tried again: the
  /// master password's (shared with the app lock), or for a vault with its
  /// own password, that password's own count.
  Future<Duration> lockoutRemaining() =>
      _remaining(_countForCurrentMode, _now());

  /// [password] is the vault's own password, or the master password for a
  /// vault under the master key — which then counts toward the app lock's
  /// wait like any other master-password attempt.
  Future<void> unlock(String password) async {
    final throttle = _countForCurrentMode;
    if (await _remaining(throttle, _now()) > Duration.zero) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: VaultFailureType.tooManyAttempts,
          authState: VaultAuthEnum.locked,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: StateStatus.loading,
        authState: VaultAuthEnum.unlocking,
      ),
    );

    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (metaRes as VaultFailure).type,
          authState: VaultAuthEnum.locked,
        ),
      );
      return;
    }

    final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
    final keyRes = await cryptoRepository.unlock(password, metadata);

    if (keyRes is VaultFailure) {
      final type = (keyRes as VaultFailure).type;
      if (type == VaultFailureType.incorrectMasterPassword) {
        await _countWrong(throttle, _now());
      }
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: type,
          authState: VaultAuthEnum.locked,
        ),
      );
      return;
    }
    await throttle?.clear();

    final masterKey = (keyRes as VaultSuccess<VaultKey>).data;

    final updatedMetadata = metadata.copyWith(lastUnlockedAt: DateTime.now());
    await vaultRepository.saveMetadata(updatedMetadata);

    _startAutoLockTimer();

    emit(
      state.copyWith(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: masterKey,
      ),
    );
  }

  /// Gives the vault its own password; [masterPassword] proves the change.
  ///
  /// The vault gets a new key and a new recovery key in the same step
  /// (security review 2026-10-26): every item is re-sealed to the new key and
  /// the new wrapping replaces the old in one atomic step, so an old copy of
  /// `vault.meta` and the master password open nothing kept here; the
  /// recovery key kept so far ends, so one somebody else made earlier with
  /// the master password opens nothing either. The vault is left locked. The
  /// answer carries the new recovery key, which the caller shows and keeps
  /// only once the user has saved it ([keepRecoveryKey]). The biometric copy
  /// held the master password and is dropped.
  Future<({VaultFailureType? failure, PendingRecoveryKey? recovery})>
      useOwnPassword({
    required String masterPassword,
    required String newPassword,
  }) async {
    ({VaultFailureType? failure, PendingRecoveryKey? recovery}) failed(
      VaultFailureType type,
    ) =>
        (failure: type, recovery: null);

    // The master password typed here counts like any other (security
    // review 2026-10-26).
    if (await _remaining(appLockThrottleRepository, _now()) > Duration.zero) {
      return failed(VaultFailureType.tooManyAttempts);
    }
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultFailure) return failed((metaRes as VaultFailure).type);
    final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
    final switchRes = await cryptoRepository.useOwnPassword(
      masterPassword: masterPassword,
      newPassword: newPassword,
      metadata: metadata,
    );
    if (switchRes is VaultFailure) {
      final type = (switchRes as VaultFailure).type;
      if (type == VaultFailureType.incorrectMasterPassword) {
        await _countWrong(appLockThrottleRepository, _now());
      }
      return failed(type);
    }
    await appLockThrottleRepository.clear();
    final changed =
        (switchRes as VaultSuccess<CryptoCoreVaultOwnPassword>).data;

    // Nothing may write an item under the old key from here on.
    await lock();
    final rekeyRes = await vaultRepository.rekey(
      previous: changed.previous,
      key: changed.key,
      metadata: metadata.copyWith(
        verificationToken: base64Encode(changed.wrapped),
      ),
      // A copy of the old key sealed to the old recovery lock must not
      // outlive the move: it would put the old key back.
      beforeCommit: () async {
        final dropRes = await cryptoRepository.dropRecoveryCopy();
        return dropRes is VaultFailure ? dropRes.type : null;
      },
    );
    await _closeKey(changed.previous);
    await _closeKey(changed.key);
    if (rekeyRes is VaultFailure) {
      return failed(rekeyRes.type);
    }

    final endRes = await cryptoRepository.endRecoveryKey();
    if (endRes is VaultFailure) {
      logger.w('The old recovery key could not be removed');
    }
    await biometricAuthRepository.disable(BiometricScope.vault);
    emit(
      state.copyWith(
        usesOwnPassword: true,
        biometricEnabled: false,
        recoverable: false,
        recoveryKeyKept: false,
      ),
    );
    return (
      failure: null,
      recovery: PendingRecoveryKey(
        recoveryKey: changed.recovery.recoveryKey,
        recoveryWrap: changed.recovery.recoveryWrap,
        recoveryLock: changed.recovery.recoveryLock,
        vaultRecovery: changed.vaultRecovery,
      ),
    );
  }

  /// Keeps the recovery key [useOwnPassword] made, once the user has saved
  /// it. `null` on success.
  Future<VaultFailureType?> keepRecoveryKey(PendingRecoveryKey pending) async {
    final keepRes = await cryptoRepository.keepRecoveryKey(pending);
    await refreshRecovery();
    return keepRes is VaultFailure ? keepRes.type : null;
  }

  /// Opens the vault with the master password again. Both passwords are
  /// typed here; My safe's password is checked first, so a wrong answer
  /// counts toward its own wait (security review 2026-10-26), and the master
  /// password's wait applies too.
  Future<VaultFailureType?> useMasterPassword({
    required String vaultPassword,
    required String masterPassword,
  }) async {
    final vaultCount = vaultPasswordThrottleRepository;
    if (await _remaining(vaultCount, _now()) > Duration.zero ||
        await _remaining(appLockThrottleRepository, _now()) > Duration.zero) {
      return VaultFailureType.tooManyAttempts;
    }
    final failure = await _changeWrapping(
      (metadata) => cryptoRepository.useMasterPassword(
        vaultPassword: vaultPassword,
        masterPassword: masterPassword,
        metadata: metadata,
      ),
      usesOwnPassword: false,
    );
    if (failure == VaultFailureType.incorrectMasterPassword) {
      await _countWrong(vaultCount, _now());
    } else if (failure == null) {
      await vaultCount?.clear();
    }
    return failure;
  }

  /// Re-reads whether a recovery key is kept and whether it opens the vault
  /// — after a new recovery key was saved or skipped in the settings.
  Future<void> refreshRecovery() async {
    final kept = await cryptoRepository.hasRecoveryKey();
    final copy =
        state.usesOwnPassword && await cryptoRepository.hasRecoveryCopy();
    emit(state.copyWith(recoveryKeyKept: kept, recoverable: copy));
  }

  /// The recovery key opens a vault with its own password ("forgot the
  /// vault password", or after a new master password from the recovery
  /// key): with [newPassword] the vault keeps its own password, now that one;
  /// without it the master password opens the vault from now on. The vault
  /// is then open. `null` on success.
  Future<VaultFailureType?> recover({
    required String recoveryKey,
    String? newPassword,
  }) async {
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultFailure) return (metaRes as VaultFailure).type;
    final recoverRes = await cryptoRepository.recover(
      recoveryKey: recoveryKey,
      newPassword: newPassword,
      metadata: (metaRes as VaultSuccess<VaultMetadata>).data,
    );
    if (recoverRes is VaultFailure) return (recoverRes as VaultFailure).type;
    final recovered =
        (recoverRes as VaultSuccess<({VaultKey key, VaultMetadata metadata})>)
            .data;
    final saveRes = await vaultRepository.saveMetadata(
      recovered.metadata.copyWith(lastUnlockedAt: _now()),
    );
    if (saveRes is VaultFailure) {
      await _closeKey(recovered.key);
      return saveRes.type;
    }
    final ownPassword = newPassword != null;
    if (!ownPassword) await cryptoRepository.dropRecoveryCopy();
    // The biometric copy held the forgotten password.
    await biometricAuthRepository.disable(BiometricScope.vault);
    final previous = state.masterKey;
    if (previous != null) await _closeKey(previous);
    _startAutoLockTimer();
    emit(
      state.copyWith(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: recovered.key,
        biometricEnabled: false,
        usesOwnPassword: ownPassword,
        recoverable: ownPassword,
      ),
    );
    return null;
  }

  /// `null` on success.
  Future<VaultFailureType?> _changeWrapping(
    Future<VaultResponse<VaultMetadata>> Function(VaultMetadata) rewrap, {
    required bool usesOwnPassword,
  }) async {
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultFailure) return (metaRes as VaultFailure).type;
    final rewrapRes =
        await rewrap((metaRes as VaultSuccess<VaultMetadata>).data);
    if (rewrapRes is VaultFailure) return (rewrapRes as VaultFailure).type;
    final saveRes = await vaultRepository
        .saveMetadata((rewrapRes as VaultSuccess<VaultMetadata>).data);
    if (saveRes is VaultFailure) return saveRes.type;
    if (!usesOwnPassword) await cryptoRepository.dropRecoveryCopy();
    await biometricAuthRepository.disable(BiometricScope.vault);
    emit(
      state.copyWith(
        usesOwnPassword: usesOwnPassword,
        biometricEnabled: false,
        recoverable:
            usesOwnPassword && await cryptoRepository.hasRecoveryCopy(),
      ),
    );
    return null;
  }

  Future<void> lock() async {
    _autoLockTimer?.cancel();
    final keyToWipe = state.masterKey;
    if (keyToWipe != null) {
      await _closeKey(keyToWipe);
    }
    emit(
      VaultAuthState(
        status: StateStatus.success,
        authState: state.authState == VaultAuthEnum.noVault ||
                state.authState == VaultAuthEnum.moveUnfinished ||
                state.authState == VaultAuthEnum.initial
            ? state.authState
            : VaultAuthEnum.locked,
        biometricEnabled: state.biometricEnabled,
        usesOwnPassword: state.usesOwnPassword,
        recoverable: state.recoverable,
        recoveryKeyKept: state.recoveryKeyKept,
      ),
    );
  }

  /// Zeroises the vault key in the core and frees the handle.
  Future<void> _closeKey(VaultKey key) async {
    await key.close();
    key.dispose();
  }

  void _startAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(autoLockAfter, lock);
  }

  @override
  Future<void> close() {
    _autoLockTimer?.cancel();
    return super.close();
  }
}
