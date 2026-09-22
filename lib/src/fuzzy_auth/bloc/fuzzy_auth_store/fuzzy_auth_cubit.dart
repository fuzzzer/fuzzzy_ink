import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

part 'fuzzy_auth_state.dart';

class FuzzyAuthStore extends Cubit<FuzzyAuthState> {
  FuzzyAuthStore({
    required this.chatAuthRepository,
    required this.biometricAuthRepository,
    required this.cryptoStoreKeyRepository,
    required this.cryptoCoreService,
  }) : super(
          const FuzzyAuthState.initial(),
        );

  final ChatAuthRepository chatAuthRepository;
  final BiometricAuthRepository biometricAuthRepository;
  final CryptoStoreKeyRepository cryptoStoreKeyRepository;
  final CryptoCoreService cryptoCoreService;

  /// The store is open whenever the status is `noAuthRequired` or
  /// `authenticated`, and closed on [lock]. Whether the lock is enabled is
  /// read from the store-key blob, not the preference
  /// ([ChatAuthRepository.isChatAuthEnabled]).
  Future<void> checkAuthStatus() async {
    final ensureRes = await cryptoStoreKeyRepository.ensureStoreKey('');
    if (ensureRes is CryptoCoreFailure) {
      logger.e('Store key could not be created: ${ensureRes.type}');
    }

    final enabled = await chatAuthRepository.isChatAuthEnabled();
    final biometricEnabled =
        enabled && await biometricAuthRepository.isEnabled(BiometricScope.chat);
    if (enabled) {
      emit(
        state.copyWith(
          status: AuthStateStatus.locked,
          biometricEnabled: biometricEnabled,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStateStatus.noAuthRequired,
          biometricEnabled: false,
        ),
      );
    }
  }

  Future<void> unlockWithBiometrics() async {
    emit(state.copyWith(status: AuthStateStatus.unlocking));
    try {
      final password =
          await biometricAuthRepository.retrievePassword(BiometricScope.chat);
      if (password == null) {
        logger.w(
          'Biometric unlock returned null password (cancelled or empty storage)',
        );
        await _handleBiometricInvalidation();
        return;
      }
      await unlock(password);
    } catch (e, stack) {
      logger.e('Biometric unlock failed', error: e, stackTrace: stack);
      await _handleBiometricInvalidation();
    }
  }

  Future<void> _handleBiometricInvalidation() async {
    await biometricAuthRepository.disable(BiometricScope.chat);
    emit(
      state.copyWith(
        status: AuthStateStatus.locked,
        biometricEnabled: false,
        biometricInvalidated: true,
      ),
    );
  }

  Future<void> unlock(String password) async {
    emit(state.copyWith(status: AuthStateStatus.unlocking));

    final isValid = await chatAuthRepository.verifyPassword(password);

    if (isValid) {
      emit(
        state.copyWith(
          status: AuthStateStatus.authenticated,
          authData: AuthData(password: password),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStateStatus.locked,
          verificationFailed: true,
        ),
      );
    }
  }

  Future<void> authenticate(AuthData authData) async {
    emit(
      state.copyWith(
        status: AuthStateStatus.authenticated,
        authData: authData,
      ),
    );
  }

  Future<void> lock() async {
    await cryptoCoreService.close();
    emit(
      state.copyWith(
        status: AuthStateStatus.locked,
        authData: const AuthData(password: ''),
      ),
    );
  }

  Future<void> onPasswordSetup(String password) async {
    emit(
      state.copyWith(
        status: AuthStateStatus.authenticated,
        authData: AuthData(password: password),
      ),
    );
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final success = await chatAuthRepository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );

    if (success) {
      await biometricAuthRepository.disable(BiometricScope.chat);
      emit(
        state.copyWith(
          authData: AuthData(password: newPassword),
          biometricEnabled: false,
        ),
      );
    }

    return success;
  }

  Future<void> setBiometricEnabled({required bool enabled}) async {
    emit(state.copyWith(biometricEnabled: enabled));
  }
}
