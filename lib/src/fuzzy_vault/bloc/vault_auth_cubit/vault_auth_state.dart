part of 'vault_auth_cubit.dart';

enum VaultAuthEnum {
  initial,
  noVault,

  /// The old vault is not yet in its private folder: nothing opens, and no
  /// new vault is offered, until a restart finishes the move.
  moveUnfinished,
  locked,
  unlocking,
  unlocked,
}

class VaultAuthState {
  const VaultAuthState({
    this.status = StateStatus.initial,
    this.authState = VaultAuthEnum.initial,
    this.masterKey,
    this.failureType,
    this.biometricEnabled = false,
    this.biometricInvalidated = false,
    this.usesOwnPassword = false,
  });

  final StateStatus status;
  final VaultAuthEnum authState;
  final VaultKey? masterKey;
  final VaultFailureType? failureType;
  final bool biometricEnabled;
  final bool biometricInvalidated;

  /// The vault has its own password; otherwise the master password opens it.
  final bool usesOwnPassword;

  VaultAuthState copyWith({
    StateStatus? status,
    VaultAuthEnum? authState,
    VaultKey? masterKey,
    VaultFailureType? failureType,
    bool? biometricEnabled,
    bool? biometricInvalidated,
    bool? usesOwnPassword,
  }) {
    return VaultAuthState(
      status: status ?? this.status,
      authState: authState ?? this.authState,
      masterKey: masterKey ?? this.masterKey,
      failureType: failureType ??
          (status == StateStatus.success ? null : this.failureType),
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricInvalidated: biometricInvalidated ?? false,
      usesOwnPassword: usesOwnPassword ?? this.usesOwnPassword,
    );
  }
}
