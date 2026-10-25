import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'vault_auth_state.dart';

class VaultAuthCubit extends Cubit<VaultAuthState> {
  VaultAuthCubit({
    required this.cryptoRepository,
    required this.vaultRepository,
    required this.biometricAuthRepository,
    required this.appLockThrottleRepository,
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
  final DateTime Function() _now;
  Timer? _autoLockTimer;

  Future<void> checkVaultStatus() async {
    emit(state.copyWith(status: StateStatus.loading));
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultSuccess) {
      final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
      final ownRes = cryptoRepository.usesOwnPassword(metadata);
      final biometricEnabled =
          await biometricAuthRepository.isEnabled(BiometricScope.vault);
      emit(
        state.copyWith(
          status: StateStatus.success,
          authState: VaultAuthEnum.locked,
          biometricEnabled: biometricEnabled,
          usesOwnPassword: ownRes is VaultSuccess<bool> && ownRes.data,
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
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is! VaultSuccess) return BiometricEnableResult.wrongPassword;

    final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
    final keyRes = await cryptoRepository.unlock(currentPassword, metadata);
    if (keyRes is VaultFailure) return BiometricEnableResult.wrongPassword;
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

  /// By default [password] is the master password and the master key wraps
  /// the vault key; with [ownPassword] the vault gets [password] as its own.
  Future<void> createVault(String password, {bool ownPassword = false}) async {
    emit(state.copyWith(status: StateStatus.loading));

    final initRes = await cryptoRepository.initializeVault(
      password,
      ownPassword: ownPassword,
    );
    if (initRes is VaultFailure) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (initRes as VaultFailure).type,
        ),
      );
      return;
    }

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
        usesOwnPassword: ownPassword,
      ),
    );
  }

  /// [password] is the vault's own password, or the master password for a
  /// vault under the master key — which then counts toward the app lock's
  /// wait like any other master-password attempt.
  Future<void> unlock(String password) async {
    final usesMaster = !state.usesOwnPassword;
    if (usesMaster) {
      final throttle = await appLockThrottleRepository.read();
      if (throttle.remainingAt(_now()) > Duration.zero) {
        emit(
          state.copyWith(
            status: StateStatus.failed,
            failureType: VaultFailureType.tooManyAttempts,
            authState: VaultAuthEnum.locked,
          ),
        );
        return;
      }
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
      if (usesMaster && type == VaultFailureType.incorrectMasterPassword) {
        final before = await appLockThrottleRepository.read();
        await appLockThrottleRepository.save(before.afterFailure(_now()));
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
    if (usesMaster) await appLockThrottleRepository.clear();

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
  /// The biometric copy held the master password and is dropped.
  Future<VaultFailureType?> useOwnPassword({
    required String masterPassword,
    required String newPassword,
  }) {
    return _changeWrapping(
      (metadata) => cryptoRepository.useOwnPassword(
        masterPassword: masterPassword,
        newPassword: newPassword,
        metadata: metadata,
      ),
      usesOwnPassword: true,
    );
  }

  /// Opens the vault with the master password again.
  Future<VaultFailureType?> useMasterPassword({
    required String vaultPassword,
    required String masterPassword,
  }) {
    return _changeWrapping(
      (metadata) => cryptoRepository.useMasterPassword(
        vaultPassword: vaultPassword,
        masterPassword: masterPassword,
        metadata: metadata,
      ),
      usesOwnPassword: false,
    );
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
    await biometricAuthRepository.disable(BiometricScope.vault);
    emit(
      state.copyWith(
        usesOwnPassword: usesOwnPassword,
        biometricEnabled: false,
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
