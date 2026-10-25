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

  FuzzyUserAuthPreferencesCubit({
    required ChatAuthRepository chatAuthRepository,
    required FuzzyAuthStore fuzzyAuthStore,
    required BiometricAuthRepository biometricAuthRepository,
    required PasswordStrengthService passwordStrengthService,
  })  : _chatAuthRepository = chatAuthRepository,
        _fuzzyAuthStore = fuzzyAuthStore,
        _biometricAuthRepository = biometricAuthRepository,
        _passwordStrengthService = passwordStrengthService,
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

  /// A new recovery key, once [currentPassword] is right. The old key stops
  /// working now; the new one counts only once it is confirmed saved.
  Future<void> newRecoveryKey(String currentPassword) async {
    const action = AuthPreferencesAction.newRecoveryKey;
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    final createRes = await _chatAuthRepository.newRecoveryKey(currentPassword);
    if (createRes is CryptoCoreFailure<CryptoCoreRecoveryKey>) {
      _emitFailed(action, _messageOf(createRes.type));
      return;
    }
    final created =
        (createRes as CryptoCoreSuccess<CryptoCoreRecoveryKey>).data;
    emit(
      state.copyWith(
        activationStatus: StateStatus.success,
        lastAction: action,
        hasRecoveryKey: false,
        pendingRecoveryKey: created.recoveryKey,
        pendingRecoveryWrap: created.recoveryWrap,
      ),
    );
  }

  Future<void> confirmRecoveryKeySaved() async {
    const action = AuthPreferencesAction.saveRecoveryKey;
    final recoveryWrap = state.pendingRecoveryWrap;
    if (recoveryWrap == null) return;
    emit(
      state.copyWith(activationStatus: StateStatus.loading, lastAction: action),
    );
    final saveRes = await _chatAuthRepository.saveRecoveryWrap(recoveryWrap);
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
