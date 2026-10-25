import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

part 'master_password_recovery_state.dart';

/// The forgotten-password path: the recovery key sets a new master password
/// ("good" or better) and opens the app.
class MasterPasswordRecoveryCubit extends Cubit<MasterPasswordRecoveryState> {
  MasterPasswordRecoveryCubit({
    required ChatAuthRepository chatAuthRepository,
    required FuzzyAuthStore fuzzyAuthStore,
    required PasswordStrengthService passwordStrengthService,
  })  : _chatAuthRepository = chatAuthRepository,
        _fuzzyAuthStore = fuzzyAuthStore,
        _passwordStrengthService = passwordStrengthService,
        super(const MasterPasswordRecoveryState());

  final ChatAuthRepository _chatAuthRepository;
  final FuzzyAuthStore _fuzzyAuthStore;
  final PasswordStrengthService _passwordStrengthService;

  bool isStrongEnough(String password) =>
      _passwordStrengthService.isStrongEnough(password);

  Future<void> recover({
    required String recoveryKey,
    required String newPassword,
  }) async {
    if (state.status.isLoading) return;
    if (!isStrongEnough(newPassword)) {
      emit(
        const MasterPasswordRecoveryState(
          status: StateStatus.failed,
          tooWeak: true,
        ),
      );
      return;
    }
    emit(const MasterPasswordRecoveryState(status: StateStatus.loading));
    final recoverRes = await _chatAuthRepository.recover(
      recoveryKey: recoveryKey,
      newPassword: newPassword,
    );
    if (recoverRes is CryptoCoreFailure<void>) {
      emit(
        MasterPasswordRecoveryState(
          status: StateStatus.failed,
          failureType: recoverRes.type,
        ),
      );
      return;
    }
    emit(const MasterPasswordRecoveryState(status: StateStatus.success));
    await _fuzzyAuthStore.onRecovered();
  }
}
