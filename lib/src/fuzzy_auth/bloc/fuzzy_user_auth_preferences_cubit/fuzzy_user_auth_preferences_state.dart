part of 'fuzzy_user_auth_preferences_cubit.dart';

enum AuthPreferencesAction {
  none,
  enable,
  disable,
  changePassword,
  enableBiometric,
  disableBiometric,
}

class FuzzyUserAuthPreferencesState {
  final StateStatus activationStatus;
  final DefaultFailure? activationFailure;
  final AuthPreferencesAction lastAction;

  const FuzzyUserAuthPreferencesState({
    required this.activationStatus,
    this.activationFailure,
    this.lastAction = AuthPreferencesAction.none,
  });

  FuzzyUserAuthPreferencesState copyWith({
    StateStatus? activationStatus,
    DefaultFailure? activationFailure,
    AuthPreferencesAction? lastAction,
  }) {
    return FuzzyUserAuthPreferencesState(
      activationStatus: activationStatus ?? this.activationStatus,
      activationFailure: activationFailure ?? this.activationFailure,
      lastAction: lastAction ?? this.lastAction,
    );
  }

  @override
  String toString() {
    return 'FuzzyUserAuthPreferencesState(activationStatus: $activationStatus, activationFailure: $activationFailure, lastAction: $lastAction)';
  }
}
