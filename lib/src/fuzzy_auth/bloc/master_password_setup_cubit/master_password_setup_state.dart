part of 'master_password_setup_cubit.dart';

/// The first run after the welcome (DESIGN.md section 4.1): the master
/// password, the recovery key, the fingerprint shortcut (only where the
/// device has strong biometrics), "You're ready", then the app opens.
enum MasterPasswordSetupStep { password, recoveryKey, quickUnlock, ready, done }

class MasterPasswordSetupState {
  const MasterPasswordSetupState({
    this.step = MasterPasswordSetupStep.password,
    this.status = StateStatus.initial,
    this.tooWeak = false,
    this.failureType,
    this.recoveryKey,
    this.recoveryWrap,
    this.recoveryLock,
    this.pendingSetup,
    this.interruptedBefore = false,
    this.quickUnlockAvailable = false,
    this.quickUnlockOn = false,
    this.quickUnlockResult,
  });

  final MasterPasswordSetupStep step;
  final StateStatus status;
  final bool tooWeak;
  final CryptoCoreFailureType? failureType;

  /// Shown once on the recovery-key step and dropped with this state.
  final String? recoveryKey;
  final Uint8List? recoveryWrap;
  final Uint8List? recoveryLock;

  /// The keys drawn at the password step, kept only when the recovery-key
  /// step ends; dropped with the recovery key.
  final CryptoCoreMasterKeySetup? pendingSetup;

  /// An earlier first run was closed after drawing its keys and before
  /// keeping them: the recovery key it showed never worked.
  final bool interruptedBefore;

  /// The device has strong biometrics: the fingerprint step is offered.
  final bool quickUnlockAvailable;

  /// The fingerprint shortcut was turned on in the fingerprint step.
  final bool quickUnlockOn;

  /// Why the fingerprint step did not turn it on (null when it did, or was
  /// not tried).
  final BiometricEnableResult? quickUnlockResult;

  /// How many steps the step bar counts: the fingerprint step only where
  /// it is offered.
  int get totalSteps => quickUnlockAvailable ? 3 : 2;

  MasterPasswordSetupState copyWith({
    MasterPasswordSetupStep? step,
    StateStatus? status,
    bool? tooWeak,
    CryptoCoreFailureType? failureType,
    bool? quickUnlockAvailable,
    bool? quickUnlockOn,
    BiometricEnableResult? quickUnlockResult,
    bool dropRecoveryKey = false,
  }) {
    return MasterPasswordSetupState(
      step: step ?? this.step,
      status: status ?? this.status,
      tooWeak: tooWeak ?? false,
      failureType: failureType,
      recoveryKey: dropRecoveryKey ? null : recoveryKey,
      recoveryWrap: dropRecoveryKey ? null : recoveryWrap,
      recoveryLock: dropRecoveryKey ? null : recoveryLock,
      pendingSetup: dropRecoveryKey ? null : pendingSetup,
      interruptedBefore: interruptedBefore,
      quickUnlockAvailable: quickUnlockAvailable ?? this.quickUnlockAvailable,
      quickUnlockOn: quickUnlockOn ?? this.quickUnlockOn,
      quickUnlockResult: quickUnlockResult,
    );
  }
}
