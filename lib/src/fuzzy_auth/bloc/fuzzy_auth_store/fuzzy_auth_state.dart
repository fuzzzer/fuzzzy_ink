part of 'fuzzy_auth_cubit.dart';

/// The app lock's state. It never holds the master password: the store
/// handle in the core is the only proof of an unlock.
class FuzzyAuthState {
  final AuthStateStatus status;
  final bool verificationFailed;
  final bool biometricEnabled;
  final bool biometricInvalidated;

  /// One-shot: an update dropped a biometric copy made under the old,
  /// weaker Android key settings; the user turns biometrics on again.
  final bool biometricReset;

  /// Time left before the next password may be tried; zero when none.
  final Duration lockoutRemaining;

  /// The first run found data an earlier build left (its own key): the
  /// setup explains that it cannot be opened and starts fresh.
  final bool previousDataFound;

  const FuzzyAuthState._({
    required this.status,
    this.verificationFailed = false,
    this.biometricEnabled = false,
    this.biometricInvalidated = false,
    this.biometricReset = false,
    this.lockoutRemaining = Duration.zero,
    this.previousDataFound = false,
  });

  const FuzzyAuthState.initial()
      : status = AuthStateStatus.initial,
        verificationFailed = false,
        biometricEnabled = false,
        biometricInvalidated = false,
        biometricReset = false,
        lockoutRemaining = Duration.zero,
        previousDataFound = false;

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  FuzzyAuthState copyWith({
    AuthStateStatus? status,
    bool? verificationFailed,
    bool? biometricEnabled,
    bool? biometricInvalidated,
    bool? biometricReset,
    Duration? lockoutRemaining,
    bool? previousDataFound,
  }) {
    return FuzzyAuthState._(
      status: status ?? this.status,
      verificationFailed: verificationFailed ?? false,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricInvalidated: biometricInvalidated ?? false,
      biometricReset: biometricReset ?? false,
      lockoutRemaining: lockoutRemaining ?? this.lockoutRemaining,
      previousDataFound: previousDataFound ?? this.previousDataFound,
    );
  }
}
