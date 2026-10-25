part of 'master_password_recovery_cubit.dart';

class MasterPasswordRecoveryState {
  const MasterPasswordRecoveryState({
    this.status = StateStatus.initial,
    this.tooWeak = false,
    this.failureType,
  });

  final StateStatus status;
  final bool tooWeak;

  /// `corrupt`: a typo in the key; `wrongPassword`: a key that does not open
  /// this device (or none was saved).
  final CryptoCoreFailureType? failureType;
}
