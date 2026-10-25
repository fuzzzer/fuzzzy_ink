part of 'fuzzy_user_auth_preferences_cubit.dart';

enum AuthPreferencesAction {
  none,
  changePassword,
  enableBiometric,
  disableBiometric,
  newRecoveryKey,
  saveRecoveryKey,
  skipRecoveryKey,
}

class FuzzyUserAuthPreferencesState {
  final StateStatus activationStatus;
  final DefaultFailure? activationFailure;
  final AuthPreferencesAction lastAction;

  /// `null` until read.
  final bool? hasRecoveryKey;

  /// A new recovery key on screen until it is confirmed saved or skipped.
  final PendingRecoveryKey? pendingRecovery;

  String? get pendingRecoveryKey => pendingRecovery?.recoveryKey;

  const FuzzyUserAuthPreferencesState({
    required this.activationStatus,
    this.activationFailure,
    this.lastAction = AuthPreferencesAction.none,
    this.hasRecoveryKey,
    this.pendingRecovery,
  });

  FuzzyUserAuthPreferencesState copyWith({
    StateStatus? activationStatus,
    DefaultFailure? activationFailure,
    AuthPreferencesAction? lastAction,
    bool? hasRecoveryKey,
    PendingRecoveryKey? pendingRecovery,
    bool clearPendingRecoveryKey = false,
  }) {
    return FuzzyUserAuthPreferencesState(
      activationStatus: activationStatus ?? this.activationStatus,
      activationFailure: activationFailure ?? this.activationFailure,
      lastAction: lastAction ?? this.lastAction,
      hasRecoveryKey: hasRecoveryKey ?? this.hasRecoveryKey,
      pendingRecovery: clearPendingRecoveryKey
          ? null
          : pendingRecovery ?? this.pendingRecovery,
    );
  }

  @override
  String toString() {
    return 'FuzzyUserAuthPreferencesState(activationStatus: $activationStatus, activationFailure: $activationFailure, lastAction: $lastAction, hasRecoveryKey: $hasRecoveryKey)';
  }
}
