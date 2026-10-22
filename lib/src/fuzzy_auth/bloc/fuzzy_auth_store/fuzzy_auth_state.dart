part of 'fuzzy_auth_cubit.dart';

class FuzzyAuthState {
  final AuthStateStatus status;
  final AuthData authData;
  final bool verificationFailed;
  final bool biometricEnabled;
  final bool biometricInvalidated;

  /// One-shot: an update dropped a biometric copy made under the old,
  /// weaker Android key settings; the user turns biometrics on again.
  final bool biometricReset;

  /// Time left before the next password may be tried; zero when none.
  final Duration lockoutRemaining;

  const FuzzyAuthState._({
    required this.status,
    required this.authData,
    this.verificationFailed = false,
    this.biometricEnabled = false,
    this.biometricInvalidated = false,
    this.biometricReset = false,
    this.lockoutRemaining = Duration.zero,
  });

  const FuzzyAuthState.initial()
      : status = AuthStateStatus.initial,
        authData = const AuthData(password: ''),
        verificationFailed = false,
        biometricEnabled = false,
        biometricInvalidated = false,
        biometricReset = false,
        lockoutRemaining = Duration.zero;

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  FuzzyAuthState copyWith({
    AuthStateStatus? status,
    AuthData? authData,
    bool? verificationFailed,
    bool? biometricEnabled,
    bool? biometricInvalidated,
    bool? biometricReset,
    Duration? lockoutRemaining,
  }) {
    return FuzzyAuthState._(
      status: status ?? this.status,
      authData: authData ?? this.authData,
      verificationFailed: verificationFailed ?? false,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricInvalidated: biometricInvalidated ?? false,
      biometricReset: biometricReset ?? false,
      lockoutRemaining: lockoutRemaining ?? this.lockoutRemaining,
    );
  }
}
