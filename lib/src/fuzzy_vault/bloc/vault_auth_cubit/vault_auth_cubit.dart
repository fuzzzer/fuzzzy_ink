import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'vault_auth_state.dart';

class VaultAuthCubit extends Cubit<VaultAuthState> {
  VaultAuthCubit({
    required this.cryptoRepository,
    required this.vaultRepository,
    required this.biometricAuthRepository,
  }) : super(const VaultAuthState());

  final VaultCryptoRepository cryptoRepository;
  final VaultRepository vaultRepository;
  final BiometricAuthRepository biometricAuthRepository;
  Timer? _autoLockTimer;

  Future<void> checkVaultStatus() async {
    emit(state.copyWith(status: StateStatus.loading));
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultSuccess) {
      final biometricEnabled =
          await biometricAuthRepository.isEnabled(BiometricScope.vault);
      emit(
        state.copyWith(
          status: StateStatus.success,
          authState: VaultAuthEnum.locked,
          biometricEnabled: biometricEnabled,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: StateStatus.success,
          authState: VaultAuthEnum.noVault,
          biometricEnabled: false,
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
      final password =
          await biometricAuthRepository.retrievePassword(BiometricScope.vault);
      if (password == null) {
        logger.w(
          'Vault biometric unlock returned null (cancelled or empty storage)',
        );
        await _handleBiometricInvalidation();
        return;
      }
      await unlock(password);
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

  Future<bool> enableBiometric(String currentPassword) async {
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is! VaultSuccess) return false;

    final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
    final keyRes = await cryptoRepository.unlock(currentPassword, metadata);
    if (keyRes is VaultFailure) return false;
    await _closeKey((keyRes as VaultSuccess<VaultKey>).data);

    await biometricAuthRepository.enable(BiometricScope.vault, currentPassword);
    emit(state.copyWith(biometricEnabled: true));
    return true;
  }

  Future<void> disableBiometric() async {
    await biometricAuthRepository.disable(BiometricScope.vault);
    emit(state.copyWith(biometricEnabled: false));
  }

  Future<void> createVault(String password) async {
    emit(state.copyWith(status: StateStatus.loading));

    final initRes = await cryptoRepository.initializeVault(password);
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
    _startAutoLockTimer(metadata.autoLockMinutes);

    emit(
      state.copyWith(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: masterKey,
      ),
    );
  }

  Future<void> unlock(String password) async {
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
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: (keyRes as VaultFailure).type,
          authState: VaultAuthEnum.locked,
        ),
      );
      return;
    }

    final masterKey = (keyRes as VaultSuccess<VaultKey>).data;

    final updatedMetadata = metadata.copyWith(lastUnlockedAt: DateTime.now());
    await vaultRepository.saveMetadata(updatedMetadata);

    _startAutoLockTimer(updatedMetadata.autoLockMinutes);

    emit(
      state.copyWith(
        status: StateStatus.success,
        authState: VaultAuthEnum.unlocked,
        masterKey: masterKey,
      ),
    );
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
        authState: VaultAuthEnum.locked,
        biometricEnabled: state.biometricEnabled,
      ),
    );
  }

  /// Zeroises the master key in the core and frees the handle.
  Future<void> _closeKey(VaultKey key) async {
    await key.close();
    key.dispose();
  }

  void _startAutoLockTimer(int minutes) {
    _autoLockTimer?.cancel();
    if (minutes <= 0) return;
    _autoLockTimer = Timer(Duration(minutes: minutes), lock);
  }

  @override
  Future<void> close() {
    _autoLockTimer?.cancel();
    return super.close();
  }
}
