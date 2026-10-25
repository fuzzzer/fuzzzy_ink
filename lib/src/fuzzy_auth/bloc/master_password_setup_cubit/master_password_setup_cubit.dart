import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

part 'master_password_setup_state.dart';

/// The first run: a master password ("good" or better), then the recovery
/// key — saved and confirmed, or explicitly skipped. Nothing from an earlier
/// build survives: its data cannot be opened without the old key.
class MasterPasswordSetupCubit extends Cubit<MasterPasswordSetupState> {
  MasterPasswordSetupCubit({
    required ChatAuthRepository chatAuthRepository,
    required AppResetRepository appResetRepository,
    required FuzzyAuthStore fuzzyAuthStore,
    required PasswordStrengthService passwordStrengthService,
  })  : _chatAuthRepository = chatAuthRepository,
        _appResetRepository = appResetRepository,
        _fuzzyAuthStore = fuzzyAuthStore,
        _passwordStrengthService = passwordStrengthService,
        super(const MasterPasswordSetupState());

  final ChatAuthRepository _chatAuthRepository;
  final AppResetRepository _appResetRepository;
  final FuzzyAuthStore _fuzzyAuthStore;
  final PasswordStrengthService _passwordStrengthService;

  bool isStrongEnough(String password) =>
      _passwordStrengthService.isStrongEnough(password);

  /// Clears whatever an earlier install left, then lets the core draw every
  /// key and open the store. The recovery key comes next.
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
    final setUpRes = await _chatAuthRepository.setUp(password);
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
    emit(
      MasterPasswordSetupState(
        step: MasterPasswordSetupStep.recoveryKey,
        status: StateStatus.success,
        recoveryKey: setup.recoveryKey,
        recoveryWrap: setup.recoveryWrap,
        recoveryLock: setup.recoveryLock,
      ),
    );
  }

  /// The user saved the recovery key: its wrap and lock are kept, the app
  /// opens.
  Future<void> confirmRecoveryKeySaved() async {
    final recoveryKey = state.recoveryKey;
    final recoveryWrap = state.recoveryWrap;
    final recoveryLock = state.recoveryLock;
    if (recoveryKey == null ||
        recoveryWrap == null ||
        recoveryLock == null ||
        state.status.isLoading) {
      return;
    }
    emit(state.copyWith(status: StateStatus.loading));
    final saveRes = await _chatAuthRepository.saveRecovery(
      PendingRecoveryKey(
        recoveryKey: recoveryKey,
        recoveryWrap: recoveryWrap,
        recoveryLock: recoveryLock,
      ),
    );
    if (saveRes is CryptoCoreFailure<void>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failureType: saveRes.type,
        ),
      );
      return;
    }
    _finish();
  }

  /// The user chose, after the warning, to go without a recovery key: its
  /// wrap is never stored, so no recovery key exists for this device.
  void skipRecoveryKey() {
    if (state.recoveryWrap == null || state.status.isLoading) return;
    _finish();
  }

  void _finish() {
    emit(const MasterPasswordSetupState(step: MasterPasswordSetupStep.done));
    _fuzzyAuthStore.onSetUpComplete();
  }
}
