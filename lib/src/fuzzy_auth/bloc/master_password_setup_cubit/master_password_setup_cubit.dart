import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

part 'master_password_setup_state.dart';

/// The first run: a master password ("good" or better), then the recovery
/// key — saved and confirmed, or explicitly skipped — then the fingerprint
/// shortcut where the device has strong biometrics, then "You're ready".
/// The app opens only at [finish]. Nothing from an earlier build survives:
/// its data cannot be opened without the old key.
///
/// The keys are drawn at [create] but kept only when the recovery-key step
/// ends ([confirmRecoveryKeySaved] or [skipRecoveryKey]): a first run closed
/// on that step leaves nothing behind and starts again, so a recovery key
/// that was shown is either kept or never valid.
class MasterPasswordSetupCubit extends Cubit<MasterPasswordSetupState> {
  MasterPasswordSetupCubit({
    required ChatAuthRepository chatAuthRepository,
    required AppResetRepository appResetRepository,
    required FuzzyAuthStore fuzzyAuthStore,
    required PasswordStrengthService passwordStrengthService,
    BiometricAuthRepository? biometricAuthRepository,
    PreferencesService? preferencesService,
  })  : _chatAuthRepository = chatAuthRepository,
        _appResetRepository = appResetRepository,
        _fuzzyAuthStore = fuzzyAuthStore,
        _passwordStrengthService = passwordStrengthService,
        _biometricAuthRepository = biometricAuthRepository,
        _preferencesService = preferencesService,
        super(
          MasterPasswordSetupState(
            interruptedBefore: preferencesService?.firstRunPending ?? false,
          ),
        );

  final ChatAuthRepository _chatAuthRepository;
  final AppResetRepository _appResetRepository;
  final FuzzyAuthStore _fuzzyAuthStore;
  final PasswordStrengthService _passwordStrengthService;

  /// Without it there is no fingerprint step.
  final BiometricAuthRepository? _biometricAuthRepository;

  /// Remembers a first run that drew keys but did not keep them yet.
  final PreferencesService? _preferencesService;

  bool isStrongEnough(String password) =>
      _passwordStrengthService.isStrongEnough(password);

  /// Whether the fingerprint step will be offered, so the step bar can
  /// count it from the start.
  Future<void> checkQuickUnlock() async {
    final available =
        await _biometricAuthRepository?.canUseBiometrics() ?? false;
    if (isClosed) return;
    emit(state.copyWith(quickUnlockAvailable: available));
  }

  /// Clears whatever an earlier install left, then lets the core draw every
  /// key and open the store. Nothing is kept yet: the recovery key comes
  /// next.
  Future<void> create(String password) async {
    if (state.status.isLoading) return;
    if (!isStrongEnough(password)) {
      emit(state.copyWith(status: StateStatus.failed, tooWeak: true));
      return;
    }
    emit(state.copyWith(status: StateStatus.loading));

    final eraseRes = await _appResetRepository.eraseEverything();
    if (eraseRes is CryptoCoreFailure<void>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: eraseRes.type,
        ),
      );
      return;
    }
    final setUpRes = await _chatAuthRepository.prepareSetUp(password);
    if (setUpRes is CryptoCoreFailure<CryptoCoreMasterKeySetup>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: setUpRes.type,
        ),
      );
      return;
    }
    final setup =
        (setUpRes as CryptoCoreSuccess<CryptoCoreMasterKeySetup>).data;
    await _preferencesService?.setFirstRunPending(true);
    emit(
      MasterPasswordSetupState(
        step: MasterPasswordSetupStep.recoveryKey,
        status: StateStatus.success,
        recoveryKey: setup.recoveryKey,
        recoveryWrap: setup.recoveryWrap,
        recoveryLock: setup.recoveryLock,
        pendingSetup: setup,
        quickUnlockAvailable: state.quickUnlockAvailable,
      ),
    );
  }

  /// The user saved the recovery key: it is kept with the master password.
  Future<void> confirmRecoveryKeySaved() => _keep(keepRecovery: true);

  /// The user chose, after the warning, to go without a recovery key: the
  /// master password is kept, its recovery wrap never is, so no recovery
  /// key exists for this device.
  Future<void> skipRecoveryKey() => _keep(keepRecovery: false);

  /// Keeps the master password (and the recovery key with [keepRecovery]):
  /// from here the device is set up. A failed write stays on the key step,
  /// so it can be tried again.
  Future<void> _keep({required bool keepRecovery}) async {
    final pending = state.pendingSetup;
    if (pending == null || state.status.isLoading) return;
    emit(state.copyWith(status: StateStatus.loading));
    final keepRes = await _chatAuthRepository.completeSetUp(
      pending,
      keepRecovery: keepRecovery,
    );
    if (keepRes is CryptoCoreFailure<void>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: keepRes.type,
        ),
      );
      return;
    }
    await _preferencesService?.setFirstRunPending(false);
    _afterRecoveryKey();
  }

  /// The key leaves the state; the fingerprint step, or "You're ready".
  void _afterRecoveryKey() {
    emit(
      state.copyWith(
        step: state.quickUnlockAvailable
            ? MasterPasswordSetupStep.quickUnlock
            : MasterPasswordSetupStep.ready,
        status: StateStatus.success,
        dropRecoveryKey: true,
      ),
    );
  }

  /// "Use fingerprint or face": keeps [password] behind the device's strong
  /// biometrics, as Settings does. On a refusal the step stays, so "Not
  /// now" is still there.
  Future<void> enableQuickUnlock(String password) async {
    final biometrics = _biometricAuthRepository;
    if (biometrics == null || state.status.isLoading) return;
    emit(state.copyWith(status: StateStatus.loading));
    final result = await biometrics.enable(BiometricScope.chat, password);
    if (result != BiometricEnableResult.enabled) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          quickUnlockResult: result,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        step: MasterPasswordSetupStep.ready,
        status: StateStatus.success,
        quickUnlockOn: true,
      ),
    );
  }

  /// "Not now".
  void skipQuickUnlock() {
    if (state.status.isLoading) return;
    emit(
      state.copyWith(
        step: MasterPasswordSetupStep.ready,
        status: StateStatus.success,
      ),
    );
  }

  /// "Add your first person" or "Look around first": the store opened at
  /// [create] becomes the session's.
  Future<void> finish() async {
    if (state.step != MasterPasswordSetupStep.ready) return;
    final quickUnlockOn = state.quickUnlockOn;
    emit(state.copyWith(step: MasterPasswordSetupStep.done));
    _fuzzyAuthStore.onSetUpComplete();
    if (quickUnlockOn) {
      await _fuzzyAuthStore.setBiometricEnabled(enabled: true);
    }
  }
}
