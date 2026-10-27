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

  /// The person locked the app themselves (Lock now): the lock screen then
  /// waits for them and never starts the fingerprint or face prompt on its
  /// own, or the lock would undo itself at once (QA 2026-10-26). Kept until
  /// the next unlock.
  final bool lockedByUser;

  /// Which quick unlock the device has, so the screens name it ("Use Face
  /// ID"); read at launch.
  final BiometricKind biometricKind;

  const FuzzyAuthState._({
    required this.status,
    this.verificationFailed = false,
    this.biometricEnabled = false,
    this.biometricInvalidated = false,
    this.biometricReset = false,
    this.lockoutRemaining = Duration.zero,
    this.previousDataFound = false,
    this.lockedByUser = false,
    this.biometricKind = BiometricKind.other,
  });

  const FuzzyAuthState.initial()
      : status = AuthStateStatus.initial,
        verificationFailed = false,
        biometricEnabled = false,
        biometricInvalidated = false,
        biometricReset = false,
        lockoutRemaining = Duration.zero,
        previousDataFound = false,
        lockedByUser = false,
        biometricKind = BiometricKind.other;

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  FuzzyAuthState copyWith({
    AuthStateStatus? status,
    bool? verificationFailed,
    bool? biometricEnabled,
    bool? biometricInvalidated,
    bool? biometricReset,
    Duration? lockoutRemaining,
    bool? previousDataFound,
    bool? lockedByUser,
    BiometricKind? biometricKind,
  }) {
    return FuzzyAuthState._(
      status: status ?? this.status,
      verificationFailed: verificationFailed ?? false,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricInvalidated: biometricInvalidated ?? false,
      biometricReset: biometricReset ?? false,
      lockoutRemaining: lockoutRemaining ?? this.lockoutRemaining,
      previousDataFound: previousDataFound ?? this.previousDataFound,
      lockedByUser: lockedByUser ?? this.lockedByUser,
      biometricKind: biometricKind ?? this.biometricKind,
    );
  }
}
