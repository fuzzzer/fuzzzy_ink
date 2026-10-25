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
  final String? pendingRecoveryKey;
  final Uint8List? pendingRecoveryWrap;

  const FuzzyUserAuthPreferencesState({
    required this.activationStatus,
    this.activationFailure,
    this.lastAction = AuthPreferencesAction.none,
    this.hasRecoveryKey,
    this.pendingRecoveryKey,
    this.pendingRecoveryWrap,
  });

  FuzzyUserAuthPreferencesState copyWith({
    StateStatus? activationStatus,
    DefaultFailure? activationFailure,
    AuthPreferencesAction? lastAction,
    bool? hasRecoveryKey,
    String? pendingRecoveryKey,
    Uint8List? pendingRecoveryWrap,
    bool clearPendingRecoveryKey = false,
  }) {
    return FuzzyUserAuthPreferencesState(
      activationStatus: activationStatus ?? this.activationStatus,
      activationFailure: activationFailure ?? this.activationFailure,
      lastAction: lastAction ?? this.lastAction,
      hasRecoveryKey: hasRecoveryKey ?? this.hasRecoveryKey,
      pendingRecoveryKey: clearPendingRecoveryKey
          ? null
          : pendingRecoveryKey ?? this.pendingRecoveryKey,
      pendingRecoveryWrap: clearPendingRecoveryKey
          ? null
          : pendingRecoveryWrap ?? this.pendingRecoveryWrap,
    );
  }

  @override
  String toString() {
    return 'FuzzyUserAuthPreferencesState(activationStatus: $activationStatus, activationFailure: $activationFailure, lastAction: $lastAction, hasRecoveryKey: $hasRecoveryKey)';
  }
}
