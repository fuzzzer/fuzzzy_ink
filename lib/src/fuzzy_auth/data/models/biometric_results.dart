/// What reading a biometric copy of a password gave.
sealed class BiometricRead {
  const BiometricRead();
}

final class BiometricPassword extends BiometricRead {
  const BiometricPassword(this.password);

  final String password;
}

/// The copy no longer exists: a new fingerprint or face invalidated its key,
/// or nothing was stored. Only this turns biometric unlock off.
final class BiometricCopyGone extends BiometricRead {
  const BiometricCopyGone();
}

/// Nothing was read — the prompt was cancelled, too many tries locked the
/// sensor, or it failed — but the copy is still there: the setting stays and
/// the user types the password.
final class BiometricNotRead extends BiometricRead {
  const BiometricNotRead();
}

/// The outcome of turning biometric unlock on.
enum BiometricEnableResult {
  enabled,

  /// The caller's own password check failed; the repository never answers
  /// this.
  wrongPassword,

  /// The prompt was cancelled or timed out.
  cancelled,

  /// Android could not make a key for strong biometrics: the device has only
  /// weak (class 2) biometrics, or none of its strong ones is enrolled.
  notStrongEnough,

  failed,
}
