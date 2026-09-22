part of 'vault_auth_cubit.dart';

enum VaultAuthEnum { initial, noVault, locked, unlocking, unlocked }

class VaultAuthState {
  const VaultAuthState({
    this.status = StateStatus.initial,
    this.authState = VaultAuthEnum.initial,
    this.masterKey,
    this.failureType,
    this.biometricEnabled = false,
    this.biometricInvalidated = false,
  });

  final StateStatus status;
  final VaultAuthEnum authState;
  final VaultKey? masterKey;
  final VaultFailureType? failureType;
  final bool biometricEnabled;
  final bool biometricInvalidated;

  VaultAuthState copyWith({
    StateStatus? status,
    VaultAuthEnum? authState,
    VaultKey? masterKey,
    VaultFailureType? failureType,
    bool? biometricEnabled,
    bool? biometricInvalidated,
  }) {
    return VaultAuthState(
      status: status ?? this.status,
      authState: authState ?? this.authState,
      masterKey: masterKey ?? this.masterKey,
      failureType: failureType ??
          (status == StateStatus.success ? null : this.failureType),
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricInvalidated: biometricInvalidated ?? false,
    );
  }
}
