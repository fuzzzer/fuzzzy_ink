import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'fuzzy_user_auth_preferences_state.dart';

/// The master password's settings: change it, the biometric shortcut, and
/// the recovery key. The master password cannot be switched off.
class FuzzyUserAuthPreferencesCubit
    extends Cubit<FuzzyUserAuthPreferencesState> {
  final ChatAuthRepository _chatAuthRepository;
  final FuzzyAuthStore _fuzzyAuthStore;
  final BiometricAuthRepository _biometricAuthRepository;
  final PasswordStrengthService _passwordStrengthService;

  /// The vault, so a new recovery key can be sealed into a vault that has
  /// its own password; without it no vault is looked at.
  final VaultRepository? _vaultRepository;

  FuzzyUserAuthPreferencesCubit({
    required ChatAuthRepository chatAuthRepository,
    required FuzzyAuthStore fuzzyAuthStore,
    required BiometricAuthRepository biometricAuthRepository,
    required PasswordStrengthService passwordStrengthService,
    VaultRepository? vaultRepository,
  })  : _chatAuthRepository = chatAuthRepository,
        _fuzzyAuthStore = fuzzyAuthStore,
        _biometricAuthRepository = biometricAuthRepository,
        _passwordStrengthService = passwordStrengthService,
        _vaultRepository = vaultRepository,
        super(
          const FuzzyUserAuthPreferencesState(
            activationStatus: StateStatus.initial,
          ),
        );

  /// The bar the vault and the archive export set: "good" or better. Only
  /// a new or changed password must reach it; an existing one still unlocks.
  bool isStrongEnough(String password) =>
      _passwordStrengthService.isStrongEnough(password);

  Future<void> loadRecoveryKeyStatus() async {
    final hasRes = await _chatAuthRepository.hasRecoveryKey();
    if (hasRes is CryptoCoreSuccess<bool>) {
      emit(state.copyWith(hasRecoveryKey: hasRes.data));
    }
  }

  void _emitFailed(AuthPreferencesAction action, String message) {
    emit(
      state.copyWith(
        activationStatus: StateStatus.failed,
        lastAction: action,
        activationFailure: DefaultFailure(message: message),
      ),
    );
  }

  String _messageOf(CryptoCoreFailureType type) =>
      type == CryptoCoreFailureType.wrongPassword
          ? currentContextLocalization.chatAuthIncorrectPassword
          : currentContextLocalization.unknownError;

  /// Re-wraps the master key only; the biometric copy held the old password
  /// and is dropped.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    const action = AuthPreferencesAction.changePassword;
    if (!isStrongEnough(newPassword)) {
      _emitFailed(action, currentContextLocalization.chatAuthPasswordTooWeak);
      return;
    }
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    final changeRes = await _chatAuthRepository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    if (changeRes is CryptoCoreFailure<void>) {
      _emitFailed(action, _messageOf(changeRes.type));
      return;
    }
    await _biometricAuthRepository.disable(BiometricScope.chat);
    await _fuzzyAuthStore.setBiometricEnabled(enabled: false);
    emit(
      state.copyWith(activationStatus: StateStatus.success, lastAction: action),
    );
  }

  /// The master password is checked by opening the store with it before
  /// the copy is made.
  Future<void> enableBiometric(String currentPassword) async {
    const action = AuthPreferencesAction.enableBiometric;
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    final unlockRes = await _chatAuthRepository.unlock(currentPassword);
    if (unlockRes is CryptoCoreFailure<void>) {
      _emitFailed(action, _messageOf(unlockRes.type));
      return;
    }
    final result = await _biometricAuthRepository.enable(
      BiometricScope.chat,
      currentPassword,
    );
    if (result != BiometricEnableResult.enabled) {
      _emitFailed(
        action,
        result == BiometricEnableResult.notStrongEnough
            ? currentContextLocalization.biometricNotStrongEnough
            : currentContextLocalization.biometricNotTurnedOn,
      );
      return;
    }
    await _fuzzyAuthStore.setBiometricEnabled(enabled: true);
    emit(
      state.copyWith(activationStatus: StateStatus.success, lastAction: action),
    );
  }

  Future<void> disableBiometric() async {
    const action = AuthPreferencesAction.disableBiometric;
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    await _biometricAuthRepository.disable(BiometricScope.chat);
    await _fuzzyAuthStore.setBiometricEnabled(enabled: false);
    emit(
      state.copyWith(activationStatus: StateStatus.success, lastAction: action),
    );
  }

  /// A new recovery key, once [currentPassword] is right. A vault with its
  /// own password needs [vaultPassword] too, so the new key opens it as well
  /// — the master password alone never reaches that vault. The old key stops
  /// working now; the new one counts only once it is confirmed saved.
  Future<void> newRecoveryKey(
    String currentPassword, {
    String? vaultPassword,
  }) async {
    const action = AuthPreferencesAction.newRecoveryKey;
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    final vault = await _vaultWithOwnPassword();
    if (vault.unreadable) {
      _emitFailed(action, currentContextLocalization.unknownError);
      return;
    }
    final vaultMetadata = vault.metadata;
    if (vaultMetadata != null &&
        (vaultPassword == null || vaultPassword.isEmpty)) {
      _emitFailed(action, currentContextLocalization.vaultIncorrectPassword);
      return;
    }
    var vaultPasswordWrong = false;
    final createRes = await _chatAuthRepository.newRecoveryKey(
      currentPassword,
      sealVault: vaultMetadata == null
          ? null
          : (recoveryLock) async {
              final sealRes =
                  await _vaultRepository!.cryptoRepository.sealForRecovery(
                vaultPassword: vaultPassword!,
                metadata: vaultMetadata,
                recoveryLock: recoveryLock,
              );
              vaultPasswordWrong = sealRes is CryptoCoreFailure<Uint8List> &&
                  sealRes.type == CryptoCoreFailureType.wrongPassword;
              return sealRes;
            },
    );
    if (createRes is CryptoCoreFailure<PendingRecoveryKey>) {
      _emitFailed(
        action,
        vaultPasswordWrong
            ? currentContextLocalization.vaultIncorrectPassword
            : _messageOf(createRes.type),
      );
      return;
    }
    emit(
      state.copyWith(
        activationStatus: StateStatus.success,
        lastAction: action,
        hasRecoveryKey: false,
        pendingRecovery:
            (createRes as CryptoCoreSuccess<PendingRecoveryKey>).data,
      ),
    );
  }

  /// The vault's metadata when a vault exists and has its own password. A
  /// vault that cannot be read is `unreadable`: the old key is then kept
  /// rather than replaced by one that might not open the vault.
  Future<({bool unreadable, VaultMetadata? metadata})>
      _vaultWithOwnPassword() async {
    const none = (unreadable: false, metadata: null);
    final vaultRepository = _vaultRepository;
    if (vaultRepository == null) return none;
    final metaRes = await vaultRepository.getMetadata();
    if (metaRes is VaultFailure<VaultMetadata>) {
      return metaRes.type == VaultFailureType.vaultNotInitialized
          ? none
          : (unreadable: true, metadata: null);
    }
    final metadata = (metaRes as VaultSuccess<VaultMetadata>).data;
    final ownRes = vaultRepository.cryptoRepository.usesOwnPassword(metadata);
    if (ownRes is VaultFailure<bool>) return (unreadable: true, metadata: null);
    return (ownRes as VaultSuccess<bool>).data
        ? (unreadable: false, metadata: metadata)
        : none;
  }

  Future<void> confirmRecoveryKeySaved() async {
    const action = AuthPreferencesAction.saveRecoveryKey;
    final pending = state.pendingRecovery;
    if (pending == null) return;
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    final saveRes = await _chatAuthRepository.saveRecovery(pending);
    if (saveRes is CryptoCoreFailure<void>) {
      _emitFailed(action, _messageOf(saveRes.type));
      return;
    }
    emit(
      state.copyWith(
        activationStatus: StateStatus.success,
        lastAction: action,
        hasRecoveryKey: true,
        clearPendingRecoveryKey: true,
      ),
    );
  }

  /// After the warning: no recovery key is kept for this device.
  void skipRecoveryKey() {
    emit(
      state.copyWith(
        activationStatus: StateStatus.success,
        lastAction: AuthPreferencesAction.skipRecoveryKey,
        hasRecoveryKey: false,
        clearPendingRecoveryKey: true,
      ),
    );
  }
}
