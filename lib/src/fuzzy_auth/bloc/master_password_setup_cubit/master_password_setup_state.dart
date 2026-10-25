part of 'master_password_setup_cubit.dart';

enum MasterPasswordSetupStep { password, recoveryKey, done }

class MasterPasswordSetupState {
  const MasterPasswordSetupState({
    this.step = MasterPasswordSetupStep.password,
    this.status = StateStatus.initial,
    this.tooWeak = false,
    this.failureType,
    this.recoveryKey,
    this.recoveryWrap,
    this.recoveryLock,
  });

  final MasterPasswordSetupStep step;
  final StateStatus status;
  final bool tooWeak;
  final CryptoCoreFailureType? failureType;

  /// Shown once on the recovery-key step and dropped with this state.
  final String? recoveryKey;
  final Uint8List? recoveryWrap;
  final Uint8List? recoveryLock;

  MasterPasswordSetupState copyWith({
    StateStatus? status,
    bool? tooWeak,
    CryptoCoreFailureType? failureType,
  }) {
    return MasterPasswordSetupState(
      step: step,
      status: status ?? this.status,
      tooWeak: tooWeak ?? false,
      failureType: failureType,
      recoveryKey: recoveryKey,
      recoveryWrap: recoveryWrap,
      recoveryLock: recoveryLock,
    );
  }
}
