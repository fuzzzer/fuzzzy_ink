import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part 'fuzzy_user_auth_preferences_state.dart';

class FuzzyUserAuthPreferencesCubit
    extends Cubit<FuzzyUserAuthPreferencesState> {
  final ChatAuthRepository _chatAuthRepository;
  final FuzzyAuthStore _fuzzyAuthStore;
  final BiometricAuthRepository _biometricAuthRepository;
  final PasswordStrengthService _passwordStrengthService;

  FuzzyUserAuthPreferencesCubit({
    required ChatAuthRepository chatAuthRepository,
    required FuzzyAuthStore fuzzyAuthStore,
    required BiometricAuthRepository biometricAuthRepository,
    required PasswordStrengthService passwordStrengthService,
  })  : _chatAuthRepository = chatAuthRepository,
        _fuzzyAuthStore = fuzzyAuthStore,
        _biometricAuthRepository = biometricAuthRepository,
        _passwordStrengthService = passwordStrengthService,
        super(
          const FuzzyUserAuthPreferencesState(
            activationStatus: StateStatus.initial,
          ),
        );

  /// The bar the vault and the archive export set: "good" or better. Only
  /// a new or changed password must reach it; an existing one still unlocks.
  bool isStrongEnough(String password) {
    final level = _passwordStrengthService.assess(password).level;
    return level == PasswordStrengthLevel.good ||
        level == PasswordStrengthLevel.strong;
  }

  void _emitTooWeak(AuthPreferencesAction action) {
    emit(
      state.copyWith(
        activationStatus: StateStatus.failed,
        lastAction: action,
        activationFailure: DefaultFailure(
          message: currentContextLocalization.chatAuthPasswordTooWeak,
        ),
      ),
    );
  }

  Future<void> enableAuth(String password) async {
    if (!isStrongEnough(password)) {
      _emitTooWeak(AuthPreferencesAction.enable);
      return;
    }
    emit(
      state.copyWith(
        activationStatus: StateStatus.loading,
        lastAction: AuthPreferencesAction.enable,
      ),
    );
    try {
      final isSetUp = await _chatAuthRepository.setupPassword(password);
      if (!isSetUp) {
        emit(
          state.copyWith(
            activationStatus: StateStatus.failed,
            activationFailure: DefaultFailure(),
          ),
        );
        return;
      }

      await _fuzzyAuthStore.onPasswordSetup(password);
      emit(
        state.copyWith(
          activationStatus: StateStatus.success,
          lastAction: AuthPreferencesAction.enable,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          activationStatus: StateStatus.failed,
          activationFailure: DefaultFailure(message: e.toString()),
        ),
      );
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isStrongEnough(newPassword)) {
      _emitTooWeak(AuthPreferencesAction.changePassword);
      return;
    }
    emit(
      state.copyWith(
        activationStatus: StateStatus.loading,
        lastAction: AuthPreferencesAction.changePassword,
      ),
    );
    try {
      final success = await _fuzzyAuthStore.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (success) {
        emit(
          state.copyWith(
            activationStatus: StateStatus.success,
            lastAction: AuthPreferencesAction.changePassword,
          ),
        );
      } else {
        emit(
          state.copyWith(
            activationStatus: StateStatus.failed,
            activationFailure: DefaultFailure(
              message: currentContextLocalization.chatAuthIncorrectPassword,
            ),
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          activationStatus: StateStatus.failed,
          activationFailure: DefaultFailure(message: e.toString()),
        ),
      );
    }
  }

  Future<void> disableAuth(String currentPassword) async {
    emit(
      state.copyWith(
        activationStatus: StateStatus.loading,
        lastAction: AuthPreferencesAction.disable,
      ),
    );
    try {
      final isValid = await _chatAuthRepository.verifyPassword(currentPassword);
      if (!isValid) {
        emit(
          state.copyWith(
            activationStatus: StateStatus.failed,
            activationFailure: DefaultFailure(
              message: currentContextLocalization.chatAuthIncorrectPassword,
            ),
          ),
        );
        return;
      }

      final isDisabled = await _chatAuthRepository.disableAuth(currentPassword);
      if (!isDisabled) {
        emit(
          state.copyWith(
            activationStatus: StateStatus.failed,
            activationFailure: DefaultFailure(),
          ),
        );
        return;
      }

      await _biometricAuthRepository.disable(BiometricScope.chat);
      await _fuzzyAuthStore.checkAuthStatus();
      emit(
        state.copyWith(
          activationStatus: StateStatus.success,
          lastAction: AuthPreferencesAction.disable,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          activationStatus: StateStatus.failed,
          activationFailure: DefaultFailure(message: e.toString()),
        ),
      );
    }
  }

  Future<void> enableBiometric(String currentPassword) async {
    emit(
      state.copyWith(
        activationStatus: StateStatus.loading,
        lastAction: AuthPreferencesAction.enableBiometric,
      ),
    );
    try {
      final isValid = await _chatAuthRepository.verifyPassword(currentPassword);
      if (!isValid) {
        emit(
          state.copyWith(
            activationStatus: StateStatus.failed,
            activationFailure: DefaultFailure(
              message: currentContextLocalization.chatAuthIncorrectPassword,
            ),
          ),
        );
        return;
      }

      final result = await _biometricAuthRepository.enable(
        BiometricScope.chat,
        currentPassword,
      );
      if (result != BiometricEnableResult.enabled) {
        emit(
          state.copyWith(
            activationStatus: StateStatus.failed,
            activationFailure: DefaultFailure(
              message: result == BiometricEnableResult.notStrongEnough
                  ? currentContextLocalization.biometricNotStrongEnough
                  : currentContextLocalization.biometricNotTurnedOn,
            ),
          ),
        );
        return;
      }
      await _fuzzyAuthStore.setBiometricEnabled(enabled: true);
      emit(
        state.copyWith(
          activationStatus: StateStatus.success,
          lastAction: AuthPreferencesAction.enableBiometric,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          activationStatus: StateStatus.failed,
          activationFailure: DefaultFailure(message: e.toString()),
        ),
      );
    }
  }

  Future<void> disableBiometric() async {
    emit(
      state.copyWith(
        activationStatus: StateStatus.loading,
        lastAction: AuthPreferencesAction.disableBiometric,
      ),
    );
    try {
      await _biometricAuthRepository.disable(BiometricScope.chat);
      await _fuzzyAuthStore.setBiometricEnabled(enabled: false);
      emit(
        state.copyWith(
          activationStatus: StateStatus.success,
          lastAction: AuthPreferencesAction.disableBiometric,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          activationStatus: StateStatus.failed,
          activationFailure: DefaultFailure(message: e.toString()),
        ),
      );
    }
  }
}
